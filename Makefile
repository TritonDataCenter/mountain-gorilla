#
# Mountain Gorilla Makefile. See "README.md".
#
# Environment variables used:
#
# - JOB_NAME (typically set by the Jenkins jobs that run this) is used for
#   some targets.
# - UPLOAD_SUBDIRS can be used to specify extra bits subdirs to upload
#   in the "upload_jenkins" target.
# ...
#

#---- Config

include bits/config.mk

# Directories
TOP := $(shell pwd)
BUILD_DIR=$(TOP)/build
BITS_DIR=$(TOP)/bits

# Tools
MAKE = make
TAR = tar
RM = rm
UNAME := $(shell uname)
PFEXEC =
ifeq ($(UNAME), SunOS)
	MAKE = gmake
	TAR = gtar
	PFEXEC = pfexec
	RM = grm
endif
JSON=$(MG_NODE) $(TOP)/tools/json
UPDATES_IMGADM=$(HOME)/opt/imgapi-cli/bin/updates-imgadm -i $(HOME)/.ssh/automation.id_rsa -u mg

# Other
# Is JOBS=16 reasonable here? The old bamboo plans used this (or higher).
JOB=16

# A TIMESTAMP to use must be defined (and typically is in 'bits/config.mk').
#
# At one point we'd just generate TIMESTAMP at the top of the Makefile, but
# that seemed to hit a gmake issue when building multiple targets: the 'ca'
# target would be run three times at (rougly) 4 seconds apart on the time
# stamp (guessing the 'three times' is because CA_BITS has three elements).
ifeq ($(TIMESTAMP),)
	TIMESTAMP=TimestampNotSet
endif

ifeq ($(UPLOAD_LOCATION),)
	UPLOAD_LOCATION=bits@bits.joyent.us:builds
endif

ifeq ($(MANTA_UPLOAD_BASE),)
	MANTA_UPLOAD_BASE=builds
endif

#
# This is set to true by the caller when, and only when, building the a
# Joyent product.  Doing so causes the inclusion of ancillary repositories that
# cannot be made publicly available.
#
JOYENT_BUILD ?= false

ifeq ($(JOYENT_BUILD),true)
	FIRMWARE_TOOLS=firmware-tools
endif

#---- Primary targets

.PHONY: all
all: smartlogin incr-upgrade amon amonredis ca agents_core heartbeater zonetracker provisioner sdcadm agentsshar assets adminui redis rabbitmq dhcpd mockcn usageapi cloudapi sdc-workflow sdc-manatee manta-manatee manatee mahi imgapi sdc sdc-system-tests cnapi vmapi fwapi papi napi sapi binder mako moray electric-moray registrar ufds platform usbheadnode minnow mola mackerel madtom marlin-dashboard config-agent sdcboot manta-deployment $(FIRMWARE_TOOLS) hagfish-watcher firewaller propeller

.PHONY: all-except-platform
all-except-platform: smartlogin incr-upgrade amon amonredis ca agents_core heartbeater zonetracker provisioner sdcadm agentsshar assets adminui redis rabbitmq dhcpd mockcn usageapi cloudapi sdc-workflow sdc-manatee manta-manatee manatee mahi imgapi sdc sdc-system-tests cnapi vmapi fwapi papi napi sapi binder mako registrar moray electric-moray ufds usbheadnode minnow mola mackerel madtom marlin-dashboard config-agent sdcboot manta-deployment $(FIRMWARE_TOOLS) hagfish-watcher firewaller propeller


#---- smartlogin
# TODO:
# - Re-instate 'gmake lint'?

SMARTLOGIN_BIT=$(BITS_DIR)/smartlogin/smartlogin-$(SMART_LOGIN_BRANCH)-$(TIMESTAMP)-g$(SMART_LOGIN_SHA).tgz
SMARTLOGIN_MANIFEST_BIT=$(BITS_DIR)/smartlogin/smartlogin-$(SMART_LOGIN_BRANCH)-$(TIMESTAMP)-g$(SMART_LOGIN_SHA).manifest

.PHONY: smartlogin
smartlogin: $(SMARTLOGIN_BIT)

# PATH: ensure using GCC from SFW. Not sure this is necessary, but has been
# the case for release builds pre-MG.
$(SMARTLOGIN_BIT): build/smart-login
	@echo "# Build smartlogin: branch $(SMART_LOGIN_BRANCH), sha $(SMART_LOGIN_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/smart-login && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) PATH=/usr/sfw/bin:$(PATH) BITS_DIR=$(BITS_DIR) gmake clean all publish)
	@echo "# Created smartlogin bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(SMARTLOGIN_BIT)
	@echo ""

smartlogin_publish_image: $(SMARTLOGIN_BIT)
	@echo "# Publish smartlogin image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(SMARTLOGIN_MANIFEST_BIT) -f $(SMARTLOGIN_BIT)

clean_smartlogin:
	$(RM) -rf $(BITS_DIR)/smartlogin



#---- incr-upgrade

_incr_upgrade_stamp=$(USB_HEADNODE_BRANCH)-$(TIMESTAMP)-g$(USB_HEADNODE_SHA)
INCR_UPGRADE_BITS=$(BITS_DIR)/incr-upgrade/incr-upgrade-$(_incr_upgrade_stamp).tgz

.PHONY: incr-upgrade
incr-upgrade: $(INCR_UPGRADE_BITS)

$(INCR_UPGRADE_BITS): build/usb-headnode
	@echo "# Build incr-upgrade: branch $(USB_HEADNODE_BRANCH), sha $(USB_HEADNODE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/usb-headnode && BRANCH="" TIMESTAMP=$(TIMESTAMP) gmake incr-upgrade)
	mkdir -p $(BITS_DIR)/incr-upgrade
	cp build/usb-headnode/incr-upgrade-$(_incr_upgrade_stamp).tgz $(BITS_DIR)/incr-upgrade
	@echo "# Created incr-upgrade bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(INCR_UPGRADE_BITS)
	@echo ""

clean_incr-upgrade:
	$(RM) -rf $(BITS_DIR)/incr-upgrade



#---- amon

_amon_stamp=$(AMON_BRANCH)-$(TIMESTAMP)-g$(AMON_SHA)
AMON_BITS=$(BITS_DIR)/amon/amon-pkg-$(_amon_stamp).tar.bz2 \
	$(BITS_DIR)/amon/amon-relay-$(_amon_stamp).tgz \
	$(BITS_DIR)/amon/amon-agent-$(_amon_stamp).tgz
AMON_BITS_0=$(shell echo $(AMON_BITS) | awk '{print $$1}')
AMON_IMAGE_BIT=$(BITS_DIR)/amon/amon-zfs-$(_amon_stamp).zfs.gz
AMON_MANIFEST_BIT=$(BITS_DIR)/amon/amon-zfs-$(_amon_stamp).imgmanifest
AMON_AGENT_BIT=$(BITS_DIR)/amon/amon-agent-$(_amon_stamp).tgz
AMON_AGENT_MANIFEST_BIT=$(BITS_DIR)/amon/amon-agent-$(_amon_stamp).manifest
AMON_RELAY_BIT=$(BITS_DIR)/amon/amon-relay-$(_amon_stamp).tgz
AMON_RELAY_MANIFEST_BIT=$(BITS_DIR)/amon/amon-relay-$(_amon_stamp).manifest

.PHONY: amon
amon: $(AMON_BITS_0) amon_image

$(AMON_BITS): build/amon
	@echo "# Build amon: branch $(AMON_BRANCH), sha $(AMON_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/amon && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake clean all pkg publish)
	@echo "# Created amon bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(AMON_BITS)
	@echo ""

.PHONY: amon_image
amon_image: $(AMON_IMAGE_BIT)

$(AMON_IMAGE_BIT): $(AMON_BITS_0)
	@echo "# Build amon_image: branch $(AMON_BRANCH), sha $(AMON_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(AMON_IMAGE_UUID)" -t $(AMON_BITS_0) \
		-o "$(AMON_IMAGE_BIT)" -p $(AMON_PKGSRC) \
		-t $(AMON_EXTRA_TARBALLS) -n $(AMON_IMAGE_NAME) \
		-v $(_amon_stamp) -d $(AMON_IMAGE_DESCRIPTION)
	@echo "# Created amon image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(AMON_IMAGE_BIT))
	@echo ""

amon_publish_image: $(AMON_IMAGE_BIT)
	@echo "# Publish amon images to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(AMON_MANIFEST_BIT) -f $(AMON_IMAGE_BIT)
	$(UPDATES_IMGADM) import -ddd -m $(AMON_AGENT_MANIFEST_BIT) -f $(AMON_AGENT_BIT)
	$(UPDATES_IMGADM) import -ddd -m $(AMON_RELAY_MANIFEST_BIT) -f $(AMON_RELAY_BIT)

clean_amon:
	$(RM) -rf $(BITS_DIR)/amon
	(cd build/amon && gmake clean)

#---- cloud-analytics
#TODO:
# - merge CA_VERSION and CA_PUBLISH_VERSION? what about the version sed'd into
#   the package.json's?
# - look at https://hub.joyent.com/wiki/display/dev/Setting+up+Cloud+Analytics+development+on+COAL-147
#   for env setup. Might be demons in there. (RELENG-192)

_ca_stamp=$(CLOUD_ANALYTICS_BRANCH)-$(TIMESTAMP)-g$(CLOUD_ANALYTICS_SHA)
CA_BITS=$(BITS_DIR)/ca/ca-pkg-$(_ca_stamp).tar.bz2 \
	$(BITS_DIR)/ca/cabase-$(_ca_stamp).tar.gz \
	$(BITS_DIR)/ca/cainstsvc-$(_ca_stamp).tar.gz
CA_BITS_0=$(shell echo $(CA_BITS) | awk '{print $$1}')
CA_IMAGE_BIT=$(BITS_DIR)/ca/ca-zfs-$(_ca_stamp).zfs.gz
CA_MANIFEST_BIT=$(BITS_DIR)/ca/ca-zfs-$(_ca_stamp).imgmanifest
CA_BASE_BIT=$(BITS_DIR)/ca/cabase-$(_ca_stamp).tar.gz
CA_BASE_MANIFEST_BIT=$(BITS_DIR)/ca/cabase-$(_ca_stamp).manifest
CA_INSTSVC_BIT=$(BITS_DIR)/ca/cainstsvc-$(_ca_stamp).tar.gz
CA_INSTSVC_MANIFEST_BIT=$(BITS_DIR)/ca/cainstsvc-$(_ca_stamp).manifest

.PHONY: ca
ca: $(CA_BITS_0) ca_image

# PATH for ca build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(CA_BITS): build/cloud-analytics
	@echo "# Build ca: branch $(CLOUD_ANALYTICS_BRANCH), sha $(CLOUD_ANALYTICS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/cloud-analytics && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) PATH="/sbin:/opt/local/bin:/usr/gnu/bin:/usr/bin:/usr/sbin:$(PATH)" gmake clean pkg release publish)
	@echo "# Created ca bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(CA_BITS)
	@echo ""

.PHONY: ca_image
ca_image: $(CA_IMAGE_BIT)

$(CA_IMAGE_BIT): $(CA_BITS_0)
	@echo "# Build ca_image: branch $(CA_BRANCH), sha $(CA_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(CA_IMAGE_UUID)" -t $(CA_BITS_0) \
		-o "$(CA_IMAGE_BIT)" -p $(CA_PKGSRC) \
		-t $(CA_EXTRA_TARBALLS) -n $(CA_IMAGE_NAME) \
		-v $(_ca_stamp) -d $(CA_IMAGE_DESCRIPTION)
	@echo "# Created ca image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(CA_IMAGE_BIT))
	@echo ""

ca_publish_image: $(CA_IMAGE_BIT)
	@echo "# Publish ca images to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(CA_MANIFEST_BIT) -f $(CA_IMAGE_BIT)
	$(UPDATES_IMGADM) import -ddd -m $(CA_BASE_MANIFEST_BIT) -f $(CA_BASE_BIT)
	$(UPDATES_IMGADM) import -ddd -m $(CA_INSTSVC_MANIFEST_BIT) -f $(CA_INSTSVC_BIT)

# Warning: if CA's submodule deps change, this 'clean_ca' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_ca:
	$(RM) -rf $(BITS_DIR)/ca
	(cd build/cloud-analytics && gmake clean)



#---- UFDS


_ufds_stamp=$(UFDS_BRANCH)-$(TIMESTAMP)-g$(UFDS_SHA)
UFDS_BITS=$(BITS_DIR)/ufds/ufds-pkg-$(_ufds_stamp).tar.bz2
UFDS_IMAGE_BIT=$(BITS_DIR)/ufds/ufds-zfs-$(_ufds_stamp).zfs.gz
UFDS_MANIFEST_BIT=$(BITS_DIR)/ufds/ufds-zfs-$(_ufds_stamp).imgmanifest

.PHONY: ufds
ufds: $(UFDS_BITS) ufds_image

# PATH for ufds build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(UFDS_BITS): build/ufds
	@echo "# Build ufds: branch $(UFDS_BRANCH), sha $(UFDS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/ufds && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake pkg release publish)
	@echo "# Created ufds bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(UFDS_BITS)
	@echo ""

.PHONY: ufds_image
ufds_image: $(UFDS_IMAGE_BIT)

$(UFDS_IMAGE_BIT): $(UFDS_BITS)
	@echo "# Build ufds_image: branch $(UFDS_BRANCH), sha $(UFDS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(UFDS_IMAGE_UUID)" -t $(UFDS_BITS) \
		-o "$(UFDS_IMAGE_BIT)" -p $(UFDS_PKGSRC) \
		-t $(UFDS_EXTRA_TARBALLS) -n $(UFDS_IMAGE_NAME) \
		-v $(_ufds_stamp) -d $(UFDS_IMAGE_DESCRIPTION)
	@echo "# Created ufds image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(UFDS_IMAGE_BIT))
	@echo ""

ufds_publish_image: $(UFDS_IMAGE_BIT)
	@echo "# Publish ufds image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(UFDS_MANIFEST_BIT) -f $(UFDS_IMAGE_BIT)

# Warning: if UFDS's submodule deps change, this 'clean_ufds' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_ufds:
	$(RM) -rf $(BITS_DIR)/ufds
	(cd build/ufds && gmake clean)


#---- usageapi

_usageapi_stamp=$(USAGEAPI_BRANCH)-$(TIMESTAMP)-g$(USAGEAPI_SHA)
USAGEAPI_BITS=$(BITS_DIR)/usageapi/usageapi-pkg-$(_usageapi_stamp).tar.bz2
USAGEAPI_IMAGE_BIT=$(BITS_DIR)/usageapi/usageapi-zfs-$(_usageapi_stamp).zfs.gz
USAGEAPI_MANIFEST_BIT=$(BITS_DIR)/usageapi/usageapi-zfs-$(_usageapi_stamp).imgmanifest

.PHONY: usageapi
usageapi: $(USAGEAPI_BITS) usageapi_image

# PATH for ufds build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(USAGEAPI_BITS): build/usageapi
	@echo "# Build usageapi: branch $(USAGEAPI_BRANCH), sha $(USAGEAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/usageapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake pkg release publish)
	@echo "# Created usageapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(USAGEAPI_BITS)
	@echo ""

.PHONY: usageapi_image
usageapi_image: $(USAGEAPI_IMAGE_BIT)

$(USAGEAPI_IMAGE_BIT): $(USAGEAPI_BITS)
	@echo "# Build usageapi_image: branch $(USAGEAPI_BRANCH), sha $(USAGEAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(USAGEAPI_IMAGE_UUID)" -t $(USAGEAPI_BITS) \
		-o "$(USAGEAPI_IMAGE_BIT)" -p $(USAGEAPI_PKGSRC) \
		-t $(USAGEAPI_EXTRA_TARBALLS) -n $(USAGEAPI_IMAGE_NAME) \
		-v $(_usageapi_stamp) -d $(USAGEAPI_IMAGE_DESCRIPTION)
	@echo "# Created usageapi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(USAGEAPI_IMAGE_BIT))
	@echo ""

usageapi_publish_image: $(USAGEAPI_IMAGE_BIT)
	@echo "# Publish usageapi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(USAGEAPI_MANIFEST_BIT) -f $(USAGEAPI_IMAGE_BIT)


# Warning: if usageapi's submodule deps change, this 'clean_ufds' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_usageapi:
	$(RM) -rf $(BITS_DIR)/usageapi
	(cd build/usageapi && gmake clean)


#---- ASSETS

_assets_stamp=$(ASSETS_BRANCH)-$(TIMESTAMP)-g$(ASSETS_SHA)
ASSETS_BITS=$(BITS_DIR)/assets/assets-pkg-$(_assets_stamp).tar.bz2
ASSETS_IMAGE_BIT=$(BITS_DIR)/assets/assets-zfs-$(_assets_stamp).zfs.gz
ASSETS_MANIFEST_BIT=$(BITS_DIR)/assets/assets-zfs-$(_assets_stamp).imgmanifest

.PHONY: assets
assets: $(ASSETS_BITS) assets_image

$(ASSETS_BITS): build/assets
	@echo "# Build assets: branch $(ASSETS_BRANCH), sha $(ASSETS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/assets && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created assets bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(ASSETS_BITS)
	@echo ""

.PHONY: assets_image
assets_image: $(ASSETS_IMAGE_BIT)

$(ASSETS_IMAGE_BIT): $(ASSETS_BITS)
	@echo "# Build assets_image: branch $(ASSETS_BRANCH), sha $(ASSETS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(ASSETS_IMAGE_UUID)" -t $(ASSETS_BITS) \
		-o "$(ASSETS_IMAGE_BIT)" -p $(ASSETS_PKGSRC) \
		-t $(ASSETS_EXTRA_TARBALLS) -n $(ASSETS_IMAGE_NAME) \
		-v $(_assets_stamp) -d $(ASSETS_IMAGE_DESCRIPTION)
	@echo "# Created assets image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(ASSETS_IMAGE_BIT))
	@echo ""

assets_publish_image: $(ASSETS_IMAGE_BIT)
	@echo "# Publish assets image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(ASSETS_MANIFEST_BIT) -f $(ASSETS_IMAGE_BIT)

clean_assets:
	$(RM) -rf $(BITS_DIR)/assets
	(cd build/assets && gmake clean)

#---- ADMINUI

_adminui_stamp=$(ADMINUI_BRANCH)-$(TIMESTAMP)-g$(ADMINUI_SHA)
ADMINUI_BITS=$(BITS_DIR)/adminui/adminui-pkg-$(_adminui_stamp).tar.bz2
ADMINUI_IMAGE_BIT=$(BITS_DIR)/adminui/adminui-zfs-$(_adminui_stamp).zfs.gz
ADMINUI_MANIFEST_BIT=$(BITS_DIR)/adminui/adminui-zfs-$(_adminui_stamp).imgmanifest

.PHONY: adminui
adminui: $(ADMINUI_BITS) adminui_image

$(ADMINUI_BITS): build/adminui
	@echo "# Build adminui: branch $(ADMINUI_BRANCH), sha $(ADMINUI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/adminui && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created adminui bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(ADMINUI_BITS)
	@echo ""

.PHONY: adminui_image
adminui_image: $(ADMINUI_IMAGE_BIT)

$(ADMINUI_IMAGE_BIT): $(ADMINUI_BITS)
	@echo "# Build adminui_image: branch $(ADMINUI_BRANCH), sha $(ADMINUI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(ADMINUI_IMAGE_UUID)" -t $(ADMINUI_BITS) \
		-o "$(ADMINUI_IMAGE_BIT)" -p $(ADMINUI_PKGSRC) \
		-t $(ADMINUI_EXTRA_TARBALLS) -n $(ADMINUI_IMAGE_NAME) \
		-v $(_adminui_stamp) -d $(ADMINUI_IMAGE_DESCRIPTION)
	@echo "# Created adminui image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(ADMINUI_IMAGE_BIT))
	@echo ""

adminui_publish_image: $(ADMINUI_IMAGE_BIT)
	@echo "# Publish adminui image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(ADMINUI_MANIFEST_BIT) -f $(ADMINUI_IMAGE_BIT)

clean_adminui:
	$(RM) -rf $(BITS_DIR)/adminui
	(cd build/adminui && gmake clean)


#---- REDIS

_redis_stamp=$(REDIS_BRANCH)-$(TIMESTAMP)-g$(REDIS_SHA)
REDIS_BITS=$(BITS_DIR)/redis/redis-pkg-$(_redis_stamp).tar.bz2
REDIS_IMAGE_BIT=$(BITS_DIR)/redis/redis-zfs-$(_redis_stamp).zfs.gz
REDIS_MANIFEST_BIT=$(BITS_DIR)/redis/redis-zfs-$(_redis_stamp).imgmanifest

.PHONY: redis
redis: $(REDIS_BITS) redis_image

$(REDIS_BITS): build/redis
	@echo "# Build redis: branch $(REDIS_BRANCH), sha $(REDIS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/redis && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created redis bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(REDIS_BITS)
	@echo ""

.PHONY: redis_image
redis_image: $(REDIS_IMAGE_BIT)

$(REDIS_IMAGE_BIT): $(REDIS_BITS)
	@echo "# Build redis_image: branch $(REDIS_BRANCH), sha $(REDIS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(REDIS_IMAGE_UUID)" -t $(REDIS_BITS) \
		-o "$(REDIS_IMAGE_BIT)" -p $(REDIS_PKGSRC) \
		-t $(REDIS_EXTRA_TARBALLS) -n $(REDIS_IMAGE_NAME) \
		-v $(_redis_stamp) -d $(REDIS_IMAGE_DESCRIPTION)
	@echo "# Created redis image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(REDIS_IMAGE_BIT))
	@echo ""

redis_publish_image: $(REDIS_IMAGE_BIT)
	@echo "# Publish redis image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(REDIS_MANIFEST_BIT) -f $(REDIS_IMAGE_BIT)

clean_redis:
	$(RM) -rf $(BITS_DIR)/redis
	(cd build/redis && gmake clean)


#---- amonredis

_amonredis_stamp=$(AMONREDIS_BRANCH)-$(TIMESTAMP)-g$(AMONREDIS_SHA)
AMONREDIS_BITS=$(BITS_DIR)/amonredis/amonredis-pkg-$(_amonredis_stamp).tar.bz2
AMONREDIS_IMAGE_BIT=$(BITS_DIR)/amonredis/amonredis-zfs-$(_amonredis_stamp).zfs.gz
AMONREDIS_MANIFEST_BIT=$(BITS_DIR)/amonredis/amonredis-zfs-$(_amonredis_stamp).imgmanifest

.PHONY: amonredis
amonredis: $(AMONREDIS_BITS) amonredis_image

$(AMONREDIS_BITS): build/amonredis
	@echo "# Build amonredis: branch $(AMONREDIS_BRANCH), sha $(AMONREDIS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/amonredis && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created amonredis bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(AMONREDIS_BITS)
	@echo ""

.PHONY: amonredis_image
amonredis_image: $(AMONREDIS_IMAGE_BIT)

$(AMONREDIS_IMAGE_BIT): $(AMONREDIS_BITS)
	@echo "# Build amonredis_image: branch $(AMONREDIS_BRANCH), sha $(AMONREDIS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(AMONREDIS_IMAGE_UUID)" -t $(AMONREDIS_BITS) \
		-o "$(AMONREDIS_IMAGE_BIT)" -p $(AMONREDIS_PKGSRC) \
		-t $(AMONREDIS_EXTRA_TARBALLS) -n $(AMONREDIS_IMAGE_NAME) \
		-v $(_amonredis_stamp) -d $(AMONREDIS_IMAGE_DESCRIPTION)
	@echo "# Created amonredis image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(AMONREDIS_IMAGE_BIT))
	@echo ""

amonredis_publish_image: $(AMONREDIS_IMAGE_BIT)
	@echo "# Publish amonredis image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(AMONREDIS_MANIFEST_BIT) -f $(AMONREDIS_IMAGE_BIT)

clean_amonredis:
	$(RM) -rf $(BITS_DIR)/amonredis
	(cd build/amonredis && gmake clean)


#---- RABBITMQ

_rabbitmq_stamp=$(RABBITMQ_BRANCH)-$(TIMESTAMP)-g$(RABBITMQ_SHA)
RABBITMQ_BITS=$(BITS_DIR)/rabbitmq/rabbitmq-pkg-$(_rabbitmq_stamp).tar.bz2
RABBITMQ_IMAGE_BIT=$(BITS_DIR)/rabbitmq/rabbitmq-zfs-$(_rabbitmq_stamp).zfs.gz
RABBITMQ_MANIFEST_BIT=$(BITS_DIR)/rabbitmq/rabbitmq-zfs-$(_rabbitmq_stamp).imgmanifest

.PHONY: rabbitmq
rabbitmq: $(RABBITMQ_BITS) rabbitmq_image

$(RABBITMQ_BITS): build/rabbitmq
	@echo "# Build rabbitmq: branch $(RABBITMQ_BRANCH), sha $(RABBITMQ_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/rabbitmq && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created rabbitmq bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(RABBITMQ_BITS)
	@echo ""

.PHONY: rabbitmq_image
rabbitmq_image: $(RABBITMQ_IMAGE_BIT)

$(RABBITMQ_IMAGE_BIT): $(RABBITMQ_BITS)
	@echo "# Build rabbitmq_image: branch $(RABBITMQ_BRANCH), sha $(RABBITMQ_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(RABBITMQ_IMAGE_UUID)" -t $(RABBITMQ_BITS) \
		-o "$(RABBITMQ_IMAGE_BIT)" -p $(RABBITMQ_PKGSRC) \
		-t $(RABBITMQ_EXTRA_TARBALLS) -n $(RABBITMQ_IMAGE_NAME) \
		-v $(_rabbitmq_stamp) -d $(RABBITMQ_IMAGE_DESCRIPTION)
	@echo "# Created rabbitmq image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(RABBITMQ_IMAGE_BIT))
	@echo ""

rabbitmq_publish_image: $(RABBITMQ_IMAGE_BIT)
	@echo "# Publish rabbitmq image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(RABBITMQ_MANIFEST_BIT) -f $(RABBITMQ_IMAGE_BIT)

clean_rabbitmq:
	$(RM) -rf $(BITS_DIR)/rabbitmq
	(cd build/rabbitmq && gmake clean)

#---- DHCPD

_dhcpd_stamp=$(DHCPD_BRANCH)-$(TIMESTAMP)-g$(DHCPD_SHA)
DHCPD_BITS=$(BITS_DIR)/dhcpd/dhcpd-pkg-$(_dhcpd_stamp).tar.bz2
DHCPD_IMAGE_BIT=$(BITS_DIR)/dhcpd/dhcpd-zfs-$(_dhcpd_stamp).zfs.gz
DHCPD_MANIFEST_BIT=$(BITS_DIR)/dhcpd/dhcpd-zfs-$(_dhcpd_stamp).imgmanifest

.PHONY: dhcpd
dhcpd: $(DHCPD_BITS) dhcpd_image

$(DHCPD_BITS): build/dhcpd
	@echo "# Build dhcpd: branch $(DHCPD_BRANCH), sha $(DHCPD_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/dhcpd && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) \
		$(MAKE) release publish)
	@echo "# Created dhcpd bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(DHCPD_BITS)
	@echo ""

.PHONY: dhcpd_image
dhcpd_image: $(DHCPD_IMAGE_BIT)

$(DHCPD_IMAGE_BIT): $(DHCPD_BITS)
	@echo "# Build dhcpd_image: branch $(DHCPD_BRANCH), sha $(DHCPD_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(DHCPD_IMAGE_UUID)" -t $(DHCPD_BITS) \
		-o "$(DHCPD_IMAGE_BIT)" -p $(DHCPD_PKGSRC) \
		-t $(DHCPD_EXTRA_TARBALLS) -n $(DHCPD_IMAGE_NAME) \
		-v $(_dhcpd_stamp) -d $(DHCPD_IMAGE_DESCRIPTION)
	@echo "# Created dhcpd image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(DHCPD_IMAGE_BIT))
	@echo ""

dhcpd_publish_image: $(DHCPD_IMAGE_BIT)
	@echo "# Publish dhcpd image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(DHCPD_MANIFEST_BIT) -f $(DHCPD_IMAGE_BIT)

clean_dhcpd:
	$(RM) -rf $(BITS_DIR)/dhcpd
	(cd build/dhcpd && gmake clean)

#---- MOCKCN

_mockcn_stamp=$(MOCKCN_BRANCH)-$(TIMESTAMP)-g$(MOCKCN_SHA)
MOCKCN_BITS=$(BITS_DIR)/mockcn/mockcn-pkg-$(_mockcn_stamp).tar.bz2
MOCKCN_IMAGE_BIT=$(BITS_DIR)/mockcn/mockcn-zfs-$(_mockcn_stamp).zfs.gz
MOCKCN_MANIFEST_BIT=$(BITS_DIR)/mockcn/mockcn-zfs-$(_mockcn_stamp).imgmanifest

.PHONY: mockcn
mockcn: $(MOCKCN_BITS) mockcn_image

$(MOCKCN_BITS): build/mockcn
	@echo "# Build mockcn: branch $(MOCKCN_BRANCH), sha $(MOCKCN_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/mockcn && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) \
		$(MAKE) release publish)
	@echo "# Created mockcn bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MOCKCN_BITS)
	@echo ""

.PHONY: mockcn_image
mockcn_image: $(MOCKCN_IMAGE_BIT)

$(MOCKCN_IMAGE_BIT): $(MOCKCN_BITS)
	@echo "# Build mockcn_image: branch $(MOCKCN_BRANCH), sha $(MOCKCN_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(MOCKCN_IMAGE_UUID)" -t $(MOCKCN_BITS) \
		-o "$(MOCKCN_IMAGE_BIT)" -p $(MOCKCN_PKGSRC) \
		-t $(MOCKCN_EXTRA_TARBALLS) -n $(MOCKCN_IMAGE_NAME) \
		-v $(_mockcn_stamp) -d $(MOCKCN_IMAGE_DESCRIPTION)
	@echo "# Created mockcn image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(MOCKCN_IMAGE_BIT))
	@echo ""

mockcn_publish_image: $(MOCKCN_IMAGE_BIT)
	@echo "# Publish mockcn image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MOCKCN_MANIFEST_BIT) -f $(MOCKCN_IMAGE_BIT)

clean_mockcn:
	$(RM) -rf $(BITS_DIR)/mockcn
	(cd build/mockcn && gmake clean)


#---- CLOUDAPI

_cloudapi_stamp=$(CLOUDAPI_BRANCH)-$(TIMESTAMP)-g$(CLOUDAPI_SHA)
CLOUDAPI_BITS=$(BITS_DIR)/cloudapi/cloudapi-pkg-$(_cloudapi_stamp).tar.bz2
CLOUDAPI_IMAGE_BIT=$(BITS_DIR)/cloudapi/cloudapi-zfs-$(_cloudapi_stamp).zfs.gz
CLOUDAPI_MANIFEST_BIT=$(BITS_DIR)/cloudapi/cloudapi-zfs-$(_cloudapi_stamp).imgmanifest

.PHONY: cloudapi
cloudapi: $(CLOUDAPI_BITS) cloudapi_image

# cloudapi still uses platform node, ensure that same version is first
# node (and npm) on the PATH.
$(CLOUDAPI_BITS): build/cloudapi
	@echo "# Build cloudapi: branch $(CLOUDAPI_BRANCH), sha $(CLOUDAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/cloudapi && PATH=/opt/node/0.6.12/bin:$(PATH) NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created cloudapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(CLOUDAPI_BITS)
	@echo ""

.PHONY: cloudapi_image
cloudapi_image: $(CLOUDAPI_IMAGE_BIT)

$(CLOUDAPI_IMAGE_BIT): $(CLOUDAPI_BITS)
	@echo "# Build cloudapi_image: branch $(CLOUDAPI_BRANCH), sha $(CLOUDAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(CLOUDAPI_IMAGE_UUID)" -t $(CLOUDAPI_BITS) \
		-o "$(CLOUDAPI_IMAGE_BIT)" -p $(CLOUDAPI_PKGSRC) \
		-t $(CLOUDAPI_EXTRA_TARBALLS) -n $(CLOUDAPI_IMAGE_NAME) \
		-v $(_cloudapi_stamp) -d $(CLOUDAPI_IMAGE_DESCRIPTION)
	@echo "# Created cloudapi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(CLOUDAPI_IMAGE_BIT))
	@echo ""

cloudapi_publish_image: $(CLOUDAPI_IMAGE_BIT)
	@echo "# Publish cloudapi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(CLOUDAPI_MANIFEST_BIT) -f $(CLOUDAPI_IMAGE_BIT)


# Warning: if cloudapi's submodule deps change, this 'clean_ufds' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_cloudapi:
	$(RM) -rf $(BITS_DIR)/cloudapi
	(cd build/cloudapi && gmake clean)


#---- MANTA_MANATEE

_manta-manatee_stamp=$(MANTA_MANATEE_BRANCH)-$(TIMESTAMP)-g$(MANTA_MANATEE_SHA)
MANTA_MANATEE_BITS=$(BITS_DIR)/manta-manatee/manta-manatee-pkg-$(_manta-manatee_stamp).tar.bz2
MANTA_MANATEE_IMAGE_BIT=$(BITS_DIR)/manta-manatee/manta-manatee-zfs-$(_manta-manatee_stamp).zfs.gz
MANTA_MANATEE_MANIFEST_BIT=$(BITS_DIR)/manta-manatee/manta-manatee-zfs-$(_manta-manatee_stamp).imgmanifest

.PHONY: manta-manatee
manta-manatee: $(MANTA_MANATEE_BITS) manta-manatee_image

$(MANTA_MANATEE_BITS): build/manta-manatee
	@echo "# Build manta-manatee: branch $(MANTA_MANATEE_BRANCH), sha $(MANTA_MANATEE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/manta-manatee && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created manta-manatee bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MANTA_MANATEE_BITS)
	@echo ""

.PHONY: manta-manatee_image
manta-manatee_image: $(MANTA_MANATEE_IMAGE_BIT)

$(MANTA_MANATEE_IMAGE_BIT): $(MANTA_MANATEE_BITS)
	@echo "# Build manta-manatee_image: branch $(MANTA_MANATEE_BRANCH), sha $(MANTA_MANATEE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(MANTA_MANATEE_IMAGE_UUID)" -t $(MANTA_MANATEE_BITS) \
		-b "manta-manatee" \
		-o "$(MANTA_MANATEE_IMAGE_BIT)" -p $(MANTA_MANATEE_PKGSRC) \
		-t $(MANTA_MANATEE_EXTRA_TARBALLS) -n $(MANTA_MANATEE_IMAGE_NAME) \
		-v $(_manta-manatee_stamp) -d $(MANTA_MANATEE_IMAGE_DESCRIPTION)
	@echo "# Created manta-manatee image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(MANTA_MANATEE_IMAGE_BIT))
	@echo ""

manta-manatee_publish_image: $(MANTA_MANATEE_IMAGE_BIT)
	@echo "# Publish manta-manatee image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MANTA_MANATEE_MANIFEST_BIT) -f $(MANTA_MANATEE_IMAGE_BIT)

clean_manta-manatee:
	$(RM) -rf $(BITS_DIR)/manta-manatee
	(cd build/manta-manatee && gmake distclean)


#---- SDC_MANATEE

_sdc-manatee_stamp=$(SDC_MANATEE_BRANCH)-$(TIMESTAMP)-g$(SDC_MANATEE_SHA)
SDC_MANATEE_BITS=$(BITS_DIR)/sdc-manatee/sdc-manatee-pkg-$(_sdc-manatee_stamp).tar.bz2
SDC_MANATEE_IMAGE_BIT=$(BITS_DIR)/sdc-manatee/sdc-manatee-zfs-$(_sdc-manatee_stamp).zfs.gz
SDC_MANATEE_MANIFEST_BIT=$(BITS_DIR)/sdc-manatee/sdc-manatee-zfs-$(_sdc-manatee_stamp).imgmanifest

.PHONY: sdc-manatee
sdc-manatee: $(SDC_MANATEE_BITS) sdc-manatee_image

$(SDC_MANATEE_BITS): build/sdc-manatee
	@echo "# Build sdc-manatee: branch $(SDC_MANATEE_BRANCH), sha $(SDC_MANATEE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/sdc-manatee && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created sdc-manatee bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(SDC_MANATEE_BITS)
	@echo ""

.PHONY: sdc-manatee_image
sdc-manatee_image: $(SDC_MANATEE_IMAGE_BIT)

$(SDC_MANATEE_IMAGE_BIT): $(SDC_MANATEE_BITS)
	@echo "# Build sdc-manatee_image: branch $(SDC_MANATEE_BRANCH), sha $(SDC_MANATEE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(SDC_MANATEE_IMAGE_UUID)" -t $(SDC_MANATEE_BITS) \
		-b "sdc-manatee" \
		-o "$(SDC_MANATEE_IMAGE_BIT)" -p $(SDC_MANATEE_PKGSRC) \
		-t $(SDC_MANATEE_EXTRA_TARBALLS) -n $(SDC_MANATEE_IMAGE_NAME) \
		-v $(_sdc-manatee_stamp) -d $(SDC_MANATEE_IMAGE_DESCRIPTION)
	@echo "# Created sdc-manatee image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(SDC_MANATEE_IMAGE_BIT))
	@echo ""

sdc-manatee_publish_image: $(SDC_MANATEE_IMAGE_BIT)
	@echo "# Publish sdc-manatee image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(SDC_MANATEE_MANIFEST_BIT) -f $(SDC_MANATEE_IMAGE_BIT)

clean_sdc-manatee:
	$(RM) -rf $(BITS_DIR)/sdc-manatee
	(cd build/sdc-manatee && gmake distclean)


#---- MANATEE

_manatee_stamp=$(MANATEE_BRANCH)-$(TIMESTAMP)-g$(MANATEE_SHA)
MANATEE_BITS=$(BITS_DIR)/manatee/manatee-pkg-$(_manatee_stamp).tar.bz2
MANATEE_IMAGE_BIT=$(BITS_DIR)/manatee/manatee-zfs-$(_manatee_stamp).zfs.gz
MANATEE_MANIFEST_BIT=$(BITS_DIR)/manatee/manatee-zfs-$(_manatee_stamp).imgmanifest

.PHONY: manatee
manatee: $(MANATEE_BITS) manatee_image

$(MANATEE_BITS): build/manatee
	@echo "# Build manatee: branch $(MANATEE_BRANCH), sha $(MANATEE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/manatee && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created manatee bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MANATEE_BITS)
	@echo ""

.PHONY: manatee_image
manatee_image: $(MANATEE_IMAGE_BIT)

$(MANATEE_IMAGE_BIT): $(MANATEE_BITS)
	@echo "# Build manatee_image: branch $(MANATEE_BRANCH), sha $(MANATEE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(MANATEE_IMAGE_UUID)" -t $(MANATEE_BITS) \
		-b "manatee" \
		-o "$(MANATEE_IMAGE_BIT)" -p $(MANATEE_PKGSRC) \
		-t $(MANATEE_EXTRA_TARBALLS) -n $(MANATEE_IMAGE_NAME) \
		-v $(_manatee_stamp) -d $(MANATEE_IMAGE_DESCRIPTION)
	@echo "# Created manatee image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(MANATEE_IMAGE_BIT))
	@echo ""

manatee_publish_image: $(MANATEE_IMAGE_BIT)
	@echo "# Publish manatee image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MANATEE_MANIFEST_BIT) -f $(MANATEE_IMAGE_BIT)

clean_manatee:
	$(RM) -rf $(BITS_DIR)/manatee
	(cd build/manatee && gmake distclean)


#---- WORKFLOW

_wf_stamp=$(SDC_WORKFLOW_BRANCH)-$(TIMESTAMP)-g$(SDC_WORKFLOW_SHA)
WORKFLOW_BITS=$(BITS_DIR)/workflow/workflow-pkg-$(_wf_stamp).tar.bz2
WORKFLOW_IMAGE_BIT=$(BITS_DIR)/workflow/workflow-zfs-$(_wf_stamp).zfs.gz
WORKFLOW_MANIFEST_BIT=$(BITS_DIR)/workflow/workflow-zfs-$(_wf_stamp).imgmanifest

.PHONY: sdc-workflow
sdc-workflow: $(WORKFLOW_BITS) workflow_image

# PATH for workflow build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(WORKFLOW_BITS): build/sdc-workflow
	@echo "# Build workflow: branch $(SDC_WORKFLOW_BRANCH), sha $(SDC_WORKFLOW_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/sdc-workflow && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created workflow bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(WORKFLOW_BITS)
	@echo ""

.PHONY: workflow_image
workflow_image: $(WORKFLOW_IMAGE_BIT)

$(WORKFLOW_IMAGE_BIT): $(WORKFLOW_BITS)
	@echo "# Build workflow_image: branch $(SDC_WORKFLOW_BRANCH), sha $(SDC_WORKFLOW_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(SDC_WORKFLOW_IMAGE_UUID)" -t $(WORKFLOW_BITS) \
		-o "$(WORKFLOW_IMAGE_BIT)" -p $(SDC_WORKFLOW_PKGSRC) \
		-t $(SDC_WORKFLOW_EXTRA_TARBALLS) -n $(SDC_WORKFLOW_IMAGE_NAME) \
		-v $(_wf_stamp) -d $(SDC_WORKFLOW_IMAGE_DESCRIPTION)
	@echo "# Created workflow image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(WORKFLOW_IMAGE_BIT))
	@echo ""

workflow_publish_image: $(WORKFLOW_IMAGE_BIT)
	@echo "# Publish workflow image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(WORKFLOW_MANIFEST_BIT) -f $(WORKFLOW_IMAGE_BIT)

# Warning: if workflow's submodule deps change, this 'clean_workflow' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_workflow:
	$(RM) -rf $(BITS_DIR)/sdc-workflow
	(cd build/sdc-workflow && gmake clean)


#---- VMAPI

_vmapi_stamp=$(VMAPI_BRANCH)-$(TIMESTAMP)-g$(VMAPI_SHA)
VMAPI_BITS=$(BITS_DIR)/vmapi/vmapi-pkg-$(_vmapi_stamp).tar.bz2
VMAPI_IMAGE_BIT=$(BITS_DIR)/vmapi/vmapi-zfs-$(_vmapi_stamp).zfs.gz
VMAPI_MANIFEST_BIT=$(BITS_DIR)/vmapi/vmapi-zfs-$(_vmapi_stamp).imgmanifest

.PHONY: vmapi
vmapi: $(VMAPI_BITS) vmapi_image

# PATH for vmapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(VMAPI_BITS): build/vmapi
	@echo "# Build vmapi: branch $(VMAPI_BRANCH), sha $(VMAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/vmapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created vmapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(VMAPI_BITS)
	@echo ""

.PHONY: vmapi_image
vmapi_image: $(VMAPI_IMAGE_BIT)

$(VMAPI_IMAGE_BIT): $(VMAPI_BITS)
	@echo "# Build vmapi_image: branch $(VMAPI_BRANCH), sha $(VMAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(VMAPI_IMAGE_UUID)" -t $(VMAPI_BITS) \
		-o "$(VMAPI_IMAGE_BIT)" -p $(VMAPI_PKGSRC) \
		-t $(VMAPI_EXTRA_TARBALLS) -n $(VMAPI_IMAGE_NAME) \
		-v $(_vmapi_stamp) -d $(VMAPI_IMAGE_DESCRIPTION)
	@echo "# Created vmapi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(VMAPI_IMAGE_BIT))
	@echo ""

vmapi_publish_image: $(VMAPI_IMAGE_BIT)
	@echo "# Publish vmapi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(VMAPI_MANIFEST_BIT) -f $(VMAPI_IMAGE_BIT)

# Warning: if vmapi's submodule deps change, this 'clean_vmapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_vmapi:
	$(RM) -rf $(BITS_DIR)/vmapi
	(cd build/vmapi && gmake clean)



#---- PAPI

_papi_stamp=$(PAPI_BRANCH)-$(TIMESTAMP)-g$(PAPI_SHA)
PAPI_BITS=$(BITS_DIR)/papi/papi-pkg-$(_papi_stamp).tar.bz2
PAPI_IMAGE_BIT=$(BITS_DIR)/papi/papi-zfs-$(_papi_stamp).zfs.gz
PAPI_MANIFEST_BIT=$(BITS_DIR)/papi/papi-zfs-$(_papi_stamp).imgmanifest


.PHONY: papi
papi: $(PAPI_BITS) papi_image

# PATH for papi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(PAPI_BITS): build/papi
	@echo "# Build papi: branch $(PAPI_BRANCH), sha $(PAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/papi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created papi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(PAPI_BITS)
	@echo ""

.PHONY: papi_image
papi_image: $(PAPI_IMAGE_BIT)

$(PAPI_IMAGE_BIT): $(PAPI_BITS)
	@echo "# Build papi_image: branch $(PAPI_BRANCH), sha $(PAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(PAPI_IMAGE_UUID)" -t $(PAPI_BITS) \
		-o "$(PAPI_IMAGE_BIT)" -p $(PAPI_PKGSRC) \
		-t $(PAPI_EXTRA_TARBALLS) -n $(PAPI_IMAGE_NAME) \
		-v $(_papi_stamp) -d $(PAPI_IMAGE_DESCRIPTION)
	@echo "# Created papi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(PAPI_IMAGE_BIT))
	@echo ""

papi_publish_image: $(PAPI_IMAGE_BIT)
	@echo "# Publish papi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(PAPI_MANIFEST_BIT) -f $(PAPI_IMAGE_BIT)

# Warning: if papi's submodule deps change, this 'clean_papi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_papi:
	$(RM) -rf $(BITS_DIR)/papi
	(cd build/papi && gmake clean)



#---- IMGAPI

_imgapi_stamp=$(IMGAPI_BRANCH)-$(TIMESTAMP)-g$(IMGAPI_SHA)
IMGAPI_BITS=$(BITS_DIR)/imgapi/imgapi-pkg-$(_imgapi_stamp).tar.bz2
IMGAPI_IMAGE_BIT=$(BITS_DIR)/imgapi/imgapi-zfs-$(_imgapi_stamp).zfs.gz
IMGAPI_MANIFEST_BIT=$(BITS_DIR)/imgapi/imgapi-zfs-$(_imgapi_stamp).imgmanifest

.PHONY: imgapi
imgapi: $(IMGAPI_BITS) imgapi_image

$(IMGAPI_BITS): build/imgapi
	@echo "# Build imgapi: branch $(IMGAPI_BRANCH), sha $(IMGAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/imgapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created imgapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(IMGAPI_BITS)
	@echo ""

.PHONY: imgapi_image
imgapi_image: $(IMGAPI_IMAGE_BIT)

$(IMGAPI_IMAGE_BIT): $(IMGAPI_BITS)
	@echo "# Build imgapi_image: branch $(IMGAPI_BRANCH), sha $(IMGAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(IMGAPI_IMAGE_UUID)" -t $(IMGAPI_BITS) \
		-o "$(IMGAPI_IMAGE_BIT)" -p $(IMGAPI_PKGSRC) \
		-t $(IMGAPI_EXTRA_TARBALLS) -n $(IMGAPI_IMAGE_NAME) \
		-v $(_imgapi_stamp) -d $(IMGAPI_IMAGE_DESCRIPTION)
	@echo "# Created imgapi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(IMGAPI_IMAGE_BIT))
	@echo ""

imgapi_publish_image: $(IMGAPI_IMAGE_BIT)
	@echo "# Publish imgapi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(IMGAPI_MANIFEST_BIT) -f $(IMGAPI_IMAGE_BIT)

clean_imgapi:
	$(RM) -rf $(BITS_DIR)/imgapi
	(cd build/imgapi && gmake clean)


#---- sdc

_sdc_stamp=$(SDC_BRANCH)-$(TIMESTAMP)-g$(SDC_SHA)
SDC_BITS=$(BITS_DIR)/sdc/sdc-pkg-$(_sdc_stamp).tar.bz2
SDC_IMAGE_BIT=$(BITS_DIR)/sdc/sdc-zfs-$(_sdc_stamp).zfs.gz
SDC_MANIFEST_BIT=$(BITS_DIR)/sdc/sdc-zfs-$(_sdc_stamp).imgmanifest

.PHONY: sdc
sdc: $(SDC_BITS) sdc_image

$(SDC_BITS): build/sdc
	@echo "# Build sdc: branch $(SDC_BRANCH), sha $(SDC_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/sdc && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created sdc bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(SDC_BITS)
	@echo ""

.PHONY: sdc_image
sdc_image: $(SDC_IMAGE_BIT)

$(SDC_IMAGE_BIT): $(SDC_BITS)
	@echo "# Build sdc_image: branch $(SDC_BRANCH), sha $(SDC_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(SDC_IMAGE_UUID)" -t $(SDC_BITS) \
		-o "$(SDC_IMAGE_BIT)" -p $(SDC_PKGSRC) \
		-t $(SDC_EXTRA_TARBALLS) -n $(SDC_IMAGE_NAME) \
		-v $(_sdc_stamp) -d $(SDC_IMAGE_DESCRIPTION)
	@echo "# Created sdc image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(SDC_IMAGE_BIT))
	@echo ""

sdc_publish_image: $(SDC_IMAGE_BIT)
	@echo "# Publish sdc image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(SDC_MANIFEST_BIT) -f $(SDC_IMAGE_BIT)

clean_sdc:
	$(RM) -rf $(BITS_DIR)/sdc
	(cd build/sdc && gmake clean)


#---- sdc-system-tests (aka systests)

_sdc_system_tests_stamp=$(SDC_SYSTEM_TESTS_BRANCH)-$(TIMESTAMP)-g$(SDC_SYSTEM_TESTS_SHA)
SDC_SYSTEM_TESTS_BITS=$(BITS_DIR)/sdc-system-tests/sdc-system-tests-$(_sdc_system_tests_stamp).tgz

.PHONY: sdc-system-tests
sdc-system-tests: $(SDC_SYSTEM_TESTS_BITS)

$(SDC_SYSTEM_TESTS_BITS): build/sdc-system-tests
	@echo "# Build sdc-system-tests: branch $(SDC_SYSTEM_TESTS_BRANCH), sha $(SDC_SYSTEM_TESTS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/sdc-system-tests && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm \
		TIMESTAMP=$(TIMESTAMP) \
		BITS_DIR=$(BITS_DIR) \
		gmake all release publish)
	@echo "# Created sdc-system-tests bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(SDC_SYSTEM_TESTS_BITS)
	@echo ""


#---- Agents core

_agents_core_stamp=$(AGENTS_CORE_BRANCH)-$(TIMESTAMP)-g$(AGENTS_CORE_SHA)
AGENTS_CORE_BIT=$(BITS_DIR)/agents_core/agents_core-$(_agents_core_stamp).tgz
AGENTS_CORE_MANIFEST_BIT=$(BITS_DIR)/agents_core/agents_core-$(_agents_core_stamp).manifest

.PHONY: agents_core
agents_core: $(AGENTS_CORE_BIT)

# PATH for agents_core build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(AGENTS_CORE_BIT): build/agents_core
	@echo "# Build agents_core: branch $(AGENTS_CORE_BRANCH), sha $(AGENTS_CORE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/agents_core && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created agents_core bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(AGENTS_CORE_BIT) $(AGENTS_CORE_MANIFEST_BIT)
	@echo ""

agents_core_publish_image: $(AGENTS_CORE_BIT)
	@echo "# Publish agents_core image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(AGENTS_CORE_MANIFEST_BIT) -f $(AGENTS_CORE_BIT)

# Warning: if agents_core's submodule deps change, this 'clean_agents_core' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_agents_core:
	$(RM) -rf $(BITS_DIR)/agents_core
	(cd build/agents_core && gmake clean)


#---- VM Agent

# The values for SDC_VM_AGENT_BRANCH and SDC_VM_AGENT_SHAR are generated from
# the name of the git repo.
# The repo name is "sdc-vm-agent" and we want the resultant tarball from this
# process to be "vm-agent-<...>.tgz", not "sdc-vm-agent-<...>.tgz".

_vm_agent_stamp=$(SDC_VM_AGENT_BRANCH)-$(TIMESTAMP)-g$(SDC_VM_AGENT_SHA)
VM_AGENT_BIT=$(BITS_DIR)/vm-agent/vm-agent-$(_vm_agent_stamp).tgz
VM_AGENT_MANIFEST_BIT=$(BITS_DIR)/vm-agent/vm-agent-$(_vm_agent_stamp).manifest

.PHONY: vm-agent
vm-agent: $(VM_AGENT_BIT)

# PATH for vm-agent build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(VM_AGENT_BIT): build/sdc-vm-agent
	@echo "# Build vm-agent: branch $(SDC_VM_AGENT_BRANCH), sha $(SDC_VM_AGENT_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/sdc-vm-agent && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created vm-agent bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(VM_AGENT_BIT) $(VM_AGENT_MANIFEST_BIT)
	@echo ""

vm-agent_publish_image: $(VM_AGENT_BIT)
	@echo "# Publish vm-agent image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(VM_AGENT_MANIFEST_BIT) -f $(VM_AGENT_BIT)

# Warning: if vm-agents's submodule deps change, this 'clean_vm_agent' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_vm_agent:
	$(RM) -rf $(BITS_DIR)/vm-agent
	(cd build/sdc-vm-agent && gmake clean)


#---- Net Agent

# The values for SDC_NET_AGENT_BRANCH and SDC_NET_AGENT_SHAR are generated from
# the name of the git repo.
# The repo name is "sdc-net-agent" and we want the resultant tarball from this
# process to be "net-agent-<...>.tgz", not "sdc-net-agent-<...>.tgz".

_net_agent_stamp=$(SDC_NET_AGENT_BRANCH)-$(TIMESTAMP)-g$(SDC_NET_AGENT_SHA)
NET_AGENT_BIT=$(BITS_DIR)/net-agent/net-agent-$(_net_agent_stamp).tgz
NET_AGENT_MANIFEST_BIT=$(BITS_DIR)/net-agent/net-agent-$(_net_agent_stamp).manifest

.PHONY: net-agent
net-agent: $(NET_AGENT_BIT)

# PATH for net-agent build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(NET_AGENT_BIT): build/sdc-net-agent
	@echo "# Build net-agent: branch $(SDC_NET_AGENT_BRANCH), sha $(SDC_NET_AGENT_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/sdc-net-agent && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created net-agent bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(NET_AGENT_BIT)
	@echo ""

net-agent_publish_image: $(NET_AGENT_BIT)
	@echo "# Publish net-agent image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(NET_AGENT_MANIFEST_BIT) -f $(NET_AGENT_BIT)

# Warning: if net-agents's submodule deps change, this 'clean_net_agent' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_net_agent:
	$(RM) -rf $(BITS_DIR)/net-agent
	(cd build/sdc-net-agent && gmake clean)


#---- CN Agent

# The values for SDC_CN_AGENT_BRANCH and SDC_CN_AGENT_SHAR are generated from
# the name of the git repo.
# The repo name is "sdc-cn-agent" and we want the resultant tarball from this
# process to be "cn-agent-<...>.tgz", not "sdc-cn-agent-<...>.tgz".

_cn_agent_stamp=$(SDC_CN_AGENT_BRANCH)-$(TIMESTAMP)-g$(SDC_CN_AGENT_SHA)
CN_AGENT_BIT=$(BITS_DIR)/cn-agent/cn-agent-$(_cn_agent_stamp).tgz
CN_AGENT_MANIFEST_BIT=$(BITS_DIR)/cn-agent/cn-agent-$(_cn_agent_stamp).manifest

.PHONY: cn-agent
cn-agent: $(CN_AGENT_BIT)

# PATH for cn-agent build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(CN_AGENT_BIT): build/sdc-cn-agent
	@echo "# Build cn-agent: branch $(SDC_CN_AGENT_BRANCH), sha $(SDC_CN_AGENT_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/sdc-cn-agent && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created cn-agent bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(CN_AGENT_BIT) $(CN_AGENT_MANIFEST_BIT)
	@echo ""

cn-agent_publish_image: $(CN_AGENT_BIT)
	@echo "# Publish cn-agent image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(CN_AGENT_MANIFEST_BIT) -f $(CN_AGENT_BIT)

# Warning: if cn-agents's submodule deps change, this 'clean_cn_agent' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_cn_agent:
	$(RM) -rf $(BITS_DIR)/cn-agent
	(cd build/sdc-cn-agent && gmake clean)


#---- Provisioner

_provisioner_stamp=$(PROVISIONER_BRANCH)-$(TIMESTAMP)-g$(PROVISIONER_SHA)
PROVISIONER_BIT=$(BITS_DIR)/provisioner/provisioner-$(_provisioner_stamp).tgz
PROVISIONER_MANIFEST_BIT=$(BITS_DIR)/provisioner/provisioner-$(_provisioner_stamp).manifest

.PHONY: provisioner
provisioner: $(PROVISIONER_BIT)

# PATH for provisioner build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(PROVISIONER_BIT): build/provisioner
	@echo "# Build provisioner: branch $(PROVISIONER_BRANCH), sha $(PROVISIONER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/provisioner && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created provisioner bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(PROVISIONER_BIT) $(PROVISIONER_MANIFEST_BIT)
	@echo ""

provisioner_publish_image: $(PROVISIONER_BIT)
	@echo "# Publish provisioner image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(PROVISIONER_MANIFEST_BIT) -f $(PROVISIONER_BIT)

# Warning: if provisioner's submodule deps change, this 'clean_provisioner' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_provisioner:
	$(RM) -rf $(BITS_DIR)/provisioner
	(cd build/provisioner && gmake clean)


#---- Heartbeater

_heartbeater_stamp=$(HEARTBEATER_BRANCH)-$(TIMESTAMP)-g$(HEARTBEATER_SHA)
HEARTBEATER_BIT=$(BITS_DIR)/heartbeater/heartbeater-$(_heartbeater_stamp).tgz
HEARTBEATER_MANIFEST_BIT=$(BITS_DIR)/heartbeater/heartbeater-$(_heartbeater_stamp).manifest

.PHONY: heartbeater
heartbeater: $(HEARTBEATER_BIT)

# PATH for heartbeater build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(HEARTBEATER_BIT): build/heartbeater
	@echo "# Build heartbeater: branch $(HEARTBEATER_BRANCH), sha $(HEARTBEATER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/heartbeater && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created heartbeater bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(HEARTBEATER_BIT)
	@echo ""

heartbeater_publish_image: $(HEARTBEATER_BIT)
	@echo "# Publish heartbeater image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(HEARTBEATER_MANIFEST_BIT) -f $(HEARTBEATER_BIT)

# Warning: if heartbeater's submodule deps change, this 'clean_heartbeater' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_heartbeater:
	$(RM) -rf $(BITS_DIR)/heartbeater
	(cd build/heartbeater && gmake clean)


#---- Zonetracker

_zonetracker_stamp=$(ZONETRACKER_BRANCH)-$(TIMESTAMP)-g$(ZONETRACKER_SHA)
ZONETRACKER_BIT=$(BITS_DIR)/zonetracker/zonetracker-$(_zonetracker_stamp).tgz
ZONETRACKER_MANIFEST_BIT=$(BITS_DIR)/zonetracker/zonetracker-$(_zonetracker_stamp).manifest

.PHONY: zonetracker
zonetracker: $(ZONETRACKER_BIT)

# PATH for zonetracker build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(ZONETRACKER_BIT): build/zonetracker
	@echo "# Build zonetracker: branch $(ZONETRACKER_BRANCH), sha $(ZONETRACKER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/zonetracker && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created zonetracker bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(ZONETRACKER_BIT) $(ZONETRACKER_MANIFEST_BIT)
	@echo ""

zonetracker_publish_image: $(ZONETRACKER_BIT)
	@echo "# Publish zonetracker image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(ZONETRACKER_MANIFEST_BIT) -f $(ZONETRACKER_BIT)

# Warning: if zonetracker's submodule deps change, this 'clean_zonetracker' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_zonetracker:
	$(RM) -rf $(BITS_DIR)/zonetracker
	(cd build/zonetracker && gmake clean)


#---- Configuration Agent

_config_agent_stamp=$(CONFIG_AGENT_BRANCH)-$(TIMESTAMP)-g$(CONFIG_AGENT_SHA)
CONFIG_AGENT_BIT=$(BITS_DIR)/config-agent/config-agent-pkg-$(_config_agent_stamp).tar.bz2
CONFIG_AGENT_MANIFEST_BIT=$(BITS_DIR)/config-agent/config-agent-pkg-$(_config_agent_stamp).manifest

.PHONY: config-agent
config-agent: $(CONFIG_AGENT_BIT)

$(CONFIG_AGENT_BIT): build/config-agent
	@echo "# Build config-agent: branch $(CONFIG_AGENT_BRANCH), sha $(CONFIG_AGENT_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/config-agent && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created config-agent bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(CONFIG_AGENT_BIT) $(CONFIG_AGENT_MANIFEST_BIT)
	@echo ""

config-agent_publish_image: $(CONFIG_AGENT_BIT)
	@echo "# Publish config-agent image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(CONFIG_AGENT_MANIFEST_BIT) -f $(CONFIG_AGENT_BIT)

clean_config_agent:
	$(RM) -rf $(BITS_DIR)/config-agent
	(cd build/config-agent && gmake clean)


#---- Hagfish Watcher

_hagfish_watcher_stamp=$(SDC_HAGFISH_WATCHER_BRANCH)-$(TIMESTAMP)-g$(SDC_HAGFISH_WATCHER_SHA)
HAGFISH_WATCHER_BIT=$(BITS_DIR)/hagfish-watcher/hagfish-watcher-$(_hagfish_watcher_stamp).tgz
HAGFISH_WATCHER_MANIFEST_BIT=$(BITS_DIR)/hagfish-watcher/hagfish-watcher-$(_hagfish_watcher_stamp).manifest

.PHONY: hagfish-watcher
hagfish-watcher: $(HAGFISH_WATCHER_BIT)

$(HAGFISH_WATCHER_BIT): build/sdc-hagfish-watcher
	@echo "# Build hagfish-watcher: branch $(SDC_HAGFISH_WATCHER_BRANCH), sha $(HAGFISH_WATCHER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/sdc-hagfish-watcher && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created hagfish-watcher bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(HAGFISH_WATCHER_BIT) $(HAGFISH_WATCHER_MANIFEST_BIT)
	@echo ""

hagfish-watcher_publish_image: $(HAGFISH_WATCHER_BIT)
	@echo "# Publish hagfish-watcher image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(HAGFISH_WATCHER_MANIFEST_BIT) -f $(HAGFISH_WATCHER_BIT)

clean_hagfish-watcher:
	$(RM) -rf $(BITS_DIR)/hagfish-watcher
	(cd build/sdc-hagfish-watcher && gmake clean)


#---- Firewaller

_firewaller_stamp=$(FIREWALLER_BRANCH)-$(TIMESTAMP)-g$(FIREWALLER_SHA)
FIREWALLER_BIT=$(BITS_DIR)/firewaller/firewaller-$(_firewaller_stamp).tgz
FIREWALLER_MANIFEST_BIT=$(BITS_DIR)/firewaller/firewaller-$(_firewaller_stamp).manifest

.PHONY: firewaller
firewaller: $(FIREWALLER_BIT)

$(FIREWALLER_BIT): build/firewaller
	@echo "# Build firewaller: branch $(FIREWALLER_BRANCH), sha $(FIREWALLER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/firewaller && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created firewaller bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(FIREWALLER_BIT) $(FIREWALLER_MANIFEST_BIT)
	@echo ""

firewaller_publish_image: $(FIREWALLER_BIT)
	@echo "# Publish firewaller image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(FIREWALLER_MANIFEST_BIT) -f $(FIREWALLER_BIT)

clean_firewaller:
	$(RM) -rf $(BITS_DIR)/firewaller
	(cd build/firewaller && gmake clean)



#---- CNAPI

_cnapi_stamp=$(CNAPI_BRANCH)-$(TIMESTAMP)-g$(CNAPI_SHA)
CNAPI_BITS=$(BITS_DIR)/cnapi/cnapi-pkg-$(_cnapi_stamp).tar.bz2
CNAPI_IMAGE_BIT=$(BITS_DIR)/cnapi/cnapi-zfs-$(_cnapi_stamp).zfs.gz
CNAPI_MANIFEST_BIT=$(BITS_DIR)/cnapi/cnapi-zfs-$(_cnapi_stamp).imgmanifest

.PHONY: cnapi
cnapi: $(CNAPI_BITS) cnapi_image

# PATH for cnapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(CNAPI_BITS): build/cnapi
	@echo "# Build cnapi: branch $(CNAPI_BRANCH), sha $(CNAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/cnapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created cnapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(CNAPI_BITS)
	@echo ""

.PHONY: cnapi_image
cnapi_image: $(CNAPI_IMAGE_BIT)

$(CNAPI_IMAGE_BIT): $(CNAPI_BITS)
	@echo "# Build cnapi_image: branch $(CNAPI_BRANCH), sha $(CNAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(CNAPI_IMAGE_UUID)" -t $(CNAPI_BITS) \
		-o "$(CNAPI_IMAGE_BIT)" -p $(CNAPI_PKGSRC) \
		-t $(CNAPI_EXTRA_TARBALLS) -n $(CNAPI_IMAGE_NAME) \
		-v $(_cnapi_stamp) -d $(CNAPI_IMAGE_DESCRIPTION)
	@echo "# Created cnapi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(CNAPI_IMAGE_BIT))
	@echo ""

cnapi_publish_image: $(CNAPI_IMAGE_BIT)
	@echo "# Publish cnapi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(CNAPI_MANIFEST_BIT) -f $(CNAPI_IMAGE_BIT)

# Warning: if cnapi's submodule deps change, this 'clean_cnapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_cnapi:
	$(RM) -rf $(BITS_DIR)/cnapi
	(cd build/cnapi && gmake clean)


#---- SDCSSO

_sdcsso_stamp=$(SDCSSO_BRANCH)-$(TIMESTAMP)-g$(SDCSSO_SHA)
SDCSSO_BITS=$(BITS_DIR)/sdcsso/sdcsso-pkg-$(_sdcsso_stamp).tar.bz2
SDCSSO_IMAGE_BIT=$(BITS_DIR)/sdcsso/sdcsso-zfs-$(_sdcsso_stamp).zfs.gz
SDCSSO_MANIFEST_BIT=$(BITS_DIR)/sdcsso/sdcsso-zfs-$(_sdcsso_stamp).imgmanifest

.PHONY: sdcsso
sdcsso: $(SDCSSO_BITS) sdcsso_image

# PATH for sdcsso build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(SDCSSO_BITS): build/sdcsso
	@echo "# Build sdcsso: branch $(KEYAPI_BRANCH), sha $(KEYAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/sdcsso && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created sdcsso bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(SDCSSO_BITS)
	@echo ""

.PHONY: sdcsso_image
sdcsso_image: $(SDCSSO_IMAGE_BIT)

$(SDCSSO_IMAGE_BIT): $(SDCSSO_BITS)
	@echo "# Build sdcsso_image: branch $(SDCSSO_BRANCH), sha $(SDCSSO_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(SDCSSO_IMAGE_UUID)" -t $(SDCSSO_BITS) \
		-o "$(SDCSSO_IMAGE_BIT)" -p $(SDCSSO_PKGSRC) \
		-t $(SDCSSO_EXTRA_TARBALLS) -n $(SDCSSO_IMAGE_NAME) \
		-v $(_sdcsso_stamp) -d $(SDCSSO_IMAGE_DESCRIPTION)
	@echo "# Created sdcsso image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(SDCSSO_IMAGE_BIT))
	@echo ""

sdcsso_publish_image: $(SDCSSO_IMAGE_BIT)
	@echo "# Publish sdcsso image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(SDCSSO_MANIFEST_BIT) -f $(SDCSSO_IMAGE_BIT)

# Warning: if SDCSSO's submodule deps change, this 'clean_sdcsso is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_sdcsso:
	$(RM) -rf $(BITS_DIR)/sdcsso
	(cd build/sdcsso && gmake clean)


#---- FWAPI

_fwapi_stamp=$(FWAPI_BRANCH)-$(TIMESTAMP)-g$(FWAPI_SHA)
FWAPI_BITS=$(BITS_DIR)/fwapi/fwapi-pkg-$(_fwapi_stamp).tar.bz2
FWAPI_IMAGE_BIT=$(BITS_DIR)/fwapi/fwapi-zfs-$(_fwapi_stamp).zfs.gz
FWAPI_MANIFEST_BIT=$(BITS_DIR)/fwapi/fwapi-zfs-$(_fwapi_stamp).imgmanifest

.PHONY: fwapi
fwapi: $(FWAPI_BITS) fwapi_image

# PATH for fwapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(FWAPI_BITS): build/fwapi
	@echo "# Build fwapi: branch $(FWAPI_BRANCH), sha $(FWAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/fwapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake pkg release publish)
	@echo "# Created fwapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(FWAPI_BITS)
	@echo ""

.PHONY: fwapi_image
fwapi_image: $(FWAPI_IMAGE_BIT)

$(FWAPI_IMAGE_BIT): $(FWAPI_BITS)
	@echo "# Build fwapi_image: branch $(FWAPI_BRANCH), sha $(FWAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(FWAPI_IMAGE_UUID)" -t $(FWAPI_BITS) \
		-o "$(FWAPI_IMAGE_BIT)" -p $(FWAPI_PKGSRC) \
		-t $(FWAPI_EXTRA_TARBALLS) -n $(FWAPI_IMAGE_NAME) \
		-v $(_fwapi_stamp) -d $(FWAPI_IMAGE_DESCRIPTION)
	@echo "# Created fwapi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(FWAPI_IMAGE_BIT))
	@echo ""

fwapi_publish_image: $(FWAPI_IMAGE_BIT)
	@echo "# Publish fwapi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(FWAPI_MANIFEST_BIT) -f $(FWAPI_IMAGE_BIT)

# Warning: if FWAPI's submodule deps change, this 'clean_fwapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_fwapi:
	$(RM) -rf $(BITS_DIR)/fwapi
	(cd build/fwapi && gmake clean)



#---- NAPI

_napi_stamp=$(NAPI_BRANCH)-$(TIMESTAMP)-g$(NAPI_SHA)
NAPI_BITS=$(BITS_DIR)/napi/napi-pkg-$(_napi_stamp).tar.bz2
NAPI_IMAGE_BIT=$(BITS_DIR)/napi/napi-zfs-$(_napi_stamp).zfs.gz
NAPI_MANIFEST_BIT=$(BITS_DIR)/napi/napi-zfs-$(_napi_stamp).imgmanifest

.PHONY: napi
napi: $(NAPI_BITS) napi_image

# PATH for napi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(NAPI_BITS): build/napi
	@echo "# Build napi: branch $(NAPI_BRANCH), sha $(NAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/napi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake pkg release publish)
	@echo "# Created napi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(NAPI_BITS)
	@echo ""

.PHONY: napi_image
napi_image: $(NAPI_IMAGE_BIT)

$(NAPI_IMAGE_BIT): $(NAPI_BITS)
	@echo "# Build napi_image: branch $(NAPI_BRANCH), sha $(NAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(NAPI_IMAGE_UUID)" -t $(NAPI_BITS) \
		-o "$(NAPI_IMAGE_BIT)" -p $(NAPI_PKGSRC) \
		-t $(NAPI_EXTRA_TARBALLS) -n $(NAPI_IMAGE_NAME) \
		-v $(_napi_stamp) -d $(NAPI_IMAGE_DESCRIPTION)
	@echo "# Created napi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(NAPI_IMAGE_BIT))
	@echo ""

napi_publish_image: $(NAPI_IMAGE_BIT)
	@echo "# Publish napi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(NAPI_MANIFEST_BIT) -f $(NAPI_IMAGE_BIT)

# Warning: if NAPI's submodule deps change, this 'clean_napi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_napi:
	$(RM) -rf $(BITS_DIR)/napi
	(cd build/napi && gmake clean)



#---- SAPI

_sapi_stamp=$(SAPI_BRANCH)-$(TIMESTAMP)-g$(SAPI_SHA)
SAPI_BITS=$(BITS_DIR)/sapi/sapi-pkg-$(_sapi_stamp).tar.bz2
SAPI_IMAGE_BIT=$(BITS_DIR)/sapi/sapi-zfs-$(_sapi_stamp).zfs.gz
SAPI_MANIFEST_BIT=$(BITS_DIR)/sapi/sapi-zfs-$(_sapi_stamp).imgmanifest

.PHONY: sapi
sapi: $(SAPI_BITS) sapi_image


# PATH for sapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(SAPI_BITS): build/sapi
	@echo "# Build sapi: branch $(SAPI_BRANCH), sha $(SAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/sapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created sapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(SAPI_BITS)
	@echo ""

.PHONY: sapi_image
sapi_image: $(SAPI_IMAGE_BIT)

$(SAPI_IMAGE_BIT): $(SAPI_BITS)
	@echo "# Build sapi_image: branch $(SAPI_BRANCH), sha $(SAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(SAPI_IMAGE_UUID)" -t $(SAPI_BITS) \
		-o "$(SAPI_IMAGE_BIT)" -p $(SAPI_PKGSRC) \
		-t $(SAPI_EXTRA_TARBALLS) -n $(SAPI_IMAGE_NAME) \
		-v $(_sapi_stamp) -d $(SAPI_IMAGE_DESCRIPTION)
	@echo "# Created sapi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(SAPI_IMAGE_BIT))
	@echo ""

sapi_publish_image: $(SAPI_IMAGE_BIT)
	@echo "# Publish sapi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(SAPI_MANIFEST_BIT) -f $(SAPI_IMAGE_BIT)

# Warning: if SAPI's submodule deps change, this 'clean_sapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_sapi:
	$(RM) -rf $(BITS_DIR)/sapi
	(cd build/sapi && gmake clean)



#---- Marlin

_marlin_stamp=$(MARLIN_BRANCH)-$(TIMESTAMP)-g$(MARLIN_SHA)
MARLIN_BITS=$(BITS_DIR)/marlin/marlin-pkg-$(_marlin_stamp).tar.bz2
MARLIN_IMAGE_BIT=$(BITS_DIR)/marlin/marlin-zfs-$(_marlin_stamp).zfs.gz
MARLIN_MANIFEST_BIT=$(BITS_DIR)/marlin/marlin-zfs-$(_marlin_stamp).imgmanifest
MARLIN_AGENT_BIT=$(BITS_DIR)/marlin/marlin-$(_marlin_stamp).tar.gz
MARLIN_AGENT_MANIFEST_BIT=$(BITS_DIR)/marlin/marlin-$(_marlin_stamp).manifest

.PHONY: marlin
marlin: $(MARLIN_BITS) marlin_image

# PATH for marlin build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(MARLIN_BITS): build/marlin
	@echo "# Build marlin: branch $(MARLIN_BRANCH), sha $(MARLIN_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/marlin && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created marlin bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MARLIN_BITS) $(MARLIN_AGENT_BIT) $(MARLIN_AGENT_MANIFEST_BIT)
	@echo ""

.PHONY: marlin_image
marlin_image: $(MARLIN_IMAGE_BIT)

$(MARLIN_IMAGE_BIT): $(MARLIN_BITS)
	@echo "# Build marlin_image: branch $(MARLIN_BRANCH), sha $(MARLIN_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(MARLIN_IMAGE_UUID)" -t $(MARLIN_BITS) \
		-b "marlin" \
		-o "$(MARLIN_IMAGE_BIT)" -p $(MARLIN_PKGSRC) \
		-t $(MARLIN_EXTRA_TARBALLS) -n $(MARLIN_IMAGE_NAME) \
		-v $(_marlin_stamp) -d $(MARLIN_IMAGE_DESCRIPTION)
	@echo "# Created marlin image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(MARLIN_IMAGE_BIT))
	@echo ""

marlin_publish_image: $(MARLIN_IMAGE_BIT)
	@echo "# Publish marlin images to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MARLIN_MANIFEST_BIT) -f $(MARLIN_IMAGE_BIT)
	$(UPDATES_IMGADM) import -ddd -m $(MARLIN_AGENT_MANIFEST_BIT) -f $(MARLIN_AGENT_BIT)

clean_marlin:
	$(RM) -rf $(BITS_DIR)/marlin
	(cd build/marlin && gmake distclean)

#---- MEDUSA

_medusa_stamp=$(MEDUSA_BRANCH)-$(TIMESTAMP)-g$(MEDUSA_SHA)
MEDUSA_BITS=$(BITS_DIR)/medusa/medusa-pkg-$(_medusa_stamp).tar.bz2
MEDUSA_IMAGE_BIT=$(BITS_DIR)/medusa/medusa-zfs-$(_medusa_stamp).zfs.gz
MEDUSA_MANIFEST_BIT=$(BITS_DIR)/medusa/medusa-zfs-$(_medusa_stamp).imgmanifest

.PHONY: medusa
medusa: $(MEDUSA_BITS) medusa_image

$(MEDUSA_BITS): build/medusa
	@echo "# Build medusa: branch $(MEDUSA_BRANCH), sha $(MEDUSA_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/medusa && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created medusa bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MEDUSA_BITS)
	@echo ""


.PHONY: medusa_image
medusa_image: $(MEDUSA_IMAGE_BIT)

$(MEDUSA_IMAGE_BIT): $(MEDUSA_BITS)
	@echo "# Build medusa_image: branch $(MEDUSA_BRANCH), sha $(MEDUSA_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(MEDUSA_IMAGE_UUID)" -t $(MEDUSA_BITS) \
		-b "medusa" \
		-o "$(MEDUSA_IMAGE_BIT)" -p $(MEDUSA_PKGSRC) \
		-t $(MEDUSA_EXTRA_TARBALLS) -n $(MEDUSA_IMAGE_NAME) \
		-v $(_medusa_stamp) -d $(MEDUSA_IMAGE_DESCRIPTION)
	@echo "# Created medusa image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(MEDUSA_IMAGE_BIT))
	@echo ""

.PHONY: medusa_publish_image
medusa_publish_image: $(MEDUSA_IMAGE_BIT)
	@echo "# Publish medusa image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MEDUSA_MANIFEST_BIT) -f $(MEDUSA_IMAGE_BIT)

clean_medusa:
	$(RM) -rf $(BITS_DIR)/medusa
	(cd build/medusa && gmake distclean)

#---- MAHI

_mahi_stamp=$(MAHI_BRANCH)-$(TIMESTAMP)-g$(MAHI_SHA)
MAHI_BITS=$(BITS_DIR)/mahi/mahi-pkg-$(_mahi_stamp).tar.bz2
MAHI_IMAGE_BIT=$(BITS_DIR)/mahi/mahi-zfs-$(_mahi_stamp).zfs.gz
MAHI_MANIFEST_BIT=$(BITS_DIR)/mahi/mahi-zfs-$(_mahi_stamp).imgmanifest

.PHONY: mahi
mahi: $(MAHI_BITS) mahi_image

$(MAHI_BITS): build/mahi
	@echo "# Build mahi: branch $(MAHI_BRANCH), sha $(MAHI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/mahi && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created mahi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MAHI_BITS)
	@echo ""

.PHONY: mahi_image
mahi_image: $(MAHI_IMAGE_BIT)

$(MAHI_IMAGE_BIT): $(MAHI_BITS)
	@echo "# Build mahi_image: branch $(MAHI_BRANCH), sha $(MAHI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(MAHI_IMAGE_UUID)" -t $(MAHI_BITS) \
		-b "mahi" \
		-o "$(MAHI_IMAGE_BIT)" -p $(MAHI_PKGSRC) \
		-t $(MAHI_EXTRA_TARBALLS) -n $(MAHI_IMAGE_NAME) \
		-v $(_mahi_stamp) -d $(MAHI_IMAGE_DESCRIPTION)
	@echo "# Created mahi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(MAHI_IMAGE_BIT))
	@echo ""

mahi_publish_image: $(MAHI_IMAGE_BIT)
	@echo "# Publish mahi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MAHI_MANIFEST_BIT) -f $(MAHI_IMAGE_BIT)

clean_mahi:
	$(RM) -rf $(BITS_DIR)/mahi
	(cd build/mahi && gmake distclean)


#---- Mola

_mola_stamp=$(MOLA_BRANCH)-$(TIMESTAMP)-g$(MOLA_SHA)
MOLA_BITS=$(BITS_DIR)/mola/mola-pkg-$(_mola_stamp).tar.bz2
MOLA_IMAGE_BIT=$(BITS_DIR)/mola/mola-zfs-$(_mola_stamp).zfs.gz
MOLA_MANIFEST_BIT=$(BITS_DIR)/mola/mola-zfs-$(_mola_stamp).imgmanifest

.PHONY: mola
mola: $(MOLA_BITS) mola_image

# PATH for mola build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(MOLA_BITS): build/mola
	@echo "# Build mola: branch $(MOLA_BRANCH), sha $(MOLA_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/mola && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created mola bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MOLA_BITS)
	@echo ""

.PHONY: mola_image
mola_image: $(MOLA_IMAGE_BIT)

$(MOLA_IMAGE_BIT): $(MOLA_BITS)
	@echo "# Build mola_image: branch $(MOLA_BRANCH), sha $(MOLA_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(MOLA_IMAGE_UUID)" -t $(MOLA_BITS) \
		-b "mola" \
		-o "$(MOLA_IMAGE_BIT)" -p $(MOLA_PKGSRC) \
		-t $(MOLA_EXTRA_TARBALLS) -n $(MOLA_IMAGE_NAME) \
		-v $(_mola_stamp) -d $(MOLA_IMAGE_DESCRIPTION)
	@echo "# Created mola image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(MOLA_IMAGE_BIT))
	@echo ""

mola_publish_image: $(MOLA_IMAGE_BIT)
	@echo "# Publish mola image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MOLA_MANIFEST_BIT) -f $(MOLA_IMAGE_BIT)

clean_mola:
	$(RM) -rf $(BITS_DIR)/mola
	(cd build/mola && gmake distclean)


#---- Madtom

_madtom_stamp=$(MADTOM_BRANCH)-$(TIMESTAMP)-g$(MADTOM_SHA)
MADTOM_BITS=$(BITS_DIR)/madtom/madtom-pkg-$(_madtom_stamp).tar.bz2
MADTOM_IMAGE_BIT=$(BITS_DIR)/madtom/madtom-zfs-$(_madtom_stamp).zfs.gz
MADTOM_MANIFEST_BIT=$(BITS_DIR)/madtom/madtom-zfs-$(_madtom_stamp).imgmanifest

.PHONY: madtom
madtom: $(MADTOM_BITS) madtom_image

# PATH for madtom build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(MADTOM_BITS): build/madtom
	@echo "# Build madtom: branch $(MADTOM_BRANCH), sha $(MADTOM_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/madtom && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created madtom bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MADTOM_BITS)
	@echo ""

.PHONY: madtom_image
madtom_image: $(MADTOM_IMAGE_BIT)

$(MADTOM_IMAGE_BIT): $(MADTOM_BITS)
	@echo "# Build madtom_image: branch $(MADTOM_BRANCH), sha $(MADTOM_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(MADTOM_IMAGE_UUID)" -t $(MADTOM_BITS) \
		-b "madtom" \
		-o "$(MADTOM_IMAGE_BIT)" -p $(MADTOM_PKGSRC) \
		-t $(MADTOM_EXTRA_TARBALLS) -n $(MADTOM_IMAGE_NAME) \
		-v $(_madtom_stamp) -d $(MADTOM_IMAGE_DESCRIPTION)
	@echo "# Created madtom image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(MADTOM_IMAGE_BIT))
	@echo ""

madtom_publish_image: $(MADTOM_IMAGE_BIT)
	@echo "# Publish madtom image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MADTOM_MANIFEST_BIT) -f $(MADTOM_IMAGE_BIT)

clean_madtom:
	$(RM) -rf $(BITS_DIR)/madtom
	(cd build/madtom && gmake distclean)


#---- Marlin Dashboard

_marlin-dashboard_stamp=$(MARLIN_DASHBOARD_BRANCH)-$(TIMESTAMP)-g$(MARLIN_DASHBOARD_SHA)
MARLIN_DASHBOARD_BITS=$(BITS_DIR)/marlin-dashboard/marlin-dashboard-pkg-$(_marlin-dashboard_stamp).tar.bz2
MARLIN_DASHBOARD_IMAGE_BIT=$(BITS_DIR)/marlin-dashboard/marlin-dashboard-zfs-$(_marlin-dashboard_stamp).zfs.gz
MARLIN_DASHBOARD_MANIFEST_BIT=$(BITS_DIR)/marlin-dashboard/marlin-dashboard-zfs-$(_marlin-dashboard_stamp).imgmanifest

.PHONY: marlin-dashboard
marlin-dashboard: $(MARLIN_DASHBOARD_BITS) marlin-dashboard_image

# PATH for marlin-dashboard build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(MARLIN_DASHBOARD_BITS): build/marlin-dashboard
	@echo "# Build marlin-dashboard: branch $(MARLIN_DASHBOARD_BRANCH), sha $(MARLIN_DASHBOARD_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/marlin-dashboard && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created marlin-dashboard bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MARLIN_DASHBOARD_BITS)
	@echo ""

.PHONY: marlin-dashboard_image
marlin-dashboard_image: $(MARLIN_DASHBOARD_IMAGE_BIT)

$(MARLIN_DASHBOARD_IMAGE_BIT): $(MARLIN_DASHBOARD_BITS)
	@echo "# Build marlin-dashboard_image: branch $(MARLIN_DASHBOARD_BRANCH), sha $(MARLIN_DASHBOARD_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(MARLIN_DASHBOARD_IMAGE_UUID)" -t $(MARLIN_DASHBOARD_BITS) \
		-b "marlin-dashboard" \
		-o "$(MARLIN_DASHBOARD_IMAGE_BIT)" -p $(MARLIN_DASHBOARD_PKGSRC) \
		-t $(MARLIN_DASHBOARD_EXTRA_TARBALLS) -n $(MARLIN_DASHBOARD_IMAGE_NAME) \
		-v $(_marlin-dashboard_stamp) -d $(MARLIN_DASHBOARD_IMAGE_DESCRIPTION)
	@echo "# Created marlin-dashboard image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(MARLIN_DASHBOARD_IMAGE_BIT))
	@echo ""

marlin-dashboard_publish_image: $(MARLIN_DASHBOARD_IMAGE_BIT)
	@echo "# Publish marlin-dashboard image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MARLIN_DASHBOARD_MANIFEST_BIT) -f $(MARLIN_DASHBOARD_IMAGE_BIT)

clean_marlin-dashboard:
	$(RM) -rf $(BITS_DIR)/marlin-dashboard
	(cd build/marlin-dashboard && gmake distclean)


#---- Propeller

_propeller_stamp=$(PROPELLER_BRANCH)-$(TIMESTAMP)-g$(PROPELLER_SHA)
PROPELLER_BITS=$(BITS_DIR)/propeller/propeller-pkg-$(_propeller_stamp).tar.bz2
PROPELLER_IMAGE_BIT=$(BITS_DIR)/propeller/propeller-zfs-$(_propeller_stamp).zfs.gz
PROPELLER_MANIFEST_BIT=$(BITS_DIR)/propeller/propeller-zfs-$(_propeller_stamp).imgmanifest

.PHONY: propeller
propeller: $(PROPELLER_BITS) propeller_image

# PATH for propeller build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(PROPELLER_BITS): build/propeller
	@echo "# Build propeller: branch $(PROPELLER_BRANCH), sha $(PROPELLER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/propeller && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created propeller bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(PROPELLER_BITS)
	@echo ""

.PHONY: propeller_image
propeller_image: $(PROPELLER_IMAGE_BIT)

$(PROPELLER_IMAGE_BIT): $(PROPELLER_BITS)
	@echo "# Build propeller_image: branch $(PROPELLER_BRANCH), sha $(PROPELLER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(PROPELLER_IMAGE_UUID)" -t $(PROPELLER_BITS) \
		-b "propeller" \
		-o "$(PROPELLER_IMAGE_BIT)" -p $(PROPELLER_PKGSRC) \
		-t $(PROPELLER_EXTRA_TARBALLS) -n $(PROPELLER_IMAGE_NAME) \
		-v $(_propeller_stamp) -d $(PROPELLER_IMAGE_DESCRIPTION)
	@echo "# Created propeller image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(PROPELLER_IMAGE_BIT))
	@echo ""

propeller_publish_image: $(PROPELLER_IMAGE_BIT)
	@echo "# Publish propeller image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(PROPELLER_MANIFEST_BIT) -f $(PROPELLER_IMAGE_BIT)

clean_propeller:
	$(RM) -rf $(BITS_DIR)/propeller
	(cd build/propeller && gmake distclean)


#---- Moray

_moray_stamp=$(MORAY_BRANCH)-$(TIMESTAMP)-g$(MORAY_SHA)
MORAY_BITS=$(BITS_DIR)/moray/moray-pkg-$(_moray_stamp).tar.bz2
MORAY_IMAGE_BIT=$(BITS_DIR)/moray/moray-zfs-$(_moray_stamp).zfs.gz
MORAY_MANIFEST_BIT=$(BITS_DIR)/moray/moray-zfs-$(_moray_stamp).imgmanifest

.PHONY: moray
moray: $(MORAY_BITS) moray_image

# PATH for moray build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(MORAY_BITS): build/moray
	@echo "# Build moray: branch $(MORAY_BRANCH), sha $(MORAY_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/moray && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created moray bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MORAY_BITS)
	@echo ""

.PHONY: moray_image
moray_image: $(MORAY_IMAGE_BIT)

$(MORAY_IMAGE_BIT): $(MORAY_BITS)
	@echo "# Build moray_image: branch $(MORAY_BRANCH), sha $(MORAY_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(MORAY_IMAGE_UUID)" -t $(MORAY_BITS) \
		-b "moray" \
		-o "$(MORAY_IMAGE_BIT)" -p $(MORAY_PKGSRC) \
		-t $(MORAY_EXTRA_TARBALLS) -n $(MORAY_IMAGE_NAME) \
		-v $(_moray_stamp) -d $(MORAY_IMAGE_DESCRIPTION)
	@echo "# Created moray image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(MORAY_IMAGE_BIT))
	@echo ""

moray_publish_image: $(MORAY_IMAGE_BIT)
	@echo "# Publish moray image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MORAY_MANIFEST_BIT) -f $(MORAY_IMAGE_BIT)

clean_moray:
	$(RM) -rf $(BITS_DIR)/moray
	(cd build/moray && gmake distclean)


#---- Electric-Moray

_electric-moray_stamp=$(ELECTRIC_MORAY_BRANCH)-$(TIMESTAMP)-g$(ELECTRIC_MORAY_SHA)
ELECTRIC_MORAY_BITS=$(BITS_DIR)/electric-moray/electric-moray-pkg-$(_electric-moray_stamp).tar.bz2
ELECTRIC_MORAY_IMAGE_BIT=$(BITS_DIR)/electric-moray/electric-moray-zfs-$(_electric-moray_stamp).zfs.gz
ELECTRIC_MORAY_MANIFEST_BIT=$(BITS_DIR)/electric-moray/electric-moray-zfs-$(_electric-moray_stamp).imgmanifest

.PHONY: electric-moray
electric-moray: $(ELECTRIC_MORAY_BITS) electric-moray_image

# PATH for electric-moray build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(ELECTRIC_MORAY_BITS): build/electric-moray
	@echo "# Build electric-moray: branch $(ELECTRIC_MORAY_BRANCH), sha $(ELECTRIC_MORAY_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/electric-moray && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created electric-moray bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(ELECTRIC_MORAY_BITS)
	@echo ""

.PHONY: electric-moray_image
electric-moray_image: $(ELECTRIC_MORAY_IMAGE_BIT)

$(ELECTRIC_MORAY_IMAGE_BIT): $(ELECTRIC_MORAY_BITS)
	@echo "# Build electric-moray_image: branch $(ELECTRIC_MORAY_BRANCH), sha $(ELECTRIC_MORAY_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(ELECTRIC_MORAY_IMAGE_UUID)" -t $(ELECTRIC_MORAY_BITS) \
		-b "electric-moray" \
		-o "$(ELECTRIC_MORAY_IMAGE_BIT)" -p $(ELECTRIC_MORAY_PKGSRC) \
		-t $(ELECTRIC_MORAY_EXTRA_TARBALLS) -n $(ELECTRIC_MORAY_IMAGE_NAME) \
		-v $(_electric-moray_stamp) -d $(ELECTRIC_MORAY_IMAGE_DESCRIPTION)
	@echo "# Created electric-moray image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(ELECTRIC_MORAY_IMAGE_BIT))
	@echo ""

electric-moray_publish_image: $(ELECTRIC_MORAY_IMAGE_BIT)
	@echo "# Publish electric-moray image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(ELECTRIC_MORAY_MANIFEST_BIT) -f $(ELECTRIC_MORAY_IMAGE_BIT)

clean_electric-moray:
	$(RM) -rf $(BITS_DIR)/electric-moray
	(cd build/electric-moray && gmake distclean)


#---- Muskie

_muskie_stamp=$(MUSKIE_BRANCH)-$(TIMESTAMP)-g$(MUSKIE_SHA)
MUSKIE_BITS=$(BITS_DIR)/muskie/muskie-pkg-$(_muskie_stamp).tar.bz2
MUSKIE_IMAGE_BIT=$(BITS_DIR)/muskie/muskie-zfs-$(_muskie_stamp).zfs.gz
MUSKIE_MANIFEST_BIT=$(BITS_DIR)/muskie/muskie-zfs-$(_muskie_stamp).imgmanifest

.PHONY: muskie
muskie: $(MUSKIE_BITS) muskie_image

# PATH for muskie build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(MUSKIE_BITS): build/muskie
	@echo "# Build muskie: branch $(MUSKIE_BRANCH), sha $(MUSKIE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/muskie && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created muskie bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MUSKIE_BITS)
	@echo ""

.PHONY: muskie_image
muskie_image: $(MUSKIE_IMAGE_BIT)

$(MUSKIE_IMAGE_BIT): $(MUSKIE_BITS)
	@echo "# Build muskie_image: branch $(MUSKIE_BRANCH), sha $(MUSKIE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(MUSKIE_IMAGE_UUID)" -t $(MUSKIE_BITS) \
		-b "muskie" \
		-o "$(MUSKIE_IMAGE_BIT)" -p $(MUSKIE_PKGSRC) \
		-t $(MUSKIE_EXTRA_TARBALLS) -n $(MUSKIE_IMAGE_NAME) \
		-v $(_muskie_stamp) -d $(MUSKIE_IMAGE_DESCRIPTION)
	@echo "# Created muskie image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(MUSKIE_IMAGE_BIT))
	@echo ""

muskie_publish_image: $(MUSKIE_IMAGE_BIT)
	@echo "# Publish muskie image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MUSKIE_MANIFEST_BIT) -f $(MUSKIE_IMAGE_BIT)

clean_muskie:
	$(RM) -rf $(BITS_DIR)/muskie
	(cd build/muskie && gmake distclean)


#---- Wrasse

_wrasse_stamp=$(WRASSE_BRANCH)-$(TIMESTAMP)-g$(WRASSE_SHA)
WRASSE_BITS=$(BITS_DIR)/wrasse/wrasse-pkg-$(_wrasse_stamp).tar.bz2
WRASSE_IMAGE_BIT=$(BITS_DIR)/wrasse/wrasse-zfs-$(_wrasse_stamp).zfs.gz
WRASSE_MANIFEST_BIT=$(BITS_DIR)/wrasse/wrasse-zfs-$(_wrasse_stamp).imgmanifest

.PHONY: wrasse
wrasse: $(WRASSE_BITS) wrasse_image

# PATH for wrasse build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(WRASSE_BITS): build/wrasse
	@echo "# Build wrasse: branch $(WRASSE_BRANCH), sha $(WRASSE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/wrasse && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created wrasse bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(WRASSE_BITS)
	@echo ""

.PHONY: wrasse_image
wrasse_image: $(WRASSE_IMAGE_BIT)

$(WRASSE_IMAGE_BIT): $(WRASSE_BITS)
	@echo "# Build wrasse_image: branch $(WRASSE_BRANCH), sha $(WRASSE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(WRASSE_IMAGE_UUID)" -t $(WRASSE_BITS) \
		-b "wrasse" \
		-o "$(WRASSE_IMAGE_BIT)" -p $(WRASSE_PKGSRC) \
		-t $(WRASSE_EXTRA_TARBALLS) -n $(WRASSE_IMAGE_NAME) \
		-v $(_wrasse_stamp) -d $(WRASSE_IMAGE_DESCRIPTION)
	@echo "# Created wrasse image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(WRASSE_IMAGE_BIT))
	@echo ""

wrasse_publish_image: $(WRASSE_IMAGE_BIT)
	@echo "# Publish wrasse image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(WRASSE_MANIFEST_BIT) -f $(WRASSE_IMAGE_BIT)

clean_wrasse:
	$(RM) -rf $(BITS_DIR)/wrasse
	(cd build/wrasse && gmake distclean)


#---- Registrar

_registrar_stamp=$(REGISTRAR_BRANCH)-$(TIMESTAMP)-g$(REGISTRAR_SHA)
REGISTRAR_BITS=$(BITS_DIR)/registrar/registrar-pkg-$(_registrar_stamp).tar.bz2

.PHONY: registrar
registrar: $(REGISTRAR_BITS)

$(REGISTRAR_BITS): build/registrar
	@echo "# Build registrar: branch $(REGISTRAR_BRANCH), sha $(REGISTRAR_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/registrar && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created registrar bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(REGISTRAR_BITS)
	@echo ""

clean_registrar:
	$(RM) -rf $(BITS_DIR)/registrar
	(cd build/registrar && gmake distclean)


#---- mackerel

_mackerel_stamp=$(MACKEREL_BRANCH)-$(TIMESTAMP)-g$(MACKEREL_SHA)
MACKEREL_BITS=$(BITS_DIR)/mackerel/mackerel-pkg-$(_mackerel_stamp).tar.bz2

.PHONY: mackerel
mackerel: $(MACKEREL_BITS)

$(MACKEREL_BITS): build/mackerel
	@echo "# Build mackerel: branch $(MACKEREL_BRANCH), sha $(MACKEREL_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/mackerel && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created mackerel bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MACKEREL_BITS)
	@echo ""

clean_mackerel:
	$(RM) -rf $(BITS_DIR)/mackerel
	(cd build/mackerel && gmake distclean)


#---- Binder

_binder_stamp=$(BINDER_BRANCH)-$(TIMESTAMP)-g$(BINDER_SHA)
BINDER_BITS=$(BITS_DIR)/binder/binder-pkg-$(_binder_stamp).tar.bz2
BINDER_IMAGE_BIT=$(BITS_DIR)/binder/binder-zfs-$(_binder_stamp).zfs.gz
BINDER_MANIFEST_BIT=$(BITS_DIR)/binder/binder-zfs-$(_binder_stamp).imgmanifest

.PHONY: binder
binder: $(BINDER_BITS) binder_image

$(BINDER_BITS): build/binder
	@echo "# Build binder: branch $(BINDER_BRANCH), sha $(BINDER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/binder && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created binder bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(BINDER_BITS)
	@echo ""

.PHONY: binder_image
binder_image: $(BINDER_IMAGE_BIT)

$(BINDER_IMAGE_BIT): $(BINDER_BITS)
	@echo "# Build binder_image: branch $(BINDER_BRANCH), sha $(BINDER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(BINDER_IMAGE_UUID)" -t $(BINDER_BITS) \
		-b "binder" \
		-o "$(BINDER_IMAGE_BIT)" -p $(BINDER_PKGSRC) \
		-t $(BINDER_EXTRA_TARBALLS) -n $(BINDER_IMAGE_NAME) \
		-v $(_binder_stamp) -d $(BINDER_IMAGE_DESCRIPTION)
	@echo "# Created binder image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(BINDER_IMAGE_BIT))
	@echo ""

binder_publish_image: $(BINDER_IMAGE_BIT)
	@echo "# Publish binder image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(BINDER_MANIFEST_BIT) -f $(BINDER_IMAGE_BIT)

clean_binder:
	$(RM) -rf $(BITS_DIR)/binder
	(cd build/binder && gmake distclean)


#---- sdc-zookeeper

_sdc-zookeeper_stamp=$(SDC_ZOOKEEPER_BRANCH)-$(TIMESTAMP)-g$(SDC_ZOOKEEPER_SHA)
SDC_ZOOKEEPER_BITS=$(BITS_DIR)/sdc-zookeeper/sdc-zookeeper-pkg-$(_sdc-zookeeper_stamp).tar.bz2
SDC_ZOOKEEPER_IMAGE_BIT=$(BITS_DIR)/sdc-zookeeper/sdc-zookeeper-zfs-$(_sdc-zookeeper_stamp).zfs.gz
SDC_ZOOKEEPER_MANIFEST_BIT=$(BITS_DIR)/sdc-zookeeper/sdc-zookeeper-zfs-$(_sdc-zookeeper_stamp).imgmanifest

.PHONY: sdc-zookeeper
sdc-zookeeper: $(SDC_ZOOKEEPER_BITS) sdc-zookeeper_image

$(SDC_ZOOKEEPER_BITS): build/sdc-zookeeper
	@echo "# Build sdc-zookeeper: branch $(SDC_ZOOKEEPER_BRANCH), sha $(SDC_ZOOKEEPER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/sdc-zookeeper && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created sdc-zookeeper bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(SDC_ZOOKEEPER_BITS)
	@echo ""

.PHONY: sdc-zookeeper_image
sdc-zookeeper_image: $(SDC_ZOOKEEPER_IMAGE_BIT)

$(SDC_ZOOKEEPER_IMAGE_BIT): $(SDC_ZOOKEEPER_BITS)
	@echo "# Build sdc-zookeeper_image: branch $(SDC_ZOOKEEPER_BRANCH), sha $(SDC_ZOOKEEPER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(SDC_ZOOKEEPER_IMAGE_UUID)" -t $(SDC_ZOOKEEPER_BITS) \
		-b "sdc-zookeeper" \
		-o "$(SDC_ZOOKEEPER_IMAGE_BIT)" -p $(SDC_ZOOKEEPER_PKGSRC) \
		-t $(SDC_ZOOKEEPER_EXTRA_TARBALLS) -n $(SDC_ZOOKEEPER_IMAGE_NAME) \
		-v $(_sdc-zookeeper_stamp) -d $(SDC_ZOOKEEPER_IMAGE_DESCRIPTION)
	@echo "# Created sdc-zookeeper image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(SDC_ZOOKEEPER_IMAGE_BIT))
	@echo ""

sdc-zookeeper_publish_image: $(SDC_ZOOKEEPER_IMAGE_BIT)
	@echo "# Publish sdc-zookeeper image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(SDC_ZOOKEEPER_MANIFEST_BIT) -f $(SDC_ZOOKEEPER_IMAGE_BIT)

clean_sdc-zookeeper:
	$(RM) -rf $(BITS_DIR)/sdc-zookeeper
	(cd build/sdc-zookeeper && gmake distclean)


#---- Muppet

_muppet_stamp=$(MUPPET_BRANCH)-$(TIMESTAMP)-g$(MUPPET_SHA)
MUPPET_BITS=$(BITS_DIR)/muppet/muppet-pkg-$(_muppet_stamp).tar.bz2
MUPPET_IMAGE_BIT=$(BITS_DIR)/muppet/muppet-zfs-$(_muppet_stamp).zfs.gz
MUPPET_MANIFEST_BIT=$(BITS_DIR)/muppet/muppet-zfs-$(_muppet_stamp).imgmanifest

.PHONY: muppet
muppet: $(MUPPET_BITS) muppet_image

$(MUPPET_BITS): build/muppet
	@echo "# Build muppet: branch $(MUPPET_BRANCH), sha $(MUPPET_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/muppet && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created muppet bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MUPPET_BITS)
	@echo ""

.PHONY: muppet_image
muppet_image: $(MUPPET_IMAGE_BIT)

$(MUPPET_IMAGE_BIT): $(MUPPET_BITS)
	@echo "# Build muppet_image: branch $(MUPPET_BRANCH), sha $(MUPPET_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(MUPPET_IMAGE_UUID)" -t $(MUPPET_BITS) \
		-b "muppet" \
		-o "$(MUPPET_IMAGE_BIT)" -p $(MUPPET_PKGSRC) \
		-t $(MUPPET_EXTRA_TARBALLS) -n $(MUPPET_IMAGE_NAME) \
		-v $(_muppet_stamp) -d $(MUPPET_IMAGE_DESCRIPTION)
	@echo "# Created muppet image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(MUPPET_IMAGE_BIT))
	@echo ""

muppet_publish_image: $(MUPPET_IMAGE_BIT)
	@echo "# Publish muppet image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MUPPET_MANIFEST_BIT) -f $(MUPPET_IMAGE_BIT)

clean_muppet:
	$(RM) -rf $(BITS_DIR)/muppet
	(cd build/muppet && gmake distclean)

#---- Minnow

_minnow_stamp=$(MINNOW_BRANCH)-$(TIMESTAMP)-g$(MINNOW_SHA)
MINNOW_BITS=$(BITS_DIR)/minnow/minnow-pkg-$(_minnow_stamp).tar.bz2

.PHONY: minnow
minnow: $(MINNOW_BITS)

$(MINNOW_BITS): build/minnow
	@echo "# Build minnow: branch $(MINNOW_BRANCH), sha $(MINNOW_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/minnow && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created minnow bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MINNOW_BITS)
	@echo ""

clean_minnow:
	$(RM) -rf $(BITS_DIR)/minnow
	(cd build/minnow && gmake distclean)


#---- Mako

_mako_stamp=$(MAKO_BRANCH)-$(TIMESTAMP)-g$(MAKO_SHA)
MAKO_BITS=$(BITS_DIR)/mako/mako-pkg-$(_mako_stamp).tar.bz2
MAKO_IMAGE_BIT=$(BITS_DIR)/mako/mako-zfs-$(_mako_stamp).zfs.gz
MAKO_MANIFEST_BIT=$(BITS_DIR)/mako/mako-zfs-$(_mako_stamp).imgmanifest

.PHONY: mako
mako: $(MAKO_BITS) mako_image

$(MAKO_BITS): build/mako
	@echo "# Build mako: branch $(MAKO_BRANCH), sha $(MAKO_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/mako && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created mako bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MAKO_BITS)
	@echo ""

.PHONY: mako_image
mako_image: $(MAKO_IMAGE_BIT)

$(MAKO_IMAGE_BIT): $(MAKO_BITS)
	@echo "# Build mako_image: branch $(MAKO_BRANCH), sha $(MAKO_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(MAKO_IMAGE_UUID)" -t $(MAKO_BITS) \
		-b "mako" \
		-o "$(MAKO_IMAGE_BIT)" -p $(MAKO_PKGSRC) \
		-t $(MAKO_EXTRA_TARBALLS) -n $(MAKO_IMAGE_NAME) \
		-v $(_mako_stamp) -d $(MAKO_IMAGE_DESCRIPTION)
	@echo "# Created mako image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(MAKO_IMAGE_BIT))
	@echo ""

mako_publish_image: $(MAKO_IMAGE_BIT)
	@echo "# Publish mako image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MAKO_MANIFEST_BIT) -f $(MAKO_IMAGE_BIT)

clean_mako:
	$(RM) -rf $(BITS_DIR)/mako
	(cd build/mako && gmake distclean)


#---- sdcadm

ifeq ($(TRY_BRANCH),)
_sdcadm_stamp=$(SDCADM_BRANCH)-$(TIMESTAMP)-g$(SDCADM_SHA)
else
_sdcadm_stamp=$(TRY_BRANCH)-$(TIMESTAMP)-g$(SDCADM_SHA)
endif
SDCADM_PKG_BIT=$(BITS_DIR)/sdcadm/sdcadm-$(_sdcadm_stamp).sh
SDCADM_MANIFEST_BIT=$(BITS_DIR)/sdcadm/sdcadm-$(_sdcadm_stamp).imgmanifest
SDCADM_BITS=$(SDCADM_PKG_BIT) $(SDCADM_MANIFEST_BIT)

.PHONY: sdcadm
sdcadm: $(SDCADM_PKG_BIT)

$(SDCADM_BITS): build/sdcadm/Makefile
	@echo "# Build sdcadm: branch $(SDCADM_BRANCH), sha $(SDCADM_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)/sdcadm
	(cd build/sdcadm && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created sdcadm bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(SDCADM_BITS)
	@echo ""

clean_sdcadm:
	$(RM) -rf $(BITS_DIR)/sdcadm

sdcadm_publish_image: $(SDCADM_BITS)
	@echo "# Publish sdcadm image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(SDCADM_MANIFEST_BIT) -f $(SDCADM_PKG_BIT) -c none


#---- agentsshar

ifeq ($(TRY_BRANCH),)
_as_stamp=$(AGENTS_INSTALLER_BRANCH)-$(TIMESTAMP)-g$(AGENTS_INSTALLER_SHA)
else
_as_stamp=$(TRY_BRANCH)-$(TIMESTAMP)-g$(AGENTS_INSTALLER_SHA)
endif
AGENTSSHAR_BITS=$(BITS_DIR)/agentsshar/agents-$(_as_stamp).sh \
	$(BITS_DIR)/agentsshar/agents-$(_as_stamp).md5sum
AGENTSSHAR_BITS_0=$(shell echo $(AGENTSSHAR_BITS) | awk '{print $$1}')
AGENTSSHAR_MANIFEST_BIT=$(BITS_DIR)/agentsshar/agents-$(_as_stamp).manifest

.PHONY: agentsshar
agentsshar: $(AGENTSSHAR_BITS_0)

$(AGENTSSHAR_BITS): build/agents-installer/Makefile
	@echo "# Build agentsshar: branch $(AGENTS_INSTALLER_BRANCH), sha $(AGENTS_INSTALLER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)/agentsshar
	(cd build/agents-installer && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) ./mk-agents-shar -o $(BITS_DIR)/agentsshar/ -d $(BITS_DIR) -b "$(TRY_BRANCH) $(BRANCH)")
	@echo "# Created agentsshar bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(AGENTSSHAR_BITS)
	@echo ""

agentsshar_publish_image: $(AGENTSSHAR_BITS)
	@echo "# Publish agentsshar image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(AGENTSSHAR_MANIFEST_BIT) -f $(AGENTSSHAR_BITS_0)

clean_agentsshar:
	$(RM) -rf $(BITS_DIR)/agentsshar
	(if [[ -d build/agents-installer ]]; then cd build/agents-installer && gmake clean; fi )


#---- convertvm

_convertvm_stamp=$(CONVERTVM_BRANCH)-$(TIMESTAMP)-g$(CONVERTVM_SHA)
CONVERTVM_BITS=$(BITS_DIR)/convertvm/convertvm-$(_convertvm_stamp).tar.bz2

.PHONY: convertvm
convertvm: $(CONVERTVM_BITS)

# PATH for convertvm build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(CONVERTVM_BITS): build/convertvm
	@echo "# Build convertvm: branch $(CONVERTVM_BRANCH), sha $(CONVERTVM_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/convertvm && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created convertvm bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(CONVERTVM_BITS)
	@echo ""

# Warning: if convertvm's submodule deps change, this 'clean_convertvm' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_convertvm:
	$(RM) -rf $(BITS_DIR)/convertvm
	(cd build/convertvm && gmake clean)


#---- Manta deployment (the manta zone)

_manta_deployment_stamp=$(MANTA_DEPLOYMENT_BRANCH)-$(TIMESTAMP)-g$(MANTA_DEPLOYMENT_SHA)
MANTA_DEPLOYMENT_BITS=$(BITS_DIR)/manta-deployment/manta-deployment-pkg-$(_manta_deployment_stamp).tar.bz2
MANTA_DEPLOYMENT_IMAGE_BIT=$(BITS_DIR)/manta-deployment/manta-deployment-zfs-$(_manta_deployment_stamp).zfs.gz
MANTA_DEPLOYMENT_MANIFEST_BIT=$(BITS_DIR)/manta-deployment/manta-deployment-zfs-$(_manta_deployment_stamp).imgmanifest

.PHONY: manta-deployment
manta-deployment: $(MANTA_DEPLOYMENT_BITS) manta-deployment_image

$(MANTA_DEPLOYMENT_BITS): build/manta-deployment
	@echo "# Build manta-deployment: branch $(MANTA_DEPLOYMENT_BRANCH), sha $(MANTA_DEPLOYMENT_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/manta-deployment && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created manta-deployment bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MANTA_DEPLOYMENT_BITS)
	@echo ""

.PHONY: manta-deployment_image
manta-deployment_image: $(MANTA_DEPLOYMENT_IMAGE_BIT)

$(MANTA_DEPLOYMENT_IMAGE_BIT): $(MANTA_DEPLOYMENT_BITS)
	@echo "# Build manta-deployment_image: branch $(MANTA_DEPLOYMENT_BRANCH), sha $(MANTA_DEPLOYMENT_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset_in_jpc.sh -i "$(MANTA_DEPLOYMENT_IMAGE_UUID)" -t $(MANTA_DEPLOYMENT_BITS) \
		-o "$(MANTA_DEPLOYMENT_IMAGE_BIT)" -p $(MANTA_DEPLOYMENT_PKGSRC) \
		-t $(MANTA_DEPLOYMENT_EXTRA_TARBALLS) -n $(MANTA_DEPLOYMENT_IMAGE_NAME) \
		-v $(_manta_deployment_stamp) -d $(MANTA_DEPLOYMENT_IMAGE_DESCRIPTION)
	@echo "# Created manta-deployment image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $$(dirname $(MANTA_DEPLOYMENT_IMAGE_BIT))
	@echo ""

manta-deployment_publish_image: $(MANTA_DEPLOYMENT_IMAGE_BIT)
	@echo "# Publish manta-deployment image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MANTA_DEPLOYMENT_MANIFEST_BIT) -f $(MANTA_DEPLOYMENT_IMAGE_BIT)


clean_manta-deployment:
	$(RM) -rf $(BITS_DIR)/manta-deployment
	(cd build/manta-deployment && gmake distclean)



#---- sdcboot (boot utilities for usb-headnode)

_sdcboot_stamp=$(SDCBOOT_BRANCH)-$(TIMESTAMP)-g$(SDCBOOT_SHA)
SDCBOOT_BITS=$(BITS_DIR)/sdcboot/sdcboot-$(_sdcboot_stamp).tgz

.PHONY: sdcboot
sdcboot: $(SDCBOOT_BITS)

$(SDCBOOT_BITS): build/sdcboot
	mkdir -p $(BITS_DIR)
	(cd build/sdcboot && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) \
	    gmake pkg release publish)
	@echo "# Created sdcboot bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(SDCBOOT_BITS)
	@echo ""

clean_sdcboot:
	$(RM) -rf $(BITS_DIR)/sdcboot
	(cd build/sdcboot && gmake clean)

#---- firmware-tools (Legacy-mode FDUM facilities and firmware for Joyent HW)

ifeq ($(JOYENT_BUILD),true)

_firmware_tools_stamp=$(FIRMWARE_TOOLS_BRANCH)-$(TIMESTAMP)-g$(FIRMWARE_TOOLS_SHA)
FIRMWARE_TOOLS_BITS=$(BITS_DIR)/firmware-tools/firmware-tools-$(_firmware_tools_stamp).tgz

.PHONY: firmware-tools
firmware-tools: $(FIRMWARE_TOOLS_BITS)

$(FIRMWARE_TOOLS_BITS): build/firmware-tools
	mkdir -p $(BITS_DIR)
	(cd build/firmware-tools && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) \
	    gmake pkg release publish)
	@echo "# Created firmware-tools bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(FIRMWARE_TOOLS_BITS)
	@echo ""

clean_firmware-tools:
	$(RM) -rf $(BITS_DIR)/firmware-tools
	(cd build/firmware-tools && gmake clean)

endif	# $(JOYENT_BUILD) == true

#---- usb-headnode
# We are using the '-s STAGE-DIR' option to the usb-headnode build to
# avoid rebuilding it. We use the "boot" target to build the stage dir
# and have the other usb-headnode targets depend on that.
#
# TODO:
# - solution for datasets
# - pkgsrc isolation

.PHONY: usbheadnode usbheadnode-debug
usbheadnode usbheadnode-debug: cleanimgcruft boot coal usb releasejson

usbheadnode: USB_HEADNODE_SUFFIX = ""
usbheadnode-debug: USB_HEADNODE_SUFFIX = "-debug"
usbheadnode: USE_DEBUG_PLATFORM = false
usbheadnode-debug: USE_DEBUG_PLATFORM = true

_usbheadnode_stamp=$(USB_HEADNODE_BRANCH)-$(TIMESTAMP)-g$(USB_HEADNODE_SHA)

USB_BUILD_DIR=$(BUILD_DIR)/usb-headnode
USB_BITS_DIR=$(BITS_DIR)/usbheadnode$(USB_HEADNODE_SUFFIX)

USB_BITS_SPEC=$(USB_BITS_DIR)/build.spec.local

USB_BUILD_SPEC_ENV = \
	USE_DEBUG_PLATFORM=$(USE_DEBUG_PLATFORM) \
	JOYENT_BUILD=$(JOYENT_BUILD)

BOOT_BUILD=$(USB_BUILD_DIR)/boot-$(_usbheadnode_stamp).tgz
BOOT_OUTPUT=$(USB_BITS_DIR)/boot$(USB_HEADNODE_SUFFIX)-$(_usbheadnode_stamp).tgz


# Delete any failed image files that might be sitting around, this is safe
# because only one usbheadnode build runs at a time. Also cleanup any unused
# lofi devices (used ones will just fail)
.PHONY: cleanimgcruft
cleanimgcruft:
	$(RM) -vf /tmp/*4gb.img
	for dev in $(shell lofiadm | cut -d ' ' -f1 | grep -v "^Block"); do pfexec lofiadm -d ${dev}; done

.PHONY: boot
boot: $(BOOT_OUTPUT)

$(USB_BITS_DIR):
	mkdir -p $(USB_BITS_DIR)

$(BOOT_OUTPUT): $(USB_BITS_SPEC) $(USB_BITS_DIR)
	@echo "# Build boot: usb-headnode branch $(USB_HEADNODE_BRANCH), sha $(USB_HEADNODE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	cd build/usb-headnode \
		&& BITS_DIR=$(BITS_DIR) TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(BUILD_DIR) PKGSRC_DIR=$(TOP)/build/pkgsrc make tar
	mv $(BOOT_BUILD) $(BOOT_OUTPUT)
	@echo "# Created boot bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(BOOT_OUTPUT)
	@echo ""


COAL_BUILD=$(USB_BUILD_DIR)/coal-$(_usbheadnode_stamp)-4gb.tgz
COAL_OUTPUT=$(USB_BITS_DIR)/coal$(USB_HEADNODE_SUFFIX)-$(_usbheadnode_stamp)-4gb.tgz

$(USB_BITS_SPEC): $(USB_BITS_DIR)
	$(USB_BUILD_SPEC_ENV) bash <build.spec.in >$(USB_BITS_SPEC)
	(cd $(USB_BUILD_DIR); $(RM) -f build.spec.local; ln -s $(USB_BITS_SPEC))

.PHONY: coal
coal: usb $(COAL_OUTPUT)

$(COAL_OUTPUT): $(USB_BITS_SPEC) $(USB_OUTPUT)
	@echo "# Build coal: usb-headnode branch $(USB_HEADNODE_BRANCH), sha $(USB_HEADNODE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	cd build/usb-headnode \
		&& BITS_URL=$(BITS_DIR) TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(BUILD_DIR) PKGSRC_DIR=$(TOP)/build/pkgsrc ./bin/build-coal-image -c $(USB_OUTPUT)
	mv $(COAL_BUILD) $(COAL_OUTPUT)
	@echo "# Created coal bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(COAL_OUTPUT)
	@echo ""

USB_BUILD=$(USB_BUILD_DIR)/usb-$(_usbheadnode_stamp).tgz
USB_OUTPUT=$(USB_BITS_DIR)/usb$(USB_HEADNODE_SUFFIX)-$(_usbheadnode_stamp).tgz

.PHONY: usb
usb: $(USB_OUTPUT)

$(USB_OUTPUT): $(USB_BITS_SPEC) $(BOOT_OUTPUT)
	@echo "# Build usb: usb-headnode branch $(USB_HEADNODE_BRANCH), sha $(USB_HEADNODE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	cd build/usb-headnode \
		&& BITS_URL=$(BITS_DIR) TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(BUILD_DIR) PKGSRC_DIR=$(TOP)/build/pkgsrc ./bin/build-usb-image -c $(BOOT_OUTPUT)
	mv $(USB_BUILD) $(USB_OUTPUT)
	@echo "# Created usb bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(USB_OUTPUT)
	@echo ""


# A usbheadnode image that can be imported to an IMGAPI and used for
# sdc-on-sdc.

IMAGE_BUILD=$(USB_BUILD)/usb-$(_usbheadnode_stamp).zvol.bz2
IMAGE_OUTPUT=$(USB_BITS_DIR)/usb$(USB_HEADNODE_SUFFIX)-$(_usbheadnode_stamp).zvol.bz2
MANIFEST_BUILD=$(USB_BUILD)/usb-$(_usbheadnode_stamp).dsmanifest
MANIFEST_OUTPUT=$(USB_BITS_DIR)/usb$(USB_HEADNODE_SUFFIX)-$(_usbheadnode_stamp).dsmanifest

.PHONY: image
image: $(IMAGE_OUTPUT)

$(IMAGE_OUTPUT): $(USB_BITS_SPEC) $(USB_OUTPUT)
	@echo "# Build sdc-on-sdc image: usb-headnode branch $(USB_HEADNODE_BRANCH), sha $(USB_HEADNODE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	cd build/usb-headnode \
		&& BITS_URL=$(BITS_DIR) TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(BUILD_DIR) PKGSRC_DIR=$(TOP)/build/pkgsrc ./bin/build-dataset $(USB_OUTPUT)
	mv $(IMAGE_BUILD) $(MANIFEST_BUILD) $(USB_BITS_DIR)/
	@echo "# Created image bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(MANIFEST_OUTPUT) $(IMAGE_OUTPUT)
	@echo ""


RELEASEJSON_BIT=$(USB_BITS_DIR)/release.json

.PHONY: releasejson
releasejson: $(USB_BITS_DIR)
	echo "{ \
	\"date\": \"$(TIMESTAMP)\", \
	\"branch\": \"$(BRANCH)\", \
	\"try-branch\": \"$(TRY-BRANCH)\", \
	\"coal\": \"$(shell basename $(COAL_OUTPUT))\", \
	\"boot\": \"$(shell basename $(BOOT_OUTPUT))\", \
	\"usb\": \"$(shell basename $(USB_OUTPUT))\" \
}" | $(JSON) >$(RELEASEJSON_BIT)


clean_usbheadnode:
	$(RM) -rf $(BITS_DIR)/usbheadnode $(BITS_DIR)/usbheadnode$(USB_HEADNODE_SUFFIX)



#---- platform and debug platform

PLATFORM_BITS= \
	$(BITS_DIR)/platform$(PLAT_SUFFIX)/platform$(PLAT_SUFFIX)-$(SMARTOS_LIVE_BRANCH)-$(TIMESTAMP).tgz \
	$(BITS_DIR)/platform$(PLAT_SUFFIX)/boot$(PLAT_SUFFIX)-$(SMARTOS_LIVE_BRANCH)-$(TIMESTAMP).tgz
PLATFORM_BITS_0=$(shell echo $(PLATFORM_BITS) | awk '{print $$1}')

platform : PLAT_SUFFIX += ""
platform : PLAT_CONF_ARGS += "no"
platform-debug : PLAT_SUFFIX += "-debug"
platform-debug : PLAT_CONF_ARGS += "exclusive"


.PHONY: platform platform-debug
platform platform-debug: smartos_live_make_check $(PLATFORM_BITS_0)

build/smartos-live/configure.mg:
	sed -e "s:GITCLONESOURCE:$(shell pwd)/build/:" \
		<smartos-live-configure.mg.in >build/smartos-live/configure.mg

build/smartos-live/configure-branches:
	sed \
		-e "s:ILLUMOS_EXTRA_BRANCH:$(ILLUMOS_EXTRA_BRANCH):" \
		-e "s:ILLUMOS_JOYENT_BRANCH:$(ILLUMOS_JOYENT_BRANCH):" \
		-e "s:UR_AGENT_BRANCH:$(UR_AGENT_BRANCH):" \
		-e "s:ILLUMOS_KVM_BRANCH:$(ILLUMOS_KVM_BRANCH):" \
		-e "s:ILLUMOS_KVM_CMD_BRANCH:$(ILLUMOS_KVM_CMD_BRANCH):" \
		-e "s:MDATA_CLIENT_BRANCH:$(MDATA_CLIENT_BRANCH):" \
		-e "s:SDC_PLATFORM_BRANCH:$(SDC_PLATFORM_BRANCH):" \
		<smartos-live-configure-branches.in >build/smartos-live/configure-branches

.PHONY: smartos_live_make_check
smartos_live_make_check:
	(cd build/smartos-live && make check)

# PATH: Ensure using GCC from SFW as require for platform build.
$(PLATFORM_BITS): build/smartos-live/configure.mg build/smartos-live/configure-branches
	@echo "# Build platform: branch $(SMARTOS_LIVE_BRANCH), sha $(SMARTOS_LIVE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	(cd build/smartos-live \
		&& PATH=/usr/sfw/bin:$(PATH) \
			ILLUMOS_ENABLE_DEBUG=$(PLAT_CONF_ARGS) ./configure \
		&& PATH=/usr/sfw/bin:$(PATH) \
			BUILDSTAMP=$(TIMESTAMP) \
			gmake world \
		&& PATH=/usr/sfw/bin:$(PATH) \
			BUILDSTAMP=$(TIMESTAMP) \
			gmake live)
	(mkdir -p $(BITS_DIR)/platform$(PLAT_SUFFIX))
	(cp build/smartos-live/output/platform-$(TIMESTAMP).tgz $(BITS_DIR)/platform$(PLAT_SUFFIX)/platform$(PLAT_SUFFIX)-$(SMARTOS_LIVE_BRANCH)-$(TIMESTAMP).tgz)
	(cp build/smartos-live/output/boot-$(TIMESTAMP).tgz $(BITS_DIR)/platform$(PLAT_SUFFIX)/boot$(PLAT_SUFFIX)-$(SMARTOS_LIVE_BRANCH)-$(TIMESTAMP).tgz)
	@echo "# Created platform bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -l $(PLATFORM_BITS)
	@echo ""

clean_platform:
	$(RM) -rf $(BITS_DIR)/platform
	(cd build/smartos-live && gmake clean)

#---- docs target (based on eng.git/tools/mk code for this)

deps/%/.git:
	git submodule update --init deps/$*

RESTDOWN_EXEC	?= deps/restdown/bin/restdown
RESTDOWN	?= python2.6 $(RESTDOWN_EXEC)
RESTDOWN_FLAGS	?=
DOC_FILES	= design.restdown index.restdown
DOC_BUILD	= build/docs/public

$(DOC_BUILD):
	mkdir -p $@

$(DOC_BUILD)/%.json $(DOC_BUILD)/%.html: docs/%.restdown | $(DOC_BUILD) $(RESTDOWN_EXEC)
	$(RESTDOWN) $(RESTDOWN_FLAGS) -m $(DOC_BUILD) $<
	mv $(<:%.restdown=%.json) $(DOC_BUILD)
	mv $(<:%.restdown=%.html) $(DOC_BUILD)

.PHONY: docs
docs:							\
	$(DOC_FILES:%.restdown=$(DOC_BUILD)/%.html)		\
	$(DOC_FILES:%.restdown=$(DOC_BUILD)/%.json)

$(RESTDOWN_EXEC): | deps/restdown/.git

clean_docs:
	$(RM) -rf build/docs



#---- misc targets

.PHONY: clean
clean: clean_docs

.PHONY: clean_null
clean_null:

.PHONY: distclean
distclean:
	$(PFEXEC) $(RM) -rf bits build

.PHONY: cacheclean
cacheclean: distclean
	$(PFEXEC) $(RM) -rf cache



# DEPRECATED: Live build steps on jenkins.joyent.us still call this target.
# TODO: Remove those in Jenkins and then remove this target.
upload_jenkins:
	@echo "We no longer upload to bits.joyent.us"

# Upload bits we want to keep for a Jenkins build to manta
manta_upload_jenkins:
	@[[ -z "$(JOB_NAME)" ]] \
		&& echo "error: JOB_NAME isn't set (is this being run under Jenkins?)" \
		&& exit 1 || true
	TRACE=1 ./tools/mantaput-bits "$(BRANCH)" "$(TRY_BRANCH)" "$(TIMESTAMP)" $(MANTA_UPLOAD_BASE)/$(JOB_NAME) $(JOB_NAME) $(UPLOAD_SUBDIRS)


# Publish the image for this Jenkins job to https://updates.joyent.com, if
# appropriate. No-op if the current JOB_NAME doesn't have a "*_publish_image"
# target.
jenkins_publish_image:
	@[[ -z "$(JOB_NAME)" ]] \
		&& echo "error: JOB_NAME isn't set (is this being run under Jenkins?)" \
		&& exit 1 || true
	@[[ -z "$(shell grep '^$(JOB_NAME)_publish_image\>' Makefile || true)" ]] \
		|| make $(JOB_NAME)_publish_image
