
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad, all rights reserved.

use32

; AHCI ABAR Structure
AHCI_ABAR_CAP			= 0x0000
AHCI_ABAR_HOST_CONTROL		= 0x0004
AHCI_ABAR_INTERRUPT_STATUS	= 0x0008
AHCI_ABAR_PORTS			= 0x000C
AHCI_ABAR_VERSION		= 0x0010
AHCI_ABAR_COMMAND_CONTROL	= 0x0014
AHCI_ABAR_COMMAND_PORTS		= 0x0018
AHCI_ABAR_ENCLOSURE_LOCATION	= 0x001C
AHCI_ABAR_ENCLOSURE_CONTROL	= 0x0020
AHCI_ABAR_HOST_CAP		= 0x0024
AHCI_ABAR_HANDOFF		= 0x0028
AHCI_ABAR_RESERVED		= 0x002C
AHCI_ABAR_VENDOR_SPECIFIC	= 0x00A0
AHCI_ABAR_PORT_CONTROL		= 0x0100

; AHCI Port Structure
AHCI_PORT_COMMAND_LIST		= 0x0000
AHCI_PORT_FIS			= 0x0008
AHCI_PORT_IRQ_STATUS		= 0x0010
AHCI_PORT_IRQ_ENABLE		= 0x0014
AHCI_PORT_COMMAND		= 0x0018
AHCI_PORT_RESERVED0		= 0x001C
AHCI_PORT_TASK_FILE		= 0x0020
AHCI_PORT_SIGNATURE		= 0x0024
AHCI_PORT_SATA_STATUS		= 0x0028
AHCI_PORT_SATA_CONTROL		= 0x002C
AHCI_PORT_SATA_ERROR		= 0x0030
AHCI_PORT_SATA_ACTIVE		= 0x0034
AHCI_PORT_COMMAND_ISSUE		= 0x0038
AHCI_PORT_SATA_NOTIFICATION	= 0x003C
AHCI_PORT_FIS_CONTROL		= 0x0040
AHCI_PORT_RESERVED1		= 0x0044
AHCI_PORT_VENDOR_SPECIFIC	= 0x0070

; Command Set
SATA_IDENTIFY			= 0xEC
SATA_READ_LBA28			= 0x20
SATA_READ_LBA48			= 0x24
SATA_WRITE_LBA28		= 0x30
SATA_WRITE_LBA48		= 0x34

pci_ahci_bus			db 0
pci_ahci_dev			db 0
pci_ahci_function		db 0

align 4
ahci_abar			dd 0
;ahci_port_count		db 0	; counts how many ports are present

; ahci_detect:
; Detects AHCI devices

ahci_detect:
	mov ax, 0x0106		; ahci controller
	call pci_get_device_class

	mov [pci_ahci_bus], al
	mov [pci_ahci_dev], ah
	mov [pci_ahci_function], bl

	cmp [pci_ahci_bus], 0xFF
	je .no_ahci

	; debugging output
	mov esi, .pci_msg
	call kprint
	mov al, [pci_ahci_bus]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [pci_ahci_dev]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [pci_ahci_function]
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

	; let the device respond to MMIO access and perform DMA
	mov al, [pci_ahci_bus]
	mov ah, [pci_ahci_dev]
	mov bl, [pci_ahci_function]
	mov bh, PCI_STATUS_COMMAND
	call pci_read_dword

	mov edx, eax
	or edx, 6	; bus master | MMIO
	;call pci_write_dword

	; map the ahci abar to virtual memory
	mov al, [pci_ahci_bus]
	mov ah, [pci_ahci_dev]
	mov bl, [pci_ahci_function]
	mov dl, 5		; bar5
	call pci_map_memory
	cmp eax, 0
	je .no_memory
	mov [ahci_abar], eax

	call ahci_do_handoff		; tell the bios to let go of the ahci controller
					; QEMU and VBox don't support this; but maybe some real HW need it?
	call ahci_detect_devices	; detect ahci devices

	ret

.no_ahci:
	mov esi, .no_ahci_msg
	call kprint
	ret

.no_memory:
	mov esi, .no_memory_msg
	call kprint
	ret

.pci_msg			db "AHCI controller at PCI slot ",0
.colon				db ":",0
.no_ahci_msg			db "PCI AHCI controller not present.",10,0
.no_memory_msg			db "Failed to map AHCI ABAR in memory.",10,0

; ahci_do_handoff:
; Performs the BIOS handoff on the AHCI controller

ahci_do_handoff:
	mov eax, [ahci_abar]
	add eax, AHCI_ABAR_HOST_CAP
	mov eax, [eax]

	test eax, 1			; controller supports BIOS handoff?
	jz .no_handoff

	; if the controller supports handoff, check if the handoff has already been done
	mov eax, [ahci_abar]
	add eax, AHCI_ABAR_HANDOFF
	mov edx, [eax]

	test edx, 2
	jnz .already_handoff

	mov edx, 2
	mov [eax], edx		; request bios handoff

	mov ecx, 100000		; use this as a timeout

.wait_for_bios:
	mov edx, [eax]
	test edx, 0x10		; BIOS busy?
	jz .check

	pause

	loop .wait_for_bios
	jmp .timeout

.check:
	mov edx, [eax]
	test edx, 2
	jz .fail

	mov esi, .done_msg
	call kprint
	ret

.timeout:
	mov esi, .timeout_msg
	call kprint
	mov esi, .still_trying_msg
	call kprint
	ret

.fail:
	mov esi, .fail_msg
	call kprint
	mov esi, .still_trying_msg
	call kprint
	ret

.already_handoff:
	mov esi, .already_handoff_msg
	call kprint
	ret

.no_handoff:
	mov esi, .no_handoff_msg
	call kprint
	ret

.no_handoff_msg			db "AHCI handoff not supported.",10,0
.done_msg			db "AHCI handoff succeeded.",10,0
.already_handoff_msg		db "AHCI handoff already pre-configured.",10,0
.timeout_msg			db "AHCI handoff failed: operation timed out.",10,0
.fail_msg			db "AHCI handoff failed: controller is not responding, firmware bug maybe?",10,0
.still_trying_msg		db "Going to try to initialize AHCI anyway...",10,0

; ahci_check_port:
; Checks precense of an AHCI port
; In\	DL = Port number
; Out\	EFLAGS.CF = 0 if port is present
; Out\	EAX = Device signature; valid only if EFLAGS.CF = 0

ahci_check_port:
	mov cl, dl
	and cl, 0x1F
	mov eax, 1
	shl eax, cl

	mov esi, [ahci_abar]
	add esi, AHCI_ABAR_PORTS	; port implementation bitfield
	test [esi], eax
	jz .no

	and edx, 0x1F			; maximum 32 ports
	mov [.port], dl
	shl edx, 7
	add edx, AHCI_ABAR_PORT_CONTROL
	add edx, [ahci_abar]
	mov eax, [edx+AHCI_PORT_SIGNATURE]
	mov [.signature], eax
	cmp eax, 0xFFFFFFFF		; no device present?
	je .no

	mov esi, .msg
	call kprint
	movzx eax, [.port]
	call int_to_string
	call kprint
	mov esi, .msg2
	call kprint
	mov eax, [.signature]
	call hex_dword_to_string
	call kprint
	mov esi, .msg3
	call kprint
	mov eax, [.signature]
	call ahci_print_dev_type
	mov esi, newline
	call kprint

	clc
	mov eax, [.signature]
	ret

.no:
	xor eax, eax
	stc
	ret

.port			db 0
.signature		dd 0
.msg			db "AHCI port ",0
.msg2			db " has device signature 0x",0
.msg3			db " -> ",0

; ahci_print_dev_type:
; Prints a device type based on its signature
; In\	EAX = Device signature
; Out\	Nothing

ahci_print_dev_type:
	cmp eax, 0x00000101
	je .sata

	cmp eax, 0xEB140101
	je .satapi

	cmp eax, 0xC33C0101
	je .enclosure

	cmp eax, 0x96690101
	je .multiplier

	cmp eax, 0xFFFFFFFF
	je .nothing

.unknown:
	mov esi, .unknown_msg
	call kprint
	ret

.sata:
	mov esi, .sata_msg
	call kprint
	ret

.satapi:
	mov esi, .satapi_msg
	call kprint
	ret

.enclosure:
	mov esi, .enclosure_msg
	call kprint
	ret

.multiplier:
	mov esi, .multiplier_msg
	call kprint
	ret

.nothing:
	mov esi, .nothing_msg
	call kprint
	ret

.unknown_msg			db "undefined device signature.",0
.sata_msg			db "SATA device.",0
.satapi_msg			db "SATAPI device.",0
.enclosure_msg			db "enclosure management bridge.",0
.multiplier_msg			db "port multiplier.",0
.nothing_msg			db "no device present.",0

; ahci_detect_devices:
; Detects AHCI device ports

ahci_detect_devices:

.loop:
	mov dl, [.port]
	call ahci_check_port
	jc .next_port

	cmp eax, 0x00000101		; sata device?
	jne .next_port

	; if the device is sata, identify it
	mov bl, [.port]
	mov edi, sata_identify_data
	call sata_identify

.next_port:
	inc [.port]
	cmp [.port], 31
	jg .done
	jmp .loop

.done:
	ret

.port			db 0

; sata_identify:
; Identifies a SATA device
; In\	DL = AHCI Port Number
; In\	EDI = 512-byte buffer to store data
; Out\	EFLAGS.CF = 0 on success

sata_identify:
	mov [.port], dl
	mov [.buffer], edi

	; set up the command list
	mov edi, ahci_command_list
	mov ecx, end_of_ahci_command_list-ahci_command_list
	mov eax, 0
	rep stosb

	mov [ahci_command_list.command_information], 0x10
	mov [ahci_command_list.prdt_length], 1
	mov dword[ahci_command_list.command_table], ahci_command_table

	; and the FIS
	mov edi, ahci_fis
	mov ecx, end_of_ahci_fis-ahci_fis
	mov eax, 0
	rep stosb

	mov [ahci_dma_fis.fis_type], 0x41
	mov [ahci_pio_fis.fis_type], 0x5F
	mov [ahci_register_fis.fis_type], 0x34
	mov [ahci_device_bits_fis.fis_type], 0xA1

	; set up the command table
	mov edi, ahci_command_table
	mov ecx, end_of_ahci_command_table-ahci_command_table
	mov eax, 0
	rep stosb

	; now set up the command FIS
	mov [ahci_command_fis.fis_type], 0x27
	mov [ahci_command_fis.command], 0x80			; we're sending a command
	mov [ahci_command_fis.command_byte], SATA_IDENTIFY	; ata identify command
	mov [ahci_command_fis.device], 0xA0
	mov [ahci_command_fis.count], 1

	; now set up the PRDT
	; because AHCI uses DMA, all addresses must be ***PHYSICAL***
	mov eax, [.buffer]
	call vmm_get_page
	cmp eax, 0
	je .error
	test dl, PAGE_PRESENT
	jz .error

	mov edx, [.buffer]
	and edx, 0xFFF
	add eax, edx

	mov dword[ahci_prdt.memory], eax
	mov [ahci_prdt.byte_count], 512		; 512 bytes; don't interrupt on completion

	; device control registers
	movzx edi, [.port]
	and edi, 0x1F
	shl edi, 7
	add edi, AHCI_ABAR_PORT_CONTROL
	add edi, [ahci_abar]

.wait_for_bsy:
	; first ensure the device is not busy
	test dword[edi+AHCI_PORT_TASK_FILE], 0x80
	jnz .wait_for_bsy

	;test dword[edi+AHCI_PORT_TASK_FILE], 0x08
	;jnz .wait_for_bsy

	; now we know the device is not busy; turn off command execution
	and dword[edi+AHCI_PORT_COMMAND], 0xFFFFFFFE
	mov dword[edi+AHCI_PORT_COMMAND_ISSUE], 0
	wbinvd

	mov ecx, 100000		; timeout

.wait_for_idle:
	pause
	dec ecx
	cmp ecx, 0
	je .error
	test dword[edi+AHCI_PORT_COMMAND], 1	; is the device ready to execute command?
	jnz .wait_for_idle			; it shouldn't be; we just disabled it
	cmp dword[edi+AHCI_PORT_COMMAND_ISSUE], 0
	jne .wait_for_idle

	; send the FIS and command list to the device
	mov dword[edi+AHCI_PORT_COMMAND_LIST], ahci_command_list
	mov dword[edi+AHCI_PORT_COMMAND_LIST+4], 0
	mov dword[edi+AHCI_PORT_FIS], ahci_fis
	mov dword[edi+AHCI_PORT_FIS+4], 0
	;or dword[edi+AHCI_PORT_COMMAND], 0x10000017	; enable command execution
	mov dword[edi+AHCI_PORT_COMMAND_ISSUE], 1	; execute command list 0
	or dword[edi+AHCI_PORT_COMMAND], 1
	wbinvd

	mov ecx, 1000000		; use this as a timeout

.wait_for_command:
	; wait for the device to receive the command
	pause
	dec ecx
	cmp ecx, 0
	je .error
	test dword[edi+AHCI_PORT_COMMAND_ISSUE], 1
	jnz .wait_for_command
	test dword[edi+AHCI_PORT_TASK_FILE], 0x80		; bsy
	jnz .wait_for_command
	test dword[edi+AHCI_PORT_TASK_FILE], 0x01		; error
	jnz .error
	test dword[edi+AHCI_PORT_TASK_FILE], 0x20		; drive fault
	jnz .error
	;test dword[edi+AHCI_PORT_IRQ_STATUS], 0x40000000	; task file error
	;jnz .error

	and dword[edi+AHCI_PORT_COMMAND], 0xFFFFFFFE
	mov dword[edi+AHCI_PORT_COMMAND_ISSUE], 0
	wbinvd

	; ensure the controller transferred the correct # of bytes
	cmp [ahci_command_list.prdt_successful_count], 512
	jne .error

	mov esi, .msg
	call kprint
	movzx eax, [.port]
	call int_to_string
	call kprint
	mov esi, .msg2
	call kprint
	mov esi, sata_identify_data.model
	call swap_string_order	; apparantly ahci also uses the same stupid convention that exists in ata
	call trim_string
	call kprint
	mov esi, .msg3
	call kprint

	; since the call succeeded, register the device with the block device manager
	mov al, BLKDEV_AHCI
	mov ah, BLKDEV_PARTITIONED
	movzx edx, [.port]
	call blkdev_register

	clc
	ret

.error:
	mov esi, .error_msg
	call kprint
	movzx eax, [.port]
	call int_to_string
	call kprint
	mov esi, .error_msg2
	call kprint

	movzx edi, [.port]
	and edi, 0x1F
	shl edi, 7
	add edi, AHCI_ABAR_PORT_CONTROL
	add edi, [ahci_abar]
	mov eax, [edi+AHCI_PORT_TASK_FILE]
	call hex_byte_to_string
	call kprint

	mov esi, newline
	call kprint
	stc
	ret

.port			db 0
.buffer			dd 0
.msg			db "SATA device on AHCI port ",0
.msg2			db " is '",0
.msg3			db "'",10,0
.error_msg		db "Failed to receive data from AHCI device on port ",0
.error_msg2		db "; task file data 0x",0

; ahci_read:
; Reads from an AHCI device
; In\	EDX:EAX = LBA sector
; In\	ECX = Sector count
; In\	BL = Port number
; In\	EDI = Buffer to read sectors
; Out\	AL = 0 on success, 1 on error
; Out\	AH = Device task file

ahci_read:
	; first ensure the device is SATA
	and bl, 0x1F
	mov [.port], bl

	mov esi, ebx
	and esi, 0x1F
	shl esi, 7
	add esi, AHCI_ABAR_PORT_CONTROL
	add esi, [ahci_abar]

	cmp dword[esi+AHCI_PORT_SIGNATURE], 0x00000101	; sata
	je sata_read

	; maybe add satapi support someday?
	;cmp dword[esi+AHCI_PORT_SIGNATURE], 0xEB140101
	;je satapi_read

	mov al, 1
	mov ah, 0xFF
	ret

.port			db 0

; sata_read:
; Reads from a SATA device using AHCI
; In\	EDX:EAX = LBA sector
; In\	ECX = Sector count
; In\	BL = Port number
; In\	EDI = Buffer to read sectors
; Out\	AL = 0 on success, 1 on error
; Out\	AH = Device task file

sata_read:
	mov dword[.lba+4], edx
	mov dword[.lba], eax
	mov [.count], ecx
	and bl, 0x1F
	mov [.port], bl
	mov [.buffer], edi

	; set up the command list
	mov edi, ahci_command_list
	mov ecx, end_of_ahci_command_list-ahci_command_list
	mov eax, 0
	rep stosb

	mov [ahci_command_list.command_information], 0x10	; command fis is 64 bytes
	mov [ahci_command_list.prdt_length], 1			; do everything in 1 DMA transfer
	mov dword[ahci_command_list.command_table], ahci_command_table

	; set up the FIS
	mov edi, ahci_fis
	mov ecx, end_of_ahci_fis-ahci_fis
	mov eax, 0
	rep stosb

	; tell the device about the types of FIS
	mov [ahci_dma_fis.fis_type], 0x41
	mov [ahci_pio_fis.fis_type], 0x5F
	mov [ahci_register_fis.fis_type], 0x34
	mov [ahci_device_bits_fis.fis_type], 0xA1

	; set up the command table
	mov edi, ahci_command_table
	mov ecx, end_of_ahci_command_table-ahci_command_table
	mov eax, 0
	rep stosb

	; set up the command FIS
	mov [ahci_command_fis.fis_type], 0x27
	mov [ahci_command_fis.command], 0x80
	mov [ahci_command_fis.device], 0xE0

	; depending on the LBA, we will use LBA28 or LBA48
	cmp dword[.lba+4], 0
	jne .lba48

	cmp dword[.lba], 0xFFFFFFF-256
	jg .lba48

.lba28:
	mov [ahci_command_fis.command_byte], SATA_READ_LBA28	; read command
	jmp .do_command_fis

.lba48:
	mov [ahci_command_fis.command_byte], SATA_READ_LBA48

.do_command_fis:
	; put the lba and sector count in the command FIS
	mov eax, dword[.lba]
	mov [ahci_command_fis.lba0], al
	shr eax, 8
	mov [ahci_command_fis.lba1], al
	shr eax, 8
	mov [ahci_command_fis.lba2], al
	shr eax, 8
	mov [ahci_command_fis.lba3], al

	mov edx, dword[.lba+4]
	mov [ahci_command_fis.lba4], dl
	shr edx, 8
	mov [ahci_command_fis.lba5], dl

	mov ecx, [.count]
	;and ecx, 0xFFFF		; max 65535 sectors
	mov [ahci_command_fis.count], cx

	; now set up the PRDT
	mov eax, [.buffer]
	call vmm_get_page
	cmp eax, 0
	je .error
	test dl, PAGE_PRESENT		; ensure we don't accidentally write to non-existant page --
	jz .error			; -- because the DMA is not aware of paging!

	mov edx, [.buffer]
	and edx, 0xFFF
	add eax, edx
	mov dword[ahci_prdt.memory], eax

	mov ecx, [.count]
	and ecx, 0xFFFF
	shl ecx, 9				; mul 512
	mov [ahci_prdt.byte_count], ecx		; DMA bytes to transfer

	; device control registers
	movzx edi, [.port]
	and edi, 0x1F
	shl edi, 7
	add edi, AHCI_ABAR_PORT_CONTROL
	add edi, [ahci_abar]

.wait_for_bsy:
	; first ensure the device is not busy
	test dword[edi+AHCI_PORT_TASK_FILE], 0x80
	jnz .wait_for_bsy

	;test dword[edi+AHCI_PORT_TASK_FILE], 0x08
	;jnz .wait_for_bsy

	; now we know the device is not busy; turn off command execution
	and dword[edi+AHCI_PORT_COMMAND], 0xFFFFFFFE
	mov dword[edi+AHCI_PORT_COMMAND_ISSUE], 0
	wbinvd

	mov ecx, 100000		; timeout

.wait_for_idle:
	pause
	dec ecx
	cmp ecx, 0
	je .error
	test dword[edi+AHCI_PORT_COMMAND], 1	; is the device ready to execute command?
	jnz .wait_for_idle			; it shouldn't be; we just disabled it
	cmp dword[edi+AHCI_PORT_COMMAND_ISSUE], 0
	jne .wait_for_idle

	; send the FIS and command list to the device
	mov dword[edi+AHCI_PORT_COMMAND_LIST], ahci_command_list
	mov dword[edi+AHCI_PORT_COMMAND_LIST+4], 0
	mov dword[edi+AHCI_PORT_FIS], ahci_fis
	mov dword[edi+AHCI_PORT_FIS+4], 0
	mov dword[edi+AHCI_PORT_COMMAND_ISSUE], 1	; execute command list 0
	or dword[edi+AHCI_PORT_COMMAND], 1		; enable command execution
	wbinvd

	mov ecx, 1000000	; use this as a timeout

.wait_for_command:
	; wait for the device to receive the command
	pause
	dec ecx
	cmp ecx, 0
	je .error
	test dword[edi+AHCI_PORT_COMMAND_ISSUE], 1
	jnz .wait_for_command
	test dword[edi+AHCI_PORT_TASK_FILE], 0x80		; bsy
	jnz .wait_for_command
	test dword[edi+AHCI_PORT_IRQ_STATUS], 0x40000000	; task file error
	jnz .error
	test dword[edi+AHCI_PORT_TASK_FILE], 0x01		; error
	jnz .error
	test dword[edi+AHCI_PORT_TASK_FILE], 0x20		; drive fault
	jnz .error

	and dword[edi+AHCI_PORT_COMMAND], 0xFFFFFFFE
	mov dword[edi+AHCI_PORT_COMMAND_ISSUE], 0
	wbinvd

	; ensure the controller transferred the correct # of bytes
	mov ecx, [.count]
	and ecx, 0xFFFF
	shl ecx, 9
	cmp [ahci_command_list.prdt_successful_count], ecx
	jne .error

	mov al, 0
	ret

.error:
	movzx esi, [.port]
	shl esi, 7
	add esi, AHCI_ABAR_PORT_CONTROL
	add esi, [ahci_abar]

	mov eax, [esi+AHCI_PORT_TASK_FILE]
	mov [.task_file], al		; task file register

	mov esi, .fail_msg
	call kprint
	mov eax, [.count]
	call hex_word_to_string
	call kprint
	mov esi, .fail_msg2
	call kprint
	mov edx, dword[.lba+4]
	mov eax, dword[.lba]
	call hex_qword_to_string
	call kprint
	mov esi, .fail_msg3
	call kprint
	movzx eax, [.port]
	call int_to_string
	call kprint
	mov esi, .fail_msg4
	call kprint
	mov al, [.task_file]
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

	mov ah, [.task_file]
	mov al, 1		; indicate error
	ret


.lba				dq 0
.count				dd 0
.port				db 0
.buffer				dd 0
.task_file			db 0
.fail_msg			db "Failed to read 0x",0
.fail_msg2			db " sectors from LBA 0x",0
.fail_msg3			db " from SATA device on AHCI port ",0
.fail_msg4			db "; task file data: 0x",0

; ahci_command_list:
; Command list for sending AHCI commands
align 1024		; 1k-alignment
ahci_command_list:
	.command_information		dw 0x0010	; command FIS is 16 dwords size, all other bits un-needed for us
	.prdt_length			dw 1
	.prdt_successful_count		dd 0
	.command_table			dq ahci_command_table

	.reserved:			times 2 dq 0

	times 31*8 dd 0			; clear out the rest of the command list
end_of_ahci_command_list:

; ahci_fis:
; AHCI device to host FIS
align 1024
ahci_fis:

ahci_dma_fis:
	.fis_type		db 0x41
	.port_multiplier	db 0
	.reserved		dw 0

	.dma_buffer		dq 0
	.reserved2		dd 0
	.dma_buffer_offset	dd 0
	.transfer_count		dd 0
	.reserved3		dd 0

	.padding0:		times 0x20 - ($-ahci_fis) db 0

ahci_pio_fis:
	.fis_type		db 0x5F
	.port_multiplier	db 0
	.status			db 0
	.error			db 0

	.lba0			db 0
	.lba1			db 0
	.lba2			db 0
	.device			db 0

	.lba3			db 0
	.lba4			db 0
	.lba5			db 0
	.rsv2			db 0

	.count			dw 0
	.rsv3			db 0
	.new_status		db 0

	.transfer_count		dw 0
	.rsv4			dw 0

	.padding1:		times 0x40 - ($-ahci_fis) db 0

ahci_register_fis:
	.fis_type		db 0x34
	.port_multiplier	db 0

	.status			db 0
	.error			db 0

	.lba0			db 0
	.lba1			db 0
	.lba2			db 0
	.device			db 0

	.lba3			db 0
	.lba4			db 0
	.lba5			db 0
	.rsv2			db 0

	.count			dw 0
	.rsv3			dw 0
	.rsv4			dd 0

	.padding2:		times 0x58 - ($-ahci_fis) db 0

ahci_device_bits_fis:
	.fis_type		db 0xA1
	times 256 - ($-ahci_fis) db 0
end_of_ahci_fis:

; ahci_command_table:
; Command table for sending AHCI commands
align 1024
ahci_command_table:

ahci_command_fis:
	.fis_type			db 0x27		; Host to Device
	.command			db 0x80		; command not control

	.command_byte			db 0x00
	.feature_low			db 0x00

	.lba0				db 0
	.lba1				db 0
	.lba2				db 0
	.device				db 0

	.lba3				db 0
	.lba4				db 0
	.lba5				db 0
	.feature_high			db 0x00

	.count				dw 0
	.icc				db 0
	.control			db 0

	.reserved			dd 0

	times 64 - ($-ahci_command_table) db 0

ahci_satapi_fis:			times 16 db 0	; for sending atapi packets using ahci

	times 128 - ($-ahci_command_table) db 0

ahci_prdt:
	.memory				dq 0
	.rsv0				dd 0
	.byte_count			dd 0x00000000

end_of_ahci_command_table:

; sata_identify_data:
; Data returned from the SATA/SATAPI IDENTIFY command
align 16
sata_identify_data:
	.device_type		dw 0		; 0

	.cylinders		dw 0		; 1
	.reserved_word2		dw 0		; 2
	.heads			dw 0		; 3
				dd 0		; 4
	.sectors_per_track	dw 0		; 6
	.vendor_unique:		times 3 dw 0	; 7
	.serial_number:		times 20 db 0	; 10
				dd 0		; 11
	.obsolete1		dw 0		; 13
	.firmware_revision:	times 8 db 0	; 14
	.model:			times 40 db 0	; 18
	.maximum_block_transfer	db 0
				db 0
				dw 0

				db 0
	.dma_support		db 0
	.lba_support		db 0
	.iordy_disable		db 0
	.iordy_support		db 0
				db 0
	.standyby_timer_support	db 0
				db 0
				dw 0

				dd 0
	.translation_fields	dw 0
				dw 0
	.current_cylinders	dw 0
	.current_heads		dw 0
	.current_spt		dw 0
	.current_sectors	dd 0
				db 0
				db 0
				db 0
	.user_addressable_secs	dd 0
				dw 0
	times 512 - ($-sata_identify_data) db 0






