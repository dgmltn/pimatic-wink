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


  class WinkShade extends env.devices.ShutterController

    constructor: (@config, @plugin) ->
      @id = @config.id
      @name = @config.name
      @device_id = @config.device_id
      @pubnub_channel = @config.pubnub_channel
      @pubnub_subscribe_key = @config.pubnub_subscribe_key
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
      return wink_shade(@plugin.config.auth_token, @device_id, undefined) 
        .then( (result) => @_setPosition(result) )
        .catch( (err) =>
            env.logger.error("Error getting status from Wink ", err))

    moveToPosition: (position) ->
      assert position in ['up', 'down', 'stopped']
      return wink_shade(@plugin.config.auth_token, @device_id, position) 
        .then( (result) => @_setPosition(result) )
        .catch( (err) =>
            env.logger.error("Error getting status from Wink ", err))

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
      position_unmap = 
        1: 'up',
        0: 'down'

      @body = JSON.parse(result)
      @desired_state = @body.desired_state
      @position = position_unmap[@desired_state.position]

      if @powered?
        @_setPosition(@position)
      else
        @position = 'stopped'
   

  return exports = {
    WinkShade
  }
