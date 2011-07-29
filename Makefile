
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

$(SMARTLOGIN_BITS): build/smartlogin $(BITS_DIR)
	@echo "# Build smartlogin: branch $(SMARTLOGIN_BRANCH), sha $(SMARTLOGIN_SHA)"
	(cd build/smartlogin && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake clean all publish)
	@echo "# Created smartlogin bits:"
	@ls $(SMARTLOGIN_BITS)
	@echo ""



#---- agents
# Bamboo does: ./build.sh -p -n -l /rpool/data/coal/releases/2011-07-14/deps/
#
# src_agents:
# 	git config core.autocrlf false

AGENTS_BUILDSTAMP=$(AGENTS_BRANCH)-$(TIMESTAMP)-$(AGENTS_SHA)

#TODO:
# - drop the "$branch" dir in bits for these on publish
# - support BUILDSTAMP in build.sh
agents: build/agents $(BITS_DIR)
	@echo "# Build agents $(AGENTS_BUILDSTAMP)."
	(cd build/agents && BUILDSTAMP=$(AGENTS_BUILDSTAMP) ./build.sh -p -n -l $(BITS_DIR))



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

ca: build/ca $(BITS_DIR)
	@echo "# Build ca $(CA_BUILDSTAMP)."
	(cd build/ca && BUILDSTAMP=$(CA_BUILDSTAMP) BITS_DIR=$(BITS_DIR) PATH="/sbin:/opt/local/bin:/usr/gnu/bin:/usr/bin:/usr/sbin:$PATH" gmake pkg release publish)



#---- agents shar
# Bamboo does:
# 	JOBS=12 COAL_PUBLISH=1
# 	./build_scripts -l /rpool/data/coal/releases/2011-07-14/deps/
#
# TODO:
# - pass in TIMESTAMP so know expected file
# - how (if at all) to encode deps on ca, agents and smartlogin?

agentsshar: build/agents-installer $(BITS_DIR)
	@echo "# Build '$(AGENTSSHAR_BRANCH)' agentsshar."
	mkdir -p $(BITS_DIR)/ur-scripts
	(cd build/agents-installer && ./mk-agents-shar -o $(BITS_DIR)/ur-scripts -d $(BITS_DIR) -b $(AGENTSSHAR_BRANCH))




#---- misc targets

info:
	@echo "TIMESTAMP: $(TIMESTAMP)"
	@echo "BITS_DIR: $(BITS_DIR)"
	@echo "SMARTLOGIN_BUILDSTAMP: $(SMARTLOGIN_BUILDSTAMP)"


$(BITS_DIR):
	mkdir -p $(BITS_DIR)


