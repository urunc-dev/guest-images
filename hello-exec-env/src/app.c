/*
 * Print the user and group IDs, the working directory and the URUNC
 * environment variable. urunc's tests run it to check that the container's
 * user, working directory and environment reach the guest.
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(void)
{
	char cwd[4096];
	const char *urunc;

	if (!getcwd(cwd, sizeof(cwd))) {
		perror("getcwd");
		return 1;
	}
	urunc = getenv("URUNC");
	printf("UID: %d ", (int)getuid());
	printf("GID: %d ", (int)getgid());
	printf("WD: %s ", cwd);
	printf("URUNC: %s\n", urunc ? urunc : "(null)");
	return 0;
}
