#!/bin/bash
# vi: expandtab sw=2 ts=2
#
# "Prepare a dataset, by deploying to JPC"
#
# This is called for "appliance" image/dataset builds to: (a) provision
# a new zone of a given image, (b) drop in an fs tarball and
# optionally some other tarballs, and (c) make an image out of this.
#

export PS4='${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
if [[ -z "$(echo "$*" | grep -- ' -h ' || /bin/true)" ]]; then
  # Try to avoid xtrace goop when print help/usage output.
  set -o xtrace
fi
set -o errexit



#---- globals, config

CREATED_MACHINE_UUID=
CREATED_MACHINE_IMAGE_UUID=
TOP=$(cd $(dirname $0)/../ >/dev/null; pwd)
JSON=${TOP}/tools/json
export PATH="${TOP}/node_modules/manta/bin:${TOP}/node_modules/smartdc/bin:${PATH}"
image_package="g3-standard-2-smartos"

if [[ -z ${SDC_ACCOUNT} ]]; then
  export SDC_ACCOUNT="Joyent_Dev"
fi
if [[ -z ${SDC_URL} ]]; then
  # Manta locality, use east
  export SDC_URL="https://us-east-1.api.joyentcloud.com"
  # To test in us-beta-4 uncomment the following:
  #export SDC_URL=https://165.225.142.135
  #export SDC_TESTING=1
fi

if [[ -z ${SDC_KEY_ID} ]]; then
  export SDC_KEY_ID="$(ssh-keygen -l -f ~/.ssh/id_rsa.pub | awk '{print $2}' | tr -d '\n')"
fi

if [[ -z ${MANTA_USER} ]]; then
  export MANTA_USER=${SDC_ACCOUNT}
fi
if [[ -z ${MANTA_URL} ]]; then
  export MANTA_URL=https://us-east.manta.joyent.com
fi

if [[ -z ${MANTA_KEY_ID} ]]; then
  export MANTA_KEY_ID="${SDC_KEY_ID}"
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

  cleanup 1
}

function cleanup() {
  local exit_status=${1:-$?}
  if [[ "$KEEP_INFRA_ON_FAILURE" == "true" || "$KEEP_INFRA_ON_FAILURE" == 1 ]]; then
    echo "$0: NOT cleaning up (KEEP_INFRA_ON_FAILURE=$KEEP_INFRA_ON_FAILURE)"
  else
    if [[ -n ${CREATED_MACHINE_UUID} ]]; then
      sdc-deletemachine ${CREATED_MACHINE_UUID}
    fi
    if [[ -n ${CREATED_MACHINE_IMAGE_UUID} ]]; then
      sdc-deleteimage ${CREATED_MACHINE_IMAGE_UUID}
    fi
  fi
  exit ${exit_status}
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
  echo "  -b BUILD_NAME   The name of the build (if different from the image name)"
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

  echo "  -P PACKAGE      Package (instance / limit) name to use (eg sdc_256)"
  echo "  -o OUTPUT       Image output path. Should be of the form:"
  echo "                  '/path/to/name.manta'."
  echo "  -v VERSION      Version for produced image manifest."
  echo "  -n NAME         NAME for the produced image manifest."
  echo "  -d DESCRIPTION  DESCRIPTION for the produced image manifest."
  echo ""
  exit 1
}


#---- mainline

trap cleanup ERR

while getopts ht:p:P:i:o:n:v:d:b: opt; do
  case ${opt} in
  h)
    usage
    ;;
  t)
    if [[ -n ${OPTARG} ]]; then
      tarballs="${tarballs} ${OPTARG}"
    fi
    ;;
  p)
    if [[ -n ${OPTARG} ]]; then
      packages="${packages} ${OPTARG}"
    fi
    ;;
  P)
    if [[ -n ${OPTARG} ]]; then
      image_package="${OPTARG}"
    fi
    ;;
  i)
    if [[ -n ${OPTARG} ]]; then
        image_uuid=${OPTARG}
    fi
    ;;
  o)
    if [[ -n ${OPTARG} ]]; then
        output="${OPTARG}"
    fi
    ;;
  b)
    if [[ -n ${OPTARG} ]]; then
        build_name=${OPTARG}
    fi
    ;;
  n)
    if [[ -n ${OPTARG} ]]; then
        image_name=${OPTARG}
    fi
    ;;
  v)
    if [[ -n ${OPTARG} ]]; then
        image_version=${OPTARG}
    fi
    ;;
  d)
    if [[ -n ${OPTARG} ]]; then
        image_description="${OPTARG}"
    fi
    ;;
  \?)
    echo "Invalid flag"
    exit 1;
  esac
done

if [[ -z ${output} ]]; then
  fatal "No output file specified. Use '-o' option."
fi

[[ -n ${image_name} ]] || fatal "No image name, use '-n NAME'."
[[ -n ${image_version} ]] || fatal "No image version, use '-v VERSION'."
[[ -n ${image_description} ]] || image_description="${image_name}"
[[ -n ${build_name} ]] || build_name=${image_name}

if [[ -z ${image_uuid} ]]; then
  fatal "No image_uuid provided. Use the '-i' option."
fi

# Create the machine in the specified DC
package=$(sdc-listpackages | ${JSON} -c "this.name == '${image_package}'" 0.id)
[[ -n ${package} ]] || fatal "cannot find package \"${image_package}\""

machine=$(sdc-createmachine --dataset ${image_uuid} --package ${package} --tag MG_IMAGE_BUILD=true --name "TEMP-${build_name}-$(date +%s)"  | json id)
[[ -n ${machine} ]] || fatal "cannot get uuid for new VM."

# Set this here so from here out fatal() can try to destroy too.
CREATED_MACHINE_UUID=${machine}

echo "Wait up to 30 minutes for machine $machine to provision"
for i in {1..360}; do
    sleep 5
    state=$(sdc-getmachine ${machine} | json state)
    echo "Checking if machine $machine is provisioned (check $i of 360): $state"
    if [[ $state != 'provisioning' ]]; then
        break
    fi
done

machine_json=$(sdc-getmachine ${machine})

if [[ ${state} != 'running' ]]; then
  echo "Problem with machine ${machine}"
  exit 1
fi
SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$(echo "${machine_json}" | json ips.0)"

# Wait for the broken networking in east to settle (EASTONE-111)
# we'll wait up to 20 minutes then attempt to delete the VM, this
# used to be 10m but that wasn't even enough. :(
waited=0
while [[ ${waited} -lt 1200 && -z $(${SSH} zonename) ]]; do
  sleep 5
  waited=$((${waited} + 5))
done
if [[ ${waited} -ge 600 ]]; then
  fatal "VM ${machine} still unavailable after ${waited} seconds."
fi

# The current smartos-prepare-image script built-in to IMGAPI that are
# used for as part of image creation relies on having
# /opt/local/bin/sm-prepare-image. The old smartos/1.6.3 image that
# we currently use for some SDC images doesn't have that script. Add it.
#     01b2c898-945f-11e1-a523-af1afbe22822  smartos/1.6.3
#     fd2cc906-8938-11e3-beab-4359c665ac99  sdc-smartos/1.6.3
if [[ ${image_uuid} == "01b2c898-945f-11e1-a523-af1afbe22822"
      || ${image_uuid} == "fd2cc906-8938-11e3-beab-4359c665ac99" ]]; then
    cat tools/clean-image.sh | ${SSH} "cat > /opt/local/bin/sm-prepare-image && chmod 755 /opt/local/bin/sm-prepare-image && cat /opt/local/bin/sm-prepare-image"
fi

# "tarballs" is a list of:
#   TARBALL-ABSOLUTE-PATH-PATTERN[:SYSROOT]
# e.g.:
#   /root/joy/mountain-gorilla/bits/amon/amon-agent-*.tgz:/opt
for tb_info in ${tarballs}; do
  tb_tarball=$(echo "${tb_info}" | awk -F':' '{print $1}')
  tb_sysroot=$(echo "${tb_info}" | awk -F':' '{print $2}')
  [[ -z "${tb_sysroot}" ]] && tb_sysroot=/

  bzip=$(echo ${tb_tarball} | grep "bz2$" || true)
  if [[ -n ${bzip} ]]; then
    uncompress=bzcat
  else
    uncompress=gzcat
  fi

  echo "Copying tarball '${tb_tarball}' to zone '${uuid}'."
  if [[ ${tb_sysroot} == "/" ]]; then
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

  if [[ ${build_name} == "manatee" || ${build_name} == "sdc-manatee" || ${build_name} == "manta-manatee" ]]; then
    ${SSH} "/opt/local/bin/pkgin -y remove libuuid"
  fi

  ${SSH} "/opt/local/bin/pkgin -y in ${packages}"

  echo "Validating pkgsrc installation"
  for p in ${packages}
  do
    echo "Checking for ${p}"
    PKG_OK=$(${SSH} "/opt/local/bin/pkgin -y list | grep ${p} || true")
    if [[ -z "${PKG_OK}" ]]; then
      echo "error: pkgin install failed (${p})"
      exit 1
    fi
  done

fi

# And then turn it in to an image
image=$(sdc-createimagefrommachine --machine ${machine} --name ${image_name}-zfs --imageVersion ${image_version} --description ${image_description} --tags '{"smartdc_service": true}')
image_id=$(echo "${image}" | json -H 'id')

# Set this here so from here out fatal() can try to destroy too.
CREATED_MACHINE_IMAGE_UUID=${image_id}

# wait up to 10 minutes for image creation
waited=0
state=$(sdc-getimage ${image_id} | json 'state')
while [[ ${waited} -lt 600 ]] && [[ ${state} == "creating" || ${state} == "unactivated" ]]; do
  sleep 5
  waited=$((${waited} + 5))
  state=$(sdc-getimage ${image_id} | json 'state')
done

if [[ "$KEEP_INFRA_ON_FAILURE" == "true" || "$KEEP_INFRA_ON_FAILURE" == 1 ]]; then
    echo "$0: NOT deleting machine (KEEP_INFRA_ON_FAILURE=$KEEP_INFRA_ON_FAILURE)"
else
    sdc-deletemachine ${machine}
fi

if [[ "$(sdc-getimage ${image_id} | json 'state')" != "active" ]]; then
  echo "Error creating image"
  exit 1
fi

mantapath=/${SDC_ACCOUNT}/stor/builds/${build_name}/$(echo ${image_version} | cut -d '-' -f1,2)/${build_name}
mmkdir -p ${mantapath}

manta_bits=/tmp/manta-exported-image.$$
sdc-exportimage --mantaPath ${mantapath} ${image_id} > ${manta_bits}

output_dir=$(dirname ${output})
image_path=$(json image_path < ${manta_bits})
manifest_path=$(json manifest_path < ${manta_bits})

image_filename=$(basename ${image_path})
image_manifest_filename=$(basename ${manifest_path})

# XXX See TOOLS-359, basically binder has image_name = manta-nameservice which breaks
# backward compat when we switch to using JPC images. So I need to rename to the old
# name here.
if [[ ${image_name} != ${build_name} ]]; then
  new_image_filename=$(echo ${image_filename} | sed -e "s/^${image_name}/${build_name}/")
  new_image_manifest_filename=$(echo ${image_manifest_filename} | sed -e "s/^${image_name}/${build_name}/")
  mln ${mantapath}/${image_filename} ${mantapath}/${new_image_filename}
  mln ${mantapath}/${image_manifest_filename} ${mantapath}/${new_image_manifest_filename}
  mrm ${mantapath}/${image_filename}
  mrm ${mantapath}/${image_manifest_filename}
  image_filename=${new_image_filename}
  image_manifest_filename=${new_image_manifest_filename}
  image_path=${mantapath}/${image_filename}
  manifest_path=${mantapath}/${image_manifest_filename}

  json \
    -e "this.image_path='${image_path}'" \
    -e "this.manifest_path='${manifest_path}'" \
    < ${manta_bits} \
    > ${manta_bits}.new \
    && mv ${manta_bits}.new ${manta_bits}

fi

# XXX we download back from manta now just so other scripts work and we can publish
# to updates. Obviously it makes more sense not to do this, but there is not time to
# fix everything at once.
mget -o ${output_dir}/${image_filename} ${image_path}
[[ -f ${output_dir}/${image_filename} ]] || fatal "Failed to download ${image_filename}"
mget -o ${output_dir}/${image_manifest_filename} ${manifest_path}
[[ -f ${output_dir}/${image_manifest_filename} ]] || fatal "Failed to download ${image_manifest_filename}"

# Image Notes:
# - We need to add a requirement on the manifest for networks but CloudAPI does
#   not allow us to do that, so we have to change locally and push over the
#   original.
# - We also set the min_platform to the platform we just built the bits on,
#   not the platform we created the image on, since that's where the binary
#   dependency should come from.
# - And we remove the '-zfs' from the end of the name which we added
#   for the filename.
#   TODO: Use a basename in the 'sdc-exportimage' arg above, then change this
#   to prefix the name with "BUILD-" or similar as a sign to not use these
#   images for provisioning.
# - We set owner to the "not set" UUID (see IMGAPI-408), as is done by
#   updates.joyent.com itself on import.
# - We change the UUID because with the above changes this really is a different
#   beast. See RELENG-518.
#
cat ${output_dir}/${image_manifest_filename} \
  | json -e 'this.requirements.networks = [{name: "net0", description: "admin"}]' \
    -e "this.requirements.min_platform['7.0'] = '$(uname -v | cut -d '_' -f 2)'" \
    -e "this.owner = '00000000-0000-0000-0000-000000000000'" \
    -e "this.name = '${image_name}'" \
    -e "this.uuid = '$(uuid)'" \
  > ${output_dir}/${image_manifest_filename}.new \
  && mv ${output_dir}/${image_manifest_filename}.new ${output_dir}/${image_manifest_filename} \
  && mput -f ${output_dir}/${image_manifest_filename} ${manifest_path}

if [[ "$KEEP_INFRA_ON_FAILURE" == "true" || "$KEEP_INFRA_ON_FAILURE" == 1 ]]; then
    echo "$0: NOT deleting image (KEEP_INFRA_ON_FAILURE=$KEEP_INFRA_ON_FAILURE)"
else
    sdc-deleteimage ${image_id}
fi

cat ${manta_bits}

exit 0
