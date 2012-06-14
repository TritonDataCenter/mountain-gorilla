#!/usr/bin/env python
#
# Remove old builds under here. This presumes the MG-uploaded
# structure (see:
# <https://mo.joyent.com/mountain-gorilla/blob/master/tools/upload-bits>)
#
# This script lives here: <https://mo.joyent.com/mountain-gorilla/tree/master/tools>
#
# Usage:
#       python rm-old-builds.py [DIRS...]
#
# For each given DIR, remove all old MG-style build dirs. If DIRS is not given, then
# all subdirs in the cwd are checked.
#
# "Old" is anything older than 20 days.
#

import sys
import os
from os.path import isdir, abspath, join, basename, islink, lexists
import datetime
import time
from glob import glob
import re
from collections import defaultdict
from pprint import pprint


DRYRUN = False
VERBOSE = True
OLD = datetime.timedelta(days=20)
BUILD_DIR_PATH = re.compile(r"^(?P<branch>.*?)-(?P<time>\d{8}T\d{6}Z)$")


def rm_old_builds(dir):
    print "# %s" % dir
    # Get list of all build dirs.
    subdirs = [d for d in glob(dir + "/*") if isdir(d)]
    dirs_from_branch = defaultdict(set)
    for d in subdirs:
        match = BUILD_DIR_PATH.match(basename(d))
        if not match:
            continue
        dirs_from_branch[match.group("branch")].add(d)
    # Skip "release-*" branches.
    for branch in list(dirs_from_branch.keys()):
        if branch.startswith("release-"):
            if VERBOSE:
                print "# skip '%s' branch '%s' (release branch)" % (dir, branch)
            del dirs_from_branch[branch]
    # Skip most recent two and anything younger than "OLD".
    for branch, dirs in dirs_from_branch.items():
        mtime_and_dirs = [(os.stat(d).st_mtime, d) for d in dirs]
        mtime_and_dirs.sort()
        for mtime, d in mtime_and_dirs[-2:]: # skip most recent two
            if VERBOSE:
                print "# skip '%s' (most recent two)" % d
            dirs.discard(d)
    # Skip "$BRANCH-latest" linked dirs.
    for branch, dirs in dirs_from_branch.items():
        latest_dir = join(dir, branch + '-latest')
        if islink(latest_dir) and lexists(latest_dir):
            latest_target = os.readlink(latest_dir)
            if latest_target in dirs:
                if VERBOSE:
                    print "# skip '%s' (*-latest target)" % join(dir, latest_target)
                dirs.discard(latest_target)
    # Skip young ones.
    cutoff = time.mktime((datetime.datetime.now() - OLD).timetuple())
    for branch, dirs in dirs_from_branch.items():
        marked_for_death = set()
        if len(dirs) > 20:
            # Only keep up to 20 recent ones in the same branch, this is
            # to avoid a dir with frequent builds swamping things.
            marked_for_death = set(list(sorted(dirs))[:-20])
        for d in list(dirs):
            if d in marked_for_death:
                continue
            mtime = os.stat(d).st_mtime
            if mtime > cutoff:
                if VERBOSE:
                    print "# skip '%s' (young)" % d
                dirs.discard(d)
    # Do it
    for branch, dirs in dirs_from_branch.items():
        for d in dirs:
            cmd = "rm -rf %s" % d
            print cmd
            if not DRYRUN:
                os.system(cmd)


def main(argv):
    if len(argv) == 1:
        dirs = [d for d in os.listdir('.') if isdir(d)]
    else:
        dirs = argv[1:]
        for d in dirs:
            assert isdir(d), "'%s' is not a directory" % d
    for d in dirs:
        rm_old_builds(d)

main(sys.argv)
