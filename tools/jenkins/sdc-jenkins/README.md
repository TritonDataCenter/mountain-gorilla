<!--
    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
-->

<!--
    Copyright (c) 2014, Joyent, Inc.
-->

# NAME

sdc-jenkins - SmartDataCentre Jenkins multi-toool

# SYNOPSIS

        sdc-jenkins [OPTIONS] COMMAND [ARGS...]
        sdc-jenkins help COMMAND

    Options:
        -c FILE, --config=FILE  Configuration JSON file. Must contain keys: user,
                                pass, host.

    Commands:
        help (?)        Help on a specific sub-command.
        nodes           Return all Jenkins nodes (workers)

# DESCRIPTION

`sdc-jenkins` is meant to be a convenient tool to maintain the SmartDataCentre
Jenkins build vms.

The utility is a patchwork abomination of different API calls (REST/ssh),
HTML scraping, and ssh'ing. You've been warned.


# INSTALLATION

    git clone git@github.com:joyent/mountain-gorilla.git
    npm install -g mountain-gorilla/tools/jenkins/sdc-jenkins

# REQUIREMENTS

- Access to the 'automation' Jenkins user
- SSH access to emy-jenkins


# COMMANDS

### nodes

Return a list of all nodes the Jenkins instance knows about. Returns the
following information on these nodes: name, ip, dc, server uuid, image uuid,
platform image, jenkins labels.

*Important Note* In order to retrieve some data you will need to have ssh
access to the given jenkins node by it's name.

For instance, if there is a Jenkins node named 'igor', in order to retrieve
certain details about igor, `sdc-jenkins` will perform `ssh igor ...`.

### create-node

Create a new Jenkins SDC node in Emeryville. 

- create directory in emy-jenkins (/var/tmp/jenkins-node-setup-XXX)
- scp create-jenkins-slave files to directory
- run `create-jenkins-slave` with parameters
- ensure machine shows up in jenkins




# OPTIONS

     -c   Specify a configuration file other than the default.


# FILES

#### ~/.sdcjenkins

Jenkins url and credentials. Must contain "user", "pass", and "host" keys.

    {
        "user": "automation",
        "pass": "PASSWORD",
        "host": "jenkins.joyent.us"
    }

# SSH Config Entries

    Host emy-jenkins
        User root
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
        Hostname 172.26.0.4



# AUTHOR

Joyent
