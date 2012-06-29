
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
all: smartlogin amon ca agents agentsshar assets adminui portal redis rabbitmq dhcpd webinfo billapi cloudapi workflow manatee mahi cnapi vmapi dapi napi dcapi binder mako moray registrar ufds platform usbheadnode minnow

.PHONY: all-except-platform
all-except-platform: smartlogin amon ca agents agentsshar assets adminui portal redis rabbitmq dhcpd webinfo billapi cloudapi workflow manatee mahi cnapi vmapi dapi napi dcapi binder mako registrar moray ufds usbheadnode minnow


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



#---- agents

_a_stamp=$(AGENTS_BRANCH)-$(TIMESTAMP)-g$(AGENTS_SHA)
AGENTS_BITS=$(BITS_DIR)/agents/agents_core/agents_core-$(_a_stamp).tgz \
	$(BITS_DIR)/agents/heartbeater/heartbeater-$(_a_stamp).tgz \
	$(BITS_DIR)/agents/dataset_manager/dataset_manager-$(_a_stamp).tgz \
	$(BITS_DIR)/agents/provisioner-v2/provisioner-v2-$(_a_stamp).tgz \
	$(BITS_DIR)/agents/zonetracker-v2/zonetracker-v2-$(_a_stamp).tgz
AGENTS_BITS_0=$(shell echo $(AGENTS_BITS) | awk '{print $$1}')

agents: $(AGENTS_BITS_0)

# PATH: ensure using GCC from SFW. Not sure this is necessary, but has been
# the case for release builds pre-MG.
$(AGENTS_BITS): build/agents
	@echo "# Build agents: branch $(AGENTS_BRANCH), sha $(AGENTS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/agents && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) PATH=/usr/sfw/bin:$(PATH) ./build.sh -p -l $(BITS_DIR)/agents -L)
	@echo "# Created agents bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(AGENTS_BITS)
	@echo ""

clean_agents:
	rm -rf $(BITS_DIR)/agents



#---- amon

_amon_stamp=$(AMON_BRANCH)-$(TIMESTAMP)-g$(AMON_SHA)
AMON_BITS=$(BITS_DIR)/amon/amon-pkg-$(_amon_stamp).tar.bz2 \
	$(BITS_DIR)/amon/amon-relay-$(_amon_stamp).tgz \
	$(BITS_DIR)/amon/amon-agent-$(_amon_stamp).tgz
AMON_BITS_0=$(shell echo $(AMON_BITS) | awk '{print $$1}')

.PHONY: amon
amon: $(AMON_BITS_0)

$(AMON_BITS): build/amon
	@echo "# Build amon: branch $(AMON_BRANCH), sha $(AMON_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/amon && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake clean all pkg publish)
	@echo "# Created amon bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(AMON_BITS)
	@echo ""

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

.PHONY: ca
ca: $(CA_BITS_0)

# PATH for ca build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
config_ca_old: build/cloud-analytics
	@echo "# Build ca: branch $(CLOUD_ANALYTICS_BRANCH), sha $(CLOUD_ANALYTICS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/cloud-analytics && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) PATH="/sbin:/opt/local/bin:/usr/gnu/bin:/usr/bin:/usr/sbin:$(PATH)" gmake clean pkg release publish)
	@echo "# Created ca bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(CA_BITS)
	@echo ""

#
# Build CA in the new build-zone style if requested by configure.
#
config_ca_new: build/cloud-analytics
	@echo "# Build ca: branch $(CLOUD_ANALYTICS_BRANCH), sha $(CLOUD_ANALYTICS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BRANCH=$(BRANCH) $(TOP)/tools/build-zone build.json $(TOP)/targets.json ca $(CLOUD_ANALYTICS_SHA)
	@ls -1 $(CA_BITS)
	@echo ""

# Warning: if CA's submodule deps change, this 'clean_ca' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_ca:
	rm -rf $(BITS_DIR)/ca
	(cd build/cloud-analytics && gmake clean)



#---- UFDS

_ufds_stamp=$(UFDS_BRANCH)-$(TIMESTAMP)-g$(UFDS_SHA)
UFDS_BITS=$(BITS_DIR)/ufds/ufds-pkg-$(_ufds_stamp).tar.bz2

.PHONY: ufds
ufds: $(UFDS_BITS)

# PATH for ufds build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(UFDS_BITS): build/ufds
	@echo "# Build ufds: branch $(UFDS_BRANCH), sha $(UFDS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/ufds && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake pkg release publish)
	@echo "# Created ufds bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(UFDS_BITS)
	@echo ""

# Warning: if UFDS's submodule deps change, this 'clean_ufds' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_ufds:
	rm -rf $(BITS_DIR)/ufds
	(cd build/ufds && gmake clean)

#---- BILLAPI

_billapi_stamp=$(BILLING_API_BRANCH)-$(TIMESTAMP)-g$(BILLING_API_SHA)
BILLAPI_BITS=$(BITS_DIR)/billapi/billapi-pkg-$(_billapi_stamp).tar.bz2

.PHONY: billapi
billapi: $(BILLAPI_BITS)

# PATH for ufds build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(BILLAPI_BITS): build/billing_api
	@echo "# Build billapi: branch $(BILLING_API_BRANCH), sha $(BILLING_API_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/billing_api && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake pkg release publish)
	@echo "# Created billapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(BILLAPI_BITS)
	@echo ""

# Warning: if billapi's submodule deps change, this 'clean_ufds' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_billapi:
	rm -rf $(BITS_DIR)/billapi
	(cd build/billapi && gmake clean)

#---- ASSETS

_assets_stamp=$(ASSETS_BRANCH)-$(TIMESTAMP)-g$(ASSETS_SHA)
ASSETS_BITS=$(BITS_DIR)/assets/assets-pkg-$(_assets_stamp).tar.bz2

.PHONY: assets
assets: $(ASSETS_BITS)

$(ASSETS_BITS): build/assets
	@echo "# Build assets: branch $(ASSETS_BRANCH), sha $(ASSETS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/assets && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created assets bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(ASSETS_BITS)
	@echo ""

clean_assets:
	rm -rf $(BITS_DIR)/assets
	(cd build/assets && gmake clean)

#---- ADMINUI

_adminui_stamp=$(ADMINUI_BRANCH)-$(TIMESTAMP)-g$(ADMINUI_SHA)
ADMINUI_BITS=$(BITS_DIR)/adminui/adminui-pkg-$(_adminui_stamp).tar.bz2

.PHONY: adminui
adminui: $(ADMINUI_BITS)

$(ADMINUI_BITS): build/adminui
	@echo "# Build adminui: branch $(ADMINUI_BRANCH), sha $(ADMINUI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/adminui && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created adminui bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(ADMINUI_BITS)
	@echo ""

clean_adminui:
	rm -rf $(BITS_DIR)/adminui
	(cd build/adminui && gmake clean)

#---- PORTAL

_portal_stamp=$(PORTAL_BRANCH)-$(TIMESTAMP)-g$(PORTAL_SHA)
PORTAL_BITS=$(BITS_DIR)/portal/portal-pkg-$(_portal_stamp).tar.bz2

.PHONY: portal
portal: $(PORTAL_BITS)

$(PORTAL_BITS): build/portal
	@echo "# Build portal: branch $(PORTAL_BRANCH), sha $(PORTAL_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/portal && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created portal bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(PORTAL_BITS)
	@echo ""

clean_portal:
	rm -rf $(BITS_DIR)/portal
	(cd build/portal && gmake clean)


#---- REDIS

_redis_stamp=$(REDIS_BRANCH)-$(TIMESTAMP)-g$(REDIS_SHA)
REDIS_BITS=$(BITS_DIR)/redis/redis-pkg-$(_redis_stamp).tar.bz2

.PHONY: redis
redis: $(REDIS_BITS)

$(REDIS_BITS): build/redis
	@echo "# Build redis: branch $(REDIS_BRANCH), sha $(REDIS_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/redis && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created redis bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(REDIS_BITS)
	@echo ""

clean_redis:
	rm -rf $(BITS_DIR)/redis
	(cd build/redis && gmake clean)

#---- RABBITMQ

_rabbitmq_stamp=$(RABBITMQ_BRANCH)-$(TIMESTAMP)-g$(RABBITMQ_SHA)
RABBITMQ_BITS=$(BITS_DIR)/rabbitmq/rabbitmq-pkg-$(_rabbitmq_stamp).tar.bz2

.PHONY: rabbitmq
rabbitmq: $(RABBITMQ_BITS)

$(RABBITMQ_BITS): build/rabbitmq
	@echo "# Build rabbitmq: branch $(RABBITMQ_BRANCH), sha $(RABBITMQ_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/rabbitmq && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created rabbitmq bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(RABBITMQ_BITS)
	@echo ""

clean_rabbitmq:
	rm -rf $(BITS_DIR)/rabbitmq
	(cd build/rabbitmq && gmake clean)

#---- DHCPD

_dhcpd_stamp=$(DHCPD_BRANCH)-$(TIMESTAMP)-g$(DHCPD_SHA)
DHCPD_BITS=$(BITS_DIR)/dhcpd/dhcpd-pkg-$(_dhcpd_stamp).tar.bz2

.PHONY: dhcpd
dhcpd: $(DHCPD_BITS)

$(DHCPD_BITS): build/dhcpd
	@echo "# Build dhcpd: branch $(DHCPD_BRANCH), sha $(DHCPD_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/dhcpd && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) \
		$(MAKE) release publish)
	@echo "# Created dhcpd bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(DHCPD_BITS)
	@echo ""

clean_dhcpd:
	rm -rf $(BITS_DIR)/dhcpd
	(cd build/dhcpd && gmake clean)

#---- WEBINFO

_webinfo_stamp=$(WEBINFO_BRANCH)-$(TIMESTAMP)-g$(WEBINFO_SHA)
WEBINFO_BITS=$(BITS_DIR)/webinfo/webinfo-pkg-$(_webinfo_stamp).tar.bz2

.PHONY: webinfo
webinfo: $(WEBINFO_BITS)

$(WEBINFO_BITS): build/webinfo
	@echo "# Build webinfo: branch $(WEBINFO_BRANCH), sha $(WEBINFO_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/webinfo && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created webinfo bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(WEBINFO_BITS)
	@echo ""

clean_webinfo:
	rm -rf $(BITS_DIR)/webinfo
	(cd build/webinfo && gmake clean)

#---- CLOUDAPI

_cloudapi_stamp=$(CLOUDAPI_BRANCH)-$(TIMESTAMP)-g$(CLOUDAPI_SHA)
CLOUDAPI_BITS=$(BITS_DIR)/cloudapi/cloudapi-pkg-$(_cloudapi_stamp).tar.bz2

.PHONY: cloudapi
cloudapi: $(CLOUDAPI_BITS)

# cloudapi still uses platform node, ensure that same version is first
# node (and npm) on the PATH.
$(CLOUDAPI_BITS): build/cloudapi
	@echo "# Build cloudapi: branch $(CLOUDAPI_BRANCH), sha $(CLOUDAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/cloudapi && PATH=/opt/node/0.6.12/bin:$(PATH) NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created cloudapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(CLOUDAPI_BITS)
	@echo ""

# Warning: if cloudapi's submodule deps change, this 'clean_ufds' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_cloudapi:
	rm -rf $(BITS_DIR)/cloudapi
	(cd build/cloudapi && gmake clean)


#---- MANATEE

_manatee_stamp=$(MANATEE_BRANCH)-$(TIMESTAMP)-g$(MANATEE_SHA)
MANATEE_BITS=$(BITS_DIR)/manatee/manatee-pkg-$(_manatee_stamp).tar.bz2
MANATEE_DATASET=$(BITS_DIR)/manatee/manatee-zfs-$(_manatee_stamp).zfs.bz2

.PHONY: manatee
manatee: $(MANATEE_BITS) manatee_dataset

$(MANATEE_BITS): build/manatee
	@echo "# Build manatee: branch $(MANATEE_BRANCH), sha $(MANATEE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/manatee && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created manatee bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MANATEE_BITS)
	@echo ""

.PHONY: manatee_dataset
manatee_dataset: $(MANATEE_DATASET)

$(MANATEE_DATASET): $(MANATEE_BITS)
	@echo "# Build manatee_dataset: branch $(MANATEE_BRANCH), sha $(MANATEE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -t $(MANATEE_BITS) -o $(MANATEE_DATASET) -p $(MANATEE_PKGSRC) -t $(MANATEE_EXTRA_TARBALLS) -u $(MANATEE_URN) -v $(MANATEE_VERSION)
	@echo "# Created manatee dataset (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MANATEE_DATASET)
	@echo ""

clean_manatee:
	rm -rf $(BITS_DIR)/manatee
	(cd build/manatee && gmake distclean)

#---- WORKFLOW

_wf_stamp=$(WORKFLOW_BRANCH)-$(TIMESTAMP)-g$(WORKFLOW_SHA)
WORKFLOW_BITS=$(BITS_DIR)/workflow/workflow-pkg-$(_wf_stamp).tar.bz2

.PHONY: workflow
workflow: $(WORKFLOW_BITS)

# PATH for workflow build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(WORKFLOW_BITS): build/workflow
	@echo "# Build workflow: branch $(WORKFLOW_BRANCH), sha $(WORKFLOW_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/workflow && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created workflow bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(WORKFLOW_BITS)
	@echo ""

# Warning: if workflow's submodule deps change, this 'clean_workflow' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_workflow:
	rm -rf $(BITS_DIR)/workflow
	(cd build/workflow && gmake clean)


#---- VMAPI

_vmapi_stamp=$(VMAPI_BRANCH)-$(TIMESTAMP)-g$(VMAPI_SHA)
VMAPI_BITS=$(BITS_DIR)/vmapi/vmapi-pkg-$(_vmapi_stamp).tar.bz2

.PHONY: vmapi
vmapi: $(VMAPI_BITS)

# PATH for vmapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(VMAPI_BITS): build/vmapi
	@echo "# Build vmapi: branch $(VMAPI_BRANCH), sha $(VMAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/vmapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created vmapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(VMAPI_BITS)
	@echo ""

# Warning: if vmapi's submodule deps change, this 'clean_vmapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_vmapi:
	rm -rf $(BITS_DIR)/vmapi
	(cd build/vmapi && gmake clean)


#---- DAPI

_dapi_stamp=$(DAPI_BRANCH)-$(TIMESTAMP)-g$(DAPI_SHA)
DAPI_BITS=$(BITS_DIR)/dapi/dapi-pkg-$(_dapi_stamp).tar.bz2

.PHONY: dapi
dapi: $(DAPI_BITS)

# PATH for dapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(DAPI_BITS): build/dapi
	@echo "# Build dapi: branch $(DAPI_BRANCH), sha $(DAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/dapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created dapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(DAPI_BITS)
	@echo ""

# Warning: if dapi's submodule deps change, this 'clean_dapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_dapi:
	rm -rf $(BITS_DIR)/dapi
	(cd build/dapi && gmake clean)


#---- CNAPI

_cnapi_stamp=$(CNAPI_BRANCH)-$(TIMESTAMP)-g$(CNAPI_SHA)
CNAPI_BITS=$(BITS_DIR)/cnapi/cnapi-pkg-$(_cnapi_stamp).tar.bz2

.PHONY: cnapi
cnapi: $(CNAPI_BITS)

# PATH for cnapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(CNAPI_BITS): build/cnapi
	@echo "# Build cnapi: branch $(CNAPI_BRANCH), sha $(CNAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/cnapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created cnapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(CNAPI_BITS)
	@echo ""

# Warning: if cnapi's submodule deps change, this 'clean_cnapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_cnapi:
	rm -rf $(BITS_DIR)/cnapi
	(cd build/cnapi && gmake clean)




#---- NAPI

_napi_stamp=$(NAPI_BRANCH)-$(TIMESTAMP)-g$(NAPI_SHA)
NAPI_BITS=$(BITS_DIR)/napi/napi-pkg-$(_napi_stamp).tar.bz2

.PHONY: napi
napi: $(NAPI_BITS)

# PATH for napi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(NAPI_BITS): build/napi
	@echo "# Build napi: branch $(NAPI_BRANCH), sha $(NAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/napi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake pkg release publish)
	@echo "# Created napi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(NAPI_BITS)
	@echo ""

# Warning: if NAPI's submodule deps change, this 'clean_napi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_napi:
	rm -rf $(BITS_DIR)/napi
	(cd build/napi && gmake clean)


#---- Marlin

_marlin_stamp=$(MARLIN_BRANCH)-$(TIMESTAMP)-g$(MARLIN_SHA)
MARLIN_BITS=$(BITS_DIR)/marlin/marlin-pkg-$(_marlin_stamp).tar.bz2
MARLIN_DATASET=$(BITS_DIR)/marlin/marlin-zfs-$(_marlin_stamp).zfs.bz2

.PHONY: marlin
marlin: $(MARLIN_BITS) marlin_dataset

# PATH for marlin build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(MARLIN_BITS): build/marlin
	@echo "# Build marlin: branch $(MARLIN_BRANCH), sha $(MARLIN_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/marlin && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created marlin bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MARLIN_BITS)
	@echo ""

.PHONY: marlin_dataset
marlin_dataset: $(MARLIN_DATASET)

$(MARLIN_DATASET): $(MARLIN_BITS)
	@echo "# Build marlin_dataset: branch $(MARLIN_BRANCH), sha $(MARLIN_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -t $(MARLIN_BITS) -o $(MARLIN_DATASET) -p $(MARLIN_PKGSRC) -t $(MARLIN_EXTRA_TARBALLS) -u $(MARLIN_URN) -v $(MARLIN_VERSION)
	@echo "# Created marlin dataset (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MARLIN_DATASET)
	@echo ""

clean_marlin:
	rm -rf $(BITS_DIR)/marlin
	(cd build/marlin && gmake distclean)


#---- MAHI

_mahi_stamp=$(MAHI_BRANCH)-$(TIMESTAMP)-g$(MAHI_SHA)
MAHI_BITS=$(BITS_DIR)/mahi/mahi-pkg-$(_mahi_stamp).tar.bz2
MAHI_DATASET=$(BITS_DIR)/mahi/mahi-zfs-$(_mahi_stamp).zfs.bz2

.PHONY: mahi
mahi: $(MAHI_BITS) mahi_dataset

$(MAHI_BITS): build/mahi
	@echo "# Build mahi: branch $(MAHI_BRANCH), sha $(MAHI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/mahi && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created mahi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MAHI_BITS)
	@echo ""

.PHONY: mahi_dataset
mahi_dataset: $(MAHI_DATASET)

$(MAHI_DATASET): $(MAHI_BITS)
	@echo "# Build mahi_dataset: branch $(MAHI_BRANCH), sha $(MAHI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -t $(MAHI_BITS) -o $(MAHI_DATASET) -p $(MAHI_PKGSRC) -t $(MAHI_EXTRA_TARBALLS) -u $(MAHI_URN) -v $(MAHI_VERSION)
	@echo "# Created mahi dataset (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MAHI_DATASET)
	@echo ""

clean_mahi:
	rm -rf $(BITS_DIR)/mahi
	(cd build/mahi && gmake distclean)


#---- Moray

_moray_stamp=$(MORAY_BRANCH)-$(TIMESTAMP)-g$(MORAY_SHA)
MORAY_BITS=$(BITS_DIR)/moray/moray-pkg-$(_moray_stamp).tar.bz2
MORAY_DATASET=$(BITS_DIR)/moray/moray-zfs-$(_moray_stamp).zfs.bz2

.PHONY: moray
moray: $(MORAY_BITS) moray_dataset

# PATH for moray build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(MORAY_BITS): build/moray
	@echo "# Build moray: branch $(MORAY_BRANCH), sha $(MORAY_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/moray && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created moray bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MORAY_BITS)
	@echo ""

.PHONY: moray_dataset
moray_dataset: $(MORAY_DATASET)

$(MORAY_DATASET): $(MORAY_BITS)
	@echo "# Build moray_dataset: branch $(MORAY_BRANCH), sha $(MORAY_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -t $(MORAY_BITS) -o $(MORAY_DATASET) -p $(MORAY_PKGSRC) -t $(MORAY_EXTRA_TARBALLS) -u $(MORAY_URN) -v $(MORAY_VERSION)
	@echo "# Created moray dataset (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MORAY_DATASET)
	@echo ""

clean_moray:
	rm -rf $(BITS_DIR)/moray
	(cd build/moray && gmake distclean)


#---- Muskie

_muskie_stamp=$(MUSKIE_BRANCH)-$(TIMESTAMP)-g$(MUSKIE_SHA)
MUSKIE_BITS=$(BITS_DIR)/muskie/muskie-pkg-$(_muskie_stamp).tar.bz2
MUSKIE_DATASET=$(BITS_DIR)/muskie/muskie-zfs-$(_muskie_stamp).zfs.bz2

.PHONY: muskie
muskie: $(MUSKIE_BITS) muskie_dataset

# PATH for muskie build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(MUSKIE_BITS): build/muskie
	@echo "# Build muskie: branch $(MUSKIE_BRANCH), sha $(MUSKIE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/muskie && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created muskie bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MUSKIE_BITS)
	@echo ""

.PHONY: muskie_dataset
muskie_dataset: $(MUSKIE_DATASET)

$(MUSKIE_DATASET): $(MUSKIE_BITS)
	@echo "# Build muskie_dataset: branch $(MUSKIE_BRANCH), sha $(MUSKIE_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -t $(MUSKIE_BITS) -o $(MUSKIE_DATASET) -p $(MUSKIE_PKGSRC) -t $(MUSKIE_EXTRA_TARBALLS) -u $(MUSKIE_URN) -v $(MUSKIE_VERSION)
	@echo "# Created muskie dataset (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MUSKIE_DATASET)
	@echo ""

clean_muskie:
	rm -rf $(BITS_DIR)/muskie
	(cd build/muskie && gmake distclean)


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

#---- Binder

_binder_stamp=$(BINDER_BRANCH)-$(TIMESTAMP)-g$(BINDER_SHA)
BINDER_BITS=$(BITS_DIR)/binder/binder-pkg-$(_binder_stamp).tar.bz2
BINDER_DATASET=$(BITS_DIR)/binder/binder-zfs-$(_binder_stamp).zfs.bz2

.PHONY: binder
binder: $(BINDER_BITS) binder_dataset

$(BINDER_BITS): build/binder
	@echo "# Build binder: branch $(BINDER_BRANCH), sha $(BINDER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/binder && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created binder bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(BINDER_BITS)
	@echo ""

.PHONY: binder_dataset
binder_dataset: $(BINDER_DATASET)

$(BINDER_DATASET): $(BINDER_BITS)
	@echo "# Build binder_dataset: branch $(BINDER_BRANCH), sha $(BINDER_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -t $(BINDER_BITS) -o $(BINDER_DATASET) -p $(BINDER_PKGSRC) -u $(BINDER_URN) -v $(BINDER_VERSION)
	@echo "# Created binder dataset (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(BINDER_DATASET)
	@echo ""

clean_binder:
	rm -rf $(BITS_DIR)/binder
	(cd build/binder && gmake distclean)

#---- Muppet

_muppet_stamp=$(MUPPET_BRANCH)-$(TIMESTAMP)-g$(MUPPET_SHA)
MUPPET_BITS=$(BITS_DIR)/muppet/muppet-pkg-$(_muppet_stamp).tar.bz2
MUPPET_DATASET=$(BITS_DIR)/muppet/muppet-zfs-$(_muppet_stamp).zfs.bz2

.PHONY: muppet
muppet: $(MUPPET_BITS) muppet_dataset

$(MUPPET_BITS): build/muppet
	@echo "# Build muppet: branch $(MUPPET_BRANCH), sha $(MUPPET_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/muppet && LDFLAGS="-L/opt/local/lib -R/opt/local/lib" NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created muppet bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MUPPET_BITS)
	@echo ""

.PHONY: muppet_dataset
muppet_dataset: $(MUPPET_DATASET)

$(MUPPET_DATASET): $(MUPPET_BITS)
	@echo "# Build muppet_dataset: branch $(MUPPET_BRANCH), sha $(MUPPET_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -t $(MUPPET_BITS) -o $(MUPPET_DATASET) -p $(MUPPET_PKGSRC) -t $(MUPPET_EXTRA_TARBALLS) -u $(MUPPET_URN) -v $(MUPPET_VERSION)
	@echo "# Created muppet dataset (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MUPPET_DATASET)
	@echo ""

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
MAKO_DATASET=$(BITS_DIR)/mako/mako-zfs-$(_mako_stamp).zfs.bz2

.PHONY: mako
mako: $(MAKO_BITS) mako_dataset

$(MAKO_BITS): build/mako
	@echo "# Build mako: branch $(MAKO_BRANCH), sha $(MAKO_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/mako && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created mako bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MAKO_BITS)
	@echo ""

.PHONY: mako_dataset
mako_dataset: $(MAKO_DATASET)

$(MAKO_DATASET): $(MAKO_BITS)
	@echo "# Build mako dataset: branch $(MAKO_BRANCH), sha $(MAKO_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	./tools/prep_dataset.sh -t $(MAKO_BITS) -o $(MAKO_DATASET) -p $(MAKO_PKGSRC) -t $(MAKO_EXTRA_TARBALLS) -u $(MAKO_URN) -v $(MAKO_VERSION)
	@echo "# Created mako dataset (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(MAKO_DATASET)
	@echo ""

clean_mako:
	rm -rf $(BITS_DIR)/mako
	(cd build/mako && gmake distclean)

#---- DCAPI

_dcapi_stamp=$(DCAPI_BRANCH)-$(TIMESTAMP)-g$(DCAPI_SHA)
DCAPI_BITS=$(BITS_DIR)/dcapi/dcapi-pkg-$(_dcapi_stamp).tar.bz2

.PHONY: dcapi
dcapi: $(DCAPI_BITS)

# PATH for dcapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(DCAPI_BITS): build/dcapi
	@echo "# Build dcapi: branch $(DCAPI_BRANCH), sha $(DCAPI_SHA), time `date -u +%Y%m%dT%H%M%SZ`"
	mkdir -p $(BITS_DIR)
	(cd build/dcapi && NPM_CONFIG_CACHE=$(MG_CACHE_DIR)/npm NODE_PREBUILT_DIR=$(BITS_DIR)/sdcnode TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created dcapi bits (time `date -u +%Y%m%dT%H%M%SZ`):"
	@ls -1 $(DCAPI_BITS)
	@echo ""

# Warning: if DCAPI's submodule deps change, this 'clean_dcapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_dcapi:
	rm -rf $(BITS_DIR)/dcapi
	(cd build/dcapi && gmake clean)


#---- agents shar

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

PLATFORM_BITS=$(BITS_DIR)/platform/platform-$(SMARTOS_LIVE_BRANCH)-$(TIMESTAMP).tgz
PLATFORM_BITS_0=$(shell echo $(PLATFORM_BITS) | awk '{print $$1}')

.PHONY: platform
platform: $(PLATFORM_BITS_0)

build/smartos-live/configure.mg:
	sed -e "s/BRANCH/$(SMARTOS_LIVE_BRANCH)/" -e "s:GITCLONESOURCE:$(shell pwd)/build/:" <illumos-configure.tmpl >build/smartos-live/configure.mg

build/smartos-live/configure-branches:
	sed -e "s/BRANCH/$(SMARTOS_LIVE_BRANCH)/" <illumos-configure-branches.tmpl >build/smartos-live/configure-branches

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

include bits/config.targ.mk
