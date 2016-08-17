
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

; struct file {
; u32 flags;		// 00
; u32 position;		// 04
; u8 filename[12];	// 08
; u8 reserved[12];	// 14
; }
;
;
; sizeof(file) = 0x20;
;

FILE_FLAGS		= 0x00
FILE_POSITION		= 0x04
FILE_NAME		= 0x08
FILE_RESERVED		= 0x14
FILE_HANDLE_SIZE	= 0x20

; Max no. of files the kernel can handle
MAXIMUM_FILE_HANDLES	= 32		; increase this in the future

; File Flags
FILE_PRESENT		= 0x00000001
FILE_WRITE		= 0x00000002
FILE_READ		= 0x00000004

file_handles		dd 0
open_files		dd 0

; xfs_detect:
; Detects the xFS filesystem

xfs_detect:
	ret

.starting_msg		db "Detecting XFS partition on boot device...",10,0



