# Moutain Gorilla

A single repo to build SDC. This is just a *driver* repo, all the components
are still in their existing separate repos.


# Motivation

It is too hard to build SDC. Single Person of Failure. Everyone should be able
to build it... and not just a local usb-headnode build (which *is* easy). The
primary focus is making reliable and reproducible SDC builds for official
release builds and CI. However, eventually this should help enable any Joyent
devs to be able to build the entire stack.


# Usage

If you'll actually be building, see "Prerequisites" section below first.

    git clone git@git.joyent.com:mountain-gorilla.git
    cd mountain-gorilla.git
    ./configure --help
    ./configure [OPTIONS...]    # generates config.mk with all build config
    make                        # builds entire stack from source

The "config.mk" contains all config information necessary to fully reproduce
the build. There will be configure options to use some prebuilt
bits (e.g. a prebuilt platform) -- so to fully reproduce in this scenario
those pre-built bits will need to be available. The "configure" step might
take a while because it needs to get/update all (most?) of the source
repositories to get revision information (the git shas to be built are part
of the created "config.mk" file)

The end result is a "bits" directory (currently at "./bits") with all the
built components. Primarily this includes the release bits:
"coal-$VERSION.tgz", "usb-$VERSION.tgz", "boot-$VERSION.tgz" and
"upgrade-$VERSION.tgz". However, also included are all the constituent
built bits: agents, platform, ca, etc.


# Current Status

Basically working. Isn't yet being used as the replacement for Bamboo for SDC
release builds. See [RELENG](https://devhub.joyent.com/jira/browse/RELENG)
for current issues.


# Prerequisites

MG should be fully buildable on a SmartOS zone. Here are notes on how
to create one and set it up for building MG. Some issues include having
multiple gcc's and multiple npm versions. Specific paths are chosen for
these and presumed by MG's Makefile. There are multiple ways to skin this
cat -- improvements are welcome.

    # Let's create a zone on bh1-build0 (dev machine in the Bellingham
    # lab, <https://hub.joyent.com/wiki/display/dev/Development+Lab>).
    ssh bh1-build0
    /opt/custom/create-zone.sh trent   # Pick a different name for yourself :)
    # wait 30s or so it to setup.
    
    zlogin trent
    echo "Your IP is $(ifconfig -a | grep 'inet 10\.' | cut -d' ' -f 2)"
    # --> "Your IP is 10.2.0.145"
    
    vi /root/.ssh/authorized_keys   # Add your key
    chmod 600 /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    
    # Re-login and setup environment:
    ssh -A root@10.2.0.145
    curl -k -O https://joydev:leichiB8eeQu@216.57.203.66/templates/bss-prime/setup-build-zone
    curl -k -O https://joydev:leichiB8eeQu@216.57.203.66/templates/bss-prime/fake-subset.tbz2
    chmod 755 setup-build-zone
    ./setup-build-zone
    
    # Note: After any reboot you'll need to run:
    #   ./setup-build-zone -e
    
    # Having git "core.autocrlf=input" will cause spurious dirty files in
    # some of our repos. Don't go there.
    [[ `git config core.autocrlf` == "input" ]] \
        && echo "* * * Warning: remove 'autocrlf=input' from your ~/.gitconfig"
    
    # Note: This "./configure" step is necessary to setup your system.
    # TODO: Pull out the requisite system setup steps. Shouldn't really
    #       be tucked away in illumos-live.git and configure.joyent.
    git clone git@git.joyent.com:illumos-live.git
    cd illumos-live
    curl -k -O https://joydev:leichiB8eeQu@216.57.203.66/illumos/configure.joyent
    GIT_SSL_NO_VERIFY=true ./configure
    
    # You need nodejs >= 0.4.9 (for usb-headnode) and npm 0.2.x (for agent
    # builds).
    pkgin -y in nodejs-0.4.9 npm-0.2.18
    
    # We also need npm 1.x for the usb-headnode build. To not conflict with
    # npm 0.2 in /opt/local we choose to install to "/opt/npm" and
    # *not* put is on our default PATH. "./tools/build-usb-headnode" will
    # ensure it is used from there.
    mkdir -p /opt/npm
    curl http://npmjs.org/install.sh | npm_config_prefix=/opt/npm clean=no sh
    
    # To build CA you need some more stuff (the authority here on needed
    # packages is <https://mo.joyent.com/cloud-analytics/blob/master/tools/ca-headnode-setup#L274>
    pkgin -y in gcc-compiler gcc-runtime gcc-tools cscope gmake \
        scmgit python24 python26 png npm GeoIP GeoLiteCity ghostscript
    
    # You should now be able to build mountain-gorilla (MG): i.e. all of SDC.
    # Let's try that:
    git clone git@git.joyent.com:mountain-gorilla.git
    cd mountain-gorilla
    time (./configure && gmake) 2>&1 | tee build.log

If your build zone in inside BH1, then you must add the following to "/etc/inet/hosts"
for the "tools/upload-bits" script (used by all of the 'upload_' targets) to work:

    10.2.0.190      stuff.joyent.us


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
their Makefile to handle package naming:

    NAME=smartlogin
    # Need GNU awk for multi-char arg to "-F".
    AWK=$(shell (which gawk 2>/dev/null | grep -v "^no ") || which awk)
    BRANCH=$(shell git symbolic-ref HEAD | $(AWK) -F/ '{print $$3}')
    ifeq ($(TIMESTAMP),)
        TIMESTAMP=$(shell date -u "+%Y%m%dT%H%M%SZ")
    endif
    GITDESCRIBE=g$(shell git describe --all --long --dirty | $(AWK) -F'-g' '{print $$NF}')
    ...
    TARBALL=$(NAME)-$(BRANCH)-$(TIMESTAMP)-$(GITDESCRIBE).tgz

or like this in a Bash script:

    # Need GNU awk for multi-char arg to "-F".
    AWK=$((which gawk 2>/dev/null | grep -v "^no ") || which awk)
    BRANCH=$(git symbolic-ref HEAD | ${AWK} -F/ '{print $3}')
    if [[ -z "$TIMESTAMP" ]]; then
        TIMESTAMP=$(date -u "+%Y%m%dT%H%M%SZ")
    fi
    GITDESCRIBE=g$(git describe --all --long --dirty | ${AWK} -F'-g' '{print $NF}')
    ...
    TARBALL=${NAME}-${BRANCH}-${TIMESTAMP}-${GITDESCRIBE}.tgz



Notes:
- This gives the option of the TIMESTAMP being passed in. This is important
  to allow an external driver -- e.g., moutain-gorilla, bamboo, CI -- to
  predict the expected output files, and hence be able to raise errors if
  expected files are not generated.
- Consistency here will help avoid confusion, and surprises in things like
  subtle differences in `awk` on Mac vs. SmartOS, various options to
  `git describe`.



# TODOs

- pkgsrc is a notable unversioned and pre-built component of this. For sanity
  at least there should be a manifest checksuming of used pkgsrc packages.
- datasets are prebuilt. We rely on the rule that a dataset, once published,
  never changes. Any dataset change must mean a new version and UUID.
- PLATFORM_TIMESTAMP: *want* (if possible) to have this in config.mk and pass
  it into the illumos-live build. Then MG's Makefile can be explicit about
  expected build outputs and do meaningful deps.
- "./configure -n" (i.e. using prebuilt platform): Should not presume a platform
  is already in "bits/". First it should look at our platform releases area
  on stuff.joyent.us. Then shuold download that to "cache/" dir, then should copy
  the selected one to "bits/" dir. Then the normal build should use that.
- Here is my (Trent's) current list of stuff that isn't yet built from source, i.e.
  stuff that I need to preload in my "bits" dir for a full build of release
  bits. We should chip away at these:
    in.bits/datasets
    in.bits/datasets/ubuntu-10.04.2.4.dsmanifest
    in.bits/datasets/ubuntu-10.04.2.4.img.gz
    in.bits/datasets/nodejs-1.1.4.dsmanifest
    in.bits/datasets/nodejs-1.1.4.zfs.bz2
    in.bits/datasets/smartos-1.3.15.zfs.bz2
    in.bits/datasets/smartos-1.3.15.dsmanifest
- npm: run an npm proxy? and set npm_config_... for this. Would that work?
  The idea is to have the build pull *all* component parts from our local
  "bits" dir.
- some solution for the datasets/ubuntu-*.dsmanifest "url" hack in usb-headnode?
  If this is temporary (i.e. the real ubuntu SmartOS-KVM dataset will be
  published to live DSAPI before a publish release) then perhaps not worth it.
- "make dumpenv" is done at the start of a full build here to dump environment
  details for the build log.
- Log (log all this to a log file or files). High prio.
- Dirty support (ability to do a build with local changes). Low prio.
- "make rc"






## A Plan (Dream?)

(warning: this is getting a little out of date)

What if a (full) build went like this:

- take a source "bits" directory or URL
- download all of that to a "deps" or "bits" or "cache" subdir
- clone (or update) all the source directories
    cache/repos/$repo    # pristine clones, for faster clean recloning
- kick off each of the steps (with appropriate order), publishing
  resultant bits to the same local "bits" dir
- 'make rc' to create a new 'rc' directory in a standard place and
  upload all bits (release bits, all built deps, build logs, changelog) to it.


How would this look for smartlogin only?

    $ ./configure --branch=release-20110714
    Fetching smartlogin repo cache (cache/repos/smart-login).
    Latest revision on 'release-20110714' branch is 'cafebabe'.
    Using smartlogin 'release-20110714-cafebabe'.
    Generated 'config.mk'.
    $ cat config.mk
    SMARTLOGIN_BRANCH="release-20110714"
    SMARTLOGIN_SHA="cafebabe"


Offline (i.e. just use what is local already):

    $ ./configure -o|--offline --branch=release-20110714
    Not updating smartlogin repo (in cache/repos/smart-login): offline mode.
    Latest revision on 'release-20110714' branch is 'cafebabe'.
    Using smartlogin 'release-20110714-cafebabe'.
    Generated 'config.mk'.


Now all 'make' steps will use "config.mk". Get a clean source tree
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
    builddeps_smartlogin -> logs build dump info and bails early if expected failure
    smartlogin -> builds, using only BITS_DIR for dependencies and puts products in BITS_DIR
    
