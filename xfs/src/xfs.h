
/* XFS Filesystem Utility */

#ifndef __XFS_H
#define __XFS_H

#include <stdio.h>

#define SECTOR_SIZE		512	// for HDDs
#define XFS_MBR_ID		0xF3	// for mbr partition table

#define ENTRY_DELETED		0xF0	// indicates the entry contains a deleted file
#define ENTRY_UNUSED		0x00	// indicates entry is unused

// Prototype
extern FILE* disk_image;
extern long disk_size;
extern const char* disk_image_name;
extern long partition_lba;
extern long partition_end;

// Typedefs...
typedef struct partition_t
{
	unsigned char active;
	char chs[3];
	unsigned char type;		// 0xF3 for XFS
	char end_chs[3];
	unsigned int lba;
	unsigned int size;
} __attribute__((packed)) partition_t;

// Master Boot Record
typedef struct mbr_t
{
	unsigned char bootcode[446];
	partition_t partitions[4];
	unsigned short boot_signature;	// 0xAA55
} __attribute__((packed)) mbr_t;

// Boot Sector
typedef struct bootsect_t
{
	unsigned char bootcode1[3];	// jmp short 0x28; nop;
	char formatting_tool_name[8];	// 'MKXFS   '
	char formatting_tool_version;
	unsigned int magic_number;	// 0x7A658502
	unsigned short formatting_time;
	unsigned short formatting_date;
	unsigned short formatting_year;
	unsigned int serial_number;
	char volume_label[8];
	char filesystem_id[8];		// 'XFS     '

	unsigned char bootcode2[468];
	unsigned short boot_signature;	// 0xAA55
} __attribute__((packed)) bootsect_t;

// Directory Entry
typedef struct directory_t
{
	char filename[11];
	char reserved1;
	unsigned int lba;
	unsigned int size_sectors;
	unsigned int size_bytes;
	unsigned short time;
	unsigned short date;
	unsigned short year;
	short reserved2;
} __attribute__((packed)) directory_t;

// Root Directory
typedef struct root_t
{
	directory_t directory[512];
} __attribute__((packed)) root_t;

// Function Prototypes
extern int read_sectors(long lba, long count, void* buffer);
extern int write_sectors(long lba, long count, void* buffer);
extern int list_files();

#endif		// __XFS_H


