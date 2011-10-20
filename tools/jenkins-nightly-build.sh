# This script lives at
# <mountain-gorilla.git/tools/jenkins-nightly-build.sh>.
#
# A suggested jenkins build step for an MG nightly build.
# See the jenkins project for the *actual* current build steps:
#   https://jenkins.joyent.us/job/mg/configure
#

# Poorman's backup of last build run.
rm -rf mountain-gorilla.last
mv mountain-gorilla mountain-gorilla.last

git clone git@git.joyent.com:mountain-gorilla.git
cd mountain-gorilla

LOG=bits/build.log
mkdir -p bits
date | tee $LOG
pwd | tee -a $LOG
whoami | tee -a $LOG
env | tee -a $LOG

echo "" | tee -a $LOG
echo "#----------------------" | tee -a $LOG
./configure 2>&1 | tee -a $LOG

echo "" | tee -a $LOG
echo "#----------------------" | tee -a $LOG
gmake 2>&1 | tee -a $LOG

echo "" | tee -a $LOG
echo "#----------------------" | tee -a $LOG
gmake upload_nightly 2>&1 | tee -a $LOG
