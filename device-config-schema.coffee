# #Shell device configuration options
module.exports = {
  title: "pimatic-wink device config schemas"
  WinkBinarySwitch: {
    title: "WinkBinarySwitch config options"
    type: "object"
    properties:
      device_id:
        description: "Device id retrieved using Wink API"
        type: "string"
        required: true        
      pubnub_channel:
        description: "Pubnub channel retrieved using Wink API"
        type: "string"
        required: true    
      pubnub_subscribe_key:
        description: "Pubnub subscription key retrieved using Wink API"
        type: "string"
        required: true    
      interval:
        description: "
          The time in ms, the command gets executed to get the actual state. 
          If 0 then the state will not updated automatically.
        "
        type: "number"
        default: 0   
  }
  WinkLightSwitch: {
    title: "WinkLightSwitch config options"
    type: "object"
    properties:
      device_id:
        description: "Device id retrieved using Wink API"
        type: "string"
        required: true    
      pubnub_channel:
        description: "Pubnub channel retrieved using Wink API"
        type: "string"
        required: true    
      pubnub_subscribe_key:
        description: "Pubnub subscription key retrieved using Wink API"
        type: "string"
        required: true    
      interval:
        description: "
          The time in ms, the command gets executed to get the actual state. 
          If 0 then the state will not updated automatically.
        "
        type: "number"
        default: 0        
  }
  WinkLightBulb: {
    title: "WinkLightBulb config options"
    type: "object"
    properties:
      device_id:
        description: "Device id retrieved using Wink API"
        type: "string"
        required: true    
      pubnub_channel:
        description: "Pubnub channel retrieved using Wink API"
        type: "string"
        required: true    
      pubnub_subscribe_key:
        description: "Pubnub subscription key retrieved using Wink API"
        type: "string"
        required: true    
      interval:
        description: "
          The time in ms, the command gets executed to get the actual state. 
          If 0 then the state will not updated automatically.
        "
        type: "number"
        default: 0        
  }
  WinkShade: {
    title: "WinkShade config options"
    type: "object"
    properties:
      device_id:
        description: "Device id retrieved using Wink API"
        type: "string"
        required: true    
      pubnub_channel:
        description: "Pubnub channel retrieved using Wink API"
        type: "string"
        required: true    
      pubnub_subscribe_key:
        description: "Pubnub subscription key retrieved using Wink API"
        type: "string"
        required: true    
      interval:
        description: "
          The time in ms, the command gets executed to get the actual state. 
          If 0 then the state will not updated automatically.
        "
        type: "number"
        default: 0        
  }
  WinkLock: {
    title: "WinkShade config options"
    type: "object"
    properties:
      device_id:
        description: "Device id retrieved using Wink API"
        type: "string"
        required: true    
      pubnub_channel:
        description: "Pubnub channel retrieved using Wink API"
        type: "string"
        required: true    
      pubnub_subscribe_key:
        description: "Pubnub subscription key retrieved using Wink API"
        type: "string"
        required: true    
      interval:
        description: "
          The time in ms, the command gets executed to get the actual state. 
          If 0 then the state will not updated automatically.
        "
        type: "number"
        default: 0        
  }
}
