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
 
  wink = require('../wink-node.js')

  wink_light_bulb = Promise.promisify(wink.light_bulb);
  wink_switch = Promise.promisify(wink.wink_switch);

  class WinkLightBulb extends env.devices.DimmerActuator
    template: "wink-lightbulb"
    @_wink_state
    @_wink_level
    @_plugin
    @switch_type

    constructor: (@config,@plugin) ->
      @id = @config.id
      @name = @config.name
      @device_id = @config.device_id
      @pubnub_channel = @config.pubnub_channel
      @pubnub_subscribe_key = @config.pubnub_subscribe_key
      @_plugin = @plugin
      @switch_type = 'light_bulb'

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
      env.logger.debug("turnOn")
      @changeStateTo on 

    # Retuns a promise
    turnOff: -> 
      env.logger.debug("turnOff")
      @changeDimlevelTo 0 

    downloadState: () ->
      return wink_light_bulb(@_plugin.config.auth_token, @device_id, undefined) 
         .then( (result) => 
          env.logger.debug("downloadState "+@name +  " state:"  + @_state + " dimlevel:"+ @_dimlevel)
          env.logger.debug(result)
          @syncpimatic2wink(result)) 
        .catch( (err) =>
          env.logger.error("Error getting status from Wink ", err)) 

    changeStateTo: (state) ->
      env.logger.debug("changeStateTo "+ @name + " From:" + @_state + " to:"+state)
      assert state is on or state is off
      return Promise.resolve() if state is @_wink_state 
      return wink_switch(@_plugin.config.auth_token, @device_id, state, @switch_type) 

    changeDimlevelTo: (dimlevel) ->
      env.logger.debug("changeDimlevelTo "+ @name + " From:" +  @_dimlevel + " to:"+dimlevel)
      dimlevel = parseFloat(dimlevel)
      assert not isNaN(dimlevel)
      assert dimlevel >= 0
      assert dimlevel <= 100
      return Promise.resolve() if dimlevel is @_dimlevel
      return Promise.resolve() if dimlevel is @_wink_level
      return wink_light_bulb(@_plugin.config.auth_token, @device_id, dimlevel) 

    _setDimlevel: (level) =>
      env.logger.debug("_setDimlevel "+@name)
      level = parseFloat(level)
      assert(not isNaN(level))
      assert level >= 0
      assert level <= 100
      if @_dimlevel is level then return
      @_dimlevel = level
      @emit "dimlevel", level
      @_setState(level > 0)

    initialize: ()->
      @_plugin.pendingAuth.then( (auth_token) =>
        env.logger.debug("Intializing " + @name)
        @subdata = 
          subscribe_key  : @pubnub_subscribe_key

        @channeldata = 
          channel  : @pubnub_channel

        pubnub = PUBNUB(@subdata) 
        pubnub.subscribe(@channeldata, @pncallback.bind(this))
        env.logger.debug("INTIALIZE "+@name +  " state:"  + @_state + " dimlevel:"+ @_dimlevel)
        @downloadState()
      )  

    pncallback: (result) ->
      env.logger.debug("CALLBACK "+@name +  " @state:"  + @_state + " dimlevel:"+ @_dimlevel)
      @body = JSON.parse(result)
      @desired_state = @body.desired_state
      @syncpimatic2wink(@desired_state)

    syncpimatic2wink: (desired_state) ->
      env.logger.debug("syncpimatic2wink " + desired_state)

      if desired_state.powered?
        @_wink_state = desired_state.powered
        env.logger.debug(@name + " Wink Status >> " + @_wink_state)

      if desired_state.brightness? and not isNaN(desired_state.brightness)
        @_wink_level = desired_state.brightness * 100
        @dimlevel = @_wink_level
        @dimlevel = 0 if not @_wink_state
        env.logger.debug(@name + " Wink Dim Level >> " + @_wink_level)
        @_setDimlevel(@dimlevel)


  return exports = {
    WinkLightBulb
  }
