#!/bin/bash

set -o errexit

JSON="tools/json"

tarball=$1
output=$2
gzservers=$3

if [[ -z ${gzservers} ]]; then
  gzservers=gzhosts.json
fi

bzip=$(echo $tarball | grep "tar.bz2" || /bin/true ) 

if [[ -n ${bzip} ]]; then
  UNCOMPRESS=bzcat
else
  UNCOMPRESS=gzcat
fi

host=$(cat ${gzservers} | json  $(($RANDOM % `cat ${gzservers} | ./tools/json length`)) )
gzhost=$(echo ${host} | json hostname)
dataset=$(echo ${host} | json dataset)

SSH="ssh root@${gzhost}"

echo "{
  \"brand\": \"joyent\",
  \"zfs_io_priority\": 10,
  \"quota\": 10000,
  \"ram\": 1024,
  \"max_physical_memory\": 1024,
  \"nowait\": true,
  \"dataset_uuid\": \"${dataset}\",
  \"alias\": \"temp_image.$$\",
  \"hostname\": \"temp_image.$$\",
  \"dns_domain\": \"lab.joyent.dev\",
  \"resolvers\": [
    \"8.8.8.8\"
  ],
  \"autoboot\": true,
  \"nics\": [
    {
      \"nic_tag\": \"admin\",
      \"ip\": \"dhcp\"
    }
  ]
}" | $SSH "vmadm create"

uuid=$(${SSH} "vmadm list -p -o uuid,alias | grep temp_image.$$ | cut -d ':' -f 1")

cat ${tarball} | ${SSH} "zlogin ${uuid} 'cd / ; ${UNCOMPRESS} | tar -xf -'"

cat tools/clean-image.sh | ${SSH} "zlogin ${uuid} 'cat > /tmp/clean-image.sh; /usr/bin/bash /tmp/prepare-image.sh; shutdown -i5 -g0 -y;'"

${SSH} "zfs snapshot zones/${uuid}@dataset.$$ ; zfs send zones/${uuid}@dataset.$$" | cat > ${output}

${SSH} "vmadm destroy ${uuid}"
