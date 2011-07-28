
#---- Config

include config.mk

TIMESTAMP=$(shell TZ=UTC date "+%Y%m%dT%H%M%SZ")

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


#---- Primary targets



#---- smartlogin

SMARTLOGIN_BUILDSTAMP=$(SMARTLOGIN_BRANCH)-$(TIMESTAMP)-$(SMARTLOGIN_SHA)

# Notes: Re-instate 'gmake lint'?
smartlogin: build/smartlogin $(BITS_DIR)
	@echo "# Build smartlogin $(SMARTLOGIN_BUILDSTAMP)."
	(cd build/smartlogin && BUILDSTAMP=$(SMARTLOGIN_BUILDSTAMP) BITS_DIR=$(BITS_DIR) gmake clean all publish)



#---- agents
# Bamboo does: ./build.sh -p -n -l /rpool/data/coal/releases/2011-07-14/deps/
#
# src_agents:
# 	git config core.autocrlf false

AGENTS_BUILDSTAMP=$(AGENTS_BRANCH)-$(TIMESTAMP)-$(AGENTS_SHA)

agents: build/agents $(BITS_DIR)
	@echo "# Build agents $(AGENTS_BUILDSTAMP)."
	(cd build/agents && BUILDSTAMP=$(SMARTLOGIN_BUILDSTAMP) ./build.sh -p -n -l $(BITS_DIR))



#---- misc targets

info:
	@echo "TIMESTAMP: $(TIMESTAMP)"
	@echo "BITS_DIR: $(BITS_DIR)"
	@echo "SMARTLOGIN_BUILDSTAMP: $(SMARTLOGIN_BUILDSTAMP)"


$(BITS_DIR):
	mkdir -p $(BITS_DIR)


