// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * reboot-to [normal|fastboot|maskrom]: reboot into a boot mode. The kernel's
 * reboot-mode driver stores it where U-Boot / the BootROM look:
 *   normal    normal boot (the default)
 *   fastboot  U-Boot starts fastboot on USB
 *   maskrom   the BootROM enters USB download (maskrom) mode
 */
#include <linux/reboot.h>
#include <stdio.h>
#include <string.h>
#include <sys/syscall.h>
#include <unistd.h>

static const char * const modes[] = { "normal", "fastboot", "maskrom" };

int main(int argc, char **argv)
{
	const char *mode = argc > 1 ? argv[1] : "normal";
	unsigned int i;

	for (i = 0; i < sizeof(modes) / sizeof(modes[0]); i++)
		if (!strcmp(mode, modes[i]))
			break;
	if (argc > 2 || i == sizeof(modes) / sizeof(modes[0])) {
		fprintf(stderr, "usage: %s [normal|fastboot|maskrom]\n", argv[0]);
		return 1;
	}

	sync();
	syscall(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
		LINUX_REBOOT_CMD_RESTART2, mode);
	perror("reboot");
	return 1;
}
