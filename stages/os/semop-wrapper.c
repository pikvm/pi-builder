// Stolen from https://github.com/osrf/multiarch-docker-image-generation/
//
// glibc 2.31 wraps semop() as a call to semtimedop() with the timespec set to NULL
// qemu 3.1 doesn't support semtimedop(), so this wrapper syscalls the real semop()


#include <unistd.h>
#include <asm/unistd.h>
#include <sys/syscall.h>
#include <linux/sem.h>


int semop(int semid, struct sembuf *sops, unsigned nsops) {
	return syscall(__NR_semop, semid, sops, nsops);
}
