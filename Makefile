
#
# Mountain Gorilla Makefile. See "README.md".
#

#---- Config

include bits/config.mk

# Directories
TOP=$(shell pwd)
BITS_DIR=$(TOP)/bits

# Tools
MAKE = make
TAR = tar
UNAME := $(shell uname)
ifeq ($(UNAME), SunOS)
	MAKE = gmake
	TAR = gtar
endif

# Other
# Is JOBS=16 reasonable here? The old bamboo plans used this (or higher).
JOB=16

# A TIMESTAMP to use must be defined (and typically is in 'bits/config.mk').
# 
# At one point we'd just generate TIMESTAMP at the top of the Makefile, but
# that seemed to hit a gmake issue when building multiple targets: the 'ca'
# target would be run three times at (rougly) 4 seconds apart on the time
# stamp (guessing the 'three times' is because CA_BITS has three elements).
# Similarly for the 'agents' target.
ifeq ($(TIMESTAMP),)
	TIMESTAMP=TimestampNotSet
endif

ifeq ($(UPLOAD_LOCATION),)
	UPLOAD_LOCATION=stuff@stuff.joyent.us:builds
endif

#---- Primary targets

.PHONY: all
all: smartlogin amon ca agents agentsshar platform ufds usbheadnode releasejson


#---- smartlogin
# TODO:
# - Re-instate 'gmake lint'?

SMARTLOGIN_BITS=$(BITS_DIR)/smartlogin/smartlogin-$(SMARTLOGIN_BRANCH)-$(TIMESTAMP)-g$(SMARTLOGIN_SHA).tgz

.PHONY: smartlogin
smartlogin: $(SMARTLOGIN_BITS)

# PATH: ensure using GCC from SFW. Not sure this is necessary, but has been
# the case for release builds pre-MG.
$(SMARTLOGIN_BITS): build/smart-login
	@echo "# Build smartlogin: branch $(SMARTLOGIN_BRANCH), sha $(SMARTLOGIN_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/smart-login && TIMESTAMP=$(TIMESTAMP) PATH=/usr/sfw/bin:$(PATH) BITS_DIR=$(BITS_DIR) gmake clean all publish)
	@echo "# Created smartlogin bits:"
	@ls -1 $(SMARTLOGIN_BITS)
	@echo ""

clean_smartlogin:
	rm -rf $(BITS_DIR)/smartlogin

upload_smartlogin:
	./tools/upload-bits $(SMARTLOGIN_BRANCH) $(TIMESTAMP) $(UPLOAD_LOCATION)/smartlogin


#---- agents

_a_stamp=$(AGENTS_BRANCH)-$(TIMESTAMP)-g$(AGENTS_SHA)
AGENTS_BITS=$(BITS_DIR)/agents/agents_core/agents_core-$(_a_stamp).tgz \
	$(BITS_DIR)/agents/heartbeater/heartbeater-$(_a_stamp).tgz \
	$(BITS_DIR)/agents/metadata/metadata-$(_a_stamp).tgz \
	$(BITS_DIR)/agents/dataset_manager/dataset_manager-$(_a_stamp).tgz \
	$(BITS_DIR)/agents/zonetracker/zonetracker-$(_a_stamp).tgz \
	$(BITS_DIR)/agents/provisioner-v2/provisioner-v2-$(_a_stamp).tgz \
	$(BITS_DIR)/agents/zonetracker-v2/zonetracker-v2-$(_a_stamp).tgz \
	$(BITS_DIR)/agents/mock_cloud/mock_cloud-$(_a_stamp).tgz
AGENTS_BITS_0=$(shell echo $(AGENTS_BITS) | awk '{print $$1}')

agents: $(AGENTS_BITS_0)

# PATH: ensure using GCC from SFW. Not sure this is necessary, but has been
# the case for release builds pre-MG.
$(AGENTS_BITS): build/agents
	@echo "# Build agents: branch $(AGENTS_BRANCH), sha $(AGENTS_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/agents && TIMESTAMP=$(TIMESTAMP) PATH=/usr/sfw/bin:$(PATH) ./build.sh -p -n -l $(BITS_DIR)/agents -L)
	@echo "# Created agents bits:"
	@ls -1 $(AGENTS_BITS)
	@echo ""

clean_agents:
	rm -rf $(BITS_DIR)/agents

upload_agents:
	./tools/upload-bits $(AGENTS_BRANCH) $(TIMESTAMP) $(UPLOAD_LOCATION)/agents



#---- amon

_amon_stamp=$(AMON_BRANCH)-$(TIMESTAMP)-g$(AMON_SHA)
AMON_BITS=$(BITS_DIR)/amon/amon-master-$(_amon_stamp).tar.bz2 \
	$(BITS_DIR)/amon/amon-relay-$(_amon_stamp).tgz \
	$(BITS_DIR)/amon/amon-agent-$(_amon_stamp).tgz
AMON_BITS_0=$(shell echo $(AMON_BITS) | awk '{print $$1}')

.PHONY: amon
amon: $(AMON_BITS_0)

$(AMON_BITS): build/amon
	@echo "# Build amon: branch $(AMON_BRANCH), sha $(AMON_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/amon && IGNORE_DIRTY=1 TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake clean all pkg publish)
	@echo "# Created amon bits:"
	@ls -1 $(AMON_BITS)
	@echo ""

clean_amon:
	rm -rf $(BITS_DIR)/amon
	(cd build/amon && gmake clean)

upload_amon:
	./tools/upload-bits $(AMON_BRANCH) $(TIMESTAMP) $(UPLOAD_LOCATION)/amon


#---- cloud-analytics
#TODO:
# - merge CA_VERSION and CA_PUBLISH_VERSION? what about the version sed'd into
#   the package.json's?
# - look at https://hub.joyent.com/wiki/display/dev/Setting+up+Cloud+Analytics+development+on+COAL-147
#   for env setup. Might be demons in there. (RELENG-192)

_ca_stamp=$(CA_BRANCH)-$(TIMESTAMP)-g$(CA_SHA)
CA_BITS=$(BITS_DIR)/ca/ca-pkg-$(_ca_stamp).tar.bz2 \
	$(BITS_DIR)/ca/cabase-$(_ca_stamp).tar.gz \
	$(BITS_DIR)/ca/cainstsvc-$(_ca_stamp).tar.gz
CA_BITS_0=$(shell echo $(CA_BITS) | awk '{print $$1}')

.PHONY: ca
ca: $(CA_BITS_0)

# PATH for ca build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(CA_BITS): build/cloud-analytics
	@echo "# Build ca: branch $(CA_BRANCH), sha $(CA_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/cloud-analytics && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) PATH="/sbin:/opt/local/bin:/usr/gnu/bin:/usr/bin:/usr/sbin:$(PATH)" gmake clean pkg release publish)
	@echo "# Created ca bits:"
	@ls -1 $(CA_BITS)
	@echo ""

# Warning: if CA's submodule deps change, this 'clean_ca' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_ca:
	rm -rf $(BITS_DIR)/ca
	(cd build/cloud-analytics && gmake clean)

upload_ca:
	./tools/upload-bits $(CA_BRANCH) $(TIMESTAMP) $(UPLOAD_LOCATION)/ca


#---- UFDS

_ufds_stamp=$(UFDS_BRANCH)-$(TIMESTAMP)-g$(UFDS_SHA)
UFDS_BITS=$(BITS_DIR)/ufds/ufds-pkg-$(_ufds_stamp).tar.bz2

.PHONY: ufds
ufds: $(UFDS_BITS)

# PATH for ufds build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(UFDS_BITS): build/ufds
	@echo "# Build ufds: branch $(UFDS_BRANCH), sha $(UFDS_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/ufds && PATH=/opt/npm/bin:$(PATH) TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake pkg release publish)
	@echo "# Created ufds bits:"
	@ls -1 $(UFDS_BITS)
	@echo ""

# Warning: if UFDS's submodule deps change, this 'clean_ufds' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_ufds:
	rm -rf $(BITS_DIR)/ufds
	(cd build/ufds && gmake clean)

upload_ufds:
	./tools/upload-bits $(UFDS_BRANCH) $(TIMESTAMP) $(UPLOAD_LOCATION)/ufds



#---- agents shar

_as_stamp=$(AGENTSSHAR_BRANCH)-$(TIMESTAMP)-g$(AGENTSSHAR_SHA)
AGENTSSHAR_BITS=$(BITS_DIR)/agentsshar/agents-$(_as_stamp).sh \
	$(BITS_DIR)/agentsshar/agents-$(_as_stamp).md5sum
AGENTSSHAR_BITS_0=$(shell echo $(AGENTSSHAR_BITS) | awk '{print $$1}')

.PHONY: agentsshar
agentsshar: $(AGENTSSHAR_BITS_0)

$(AGENTSSHAR_BITS): build/agents-installer/Makefile
	@echo "# Build agentsshar: branch $(AGENTSSHAR_BRANCH), sha $(AGENTSSHAR_SHA)"
	mkdir -p $(BITS_DIR)/agentsshar
	(cd build/agents-installer && TIMESTAMP=$(TIMESTAMP) ./mk-agents-shar -o $(BITS_DIR)/agentsshar/ -d $(BITS_DIR) -b $(AGENTSSHAR_BRANCH))
	@echo "# Created agentsshar bits:"
	@ls -1 $(AGENTSSHAR_BITS)
	@echo ""

clean_agentsshar:
	rm -rf $(BITS_DIR)/agentsshar
	(if [[ -d build/agents-installer ]]; then cd build/agents-installer && gmake clean; fi )

upload_agentsshar:
	./tools/upload-bits $(AGENTSSHAR_BRANCH) $(TIMESTAMP) $(UPLOAD_LOCATION)/agentsshar


#---- usb-headnode
# TODO:
# - solution for datasets
# - pkgsrc isolation

.PHONY: usbheadnode
usbheadnode: coal usb upgrade boot

_usbheadnode_stamp=$(USBHEADNODE_BRANCH)-$(TIMESTAMP)-g$(USBHEADNODE_SHA)
COAL_BIT=$(BITS_DIR)/usbheadnode/coal-$(_usbheadnode_stamp)-4gb.tgz

bits/usbheadnode/build.spec.local:
	mkdir -p bits/usbheadnode
	sed -e "s/{{BRANCH}}/$(USBHEADNODE_BRANCH)/" <build.spec.in >bits/usbheadnode/build.spec.local
	(cd build/usb-headnode; rm -f build.spec.local; ln -s ../../bits/usbheadnode/build.spec.local)

.PHONY: coal
coal: $(COAL_BIT)

$(COAL_BIT): build/usb-headnode/Makefile bits/usbheadnode/build.spec.local
	@echo "# Build coal: usb-headnode branch $(USBHEADNODE_BRANCH), sha $(USBHEADNODE_SHA)"
	mkdir -p $(BITS_DIR)/usbheadnode
	cd build/usb-headnode \
		&& PATH=/opt/npm/bin:$(PATH) BITS_URL=$(TOP)/bits TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(TOP)/build ./bin/build-image -c coal
	mv build/usb-headnode/$(shell basename $(COAL_BIT)) $(BITS_DIR)/usbheadnode
	@echo "# Created coal bits:"
	@ls -1 $(COAL_BIT)
	@echo ""

USB_BIT=$(BITS_DIR)/usbheadnode/usb-$(_usbheadnode_stamp).tgz

.PHONY: usb
usb: $(USB_BIT)

$(USB_BIT): build/usb-headnode/Makefile bits/usbheadnode/build.spec.local
	@echo "# Build usb: usb-headnode branch $(USBHEADNODE_BRANCH), sha $(USBHEADNODE_SHA)"
	mkdir -p $(BITS_DIR)/usbheadnode
	cd build/usb-headnode \
		&& PATH=/opt/npm/bin:$(PATH) BITS_URL=$(TOP)/bits TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(TOP)/build ./bin/build-image -c usb
	mv build/usb-headnode/$(shell basename $(USB_BIT)) $(BITS_DIR)/usbheadnode
	@echo "# Created usb bits:"
	@ls -1 $(USB_BIT)
	@echo ""

UPGRADE_BIT=$(BITS_DIR)/usbheadnode/upgrade-$(_usbheadnode_stamp).tgz

.PHONY: upgrade
upgrade: $(UPGRADE_BIT)

$(UPGRADE_BIT): build/usb-headnode/Makefile bits/usbheadnode/build.spec.local
	@echo "# Build upgrade: usb-headnode branch $(USBHEADNODE_BRANCH), sha $(USBHEADNODE_SHA)"
	mkdir -p $(BITS_DIR)/usbheadnode
	cd build/usb-headnode \
		&& PATH=/opt/npm/bin:$(PATH) BITS_URL=$(TOP)/bits TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(TOP)/build ./bin/build-image upgrade 
	mv build/usb-headnode/$(shell basename $(UPGRADE_BIT)) $(BITS_DIR)/usbheadnode
	@echo "# Created upgrade bits:"
	@ls -1 $(UPGRADE_BIT)
	@echo ""

BOOT_BIT=$(BITS_DIR)/usbheadnode/boot-$(_usbheadnode_stamp).tgz

.PHONY: boot
boot: $(BOOT_BIT)

$(BOOT_BIT): build/usb-headnode/Makefile bits/usbheadnode/build.spec.local
	@echo "# Build boot: usb-headnode branch $(USBHEADNODE_BRANCH), sha $(USBHEADNODE_SHA)"
	mkdir -p $(BITS_DIR)/usbheadnode
	cd build/usb-headnode \
		&& PATH=/opt/npm/bin:$(PATH) BITS_URL=$(TOP)/bits TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(TOP)/build ./bin/build-image tar 
	mv build/usb-headnode/$(shell basename $(BOOT_BIT)) $(BITS_DIR)/usbheadnode
	@echo "# Created boot bits:"
	@ls -1 $(BOOT_BIT)
	@echo ""


RELEASEJSON_BIT=$(BITS_DIR)/usbheadnode/release.json

.PHONY: boot
releasejson:
	mkdir -p $(BITS_DIR)/usbheadnode
	echo "{ \
	\"date\": \"$(TIMESTAMP)\", \
	\"branch\": \"$(USBHEADNODE_BRANCH)\", \
	\"coal\": \"$(shell basename $(COAL_BIT))\", \
	\"boot\": \"$(shell basename $(BOOT_BIT))\", \
	\"usb\": \"$(shell basename $(USB_BIT))\", \
	\"upgrade\": \"$(shell basename $(UPGRADE_BIT))\" \
}" | json >$(RELEASEJSON_BIT)


clean_usb-headnode:
	rm -rf $(BOOT_BIT) $(UPGRADE_BIT) $(USB_BIT) $(COAL_BIT)



#---- platform

PLATFORM_BIT=$(BITS_DIR)/platform/platform-$(PLATFORM_BRANCH)-$(TIMESTAMP).tgz

.PHONY: platform
platform: $(PLATFORM_BIT)

build/illumos-live/configure.mg:
	sed -e "s/BRANCH/$(PLATFORM_BRANCH)/" -e "s:GITCLONESOURCE:$(shell pwd)/build/:" <illumos-configure.tmpl >build/illumos-live/configure.mg

build/illumos-live/configure-branches:
	sed -e "s/BRANCH/$(PLATFORM_BRANCH)/" <illumos-configure-branches.tmpl >build/illumos-live/configure-branches

# PATH: Ensure using GCC from SFW as require for platform build.
$(PLATFORM_BIT): build/illumos-live/configure.mg build/illumos-live/configure-branches
	@echo "# Build platform: branch $(PLATFORM_BRANCH), sha $(PLATFORM_SHA)"
	(cd build/illumos-live && PATH=/usr/sfw/bin:$(PATH) ./configure && PATH=/usr/sfw/bin:$(PATH) BUILDSTAMP=$(TIMESTAMP) gmake world && PATH=/usr/sfw/bin:$(PATH) BUILDSTAMP=$(TIMESTAMP) gmake live)
	(mkdir -p $(BITS_DIR)/platform)
	(cp build/illumos-live/output/platform-$(TIMESTAMP).tgz $(BITS_DIR)/platform/platform-$(PLATFORM_BRANCH)-$(TIMESTAMP).tgz)
	@echo "# Created platform bits:"
	@ls -1 $(PLATFORM_BIT)
	@echo ""

clean_platform:
	rm -f $(BITS_DIR)/platform-*
	(cd build/illumos-live && gmake clean)

upload_platform:
	./tools/upload-bits $(PLATFORM_BRANCH) $(TIMESTAMP) $(UPLOAD_LOCATION)/platform



#---- misc targets

clean_null:

.PHONY: distclean
distclean:
	pfexec rm -rf bits build


# Upload bits we want to keep for a Jenkins build.
upload_jenkins:
	@[[ -z "$(JOB_NAME)" ]] \
		&& echo "error: JOB_NAME isn't set (is this being run under Jenkins?)" \
		&& exit 1 || true
	./tools/upload-bits $(BRANCH) $(TIMESTAMP) $(UPLOAD_LOCATION)/$(JOB_NAME)

