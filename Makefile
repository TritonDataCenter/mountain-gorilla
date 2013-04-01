
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
	UPLOAD_LOCATION=stuff@stuff.joyent.us:builds
endif



#---- Primary targets

.PHONY: all
all: smartlogin amon ca agents_core heartbeater zonetracker provisioner agentsshar assets adminui redis rabbitmq dhcpd usageapi cloudapi workflow manatee mahi imgapi imgapi-cli sdc-system-tests cnapi vmapi dapi fwapi napi sapi binder mako moray electric-moray registrar configurator ufds platform usbheadnode minnow mola manta mackerel manowar config-agent sdcboot manta-deployment

.PHONY: all-except-platform
all-except-platform: smartlogin amon ca agents_core heartbeater zonetracker provisioner agentsshar assets adminui redis rabbitmq dhcpd usageapi cloudapi workflow manatee mahi imgapi imgapi-cli sdc-system-tests cnapi vmapi dapi fwapi napi sapi binder mako registrar configurator moray electric-moray ufds usbheadnode minnow mola manta mackerel manowar config-agent sdcboot manta-deployment


#---- smartlogin
# TODO:
# - Re-instate 'gmake lint'?

SMARTLOGIN_BITS=$(BITS_DIR)/smartlogin/smartlogin-$(SMART_LOGIN_BRANCH)-$(TIMESTAMP)-g$(SMART_LOGIN_SHA).tgz

.PHONY: smartlogin
smartlogin: $(SMARTLOGIN_BITS)

# PATH: ensure using GCC from SFW. Not sure this is necessary, but has been
# the case for release builds pre-MG.
$(SMARTLOGIN_BITS): build/smart-login
	@echo "# Build smartlogin: branch $(SMART_LOGIN_BRANCH), sha $(SMART_LOGIN_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/smart-login && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) PATH=/usr/sfw/bin:$(PATH) BITS_DIR=$(BITS_DIR) gmake clean all publish)
	@echo "# Created smartlogin bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(SMARTLOGIN_BITS)
	@echo ""

clean_smartlogin:
	rm -rf $(BITS_DIR)/smartlogin



#---- amon

_amon_stamp=$(AMON_BRANCH)-$(TIMESTAMP)-g$(AMON_SHA)
AMON_BITS=$(BITS_DIR)/amon/amon-pkg-$(_amon_stamp).tar.bz2 \
	$(BITS_DIR)/amon/amon-relay-$(_amon_stamp).tgz \
	$(BITS_DIR)/amon/amon-agent-$(_amon_stamp).tgz
AMON_BITS_0=$(shell echo $(AMON_BITS) | awk '{print $$1}')
AMON_IMAGE_BIT=$(BITS_DIR)/amon/amon-zfs-$(_amon_stamp).zfs.gz
AMON_MANIFEST_BIT=$(BITS_DIR)/amon/amon-zfs-$(_amon_stamp).zfs.dsmanifest

.PHONY: amon
amon: $(AMON_BITS_0) amon_image

$(AMON_BITS): build/amon
	@echo "# Build amon: branch $(AMON_BRANCH), sha $(AMON_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/amon && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake clean all pkg publish)
	@echo "# Created amon bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(AMON_BITS)
	@echo ""

.PHONY: amon_image
amon_image: $(AMON_IMAGE_BIT)

$(AMON_IMAGE_BIT): $(AMON_BITS_0)
	@echo "# Build amon_image: branch $(AMON_BRANCH), sha $(AMON_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(AMON_IMAGE_UUID)" -t $(AMON_BITS_0) \
		-o "$(AMON_IMAGE_BIT)" -p $(AMON_PKGSRC) \
		-t $(AMON_EXTRA_TARBALLS) -n $(AMON_IMAGE_NAME) \
		-v $(_amon_stamp) -d $(AMON_IMAGE_DESCRIPTION)
	@echo "# Created amon image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(AMON_IMAGE_BIT)
	@echo ""

amon_publish_image: $(AMON_IMAGE_BIT)
	@echo "# Publish amon image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(AMON_MANIFEST_BIT) -f $(AMON_IMAGE_BIT)

clean_amon:
	rm -rf $(BITS_DIR)/amon
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
CA_MANIFEST_BIT=$(BITS_DIR)/ca/ca-zfs-$(_ca_stamp).zfs.dsmanifest

.PHONY: ca
ca: $(CA_BITS_0) ca_image

# PATH for ca build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(CA_BITS): build/cloud-analytics
	@echo "# Build ca: branch $(CLOUD_ANALYTICS_BRANCH), sha $(CLOUD_ANALYTICS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/cloud-analytics && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) PATH="/sbin:/opt/local/bin:/usr/gnu/bin:/usr/bin:/usr/sbin:$(PATH)" gmake clean pkg release publish)
	@echo "# Created ca bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(CA_BITS)
	@echo ""

.PHONY: ca_image
ca_image: $(CA_IMAGE_BIT)

$(CA_IMAGE_BIT): $(CA_BITS_0)
	@echo "# Build ca_image: branch $(CA_BRANCH), sha $(CA_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(CA_IMAGE_UUID)" -t $(CA_BITS_0) \
		-o "$(CA_IMAGE_BIT)" -p $(CA_PKGSRC) \
		-t $(CA_EXTRA_TARBALLS) -n $(CA_IMAGE_NAME) \
		-v $(_ca_stamp) -d $(CA_IMAGE_DESCRIPTION)
	@echo "# Created ca image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(CA_IMAGE_BIT)
	@echo ""

ca_publish_image: $(CA_IMAGE_BIT)
	@echo "# Publish ca image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(CA_MANIFEST_BIT) -f $(CA_IMAGE_BIT)

# Warning: if CA's submodule deps change, this 'clean_ca' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_ca:
	rm -rf $(BITS_DIR)/ca
	(cd build/cloud-analytics && gmake clean)



#---- UFDS


_ufds_stamp=$(UFDS_BRANCH)-$(TIMESTAMP)-g$(UFDS_SHA)
UFDS_BITS=$(BITS_DIR)/ufds/ufds-pkg-$(_ufds_stamp).tar.bz2
UFDS_IMAGE_BIT=$(BITS_DIR)/ufds/ufds-zfs-$(_ufds_stamp).zfs.gz
UFDS_MANIFEST_BIT=$(BITS_DIR)/ufds/ufds-zfs-$(_ufds_stamp).zfs.dsmanifest

.PHONY: ufds
ufds: $(UFDS_BITS) ufds_image

# PATH for ufds build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(UFDS_BITS): build/ufds
	@echo "# Build ufds: branch $(UFDS_BRANCH), sha $(UFDS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/ufds && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake pkg release publish)
	@echo "# Created ufds bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(UFDS_BITS)
	@echo ""

.PHONY: ufds_image
ufds_image: $(UFDS_IMAGE_BIT)

$(UFDS_IMAGE_BIT): $(UFDS_BITS)
	@echo "# Build ufds_image: branch $(UFDS_BRANCH), sha $(UFDS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(UFDS_IMAGE_UUID)" -t $(UFDS_BITS) \
		-o "$(UFDS_IMAGE_BIT)" -p $(UFDS_PKGSRC) \
		-t $(UFDS_EXTRA_TARBALLS) -n $(UFDS_IMAGE_NAME) \
		-v $(_ufds_stamp) -d $(UFDS_IMAGE_DESCRIPTION)
	@echo "# Created ufds image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(UFDS_IMAGE_BIT)
	@echo ""

ufds_publish_image: $(UFDS_IMAGE_BIT)
	@echo "# Publish ufds image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(UFDS_MANIFEST_BIT) -f $(UFDS_IMAGE_BIT)

# Warning: if UFDS's submodule deps change, this 'clean_ufds' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_ufds:
	rm -rf $(BITS_DIR)/ufds
	(cd build/ufds && gmake clean)


#---- usageapi

_usageapi_stamp=$(USAGEAPI_BRANCH)-$(TIMESTAMP)-g$(USAGEAPI_SHA)
USAGEAPI_BITS=$(BITS_DIR)/usageapi/usageapi-pkg-$(_usageapi_stamp).tar.bz2
USAGEAPI_IMAGE_BIT=$(BITS_DIR)/usageapi/usageapi-zfs-$(_usageapi_stamp).zfs.gz
USAGEAPI_MANIFEST_BIT=$(BITS_DIR)/usageapi/usageapi-zfs-$(_usageapi_stamp).zfs.dsmanifest

.PHONY: usageapi
usageapi: $(USAGEAPI_BITS) usageapi_image

# PATH for ufds build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(USAGEAPI_BITS): build/usageapi
	@echo "# Build usageapi: branch $(USAGEAPI_BRANCH), sha $(USAGEAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/usageapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake pkg release publish)
	@echo "# Created usageapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(USAGEAPI_BITS)
	@echo ""

.PHONY: usageapi_image
usageapi_image: $(USAGEAPI_IMAGE_BIT)

$(USAGEAPI_IMAGE_BIT): $(USAGEAPI_BITS)
	@echo "# Build usageapi_image: branch $(USAGEAPI_BRANCH), sha $(USAGEAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(USAGEAPI_IMAGE_UUID)" -t $(USAGEAPI_BITS) \
		-o "$(USAGEAPI_IMAGE_BIT)" -p $(USAGEAPI_PKGSRC) \
		-t $(USAGEAPI_EXTRA_TARBALLS) -n $(USAGEAPI_IMAGE_NAME) \
		-v $(_usageapi_stamp) -d $(USAGEAPI_IMAGE_DESCRIPTION)
	@echo "# Created usageapi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(USAGEAPI_IMAGE_BIT)
	@echo ""

usageapi_publish_image: $(USAGEAPI_IMAGE_BIT)
	@echo "# Publish usageapi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(USAGEAPI_MANIFEST_BIT) -f $(USAGEAPI_IMAGE_BIT)


# Warning: if usageapi's submodule deps change, this 'clean_ufds' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_usageapi:
	rm -rf $(BITS_DIR)/usageapi
	(cd build/usageapi && gmake clean)


#---- ASSETS

_assets_stamp=$(ASSETS_BRANCH)-$(TIMESTAMP)-g$(ASSETS_SHA)
ASSETS_BITS=$(BITS_DIR)/assets/assets-pkg-$(_assets_stamp).tar.bz2
ASSETS_IMAGE_BIT=$(BITS_DIR)/assets/assets-zfs-$(_assets_stamp).zfs.gz
ASSETS_MANIFEST_BIT=$(BITS_DIR)/assets/assets-zfs-$(_assets_stamp).zfs.dsmanifest

.PHONY: assets
assets: $(ASSETS_BITS) assets_image

$(ASSETS_BITS): build/assets
	@echo "# Build assets: branch $(ASSETS_BRANCH), sha $(ASSETS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/assets && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created assets bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(ASSETS_BITS)
	@echo ""

.PHONY: assets_image
assets_image: $(ASSETS_IMAGE_BIT)

$(ASSETS_IMAGE_BIT): $(ASSETS_BITS)
	@echo "# Build assets_image: branch $(ASSETS_BRANCH), sha $(ASSETS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(ASSETS_IMAGE_UUID)" -t $(ASSETS_BITS) \
		-o "$(ASSETS_IMAGE_BIT)" -p $(ASSETS_PKGSRC) \
		-t $(ASSETS_EXTRA_TARBALLS) -n $(ASSETS_IMAGE_NAME) \
		-v $(_assets_stamp) -d $(ASSETS_IMAGE_DESCRIPTION)
	@echo "# Created assets image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(ASSETS_IMAGE_BIT)
	@echo ""

assets_publish_image: $(ASSETS_IMAGE_BIT)
	@echo "# Publish assets image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(ASSETS_MANIFEST_BIT) -f $(ASSETS_IMAGE_BIT)

clean_assets:
	rm -rf $(BITS_DIR)/assets
	(cd build/assets && gmake clean)

#---- ADMINUI

_adminui_stamp=$(ADMINUI_BRANCH)-$(TIMESTAMP)-g$(ADMINUI_SHA)
ADMINUI_BITS=$(BITS_DIR)/adminui/adminui-pkg-$(_adminui_stamp).tar.bz2
ADMINUI_IMAGE_BIT=$(BITS_DIR)/adminui/adminui-zfs-$(_adminui_stamp).zfs.gz
ADMINUI_MANIFEST_BIT=$(BITS_DIR)/adminui/adminui-zfs-$(_adminui_stamp).zfs.dsmanifest

.PHONY: adminui
adminui: $(ADMINUI_BITS) adminui_image

$(ADMINUI_BITS): build/adminui
	@echo "# Build adminui: branch $(ADMINUI_BRANCH), sha $(ADMINUI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/adminui && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created adminui bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(ADMINUI_BITS)
	@echo ""

.PHONY: adminui_image
adminui_image: $(ADMINUI_IMAGE_BIT)

$(ADMINUI_IMAGE_BIT): $(ADMINUI_BITS)
	@echo "# Build adminui_image: branch $(ADMINUI_BRANCH), sha $(ADMINUI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(ADMINUI_IMAGE_UUID)" -t $(ADMINUI_BITS) \
		-o "$(ADMINUI_IMAGE_BIT)" -p $(ADMINUI_PKGSRC) \
		-t $(ADMINUI_EXTRA_TARBALLS) -n $(ADMINUI_IMAGE_NAME) \
		-v $(_adminui_stamp) -d $(ADMINUI_IMAGE_DESCRIPTION)
	@echo "# Created adminui image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(ADMINUI_IMAGE_BIT)
	@echo ""

adminui_publish_image: $(ADMINUI_IMAGE_BIT)
	@echo "# Publish adminui image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(ADMINUI_MANIFEST_BIT) -f $(ADMINUI_IMAGE_BIT)

clean_adminui:
	rm -rf $(BITS_DIR)/adminui
	(cd build/adminui && gmake clean)

#---- REDIS

_redis_stamp=$(REDIS_BRANCH)-$(TIMESTAMP)-g$(REDIS_SHA)
REDIS_BITS=$(BITS_DIR)/redis/redis-pkg-$(_redis_stamp).tar.bz2
REDIS_IMAGE_BIT=$(BITS_DIR)/redis/redis-zfs-$(_redis_stamp).zfs.gz
REDIS_MANIFEST_BIT=$(BITS_DIR)/redis/redis-zfs-$(_redis_stamp).zfs.dsmanifest

.PHONY: redis
redis: $(REDIS_BITS) redis_image

$(REDIS_BITS): build/redis
	@echo "# Build redis: branch $(REDIS_BRANCH), sha $(REDIS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/redis && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created redis bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(REDIS_BITS)
	@echo ""

.PHONY: redis_image
redis_image: $(REDIS_IMAGE_BIT)

$(REDIS_IMAGE_BIT): $(REDIS_BITS)
	@echo "# Build redis_image: branch $(REDIS_BRANCH), sha $(REDIS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(REDIS_IMAGE_UUID)" -t $(REDIS_BITS) \
		-o "$(REDIS_IMAGE_BIT)" -p $(REDIS_PKGSRC) \
		-t $(REDIS_EXTRA_TARBALLS) -n $(REDIS_IMAGE_NAME) \
		-v $(_redis_stamp) -d $(REDIS_IMAGE_DESCRIPTION)
	@echo "# Created redis image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(REDIS_IMAGE_BIT)
	@echo ""

redis_publish_image: $(REDIS_IMAGE_BIT)
	@echo "# Publish redis image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(REDIS_MANIFEST_BIT) -f $(REDIS_IMAGE_BIT)

clean_redis:
	rm -rf $(BITS_DIR)/redis
	(cd build/redis && gmake clean)

#---- RABBITMQ

_rabbitmq_stamp=$(RABBITMQ_BRANCH)-$(TIMESTAMP)-g$(RABBITMQ_SHA)
RABBITMQ_BITS=$(BITS_DIR)/rabbitmq/rabbitmq-pkg-$(_rabbitmq_stamp).tar.bz2
RABBITMQ_IMAGE_BIT=$(BITS_DIR)/rabbitmq/rabbitmq-zfs-$(_rabbitmq_stamp).zfs.gz
RABBITMQ_MANIFEST_BIT=$(BITS_DIR)/rabbitmq/rabbitmq-zfs-$(_rabbitmq_stamp).zfs.dsmanifest

.PHONY: rabbitmq
rabbitmq: $(RABBITMQ_BITS) rabbitmq_image

$(RABBITMQ_BITS): build/rabbitmq
	@echo "# Build rabbitmq: branch $(RABBITMQ_BRANCH), sha $(RABBITMQ_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/rabbitmq && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created rabbitmq bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(RABBITMQ_BITS)
	@echo ""

.PHONY: rabbitmq_image
rabbitmq_image: $(RABBITMQ_IMAGE_BIT)

$(RABBITMQ_IMAGE_BIT): $(RABBITMQ_BITS)
	@echo "# Build rabbitmq_image: branch $(RABBITMQ_BRANCH), sha $(RABBITMQ_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(RABBITMQ_IMAGE_UUID)" -t $(RABBITMQ_BITS) \
		-o "$(RABBITMQ_IMAGE_BIT)" -p $(RABBITMQ_PKGSRC) \
		-t $(RABBITMQ_EXTRA_TARBALLS) -n $(RABBITMQ_IMAGE_NAME) \
		-v $(_rabbitmq_stamp) -d $(RABBITMQ_IMAGE_DESCRIPTION)
	@echo "# Created rabbitmq image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(RABBITMQ_IMAGE_BIT)
	@echo ""

rabbitmq_publish_image: $(RABBITMQ_IMAGE_BIT)
	@echo "# Publish rabbitmq image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(RABBITMQ_MANIFEST_BIT) -f $(RABBITMQ_IMAGE_BIT)

clean_rabbitmq:
	rm -rf $(BITS_DIR)/rabbitmq
	(cd build/rabbitmq && gmake clean)

#---- DHCPD

_dhcpd_stamp=$(DHCPD_BRANCH)-$(TIMESTAMP)-g$(DHCPD_SHA)
DHCPD_BITS=$(BITS_DIR)/dhcpd/dhcpd-pkg-$(_dhcpd_stamp).tar.bz2
DHCPD_IMAGE_BIT=$(BITS_DIR)/dhcpd/dhcpd-zfs-$(_dhcpd_stamp).zfs.gz
DHCPD_MANIFEST_BIT=$(BITS_DIR)/dhcpd/dhcpd-zfs-$(_dhcpd_stamp).zfs.dsmanifest

.PHONY: dhcpd
dhcpd: $(DHCPD_BITS) dhcpd_image

$(DHCPD_BITS): build/dhcpd
	@echo "# Build dhcpd: branch $(DHCPD_BRANCH), sha $(DHCPD_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/dhcpd && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) \
		$(MAKE) release publish)
	@echo "# Created dhcpd bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(DHCPD_BITS)
	@echo ""

.PHONY: dhcpd_image
dhcpd_image: $(DHCPD_IMAGE_BIT)

$(DHCPD_IMAGE_BIT): $(DHCPD_BITS)
	@echo "# Build dhcpd_image: branch $(DHCPD_BRANCH), sha $(DHCPD_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(DHCPD_IMAGE_UUID)" -t $(DHCPD_BITS) \
		-o "$(DHCPD_IMAGE_BIT)" -p $(DHCPD_PKGSRC) \
		-t $(DHCPD_EXTRA_TARBALLS) -n $(DHCPD_IMAGE_NAME) \
		-v $(_dhcpd_stamp) -d $(DHCPD_IMAGE_DESCRIPTION)
	@echo "# Created dhcpd image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(DHCPD_IMAGE_BIT)
	@echo ""

dhcpd_publish_image: $(DHCPD_IMAGE_BIT)
	@echo "# Publish dhcpd image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(DHCPD_MANIFEST_BIT) -f $(DHCPD_IMAGE_BIT)

clean_dhcpd:
	rm -rf $(BITS_DIR)/dhcpd
	(cd build/dhcpd && gmake clean)


#---- CLOUDAPI

_cloudapi_stamp=$(CLOUDAPI_BRANCH)-$(TIMESTAMP)-g$(CLOUDAPI_SHA)
CLOUDAPI_BITS=$(BITS_DIR)/cloudapi/cloudapi-pkg-$(_cloudapi_stamp).tar.bz2
CLOUDAPI_IMAGE_BIT=$(BITS_DIR)/cloudapi/cloudapi-zfs-$(_cloudapi_stamp).zfs.gz
CLOUDAPI_MANIFEST_BIT=$(BITS_DIR)/cloudapi/cloudapi-zfs-$(_cloudapi_stamp).zfs.dsmanifest

.PHONY: cloudapi
cloudapi: $(CLOUDAPI_BITS) cloudapi_image

# cloudapi still uses platform node, ensure that same version is first
# node (and npm) on the PATH.
$(CLOUDAPI_BITS): build/cloudapi
	@echo "# Build cloudapi: branch $(CLOUDAPI_BRANCH), sha $(CLOUDAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/cloudapi && PATH=/opt/node/0.6.12/bin:$(PATH) NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created cloudapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(CLOUDAPI_BITS)
	@echo ""

.PHONY: cloudapi_image
cloudapi_image: $(CLOUDAPI_IMAGE_BIT)

$(CLOUDAPI_IMAGE_BIT): $(CLOUDAPI_BITS)
	@echo "# Build cloudapi_image: branch $(CLOUDAPI_BRANCH), sha $(CLOUDAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(CLOUDAPI_IMAGE_UUID)" -t $(CLOUDAPI_BITS) \
		-o "$(CLOUDAPI_IMAGE_BIT)" -p $(CLOUDAPI_PKGSRC) \
		-t $(CLOUDAPI_EXTRA_TARBALLS) -n $(CLOUDAPI_IMAGE_NAME) \
		-v $(_cloudapi_stamp) -d $(CLOUDAPI_IMAGE_DESCRIPTION)
	@echo "# Created cloudapi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(CLOUDAPI_IMAGE_BIT)
	@echo ""

cloudapi_publish_image: $(CLOUDAPI_IMAGE_BIT)
	@echo "# Publish cloudapi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(CLOUDAPI_MANIFEST_BIT) -f $(CLOUDAPI_IMAGE_BIT)


# Warning: if cloudapi's submodule deps change, this 'clean_ufds' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_cloudapi:
	rm -rf $(BITS_DIR)/cloudapi
	(cd build/cloudapi && gmake clean)


#---- MANATEE

_manatee_stamp=$(MANATEE_BRANCH)-$(TIMESTAMP)-g$(MANATEE_SHA)
MANATEE_BITS=$(BITS_DIR)/manatee/manatee-pkg-$(_manatee_stamp).tar.bz2
MANATEE_IMAGE_BIT=$(BITS_DIR)/manatee/manatee-zfs-$(_manatee_stamp).zfs.gz
MANATEE_MANIFEST_BIT=$(BITS_DIR)/manatee/manatee-zfs-$(_manatee_stamp).zfs.dsmanifest

.PHONY: manatee
manatee: $(MANATEE_BITS) manatee_image

$(MANATEE_BITS): build/manatee
	@echo "# Build manatee: branch $(MANATEE_BRANCH), sha $(MANATEE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/manatee && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created manatee bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MANATEE_BITS)
	@echo ""

.PHONY: manatee_image
manatee_image: $(MANATEE_IMAGE_BIT)

$(MANATEE_IMAGE_BIT): $(MANATEE_BITS)
	@echo "# Build manatee_image: branch $(MANATEE_BRANCH), sha $(MANATEE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(MANATEE_IMAGE_UUID)" -t $(MANATEE_BITS) \
		-o "$(MANATEE_IMAGE_BIT)" -p $(MANATEE_PKGSRC) \
		-t $(MANATEE_EXTRA_TARBALLS) -n $(MANATEE_IMAGE_NAME) \
		-v $(_manatee_stamp) -d $(MANATEE_IMAGE_DESCRIPTION)
	@echo "# Created manatee image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MANATEE_IMAGE_BIT)
	@echo ""

manatee_publish_image: $(MANATEE_IMAGE_BIT)
	@echo "# Publish manatee image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MANATEE_MANIFEST_BIT) -f $(MANATEE_IMAGE_BIT)

clean_manatee:
	rm -rf $(BITS_DIR)/manatee
	(cd build/manatee && gmake distclean)


#---- WORKFLOW

_wf_stamp=$(WORKFLOW_BRANCH)-$(TIMESTAMP)-g$(WORKFLOW_SHA)
WORKFLOW_BITS=$(BITS_DIR)/workflow/workflow-pkg-$(_wf_stamp).tar.bz2
WORKFLOW_IMAGE_BIT=$(BITS_DIR)/workflow/workflow-zfs-$(_wf_stamp).zfs.gz
WORKFLOW_MANIFEST_BIT=$(BITS_DIR)/workflow/workflow-zfs-$(_wf_stamp).zfs.dsmanifest

.PHONY: workflow
workflow: $(WORKFLOW_BITS) workflow_image

# PATH for workflow build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(WORKFLOW_BITS): build/workflow
	@echo "# Build workflow: branch $(WORKFLOW_BRANCH), sha $(WORKFLOW_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/workflow && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created workflow bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(WORKFLOW_BITS)
	@echo ""

.PHONY: workflow_image
workflow_image: $(WORKFLOW_IMAGE_BIT)

$(WORKFLOW_IMAGE_BIT): $(WORKFLOW_BITS)
	@echo "# Build workflow_image: branch $(WORKFLOW_BRANCH), sha $(WORKFLOW_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(WORKFLOW_IMAGE_UUID)" -t $(WORKFLOW_BITS) \
		-o "$(WORKFLOW_IMAGE_BIT)" -p $(WORKFLOW_PKGSRC) \
		-t $(WORKFLOW_EXTRA_TARBALLS) -n $(WORKFLOW_IMAGE_NAME) \
		-v $(_wf_stamp) -d $(WORKFLOW_IMAGE_DESCRIPTION)
	@echo "# Created workflow image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(WORKFLOW_IMAGE_BIT)
	@echo ""

workflow_publish_image: $(WORKFLOW_IMAGE_BIT)
	@echo "# Publish workflow image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(WORKFLOW_MANIFEST_BIT) -f $(WORKFLOW_IMAGE_BIT)

# Warning: if workflow's submodule deps change, this 'clean_workflow' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_workflow:
	rm -rf $(BITS_DIR)/workflow
	(cd build/workflow && gmake clean)


#---- VMAPI

_vmapi_stamp=$(VMAPI_BRANCH)-$(TIMESTAMP)-g$(VMAPI_SHA)
VMAPI_BITS=$(BITS_DIR)/vmapi/vmapi-pkg-$(_vmapi_stamp).tar.bz2
VMAPI_IMAGE_BIT=$(BITS_DIR)/vmapi/vmapi-zfs-$(_vmapi_stamp).zfs.gz
VMAPI_MANIFEST_BIT=$(BITS_DIR)/vmapi/vmapi-zfs-$(_vmapi_stamp).zfs.dsmanifest

.PHONY: vmapi
vmapi: $(VMAPI_BITS) vmapi_image

# PATH for vmapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(VMAPI_BITS): build/vmapi
	@echo "# Build vmapi: branch $(VMAPI_BRANCH), sha $(VMAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/vmapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created vmapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(VMAPI_BITS)
	@echo ""

.PHONY: vmapi_image
vmapi_image: $(VMAPI_IMAGE_BIT)

$(VMAPI_IMAGE_BIT): $(VMAPI_BITS)
	@echo "# Build vmapi_image: branch $(VMAPI_BRANCH), sha $(VMAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(VMAPI_IMAGE_UUID)" -t $(VMAPI_BITS) \
		-o "$(VMAPI_IMAGE_BIT)" -p $(VMAPI_PKGSRC) \
		-t $(VMAPI_EXTRA_TARBALLS) -n $(VMAPI_IMAGE_NAME) \
		-v $(_vmapi_stamp) -d $(VMAPI_IMAGE_DESCRIPTION)
	@echo "# Created vmapi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(VMAPI_IMAGE_BIT)
	@echo ""

vmapi_publish_image: $(VMAPI_IMAGE_BIT)
	@echo "# Publish vmapi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(VMAPI_MANIFEST_BIT) -f $(VMAPI_IMAGE_BIT)

# Warning: if vmapi's submodule deps change, this 'clean_vmapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_vmapi:
	rm -rf $(BITS_DIR)/vmapi
	(cd build/vmapi && gmake clean)


#---- DAPI

_dapi_stamp=$(DAPI_BRANCH)-$(TIMESTAMP)-g$(DAPI_SHA)
DAPI_BITS=$(BITS_DIR)/dapi/dapi-pkg-$(_dapi_stamp).tar.bz2
DAPI_IMAGE_BIT=$(BITS_DIR)/dapi/dapi-zfs-$(_dapi_stamp).zfs.gz
DAPI_MANIFEST_BIT=$(BITS_DIR)/dapi/dapi-zfs-$(_dapi_stamp).zfs.dsmanifest


.PHONY: dapi
dapi: $(DAPI_BITS) dapi_image

# PATH for dapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(DAPI_BITS): build/dapi
	@echo "# Build dapi: branch $(DAPI_BRANCH), sha $(DAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/dapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created dapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(DAPI_BITS)
	@echo ""

.PHONY: dapi_image
dapi_image: $(DAPI_IMAGE_BIT)

$(DAPI_IMAGE_BIT): $(DAPI_BITS)
	@echo "# Build dapi_image: branch $(DAPI_BRANCH), sha $(DAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(DAPI_IMAGE_UUID)" -t $(DAPI_BITS) \
		-o "$(DAPI_IMAGE_BIT)" -p $(DAPI_PKGSRC) \
		-t $(DAPI_EXTRA_TARBALLS) -n $(DAPI_IMAGE_NAME) \
		-v $(_dapi_stamp) -d $(DAPI_IMAGE_DESCRIPTION)
	@echo "# Created dapi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(DAPI_IMAGE_BIT)
	@echo ""

dapi_publish_image: $(DAPI_IMAGE_BIT)
	@echo "# Publish dapi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(DAPI_MANIFEST_BIT) -f $(DAPI_IMAGE_BIT)

# Warning: if dapi's submodule deps change, this 'clean_dapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_dapi:
	rm -rf $(BITS_DIR)/dapi
	(cd build/dapi && gmake clean)


#---- imgapi-cli

_imgapi_cli_stamp=$(IMGAPI_CLI_BRANCH)-$(TIMESTAMP)-g$(IMGAPI_CLI_SHA)
IMGAPI_CLI_BITS=$(BITS_DIR)/imgapi-cli/imgapi-cli-pkg-$(_imgapi_cli_stamp).tar.bz2

.PHONY: imgapi-cli
imgapi-cli: $(IMGAPI_CLI_BITS)

$(IMGAPI_CLI_BITS): build/imgapi-cli
	@echo "# Build imgapi-cli: branch $(IMGAPI_CLI_BRANCH), sha $(IMGAPI_CLI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/imgapi-cli && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created imgapi-cli bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(IMGAPI_CLI_BITS)
	@echo ""

clean_imgapi_cli:
	rm -rf $(BITS_DIR)/imgapi-cli
	(cd build/imgapi-cli && gmake clean)



#---- IMGAPI

_imgapi_stamp=$(IMGAPI_BRANCH)-$(TIMESTAMP)-g$(IMGAPI_SHA)
IMGAPI_BITS=$(BITS_DIR)/imgapi/imgapi-pkg-$(_imgapi_stamp).tar.bz2
IMGAPI_IMAGE_BIT=$(BITS_DIR)/imgapi/imgapi-zfs-$(_imgapi_stamp).zfs.gz
IMGAPI_MANIFEST_BIT=$(BITS_DIR)/imgapi/imgapi-zfs-$(_imgapi_stamp).zfs.dsmanifest

.PHONY: imgapi
imgapi: $(IMGAPI_BITS) imgapi_image

$(IMGAPI_BITS): build/imgapi
	@echo "# Build imgapi: branch $(IMGAPI_BRANCH), sha $(IMGAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/imgapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created imgapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(IMGAPI_BITS)
	@echo ""

.PHONY: imgapi_image
imgapi_image: $(IMGAPI_IMAGE_BIT)

$(IMGAPI_IMAGE_BIT): $(IMGAPI_BITS)
	@echo "# Build imgapi_image: branch $(IMGAPI_BRANCH), sha $(IMGAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(IMGAPI_IMAGE_UUID)" -t $(IMGAPI_BITS) \
		-o "$(IMGAPI_IMAGE_BIT)" -p $(IMGAPI_PKGSRC) \
		-t $(IMGAPI_EXTRA_TARBALLS) -n $(IMGAPI_IMAGE_NAME) \
		-v $(_imgapi_stamp) -d $(IMGAPI_IMAGE_DESCRIPTION)
	@echo "# Created imgapi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(IMGAPI_IMAGE_BIT)
	@echo ""

imgapi_publish_image: $(IMGAPI_IMAGE_BIT)
	@echo "# Publish imgapi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(IMGAPI_MANIFEST_BIT) -f $(IMGAPI_IMAGE_BIT)

clean_imgapi:
	rm -rf $(BITS_DIR)/imgapi
	(cd build/imgapi && gmake clean)



#---- sdc-system-tests (aka systests)

_sdc_system_tests_stamp=$(SDC_SYSTEM_TESTS_BRANCH)-$(TIMESTAMP)-g$(SDC_SYSTEM_TESTS_SHA)
SDC_SYSTEM_TESTS_BITS=$(BITS_DIR)/sdc-system-tests/sdc-system-tests-$(_sdc_system_tests_stamp).tgz

.PHONY: sdc-system-tests
sdc-system-tests: $(SDC_SYSTEM_TESTS_BITS)

$(SDC_SYSTEM_TESTS_BITS): build/sdc-system-tests
	@echo "# Build sdc-system-tests: branch $(SDC_SYSTEM_TESTS_BRANCH), sha $(SDC_SYSTEM_TESTS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/sdc-system-tests && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm \
		NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode \
		TIMESTAMP=$(TIMESTAMP) \
		BITS_DIR=$(BITS_DIR) \
		gmake all release publish)
	@echo "# Created sdc-system-tests bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(SDC_SYSTEM_TESTS_BITS)
	@echo ""


#---- Agents core

_agents_core_stamp=$(AGENTS_CORE_BRANCH)-$(TIMESTAMP)-g$(AGENTS_CORE_SHA)
AGENTS_CORE_BITS=$(BITS_DIR)/agents_core/agents_core-$(_agents_core_stamp).tgz

.PHONY: agents_core
agents_core: $(AGENTS_CORE_BITS)

# PATH for agents_core build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(AGENTS_CORE_BITS): build/agents_core
	@echo "# Build agents_core: branch $(AGENTS_CORE_BRANCH), sha $(AGENTS_CORE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/agents_core && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created agents_core bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(AGENTS_CORE_BITS)
	@echo ""

# Warning: if agents_core's submodule deps change, this 'clean_agents_core' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_agents_core:
	rm -rf $(BITS_DIR)/agents_core
	(cd build/agents_core && gmake clean)


#---- Provisioner

_provisioner_stamp=$(PROVISIONER_BRANCH)-$(TIMESTAMP)-g$(PROVISIONER_SHA)
PROVISIONER_BITS=$(BITS_DIR)/provisioner/provisioner-$(_provisioner_stamp).tgz

.PHONY: provisioner
provisioner: $(PROVISIONER_BITS)

# PATH for provisioner build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(PROVISIONER_BITS): build/provisioner
	@echo "# Build provisioner: branch $(PROVISIONER_BRANCH), sha $(PROVISIONER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/provisioner && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created provisioner bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(PROVISIONER_BITS)
	@echo ""

# Warning: if provisioner's submodule deps change, this 'clean_provisioner' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_provisioner:
	rm -rf $(BITS_DIR)/provisioner
	(cd build/provisioner && gmake clean)


#---- Heartbeater

_heartbeater_stamp=$(HEARTBEATER_BRANCH)-$(TIMESTAMP)-g$(HEARTBEATER_SHA)
HEARTBEATER_BITS=$(BITS_DIR)/heartbeater/heartbeater-$(_heartbeater_stamp).tgz

.PHONY: heartbeater
heartbeater: $(HEARTBEATER_BITS)

# PATH for heartbeater build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(HEARTBEATER_BITS): build/heartbeater
	@echo "# Build heartbeater: branch $(HEARTBEATER_BRANCH), sha $(HEARTBEATER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/heartbeater && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created heartbeater bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(HEARTBEATER_BITS)
	@echo ""

# Warning: if heartbeater's submodule deps change, this 'clean_heartbeater' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_heartbeater:
	rm -rf $(BITS_DIR)/heartbeater
	(cd build/heartbeater && gmake clean)


#---- Zonetracker

_zonetracker_stamp=$(ZONETRACKER_BRANCH)-$(TIMESTAMP)-g$(ZONETRACKER_SHA)
ZONETRACKER_BITS=$(BITS_DIR)/zonetracker/zonetracker-$(_zonetracker_stamp).tgz

.PHONY: zonetracker
zonetracker: $(ZONETRACKER_BITS)

# PATH for zonetracker build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(ZONETRACKER_BITS): build/zonetracker
	@echo "# Build zonetracker: branch $(ZONETRACKER_BRANCH), sha $(ZONETRACKER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/zonetracker && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created zonetracker bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(ZONETRACKER_BITS)
	@echo ""

# Warning: if zonetracker's submodule deps change, this 'clean_zonetracker' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_zonetracker:
	rm -rf $(BITS_DIR)/zonetracker
	(cd build/zonetracker && gmake clean)


#---- Configuration Agent

_config_agent_stamp=$(CONFIG_AGENT_BRANCH)-$(TIMESTAMP)-g$(CONFIG_AGENT_SHA)
CONFIG_AGENT_BITS=$(BITS_DIR)/config-agent/config-agent-pkg-$(_config_agent_stamp).tar.bz2

.PHONY: config-agent
config-agent: $(CONFIG_AGENT_BITS)

$(CONFIG_AGENT_BITS): build/config-agent
	@echo "# Build config-agent: branch $(CONFIG_AGENT_BRANCH), sha $(CONFIG_AGENT_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/config-agent && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created config-agent bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(CONFIG_AGENT_BITS)
	@echo ""

clean_config_agent:
	rm -rf $(BITS_DIR)/config-agent
	(cd build/config-agent && gmake clean)





#---- CNAPI

_cnapi_stamp=$(CNAPI_BRANCH)-$(TIMESTAMP)-g$(CNAPI_SHA)
CNAPI_BITS=$(BITS_DIR)/cnapi/cnapi-pkg-$(_cnapi_stamp).tar.bz2
CNAPI_IMAGE_BIT=$(BITS_DIR)/cnapi/cnapi-zfs-$(_cnapi_stamp).zfs.gz
CNAPI_MANIFEST_BIT=$(BITS_DIR)/cnapi/cnapi-zfs-$(_cnapi_stamp).zfs.dsmanifest

.PHONY: cnapi
cnapi: $(CNAPI_BITS) cnapi_image

# PATH for cnapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(CNAPI_BITS): build/cnapi
	@echo "# Build cnapi: branch $(CNAPI_BRANCH), sha $(CNAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/cnapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created cnapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(CNAPI_BITS)
	@echo ""

.PHONY: cnapi_image
cnapi_image: $(CNAPI_IMAGE_BIT)

$(CNAPI_IMAGE_BIT): $(CNAPI_BITS)
	@echo "# Build cnapi_image: branch $(CNAPI_BRANCH), sha $(CNAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(CNAPI_IMAGE_UUID)" -t $(CNAPI_BITS) \
		-o "$(CNAPI_IMAGE_BIT)" -p $(CNAPI_PKGSRC) \
		-t $(CNAPI_EXTRA_TARBALLS) -n $(CNAPI_IMAGE_NAME) \
		-v $(_cnapi_stamp) -d $(CNAPI_IMAGE_DESCRIPTION)
	@echo "# Created cnapi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(CNAPI_IMAGE_BIT)
	@echo ""

cnapi_publish_image: $(CNAPI_IMAGE_BIT)
	@echo "# Publish cnapi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(CNAPI_MANIFEST_BIT) -f $(CNAPI_IMAGE_BIT)

# Warning: if cnapi's submodule deps change, this 'clean_cnapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_cnapi:
	rm -rf $(BITS_DIR)/cnapi
	(cd build/cnapi && gmake clean)


#---- KeyAPI

_keyapi_stamp=$(KEYAPI_BRANCH)-$(TIMESTAMP)-g$(KEYAPI_SHA)
KEYAPI_BITS=$(BITS_DIR)/keyapi/keyapi-pkg-$(_keyapi_stamp).tar.bz2
KEYAPI_IMAGE_BIT=$(BITS_DIR)/keyapi/keyapi-zfs-$(_keyapi_stamp).zfs.gz
KEYAPI_MANIFEST_BIT=$(BITS_DIR)/keyapi/keyapi-zfs-$(_keyapi_stamp).zfs.dsmanifest

.PHONY: keyapi
keyapi: $(KEYAPI_BITS) keyapi_image

# PATH for keyapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(KEYAPI_BITS): build/keyapi
	@echo "# Build keyapi: branch $(KEYAPI_BRANCH), sha $(KEYAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/keyapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created keyapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(KEYAPI_BITS)
	@echo ""

.PHONY: keyapi_image
keyapi_image: $(KEYAPI_IMAGE_BIT)

$(KEYAPI_IMAGE_BIT): $(KEYAPI_BITS)
	@echo "# Build keyapi_image: branch $(KEYAPI_BRANCH), sha $(KEYAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(KEYAPI_IMAGE_UUID)" -t $(KEYAPI_BITS) \
		-o "$(KEYAPI_IMAGE_BIT)" -p $(KEYAPI_PKGSRC) \
		-t $(KEYAPI_EXTRA_TARBALLS) -n $(KEYAPI_IMAGE_NAME) \
		-v $(_keyapi_stamp) -d $(KEYAPI_IMAGE_DESCRIPTION)
	@echo "# Created keyapi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(KEYAPI_IMAGE_BIT)
	@echo ""

keyapi_publish_image: $(KEYAPI_IMAGE_BIT)
	@echo "# Publish keyapi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(KEYAPI_MANIFEST_BIT) -f $(KEYAPI_IMAGE_BIT)

# Warning: if NAPI's submodule deps change, this 'clean_keyapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_keyapi:
	rm -rf $(BITS_DIR)/keyapi
	(cd build/keyapi && gmake clean)


#---- SDCSSO

_sdcsso_stamp=$(SDCSSO_BRANCH)-$(TIMESTAMP)-g$(SDCSSO_SHA)
SDCSSO_BITS=$(BITS_DIR)/sdcsso/sdcsso-pkg-$(_sdcsso_stamp).tar.bz2
SDCSSO_IMAGE_BIT=$(BITS_DIR)/sdcsso/sdcsso-zfs-$(_sdcsso_stamp).zfs.gz
SDCSSO_MANIFEST_BIT=$(BITS_DIR)/sdcsso/sdcsso-zfs-$(_sdcsso_stamp).zfs.dsmanifest

.PHONY: sdcsso
sdcsso: $(SDCSSO_BITS) sdcsso_image

# PATH for sdcsso build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(SDCSSO_BITS): build/sdcsso
	@echo "# Build sdcsso: branch $(KEYAPI_BRANCH), sha $(KEYAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/sdcsso && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created sdcsso bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(SDCSSO_BITS)
	@echo ""

.PHONY: sdcsso_image
sdcsso_image: $(SDCSSO_IMAGE_BIT)

$(SDCSSO_IMAGE_BIT): $(SDCSSO_BITS)
	@echo "# Build sdcsso_image: branch $(SDCSSO_BRANCH), sha $(SDCSSO_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(SDCSSO_IMAGE_UUID)" -t $(SDCSSO_BITS) \
		-o "$(SDCSSO_IMAGE_BIT)" -p $(SDCSSO_PKGSRC) \
		-t $(SDCSSO_EXTRA_TARBALLS) -n $(SDCSSO_IMAGE_NAME) \
		-v $(_sdcsso_stamp) -d $(SDCSSO_IMAGE_DESCRIPTION)
	@echo "# Created sdcsso image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(SDCSSO_IMAGE_BIT)
	@echo ""

sdcsso_publish_image: $(SDCSSO_IMAGE_BIT)
	@echo "# Publish sdcsso image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(SDCSSO_MANIFEST_BIT) -f $(SDCSSO_IMAGE_BIT)

# Warning: if SDCSSO's submodule deps change, this 'clean_sdcsso is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_sdcsso:
	rm -rf $(BITS_DIR)/sdcsso
	(cd build/sdcsso && gmake clean)


#---- FWAPI

_fwapi_stamp=$(FWAPI_BRANCH)-$(TIMESTAMP)-g$(FWAPI_SHA)
FWAPI_BITS=$(BITS_DIR)/fwapi/fwapi-pkg-$(_fwapi_stamp).tar.bz2
FWAPI_IMAGE_BIT=$(BITS_DIR)/fwapi/fwapi-zfs-$(_fwapi_stamp).zfs.gz
FWAPI_MANIFEST_BIT=$(BITS_DIR)/fwapi/fwapi-zfs-$(_fwapi_stamp).zfs.dsmanifest

.PHONY: fwapi
fwapi: $(FWAPI_BITS) fwapi_image

# PATH for fwapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(FWAPI_BITS): build/fwapi
	@echo "# Build fwapi: branch $(FWAPI_BRANCH), sha $(FWAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/fwapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake pkg release publish)
	@echo "# Created fwapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(FWAPI_BITS)
	@echo ""

.PHONY: fwapi_image
fwapi_image: $(FWAPI_IMAGE_BIT)

$(FWAPI_IMAGE_BIT): $(FWAPI_BITS)
	@echo "# Build fwapi_image: branch $(FWAPI_BRANCH), sha $(FWAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(FWAPI_IMAGE_UUID)" -t $(FWAPI_BITS) \
		-o "$(FWAPI_IMAGE_BIT)" -p $(FWAPI_PKGSRC) \
		-t $(FWAPI_EXTRA_TARBALLS) -n $(FWAPI_IMAGE_NAME) \
		-v $(_fwapi_stamp) -d $(FWAPI_IMAGE_DESCRIPTION)
	@echo "# Created fwapi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(FWAPI_IMAGE_BIT)
	@echo ""

fwapi_publish_image: $(FWAPI_IMAGE_BIT)
	@echo "# Publish fwapi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(FWAPI_MANIFEST_BIT) -f $(FWAPI_IMAGE_BIT)

# Warning: if FWAPI's submodule deps change, this 'clean_fwapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_fwapi:
	rm -rf $(BITS_DIR)/fwapi
	(cd build/fwapi && gmake clean)



#---- NAPI

_napi_stamp=$(NAPI_BRANCH)-$(TIMESTAMP)-g$(NAPI_SHA)
NAPI_BITS=$(BITS_DIR)/napi/napi-pkg-$(_napi_stamp).tar.bz2
NAPI_IMAGE_BIT=$(BITS_DIR)/napi/napi-zfs-$(_napi_stamp).zfs.gz
NAPI_MANIFEST_BIT=$(BITS_DIR)/napi/napi-zfs-$(_napi_stamp).zfs.dsmanifest

.PHONY: napi
napi: $(NAPI_BITS) napi_image

# PATH for napi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(NAPI_BITS): build/napi
	@echo "# Build napi: branch $(NAPI_BRANCH), sha $(NAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/napi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake pkg release publish)
	@echo "# Created napi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(NAPI_BITS)
	@echo ""

.PHONY: napi_image
napi_image: $(NAPI_IMAGE_BIT)

$(NAPI_IMAGE_BIT): $(NAPI_BITS)
	@echo "# Build napi_image: branch $(NAPI_BRANCH), sha $(NAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(NAPI_IMAGE_UUID)" -t $(NAPI_BITS) \
		-o "$(NAPI_IMAGE_BIT)" -p $(NAPI_PKGSRC) \
		-t $(NAPI_EXTRA_TARBALLS) -n $(NAPI_IMAGE_NAME) \
		-v $(_napi_stamp) -d $(NAPI_IMAGE_DESCRIPTION)
	@echo "# Created napi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(NAPI_IMAGE_BIT)
	@echo ""

napi_publish_image: $(NAPI_IMAGE_BIT)
	@echo "# Publish napi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(NAPI_MANIFEST_BIT) -f $(NAPI_IMAGE_BIT)

# Warning: if NAPI's submodule deps change, this 'clean_napi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_napi:
	rm -rf $(BITS_DIR)/napi
	(cd build/napi && gmake clean)



#---- SAPI

_sapi_stamp=$(SAPI_BRANCH)-$(TIMESTAMP)-g$(SAPI_SHA)
SAPI_BITS=$(BITS_DIR)/sapi/sapi-pkg-$(_sapi_stamp).tar.bz2
SAPI_IMAGE_BIT=$(BITS_DIR)/sapi/sapi-zfs-$(_sapi_stamp).zfs.gz
SAPI_MANIFEST_BIT=$(BITS_DIR)/sapi/sapi-zfs-$(_sapi_stamp).zfs.dsmanifest

.PHONY: sapi
sapi: $(SAPI_BITS) sapi_image


# PATH for sapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(SAPI_BITS): build/sapi
	@echo "# Build sapi: branch $(SAPI_BRANCH), sha $(SAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/sapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created sapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(SAPI_BITS)
	@echo ""

.PHONY: sapi_image
sapi_image: $(SAPI_IMAGE_BIT)

$(SAPI_IMAGE_BIT): $(SAPI_BITS)
	@echo "# Build sapi_image: branch $(SAPI_BRANCH), sha $(SAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(SAPI_IMAGE_UUID)" -t $(SAPI_BITS) \
		-o "$(SAPI_IMAGE_BIT)" -p $(SAPI_PKGSRC) \
		-t $(SAPI_EXTRA_TARBALLS) -n $(SAPI_IMAGE_NAME) \
		-v $(_sapi_stamp) -d $(SAPI_IMAGE_DESCRIPTION)
	@echo "# Created sapi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(SAPI_IMAGE_BIT)
	@echo ""

sapi_publish_image: $(SAPI_IMAGE_BIT)
	@echo "# Publish sapi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(SAPI_MANIFEST_BIT) -f $(SAPI_IMAGE_BIT)

# Warning: if SAPI's submodule deps change, this 'clean_sapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_sapi:
	rm -rf $(BITS_DIR)/sapi
	(cd build/sapi && gmake clean)



#---- Marlin

_marlin_stamp=$(MARLIN_BRANCH)-$(TIMESTAMP)-g$(MARLIN_SHA)
MARLIN_BITS=$(BITS_DIR)/marlin/marlin-pkg-$(_marlin_stamp).tar.bz2
MARLIN_IMAGE_BIT=$(BITS_DIR)/marlin/marlin-zfs-$(_marlin_stamp).zfs.gz
MARLIN_MANIFEST_BIT=$(BITS_DIR)/marlin/marlin-zfs-$(_marlin_stamp).zfs.dsmanifest

.PHONY: marlin
marlin: $(MARLIN_BITS) marlin_image

# PATH for marlin build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(MARLIN_BITS): build/marlin
	@echo "# Build marlin: branch $(MARLIN_BRANCH), sha $(MARLIN_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/marlin && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created marlin bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MARLIN_BITS)
	@echo ""

.PHONY: marlin_image
marlin_image: $(MARLIN_IMAGE_BIT)

$(MARLIN_IMAGE_BIT): $(MARLIN_BITS)
	@echo "# Build marlin_image: branch $(MARLIN_BRANCH), sha $(MARLIN_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(MARLIN_IMAGE_UUID)" -t $(MARLIN_BITS) \
		-o "$(MARLIN_IMAGE_BIT)" -p $(MARLIN_PKGSRC) \
		-t $(MARLIN_EXTRA_TARBALLS) -n $(MARLIN_IMAGE_NAME) \
		-v $(_marlin_stamp) -d $(MARLIN_IMAGE_DESCRIPTION)
	@echo "# Created marlin image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MARLIN_IMAGE_BIT)
	@echo ""

marlin_publish_image: $(MARLIN_IMAGE_BIT)
	@echo "# Publish marlin image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MARLIN_MANIFEST_BIT) -f $(MARLIN_IMAGE_BIT)

clean_marlin:
	rm -rf $(BITS_DIR)/marlin
	(cd build/marlin && gmake distclean)


#---- MAHI

_mahi_stamp=$(MAHI_BRANCH)-$(TIMESTAMP)-g$(MAHI_SHA)
MAHI_BITS=$(BITS_DIR)/mahi/mahi-pkg-$(_mahi_stamp).tar.bz2
MAHI_IMAGE_BIT=$(BITS_DIR)/mahi/mahi-zfs-$(_mahi_stamp).zfs.gz
MAHI_MANIFEST_BIT=$(BITS_DIR)/mahi/mahi-zfs-$(_mahi_stamp).zfs.dsmanifest

.PHONY: mahi
mahi: $(MAHI_BITS) mahi_image

$(MAHI_BITS): build/mahi
	@echo "# Build mahi: branch $(MAHI_BRANCH), sha $(MAHI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/mahi && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created mahi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MAHI_BITS)
	@echo ""

.PHONY: mahi_image
mahi_image: $(MAHI_IMAGE_BIT)

$(MAHI_IMAGE_BIT): $(MAHI_BITS)
	@echo "# Build mahi_image: branch $(MAHI_BRANCH), sha $(MAHI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(MAHI_IMAGE_UUID)" -t $(MAHI_BITS) \
		-o "$(MAHI_IMAGE_BIT)" -p $(MAHI_PKGSRC) \
		-t $(MAHI_EXTRA_TARBALLS) -n $(MAHI_IMAGE_NAME) \
		-v $(_mahi_stamp) -d $(MAHI_IMAGE_DESCRIPTION)
	@echo "# Created mahi image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MAHI_IMAGE_BIT)
	@echo ""

mahi_publish_image: $(MAHI_IMAGE_BIT)
	@echo "# Publish mahi image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MAHI_MANIFEST_BIT) -f $(MAHI_IMAGE_BIT)

clean_mahi:
	rm -rf $(BITS_DIR)/mahi
	(cd build/mahi && gmake distclean)


#---- Mola

_mola_stamp=$(MOLA_BRANCH)-$(TIMESTAMP)-g$(MOLA_SHA)
MOLA_BITS=$(BITS_DIR)/mola/mola-pkg-$(_mola_stamp).tar.bz2
MOLA_IMAGE_BIT=$(BITS_DIR)/mola/mola-zfs-$(_mola_stamp).zfs.gz
MOLA_MANIFEST_BIT=$(BITS_DIR)/mola/mola-zfs-$(_mola_stamp).zfs.dsmanifest

.PHONY: mola
mola: $(MOLA_BITS) mola_image

# PATH for mola build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(MOLA_BITS): build/mola
	@echo "# Build mola: branch $(MOLA_BRANCH), sha $(MOLA_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/mola && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created mola bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MOLA_BITS)
	@echo ""

.PHONY: mola_image
mola_image: $(MOLA_IMAGE_BIT)

$(MOLA_IMAGE_BIT): $(MOLA_BITS)
	@echo "# Build mola_image: branch $(MOLA_BRANCH), sha $(MOLA_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(MOLA_IMAGE_UUID)" -t $(MOLA_BITS) \
		-o "$(MOLA_IMAGE_BIT)" -p $(MOLA_PKGSRC) \
		-t $(MOLA_EXTRA_TARBALLS) -n $(MOLA_IMAGE_NAME) \
		-v $(_mola_stamp) -d $(MOLA_IMAGE_DESCRIPTION)
	@echo "# Created mola image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MOLA_IMAGE_BIT)
	@echo ""

mola_publish_image: $(MOLA_IMAGE_BIT)
	@echo "# Publish mola image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MOLA_MANIFEST_BIT) -f $(MOLA_IMAGE_BIT)

clean_mola:
	rm -rf $(BITS_DIR)/mola
	(cd build/mola && gmake distclean)


#---- Moray

_moray_stamp=$(MORAY_BRANCH)-$(TIMESTAMP)-g$(MORAY_SHA)
MORAY_BITS=$(BITS_DIR)/moray/moray-pkg-$(_moray_stamp).tar.bz2
MORAY_IMAGE_BIT=$(BITS_DIR)/moray/moray-zfs-$(_moray_stamp).zfs.gz
MORAY_MANIFEST_BIT=$(BITS_DIR)/moray/moray-zfs-$(_moray_stamp).zfs.dsmanifest

.PHONY: moray
moray: $(MORAY_BITS) moray_image

# PATH for moray build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(MORAY_BITS): build/moray
	@echo "# Build moray: branch $(MORAY_BRANCH), sha $(MORAY_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/moray && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created moray bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MORAY_BITS)
	@echo ""

.PHONY: moray_image
moray_image: $(MORAY_IMAGE_BIT)

$(MORAY_IMAGE_BIT): $(MORAY_BITS)
	@echo "# Build moray_image: branch $(MORAY_BRANCH), sha $(MORAY_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(MORAY_IMAGE_UUID)" -t $(MORAY_BITS) \
		-o "$(MORAY_IMAGE_BIT)" -p $(MORAY_PKGSRC) \
		-t $(MORAY_EXTRA_TARBALLS) -n $(MORAY_IMAGE_NAME) \
		-v $(_moray_stamp) -d $(MORAY_IMAGE_DESCRIPTION)
	@echo "# Created moray image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MORAY_IMAGE_BIT)
	@echo ""

moray_publish_image: $(MORAY_IMAGE_BIT)
	@echo "# Publish moray image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MORAY_MANIFEST_BIT) -f $(MORAY_IMAGE_BIT)

clean_moray:
	rm -rf $(BITS_DIR)/moray
	(cd build/moray && gmake distclean)


#---- Electric-Moray

_electric-moray_stamp=$(ELECTRIC-MORAY_BRANCH)-$(TIMESTAMP)-g$(ELECTRIC-MORAY_SHA)
ELECTRIC-MORAY_BITS=$(BITS_DIR)/electric-moray/electric-moray-pkg-$(_electric-moray_stamp).tar.bz2
ELECTRIC-MORAY_IMAGE_BIT=$(BITS_DIR)/electric-moray/electric-moray-zfs-$(_electric-moray_stamp).zfs.gz
ELECTRIC-MORAY_MANIFEST_BIT=$(BITS_DIR)/electric-moray/electric-moray-zfs-$(_electric-moray_stamp).zfs.dsmanifest

.PHONY: electric-moray
electric-moray: $(ELECTRIC-MORAY_BITS) electric-moray_image

# PATH for electric-moray build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(ELECTRIC-MORAY_BITS): build/electric-moray
	@echo "# Build electric-moray: branch $(ELECTRIC-MORAY_BRANCH), sha $(ELECTRIC-MORAY_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/electric-moray && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created electric-moray bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(ELECTRIC-MORAY_BITS)
	@echo ""

.PHONY: electric-moray_image
electric-moray_image: $(ELECTRIC-MORAY_IMAGE_BIT)

$(ELECTRIC-MORAY_IMAGE_BIT): $(ELECTRIC-MORAY_BITS)
	@echo "# Build electric-moray_image: branch $(ELECTRIC-MORAY_BRANCH), sha $(ELECTRIC-MORAY_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(ELECTRIC-MORAY_IMAGE_UUID)" -t $(ELECTRIC-MORAY_BITS) \
		-o "$(ELECTRIC-MORAY_IMAGE_BIT)" -p $(ELECTRIC-MORAY_PKGSRC) \
		-t $(ELECTRIC-MORAY_EXTRA_TARBALLS) -n $(ELECTRIC-MORAY_IMAGE_NAME) \
		-v $(_electric-moray_stamp) -d $(ELECTRIC-MORAY_IMAGE_DESCRIPTION)
	@echo "# Created electric-moray image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(ELECTRIC-MORAY_IMAGE_BIT)
	@echo ""

electric-moray_publish_image: $(ELECTRIC-MORAY_IMAGE_BIT)
	@echo "# Publish electric-moray image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(ELECTRIC-MORAY_MANIFEST_BIT) -f $(ELECTRIC-MORAY_IMAGE_BIT)

clean_electric-moray:
	rm -rf $(BITS_DIR)/electric-moray
	(cd build/electric-moray && gmake distclean)


#---- Muskie

_muskie_stamp=$(MUSKIE_BRANCH)-$(TIMESTAMP)-g$(MUSKIE_SHA)
MUSKIE_BITS=$(BITS_DIR)/muskie/muskie-pkg-$(_muskie_stamp).tar.bz2
MUSKIE_IMAGE_BIT=$(BITS_DIR)/muskie/muskie-zfs-$(_muskie_stamp).zfs.gz
MUSKIE_MANIFEST_BIT=$(BITS_DIR)/muskie/muskie-zfs-$(_muskie_stamp).zfs.dsmanifest

.PHONY: muskie
muskie: $(MUSKIE_BITS) muskie_image

# PATH for muskie build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(MUSKIE_BITS): build/muskie
	@echo "# Build muskie: branch $(MUSKIE_BRANCH), sha $(MUSKIE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/muskie && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created muskie bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MUSKIE_BITS)
	@echo ""

.PHONY: muskie_image
muskie_image: $(MUSKIE_IMAGE_BIT)

$(MUSKIE_IMAGE_BIT): $(MUSKIE_BITS)
	@echo "# Build muskie_image: branch $(MUSKIE_BRANCH), sha $(MUSKIE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(MUSKIE_IMAGE_UUID)" -t $(MUSKIE_BITS) \
		-o "$(MUSKIE_IMAGE_BIT)" -p $(MUSKIE_PKGSRC) \
		-t $(MUSKIE_EXTRA_TARBALLS) -n $(MUSKIE_IMAGE_NAME) \
		-v $(_muskie_stamp) -d $(MUSKIE_IMAGE_DESCRIPTION)
	@echo "# Created muskie image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MUSKIE_IMAGE_BIT)
	@echo ""

muskie_publish_image: $(MUSKIE_IMAGE_BIT)
	@echo "# Publish muskie image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MUSKIE_MANIFEST_BIT) -f $(MUSKIE_IMAGE_BIT)

clean_muskie:
	rm -rf $(BITS_DIR)/muskie
	(cd build/muskie && gmake distclean)


#---- Wrasse

_wrasse_stamp=$(WRASSE_BRANCH)-$(TIMESTAMP)-g$(WRASSE_SHA)
WRASSE_BITS=$(BITS_DIR)/wrasse/wrasse-pkg-$(_wrasse_stamp).tar.bz2
WRASSE_IMAGE_BIT=$(BITS_DIR)/wrasse/wrasse-zfs-$(_wrasse_stamp).zfs.gz
WRASSE_MANIFEST_BIT=$(BITS_DIR)/wrasse/wrasse-zfs-$(_wrasse_stamp).zfs.dsmanifest

.PHONY: wrasse
wrasse: $(WRASSE_BITS) wrasse_image

# PATH for wrasse build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(WRASSE_BITS): build/wrasse
	@echo "# Build wrasse: branch $(WRASSE_BRANCH), sha $(WRASSE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/wrasse && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created wrasse bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(WRASSE_BITS)
	@echo ""

.PHONY: wrasse_image
wrasse_image: $(WRASSE_IMAGE_BIT)

$(WRASSE_IMAGE_BIT): $(WRASSE_BITS)
	@echo "# Build wrasse_image: branch $(WRASSE_BRANCH), sha $(WRASSE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(WRASSE_IMAGE_UUID)" -t $(WRASSE_BITS) \
		-o "$(WRASSE_IMAGE_BIT)" -p $(WRASSE_PKGSRC) \
		-t $(WRASSE_EXTRA_TARBALLS) -n $(WRASSE_IMAGE_NAME) \
		-v $(_wrasse_stamp) -d $(WRASSE_IMAGE_DESCRIPTION)
	@echo "# Created wrasse image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(WRASSE_IMAGE_BIT)
	@echo ""

wrasse_publish_image: $(WRASSE_IMAGE_BIT)
	@echo "# Publish wrasse image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(WRASSE_MANIFEST_BIT) -f $(WRASSE_IMAGE_BIT)

clean_wrasse:
	rm -rf $(BITS_DIR)/wrasse
	(cd build/wrasse && gmake distclean)


#---- Registrar

_registrar_stamp=$(REGISTRAR_BRANCH)-$(TIMESTAMP)-g$(REGISTRAR_SHA)
REGISTRAR_BITS=$(BITS_DIR)/registrar/registrar-pkg-$(_registrar_stamp).tar.bz2

.PHONY: registrar
registrar: $(REGISTRAR_BITS)

$(REGISTRAR_BITS): build/registrar
	@echo "# Build registrar: branch $(REGISTRAR_BRANCH), sha $(REGISTRAR_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/registrar && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created registrar bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(REGISTRAR_BITS)
	@echo ""

clean_registrar:
	rm -rf $(BITS_DIR)/registrar
	(cd build/registrar && gmake distclean)


#---- Configurator

_configurator_stamp=$(CONFIGURATOR_BRANCH)-$(TIMESTAMP)-g$(CONFIGURATOR_SHA)
CONFIGURATOR_BITS=$(BITS_DIR)/configurator/configurator-pkg-$(_configurator_stamp).tar.bz2

.PHONY: configurator
configurator: $(CONFIGURATOR_BITS)

$(CONFIGURATOR_BITS): build/configurator
	@echo "# Build configurator: branch $(CONFIGURATOR_BRANCH), sha $(CONFIGURATOR_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/configurator && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created configurator bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(CONFIGURATOR_BITS)
	@echo ""

clean_configurator:
	rm -rf $(BITS_DIR)/configurator
	(cd build/configurator && gmake distclean)


#---- mackerel

_mackerel_stamp=$(MACKEREL_BRANCH)-$(TIMESTAMP)-g$(MACKEREL_SHA)
MACKEREL_BITS=$(BITS_DIR)/mackerel/mackerel-pkg-$(_mackerel_stamp).tar.bz2

.PHONY: mackerel
mackerel: $(MACKEREL_BITS)

$(MACKEREL_BITS): build/mackerel
	@echo "# Build mackerel: branch $(MACKEREL_BRANCH), sha $(MACKEREL_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/mackerel && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created mackerel bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MACKEREL_BITS)
	@echo ""

clean_mackerel:
	rm -rf $(BITS_DIR)/mackerel
	(cd build/mackerel && gmake distclean)


#---- manowar

_manowar_stamp=$(MANOWAR_BRANCH)-$(TIMESTAMP)-g$(MANOWAR_SHA)
MANOWAR_BITS=$(BITS_DIR)/manowar/manowar-pkg-$(_manowar_stamp).tar.bz2

.PHONY: manowar
manowar: $(MANOWAR_BITS)

$(MANOWAR_BITS): build/manowar
	@echo "# Build manowar: branch $(MANOWAR_BRANCH), sha $(MANOWAR_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/manowar && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created manowar bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MANOWAR_BITS)
	@echo ""

clean_manowar:
	rm -rf $(BITS_DIR)/manowar
	(cd build/manowar && gmake distclean)


#---- Binder

_binder_stamp=$(BINDER_BRANCH)-$(TIMESTAMP)-g$(BINDER_SHA)
BINDER_BITS=$(BITS_DIR)/binder/binder-pkg-$(_binder_stamp).tar.bz2
BINDER_IMAGE_BIT=$(BITS_DIR)/binder/binder-zfs-$(_binder_stamp).zfs.gz
BINDER_MANIFEST_BIT=$(BITS_DIR)/binder/binder-zfs-$(_binder_stamp).zfs.dsmanifest

.PHONY: binder
binder: $(BINDER_BITS) binder_image

$(BINDER_BITS): build/binder
	@echo "# Build binder: branch $(BINDER_BRANCH), sha $(BINDER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/binder && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created binder bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(BINDER_BITS)
	@echo ""

.PHONY: binder_image
binder_image: $(BINDER_IMAGE_BIT)

$(BINDER_IMAGE_BIT): $(BINDER_BITS)
	@echo "# Build binder_image: branch $(BINDER_BRANCH), sha $(BINDER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(BINDER_IMAGE_UUID)" -t $(BINDER_BITS) \
		-o "$(BINDER_IMAGE_BIT)" -p $(BINDER_PKGSRC) \
		-t $(BINDER_EXTRA_TARBALLS) -n $(BINDER_IMAGE_NAME) \
		-v $(_binder_stamp) -d $(BINDER_IMAGE_DESCRIPTION)
	@echo "# Created binder image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(BINDER_IMAGE_BIT)
	@echo ""

binder_publish_image: $(BINDER_IMAGE_BIT)
	@echo "# Publish binder image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(BINDER_MANIFEST_BIT) -f $(BINDER_IMAGE_BIT)

clean_binder:
	rm -rf $(BITS_DIR)/binder
	(cd build/binder && gmake distclean)

#---- Muppet

_muppet_stamp=$(MUPPET_BRANCH)-$(TIMESTAMP)-g$(MUPPET_SHA)
MUPPET_BITS=$(BITS_DIR)/muppet/muppet-pkg-$(_muppet_stamp).tar.bz2
MUPPET_IMAGE_BIT=$(BITS_DIR)/muppet/muppet-zfs-$(_muppet_stamp).zfs.gz
MUPPET_MANIFEST_BIT=$(BITS_DIR)/muppet/muppet-zfs-$(_muppet_stamp).zfs.dsmanifest

.PHONY: muppet
muppet: $(MUPPET_BITS) muppet_image

$(MUPPET_BITS): build/muppet
	@echo "# Build muppet: branch $(MUPPET_BRANCH), sha $(MUPPET_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/muppet && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created muppet bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MUPPET_BITS)
	@echo ""

.PHONY: muppet_image
muppet_image: $(MUPPET_IMAGE_BIT)

$(MUPPET_IMAGE_BIT): $(MUPPET_BITS)
	@echo "# Build muppet_image: branch $(MUPPET_BRANCH), sha $(MUPPET_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(MUPPET_IMAGE_UUID)" -t $(MUPPET_BITS) \
		-o "$(MUPPET_IMAGE_BIT)" -p $(MUPPET_PKGSRC) \
		-t $(MUPPET_EXTRA_TARBALLS) -n $(MUPPET_IMAGE_NAME) \
		-v $(_muppet_stamp) -d $(MUPPET_IMAGE_DESCRIPTION)
	@echo "# Created muppet image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MUPPET_IMAGE_BIT)
	@echo ""

muppet_publish_image: $(MUPPET_IMAGE_BIT)
	@echo "# Publish muppet image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MUPPET_MANIFEST_BIT) -f $(MUPPET_IMAGE_BIT)

clean_muppet:
	rm -rf $(BITS_DIR)/muppet
	(cd build/muppet && gmake distclean)

#---- Minnow

_minnow_stamp=$(MINNOW_BRANCH)-$(TIMESTAMP)-g$(MINNOW_SHA)
MINNOW_BITS=$(BITS_DIR)/minnow/minnow-pkg-$(_minnow_stamp).tar.bz2

.PHONY: minnow
minnow: $(MINNOW_BITS)

$(MINNOW_BITS): build/minnow
	@echo "# Build minnow: branch $(MINNOW_BRANCH), sha $(MINNOW_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/minnow && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created minnow bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MINNOW_BITS)
	@echo ""

clean_minnow:
	rm -rf $(BITS_DIR)/minnow
	(cd build/minnow && gmake distclean)


#---- Mako

_mako_stamp=$(MAKO_BRANCH)-$(TIMESTAMP)-g$(MAKO_SHA)
MAKO_BITS=$(BITS_DIR)/mako/mako-pkg-$(_mako_stamp).tar.bz2
MAKO_IMAGE_BIT=$(BITS_DIR)/mako/mako-zfs-$(_mako_stamp).zfs.gz
MAKO_MANIFEST_BIT=$(BITS_DIR)/mako/mako-zfs-$(_mako_stamp).zfs.dsmanifest

.PHONY: mako
mako: $(MAKO_BITS) mako_image

$(MAKO_BITS): build/mako
	@echo "# Build mako: branch $(MAKO_BRANCH), sha $(MAKO_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/mako && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created mako bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MAKO_BITS)
	@echo ""

.PHONY: mako_image
mako_image: $(MAKO_IMAGE_BIT)

$(MAKO_IMAGE_BIT): $(MAKO_BITS)
	@echo "# Build mako_image: branch $(MAKO_BRANCH), sha $(MAKO_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -i "$(MAKO_IMAGE_UUID)" -t $(MAKO_BITS) \
		-o "$(MAKO_IMAGE_BIT)" -p $(MAKO_PKGSRC) \
		-t $(MAKO_EXTRA_TARBALLS) -n $(MAKO_IMAGE_NAME) \
		-v $(_mako_stamp) -d $(MAKO_IMAGE_DESCRIPTION)
	@echo "# Created mako image (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MAKO_IMAGE_BIT)
	@echo ""

mako_publish_image: $(MAKO_IMAGE_BIT)
	@echo "# Publish mako image to SDC Updates repo."
	$(UPDATES_IMGADM) import -ddd -m $(MAKO_MANIFEST_BIT) -f $(MAKO_IMAGE_BIT)

clean_mako:
	rm -rf $(BITS_DIR)/mako
	(cd build/mako && gmake distclean)


#---- agentsshar

ifeq ($(TRY_BRANCH),)
_as_stamp=$(AGENTS_INSTALLER_BRANCH)-$(TIMESTAMP)-g$(AGENTS_INSTALLER_SHA)
else
_as_stamp=$(TRY_BRANCH)-$(TIMESTAMP)-g$(AGENTS_INSTALLER_SHA)
endif
AGENTSSHAR_BITS=$(BITS_DIR)/agentsshar/agents-$(_as_stamp).sh \
	$(BITS_DIR)/agentsshar/agents-$(_as_stamp).md5sum
AGENTSSHAR_BITS_0=$(shell echo $(AGENTSSHAR_BITS) | awk '{print $$1}')

.PHONY: agentsshar
agentsshar: $(AGENTSSHAR_BITS_0)

$(AGENTSSHAR_BITS): build/agents-installer/Makefile
	@echo "# Build agentsshar: branch $(AGENTS_INSTALLER_BRANCH), sha $(AGENTS_INSTALLER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)/agentsshar
	(cd build/agents-installer && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) ./mk-agents-shar -o $(BITS_DIR)/agentsshar/ -d $(BITS_DIR) -b "$(TRY_BRANCH) $(AGENTS_INSTALLER_BRANCH)")
	@echo "# Created agentsshar bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(AGENTSSHAR_BITS)
	@echo ""

clean_agentsshar:
	rm -rf $(BITS_DIR)/agentsshar
	(if [[ -d build/agents-installer ]]; then cd build/agents-installer && gmake clean; fi )


#---- agents-upgrade

_agents_upgrade_stamp=$(AGENTS_BRANCH)-$(TIMESTAMP)-g$(AGENTS_SHA)
AGENTS_UPGRADE_BITS=$(BITS_DIR)/agents-upgrade/provisioner-v2-$(_agents_upgrade_stamp).tgz \
	$(BITS_DIR)/agents-upgrade/heartbeater-$(_agents_upgrade_stamp).tgz
AGENTS_UPGRADE_BITS_0=$(shell echo $(AGENTS_UPGRADE_BITS) | awk '{print $$1}')

.PHONY: agents-upgrade
agents-upgrade: $(AGENTS_UPGRADE_BITS_0)

$(AGENTS_UPGRADE_BITS): build/agents/build.sh
	@echo "# Build agents-upgrade: branch $(AGENTS_BRANCH), sha $(AGENTS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)/agents-upgrade
	(cd build/agents && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm TIMESTAMP=$(TIMESTAMP) ./build.sh -n)
	cp build/agents/build/provisioner-v2*.tgz build/agents/build/heartbeater-*.tgz $(BITS_DIR)/agents-upgrade
	@echo "# Created agents-upgrade bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(AGENTS_UPGRADE_BITS)
	@echo ""

clean_agentsshar-upgrade:
	rm -rf $(BITS_DIR)/agents-upgrade
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
	(cd build/convertvm && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created convertvm bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(CONVERTVM_BITS)
	@echo ""

# Warning: if convertvm's submodule deps change, this 'clean_convertvm' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_convertvm:
	rm -rf $(BITS_DIR)/convertvm
	(cd build/convertvm && gmake clean)


#---- Manta utilites

_manta_stamp=$(MANTA_BRANCH)-$(TIMESTAMP)-g$(MANTA_SHA)
MANTA_BITS=$(BITS_DIR)/manta/manta-pkg-$(_manta_stamp).tar.bz2

.PHONY: manta
manta: $(MANTA_BITS)

$(MANTA_BITS): build/manta
	@echo "# Build manta: branch $(MANTA_BRANCH), sha $(MANTA_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/manta && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created manta bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MANTA_BITS)
	@echo ""

clean_manta:
	rm -rf $(BITS_DIR)/manta
	(cd build/manta && gmake distclean)


_manta_deployment_stamp=$(MANTA_DEPLOYMENT_BRANCH)-$(TIMESTAMP)-g$(MANTA_DEPLOYMENT_SHA)
MANTA_DEPLOYMENT_BITS=$(BITS_DIR)/manta-deployment/manta-deployment-pkg-$(_manta_deployment_stamp).tar.bz2

.PHONY: manta-deployment
manta-deployment: $(MANTA_DEPLOYMENT_BITS)

$(MANTA_DEPLOYMENT_BITS): build/manta-deployment
	@echo "# Build manta-deployment: branch $(MANTA_DEPLOYMENT_BRANCH), sha $(MANTA_DEPLOYMENT_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/manta-deployment && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created manta-deployment bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MANTA_DEPLOYMENT_BITS)
	@echo ""

clean_manta_deployment:
	rm -rf $(BITS_DIR)/manta-deployment
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
	@ls -1 $(SDCBOOT_BITS)
	@echo ""

clean_sdcboot:
	rm -rf $(BITS_DIR)/sdcboot
	(cd build/sdcboot && gmake clean)

#---- usb-headnode
# We are using the '-s STAGE-DIR' option to the usb-headnode build to
# avoid rebuilding it. We use the "boot" target to build the stage dir
# and have the other usb-headnode targets depend on that.
#
# TODO:
# - solution for datasets
# - pkgsrc isolation

.PHONY: usbheadnode
usbheadnode: boot coal usb upgrade releasejson

_usbheadnode_stamp=$(USB_HEADNODE_BRANCH)-$(TIMESTAMP)-g$(USB_HEADNODE_SHA)


BOOT_BIT=$(BITS_DIR)/usbheadnode/boot-$(_usbheadnode_stamp).tgz

.PHONY: boot
boot: $(BOOT_BIT)

$(BOOT_BIT): bits/usbheadnode/build.spec.local
	@echo "# Build boot: usb-headnode branch $(USB_HEADNODE_BRANCH), sha $(USB_HEADNODE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)/usbheadnode
	cd build/usb-headnode \
		&& BITS_URL=$(TOP)/bits TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(TOP)/build PKGSRC_DIR=$(TOP)/build/pkgsrc ./bin/build-tar-image -c
	mv build/usb-headnode/$(shell basename $(BOOT_BIT)) $(BITS_DIR)/usbheadnode
	@echo "# Created boot bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(BOOT_BIT)
	@echo ""


COAL_BIT=$(BITS_DIR)/usbheadnode/coal-$(_usbheadnode_stamp)-4gb.tgz

bits/usbheadnode/build.spec.local:
	mkdir -p bits/usbheadnode
	bash <build.spec.in >bits/usbheadnode/build.spec.local
	(cd build/usb-headnode; rm -f build.spec.local; ln -s ../../bits/usbheadnode/build.spec.local)

.PHONY: coal
coal: usb $(COAL_BIT)

$(COAL_BIT): bits/usbheadnode/build.spec.local $(USB_BIT)
	@echo "# Build coal: usb-headnode branch $(USB_HEADNODE_BRANCH), sha $(USB_HEADNODE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)/usbheadnode
	cd build/usb-headnode \
		&& BITS_URL=$(TOP)/bits TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(TOP)/build PKGSRC_DIR=$(TOP)/build/pkgsrc ./bin/build-coal-image -c $(USB_BIT)
	mv build/usb-headnode/$(shell basename $(COAL_BIT)) $(BITS_DIR)/usbheadnode
	@echo "# Created coal bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(COAL_BIT)
	@echo ""

USB_BIT=$(BITS_DIR)/usbheadnode/usb-$(_usbheadnode_stamp).tgz

.PHONY: usb
usb: $(USB_BIT)

$(USB_BIT): bits/usbheadnode/build.spec.local $(BOOT_BIT)
	@echo "# Build usb: usb-headnode branch $(USB_HEADNODE_BRANCH), sha $(USB_HEADNODE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)/usbheadnode
	cd build/usb-headnode \
		&& BITS_URL=$(TOP)/bits TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(TOP)/build PKGSRC_DIR=$(TOP)/build/pkgsrc ./bin/build-usb-image -c $(BOOT_BIT)
	mv build/usb-headnode/$(shell basename $(USB_BIT)) $(BITS_DIR)/usbheadnode
	@echo "# Created usb bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(USB_BIT)
	@echo ""

UPGRADE_BIT=$(BITS_DIR)/usbheadnode/upgrade-$(_usbheadnode_stamp).tgz

.PHONY: upgrade
upgrade: $(UPGRADE_BIT)

$(UPGRADE_BIT): bits/usbheadnode/build.spec.local $(BOOT_BIT)
	@echo "# Build upgrade: usb-headnode branch $(USB_HEADNODE_BRANCH), sha $(USB_HEADNODE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)/usbheadnode
	cd build/usb-headnode \
		&& BITS_URL=$(TOP)/bits TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(TOP)/build PKGSRC_DIR=$(TOP)/build/pkgsrc ./bin/build-upgrade-image $(BOOT_BIT)
	mv build/usb-headnode/$(shell basename $(UPGRADE_BIT)) $(BITS_DIR)/usbheadnode
	@echo "# Created upgrade bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(UPGRADE_BIT)
	@echo ""

IMAGE_BIT=$(BITS_DIR)/usbheadnode/usb-$(_usbheadnode_stamp).zvol.bz2
MANIFEST_BIT=$(BITS_DIR)/usbheadnode/usb-$(_usbheadnode_stamp).dsmanifest

.PHONY: image
image: $(IMAGE_BIT)

$(IMAGE_BIT): bits/usbheadnode/build.spec.local $(USB_BIT)
	@echo "# Build upgrade: usb-headnode branch $(USB_HEADNODE_BRANCH), sha $(USB_HEADNODE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)/usbheadnode
	cd build/usb-headnode \
		&& BITS_URL=$(TOP)/bits TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(TOP)/build PKGSRC_DIR=$(TOP)/build/pkgsrc ./bin/build-dataset $(USB_BIT)
	mv build/usb-headnode/$(shell basename $(IMAGE_BIT)) build/usb-headnode/$(shell basename $(MANIFEST_BIT)) $(BITS_DIR)/usbheadnode
	@echo "# Created image bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(IMAGE_BIT) $(MANIFEST_BIT)
	@echo ""


RELEASEJSON_BIT=$(BITS_DIR)/usbheadnode/release.json

.PHONY: releasejson
releasejson:
	mkdir -p $(BITS_DIR)/usbheadnode
	echo "{ \
	\"date\": \"$(TIMESTAMP)\", \
	\"branch\": \"$(BRANCH)\", \
	\"try-branch\": \"$(TRY-BRANCH)\", \
	\"coal\": \"$(shell basename $(COAL_BIT))\", \
	\"boot\": \"$(shell basename $(BOOT_BIT))\", \
	\"usb\": \"$(shell basename $(USB_BIT))\", \
	\"upgrade\": \"$(shell basename $(UPGRADE_BIT))\" \
}" | $(JSON) >$(RELEASEJSON_BIT)


clean_usbheadnode:
	rm -rf $(BOOT_BIT) $(UPGRADE_BIT) $(USB_BIT) $(COAL_BIT) $(RELEASEJSON_BIT)



#---- platform

PLATFORM_BITS= \
	$(BITS_DIR)/platform/platform-$(SMARTOS_LIVE_BRANCH)-$(TIMESTAMP).tgz \
	$(BITS_DIR)/platform/boot-$(SMARTOS_LIVE_BRANCH)-$(TIMESTAMP).tgz
PLATFORM_BITS_0=$(shell echo $(PLATFORM_BITS) | awk '{print $$1}')

.PHONY: platform
platform: $(PLATFORM_BITS_0)

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
		-e "s:SDC_PLATFORM_BRANCH:$(SDC_PLATFORM_BRANCH):" \
		<smartos-live-configure-branches.in >build/smartos-live/configure-branches

# PATH: Ensure using GCC from SFW as require for platform build.
$(PLATFORM_BITS): build/smartos-live/configure.mg build/smartos-live/configure-branches
	@echo "# Build platform: branch $(SMARTOS_LIVE_BRANCH), sha $(SMARTOS_LIVE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	(cd build/smartos-live \
		&& PATH=/usr/sfw/bin:$(PATH) \
			./configure \
		&& PATH=/usr/sfw/bin:$(PATH) \
			BUILDSTAMP=$(TIMESTAMP) \
			gmake world \
		&& PATH=/usr/sfw/bin:$(PATH) \
			BUILDSTAMP=$(TIMESTAMP) \
			gmake live)
	(mkdir -p $(BITS_DIR)/platform)
	(cp build/smartos-live/output/platform-$(TIMESTAMP).tgz $(BITS_DIR)/platform/platform-$(SMARTOS_LIVE_BRANCH)-$(TIMESTAMP).tgz)
	(cp build/smartos-live/output/boot-$(TIMESTAMP).tgz $(BITS_DIR)/platform/boot-$(SMARTOS_LIVE_BRANCH)-$(TIMESTAMP).tgz)
	@echo "# Created platform bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(PLATFORM_BITS)
	@echo ""

clean_platform:
	rm -rf $(BITS_DIR)/platform
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
	rm -rf build/docs



#---- misc targets

.PHONY: clean
clean: clean_docs

.PHONY: clean_null
clean_null:

.PHONY: distclean
distclean:
	pfexec rm -rf bits build

.PHONY: cacheclean
cacheclean: distclean
	pfexec rm -rf cache



# Upload bits we want to keep for a Jenkins build.
upload_jenkins:
	@[[ -z "$(JOB_NAME)" ]] \
		&& echo "error: JOB_NAME isn't set (is this being run under Jenkins?)" \
		&& exit 1 || true
	./tools/upload-bits "$(BRANCH)" "$(TRY_BRANCH)" "$(TIMESTAMP)" $(UPLOAD_LOCATION)/$(JOB_NAME)

# Publish the image for this Jenkins job to https://updates.joyent.us, if
# appropriate. No-op if the current JOB_NAME doesn't have a "*_publish_image"
# target.
jenkins_publish_image:
	@[[ -z "$(JOB_NAME)" ]] \
		&& echo "error: JOB_NAME isn't set (is this being run under Jenkins?)" \
		&& exit 1 || true
	@[[ -z "$(shell grep '^$(JOB_NAME)_publish_image\>' Makefile || true)" ]] \
		|| make $(JOB_NAME)_publish_image

