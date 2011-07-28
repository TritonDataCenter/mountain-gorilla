
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

SMARTLOGIN_BUILDSTAMP=$(SMARTLOGIN_BRANCH)-${TIMESTAMP}-${SMARTLOGIN_SHA}
SMARTLOGIN_PKG=$(BITS_DIR)/smartlogin/smartlogin-$(SMARTLOGIN_BUILDSTAMP).tgz

smartlogin: $(SMARTLOGIN_PKG)

# Notes: Re-instate 'gmake lint'?
$(SMARTLOGIN_PKG): build/smartlogin $(BITS_DIR)
	@echo "# Build smartlogin $(SMARTLOGIN_BUILDSTAMP)."
	(cd build/smartlogin && BUILDSTAMP=$(SMARTLOGIN_BUILDSTAMP) BITS_DIR=$(BITS_DIR) gmake clean all publish)



#---- misc targets

info:
	@echo "TIMESTAMP: $(TIMESTAMP)"
	@echo "BITS_DIR: $(BITS_DIR)"
	@echo "SMARTLOGIN_BUILDSTAMP: $(SMARTLOGIN_BUILDSTAMP)"


$(BITS_DIR):
	mkdir -p $(BITS_DIR)


