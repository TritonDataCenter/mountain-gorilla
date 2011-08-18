
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


#---- Primary targets

.PHONY: all
all: smartlogin ca agents agentsshar platform usb-headnode


#---- smartlogin
# TODO:
# - Re-instate 'gmake lint'?

SMARTLOGIN_BITS=$(BITS_DIR)/smartlogin/smartlogin-$(SMARTLOGIN_BRANCH)-$(TIMESTAMP)-g$(SMARTLOGIN_SHA).tgz

.PHONY: smartlogin
smartlogin: $(SMARTLOGIN_BITS)

$(SMARTLOGIN_BITS): build/smartlogin
	@echo "# Build smartlogin: branch $(SMARTLOGIN_BRANCH), sha $(SMARTLOGIN_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/smartlogin && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake clean all publish)
	@echo "# Created smartlogin bits:"
	@ls -1 $(SMARTLOGIN_BITS)
	@echo ""



#---- agents

_a_stamp=$(AGENTS_BRANCH)-$(TIMESTAMP)-g$(AGENTS_SHA)
AGENTS_BITS=$(BITS_DIR)/heartbeater/heartbeater-$(_a_stamp).tgz \
	$(BITS_DIR)/atropos/atropos-$(_a_stamp).tgz \
	$(BITS_DIR)/metadata/metadata-$(_a_stamp).tgz \
	$(BITS_DIR)/dataset_manager/dataset_manager-$(_a_stamp).tgz \
	$(BITS_DIR)/zonetracker/zonetracker-$(_a_stamp).tgz \
	$(BITS_DIR)/provisioner-v2/provisioner-v2-$(_a_stamp).tgz \
	$(BITS_DIR)/zonetracker-v2/zonetracker-v2-$(_a_stamp).tgz \
	$(BITS_DIR)/mock_cloud/mock_cloud-$(_a_stamp).tgz

agents: $(AGENTS_BITS)

$(AGENTS_BITS): build/agents
	@echo "# Build agents: branch $(AGENTS_BRANCH), sha $(AGENTS_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/agents && TIMESTAMP=$(TIMESTAMP) ./build.sh -p -n -l $(BITS_DIR))
	@echo "# Created agents bits:"
	@ls -1 $(AGENTS_BITS)
	@echo ""



#---- cloud-analytics
#TODO:
# - add {.lock-wscript,build} to .gititnore for 
#   node-kstat
#   node-libGeoIP
#   node-libdtrace
#   node-png
#   node-uname
# - merge CA_VERSION and CA_PUBLISH_VERSION? what about the version sed'd into
#   the package.json's?
# - explain why the PATH order is necessary here
# - look at https://hub.joyent.com/wiki/display/dev/Setting+up+Cloud+Analytics+development+on+COAL-147
#   for env setup. Might be demons in there.

_ca_stamp=$(CA_BRANCH)-$(TIMESTAMP)-g$(CA_SHA)*
CA_BITS=$(BITS_DIR)/assets/ca-pkg-$(_ca_stamp).tar.bz2 \
	$(BITS_DIR)/cloud_analytics/cabase-$(_ca_stamp).tar.gz \
	$(BITS_DIR)/cloud_analytics/cainstsvc-$(_ca_stamp).tar.gz

.PHONY: ca
ca: $(CA_BITS)

$(CA_BITS): build/ca
	@echo "# Build ca: branch $(CA_BRANCH), sha $(CA_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/ca && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) PATH="/sbin:/opt/local/bin:/usr/gnu/bin:/usr/bin:/usr/sbin:$PATH" gmake pkg release publish)
	@echo "# Created ca bits:"
	@ls -1 $(CA_BITS)
	@echo ""



#---- agents shar

_as_stamp=$(AGENTSSHAR_BRANCH)-$(TIMESTAMP)-g$(AGENTSSHAR_SHA)
AGENTSSHAR_BITS=$(BITS_DIR)/ur-scripts/agents-$(_as_stamp).sh \
	$(BITS_DIR)/ur-scripts/agents-$(_as_stamp).md5sum

.PHONY: agentsshar
agentsshar: $(AGENTSSHAR_BITS)

$(AGENTSSHAR_BITS): build/agents-installer
	@echo "# Build agentsshar: branch $(AGENTSSHAR_BRANCH), sha $(AGENTSSHAR_SHA)"
	mkdir -p $(BITS_DIR)/ur-scripts
	(cd build/agents-installer && TIMESTAMP=$(TIMESTAMP) ./mk-agents-shar -o $(BITS_DIR)/ur-scripts -d $(BITS_DIR) -b $(AGENTSSHAR_BRANCH))
	@echo "# Created agentsshar bits:"
	@ls -1 $(AGENTSSHAR_BITS)
	@echo ""


#---- usb-headnode
# TODO:
# - add GITDESCRIBE
# - usb, boot, upgrade
# - "assets/" bits area for atropos is dumb (use atropos). more dumb for ca-pkg
#   (use cloud_analytics)
#
# - configure
# - solution for datasets
# - source packages (quick hack with "MAPI_DIR" et al?)
# - punt on having coal timestamp be the platform timestamp and use given or curr timestamp? Ask
#   Jerry/Josh and others about need for this.
# - pkgsrc isolation

COAL_BIT=$(BITS_DIR)/release/coal-$(USBHEADNODE_BRANCH)-$(TIMESTAMP)-4gb.tgz

.PHONY: coal
coal: $(COAL_BIT)

$(COAL_BIT): $(BITS_DIR)/platform-$(TIMESTAMP).tgz
	@echo "# Build coal: usb-headnode branch $(USBHEADNODE_BRANCH), sha $(USBHEADNODE_SHA)"
	ps -ef | grep 'python -m Simple[H]TTPServer' | awk '{print $$2}' | xargs kill 2>/dev/null || true
	(cd $(BITS_DIR); python -m SimpleHTTPServer)&

	mkdir -p $(BITS_DIR)/release
	(cd build/usb-headnode && MASTER_PLATFORM_URL=http://localhost:8000 PLATFORM_FILE=$(BITS_DIR)/platform-$(TIMESTAMP).tgz ZONE_DIR=$(TOP)/build ./bin/build-image -c coal)

	@ps -ef | grep 'python -m Simple[H]TTPServer' | awk '{print $$2}' | xargs kill 2>/dev/null || true
	mv build/usb-headnode/$(shell basename $(COAL_BIT)) $(BITS_DIR)/release
	@echo "# Created coal bits:"
	@ls -1 $(COAL_BIT)
	@echo ""

.PHONY: usb-headnode
usb-headnode: coal

#---- platform
.PHONY: platform
platform: $(BITS_DIR)/platform-$(TIMESTAMP).tgz

$(BITS_DIR)/platform-$(TIMESTAMP).tgz:
ifeq ($(BUILD_PLATFORM),true)
	@echo "Building platform"
	(cd build/illumos-live && ./configure && BUILDSTAMP=$(TIMESTAMP) gmake world && BUILDSTAMP=$(TIMESTAMP) gmake live)
	(cp build/illumos-live/output/platform-$(TIMESTAMP).tgz $(BITS_DIR)/)
endif

#---- misc targets

#TODO: also "build", but not yet
.PHONY: distclean
distclean:
	rm -rf bits

