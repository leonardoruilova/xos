
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

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

pci_ahci_bus			db 0
pci_ahci_dev			db 0
pci_ahci_function		db 0

align 4
ahci_abar			dd 0
ahci_port_count			db 0	; counts how many ports are present

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

	;call ahci_count_ports		; detect present ports
	;call ahci_detect_devices	; detect devices attached to ports

	; for now, because there's no more ahci initialization code
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

	mov ecx, 0xFFFF		; use this as a timeout

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
	ret

.fail:
	mov esi, .fail_msg
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

.no_handoff_msg			db "AHCI BIOS handoff not supported.",10,0
.done_msg			db "AHCI BIOS handoff succeeded.",10,0
.already_handoff_msg		db "AHCI BIOS handoff already pre-configured.",10,0
.timeout_msg			db "AHCI BIOS handoff timed out; failing...",10,0
.fail_msg			db "AHCI BIOS handoff failed.",10,0




