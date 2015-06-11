# #Shell device configuration options
module.exports = {
  title: "pimatic-wink device config schemas"
  WinkBinarySwitch: {
    title: "WinkBinarySwitch config options"
    type: "object"
    properties:
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
      interval:
        description: "
          The time in ms, the command gets executed to get the actual state. 
          If 0 then the state will not updated automatically.
        "
        type: "number"
        default: 0
  }
}
