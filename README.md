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
