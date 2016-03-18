class RegisterDeviceHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: (data={}, callback=->) =>
    data.discoverWhitelist = [data.owner] if data.owner?
    data.configureWhitelist = [data.owner] if data.owner?
    request =
      metadata:
        jobType: 'RegisterDevice'
      data: data

    @jobManager.do @requestQueue, @responseQueue, request, (error, response) =>
      return callback error: error.message if error?
      return callback JSON.parse response.rawData

module.exports = RegisterDeviceHandler