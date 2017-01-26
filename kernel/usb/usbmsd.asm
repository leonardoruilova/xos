
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad, all rights reserved.

use32

; usbmsd_detect:
; Detects USB mass storage devices

usbmsd_detect:
	cmp [usb_controller_count], 0
	je .quit

	mov esi, .starting_msg
	call kprint

	; go through each device searching for a USB MSD
	; USB MSD has class 0x00 in the device descriptor and class 0x08 in the interface descriptor
	; SCSI protocol is 0x06 and is the only supported one for now
	; Bulk transfer code is 0x50 and is also the only supported method

.loop:
	; read the device descriptor
	mov eax, [.controller]
	cmp eax, [usb_controller_count]
	jge .quit

	mov edi, usb_device_descriptor
	xor al, al
	mov ecx, 0x12
	rep stosb

	mov edi, usb_interface_descriptor
	xor al, al
	mov ecx, 9
	rep stosb

	mov edi, usb_configuration_descriptor
	xor al, al
	mov ecx, 9
	rep stosb

	mov bl, [.port]
	mov cx, USB_DESCRIPTOR_DEVICE shl 8
	mov dx, 0
	mov si, 0x12	; device descriptor size
	mov edi, usb_device_descriptor
	call usb_get_descriptor

	cmp eax, 0
	jne .next

	; ensure the device descriptor exists and is valid
	;cmp byte[usb_device_descriptor.length], 0x12
	;jne .next

	cmp byte[usb_device_descriptor.type], USB_DESCRIPTOR_DEVICE
	jne .next

	; check for class 0x00
	cmp byte[usb_device_descriptor.class], 0x00
	jne .next

	; read the configuration descriptor
	mov eax, [.controller]
	mov bl, [.port]
	mov cx, USB_DESCRIPTOR_CONFIGURATION shl 8
	mov dx, 0
	mov si, 0x09 + 0x09	; configuration descriptor size + interface descriptor
	mov edi, usb_configuration_descriptor
	call usb_get_descriptor

	cmp eax, 0
	jne .next

	; ensure the configuration descriptor is valid
	;cmp byte[usb_configuration_descriptor.length], 0x09
	;jne .next

	cmp byte[usb_configuration_descriptor.type], USB_DESCRIPTOR_CONFIGURATION
	jne .next

	cmp byte[usb_configuration_descriptor.interface_count], 1	; at least one interface
	jl .next

	; ensure the interface descriptor is valid
	cmp byte[usb_interface_descriptor.type], USB_DESCRIPTOR_INTERFACE
	jne .next

	; check for mass storage device
	cmp [usb_interface_descriptor.class], 0x08	; mass storage
	jne .next

	cmp [usb_interface_descriptor.protocol], 0x50	; bulk-only transport
	jne .next

	; check for SCSI
	cmp [usb_interface_descriptor.subclass], 0x06
	jne .not_scsi

	mov ebx, [.controller]
	shl ebx, 8
	mov bl, [.port]
	call usbmsd_init_device		; initialize the device

.next:
	inc [.port]
	cmp [.port], 4
	jg .next_controller

	jmp .loop

.next_controller:
	inc [.controller]
	mov [.port], 1
	jmp .loop

.not_scsi:
	mov esi, .not_scsi_msg
	call kprint
	mov al, [usb_interface_descriptor.subclass]
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

	jmp .next

.quit:
	ret

.starting_msg			db "usb-msd: detecting USB mass storage devices...",10,0
.scsi_msg			db "usb-msd: compatible mass storage device with SCSI command set.",10,0
.not_scsi_msg			db "usb-msd: incompatible mass storage device command set: 0x",0
.controller			dd 0
.port				db 1

; usbmsd_init_device:
; Initializes a USB mass storage device
; In\	EBX = Device address [bits 31:8 = controller, bits 7:0 = port]
; Out\	Nothing

usbmsd_init_device:
	mov [.address], ebx
	mov [.port], bl
	shr ebx, 8
	mov [.controller], ebx

	cli
	hlt
	cli
	hlt

.address			dd 0
.port				db 0
.controller			dd 0




