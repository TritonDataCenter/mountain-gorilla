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
# setup-remote-build-zone.sh <remote>
#
# where <remote> is an SSH target like root@<IP/hostname>. This will then
# login to the remote zone and set it up to be able to build MG targets
# designated for the image the zone is running.
#
# If the remote is not a zone or is not running a known image, this script
# will abort.
#
# In order to work successfully, the remote zone should be running one of the
# following images:
#
#   sdc-smartos 1.6.3
#   sdc-multiarch 13.3.1
#
# IMPORTANT:
#
#  You must have the variables: MANTA_USER, MANTA_KEY_ID, MANTA_URL, SDC_ACCOUNT
#  SDC_KEY_ID and SDC_URL set in your environment when you run this script.
#
#  Ideally you will point this script at a *brand new* zone without existing
#  modifications. If there are existing modifications, there may be unexpected
#  build problems.
#

set -o errexit
if [[ -n ${TRACE} ]]; then
    set -o xtrace
fi

function fatal() {
    echo "$@" >&2
    exit 2
}

[[ -n ${MANTA_USER} ]] || fatal "\${MANTA_USER} is not set"
[[ -n ${MANTA_KEY_ID} ]] || fatal "\${MANTA_KEY_ID} is not set"
[[ -n ${MANTA_URL} ]] || fatal "\${MANTA_URL} is not set"
[[ -n ${SDC_ACCOUNT} ]] || fatal "\${SDC_ACCOUNT} is not set"
[[ -n ${SDC_KEY_ID} ]] || fatal "\${SDC_KEY_ID} is not set"
[[ -n ${SDC_URL} ]] || fatal "\${SDC_URL} is not set"

REMOTE=$1

[[ -z ${REMOTE} || -n $2 ]] && fatal "Usage: $0 <remote>"

ssh -T ${REMOTE} <<EOF
#!/bin/bash

set -o errexit
if [[ -n "${TRACE}" ]]; then
    set -o xtrace
fi

IMAGE=\$(mdata-get sdc:image_uuid || true)
if [[ \${IMAGE} == "fd2cc906-8938-11e3-beab-4359c665ac99" ]]; then
    VERSION="1.6.3"
elif [[ \${IMAGE} == "b4bdc598-8939-11e3-bea4-8341f6861379" ]]; then
    VERSION="13.3.1"
else
    echo "Unknown image. Try again with a zone running a known image." >&2
    exit 1
fi

echo "Found image version \${VERSION}"

echo "Installing packages..."

if [[ \${VERSION} == "1.6.3" ]]; then
    SDCNODE_BUILD="https://download.joyent.com/pub/build/sdcnode/fd2cc906-8938-11e3-beab-4359c665ac99/master-20140830T012655Z/sdcnode/sdcnode-v0.10.26-zone-fd2cc906-8938-11e3-beab-4359c665ac99-master-20140829T232408Z-g649a9b0.tgz"
    pkgin -y install binutils
    pkgin -y install scmgit gcc-compiler gmake python26 \
        gcc-runtime gcc-tools png GeoIP GeoLiteCity ghostscript \
        zookeeper-client postgresql91-client-9.1.2 gsharutils
    [[ ! -e /opt/local/bin/gld ]] && (cd /opt/local/bin && ln -s ld gld)
else
    SDCNODE_BUILD="https://download.joyent.com/pub/build/sdcnode/b4bdc598-8939-11e3-bea4-8341f6861379/master-20140830T005350Z/sdcnode/sdcnode-v0.10.26-zone-b4bdc598-8939-11e3-bea4-8341f6861379-master-20140829T232139Z-g649a9b0.tgz"
    pkgin -y install binutils
    pkgin -y install gcc47 gmake \
        scmgit python26 png GeoIP GeoLiteCity ghostscript zookeeper-client \
        gsharutils build-essential postgresql91-client
fi

echo "Fixing ~/.bashrc..."

grep "^MANTA_USER=" ~/.bashrc \
    || echo "export MANTA_USER=\"${MANTA_USER}\"" >> ~/.bashrc
grep "^MANTA_KEY_ID=" ~/.bashrc \
    || echo "export MANTA_KEY_ID=\"${MANTA_KEY_ID}\"" >> ~/.bashrc
grep "^MANTA_URL=" ~/.bashrc \
    || echo "export MANTA_URL=\"${MANTA_URL}\"" >> ~/.bashrc
grep "^SDC_ACCOUNT=" ~/.bashrc \
    || echo "export SDC_ACCOUNT=\"${SDC_ACCOUNT}\"" >> ~/.bashrc
grep "^SDC_KEY_ID=" ~/.bashrc \
    || echo "export SDC_KEY_ID=\"${SDC_KEY_ID}\"" >> ~/.bashrc
grep "^SDC_URL=" ~/.bashrc \
    || echo "export SDC_URL=\"${SDC_URL}\"" >> ~/.bashrc
grep "^PATH=.*/root/opt/node/bin" ~/.bashrc \
    || echo "export PATH=\"/opt/local/bin:/opt/local/sbin:/usr/bin:/usr/sbin:/root/opt/node/bin\"" >> ~/.bashrc

echo "Ensuring we have ~/opt/node..."

if [[ ! -f /root/opt/node/bin/node ]]; then
   mkdir -p ~/opt && (cd ~/opt && curl \${SDCNODE_BUILD} | tar -zxvf -)
   /root/opt/node/bin/node /root/opt/node/lib/node_modules/npm/cli.js install -gf npm
fi

echo "Setting ~/.npmrc..."

echo "registry = http://registry.npmjs.org/" > ~/.npmrc

touch /opt/local/.dlj_license_accepted

echo 'DONE!'

exit 0
EOF

exit 0
