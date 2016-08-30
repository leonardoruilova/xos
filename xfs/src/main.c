
/* XFS Filesystem Utility */

#include <stdio.h>
#include "xfs.h"

int main(int argc, char* argv[])
{
	if(argc < 3)
	{
		printf("Usage: %s [disk_image] [command] [filename]\n", argv[0]);
		printf("Defined commands: \n");
		printf(" add       - Adds [filename] to the disk image.\n");
		printf(" list      - Lists files on the disk image.\n");
		printf(" rm        - Removes [filename] from the disk image.\n");
		return -1;
	}

	disk_image_name = argv[1];

	if(strcmp(argv[2], "list") == 0) return list_files();

	printf("Undefined command: %s\n", argv[2]);
	return -1;
}


