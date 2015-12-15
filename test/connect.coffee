_ = require 'lodash'
meshblu = require 'meshblu'
async = require 'async'
uuid    = require 'uuid'
redis = require 'fakeredis'
RedisNS = require '@octoblu/redis-ns'
{Pool} = require 'generic-pool'
JobManager = require 'meshblu-core-job-manager'
Server = require '../src/server'
UpstreamMeshbluServer = require './upstream-meshblu-server'

class Connect
  constructor: ->
    @redisId = uuid.v1()
    @jobManager = new JobManager
      client: _.bindAll new RedisNS 'ns', redis.createClient(@redisId)
      timeoutSeconds: 1

  connect: (callback) =>
    async.series [
      @startServer
      @startUpstream
      @createConnection
      @authenticateConnection
      @authenticateUpstreamConnection
    ], (error) =>
      return callback error if error?
      @connection.on 'ready', =>
        callback null,
          sut: @sut
          connection: @connection
          upstreamSocket: @upstreamSocket
          device: {uuid: 'masseuse', token: 'assassin'}
          jobManager: new JobManager
            client: _.bindAll new RedisNS 'ns', redis.createClient(@redisId)
            timeoutSeconds: 1

  shutItDown: (callback) =>
    @connection.close()

    async.series [
      async.apply @upstream.stop
      async.apply @sut.stop
    ], callback

  startServer: (callback) =>
    pool = new Pool
      max: 1
      min: 0
      create: (callback) =>
        client = _.bindAll new RedisNS 'ns', redis.createClient(@redisId)
        callback null, client
      destroy: (client) => client.end true

    @sut = new Server
      port: 0xcafe
      pool: pool
      timeoutSeconds: 1
      meshbluConfig:
        server: 'localhost'
        port:   0xbabe

    @sut.start callback

  startUpstream: (callback) =>
    @onUpstreamConnection = sinon.spy()
    @upstream = new UpstreamMeshbluServer onConnection: @onUpstreamConnection, port: 0xbabe
    @upstream.start callback

  createConnection: (callback) =>
    @connection = meshblu.createConnection
      server: 'localhost'
      port: 0xcafe
      uuid: 'masseuse'
      token: 'assassin'
      options: transports: ['websocket']

    @connection.on 'notReady', (error) =>
      console.error error.stack
      throw error

    callback()

  authenticateConnection: (callback) =>
    @jobManager.getRequest ['request'], (error, @request) =>
      return callback error if error?

      response =
        metadata:
          responseId: @request.metadata.responseId
          code: 204

      @jobManager.createResponse 'response', response, callback

  authenticateUpstreamConnection: (callback) =>
    onUpstreamConnectionCalled = => @onUpstreamConnection.called
    wait = (callback) => _.delay callback, 10
    async.until onUpstreamConnectionCalled, wait, =>
      [@upstreamSocket] = @onUpstreamConnection.firstCall.args
      @upstreamSocket.on 'devices', @onDevices = sinon.stub()
      @upstreamSocket.emit 'ready',
        api: 'connect'
        status: 201
        uuid: 'masseuse'
        token: 'assassin'
      callback()

module.exports = Connect
