# Mountain Gorilla

- Repository: git@git.joyent.com:mountain-gorilla.git, <https://mo.joyent.com/mountain-gorilla>
- Who: Trent Mick, John Sonnenschein
- Docs: <https://mo.joyent.com/docs/mg>
- Bugs: <https://devhub.joyent.com/jira/browse/RELENG>
- Builds: <https://jenkins.joyent.us>, <https://stuff.joyent.us/stuff/builds>

A single repo to build all the parts of SDC. This is just a *build driver*
repo, all the components are still in their respective repos.
See <https://mo.joyent.com/docs/mg> for a more complete introduction.


# Quick start

While MG theoretically knows how to "build the world", i.e all of SDC,
the typical usage is to build one piece at a time. There is a make target
(or targets) for each SDC component. So, for example, here is how you
build VMAPI:

    git clone git@git.joyent.com:mountain-gorilla.git
    cd mountain-gorilla
    # Get auth info for stuff.joyent.us from where the build grabs bits.
    scp stuff@stuff.joyent.us:trent/mk-jenkins-slave/.mg.json ~/.mg.json
    ./configure -t vmapi        # generates bits/config.mk and fetches repo and deps
    make vmapi                  # builds in build/vmapi

If that fails for you, you might be missing prerequisites. See
<https://mo.joyent.com/docs/mg/master/#prerequisites>.


If you'll actually be building, see "Prerequisites" section below first.


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

Likewise for any target (`cat targets.json | json --keys`)

There is also a special target to build everything from scratch *except* the
platform (because the platform is by far the longest part of the build):

    ./configure -t all-except-platform
    make all-except-platform


# Prerequisites

The "tools/mk-jenkins-slave/mk-jenkins-slave.sh" script is used to build
new Jenkins (CI system) slaves and set them up for building SDC. Basically
it creates a new zone (current using the smartos-1.6.3 image) passing in
"tools/mk-jenkins-slave/jenkins-slave-setup.user-script". See
"tools/mk-jenkins-slave/README.md" for how to create a new build zone
for yourself, but basically it means running this from the GZ:

    ./tools/mk-jenkins-slave/mk-jenkins-slave.sh BUILD-ZONE-ALIAS

If you already have a zone that you want to setup, you *should* be able to just
manually run that user script (though that hasn't been tested).

You should now be able to build mountain-gorilla (MG): i.e. all of SDC.
Let's try that:

    git clone git@git.joyent.com:mountain-gorilla.git
    cd mountain-gorilla
    time (./configure && gmake) >build.log 2>&1 &; tail -f build.log


# Adding a repository quickstart

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
