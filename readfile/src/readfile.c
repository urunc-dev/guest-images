/*
 * Print the first line of /data/file.txt. urunc's tests run it to check that
 * the guest can read files from its rootfs.
 */
#include <stdio.h>

int main(void)
{
	char line[256];
	FILE *f;

	f = fopen("/data/file.txt", "r");
	if (!f) {
		perror("Error opening file");
		return 1;
	}
	if (!fgets(line, sizeof(line), f)) {
		perror("Error reading file");
		fclose(f);
		return 1;
	}
	printf("\n%s", line);
	fclose(f);
	return 0;
}
