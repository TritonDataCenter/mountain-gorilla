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
# sdc-multiarch 13.3.1 build zone, in the order the should be built.
#

BASE=$(cd $(dirname $0) && pwd)/../

cd ${BASE}
if [[ ! -f "targets.json" ]]; then
    bash < targets.json.in | json > targets.json
fi

# Anything with the image_uuid set to the 13.3.1 image should be included.
node -e "var targets = require('./targets.json'); Object.keys(targets).forEach(function (t) { if (targets[t].image_uuid === 'b4bdc598-8939-11e3-bea4-8341f6861379') { console.log(t); } });" | sort

exit 0
