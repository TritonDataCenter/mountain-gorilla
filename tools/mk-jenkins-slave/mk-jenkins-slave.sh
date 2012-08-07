#!/bin/bash
#
# Copyright (c) 2012 Joyent Inc., All Rights Reserved.
#

set -e
set -o xtrace

# smartos-1.6.3
DEFAULT_IMAGE_UUID=01b2c898-945f-11e1-a523-af1afbe22822

zonename=$1
if [[ -z "${zonename}" ]]; then
    echo "Usage: $0 <zonename> [<image-uuid>]"
    echo "Where <image-uuid> defaults to the smartos-1.6.3 UUID."
    exit 1
fi

image_uuid=$2
if [[ -z "$image_uuid" ]]; then
    image_uuid=$DEFAULT_IMAGE_UUID
fi
echo "Using image $image_uuid"


# TODO: this is the part where we'd use imgadm to ensure we have
# 01b2c898-945f-11e1-a523-af1afbe22822

TOP=$(cd $(dirname $0)/ >/dev/null; pwd)
USERSCRIPT=$TOP/jenkins-slave-setup.user-script

uuid=$(uuid)

# "longleasenodes" MAC prefix configuration in the BH-1 lab (see TOOLS-132).
mac_prefix="12:22:32"
mac="$mac_prefix:$(openssl rand -hex 1):$(openssl rand -hex 1):$(openssl rand -hex 1)"

(cat | /usr/vm/sbin/add-userscript $USERSCRIPT | vmadm create)<<EOF
{
    "brand": "joyent",
    "alias": "${zonename}",
    "uuid": "${uuid}",
    "cpu_shares": 1000,
    "zfs_io_priority": 30,
    "quota": 100,
    "max_physical_memory": 32768,
    "tmpfs": 8192,
    "dns_domain": "joyent.us",
    "delegate_dataset": true,
    "dataset_uuid": "${image_uuid}",
    "fs_allowed": ["ufs", "pcfs", "tmpfs"],
    "nics": [
      {
        "nic_tag": "admin",
        "ip": "dhcp",
        "mac": "${mac}"
      }
    ]
}
EOF

# Drop in hostname
echo "${zonename}" > /zones/${uuid}/root/etc/nodename

# make it easier to drop in ssh key
mkdir -p /zones/${uuid}/root/root/.ssh
touch /zones/${uuid}/root/root/.ssh/authorized_keys
chmod 700 /zones/${uuid}/root/root/.ssh
chmod 600 /zones/${uuid}/root/root/.ssh/authorized_keys

# Add their keys if they've forwarded agent
ssh-add -L > /zones/${uuid}/root/root/.ssh/authorized_keys

# Add the automation and molybdenum keys.
# The latter was (at least) necessary to clone
# "git@github.com:twitter/bootstrap.git" for the portal build. I don't know
# why.
STUFF_IP=10.2.0.190
export BATCH_SCP="scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o BatchMode=yes"
$BATCH_SCP stuff@$STUFF_IP:trent/mk-jenkins-slave/id_dsa.automation \
    /zones/${uuid}/root/root/.ssh/id_dsa
chmod 600 /zones/${uuid}/root/root/.ssh/id_dsa
$BATCH_SCP stuff@$STUFF_IP:trent/mk-jenkins-slave/id_rsa.molybdenum \
    /zones/${uuid}/root/root/.ssh/id_rsa
chmod 600 /zones/${uuid}/root/root/.ssh/id_rsa

sleep 3

# find IP
IP=$(zlogin ${uuid} ipadm show-addr -o type,addr -p | grep dhcp | cut -d ':' -f2 | cut -d '/' -f1)
if [[ -n ${IP} ]]; then
    echo "IP is ${IP}"
else
    echo "unable to determine IP, try: zlogin ${uuid}"
fi

tail -f /zones/${uuid}/root/var/svc/log/smartdc-mdata\:execute.log

exit 0
