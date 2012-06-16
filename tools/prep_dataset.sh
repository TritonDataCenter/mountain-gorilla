#!/bin/bash

set -o errexit

JSON="tools/json"

tarballs=""
packages=""
output=""

while getopts t:p:s:o:u:v: opt; do
     case $opt in
       t)
         tarballs="${tarballs} ${OPTARG}"
         ;;
       p)
         packages="${packages} ${OPTARG}"
         ;;
       s)
         gzservers=$OPTARG
         ;;
       o)
         output=$OPTARG
         ;;
       u)
         urn=$OPTARG
         ;;
       v)
         version=$OPTARG
         ;;
       \?)
         echo "Invalid flag"
         exit 1;
     esac
done

if [[ -z ${output} ]]; then
  echo "No output file specified"
  exit 1;
fi

if [[ -z $version ]]; then
  version="0.0.0"
fi

if [[ -z $urn ]]; then
  urn=${output%.bz2}
  urn="sdc:sdc:${urn%.zfs}:${version}"
fi

ofbzip=$(echo ${output} | grep ".bz2$" || /bin/true )

if [[ -n $ofbzip ]]; then
  dobzip="true"
  output=${output%.bz2}
fi

if [[ -z ${gzservers} ]]; then
  gzservers=gzhosts.json
fi

host=$(cat ${gzservers} | json  $(($RANDOM % `cat ${gzservers} | ./tools/json length`)) )
gzhost=$(echo ${host} | json hostname)
dataset=$(echo ${host} | json dataset)

echo "Using gzhost ${gzhost}"
SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${gzhost}"

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

echo "Created build zone ${uuid}"
for tarball in $tarballs; do
  bzip=$(echo $tarball | grep "tar.bz2" || /bin/true )

  if [[ -n ${bzip} ]]; then
    uncompress=bzcat
  else
    uncompress=gzcat
  fi

  echo "Copying tarball ${tarball} to ${uuid}"
  cat ${tarball} | ${SSH} "zlogin ${uuid} 'cd / ; ${uncompress} | gtar --strip-components 1 -xf - root'"
done

##
# install packages
if [[ -n ${packages} ]]; then
  echo "Installing pkgsrc ${packages}"

  echo "Need to wait for an IP address..."
  IP_ADDR=$(${SSH} "vmadm get ${uuid} | json nics | json -a ip")
  until [[ -n $IP_ADDR ]]
  do
      sleep 5
      IP_ADDR=$(${SSH} "vmadm get ${uuid} | json nics | json -a ip")
  done
  echo "IP address acquired ${IP_ADDR}"

  ${SSH} "zlogin ${uuid} '/opt/local/bin/pkgin -f -y update'"
  ${SSH} "zlogin ${uuid} 'touch /opt/local/.dlj_license_accepted'"
  ${SSH} "zlogin ${uuid} '/opt/local/bin/pkgin -y in ${packages}'"

  echo "Validating pkgsrc installation"
  for p in ${packages}
  do
    echo "Checking for $p"
    PKG_OK=$(${SSH} "zlogin ${uuid} '/opt/local/bin/pkgin -y list | grep ${p}'")
    if [[ -z ${PKG_OK} ]]; then
      echo "pkgin install failed (${p})"
      exit 1
    fi
  done

fi

#
# import smf manifests
${SSH} "zlogin ${uuid} '/usr/bin/find /opt/smartdc -name manifests -exec svccfg import {} \;'"

cat tools/clean-image.sh | ${SSH} "zlogin ${uuid} 'cat > /tmp/clean-image.sh; /usr/bin/bash /tmp/clean-image.sh; shutdown -i5 -g0 -y;'"

${SSH} "zfs snapshot zones/${uuid}@dataset.$$ ; zfs send zones/${uuid}@dataset.$$" | cat > ${output}

${SSH} "vmadm destroy ${uuid}"

if [[ -n $dobzip ]]; then
  bzip2 ${output}
  output=${output}.bz2
fi

timestamp=$(node -e 'console.log(new Date().toISOString())')
shasum=$(/usr/bin/sum -x sha1 ${output} | cut -d ' ' -f1)
size=$(/usr/bin/du -ks ${output} | cut -f 1)

cat <<EOF>> ${output%.bz2}.dsmanifest
  {
    "name": "${output%.zfs}",
    "version": "${version}",
    "type": "zone-dataset",
    "description": "${output}",
    "published_at": "${timestamp}",
    "os": "smartos",
    "files": [
      {
        "path": "${output}",
        "sha1": "${shasum}",
        "size": ${size},
        "url": "${output}"
      }
    ],
    "requirements": {
      "networks": [
        {
          "name": "net0",
          "description": "admin"
        }
      ]
    },
    "uuid": "${uuid}",
    "creator_uuid": "352971aa-31ba-496c-9ade-a379feaecd52",
    "vendor_uuid": "352971aa-31ba-496c-9ade-a379feaecd52",
    "creator_name": "sdc",
    "platform_type": "smartos",
    "cloud_name": "sdc",
    "urn": "${urn}:${version}",
    "created_at": "${timestamp}",
    "updated_at": "${timestamp}"
  }
EOF

