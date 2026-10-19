################################################################################
#
# d200-rkbin
#
################################################################################

D200_RKBIN_VERSION = $(call qstrip,$(BR2_PACKAGE_D200_RKBIN_VERSION))
D200_RKBIN_SITE = https://github.com/rockchip-linux/rkbin.git
D200_RKBIN_SITE_METHOD = git
D200_RKBIN_LICENSE = PROPRIETARY
D200_RKBIN_LICENSE_FILES = LICENSE
D200_RKBIN_INSTALL_IMAGES = YES
D200_RKBIN_INSTALL_TARGET = NO

D200_RKBIN_TPL_FILENAME = $(call qstrip,$(BR2_PACKAGE_D200_RKBIN_TPL_FILENAME))
D200_RKBIN_BL31_FILENAME = $(call qstrip,$(BR2_PACKAGE_D200_RKBIN_BL31_FILENAME))

define D200_RKBIN_INSTALL_IMAGES_CMDS
	$(INSTALL) -D -m 0644 $(@D)/$(D200_RKBIN_TPL_FILENAME) $(BINARIES_DIR)/rkbin-tpl.bin
	$(INSTALL) -D -m 0644 $(@D)/$(D200_RKBIN_BL31_FILENAME) $(BINARIES_DIR)/rkbin-bl31.elf
	$(INSTALL) -D -m 0755 $(@D)/tools/boot_merger $(HOST_DIR)/bin/boot_merger
endef

$(eval $(generic-package))
