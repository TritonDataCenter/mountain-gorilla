#!/bin/bash
# vi: expandtab sw=2 ts=2
#
# "Prepare a dataset, by deploying to JPC"
#
# This is called for "appliance" image/dataset builds to: (a) provision
# a new zone of a given image, (b) drop in an fs tarball and
# optionally some other tarballs, and (c) make an image out of this.
#
# This uses a "gzhost" on which to create a new zone for the image
# build. One of the hosts in "gzhosts.json" is chosen at random.
#

export PS4='${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
if [[ -z "$(echo "$*" | grep -- '-h' || /bin/true)" ]]; then
  # Try to avoid xtrace goop when print help/usage output.
  set -o xtrace
fi
set -o errexit



#---- globals, config

TOP=$(cd $(dirname $0)/../ >/dev/null; pwd)
JSON=$TOP/tools/json

if [[ -z "$SDC_ACCOUNT" ]]; then
    export SDC_ACCOUNT="Joyent_Dev"
fi
if [[ -z "$SDC_URL" ]]; then
    export SDC_URL="https://us-east-1.api.joyentcloud.com"
fi

if [[ -z "$SDC_KEY_ID" ]]; then
    export SDC_KEY_ID="$(ssh-keygen -l -f ~/.ssh/id_rsa.pub | awk '{print $2}' | tr -d '\n')"
fi

# UUID of the created image/dataset.
uuid=""

image_uuid=""
tarballs=""
packages=""
output=""



#---- functions

function fatal {
  echo "$(basename $0): error: $1"
  exit 1
}

function cleanup() {
  local exit_status=${1:-$?}
  if [[ -n $gzhost ]]; then
    if [[ -n "$uuid" ]]; then
      ${SSH} "vmadm stop -F ${uuid} ; vmadm destroy ${uuid}"
    fi
  fi
  exit $exit_status
}

function usage() {
    if [[ -n "$1" ]]; then
        echo "error: $1"
        echo ""
    fi
    echo "Usage:"
    echo "  prep_dataset.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h              Print this help and exit."
    echo "  -i IMAGE_UUID   The base image UUID."
    echo "  -t TARBALL      Space-separated list of tarballs to unarchive into"
    echo "                  the new image. A tarball is of the form:"
    echo "                    TARBALL-ABSOLUTE-PATH-PATTERN[:SYSROOT]"
    echo "                  The default 'SYSROOT' is '/'. A '/' sysroot is the"
    echo "                  typical fs tarball layout with '/root' and '/site'"
    echo "                  base dirs. This can be called multiple times for"
    echo "                  more tarballs."
    echo "  -p PACKAGES     Space-separated list of pkgsrc package to install."
    echo "                  This can be called multiple times."
    echo "  -o OUTPUT       Image output path. Should be of the form:"
    echo "                  '/path/to/name.zfs.bz2'."
    echo "  -v VERSION      Version for produced image manifest."
    echo "  -n NAME         NAME for the produced image manifest."
    echo "  -d DESCRIPTION  DESCRIPTION for the produced image manifest."
    echo ""
    echo "  -s GZSERVERS    DEPRECATED. Don't see this being used."
    echo ""
    exit 1
}




#---- mainline

trap cleanup ERR

while getopts ht:p:i:o:n:v:d: opt; do
  case $opt in
  h)
    usage
    ;;
  t)
    if [[ -n "${OPTARG}" ]]; then
      tarballs="${tarballs} ${OPTARG}"
    fi
    ;;
  p)
    if [[ -n "${OPTARG}" ]]; then
      packages="${packages} ${OPTARG}"
    fi
    ;;
  i)
    image_uuid=${OPTARG}
    ;;
  o)
    output=$OPTARG
    ;;
  n)
    image_name=$OPTARG
    ;;
  v)
    image_version=$OPTARG
    ;;
  d)
    image_description="$OPTARG"
    ;;
  \?)
    echo "Invalid flag"
    exit 1;
  esac
done

if [[ -z ${output} ]]; then
  fatal "No output file specified. Use '-o' option."
fi

[[ -n $image_name ]] || fatal "No image name, use '-n NAME'."
[[ -n $image_version ]] || fatal "No image version, use '-v VERSION'."
[[ -n $image_description ]] || fatal "No image description, use '-v DESC'."

if [[ -z "$image_uuid" ]]; then
  fatal "No image_uuid provided. Use the '-i' option."
fi


#
# Choose a compression algorithm for the resulting image. The output file name
# should indicate gzip or bzip2.
#
output_ext=${output##*.}
output_sans_ext=${output%.*}
if [[ "$output_ext" == "gz" ]]; then
  compression="gzip"
elif [[ "$output_ext" == "bz2" ]]; then
  compression="bzip2"
else
  fatal "could not determine compression from output file ext: '$output_ext'"
fi

# Create the machine in the specified DC

machine=$(sdc-createmachine -e $image_uuid | json 'id')

state=$(sdc-getmachine $machine | json 'state')
while [[ $state == 'provisioning' ]]; do
  sleep 1
  state=$(sdc-getmachine $machine | json 'state')
done

machine_json=$(sdc-getmachine $machine)

if [[ $state != 'running' ]]; then
  echo "Problem with machine $machine"
  exit 1
fi
SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$(echo $machine_json | json ips.0)"

# "tarballs" is a list of:
#   TARBALL-ABSOLUTE-PATH-PATTERN[:SYSROOT]
# e.g.:
#   /root/joy/mountain-gorilla/bits/amon/amon-agent-*.tgz:/opt
for tb_info in $tarballs; do
  tb_tarball=$(echo "$tb_info" | awk -F':' '{print $1}')
  tb_sysroot=$(echo "$tb_info" | awk -F':' '{print $2}')
  [[ -z "$tb_sysroot" ]] && tb_sysroot=/

  bzip=$(echo $tb_tarball | grep "bz2$" || /bin/true)
  if [[ -n ${bzip} ]]; then
    uncompress=bzcat
  else
    uncompress=gzcat
  fi

  echo "Copying tarball '${tb_tarball}' to zone '${uuid}'."
  if [[ "$tb_sysroot" == "/" ]]; then
    # Special case: for tb_sysroot == '/' we presume these are fs-tarball
    # style tarballs with "/root/..." and "/site/...". We strip
    # appropriately.
    cat ${tb_tarball} | ${SSH} "cd / ; ${uncompress} | gtar --strip-components 1 -xf - root"
  else
    cat ${tb_tarball} | ${SSH} "cd ${tb_sysroot} ; ${uncompress} | gtar -xf -"
  fi
done

##
# install packages
if [[ -n "${packages}" ]]; then
  echo "Installing these pkgsrc package: '${packages}'"

  ${SSH} "/opt/local/bin/pkgin -f -y update"
  ${SSH} "touch /opt/local/.dlj_license_accepted"
  ${SSH} "/opt/local/bin/pkgin -y in ${packages}"

  echo "Validating pkgsrc installation"
  for p in ${packages}
  do
    echo "Checking for $p"
    PKG_OK=$(${SSH} "/opt/local/bin/pkgin -y list | grep ${p} || true")
    if [[ -z "${PKG_OK}" ]]; then
      echo "error: pkgin install failed (${p})"
      exit 1
    fi
  done

fi

cat tools/clean-image.sh \
  | ${SSH} "cat > /tmp/clean-image.sh; /usr/bin/bash /tmp/clean-image.sh; shutdown -i5 -g0 -y;"

# XXX And then somehow turn it in to an image XXX

echo $machine_json

sdc-stopimage $machine
sleep 2
sdc-deleteimage $machine

cat <<EOF>> ${output_sans_ext}.imgmanifest
{
    "v": 2,
    "uuid": "${uuid}",
    "name": "${image_name}",
    "version": "${image_version}",
    "description": "${image_description}",
    "published_at": "${timestamp}",
    "owner": "00000000-0000-0000-0000-000000000000",
    "type": "zone-dataset",
    "os": "smartos",
    "public": false,
    "files": [
        {
            "sha1": "${shasum}",
            "size": ${size},
            "compression": "${compression}"
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
    "tags": {
        "smartdc_service": true
    }
}
EOF
