// https://nodejs.org/api/https.html
var https = require('https');

// https://nodejs.org/api/fs.html
var fs = require('fs');

////////////////////////////////////////////////////////////////////////////////
// Auth Token
////////////////////////////////////////////////////////////////////////////////

var cached_auth_token;

var read_auth_token = function(callback) {
    if (callback === undefined) {
        return;
    }

    if (cached_auth_token) {
        callback(undefined, cached_auth_token);
        return;
    }

    var path = require('path').resolve(__dirname, 'WINK_AUTH_TOKEN');
    fs.readFile(path, function (err, token) {
        if (err) {
            if (err.code === 'ENOENT') {
                callback('NO_AUTH_TOKEN', undefined);
            }
            else {
                callback(err, undefined);
            }
        }
        else {
            cached_auth_token = token;
            callback(undefined, token);
        }
    });
};

var write_auth_token = function(token, callback) {
    var path = require('path').resolve(__dirname, 'WINK_AUTH_TOKEN');
    fs.writeFile(path, token, function (err) {
        if (err) {
            callback(err);
            return;
        }
        if (callback !== undefined) {
            cached_auth_token = token;
            callback();
        }
    });
};

////////////////////////////////////////////////////////////////////////////////
// Device Map
////////////////////////////////////////////////////////////////////////////////

var read_device_map = function(callback) {
    if (callback === undefined) {
        return;
    }

    var path = require('path').resolve(__dirname, 'WINK_DEVICE_MAP');
    fs.readFile(path, 'utf8', function(err, data) {
        if (err && err.code === 'ENOENT') {
            callback('NOT_FOUND', undefined);
            return;
        }
        else if (err) {
            callback(err, undefined);
            return;
        }
        callback(undefined, data);
    });
};

var write_device_map = function(data, callback) {
    var path = require('path').resolve(__dirname, 'WINK_DEVICE_MAP');
    fs.writeFile(path, data, function (err) {
        if (err) {
            callback(err);
            return;
        }
        if (callback !== undefined) {
            callback();
        }
    });
};

////////////////////////////////////////////////////////////////////////////////
// HTTPS
////////////////////////////////////////////////////////////////////////////////

var wink_https = function(method, path, put_body, callback) {
    var options = {
        host: 'winkapi.quirky.com',
        path: path,
        method: method,
        headers: {}
    };

    if (put_body !== undefined) {
        options.headers['Content-Type'] = 'application/json';
        options.headers['Content-Length'] = put_body.length;
    }

    var the_request = function() {
        var result = {};

        var req = https.request(options, function(res) {
            result.status = res.statusCode;
            result.headers = res.headers;
            result.body = '';
            res.on('data', function (chunk) {
                result.body += chunk;
            });
            res.on('end', function() {
                if (callback !== undefined) {
                    callback(result.status == 200 ? undefined : result.status, result);
                }
            });
        });

        // write data to request body
        if (put_body !== undefined) {
            req.write(put_body);
        }

        req.end();

        req.on('error', function(e) {
            result.error = e;
            if (callback !== undefined) {
                callback(e, result);
            }
        });
    };

    // Special case for when we're specifically trying to get the auth token
    if (path !== '/oauth2/token') {
        read_auth_token(function(err, token) {
            if (token) {
                options.headers['Authorization'] = 'Bearer ' + token;
            }
            the_request(callback);
        });
    }
    else {
        the_request(callback);
    }
};

////////////////////////////////////////////////////////////////////////////////
// Wink exported interface
////////////////////////////////////////////////////////////////////////////////

var Wink = function() {};

// let's use brightness = [0, 100]
Wink.prototype.light_bulb = function(device_id, brightness, callback) {
    var path = '/light_bulbs/' + device_id;

    var parse_state_callback = function(err, result) {
        if (callback === undefined) {
            return;
        }

        if (err) {
            callback(err, result);
            return;
        }

        var body;
        try {
            body = JSON.parse(result.body);
        }
        catch(e) {
            callback(e, result);
            return;
        }

        var desired_state = body.data.desired_state;
        var powered = desired_state.powered;
        var brightness = desired_state.brightness;
        callback(undefined, powered ? brightness * 100 : 0);
    };

    // brightness argument => set the light bulb's state / brightness
    if (brightness !== undefined) {
        var put_body = JSON.stringify({
            'desired_state': { 'powered': brightness != 0, 'brightness': (brightness / 100) }
        });
        wink_https('PUT', path, put_body, parse_state_callback);
    }

    // No argument => get the light bulb's state
    else {
        wink_https('GET', path, undefined, parse_state_callback);
    }   
};

Wink.prototype.binary_switch = function(device_id, powered, callback) {
    var path = '/binary_switches/' + device_id;

    var parse_state_callback = function(err, result) {
        if (callback === undefined) {
            return;
        }

        if (err) {
            callback(err, result);
            return;
        }

        var body;
        try {
            body = JSON.parse(result.body);
        }
        catch(e) {
            callback(e, result);
            return;
        }

        var desired_state = body.data.desired_state;
        var powered = desired_state.powered;
        callback(undefined, powered ? true : false);
    };

    if (powered !== undefined) {
        var put_body = JSON.stringify({
            'desired_state': { 'powered': !!powered }
        });
        wink_https('PUT', path, put_body, parse_state_callback);
    }
    else {
        wink_https('GET', path, undefined, parse_state_callback);
    }
};

Wink.prototype.shade = function(device_id, position, callback) {
    var path = '/shades/' + device_id;

    var position_map = {
        'up': 1,
        'down': 0
    };
    var position_unmap = {
        1: 'up',
        0: 'down'
    };

    var parse_state_callback = function(err, result) {
        if (callback === undefined) {
            return;
        }

        if (err) {
            callback(err, result);
            return;
        }

        var body;
        try {
            body = JSON.parse(result.body);
        }
        catch(e) {
            callback(e, result);
            return;
        }

        var desired_state = body.data.desired_state;
        var position = position_unmap[desired_state.position];
        if (position === undefined) {
            position = 'stopped';
        }
        callback(undefined, position);
    };

    if (position !== undefined && position_map[position] !== undefined) {
        var put_body = JSON.stringify({
            'desired_state': { 'position': position_map[position] }
        });
        wink_https('PUT', path, put_body, parse_state_callback);
    }
    else {
        wink_https('GET', path, undefined, parse_state_callback);
    }
};

// https://groups.google.com/forum/#!topic/openhab/pmrns4Yb8fM
// {"data":{"access_token":"267.....094","refresh_token":"b1b.....da8","token_type":"bearer","token_endpoint":"https://winkapi.quirky.com/oauth2/token"},"errors":[],"pagination":{},"access_token":"2670e.....1094","refresh_token":"b1b.....da8","token_type":"bearer","token_endpoint":"https://winkapi.quirky.com/oauth2/token"}
Wink.prototype.auth_token = function(client_id, client_secret, username, password, callback) {
    var path = '/oauth2/token';

    var put_body = JSON.stringify({
        'client_id': client_id,
        'client_secret': client_secret,
        'username': username,
        'password': password,
        'grant_type': 'password',
    });

    wink_https('POST', path, put_body, function(err, result) {
        if (callback === undefined) {
            return;
        }

        if (err) {
            callback(err, result);
            return;
        }

        var body;
        try {
            body = JSON.parse(result.body);
        }
        catch(e) {
            callback(e, result);
            return;
        }

        var access_token = body.data.access_token;
        write_auth_token(access_token, function(err) {
            callback(undefined, access_token);
        });
    });
};

Wink.prototype.device_id_map = function(callback) {

    read_device_map(function(err, data) {
        if (err === 'NOT_FOUND' || err === undefined && data === undefined) {
            wink_https('GET', '/users/me/wink_devices', undefined, function(err, result) {
                if (err) {
                    callback(err, result);
                    return;
                }

                var body;
                try {
                    body = JSON.parse(result.body);
                }
                catch(e) {
                    callback(e, result);
                    return;
                }

                var devices = {};
                var data = body.data;
                if (data !== undefined && data.constructor === Array) {
                    for (var i = 0; i < data.length; i++) {
                        var device = data[i];
                        if (device.name === undefined) {
                            // No name, can't identify
                        }
                        else if (device.light_bulb_id !== undefined) {
                            devices[device.name] = {
                                'device_id': device.light_bulb_id,
                                'device_type': 'light_bulb'
                            };
                        }
                        else if (device.binary_switch_id !== undefined) {
                            devices[device.name] = {
                                'device_id': device.binary_switch_id,
                                'device_type': 'binary_switch'
                            };
                        }
                        else if (device.shade_id !== undefined) {
                            devices[device.name] = {
                                'device_id': device.shade_id,
                                'device_type': 'shade'
                            };
                        }
                    }
                }

                write_device_map(JSON.stringify(devices), function(err) {
                    callback(err, devices);
                });
            });
        }
        else if (err) {
            callback(err, undefined);
            return;
        }
        else {
            try {
                callback(undefined, JSON.parse(data));
            }
            catch(e) {
                callback(e, undefined);
            }
        }
    });

};

module.exports = new Wink();

