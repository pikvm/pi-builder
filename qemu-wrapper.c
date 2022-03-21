#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv, char **envp) {
    char *new[argc + 3];
    new[0] = argv[0];
    new[1] = "-B";
    new[2] = "0x20000"; /* here you can set the cpu you are building for */
    memcpy(&new[3], &argv[1], sizeof(*argv) * (argc - 1));
    new[argc + 2] = NULL;

    int retval = execve("/usr/bin/qemu-" QEMU_ARCH "-static-orig", new, envp);
	if (retval != 0) {
		perror("Can't execve(/usr/bin/qemu-" QEMU_ARCH "-static-orig)");
	}
	return retval;
}
