#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2014, Joyent, Inc.
#

#
# This script gets called as:
#
# tools/setup-cloudapi.sh <remote>
#
# where <remote> is a user@host combination to which you can ssh and connect
# to the global zone of a SDC headnode. This script will then setup cloudapi on
# this headnode.
#

set -o errexit
set -o xtrace

REMOTE=$1

function fatal() {
    echo "$@" >&2
    exit 2
}

[[ -n ${REMOTE} && -z $2 ]] || fatal "Usage: $0 <remote>"

ssh -T ${REMOTE} <<EOF
export PATH="/usr/bin:/usr/sbin:/smartdc/bin:/opt/smartdc/bin:/opt/local/bin:/opt/local/sbin:/opt/smartdc/agents/bin"

# Create cloudapi
ADMIN_UUID=\$(bash /lib/sdc/config.sh -json | json ufds_admin_uuid)

NUM_ZONES=\$(sdc-vmapi /vms?owner_uuid=\$ADMIN_UUID\&tag.smartdc_role=cloudapi </dev/null | json -H length)
if [[ \$NUM_ZONES < 1 ]]; then
    echo "Provision cloudapi zone."
    cat <<EOM | sapiadm provision
{
    "service_uuid": "\$(sdc-sapi /services?name=cloudapi </dev/null | json -H 0.uuid)",
    "params": {
        "alias": "cloudapi0",
        "networks": [
            {
                "uuid": "\$(sdc-napi /networks </dev/null | json -H -c 'this.name=="admin"' 0.uuid)"
            },
            {
                "uuid": "\$(sdc-napi /networks </dev/null | json -H -c 'this.name=="external"' 0.uuid)",
                "primary": true
            }
        ]
    }
}
EOM
else
    echo "Already have a cloudapi zone."
fi

echo "Should set SDC_URL to one of:"
for ip in \$(sdc-vmapi /vms?owner_uuid=\$ADMIN_UUID\&tag.smartdc_role=cloudapi | json -Ha nics.0.ip nics.1.ip); do
    echo "SDC_URL=\"https://\${ip}\""
done
EOF
