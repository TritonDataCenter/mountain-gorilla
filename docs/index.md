---
title: Mountain Gorilla
markdown2extras: tables, cuddled-lists
apisections:
---
<!--
    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
-->

<!--
    Copyright (c) 2014, Joyent, Inc.
-->

# Mountain Gorilla

A single repo to build all the parts of SDC and Manta. This is just a *build
driver* repo, all the components are still in their respective repos.
Ideally this repo isn't necessary. Instead we should move to eng.git holding
shared tooling and each repo knowing fully how to build its own release bits.


# tl;dr

A new build of a SDC or Manta component typically works like this:

    push to vmapi.git
        -> triggers a <https://jenkins.joyent.us/job/vmapi> build in Jenkins
        -> which uses **MG's `vmapi` Makefile target** to build and upload
           new vmapi bits to `/Joyent_Dev/stor/builds/vmapi`
        -> which triggers a <https://jenkins.joyent.us/job/usbheadnode> build
        -> uses MG's `usbheadnode` target to build and upload to
           `/Joyent_Dev/stor/builds/usbheadnode`

Then you can reflash your headnode using usb-headnode.git/bin/reflash, which
will grab the latest tarball from that builds area directory. Or you can
used incremental upgrade tooling (soon to be `sdcadm update vmapi`) to get
the new vmapi build.

Roughly the same process happens in appropriate dep order for all other
SDC repos. See <https://jenkins.joyent.us/>.


# Overview

SDC (SmartDataCenter) has lots of components: the platform, agents, the core
zones like vmapi & napi, components that build both like amon and ca, and the
usb-headnode.git build that puts together the final shipping products. MG is the
meta-repo that knows how to fetch and build each of them.

An MG build generally works as follows (see ./tools/jenkins-build for more
details).

1. Clone mountain-gorilla.git
2. Configure to build one component. This pre-fetches the relevant repo(s)
   and dependencies (pre-built bits, dependent SDC component bits, pkgsrc,
   images).
3. Build it.
4. Upload its built "bits" to a structured layout of bits at
   `/Joyent_Dev/stor/builds` in Manta.
5. Publish a new image to updates.joyent.com.

Using vmapi as an example (see "Prerequisites" section below):

    git clone git@github.com:joyent/mountain-gorilla.git    # 1.
    cd mountain-gorilla
    ./configure -t vmapi -b master -d Joyent_Dev         # 2.
    gmake vmapi                                          # 3.
    JOB_NAME=vmapi gmake manta_upload_jenkins            # 4.
        # New bits at /Joyent_Dev/stor/builds/vmapi/$branch-$timestamp/
    JOB_NAME=vmapi gmake jenkins_publish_image           # 5.
        # `updates-imgadm list name=vmapi` to see added VMAPI image.

The full set of targets that MG supports is both in
[targets.json](https://mo.joyent.com/mountain-gorilla/blob/master/targets.json)
(nice and clean) and
[Makefile](https://mo.joyent.com/mountain-gorilla/blob/master/Makefile)
(ugly boilerplate that should be templatized away).



# Prerequisites

There are a lot of prerequisites to build the SDC components. For all
but the platform you will need:

- a SmartOS zone of the appropriate image. At the time of writing most
  services are using 'sdc-smartos@1.6.3', and a few are using 'sdc-multiarch'.
- [python, gcc, gmake, et al from
  pkgsrc](https://mo.joyent.com/mountain-gorilla/blob/master/tools/mk-jenkins-slave/jenkins-slave-setup.user-script#L107-119)
- [an imgapi-cli.git install to get
  "updates-imgadm"](https://mo.joyent.com/mountain-gorilla/blob/master/tools/mk-jenkins-slave/jenkins-slave-setup.user-script#L122-130)

The platform build requires more setup. The best authority are the Jenkins
build slave creation scripts here:
<https://mo.joyent.com/mountain-gorilla/tree/master/tools/jenkins/sdc-jenkins>.


# Branches

99% of the time MG builds just use (and default to) the "master" branch
and that'll be all you need to know. However, MG supports building branches
other than just "master". This is used for our bi-weekly sprint release
builds:

    ./configure -t amon -b release-YYYYMMDD

However, to get a build of a feature branch, typically you only have that
branch in *your* repo and not in ancillary repos. For that reason, MG supports
the idea of a "TRY_BRANCH" to mean: "try pulling from TRY_BRANCH first, else
fallback to BRANCH". This allows you to get a feature branch build like so:

    ./configure -t cnapi -B CNAPI-1234 -b master

or using the UI in jenkins:

    # https://jenkins.joyent.us/job/cnapi/build
    BRANCH:     master
    TRY_BRANCH: CNAPI-123


# Bits directory structure

MG uploads build bits to a controlled directory structure at
`/Joyent_Dev/stor/builds` in Manta. The MG `./configure ...` step handles
downloading pre-built dependencies from this structure. The usb-headnode and
agents-installer builds also rely on this structure.

    /Joyent_Dev/stor/builds/
        $job/                   # Typically $job === MG $target name
            $branch-latest      # File with path to latest ".../$branch-$timestamp"
            ...
            $branch-$timestamp/
                $target/
                    ...the target's built bits...
                ...all dependent bits and MG configuration...

For example:

    /Joyent_Dev/stor/builds/
        amon/
            master-latest
            master-20130208T215745Z/
            ...
            master-20130226T191921Z/
                config.mk
                md5sums.txt
                amon/
                    amon-agent-master-20130226T191921Z-g7cd3e28.tgz
                    amon-pkg-master-20130226T191921Z-g7cd3e28.tar.bz2
                    amon-relay-master-20130226T191921Z-g7cd3e28.tgz
                    build.log
        usbheadnode
            master-latest
            ...
            master-20130301T004335Z/
                config.mk
                md5sums.txt
                usbheadnode/
                    boot-master-20130301T004335Z-gad6dfc4.tgz
                    coal-master-20130301T004335Z-gad6dfc4.tgz
                    usb-master-20130301T004335Z-gad6dfc4.tgz
                    build.log
                    build.spec.local

All those "extra" pieces (build log, md5sums.txt, config.mk)
are there to be able to debug and theoretically reproduce builds.
The "md5sums.txt" is used by the usb-headnode build to ensure uncorrupted
downloads.


# Jenkins

We use [Jenkins](https://jenkins.joyent.us)
([docs](https://hub.joyent.com/wiki/display/dev/Jenkins)] for continuous
builds of all of SDC. Almost every relevant git repo is setup to trigger
a build of the relevant jobs in Jenkins. See the "tl;dr" above for
what happens after a push to a repo.


## How Jenkins builds an SDC zone image

In the "Overview" above we showed the list of files generated by an amon build.
This section will explain how we go from clicking the build button in Jenkins to
having those files in Manta.

When you click the "Build" button in Jenkins, it selects a build slave from the
pool. At the time of this writing we have 2 different categories of build
slaves:

1) Platform build slaves

These live in us-east-1 in JPC under the Joyent_Dev account. They currently are
running with the image multiarch-13.3.0 and each slave is setup to run only one
job at a time. They're only used for platform and platform-debug jobs currently.

2) Zone / Other build slaves

These all currently live in us-beta-4 on the 00000000-0000-0000-0000-00259094356c
server. This server is specifically selected because we want to build on an
ancient platform. This is very important. We must build all our binary bits for
the builds on a platform that matches (or is older than) the oldest platform the
bits can be deployed on. At the time of this writing that platform matches the
one on the eu-ams-1 headnode.  All builds other than platform and platform-debug
will get sent to one of these slaves.

The determination of which slave we should send a job to happens based on
"labels". Which you can see in the job configuration and the build slave
configuration. The job will only build where the labels between the two
match.

Having selected a slave, Jenkins will send the job to the slave over the SSH
connection it holds open to its agent running in the slave zone. What gets run
is what's listed in the 'Execute Shell / Command' section of the job's
configuration.

Simplified, what most of our jobs do here is:

    git clone git@github.com:joyent/mountain-gorilla.git   # aka "MG"
    cd mountain-gorilla
    ./configure -t <job>
    gmake <job>
    gmake manta_upload_jenkins  # which runs mountain-gorilla.git/tools/mantaput-bits
    gmake jenkins_publish_image # which uploads to updates.joyent.com

The `configure -t <job>` here usually clones the repo(s) required and pulls down
dependencies from npm and Manta. This is mountain-gorilla.git/configure in case
you need to look at it.

With all the components downloaded `gmake <job>` builds all the bits that will
end up in /opt/smartdc/$app in the zone. This is the part that's critical to
be run on an ancient platform so that we know it will work on any HN/CN we want
to deploy to in JPC. This generates a tarball.

After building the tarball but still within `gmake <job>`, we call:
`./tools/prep_dataset_in_jpc.sh` which is the newest component here and the one
that includes many of the components that talk to Manta and JPC and are the
ones that fail most often. What this does (again simplified) is:

 - provision a new zone in JPC using the g3-standard-2-smartos
 - wait for the zone to be ssh-loginable (this sometimes times out at 20m)
 - use ssh to send over the tarball and unpack
 - install packages listed in mountain-gorilla.git/targets.json
 - if smartos-1.6.3: drop tools/clean-image.sh into /opt/local/bin/sm-prepare-image
   (necessary for image creation to work on the old smartos-1.6.3 image)
 - use sdc-createimagefrommachine to create image from the VM
 - wait for the state of the image to be 'active' (or fail if it goes to failed)
 - deletes the VM
 - uses sdc-exportimage to send the image to Manta
 - deletes the image
 - downloads the manifest + image from Manta to push to updates.joyent.com
 - modifies the manifest and pushes it back to Manta

This is most of the new stuff over the previous build setup in BH1 and the
primary place where problems have been occurring.


# Automatic builds (post-receive hooks)

We use Github webhooks (for Github-hosted repos) to trigger the appropriate
project build for pushes to any repository.

An example of the former is:

    [git@083a9e4b-8e3a-44f1-9e79-2056b3569e9d ~]$ cat repositories/imgapi.git/hooks/post-receive
    #!/bin/bash
    read oldrev newrev refname
    bash $HOME/bin/common-post-receive-v2 -m -d imgapi -J imgapi $oldrev $newrev $refname

It is the "-J imgapi" switch that results in jenkins being called:

    ...
    payload="{\"before\":\"$oldrev\",\"after\":\"$newrev\",\"ref\":\"$refname\"}"
    curl -g --max-time 5 -sSf -k -X POST \
        https://automation:PASS@jenkins.joyent.us/job/$JENKINS_JOB/buildWithParameters?payload="$payload"

"common-post-receive-v2" lives in "gitosis-admin.git". It currently includes
passwords so cannot be included in MG (arguably a better place).


An example of the latter is (where "PASS" is the password of the special
"github" user in our Jenkins, actually a ldap.joyent.com account):

    https://github:PASS@jenkins.joyent.us/job/platform/buildWithParameters
    SSL verification disabled (jenkins.jo uses a self-signed cert)
    Content-type: application/x-www-form-encoded (to allow jenkins to take 'payload' as a build param)

For example: <https://github.com/joyent/smartos-live/settings/hooks/286660>


The design of our post-receive hooks is that a 'payload' param with JSON
content minimally with:

    {"ref": "<pushed git ref, e.g. refs/heads/master>"}

is passed. This is a subset of the Github webhook payload. Each [jenkins job
build step](./tools/jenkins-build) is prefixed with some code that will set
`BRANCH` and `TRY_BRANCH` for that ref.  It strictly uses "BRANCH=$branch" for
release branches to ensure that a release branch is *just bits using that
release branch*. For feature branches, it uses "TRY_BRANCH=$branch
BRANCH=master" as a convenience to allow builds where only one or a subset of
involved repos have that branch.



# Versioning

No excuses. The [JEG](https://mo.joyent.com/docs/eng/master/) makes this
easy for you.

Thou shalt name thy SDC constituent build bits as follows:

    NAME-BRANCH-TIMESTAMP[-GITDESCRIBE].TGZ

Where:

- NAME is the package name, e.g. "smartlogin", "ca-pkg".
- BRANCH is the git branch, e.g. "master", "release-20110714". Use:

        BRANCH=$(shell git symbolic-ref HEAD | awk -F / '{print $$3}')  # Makefile
        BRANCH=$(git symbolic-ref HEAD | awk -F / '{print $3}')         # Bash script

- TIMESTAMP is an ISO timestamp like "20110729T063329Z". Use:

        TIMESTAMP=$(shell TZ=UTC date "+%Y%m%dT%H%M%SZ")    # Makefile
        TIMESTAMP=$(TZ=UTC date "+%Y%m%dT%H%M%SZ")          # Bash script

  Good. A timestamp is helpful (and in this position in the package name)
  because: (a) it often helps to know approx. when a package was built when
  debugging; and (b) it ensures that simple lexographical sorting of
  "NAME-BRANCH-*" packages in a directory (as done by agents-installer and
  usb-headnode) will make choosing "the latest" possible.

  Bad. A timestamp *sucks* because successive builds in a dev tree will get a
  new timestamp: defeating Makefile dependency attempts to avoid rebuilding.
  Note that the TIMESTAMP is only necessary for released/published packages,
  so for projects that care (e.g. ca), the TIMESTAMP can just be added for
  release.

- GITDESCRIBE gives the git sha for the repo and whether the repo was dirty
  (had local changes) when it was built, e.g. "gfa1afe1-dirty", "gbadf00d".
  Use:

        # Need GNU awk for multi-char arg to "-F".
        AWK=$((which gawk 2>/dev/null | grep -v "^no ") || which awk)
        # In Bash:
        GITDESCRIBE=g$(git describe --all --long --dirty | ${AWK} -F'-g' '{print $NF}')
        # In a Makefile:
        GITDESCRIBE=g$(shell git describe --all --long --dirty | $(AWK) -F'-g' '{print $$NF}')

  Notes: "--all" allows this to work on a repo with no tags. "--long"
  ensures we always get the "sha" part even if on a tag. We strip off the
  head/tag part because we don't reliably use release tags in all our
  repos, so the results can be misleading in package names. E.g., this
  was the smartlogin package for the Lime release:

        smartlogin-release-20110714-20110714T170222Z-20110414-2-g07e9e4f.tgz

  The "20110414" there is an old old tag because tags aren't being added
  to smart-login.git anymore.

  "GITDESCRIBE" is *optional*. However, the only reason I currently see to
  exclude it is if the downstream user of the package cannot handle it in
  the package name. The "--dirty" flag is *optional* (though strongly
  suggested) to allow repos to deal with possibly intractable issues (e.g. a
  git submodule that has local changes as part of the build that can't be
  resolved, at least not resolved quickly).

- TGZ is a catch-all for whatever the package format is. E.g.: ".tgz",
  ".sh" (shar), ".md5sum", ".tar.bz2".


# HOWTO: Cut an SDC bi-weekly sprint release

The SmartDataCenter product currently does bi-weekly sprint release builds.
This involves branching/tagging all relevant repositories, building them
all, and "releasing/archiving" versions in our Jira issue tracker. This
section documents how to perform a release.

1. Branch/tag all the repos.
   Run the following on a machine with good connectivity (you'll be cloning
   all SDC's repos).

        git clone git@github.com:joyent/mountain-gorilla.git
        cd mountain-gorilla
        RELDATE=$(date +%Y%m%d)
        ./tools/check-repos-for-release -h    # grok what this does
        ./tools/check-repos-for-release -a $RELDATE

   If running this fails, it is safe to re-run to pick up where it left off.

   This will trigger builds with "BRANCH=release-$RELDATE" for all components.
   You can watch the build queue pile up at <https://jenkins.joyent.us/>.

   *Release branch* builds are strict (see the section above on automatic
   builds) in that they will fail if dependencies do not yet have a build for
   that branch. Therefore we expect some builds (e.g. usbheadnode) to fail
   until all components, in particular the slower "platform" build, have had
   time to complete.

2. Babysit builds in Jenkins. Currently our builds are not as reliable as
   we'd like, so failures do occur. The best strategy is probably:

    - Allow an initial pass of many of the builds to complete.
    - Watch the agentsshar build (https://jenkins.joyent.us/job/agentsshar/)
      (with BRANCH=release-$RELDATE) for failures. Check its console log
      to see if failures are due to dependent agent builds not having
      completed. If so, manually restart those builds.
    - Watch the usbheadnode build (https://jenkins.joyent.us/job/usbheadnode/)
      (with BRANCH=release-$RELDATE) for failures. Check its console log
      to see if failures are due to dependent agent builds not having
      completed. If so, manually restart those builds.
    - Use `./tools/ls-missing-release-builds release-YYYYMMDD` to list
      builds that are missing for this release. It provides URLs to the
      Jenkins page to start the appropriate build.

    That this babysitting is required is lame. We should attempt to fix
    this (TODO). I'm [Trent] open to suggestions. A start would be improvements
    to the `sdc-jenkins` tool to ensure that current Jenkins job definitions
    have the proper dependencies. For example, the 'amon' build currently
    triggers builds a many jobs that use amon-agent, but not all of them.
    Of latest EASTONE-111 is a killer: it stalls a build for 20 minutes, then
    often fails.

3. "Release" this sprint version in our Jira projects:

        cd .../mountain-gorilla/tools/jira
        ./releaseversion.sh 'YYYY-MM-DD NAME'
        # E.g.: ./releaseversion.sh '2014-07-10 Skynet'

4. "Archive" the *previous* sprint version in our Jira projects:

        cd .../mountain-gorilla/tools/jira
        ./archiveversion.sh 'YYYY-MM-DD NAME'
        # E.g.: ./archiveversion.sh '2014-06-26 Robocop'

5. When branches are cut, tell Keith that he can do the SmartOS build.
   SmartOS does bi-weekly releases with the same timeline as SDC.

6. (Eventually, the plan is to) Publish these release bits to the "staging"
   channel of updates.joyent.com. Then, upgrade staging-1/2/3 to the latest
   in the "staging" channel.


There are some common failure pathologies:

- "error: unexpected ref 'refs/tags/20140703': is not 'refs/heads'"
  The webhook used on github-hosted repos will POST for both the *tag* push
  and the *branch* push. We only build for branch pushes (i.e. where "ref"
  startswith "refs/heads/"). IOW, this can be ignored.

- "Read from remote host github.com: Connection timed out"
  We hit git repos hard when everything starts building. Github often doesn't
  like this. Short of us moving to not using github repos directly in our
  "package.json" files, I don't know of a fix here.



# HOWTO: Troubleshooting Jenkins build failures

The first step in debugging build failures is to ensure that you understand how
builds work. See the previous section for details. With that understanding in
hand you should start looking at the "Console Output" in Jenkins for the failed
build. Usually the end of the log will tell you why the build failed if you
follow along in the code.

The main sources of problems have been in the tools/prep_dataset_in_jpc.sh
step from MG. This primarily has failed when provisioning to JPC or when talking
to manta.



# HOWTO: Add a new project/repo/job to MG

*(Warning: This section is a little out of date.)*

Add it as a top-lever property in targets.json, as an object with properties
"repos" and "deps" minimally, both are arrays.

- "repos" is an array of objects, with the property "url", pointing at a git url
- "deps" is an array of strings, where the string is another top-level target in targets.json

For example:

    {
      ...
      mynewrepo: {
        "repos": [ {"url": "git://github.com/joyent/mynewrepo.git" } ],
        "deps": [ "platform" ]
      },
      ...
    }

Then you'll add the target to Makefile. MG's configure will automatically
populate some Makefile values for you, noteably: xxx_BRANCH , xxx_SHA, but
you will need to fill in the build stamp yourself. Configure will also git
checkout your repo in build/

    #---- MYNEWREPO

    _mynewrepo_stamp=$(MYNEWREPO_BRANCH)-$(TIMESTAMP)-g$(MYNEWREPO_SHA)
    MYNEWREPO_BITS=$(BITS_DIR)/mynewrepo/mynewrepo-pkg-$(_mynewrepo_stamp).tar.bz2

    .PHONY: mynewrepo
    mynewrepo: $(MYNEWREPO_BITS)

    $(mynewrepo_BITS): build/mynewrepo
      mkdir -p $(BITS_DIR)
      (cd build/mynewrepo && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake pkg release publish)
      @echo "# Created mynewrepo bits (time `date -u +%Y%m%dT%H%M%SZ`):"
      @ls -1 $(MYNEWREPO_BITS)
      @echo ""

    clean_mynewrepo:
      rm -rf $(BITS_DIR)/mynewrepo
      (cd build/mynewrepo && gmake clean)

if you wish to build an application zone image, the process is roughly
similar except you will need to add the "appliance":"true" property, the
"pkgsrc" property and "dataset_uuid"

    {
      ...
      "mynewrepo": {
        "repos" : [ {"url":"git://github.com/joyent/mynewrepo.git"} ],
        "appliance": "true",
        "dataset_uuid": "01b2c898-945f-11e1-a523-af1afbe22822",
        "pkgsrc": [
          "sun-jre6-6.0.26",
          "zookeeper-client-3.4.3",
          "zookeeper-server-3.4.3"
        ],
        deps: []
      },
      ...
    }

where dataset\_uuid is the uuid of the source image you wish to build off
pkgsrc is an array of strings of package names to install.

Your Makefile target will look as above, with the addition of the xxx\_dataset target:


    ...
    MYNEWREPO_DATASET=$(BITS_DIR)/mynewrepo/mynewrepo-zfs-$(_mynewrepo_stamp).zfs.bz2

    .PHONY: mynewrepo_dataset

    mynewrepo_dataset: $(MYNEWREPO_DATASET)

    $(MYNEWREPO_DATASET): $(MYNEWREPO_BITS)
            @echo "# Build mynewrepo dataset: branch $(MYNEWREPO_BRANCH), sha $(MYNEWREPO_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
            ./tools/prep_dataset.sh -t $(MYNEWREPO_BITS) -o $(MYNEWREPO_DATASET) -p $(MYNEWREPO_PKGSRC)
            @echo "# Created mynewrepo dataset (time `date -u +%Y%m%dT%H%M%SZ`):"
            @ls -1 $(MYNEWREPO_DATASET)
            @echo ""
    ...

prep\_dataset.sh is a script that generates images out of tarballs and lists
of packages.

It takes arguments of the form -t <tarball> where <tarball> is a .tar.gz
file, containing a directory "root", which is unpacked to / -p "list of
pkgsrc packages" where list of pkgsrc packages is a list of the pkgsrc
packages to be installed in the zone.

Configure will populate xxx\_DATASET and xxx\_PKGSRC based on targets.json.

Additionally, you can set the dsadm URN for the target by adding the "urn"
and "version" properties to targets.json, as properties of the target you
wish to manipulate. These will show up as urn:version ( sdc:sdc:mynewrepo:0.1
for instance ). To use them, configure will populate xxx\_URN and xxx\_VERSION
for you in the Makefile.

Note that these images can only be provisioned with the joyent-minimal brand.
If one is provisioned with the joyent brand, that zone's networking may not be
working.  Normally, the networking setup is done through zoneinit, but since
that script has already run and had its effects undone (as part of the MG
build), there's no mechanism to automatically bring that zone's VNIC up.  You
can recover by manually enabling network/physical:default, but you should just
be provisioning with the joyent-minimal brand instead.  See RELENG-337 for
details.
