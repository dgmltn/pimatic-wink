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
     
  class WinkBinarySwitch extends env.devices.PowerSwitch
    @_wink_state

    constructor: (@config, @plugin) ->
      @id = @config.id
      @name = @config.name
      @device_id = @config.device_id
      @pubnub_channel = @config.pubnub_channel
      @pubnub_subscribe_key = @config.pubnub_subscribe_key
      @switch_type = 'binary_switch'
      @plugin = @plugin

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
      return wink_switch(@plugin.config.auth_token, @device_id, undefined, @switch_type) 
        .then( (result) => 
          @_wink_state = result.powered
          @_setState(@_wink_state) )
        .catch( (err) =>
            env.logger.error("Error getting status from Wink ", err))

    changeStateTo: (state) ->
      assert state is on or state is off
      if @_state is state then return Promise.resolve()
      if @_wink_state is state then return Promise.resolve()
      return wink_switch(@plugin.config.auth_token, @device_id, state, @switch_type)
        .then( (result) => 
          @_wink_state = result.powered
          @_setState(@_wink_state) )

    initialize: ()->
      @plugin.pendingAuth.then( (auth_token) =>
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
        @body = JSON.parse(result)
        @desired_state = @body.desired_state
        @powered = @desired_state.powered

        if @powered?
          @_wink_state =  @powered
          env.logger.debug(@name + " Wink Status >> " + @powered)
          @_setState(@_wink_state)


  class WinkLightSwitch extends WinkBinarySwitch

    constructor: (@config, @plugin) ->
      super(@config, @plugin)
      @switch_type = 'light_switch'


  return exports = {
    WinkBinarySwitch,
    WinkLightSwitch
  }
