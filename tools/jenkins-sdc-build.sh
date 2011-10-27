#!/bin/bash
#
# This script lives at
# <mountain-gorilla.git/tools/jenkins-sdc-build.sh>.
#
# A suggested jenkins build step for an MG full SDC build.
# See the jenkins project for the *actual* current build steps:
#   https://jenkins.joyent.us/job/sdc/configure
#

set -o errexit

# Poorman's backup of last build run.
rm -rf mountain-gorilla.last
mv mountain-gorilla mountain-gorilla.last

git clone git@git.joyent.com:mountain-gorilla.git
cd mountain-gorilla

LOG=build.log
touch $LOG
exec > >(tee ${LOG}) 2>&1

date
pwd
whoami
env

echo ""
echo "#----------------------"
[[ -z "$BRANCH" ]] && BRANCH=master
./configure -b $BRANCH

echo ""
echo "#----------------------"
gmake

cp $LOG bits/
gmake upload_jenkins
