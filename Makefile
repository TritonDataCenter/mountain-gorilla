
#
# Mountain Gorilla Makefile. See "README.md".
#

#---- Config

include config.mk

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

# A TIMESTAMP to use must be defined (and typically is in 'config.mk').
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
	UPLOAD_LOCATION="stuff@stuff.joyent.us:builds"
endif

#---- Primary targets

.PHONY: all
all: smartlogin ca agents agentsshar platform ufds coal usb upgrade boot releasejson


#---- smartlogin
# TODO:
# - Re-instate 'gmake lint'?

SMARTLOGIN_BITS=$(BITS_DIR)/smartlogin/smartlogin-$(SMARTLOGIN_BRANCH)-$(TIMESTAMP)-g$(SMARTLOGIN_SHA).tgz

.PHONY: smartlogin
smartlogin: $(SMARTLOGIN_BITS)

# PATH: ensure using GCC from SFW. Not sure this is necessary, but has been
# the case for release builds pre-MG.
$(SMARTLOGIN_BITS): build/smartlogin
	@echo "# Build smartlogin: branch $(SMARTLOGIN_BRANCH), sha $(SMARTLOGIN_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/smartlogin && TIMESTAMP=$(TIMESTAMP) PATH=/usr/sfw/bin:$(PATH) BITS_DIR=$(BITS_DIR) gmake clean all publish)
	@echo "# Created smartlogin bits:"
	@ls -1 $(SMARTLOGIN_BITS)
	@echo ""

clean_smartlogin:
	(rm -rf $(SMARTLOGIN_BITS) || /usr/bin/true)

upload_smartlogin:
	./tools/upload-bits -f "$(SMARTLOGIN_BITS)" $(SMARTLOGIN_BRANCH) $(TIMESTAMP) $(UPLOAD_LOCATION)/smartlogin/

#---- agents

_a_stamp=$(AGENTS_BRANCH)-$(TIMESTAMP)-g$(AGENTS_SHA)
AGENTS_BITS=$(BITS_DIR)/agents_core/$(AGENTS_BRANCH)/agents_core-$(_a_stamp).tgz \
	$(BITS_DIR)/heartbeater/$(AGENTS_BRANCH)/heartbeater-$(_a_stamp).tgz \
	$(BITS_DIR)/metadata/$(AGENTS_BRANCH)/metadata-$(_a_stamp).tgz \
	$(BITS_DIR)/dataset_manager/$(AGENTS_BRANCH)/dataset_manager-$(_a_stamp).tgz \
	$(BITS_DIR)/zonetracker/$(AGENTS_BRANCH)/zonetracker-$(_a_stamp).tgz \
	$(BITS_DIR)/provisioner-v2/$(AGENTS_BRANCH)/provisioner-v2-$(_a_stamp).tgz \
	$(BITS_DIR)/zonetracker-v2/$(AGENTS_BRANCH)/zonetracker-v2-$(_a_stamp).tgz \
	$(BITS_DIR)/mock_cloud/$(AGENTS_BRANCH)/mock_cloud-$(_a_stamp).tgz
AGENTS_BITS_0=$(shell echo $(AGENTS_BITS) | awk '{print $$1}')

agents: $(AGENTS_BITS_0)

# PATH: ensure using GCC from SFW. Not sure this is necessary, but has been
# the case for release builds pre-MG.
$(AGENTS_BITS): build/agents
	@echo "# Build agents: branch $(AGENTS_BRANCH), sha $(AGENTS_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/agents && TIMESTAMP=$(TIMESTAMP) PATH=/usr/sfw/bin:$(PATH) ./build.sh -p -n -l $(BITS_DIR))
	@echo "# Created agents bits:"
	@ls -1 $(AGENTS_BITS)
	@echo ""


clean_agents:
	rm -rf $(AGENTS_BITS)

upload_agents:
	./tools/upload-bits -f "$(AGENTS_BITS)" $(AGENTS_BRANCH) $(TIMESTAMP) $(UPLOAD_LOCATION)/agents/

#---- cloud-analytics
#TODO:
# - merge CA_VERSION and CA_PUBLISH_VERSION? what about the version sed'd into
#   the package.json's?
# - look at https://hub.joyent.com/wiki/display/dev/Setting+up+Cloud+Analytics+development+on+COAL-147
#   for env setup. Might be demons in there. (RELENG-192)

_ca_stamp=$(CA_BRANCH)-$(TIMESTAMP)-g$(CA_SHA)
CA_BITS=$(BITS_DIR)/assets/ca-pkg-$(_ca_stamp).tar.bz2 \
	$(BITS_DIR)/cloud_analytics/cabase-$(_ca_stamp).tar.gz \
	$(BITS_DIR)/cloud_analytics/cainstsvc-$(_ca_stamp).tar.gz
CA_BITS_0=$(shell echo $(CA_BITS) | awk '{print $$1}')

.PHONY: ca
ca: $(CA_BITS_0)

# PATH for ca build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(CA_BITS): build/ca
	@echo "# Build ca: branch $(CA_BRANCH), sha $(CA_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/ca && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) PATH="/sbin:/opt/local/bin:/usr/gnu/bin:/usr/bin:/usr/sbin:$(PATH)" gmake pkg release publish)
	@echo "# Created ca bits:"
	@ls -1 $(CA_BITS)
	@echo ""

# Warning: if CA's submodule deps change, this 'clean_ca' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_ca:
	rm -rf $(BITS_DIR)/assets
	rm -rf $(BITS_DIR)/cloud_analytics
	(cd build/ca && gmake clean)

upload_ca:
	./tools/upload-bits -f "$(CA_BITS)" $(CA_BRANCH) $(TIMESTAMP) $(UPLOAD_LOCATION)/ca/

#---- UFDS

_ufds_stamp=$(UFDS_BRANCH)-$(TIMESTAMP)-g$(UFDS_SHA)
UFDS_BITS=$(BITS_DIR)/assets/ufds-pkg-$(_ufds_stamp).tar.bz2

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
	rm -rf $(BITS_DIR)/assets
	rm -rf $(BITS_DIR)/ufds
	(cd build/ufds && gmake clean)

upload_ufds:
	./tools/upload-bits -f "$(UFDS_BITS)" $(UFDS_BRANCH) $(TIMESTAMP) $(UPLOAD_LOCATION)/ufds/

#---- agents shar

_as_stamp=$(AGENTSSHAR_BRANCH)-$(TIMESTAMP)-g$(AGENTSSHAR_SHA)
AGENTSSHAR_BITS=$(BITS_DIR)/ur-scripts/agents-$(_as_stamp).sh \
	$(BITS_DIR)/ur-scripts/agents-$(_as_stamp).md5sum
AGENTSSHAR_BITS_0=$(shell echo $(AGENTSSHAR_BITS) | awk '{print $$1}')

.PHONY: agentsshar
agentsshar: $(AGENTSSHAR_BITS_0)

$(AGENTSSHAR_BITS): build/agents-installer/Makefile $(AGENTS_BITS) $(CA_BITS) $(SMARTLOGIN_BITS)
	@echo "# Build agentsshar: branch $(AGENTSSHAR_BRANCH), sha $(AGENTSSHAR_SHA)"
	mkdir -p $(BITS_DIR)/ur-scripts
	(cd build/agents-installer && TIMESTAMP=$(TIMESTAMP) ./mk-agents-shar -o $(BITS_DIR)/ur-scripts -d $(BITS_DIR) -b $(AGENTSSHAR_BRANCH))
	@echo "# Created agentsshar bits:"
	@ls -1 $(AGENTSSHAR_BITS)
	@echo ""

clean_agentsshar:
	(rm -rf $(AGENTSSHAR_BITS) || /usr/bin/true)
	(if [[ -d build/agents-installer ]]; then cd build/agents-installer && gmake clean; fi )

upload_agentsshar:
	./tools/upload-bits -f "$(AGENTSSHAR_BITS)" $(AGENTSSHAR_BRANCH) $(TIMESTAMP) $(UPLOAD_LOCATION)/agentsshar/
#---- usb-headnode
# TODO:
# - "assets/" bits area for ca-pkg package is dumb: use cloud_analytics
# - solution for datasets
# - pkgsrc isolation

_usbheadnode_stamp=$(USBHEADNODE_BRANCH)-$(TIMESTAMP)-g$(USBHEADNODE_SHA)
COAL_BIT=$(BITS_DIR)/release/coal-$(_usbheadnode_stamp)-4gb.tgz

# Alias for "coal". Drop it?
.PHONY: usb-headnode
usb-headnode: coal

.PHONY: coal
coal: $(COAL_BIT)

$(COAL_BIT): $(BITS_DIR)/platform-$(TIMESTAMP).tgz
	@echo "# Build coal: usb-headnode branch $(USBHEADNODE_BRANCH), sha $(USBHEADNODE_SHA)"
	mkdir -p $(BITS_DIR)/release
	./tools/build-usb-headnode $(TIMESTAMP) $(BITS_DIR) -c coal
	mv build/usb-headnode/$(shell basename $(COAL_BIT)) $(BITS_DIR)/release
	@echo "# Created coal bits:"
	@ls -1 $(COAL_BIT)
	@echo ""

USB_BIT=$(BITS_DIR)/release/usb-$(_usbheadnode_stamp).tgz

.PHONY: usb
usb: $(USB_BIT)

$(USB_BIT): $(BITS_DIR)/platform-$(TIMESTAMP).tgz
	@echo "# Build usb: usb-headnode branch $(USBHEADNODE_BRANCH), sha $(USBHEADNODE_SHA)"
	mkdir -p $(BITS_DIR)/release
	./tools/build-usb-headnode $(TIMESTAMP) $(BITS_DIR) -c usb
	mv build/usb-headnode/$(shell basename $(USB_BIT)) $(BITS_DIR)/release
	@echo "# Created usb bits:"
	@ls -1 $(USB_BIT)
	@echo ""

UPGRADE_BIT=$(BITS_DIR)/release/upgrade-$(_usbheadnode_stamp).tgz

.PHONY: upgrade
upgrade: $(UPGRADE_BIT)

$(UPGRADE_BIT): $(BITS_DIR)/platform-$(TIMESTAMP).tgz
	@echo "# Build upgrade: usb-headnode branch $(USBHEADNODE_BRANCH), sha $(USBHEADNODE_SHA)"
	mkdir -p $(BITS_DIR)/release
	./tools/build-usb-headnode $(TIMESTAMP) $(BITS_DIR) upgrade
	mv build/usb-headnode/$(shell basename $(UPGRADE_BIT)) $(BITS_DIR)/release
	@echo "# Created upgrade bits:"
	@ls -1 $(UPGRADE_BIT)
	@echo ""

BOOT_BIT=$(BITS_DIR)/release/boot-$(_usbheadnode_stamp).tgz

.PHONY: boot
boot: $(BOOT_BIT)

$(BOOT_BIT): $(BITS_DIR)/platform-$(TIMESTAMP).tgz
	@echo "# Build boot: usb-headnode branch $(USBHEADNODE_BRANCH), sha $(USBHEADNODE_SHA)"
	mkdir -p $(BITS_DIR)/release
	./tools/build-usb-headnode $(TIMESTAMP) $(BITS_DIR) -c tar
	mv build/usb-headnode/$(shell basename $(BOOT_BIT)) $(BITS_DIR)/release
	@echo "# Created boot bits:"
	@ls -1 $(BOOT_BIT)
	@echo ""


RELEASEJSON_BIT=$(BITS_DIR)/release/release.json

.PHONY: boot
releasejson:
	mkdir -p $(BITS_DIR)/release
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

PLATFORM_BIT=$(BITS_DIR)/platform-$(TIMESTAMP).tgz

.PHONY: platform
platform: $(PLATFORM_BIT)

# PATH: Ensure using GCC from SFW as require for platform build.
$(PLATFORM_BIT):
ifeq ($(BUILD_PLATFORM),true)
	@echo "# Build platform: branch $(PLATFORM_BRANCH), sha $(PLATFORM_SHA)"
	(cd build/illumos-live && PATH=/usr/sfw/bin:$(PATH) ./configure && PATH=/usr/sfw/bin:$(PATH) BUILDSTAMP=$(TIMESTAMP) gmake world && PATH=/usr/sfw/bin:$(PATH) BUILDSTAMP=$(TIMESTAMP) gmake live)
	(mkdir -p $(BITS_DIR)/)
	(cp build/illumos-live/output/platform-$(TIMESTAMP).tgz $(BITS_DIR)/)
	@echo "# Created platform bits:"
	@ls -1 $(PLATFORM_BIT)
	@echo ""
endif

clean_platform:
	rm -f $(BITS_DIR)/platform-*
	(cd build/illumos-live && gmake clean)

upload_platform:
	./tools/upload-bits -f "$(PLATFORM_BIT)" $(PLATFORM_BRANCH) $(TIMESTAMP) $(UPLOAD_LOCATION)/platform

#---- misc targets

clean_null:

#TODO: also "build", but not yet
.PHONY: distclean
distclean:
	pfexec rm -rf bits build


# Upload bits we want to keep for a nightly build.
# Note: hardcoding to "$USBHEADNODE_BRANCH" here isn't ideal.
upload_nightly:
	./tools/upload-bits $(USBHEADNODE_BRANCH) $(TIMESTAMP) $(UPLOAD_LOCATION)/nightly

