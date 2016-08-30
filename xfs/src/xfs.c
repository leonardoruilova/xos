
/* XFS Filesystem Utility */

#include <stdio.h>
#include <string.h>	// memcpy
#include <stdlib.h>	// malloc, free
#include "xfs.h"

FILE* disk_image;
long disk_size;
const char* disk_image_name;
long partition_lba;
long partition_end;

int read_sectors(long lba, long count, void* buffer)
{
	if(lba + count > disk_size) return 1;
	if(fseek(disk_image, lba*SECTOR_SIZE, SEEK_SET) != 0) return 1;

	if(fread(buffer, SECTOR_SIZE, count, disk_image) < count) return 1;

	return 0;
}

int write_sectors(long lba, long count, void* buffer)
{
	if(lba + count > disk_size) return 1;
	if(fseek(disk_image, lba*SECTOR_SIZE, SEEK_SET) != 0) return 1;

	if(fwrite(buffer, SECTOR_SIZE, count, disk_image) < count) return 1;

	return 0;
}

int list_files()
{
	// try to open the disk image with read-only access
	disk_image = fopen(disk_image_name, "r");
	if(disk_image == NULL)
	{
		printf("%s: unable to open file for reading\n", disk_image_name);
		return -1;
	}

	fseek(disk_image, 0L, SEEK_END);
	disk_size = ftell(disk_image);
	fseek(disk_image, 0L, SEEK_SET);

	disk_size /= SECTOR_SIZE;

	if(disk_size < 8192)	// 4 mb
	{
		printf("%s: disk image is corrupt\n", disk_image_name);
		fclose(disk_image);
		return -1;
	}

	// for now, use the first primary partition as the xfs partition
	mbr_t* mbr;
	mbr = malloc(sizeof(mbr_t));
	if(mbr == NULL)
	{
		printf("Unable to allocate memory\n");
		fclose(disk_image);
		return -1;
	}

	if(read_sectors(0, 1, mbr) != 0)	
	{
		printf("Unable to read from disk image\n");
		fclose(disk_image);
		return -1;
	}

	// ensure a valid mbr
	if(mbr->boot_signature != 0xAA55)
	{
		printf("MBR missing boot signature; image may be corrupt, trying to continue...\n");
	}

	// partition start and end ;)
	partition_lba = (unsigned int)mbr->partitions[0].lba;
	partition_end = (unsigned int)mbr->partitions[0].lba + mbr->partitions[0].size;

	free(mbr);
	bootsect_t* boot_sector;
	boot_sector = malloc(sizeof(bootsect_t));
	if(boot_sector == NULL)
	{
		printf("Unable to allocate memory\n");
		fclose(disk_image);
		return -1;
	}

	// read the boot sector of the partition
	if(read_sectors(partition_lba, 1, boot_sector) != 0)
	{
		printf("Unable to read from disk image\n");
		fclose(disk_image);
		return -1;
	}

	if(boot_sector->magic_number != 0x7A658502)
	{
		printf("Filesystem is corrupt\n");
		fclose(disk_image);
		return -1;
	}

	free(boot_sector);

	// allocate a root directory :3
	root_t* root_directory;
	root_directory = malloc(sizeof(root_t));
	if(root_directory == NULL)
	{
		printf("Unable to allocate memory\n");
		fclose(disk_image);
		return -1;
	}

	if(read_sectors(partition_lba+1, 32, root_directory) != 0)
	{
		printf("Unable to read from disk image\n");
		fclose(disk_image);
		return -1;
	}

	int current_entry = 1;	// root entry :3

	printf(" FILE NAME       SIZE\n");

	char filename[9] = { 0,0,0,0,0,0,0,0,0 };
	char file_ext[4] = { 0,0,0,0 };

	while(current_entry != 512)
	{
		if(root_directory->directory[current_entry].filename[0] == ENTRY_UNUSED) goto skip;
		if(root_directory->directory[current_entry].filename[0] == ENTRY_DELETED) goto skip;

		memcpy(filename, root_directory->directory[current_entry].filename, 8);
		memcpy(file_ext, root_directory->directory[current_entry].filename+8, 3);
		printf(" %s.%s    %d", filename, file_ext, root_directory->directory[current_entry].size_bytes);

		// if bigger than 1 MB, show the size in megabytes
		if(root_directory->directory[current_entry].size_bytes > 1024*1024)
		{
			printf(" (%d MB)", root_directory->directory[current_entry].size_bytes / 1024*1024);
		} else if(root_directory->directory[current_entry].size_bytes > 1024)	// or in kilobytes ;)
		{
			printf(" (%d KB)", root_directory->directory[current_entry].size_bytes / 1024);
		}

		printf("\n");

		skip:
		current_entry++;
	}

	free(root_directory);
	fclose(disk_image);
	return 0;
}


