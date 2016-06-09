#/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2014, Joyent, Inc.
#

#
# This script outputs a list of targets that can be built with MG in a
# sdc-smartos 1.6.3 build zone, in the order the should be built.
#

BASE=$(cd $(dirname $0) && pwd)/../

# These are dependencies for other builds below
echo "registrar"
echo "config-agent"
echo "amon"
echo "minnow"

# The bulk of the builds come from here. Anything that's not requiring 13.3.1
# should be built on 1.6.3.
cd ${BASE}
if [[ ! -f "targets.json" ]]; then
    bash < targets.json.in | json > targets.json
fi
node -e "var targets = require('./targets.json'); Object.keys(targets).forEach(function (t) { if (['all', 'usbheadnode', 'usbheadnode-debug', 'platform', 'platform-debug', 'agentsshar', 'minnow', 'amon', 'registar', 'config-agent', 'mockcloud', 'incr-upgrade', 'zonetracker'].indexOf(t) !== -1) { return; }; if (targets[t].image_uuid !== 'b4bdc598-8939-11e3-bea4-8341f6861379') { console.log(t); } });" | sort

# This comes last as it depends on all the individual agents to be built first.
echo "agentsshar"

exit 0
