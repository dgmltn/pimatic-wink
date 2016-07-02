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
      @plugin = @plugin
      @id = @config.id
      @name = @config.name
      @device_id = @config.device_id
      @pubnub_channel = @config.pubnub_channel
      @pubnub_subscribe_key = @config.pubnub_subscribe_key
      @switch_type = 'binary_switch'


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
      @changeStateTo off

  
    downloadState: () ->
      return wink_switch(@plugin.config.auth_token, @device_id, undefined, @switch_type) 
        .then( (result) =>  
          env.logger.debug("downloadState "+@name +  " state:"  + @_state) 
          @syncpimatic2wink(result))
        .catch( (err) => env.logger.error("Error getting status from Wink ", err))

    changeStateTo: (state) ->
      assert state is on or state is off
      return Promise.resolve() if @_state is state 
      return Promise.resolve() if @_wink_state is state  
      env.logger.debug("changeStateTo "+ @name + " From:" + @_state + " to:"+state)
      return wink_switch(@plugin.config.auth_token, @device_id, state, @switch_type)

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
      env.logger.debug("CALLBACK "+@name +  " @state:"  + @_state )
      @body = JSON.parse(result)
      @syncpimatic2wink(@body)

    syncpimatic2wink: (result) ->
      desired_state = result.desired_state.powered
      last_reading = result.last_reading.powered
      @renderWink(desired_state, last_reading)

    renderWink: (desired_state, last_reading) ->
      @_wink_state = last_reading
      env.logger.debug(@name + " Wink desired_state >> " + desired_state)
      env.logger.debug(@name + " Wink last_reading >> " + last_reading)

      if desired_state?
        @_setState(@_wink_state)  if desired_state is last_reading
      else
        @_setState(@_wink_state) 



  class WinkLightSwitch extends WinkBinarySwitch
    constructor: (@config, @plugin) ->
      super(@config, @plugin)
      @switch_type = 'light_switch'

  class WinkLock extends WinkBinarySwitch
    constructor: (@config, @plugin) ->
      super(@config, @plugin)
      @switch_type = 'lock'

    syncpimatic2wink: (result) ->
      desired_state = result.desired_state.locked
      last_reading = result.last_reading.locked
      @renderWink(desired_state, last_reading)

  return exports = {
    WinkBinarySwitch,
    WinkLightSwitch,
    WinkLock
  }
