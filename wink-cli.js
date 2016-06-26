// Generate an auth token for your username and password.  
// Use the token in subsequent calls
// node wink-cli.js auth_token 'xxxxx@yyyyyyy.com' '123456'

// Look up Wink devices by name and id.  Displays the list of devices from Wink;
// node wink-cli.js auth_token device_map

// Get the state of a binary switch, given its id:
// node wink-cli.js auth_token binary_switch 8010

// Turn on or off a binary switch:
// node wink-cli.js auth_token binary_switch 8010 true
// node wink-cli.js auth_token binary_switch 8010 false

// Get the state of a light bulb:
// node wink-cli.js auth_token light_bulb 100234

// Set the light bulb's dim level to 10% (and turn it on):
// node wink-cli.js auth_token light_bulb 100234 10

// Turn off the light bulb:
// node wink-cli.js auth_token light_bulb 100234 0

// Turn the light bulb's dim level to 90% (and turn it on):
// node wink-cli.js auth_token light_bulb 100502 90

// Turn the light bulb's dim level to 100% (and turn it on):
// node wink-cli.js auth_token light_bulb 100502 100

// Get the position of a shade (0 = closed, 1 = open):
// node wink-cli.js auth_token shade 100603

// Set the position of a shade to closed
// node wink-cli.js auth_token shade 100603 0

// Set the position of a shade to open
// node wink-cli.js auth_token shade 100603 1

var wink = require("./wink-node.js");

var wink_callback = function(err, result) {
    if (err) {
        console.error('ERROR: ' + err);
    }
    else {
        console.log(result);
    }
};

if (process.argv[2] == 'auth_token') {
    var client_id = 'quirky_wink_android_app';
    var client_secret = 'e749124ad386a5a35c0ab554a4f2c045';
    var username = process.argv[3];
    var password = process.argv[4];
    wink.auth_token(client_id, client_secret, username, password, wink_callback);
}
else if (process.argv[3] == 'device_map') {
    var auth_token = process.argv[2];
    wink.device_id_map(auth_token, wink_callback);
}
else if (process.argv[3] == 'binary_switch') {
    var auth_token = process.argv[2];
    var device_id = process.argv[4];
    var powered = process.argv[5] === undefined ? undefined : process.argv[5] === 'true';
    wink.binary_switch(device_id, powered, wink_callback);
}
else if (process.argv[3] == 'light_bulb') {
    var auth_token = process.argv[2];
    var device_id = process.argv[4];
    var brightness = process.argv[5];
    wink.light_bulb(device_id, brightness, wink_callback);
}
else if (process.argv[3] == 'shade') {
    var auth_token = process.argv[2];
    var device_id = process.argv[4];
    var position = process.argv[5];
    wink.shade(device_id, position, wink_callback);
}
else {
    console.error('ERROR: unrecognized command: "' + process.argv[2] + '"');
}

