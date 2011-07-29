
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
ifeq ($(TIMESTAMP),)
    TIMESTAMP=$(shell TZ=UTC date "+%Y%m%dT%H%M%SZ")
endif
# Is JOBS=16 reasonable here? The old bamboo plans used this (or higher).
JOB=16


#---- Primary targets



#---- smartlogin
# TODO:
# - Re-instate 'gmake lint'?

SMARTLOGIN_BITS=$(BITS_DIR)/smartlogin/smartlogin-$(SMARTLOGIN_BRANCH)-$(TIMESTAMP)-g$(SMARTLOGIN_SHA).tgz

smartlogin: $(SMARTLOGIN_BITS)

$(SMARTLOGIN_BITS): build/smartlogin
	@echo "# Build smartlogin: branch $(SMARTLOGIN_BRANCH), sha $(SMARTLOGIN_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/smartlogin && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake clean all publish)
	@echo "# Created smartlogin bits:"
	@ls -1 $(SMARTLOGIN_BITS)
	@echo ""



#---- agents
# Bamboo does: ./build.sh -p -n -l /rpool/data/coal/releases/2011-07-14/deps/
#
# src_agents:
# 	git config core.autocrlf false

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

_ca_stamp=$(CA_BRANCH)-$(TIMESTAMP)-g$(CA_SHA)-dirty
CA_BITS=$(BITS_DIR)/cloud_analytics/ca-pkg-$(_ca_stamp).tar.bz2 \
	$(BITS_DIR)/cloud_analytics/cabase-$(_ca_stamp).tar.gz \
	$(BITS_DIR)/cloud_analytics/cainstsvc-$(_ca_stamp).tar.gz \

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

agentsshar: $(AGENTSSHAR_BITS)

$(AGENTSSHAR_BITS): build/agents-installer
	@echo "# Build agentsshar: branch $(AGENTSSHAR_BRANCH), sha $(AGENTSSHAR_SHA)"
	mkdir -p $(BITS_DIR)/ur-scripts
	(cd build/agents-installer && TIMESTAMP=$(TIMESTAMP) ./mk-agents-shar -o $(BITS_DIR)/ur-scripts -d $(BITS_DIR) -b $(AGENTSSHAR_BRANCH))
	@echo "# Created agentsshar bits:"
	@ls -1 $(AGENTSSHAR_BITS)
	@echo ""




#---- misc targets

#TODO: "build", but not yet
distclean:
	rm -rf bits

