#!/bin/bash
#
# This script lives at <mountain-gorilla.git/tools/jenkins-build-step.sh>.
# A suggested jenkins build step for an MG component or full SDC build.
#
# See the appropriate jenkins job for the *actual* current build steps:
#   https://jenkins.joyent.us/job/$JOB/configure
#

set -o errexit
unset LD_LIBRARY_PATH   # ensure don't get Java's libs (see OS-703)


echo ""
echo "#----------------------"
start_time=$(date +%s)
last_time=${start_time}

rm -rf MG.last
# Poorman's backup of last build run.
mkdir -p MG && mv MG MG.last
rm -rf MG
git clone git@git.joyent.com:mountain-gorilla.git MG
cd MG

now_time=$(date +%s)
elapsed=$((${now_time} - ${last_time}))
last_time=${now_time}
echo "TIME: clone MG took ${elapsed} seconds"

LOG=build.log
touch $LOG
exec > >(tee ${LOG}) 2>&1



echo ""
echo "#---------------------- env"

date
pwd
whoami
env



echo ""
echo "#---------------------- configure"

[[ -z "$BRANCH" ]] && BRANCH=master
# Note the "-c" to use a cache dir one up, i.e. shared between builds of this job.
CACHE_DIR=$(cd ../; pwd)/cache
if [[ "$CLEAN_CACHE" == "true" ]]; then
    rm -rf $CACHE_DIR
fi
if [[ "$JOB_NAME" == "sdc" ]]; then
    TRACE=1 ./configure -c "$CACHE_DIR" -b "$BRANCH" -B "$TRY_BRANCH"
else
    TRACE=1 ./configure -t $JOB_NAME -c "$CACHE_DIR" -b "$BRANCH" -B "$TRY_BRANCH"
fi

now_time=$(date +%s)
elapsed=$((${now_time} - ${last_time}))
last_time=${now_time}
echo "TIME: MG configure took ${elapsed} seconds"



echo ""
echo "#---------------------- make"

if [[ "$JOB_NAME" == "sdc" ]]; then
    gmake
else
    gmake $JOB_NAME
fi

now_time=$(date +%s)
elapsed=$((${now_time} - ${last_time}))
last_time=${now_time}
echo "TIME: build took ${elapsed} seconds"



echo ""
echo "#---------------------- upload"

cp $LOG bits/$JOB_NAME/
gmake upload_jenkins

now_time=$(date +%s)
elapsed=$((${now_time} - ${last_time}))
last_time=${now_time}
echo "TIME: upload took ${elapsed} seconds"
