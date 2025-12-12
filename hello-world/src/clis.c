/*
 * Print the command line arguments, separated by spaces. urunc's tests run it
 * to check that the command reaches the guest.
 */
#include <stdio.h>

int main(int argc, char *argv[])
{
	for (int i = 1; i < argc; i++)
		printf("%s ", argv[i]);
	printf("\n");
	return 0;
}
