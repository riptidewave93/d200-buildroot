################################################################################
#
# d200-utils: small tools for the Ulanzi D200 (sources in src/)
#
################################################################################

D200_UTILS_VERSION = 1.0
D200_UTILS_SITE = $(BR2_EXTERNAL_D200_BUILDROOT_PATH)/package/d200-utils/src
D200_UTILS_SITE_METHOD = local
D200_UTILS_LICENSE = GPL-2.0+

define D200_UTILS_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -o $(@D)/reboot-to $(@D)/reboot-to.c
endef

define D200_UTILS_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/reboot-to $(TARGET_DIR)/usr/sbin/reboot-to
endef

$(eval $(generic-package))
