module.exports = (env) ->

  # ###require modules included in pimatic
  # To require modules that are included in pimatic use `env.require`. For available packages take 
  # a look at the dependencies section in pimatics package.json

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'

  # Other depencies
  #pubnub = require 'pubnub'
  PUBNUB = require("pubnub")
 
  wink = require('./wink-node.js')

  wink_auth_token = Promise.promisify(wink.auth_token);
  wink_device_id_map = Promise.promisify(wink.device_id_map);
  wink_binary_switch = Promise.promisify(wink.binary_switch);
  wink_light_bulb = Promise.promisify(wink.light_bulb);
  wink_light_switch = Promise.promisify(wink.light_switch);
  wink_shade = Promise.promisify(wink.shade);

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
      env.logger.info("Starting...")
      wink.init(env)
      @pendingAuth = new Promise( (resolve, reject) =>
        if @config.auth_token? and !!@config.auth_token   
          env.logger.debug("Have Auth token:" + @config.auth_token + ":")
          resolve()

        else
          env.logger.debug("No Auth token found")
          wink_auth_token(@config.client_id, @config.client_secret, @config.username, @config.password)
          .then( (result) =>  
            env.logger.debug("Have auth token now")
            @config.auth_token = result
            resolve())
          .catch( (err) =>
            env.logger.error("Error getting token - please verify you have set correct the username and password in the config ", err)
            #reject()  don't propogate for now - will do it when we can disable devices
            #for now catching and displaying an error is good enough, it prevents 
            #pimatic from sending events to the devices
            )
        )

      deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass("WinkBinarySwitch", {
        configDef: deviceConfigDef.WinkBinarySwitch, 
        createCallback: (config) => return new WinkBinarySwitch(config)
      })

      @framework.deviceManager.registerDeviceClass("WinkLightBulb", {
        configDef: deviceConfigDef.WinkLightBulb, 
        createCallback: (config) => return new WinkLightBulb(config)
      })

      @framework.deviceManager.registerDeviceClass("WinkLightSwitch", {
        configDef: deviceConfigDef.WinkLightSwitch, 
        createCallback: (config) => return new WinkLightSwitch(config)
      })

      @framework.deviceManager.registerDeviceClass("WinkShade", {
        configDef: deviceConfigDef.WinkShade, 
        createCallback: (config) => return new WinkShade(config)
      })

      @framework.deviceManager.on('discover', (eventData) =>
        @framework.deviceManager.discoverMessage(
          'pimatic-wink', 'Contacting Wink to get list of devices'
        )

        wink_device_id_map(plugin.config.auth_token)
          .then( (result) => @winkOnDiscover(result) )
      )

    winkOnDiscover : (data) ->
      #if (data !== undefined && data.constructor === Array) {
      for device in data
        if device.name? and !!device.name
          @device_name = device.name
          env.logger.debug(@device_name)
          @subscribe_key = device.subscription.pubnub.subscribe_key
          @channel = device.subscription.pubnub.channel

          if device.light_bulb_id? and !!device.light_bulb_id 
            @device_id = device.light_bulb_id
            @device_type = 'light_bulb'
            @class_name = "WinkLightBulb"
            @tellframework(@device_id, @device_name, @device_type, @class_name, @subscribe_key, @channel)

          else if device.binary_switch_id? and !!device.binary_switch_id  
            @device_id = device.binary_switch_id
            @device_type = 'binary_switch'
            @class_name = "WinkBinarySwitch"
            @tellframework(@device_id, @device_name, @device_type, @class_name, @subscribe_key, @channel)

          else if device.shade_id? and !!device.shade_id 
            @device_id = device.shade_id
            @device_type = 'shade'
            @class_name = "WinkShade"
            @tellframework(@device_id, @device_name, @device_type, @class_name, @subscribe_key, @channel)

        else
          # No name, can't identify
          env.logger.debug ("Discovery: undefined device")     

    tellframework : (device_id, device_name, device_type, class_name, subscribe_key, channel) ->
        config = {
          class: class_name
          device_id: device_id
          device_type: device_type
          pubnub_channel : channel
          pubnub_subscribe_key : subscribe_key
        }
        env.logger.debug(config)
        @framework.deviceManager.discoveredDevice(
          'pimatic-wink', device_name, config
        )
    
  class WinkBinarySwitch extends env.devices.PowerSwitch

    constructor: (@config) ->
      @id = @config.id
      @name = @config.name
      @device_id = @config.device_id
      @device_type = @config.device_type
      @pubnub_channel = @config.pubnub_channel
      @pubnub_subscribe_key = @config.pubnub_subscribe_key

      updateValue = =>
        if @config.interval > 0
          @downloadState().finally( =>
            @timerId = setTimeout(updateValue, @config.interval) 
          )
      super()
      @initialize()


    destroy: () ->
        clearTimeout @timerId if @timerId?
        if @intervalTimerID?
          clearInterval @intervalTimerID
        super()
  
    downloadState: () ->
      return wink_binary_switch(plugin.config.auth_token, @device_id, undefined) 
        .then( (result) => 
          @_setState(result) )

    changeStateTo: (state) ->
      assert state is on or state is off
      if @_state is state then return Promise.resolve()
      return wink_binary_switch(plugin.config.auth_token, @device_id, state)
        .then( (result) => @_setState(result) )

    initialize: ()->
      plugin.pendingAuth.then( (auth_token) =>
        env.logger.debug("Intializing " + @name)
        @subdata = 
          subscribe_key  : @pubnub_subscribe_key

        @channeldata = 
          channel  : @pubnub_channel

        pubnub = PUBNUB(@subdata) 
        pubnub.subscribe(@channeldata, @pncallback.bind(this))
        @downloadState()
      )      

    pncallback: (result) ->
      try
        @body = JSON.parse(result)
        @desired_state = @body.desired_state
        @powered = @desired_state.powered

        if @powered?
          env.logger.debug(@name + " Wink Status >> " + @powered)
          @_setState(@powered)

      catch error
         env.logger.debug(error)
      finally

  class WinkShade extends env.devices.ShutterController

    constructor: (@config) ->
      @id = @config.id
      @name = @config.name
      @device_id = @config.device_id
      @device_type = @config.device_type
      @pubnub_channel = @config.pubnub_channel
      @pubnub_subscribe_key = @config.pubnub_subscribe_key

      updateValue = =>
        if @config.interval > 0
          @downloadState().finally( =>
            @timerId = setTimeout(updateValue, @config.interval) 
          )
      super()
      @initialize()

    destroy: () ->
        clearTimeout @timerId if @timerId?
        super()
  
    downloadState: () ->
      return wink_shade(plugin.config.auth_token, @device_id, undefined) 
        .then( (result) => @_setPosition(result) )

    moveToPosition: (position) ->
      assert position in ['up', 'down', 'stopped']
      return wink_shade(plugin.config.auth_token, @device_id, position) 
        .then( (result) => @_setPosition(result) )

    initialize: ()->
      plugin.pendingAuth.then( (auth_token) =>
        env.logger.debug("Intializing " + @name)
        @subdata = 
          subscribe_key  : @pubnub_subscribe_key

        @channeldata = 
          channel  : @pubnub_channel

        pubnub = PUBNUB(@subdata) 
        pubnub.subscribe(@channeldata, @pncallback.bind(this))
        @downloadState()
      )  

    pncallback: (result) ->
      position_unmap = 
        1: 'up',
        0: 'down'

      try
        @body = JSON.parse(result)
        @desired_state = @body.desired_state
        @position = position_unmap[@desired_state.position]

        if @powered?
          @_setPosition(@position)
        else
          @position = 'stopped'

      catch error
         env.logger.debug(error)
      finally


  class WinkLightBulb extends env.devices.DimmerActuator

    constructor: (@config) ->
      @id = @config.id
      @name = @config.name
      @device_id = @config.device_id
      @device_type = @config.device_type
      @pubnub_channel = @config.pubnub_channel
      @pubnub_subscribe_key = @config.pubnub_subscribe_key

      updateValue = =>
        if @config.interval > 0
          @downloadState().finally( =>
            @timerId = setTimeout(updateValue, @config.interval) 
          )
      super()
      @initialize()

    destroy: () ->
        clearTimeout @timerId if @timerId?
        super()
  
    # Returns a promise
    turnOn: -> 
      if plugin.config.wink_dim_level
        @changeStateTo on
      else
        @_setDimlevel(100)

    # Retuns a promise
    turnOff: -> @changeStateTo off

    downloadState: () ->
      return wink_light_bulb(plugin.config.auth_token, @device_id, undefined) 
        .then( (result) => @_setDimlevel(result) )
        .then( (result) =>
          if plugin.config.wink_dim_level
            @_setState(result) 
        )

    changeStateTo: (state) ->
      assert state is on or state is off
      if @_state is state then return Promise.resolve()
      return wink_light_switch(plugin.config.auth_token, @device_id, state) 
        .then( (result) => @_setState(result) )

    changeDimlevelTo: (dimlevel) ->
      dimlevel = parseFloat(dimlevel)
      state = dimlevel > 0.0 ? on : off
      assert not isNaN(dimlevel)
      assert dimlevel >= 0
      assert dimlevel <= 100
      if @_dimlevel is dimlevel then return Promise.resolve()
      return wink_light_bulb(plugin.config.auth_token, @device_id, dimlevel) 
        .then( (result) => @_setDimlevel(dimlevel) )

    initialize: ()->
      plugin.pendingAuth.then( (auth_token) =>
        env.logger.debug("Intializing " + @name)
        @subdata = 
          subscribe_key  : @pubnub_subscribe_key

        @channeldata = 
          channel  : @pubnub_channel

        pubnub = PUBNUB(@subdata) 
        pubnub.subscribe(@channeldata, @pncallback.bind(this))
        @downloadState()
      )  

    pncallback: (result) ->
      try
        @body = JSON.parse(result)
        @desired_state = @body.desired_state

        if @desired_state.powered?
          @powered = @desired_state.powered
          env.logger.debug(@name + " Wink Status >> " + @powered)
          @_setState(@powered)

        if @desired_state.brightness? and not isNaN(@desired_state.brightness)
          if plugin.config.wink_dim_level or @powered
            @dimlevel = @desired_state.brightness * 100
          else 
            @dimlevel = 0
          env.logger.debug(@name + " Wink Dim Level >> " + @dimlevel)
          @_setDimlevel(@dimlevel)

      catch error
         env.logger.debug(error)
      finally

  class WinkLightSwitch extends env.devices.PowerSwitch
    constructor: (@config) ->
      @id = @config.id
      @name = @config.name
      @device_id = @config.device_id
      @device_type = @config.device_type
      @pubnub_channel = @config.pubnub_channel
      @pubnub_subscribe_key = @config.pubnub_subscribe_key

      updateValue = =>
        if @config.interval > 0
          @downloadState().finally( =>
            @timerId = setTimeout(updateValue, @config.interval) 
          )
      super()
      @initialize()

    destroy: () ->
        clearTimeout @timerId if @timerId?
        super()
  
    downloadState: () ->
      return wink_light_switch(plugin.config.auth_token, @device_id, undefined) 
        .then( (result) => @_setState(result) )

    changeStateTo: (state) ->
      assert state is on or state is off
      if @_state is state then return Promise.resolve()
      return wink_light_switch(plugin.config.auth_token, @device_id, state) 
        .then( (result) => @_setState(result) )

    initialize: ()->
      plugin.pendingAuth.then( (auth_token) =>
        env.logger.debug("Intializing " + @name)
        @subdata = 
          subscribe_key  : @pubnub_subscribe_key

        @channeldata = 
          channel  : @pubnub_channel

        pubnub = PUBNUB(@subdata) 
        pubnub.subscribe(@channeldata, @pncallback.bind(this))
        @downloadState()
      )  

    pncallback: (result) ->
      try
        @body = JSON.parse(result)
        @desired_state = @body.desired_state
        @powered = @desired_state.powered

        if @powered?
          env.logger.debug(@name + " Wink Status >> ", @powered )
          @_setState(@powered)
      catch error
         env.logger.debug(error)
      finally

  # ###Finally
  # Create a instance of my plugin
  plugin = new PimaticWink
  # and return it to the framework.
  return plugin 
