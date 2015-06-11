pimatic-wink
============

Pimatic plugin to interface with Wink connected devices. Currently supports the following device types:
 1. light_bulb
 2. binary_switch
 3. shade

Plugin
------

    {
      "plugin": "wink",
      "client_id": "quirky_wink_android_app",
      "client_secret": "e749124ad386a5a35c0ab554a4f2c045",
      "username": "xxxxx@yyyyyyy.com",
      "password": "123456"
    },

`client_id` and `client_secret` are used for OAuth token generation. 
There's no (known) official way to generate a personalized `client_id` and `client_secret`,
so these were taken from the Android Wink app, first seen here:

  https://github.com/davidgruhin/WinkPost/blob/master/js/wink.js#L335

`username` and `password` are those used to log in to the official Wink app.


Devices
-------
pimatic-wink searches for your devices using the `name` field here. That field must
match exactly as it's seen on the official Wink app.

    {
      "id": "my-light-bulb",
      "class": "WinkLightBulb",
      "name": "Office Light Bulb"
    },
    {
      "id": "my-switch",
      "class": "WinkBinarySwitch",
      "name": "Outlet"
    },
    {
      "id": "my-shade",
      "class": "WinkShade",
      "name": "Curtains"
    },

Bonus: CLI
----------
pimatic-wink includes a bonus utility that can be run from the command line (via `node`).
See wink-cli.js for more information.
