#!/usr/bin/env node

var App = require('../lib/app');
var cmdln = require('cmdln');

// Avoid DEPTH_ZERO_SELF_SIGNED_CERT error from self-signed certs
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

cmdln.main(App);
