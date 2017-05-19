#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2017, Joyent, Inc.
#

#
# Validate a given Triton CLI profile for usage as the target DC (and account)
# for image creation (i.e. what `tools/prep_dataset_in_jpc.sh` does).
#
# Requirements:
# - the profile's account (typically this is Joyent_Dev for core builds) has
#   access to all origin images (per "image_uuid" entries in "targets.json.in")
# - capacity for N instances
#
# Warning: To test capacity, this *provisions a number of instances*.
#

if [[ -n "$TRACE" ]]; then
    export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -o xtrace
fi
set -o errexit
set -o pipefail

#---- globals, config

TOP=$(cd $(dirname $0)/../; pwd)

# The number of simultaneous instances we use to test the DCs capacity.
# Theoretically this means we could do N parallel image builds in this DC.
# Eventually I think this number should approach the number of images we
# build so that we could do the entire build suite in parallel.
N=5

INST_NAME_PREFIX=TMP-validate-dc-for-image-creation-$(hostname)
PROFILE=


#---- functions

function usage() {
    if [[ -n "$1" ]]; then
        echo "$(basename $0): error: $1"
        echo ""
    fi
    echo "Usage:"
    echo "    validate-dc-for-image-creation.sh [<options>] TRITON-CLI-PROFILE"
    echo ""
    echo "Options:"
    echo "    -h          Print this help and exit."
    if [[ -n "$1" ]]; then
        exit 1
    else
        exit 0
    fi
}

function fatal {
    echo "$(basename $0): error: $1"
    clean_insts
    exit 1
}

function clean_insts {
    inst_ids=$(triton -p $PROFILE ls -j \
        | json -ga -c "this.name.indexOf('$INST_NAME_PREFIX') === 0 && this.tags.pid === $$" id \
        | xargs)
    if [[ -n "$inst_ids" ]]; then
        echo ""
        echo "Cleaning up instances:"
        triton -p $PROFILE inst rm -w $inst_ids
    fi
}


#---- mainline

while getopts "h" ch; do
    case "$ch" in
    h)
        usage
        ;;
    *)
        usage "illegal option -- $OPTARG"
        ;;
    esac
done
shift $((OPTIND - 1))

PROFILE=$1
[[ -n "$PROFILE" ]] || fatal "missing TRITON-CLI-PROFILE arg"

# First clear out provisions from earlier runs.
earlier_insts=$(triton -p $PROFILE ls -j \
    | json -ga -c "this.name.indexOf('$INST_NAME_PREFIX') === 0")
if [[ -n "$earlier_insts" ]]; then
    echo "There are insts from earlier runs:"
    echo "$earlier_insts" | json -ga shortid name age | sed -e 's/^/    /'
    echo "Deleting them first:"
    triton -p $PROFILE inst rm -w $(echo "$earlier_insts" | json -ga id | xargs)
    echo ""
fi

# First test that we have access to all of the images.
images=$(bash $TOP/targets.json.in 2>/dev/null \
    | json -M -a value.image_uuid -C 'this.value.image_uuid' \
    | sort | uniq)
echo "# Validating access to origin images"
for image in $images; do
    set +o errexit
    output=$(triton -p $PROFILE image get $image 2>&1)
    retval=$?
    set -o errexit
    case "$retval" in
    0)
        echo "- Have access to image '$image'"
        ;;
    3)
        fatal "cannot find image $image with triton profile '$PROFILE'"
        ;;
    *)
        fatal "unexpected error looking up image $image: $output"
    esac
done

# Test capacity by provisioning N.
package=$(triton -p $PROFILE pkgs memory=4096 -H -o name | head -1)
[[ -n "$package" ]] || fatal "could not find a package with memory=4096"
image=$(echo "$images" | tail -1)

echo ""
echo "# Validating capacity with $N provisions"
for i in $(seq 0 $(($N - 1))); do
    triton -p $PROFILE create -n ${INST_NAME_PREFIX}-$(printf "%03d" $i) \
        -t pid=$$ \
        $image $package
done

# Wait for those provisions to complete.
# Doing a `triton ls` search immediately often misses the last "triton create".
# That sucks. Solution: retry a few times until we get the expected number.
insts=
attempts=5
while true; do
    if [[ $attempts -le 0 ]]; then
        fatal "'triton -p $PROFILE ls | ...' is not resolving to $N instances: $insts"
    fi
    attempts=$(( $attempts - 1 ))

    insts=$(triton -p $PROFILE ls -j | json -ga -c "this.tags && this.tags.pid === $$")
    if [[ $(echo "$insts" | json -gA length) == "$N" ]]; then
        break
    fi
    sleep 1
done
triton -p $PROFILE inst wait $(echo "$insts" | json -ga id | xargs)

not_running=$(triton -p $PROFILE ls -j \
    | json -ga -c "this.tags && this.tags.pid === $$ && this.state !== 'running'")
if [[ -n "$not_running" ]]; then
    echo "$(basename $0): capacity error: the following instance provisions failed:" >&2
    echo "$not_running" | json -ga id name state | sed -e 's/^/    /'
    clean_insts
    exit 1
else
    clean_insts
fi

echo ""
echo "Success. It looks like this DC (profile $PROFILE) could work."
