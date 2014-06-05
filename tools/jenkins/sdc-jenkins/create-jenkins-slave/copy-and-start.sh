#!/bin/bash

set -o xtrace

DIR=$(cd `dirname $0` && pwd)
DESTDIR=/var/tmp/jenkins-setup

ssh root@emy-jenkins mkdir -p ${DESTDIR}

# copy all files in create-jenkins-slave to remote
scp -r $DIR/* root@emy-jenkins:${DESTDIR}

ssh -A root@emy-jenkins \
    "cd ${DESTDIR} && JENKINS_USER=$JENKINS_USER ./create-slave.sh $*"

