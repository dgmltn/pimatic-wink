module.exports = (env) ->

  # ###require modules included in pimatic
  # To require modules that are included in pimatic use `env.require`. For available packages take 
  # a look at the dependencies section in pimatics package.json

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'

  # Other depencies
  wink = require('./wink-node.js')

  wink_auth_token = Promise.promisify(wink.auth_token);
  wink_device_id_map = Promise.promisify(wink.device_id_map);
  wink_binary_switch = Promise.promisify(wink.binary_switch);
  wink_light_bulb = Promise.promisify(wink.light_bulb);

  class PimaticWink extends env.plugins.Plugin

    # ####init()
    # The `init` function is called by the framework to ask your plugin to initialise.
    #  
    # #####params:
    #  * `app` is the [express] instance the framework is using.
    #  * `framework` the framework itself
    #  * `config` the properties the user specified as config for your plugin in the `plugins` 
    #     section of the config.json file 
    #     
    # 
    init: (app, @framework, @config) =>
      ##env.logger.info("Hello World")
      ##env.logger.info(JSON.stringify(config))

      #TODO uncomment wink_auth_token(config.client_id, config.client_secret, config.username, config.password)
      #TODO uncomment  .then (response) -> env.logger.info(response)

      deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass("WinkBinarySwitch", {
        configDef: deviceConfigDef.WinkBinarySwitch, 
        createCallback: (config) => return new WinkBinarySwitch(config)
      })

      @framework.deviceManager.registerDeviceClass("WinkLightBulb", {
        configDef: deviceConfigDef.WinkLightBulb, 
        createCallback: (config) => return new WinkLightBulb(config)
      })

      @framework.deviceManager.registerDeviceClass("WinkShade", {
        configDef: deviceConfigDef.WinkShade, 
        createCallback: (config) => return new WinkShade(config)
      })

  class WinkBinarySwitch extends env.devices.PowerSwitch

    constructor: (@config) ->
      @id = config.id
      @name = config.name

      updateValue = =>
        if @config.interval > 0
          @downloadState().finally( =>
            setTimeout(updateValue, @config.interval) 
          )

      super()
      @downloadState()

    downloadState: () ->
      return wink_device_id_map()
        .then( (result) => wink_binary_switch(result[@name].device_id, undefined) )
        .then( (result) => @_setState(result) )

    changeStateTo: (state) ->
      assert state is on or state is off
      return wink_device_id_map()
        .then( (result) => wink_binary_switch(result[@name].device_id, state) )
        .then( (result) => @_setState(result) )

  class WinkShade extends env.devices.ShutterController

    constructor: (@config) ->
      @id = config.id
      @name = config.name

      updateValue = =>
        if @config.interval > 0
          @downloadState().finally( =>
            setTimeout(updateValue, @config.interval) 
          )

      super()
      @downloadState()

    downloadState: () ->
      return wink_device_id_map()
        .then( (result) => wink_shade(result[@name].device_id, undefined) )
        .then( (result) => @_setState(result) )

    moveToPosition: (position) ->
      assert position in ['up', 'down', 'stopped']
      return wink_device_id_map()
        .then( (result) => wink_shade(result[@name].device_id, position) )
        .then( (result) => @_setState(result) )

  class WinkLightBulb extends env.devices.DimmerActuator

    constructor: (@config) ->
      @id = config.id
      @name = config.name

      updateValue = =>
        if @config.interval > 0
          @downloadState().finally( =>
            setTimeout(updateValue, @config.interval) 
          )

      super()
      @downloadState()

    downloadState: () ->
      env.logger.info("downloadState")
      return wink_device_id_map()
        .then( (result) => wink_light_bulb(result[@name].device_id, undefined) )
        .then( (result) => @_setDimlevel(result) )

    changeDimlevelTo: (dimlevel) ->
      dimlevel = parseFloat(dimlevel)
      assert not isNaN(dimlevel)
      assert dimlevel >= 0
      assert dimlevel <= 100
      if @_dimlevel is dimlevel then return
      return wink_device_id_map()
        .then( (result) => wink_light_bulb(result[@name].device_id, dimlevel) )
        .then( (result) => @_setDimlevel(dimlevel) )

  # ###Finally
  # Create a instance of my plugin
  instance = new PimaticWink
  # and return it to the framework.
  return instance
