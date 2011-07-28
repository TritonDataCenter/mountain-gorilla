# Moutain Gorilla

Trent's stab at a single repo to build SDC.


# Build

What if a (full) build went like this:

- take a source "bits" directory or URL
- download all of that to a "deps" or "bits" or "cache" subdir
- clone (or update) all the source directories
    cache/repos/$repo    # pristine clones, for faster clean recloning
- kick off each of the steps (with appropriate order), publishing
  resultant bits to the same local "bits" dir
- 'make upload' to upload bits to the release bits dir ... including logs


platform
hvm-platform:
    echo "* * *"
    echo "* Josh handles this build and uploads a release.
    echo "* * *"
smartlogin
ca
agents
agents-shar   # or "agents-installer"

usb-headnode: coal usb upgrade boot

DEPS_DIR=https://216.57.203.66:444/coal/releases/2011-07-14/deps/ make usb-headnode
RELEASE_DIR=...


- build to "build/"
- add a file to "build/versions/$name.versions" for each component



## set the version to build

    ./configure master   # gets latest revs from master
    ./configure release-20110714   # add "lime" alias for this

How would that work for smartlogin only.

    $ ./configure release-20110714
    Fetching smartlogin repo cache (cache/repos/smart-login).
        # recursive update of submodules as well
    Latest revision on 'release-20110714' branch is 'cafebabe'.
    Using smartlogin 'release-20110714-cafebabe'.
    Generated 'config.mak'.
    $ cat config.mak
    SMARTLOGIN_VERSION="release-20110714-cafebabe"
    # or
    SMARTLOGIN_BRANCH="release-20110714"
    SMARTLOGIN_SHA="cafebabe"
    # or ... something else, having both is redundant.


Offline (i.e. just use what is local already):

    $ ./configure -o|--offline release-20110714
    Not updating smartlogin repo (in cache/repos/smart-login): offline mode.
    Latest revision on 'release-20110714' branch is 'cafebabe'.
    Using smartlogin 'release-20110714-cafebabe'.
    Generated 'config.mak'.

Now all 'make' steps will use "config.mak". Get a clean source tree
(building a source package if necessary):

    $ make src_smartlogin
    # if bits/src/smartlogin-src-cafebabe.tgz doesn't exist:
    Creating smartlogin source package (bits/src/smartlogin-src-cafebabe.tgz).
        rm -rf src/smartlogin
        git clone cache/repos/smart-login src/smartlogin
        (cd src/smartlogin && git checkout cafebabe && git submodule update --init --recursive)
        (cd src && tar czf smartlogin-src-cafebabe.tgz smartlogin)
    Extracting "bits/src/smartlogin-src-cafebabe.tgz" to "build/smartlogin".

(Optionally: Check for build system deps:

    $ make builddeps_smartlogin
    (cd build/smartlogin && make builddeps)

This should fail if there are deficiencies in the build system/environment.
Why separate this instead of just failing on build? Without clear good
reason, then don't bother. Reasons:

1. To allow quicker recognition that the build is going to fail,
   rather than building almost everything then failing at the end.
2. Explicit listing of details of deps for the log files. Versions of tools,
   environment settings, etc.
)


Check that src/smartlogin looks like what we expect (i.e. it hasn't been
mucked with):

    $ make checksrc_smartlogin
    TIMESTAMP=$(shell TZ=UTC date "+%Y%m%dT%H%M%SZ")  # this is at top of Makefile
    SMARTLOGIN_BUILDSTAMP=$SMARTLOGIN_BRANCH-$TIMESTAMP-$SMARTLOGIN_SHA
    (cd build/smartlogin \
        && echo "$(git describe --contains --all HEAD | cut -d~ -f1)-$TIMESAMP-$(git describe --long --dirty | cut -d- -f3,4) \
        > ../smartlogin.buildstamp
    [[ $(cat build/smartlogin.buildstamp) != "$SMARTLOGIN_BUILDSTAMP" ]] \
        && fail "unexpected smartlogin sources in 'build/smartlogin': ..."


Build:

    $ make smartlogin
    #TODO: pass in versions path and expect it to append dep versions? Feel this out.
    #TODO: perhaps add MG_ prefix to envvars if Makefiles need to know.
    (cd build/smartlogin && BUILDSTAMP=$(SMARTLOGIN_BUILDSTAMP) BITS_DIR=$ROOT/bits gmake clean lint all)
    # update smartlogin Makefile: expect creation of build/smartlogin/smartlogin-$BUILDSTAMP.tgz
    cp !$ bits/smartlogin/   # <--- this could be responsibility of smartlogin/Makefile

Summary:

    configure -> decides which version of smartlogin (and its deps)
    src_smartlogin -> gets clean sources (including submodules) for smartlogin at given version
    checksrc_smartlogin -> ensures this *is* a clean source tree
    builddeps_smartlogin -> logs build dump info and bails early if expected failure
    smartlogin -> builds, using only BITS_DIR for dependencies and puts products in BITS_DIR
    

TODOs:
- How to specify a particular rev with "./configure". Want to be able to
  pass in a "build.spec" (see 'make buildspec' below).
- How to specify that we don't want to rebuild a subcomponent? E.g. just
  rebuild usb-headnode, but not platform? Or *should* that be allowed...
  if deps are correct against source tree version. You *can* do it manually
  via the build targets.
- "make dumpenv" is done at the start of a full build here to dump environment
  details for the build log.
- Log (log all this to a log file or files). High prio.
- Dirty support (ability to do a build with local changes). Low prio.


# bigger picture

    ./configure BRANCH
    make
        dumpenv
        src
            src_smartlogin
        checksrc
            checksrc_smartlogin
        builddeps
            builddeps_smartlogin
        build
            smartlogin
    
If, say, just rebuilding usb-headnode, then the above is wasteful... e.g.
getting fresh sources for platform. So perhaps more like this:


all: $COAL $USB $UPGRADE $BOOT

deps_usbheadnode: XXX
$COAL: src_usbheadnode deps_usbheadnode
    (cd build/usb-headnode && make coal)
$USB: src_usbheadnode
    (cd build/usb-headnode && make usb)


# next steps (START HERE)

- extend 'smartlogin' example to ca, agents and agents-installer
  to feel it out
- implement that (should be fast to build)
- then usb-headnode: hardcoding a platform and platform-HVM version
  And how can this fit in with existing usb-headnode/build.spec.
- add platform
- how can platform-HVM fit in? it needs to be built on separate OS
- usb-headnode: pulling in and caching datasets in "bits" dir
- npm: run an npm proxy? and set npm_config_... for this. Would that work?



# scrapyard
    
    # -> build-$CONFIGNAME-$TIMESTAMP.spec from the build/versions state.
    #    Or perhaps this is already the output of "configure" above? I.e.
    #    'make smartlogin' should bail if the source tree doesn't look as
    #    requested in configure's build.spec/config.mak. This is better.
    buildspec
    



# notes from Lime RC builds

- platform build used "master" branch of illumos-extra (on github)
  for a *release* (Lime) build. That needs to be a tag... or we
  start doing release branches on illumos-extra.

- bamboo build agents (i.e. build slave boxes):
    - "illumos": bh1-autobuild
      https://devhub.joyent.com/bamboo/admin/agent/viewAgent.action?agentId=9076737
      This is the only one that can build "platform" (i.e. illumos-live.git)
    - "headnode": bamboo-ubuntu.joyent.us
      "0 / 0 Successful"
      TODO: kill it
    - "bldzone2": bldzone2 (10.99.99.101)
      https://devhub.joyent.com/bamboo/admin/agent/viewAgent.action?agentId=12779522
    - Josh: bh1-build shall die (devs move to bh1-build2 and build in a
      zone on there) and be repurposed as bh1-autobuild2. A zone could be
      added on here that can be a build slave to use.
- Lime RC:
    https://devhub.joyent.com/bamboo/browse/REL-SMARTLOGIN-14
        bamboo@bh1-autobuild:/rpool/data/coal/live_147/agents/smartlogin/release-20110714/smartlogin-release-20110714-20110721T220018Z-20110414-2-g07e9e4f.tgz
    https://devhub.joyent.com/bamboo/browse/REL-CA-26
        scp build/pkg/cabase.tar.gz bamboo@10.2.0.190:/rpool/data/coal/live_147/agents/cloud_analytics/release-20110714//cabase-release-20110714-20110721T220224Z-20110714.tgz
        scp build/pkg/cainstsvc.tar.gz bamboo@10.2.0.190:/rpool/data/coal/live_147/agents/cloud_analytics/release-20110714//cainstsvc-release-20110714-20110721T220224Z-20110714.tgz
        manual:
            - cp these to the "releases/.../deps" dir
            - as per john's email, run 'gmake release'
            - cp 'ca-pkg-...' tarball to 'releases/.../deps' dir
    https://devhub.joyent.com/bamboo/browse/REL-AGENTSREL-28
        /rpool/data/coal/releases/2011-07-14/deps//zonetracker/release-20110714/zonetracker-release-20110714-20110721T220309Z.tgz
        /rpool/data/coal/releases/2011-07-14/deps//provisioner/release-20110714/provisioner-release-20110714-20110721T220309Z.tgz
        /rpool/data/coal/releases/2011-07-14/deps//provisioner-v2/release-20110714/provisioner-v2-release-20110714-20110721T220309Z.tgz
        /rpool/data/coal/releases/2011-07-14/deps//zonetracker-v2/release-20110714/zonetracker-v2-release-20110714-20110721T220309Z.tgz
        /rpool/data/coal/releases/2011-07-14/deps//atropos/release-20110714/atropos-release-20110714-20110721T220309Z.tgz
        /rpool/data/coal/releases/2011-07-14/deps//dataset_manager/release-20110714/dataset_manager-release-20110714-20110721T220309Z.tgz
        /rpool/data/coal/releases/2011-07-14/deps//heartbeater/release-20110714/heartbeater-release-20110714-20110721T220309Z.tgz
    https://devhub.joyent.com/bamboo/browse/REL-AGENTS-39
        - /bin/bash ./build_scripts -l /rpool/data/coal/releases/2011-07-14/deps/
          env: JOBS=12 COAL_PUBLISH=1
        - TODO: want 'set -x' in this
        - using "latest.tgz" symlinks which I don't like, e.g.
          /rpool/data/coal/releases/2011-07-14/deps/atropos/release-20110714/latest.tgz
        - agents-installer/build.spec needs to be updated for a release branch
          TODO: :(
        - TODO: limitation: the "deps" dir from which to get packages has to be
          local (just using 'cp')
        - don't like the versions of the agents aren't in here. Tracking is harder:
            ./shar: Saving agents/atropos.tgz (binary)
            ./shar: Saving agents/smartlogin-release-20110714-20110714T170222Z-20110414-2-g07e9e4f.tgz (binary)
            ./shar: Saving agents/dataset_manager.tgz (binary)
            ./shar: Saving agents/heartbeater.tgz (binary)
            ./shar: Saving agents/cabase-release-20110714-20110714T175258Z-20110714.tgz (binary)
            ./shar: Saving agents/zonetracker-v2.tgz (binary)
            ./shar: Saving agents/zonetracker.tgz (binary)
            ./shar: Saving agents/cainstsvc-release-20110714-20110714T175258Z-20110714.tgz (binary)
            ./shar: Saving agents/provisioner-v2.tgz (binary)
            ./shar: Saving agents/install.sh (text)
        /rpool/data/coal/live_147/ur-scripts/agents-release-20110714-20110722T173311Z.md5sum
        /rpool/data/coal/live_147/ur-scripts/agents-release-20110714-20110722T173311Z.sh
        - manually cp those to 'releases/.../deps/ur-scripts' dir
    https://devhub.joyent.com/bamboo/browse/REL-PLATFORM-40
        - /home/bamboo/bin/bamboo-builders/illumos-release.sh on bh1-autobuild is the build step (TODO: ack!)
        /rpool/data/coal/releases/2011-07-14/deps/platform-20110721T221614Z.tgz
    https://devhub.joyent.com/bamboo/browse/REL-APPZONE-41
        - /home/bamboo/bin/bamboo-builders/build-app.sh (TODO: ack!)
        bits???  who cares. not used.
    JOSH: will add HVM platform builds to the deps dir (built on bh1-linux)
    https://devhub.joyent.com/bamboo/browse/REL-SDC6-119
        - /home/jill/bin/bamboo-builders/coal.sh (TODO: ack!)
            env: UPLOAD=true TAR=true VMWARE=false
            env: UPLOAD=true UPGRADE=true VMWARE=false
            env: UPLOAD=true USB=true VMWARE=false RELEASE=true
            env: UPLOAD=true RELEASE=true
        - manual: copy those four files from /rpool/data/coal/live_147/coal/
          to the releases dir

- think about how the build could be automated more:
    - package name: smartlogin-release-20110714-20110714T170222Z-20110414-2-g07e9e4f.tgz
      The "git describe" part: annoying to have tag in there given that
      smartlogin repo isn't doing reasonable tags:
        $ git describe --long | cut -d- -f3
        g5f29ded
      Ditto for CA bits.
    - The smartlogin's package task should perhaps create a reasonable name.
      I.e. it should get its versioning act together.
    - smartlogin: why separate build.sh and publish.sh for bamboo? Historic cruft
      for bamboo "artifacts"? If so, drop the separation. Complexity.
    - "Agents" repo setup is pros/cons:
        - Agents pro: release dir is passed in (it shouldn't be hard coded)
        - Agents con: there isn't a separate "bamboo/build.sh" so it
          could accidentally be broken.
        - overall: Agents build.sh iface is better than the hacks for the
          others. Perhaps a "bamboo-build" script in each repo with a
          standardized interface.
        - bits filenames: add the git sha suffix a la the others


# old notes from John

- john wants: PUBLISH_LOCATION envvar and/or "-l PATH" arg for the various
  sdc bits. Has it for agents.git
- john also mentioned the same is wanted for illumos-live:
  https://hub.joyent.com/wiki/display/dev/Building+the+147+live+image
  I've started a build on bh1-build `ssh -A trent@10.2.0.191`

