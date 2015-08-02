# #pimatic-wink configuration options
module.exports = {
  title: "pimatic-wink config options"
  type: "object"
  properties:
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
}
