module.exports = (env) ->

  # ###require modules included in pimatic
  # To require modules that are included in pimatic use `env.require`. For available packages take 
  # a look at the dependencies section in pimatics package.json

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'

  # Other depencies
  PUBNUB = require("pubnub")
 
  wink = require('./wink-node.js')

  winklightbulb = require("./lib/wink-lightbulb") env
  winkswitch = require("./lib/wink-switch") env
  winkshade = require("./lib/wink-shade") env

  wink_auth_token = Promise.promisify(wink.auth_token);
  wink_device_id_map = Promise.promisify(wink.device_id_map);
  wink_switch = Promise.promisify(wink.wink_switch);
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
        createCallback: (config) => return new winkswitch.WinkBinarySwitch(config, plugin)
      })

      @framework.deviceManager.registerDeviceClass("WinkLightBulb", {
        configDef: deviceConfigDef.WinkLightBulb, 
        createCallback: (config) => return new winklightbulb.WinkLightBulb(config, plugin)
      })

      @framework.deviceManager.registerDeviceClass("WinkLightSwitch", {
        configDef: deviceConfigDef.WinkLightSwitch, 
        createCallback: (config) => return new winkswitch.WinkLightSwitch(config, plugin)
      })

      @framework.deviceManager.registerDeviceClass("WinkLock", {
        configDef: deviceConfigDef.WinkLock, 
        createCallback: (config) => return new winkswitch.WinkLock(config, plugin)
      })


      @framework.deviceManager.registerDeviceClass("WinkShade", {
        configDef: deviceConfigDef.WinkShade, 
        createCallback: (config) => return new winkshade.WinkShade(config, plugin)
      })

      @framework.on "after init", =>
        # Check if the mobile-frontent was loaded and get a instance
        mobileFrontend = @framework.pluginManager.getPlugin 'mobile-frontend'
        if mobileFrontend?
          mobileFrontend.registerAssetFile 'js', "pimatic-wink/app/wink-items.coffee"
          mobileFrontend.registerAssetFile 'html', "pimatic-wink/app/wink-items.jade"
        else
          env.logger.warn "your plugin could not find the mobile-frontend. No gui will be available"

      @framework.deviceManager.on('discover', (eventData) =>
        @framework.deviceManager.discoverMessage(
          'pimatic-wink', 'Contacting Wink to get list of devices'
        )

        wink_device_id_map(plugin.config.auth_token)
          .then( (result) => @winkOnDiscover(result) )
      )

    winkOnDiscover : (data) ->
      #if (data !== undefined && data.constructor === Array) {
      if data?
        for device in data
          if device.name? and !!device.name
            @device_name = device.name
            env.logger.debug(@device_name)
            @subscribe_key = device.subscription.pubnub.subscribe_key
            @channel = device.subscription.pubnub.channel

            if device.light_bulb_id? and !!device.light_bulb_id 
              @device_id = device.light_bulb_id
              @class_name = "WinkLightBulb"
              @tellframework(@device_id, @device_name, @class_name, @subscribe_key, @channel)

            else if device.binary_switch_id? and !!device.binary_switch_id  
              @device_id = device.binary_switch_id
              @class_name = "WinkBinarySwitch"
              @tellframework(@device_id, @device_name, @class_name, @subscribe_key, @channel)

            else if device.shade_id? and !!device.shade_id 
              @device_id = device.shade_id
              @class_name = "WinkShade"
              @tellframework(@device_id, @device_name, @class_name, @subscribe_key, @channel)

            else if device.lock_id? and !!device.lock_id 
              @device_id = device.lock_id
              @class_name = "WinkLock"
              @tellframework(@device_id, @device_name, @class_name, @subscribe_key, @channel)
          else
            # No name, can't identify
            env.logger.debug ("Discovery: undefined device")     

    tellframework : (device_id, device_name, class_name, subscribe_key, channel) ->
        config = {
          class: class_name
          device_id: device_id
          pubnub_channel : channel
          pubnub_subscribe_key : subscribe_key
        }
        env.logger.debug(config)
        @framework.deviceManager.discoveredDevice(
          'pimatic-wink', device_name, config
        )

  # ###Finally
  # Create a instance of my plugin
  plugin = new PimaticWink
  # and return it to the framework.
  return plugin 
