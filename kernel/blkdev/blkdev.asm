
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

;
; struct blkdev {
; u8 device_type;		// 00
; u8 device_content;		// 01
; u32 address;			// 02
; u16 padding;			// 06
; };
;
;
; sizeof(blkdev) = 8;
;

BLKDEV_DEVICE_TYPE		= 0x00
BLKDEV_DEVICE_CONTENT		= 0x01
BLKDEV_ADDRESS			= 0x02
BLKDEV_PADDING			= 0x06
BLKDEV_SIZE			= 0x08

; System can manage up to 64 block devices
MAXIMUM_BLKDEVS			= 64

; Device Type
BLKDEV_UNPRESENT		= 0
BLKDEV_ATA			= 1
BLKDEV_AHCI			= 2
BLKDEV_RAMDISK			= 3

; Device Content
BLKDEV_FLAT			= 0
BLKDEV_PARTITIONED		= 1

align 4
blkdev_structure		dd 0
blkdevs				dd 0	; number of block devices on the system
boot_device			dd 0

; blkdev_init:
; Detects and initializes block devices

blkdev_init:
	mov ecx, MAXIMUM_BLKDEVS*BLKDEV_SIZE
	call kmalloc
	mov [blkdev_structure], eax

	; detect devices ;)
	call ata_detect
	call ahci_detect
	;call usb_mass_detect

	; determine the boot device
	; allocate a temporary buffer 512 bytes to read the MBR of each device present
	; then search for the partition entry which we booted from
	; it's very unlikely two disks on the same system have identical partitions ;)
	mov ecx, 512
	call kmalloc
	mov [.tmp_buffer], eax

.loop:
	mov ebx, [.current_device]
	cmp ebx, [blkdevs]
	jge .no_bootdev

	xor edx, edx	; lba sector 0, this function uses edx:eax to support 48-bit LBA
	xor eax, eax
	mov ecx, 1
	mov edi, [.tmp_buffer]
	call blkdev_read

	cmp al, 0
	je .check_device

.next:
	inc [.current_device]
	jmp .loop

.check_device:
	; scan the device's partition table for the boot partition
	mov esi, [.tmp_buffer]
	add esi, 0x1BE

	mov ecx, 4		; 4 partitions per mbr

.check_loop:
	push ecx
	mov edi, boot_partition
	mov ecx, 16
	rep cmpsb
	je .found_boot_device

	pop ecx
	loop .check_loop
	jmp .next

.found_boot_device:
	pop ecx

	; save the boot device
	mov eax, [.current_device]
	mov [boot_device], eax

	mov esi, .bootdev_msg
	call kprint
	mov eax, [boot_device]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	; and fly!
	mov eax, [.tmp_buffer]
	call kfree
	ret

.no_bootdev:
	mov esi, .no_bootdev_msg
	jmp early_boot_error

.tmp_buffer			dd 0
.current_device			dd 0
.bootdev_msg			db "Boot device is logical device ",0
.no_bootdev_msg			db "Unable to determine the boot device.",10,0

; blkdev_register:
; Registers a device
; In\	AL = Device type
; In\	AH = Device content (partitioned/flat?)
; In\	EDX = Address
; Out\	EDX = Device number

blkdev_register:
	mov [.type], al

	mov edi, [blkdevs]
	shl edi, 3		; mul 8
	add edi, [blkdev_structure]
	mov [edi+BLKDEV_DEVICE_TYPE], al
	mov [edi+BLKDEV_DEVICE_CONTENT], ah
	mov [edi+BLKDEV_ADDRESS], edx
	mov word[edi+6], 0

	mov esi, .msg
	call kprint

	mov al, [.type]
	cmp al, BLKDEV_ATA
	je .ata
	cmp al, BLKDEV_AHCI
	je .ahci
	cmp al, BLKDEV_RAMDISK
	je .ramdisk

.undefined:
	mov esi, .undefined_msg
	call kprint
	jmp .done

.ata:
	mov esi, .ata_msg
	call kprint
	jmp .done

.ahci:
	mov esi, .ahci_msg
	call kprint
	jmp .done

.ramdisk:
	mov esi, .ramdisk_msg
	call kprint

.done:
	mov esi, .msg2
	call kprint
	mov eax, [blkdevs]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	mov edx, [blkdevs]
	inc [blkdevs]
	ret

.type			db 0
.msg			db "Registered ",0
.ata_msg		db "ATA device",0
.ahci_msg		db "AHCI device",0
.ramdisk_msg		db "ramdisk device",0
.undefined_msg		db "undefined device",0
.msg2			db ", device number ",0

; blkdev_read:
; Reads from a block device
; In\	EDX:EAX	= LBA sector
; In\	ECX = Sector count
; In\	EBX = Drive number
; In\	EDI = Buffer to read sectors
; Out\	AL = 0 on success, 1 on error
; Out\	AH = Device status (for ATA and AHCI, at least)
align 32
blkdev_read:
	cmp ebx, [blkdevs]	; can't read from a non existant drive
	jge .fail

	shl ebx, 3
	add ebx, [blkdev_structure]

	; give control to device-specific code
	cmp byte[ebx], BLKDEV_ATA
	je .ata

	cmp byte[ebx], BLKDEV_AHCI
	je .ahci

	;cmp byte[ebx], BLKDEV_RAMDISK
	;je .ramdisk

	jmp .fail

.ata:
	mov bl, [ebx+BLKDEV_ADDRESS]
	call ata_read
	ret

.ahci:
	mov bl, [ebx+BLKDEV_ADDRESS]	; ahci port
	call ahci_read
	ret

.fail:
	mov al, 1
	mov ah, -1
	ret




