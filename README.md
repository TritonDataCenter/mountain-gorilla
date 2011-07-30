# Moutain Gorilla

Trent's stab at a single repo to build SDC. This is just a *driver* repo,
all the components are still in their existing separate repos.


# Build System Dependencies

Notes on build sys requirements that I've hit:

- npm 1.0.x (a recent version require?)
- node >=0.4.9
- `tar` has to be a capable GNU tar or you need this in "~/.npmrc":

    tar = gtar

- Cannot have "core.autocrlf=input" in your "~/.gitconfig", else you will
  get spurious dirty repos (mostly in submodules) about EOL changes.

    



# Package Versioning

    NAME-BRANCH-TIMESTAMP[-GITDESCRIBE].TGZ

where:

- NAME is the package name, e.g. "smartlogin", "ca-pkg".
- BRANCH is the git branch, e.g. "master", "release-20110714". Use:
    
        BRANCH=$(shell git symbolic-ref HEAD | awk -F / '{print $$3}')  # Makefile
        BRANCH=$(git symbolic-ref HEAD | awk -F / '{print $3}')         # Bash script

- TIMESTAMP is an ISO timestamp like "20110729T063329Z". Use:

        TIMESTAMP=$(shell TZ=UTC date "+%Y%m%dT%H%M%SZ")    # Makefile
        TIMESTAMP=$(TZ=UTC date "+%Y%m%dT%H%M%SZ")          # Bash script

  A timestamp is helpful (and in this position in the package name) because:
  (a) it often helps to know about when a package was built when debugging;
  and (b) it ensures that simple lexographical sorting of "NAME-BRANCH-*"
  packages in a directory (as done by agents-installer and usb-headnode)
  will make choosing "the latest" possible.

  A timestamp *sucks* because successive builds in a dev tree will get a
  new timestamp: defeating Makefile dependency attempts to avoid rebuilding.
  Note that the TIMESTAMP is only necessary for released/published packages,
  so for projects that care (e.g. ca), the TIMESTAMP can just be added
  for release.

- GITDESCRIBE gives the git sha for the repo and whether the repo was dirty
  (had local changes) when it was built, e.g. "gfa1afe1-dirty", "gbadf0d".
  Use:
  
        GITDESCRIBE=$(shell git describe --all --long --dirty | cut -d- -f3,4)
        GITDESCRIBE=$(git describe --all --long --dirty | cut -d- -f3,4)

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
    BRANCH=$(shell git symbolic-ref HEAD | awk -F/ '{print $$3}')
    ifeq ($(TIMESTAMP),)
        TIMESTAMP=$(shell TZ=UTC date "+%Y%m%dT%H%M%SZ")
    endif
    GITDESCRIBE=$(shell git describe --all --long --dirty | cut -d- -f3,4)
    ...
    TARBALL=$(NAME)-$(BRANCH)-$(TIMESTAMP)-$(GITDESCRIBE).tgz

or like this in a Bash script:

    BRANCH=$(git symbolic-ref HEAD | awk -F/ '{print $3}')
    if [[ -z "$TIMESTAMP" ]]; then
        TIMESTAMP=$(TZ=UTC date "+%Y%m%dT%H%M%SZ")
    fi
    GITDESCRIBE=$(git describe --all --long --dirty | cut -d- -f3,4)
    ...
    TARBALL=${NAME}-${BRANCH}-${TIMESTAMP}-${GITDESCRIBE}.tgz



Notes:
- This gives the option of the TIMESTAMP being passed in. This is important
  to allow an external driver -- e.g., moutain-gorilla or bamboo -- to
  predict the expected output files, and hence be able to raise errors if
  expected files are not generated.
- Consistency here will help avoid confusion, and surprises in things like
  subtle differences in `awk` on Mac vs. SmartOS, various options to
  `git describe`.
    


# 'publish' target

TODO: describe MG's desire for a "gmake publish" in each project
and the "known subdir" in the BITS_DIR.



# TODOs


- in.bits:
    in.bits/
    in.bits/platform-master-20110729T154436Z.tgz
    in.bits/ur-scripts
    in.bits/ur-scripts/release-20110714
    in.bits/ur-scripts/release-20110714/agents-hvm-20110726T001206Z.md5sum
    in.bits/ur-scripts/release-20110714/agents-hvm-20110726T001206Z.sh
    in.bits/release-20110714
    in.bits/release-20110714/platform-HVM-20110726T001212Z.tgz
    in.bits/datasets
    in.bits/datasets/ubuntu-10.04.2.4.dsmanifest
    in.bits/datasets/ubuntu-10.04.2.4.img.gz
    in.bits/datasets/nodejs-1.1.4.dsmanifest
    in.bits/datasets/nodejs-1.1.4.zfs.bz2
    in.bits/datasets/smartos-1.3.15.zfs.bz2
    in.bits/datasets/smartos-1.3.15.dsmanifest
    in.bits/assets
    in.bits/assets/atropos-develop-20110210.tar.bz2
- then usb-headnode: hardcoding a platform and platform-HVM version
  And how can this fit in with existing usb-headnode/build.spec.
- make platform hvmplatform hvmagentsshar  # hardcoded download
- "assets": WTF. ca-pkg easy. Who builds "atropos"? If that is going away
  (ask Orlando) then just hack it.
- Get that ca gitignore thing to work. Do the pull requests for the
  appropriate gitignores for those repos.
- add platform
  https://hub.joyent.com/wiki/display/dev/Building+the+SmartOS+live+image+in+a+SmartOS+zone
  older: https://hub.joyent.com/wiki/display/dev/Building+the+147+live+image
- simple git cloning... then "src package" handling for reproducibility
  and faster cloning.
- how can platform-HVM fit in? it needs to be built on separate OS
- usb-headnode: pulling in and caching datasets in "bits" dir
- mg: move bits dir to build/bits (should be clean for each build)
  can have a 'cache/' dir to save old stuff.
- npm: run an npm proxy? and set npm_config_... for this. Would that work?
- some solution for the datasets/ubuntu-*.dsmanifest "url" hack in usb-headnode?





# scratch space for notes

- "Agents" repo setup is pros/cons:
    - Agents pro: release dir is passed in (it shouldn't be hard coded)
    - Agents con: there isn't a separate "bamboo/build.sh" so it
      could accidentally be broken.
    - overall: Agents build.sh iface is better than the hacks for the
      others. Perhaps a "bamboo-build" script in each repo with a
      standardized interface.
    - bits filenames: add the git sha suffix a la the others



## A Plan (Dream?)

What if a (full) build went like this:

- take a source "bits" directory or URL
- download all of that to a "deps" or "bits" or "cache" subdir
- clone (or update) all the source directories
    cache/repos/$repo    # pristine clones, for faster clean recloning
- kick off each of the steps (with appropriate order), publishing
  resultant bits to the same local "bits" dir
- 'make upload' to upload bits to the release bits dir ... including logs


Set the version to build

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


## bigger picture

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
