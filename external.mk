include $(sort $(wildcard $(BR2_EXTERNAL_D200_BUILDROOT_PATH)/package/*/*.mk))

# U-Boot needs the rkbin blobs (BL31, DDR TPL) from d200-rkbin. external.mk is
# parsed after U-Boot's package definition, so order it with a stamp-file
# prerequisite instead of UBOOT_DEPENDENCIES.
ifeq ($(BR2_TARGET_UBOOT)$(BR2_PACKAGE_D200_RKBIN),yy)
$(UBOOT_TARGET_CONFIGURE): $(D200_RKBIN_TARGET_INSTALL_IMAGES)
endif

# The last commit that changed any of the paths in $(1), as a Unix time; the
# Buildroot release date without git history
d200-epoch = $(or $(shell git -C $(BR2_EXTERNAL_D200_BUILDROOT_PATH) log -1 \
	--format=%ct -- $(1) 2>/dev/null),$(BR2_VERSION_EPOCH))
ifeq ($(shell git -C $(BR2_EXTERNAL_D200_BUILDROOT_PATH) rev-parse 2>/dev/null && echo y),)
$(warning No git history: U-Boot and the kernel are dated by Buildroot instead, so updates rewrite the bootloader once)
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
D200_UBOOT_EPOCH := $(call d200-epoch,$(D200_UBOOT_INPUTS))
UBOOT_MAKE_OPTS += SOURCE_DATE_EPOCH=$(D200_UBOOT_EPOCH)
endif

# Reproducible kernel, the same way: kernel.itb only changes with the kernel
D200_LINUX_INPUTS = board/ulanzi/d200/patches/linux board/ulanzi/d200/linux.config \
	board/ulanzi/d200/kernel.its
export D200_LINUX_EPOCH := $(call d200-epoch,$(D200_LINUX_INPUTS))
LINUX_MAKE_ENV += \
	KBUILD_BUILD_VERSION=1 \
	KBUILD_BUILD_USER=d200 \
	KBUILD_BUILD_HOST=d200 \
	KBUILD_BUILD_TIMESTAMP="$(shell LC_ALL=C date -u -d @$(D200_LINUX_EPOCH))"
