# Moutain Gorilla

A single repo to build SDC. This is just a *driver* repo, all the components
are still in their existing separate repos.


# Usage

If you'll actually be building, see "Prerequisites" section below first.

    git clone git@git.joyent.com:mountain-gorilla.git
    cd mountain-gorilla.git
    ./configure -h
    ./configure [OPTIONS...]    # generates bits/config.mk with all build config
    make                        # builds entire stack from source

The "bits/config.mk" contains all config information necessary to fully
reproduce the build. There will be configure options to use some prebuilt
bits (e.g. a prebuilt platform) -- so to fully reproduce in this scenario
those pre-built bits will need to be available. The "configure" step might
take a while because it needs to get/update all of the source repositories to
get revision information (the git shas to be built are part of the created
"config.mk" file)

The end result is a "bits" directory with all the built components. Primarily
this includes the release bits in "bits/usbheadnode": "coal-$VERSION.tgz",
"usb-$VERSION.tgz", "boot-$VERSION.tgz" and "upgrade-$VERSION.tgz". However,
also included are all the constituent built bits: agents, platform, ca, etc.

The above configuration is to build the world from scratch. That
takes around 2 hours. You can also build just the individual pieces, e.g.
cloudapi:

    ./configure -t cloudapi
    make cloudapi

Likewise for any target (a key in "targets.json").

There is also a special target to build everything from scratch *except* the
platform (because the platform is by far the longest part of the build):

    ./configure -t all-except-platform
    make all-except-platform


# Prerequisites

MG should be fully buildable on a SmartOS zone. Here are notes on how
to create one and set it up for building MG. Some issues include having
multiple gcc's and some specific node's. Specific paths are chosen
for these and presumed by MG's Makefile.

First, create zone. For example:

    # Let's create a zone on bh1-build0 (dev machine in the Bellingham
    # lab, <https://hub.joyent.com/wiki/display/dev/Development+Lab>).
    ssh bh1-build0
    /opt/custom/create-zone.sh trent   # Pick a different name for yourself :)
    #  Or use Josh's new "/opt/custom/create-zone-16.sh" to use the newer
    #  smartos-1.6.1 dataset. It is the future.
    # wait 30s or so it to setup.

    zlogin trent
    echo "Your IP is $(ifconfig -a | grep 'inet 10\.' | cut -d' ' -f 2)"
    # --> "Your IP is 10.2.0.145"

    vi /root/.ssh/authorized_keys   # Add your key
    chmod 600 /root/.ssh/authorized_keys
    chmod 700 /root/.ssh

Re-login and setup environment:

    ssh -A root@10.2.0.145
    curl -k -O https://download.joyent.com/pub/build/setup-build-zone
    curl -k -O https://download.joyent.com/pub/build/fake-subset.tbz2
    chmod 755 setup-build-zone
    ./setup-build-zone

    # Note: After any reboot you'll need to run:
    #   ./setup-build-zone -e
    # On the Jenkins build slaves a transient SMF service is setup for
    # this. See <https://hub.joyent.com/wiki/display/dev/Jenkins#Jenkins-JenkinsSetupDetails>

    # Having git "core.autocrlf=input" will cause spurious dirty files in
    # some of our repos. Don't go there.
    [[ `git config core.autocrlf` == "input" ]] \
        && echo "* * * Warning: remove 'autocrlf=input' from your ~/.gitconfig"

    # To build CA you need some more stuff (the authority here on needed
    # packages is <https://mo.joyent.com/cloud-analytics/blob/master/tools/ca-headnode-setup#L274>
    # TODO: Are these all still necessary?
    pkgin -y in gcc-compiler gcc-runtime gcc-tools cscope gmake \
        scmgit python24 python26 png GeoIP GeoLiteCity ghostscript

    # Note: This "./configure" step is necessary to setup your system.
    # TODO: Why is this necessary?
    # TODO: Pull out the requisite system setup steps. Shouldn't really
    #       be tucked away in illumos-live.git and configure.joyent.
    git clone git@git.joyent.com:illumos-live.git
    cd illumos-live
    curl -k -O https://joydev:leichiB8eeQu@216.57.203.66/illumos/configure.joyent
    GIT_SSL_NO_VERIFY=true ./configure

Next, ensure that you do NOT have the 'nodejs' and 'npm' packages from
pkgsrc installed:

    pkgin ls | grep '\(nodejs\|npm\)' && pkgin -y rm npm-0.2.18 nodejs-0.4.2

Next, setup a few required versions of node and npm. (See RELENG-283 for
efforts to remove this requirement.)

    # node 0.6.12
    mkdir -p /opt/node
    cd /opt/node
    git clone https://github.com/joyent/node.git src
    cd src
    git checkout v0.6.12
    ./configure --prefix=/opt/node/0.6.12 && make && make install

    # node 0.4.9
    make distclean
    git checkout v0.4.9
    ./configure --prefix=/opt/node/0.4.9 && make && make install
    (cd /opt/node && ln -s 0.4.9 0.4)

    # npm 1.0
    cd /var/tmp
    mkdir -p /opt/npm
    (export PATH=/opt/node/0.4/bin:$PATH \
        && curl http://npmjs.org/install.sh | npm_config_prefix=/opt/npm/1.0 npm_config_tar=gtar sh)


Ensure node 0.6 is the first `node` on your PATH, as required by the MG
build. For example (but you don't have to use this node):

    export PATH=/opt/node/0.6.12/bin:$PATH

If your build zone in inside BH1, then you must add the following to "/etc/inet/hosts"
for the "tools/upload-bits" script (used by all of the 'upload_' targets) to work:

    10.2.0.190      stuff.joyent.us

You should now be able to build mountain-gorilla (MG): i.e. all of SDC.
Let's try that:

    git clone git@git.joyent.com:mountain-gorilla.git
    cd mountain-gorilla
    time (./configure && gmake) >build.log 2>&1 &; tail -f build.log


# Package Versioning

Thou shalt name thy SDC constituent build bits as follows:

    NAME-BRANCH-TIMESTAMP[-GITDESCRIBE].TGZ

where:

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


## Exceptions

The agents shar is a subtle exception:

    agents-release-20110714-20110726T230725Z.sh

That "release-20110714" really refers to the branch used to build the
agent packages included in the shar. For typical release builds, however,
the "agents-installer.git" repo is always also on a branch of the same
name so there shouldn't be a mismatch.



## Suggested Versioning Usage

It is suggested that the SDC repos use something like this at the top of
their Makefile to handle package naming (using the Joyent Engineering
Guidelines, eng.git):

    include ./Makefile.defs   # provides "STAMP"
    ...
    PKG_NAME=$(NAME)-$(STAMP).tgz


Notes:
- This gives the option of the TIMESTAMP being passed in. This is important
  to allow an external driver -- e.g., moutain-gorilla, bamboo, CI -- to
  predict the expected output files, and hence be able to raise errors if
  expected files are not generated.
- Consistency here will help avoid confusion, and surprises in things like
  subtle differences in `awk` on Mac vs. SmartOS, various options to
  `git describe`.
