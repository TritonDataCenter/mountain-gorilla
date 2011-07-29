
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
	@ls $(SMARTLOGIN_BITS)
	@echo ""



#---- agents
# Bamboo does: ./build.sh -p -n -l /rpool/data/coal/releases/2011-07-14/deps/
#
# src_agents:
# 	git config core.autocrlf false

_stamp=$(AGENTS_BRANCH)-$(TIMESTAMP)-g$(AGENTS_SHA)-dirty
AGENTS_BITS=$(BITS_DIR)/heartbeater/heartbeater-$(_stamp).tgz \
	$(BITS_DIR)/atropos/atropos-$(_stamp).tgz \
	$(BITS_DIR)/metadata/metadata-$(_stamp).tgz \
	$(BITS_DIR)/dataset_manager/dataset_manager-$(_stamp).tgz \
	$(BITS_DIR)/zonetracker/zonetracker-$(_stamp).tgz \
	$(BITS_DIR)/provisioner-v2/provisioner-v2-$(_stamp).tgz \
	$(BITS_DIR)/zonetracker-v2/zonetracker-v2-$(_stamp).tgz \
	$(BITS_DIR)/mock_cloud/mock_cloud-$(_stamp).tgz

agents: $(AGENTS_BITS)

$(AGENTS_BITS): build/agents
	@echo "# Build agents: branch $(AGENTS_BRANCH), sha $(AGENTS_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/agents && TIMESTAMP=$(TIMESTAMP) ./build.sh -p -n -l $(BITS_DIR))
	@echo "# Created agents bits:"
	@ls $(AGENTS_BITS)
	@echo ""



#---- cloud-analytics
# Bamboo does:
# 	./bamboo/build.sh
# 	PATH="/sbin:/opt/local/bin:/usr/gnu/bin:/usr/bin:/usr/sbin:$PATH" JOBS=16
#
#TODO:
# - add BUILDSTAMP support
# - explain why the PATH order is necessary here
# - look at https://hub.joyent.com/wiki/display/dev/Setting+up+Cloud+Analytics+development+on+COAL-147
#   for env setup. Might be demons in there.
# - add {.lock-wscript,build} to .gititnore for 
#   node-kstat
#   node-libGeoIP
#   node-libdtrace
#   node-png
#   node-uname

CA_BUILDSTAMP=$(CA_BRANCH)-$(TIMESTAMP)-$(CA_SHA)

ca: build/ca
	@echo "# Build ca $(CA_BUILDSTAMP)."
	mkdir -p $(BITS_DIR)
	(cd build/ca && BUILDSTAMP=$(CA_BUILDSTAMP) BITS_DIR=$(BITS_DIR) PATH="/sbin:/opt/local/bin:/usr/gnu/bin:/usr/bin:/usr/sbin:$PATH" gmake pkg release publish)



#---- agents shar
# Bamboo does:
# 	JOBS=12 COAL_PUBLISH=1
# 	./build_scripts -l /rpool/data/coal/releases/2011-07-14/deps/
#
# TODO:
# - pass in TIMESTAMP so know expected file
# - how (if at all) to encode deps on ca, agents and smartlogin?

agentsshar: build/agents-installer
	@echo "# Build '$(AGENTSSHAR_BRANCH)' agentsshar."
	mkdir -p $(BITS_DIR)/ur-scripts
	(cd build/agents-installer && ./mk-agents-shar -o $(BITS_DIR)/ur-scripts -d $(BITS_DIR) -b $(AGENTSSHAR_BRANCH))




#---- misc targets


