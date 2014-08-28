#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2014, Joyent, Inc.
#

set -o xtrace

DIR=$(cd `dirname $0` && pwd)
DESTDIR=/var/tmp/jenkins-setup

ssh root@emy-jenkins mkdir -p ${DESTDIR}

# copy all files in create-jenkins-slave to remote
scp -r $DIR/* root@emy-jenkins:${DESTDIR}

ssh -A root@emy-jenkins \
    "cd ${DESTDIR} && JENKINS_USER=$JENKINS_USER ./create-slave.sh $*"

