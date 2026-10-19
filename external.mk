include $(sort $(wildcard $(BR2_EXTERNAL_D200_BUILDROOT_PATH)/package/*/*.mk))

# U-Boot needs the rkbin blobs (BL31, DDR TPL) from d200-rkbin. external.mk is
# parsed after U-Boot's package definition, so order it with a stamp-file
# prerequisite instead of UBOOT_DEPENDENCIES.
ifeq ($(BR2_TARGET_UBOOT)$(BR2_PACKAGE_D200_RKBIN),yy)
$(UBOOT_TARGET_CONFIGURE): $(D200_RKBIN_TARGET_INSTALL_IMAGES)
endif

# Boot screens: binary files can't go through the patch series, so drop the
# D200 boot logo ("Booting..." in the large key, "Hold for Fastboot" in the
# top-left key) and the fastboot screen into the U-Boot tree here.
D200_LOGO_DIR = $(BR2_EXTERNAL_D200_BUILDROOT_PATH)/board/ulanzi/d200/logo
ifeq ($(BR2_TARGET_UBOOT),y)
define D200_UBOOT_INSTALL_LOGO
	$(INSTALL) -m 0644 $(D200_LOGO_DIR)/d200-boot-logo.bmp $(@D)/drivers/video/u_boot_logo.bmp
	$(INSTALL) -m 0644 $(D200_LOGO_DIR)/d200-fastboot.bmp $(@D)/board/ulanzi/d200/d200_fastboot.bmp
endef
UBOOT_POST_PATCH_HOOKS += D200_UBOOT_INSTALL_LOGO

# Reproducible U-Boot: its build date is the last commit that changed one of
# its inputs here, so a rebuild without U-Boot changes gives the same images
# and an update skips the bootloader (docs/ota.md)
D200_UBOOT_INPUTS = board/ulanzi/d200/patches/uboot board/ulanzi/d200/logo \
	board/ulanzi/d200/uboot-release.fragment package/d200-rkbin
D200_UBOOT_EPOCH := $(shell git -C $(BR2_EXTERNAL_D200_BUILDROOT_PATH) log -1 \
	--format=%ct -- $(D200_UBOOT_INPUTS) 2>/dev/null)
ifeq ($(D200_UBOOT_EPOCH),)
$(warning No git history: U-Boot is dated by Buildroot instead, so updates rewrite the bootloader once)
endif
UBOOT_MAKE_OPTS += SOURCE_DATE_EPOCH=$(or $(D200_UBOOT_EPOCH),$(BR2_VERSION_EPOCH))
endif
