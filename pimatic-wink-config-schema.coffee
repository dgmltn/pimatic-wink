# #pimatic-wink configuration options
# Declare your config option for your plugin here. 
module.exports = {
  title: "pimatic-wink config options"
  type: "object"
  properties:
    wink_dim_level:
      description: "If this is set to true then Pimatic will show,
                    Wink dim level and ignore off state. If you use pimatic as your primary controller
                    leve it false.  This for supporting true status in Homekit via hap plugin."
      type: "boolean"
      default: "false"
    client_id:
      description: "oauth2 client_id provided by wink"
      type: "string"
      default: "quirky_wink_android_app"
    client_secret:
      description: "oauth2 client secret provided by wink"
      type: "string"
      default: "e749124ad386a5a35c0ab554a4f2c045"
    username:
      description: "wink username"
      type: "string"
    password:
      description: "wink password"
      type: "string"
    auth_token:
      description: "Oauth token recieved from Wink"
      type: "string"
}
