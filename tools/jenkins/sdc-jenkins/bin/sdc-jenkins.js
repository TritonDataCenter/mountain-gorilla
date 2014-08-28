#!/usr/bin/env node
/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

/*
 * Copyright (c) 2014, Joyent, Inc.
 */

var App = require('../lib/app');
var cmdln = require('cmdln');

// Avoid DEPTH_ZERO_SELF_SIGNED_CERT error from self-signed certs
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

cmdln.main(App);
