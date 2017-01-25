
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad, all rights reserved.

use32

;
;
; struct usb_controller
; {
;	u8 type;		// USB_UHCI, USB_OHCI, USB_EHCI, USB_XHCI
;	u8 pci_bus;
;	u8 pci_slot;
;	u8 pci_function;
;	u32 base;
; }
;
; sizeof(usb_controller) = 8;
;
;

USB_CONTROLLER_TYPE		= 0x00
USB_CONTROLLER_BUS		= 0x01
USB_CONTROLLER_SLOT		= 0x02
USB_CONTROLLER_FUNCTION		= 0x03
USB_CONTROLLER_BASE		= 0x04
USB_CONTROLLER_SIZE		= 0x08

; Controller Types
USB_NONE			= 0x00
USB_UHCI			= 0x01
USB_OHCI			= 0x02
USB_EHCI			= 0x03
USB_XHCI			= 0x04

MAXIMUM_USB_CONTROLLERS		= 32	; much, much more than enough...
		; TO-DO: if someone knows, what is the maximum USB cotnrollers that can be present?

; Standard USB Requests
USB_GET_STATUS			= 0x00
USB_CLEAR_FEATURE		= 0x01
USB_SET_FEATURE			= 0x03
USB_SET_ADDRESS			= 0x05
USB_GET_DESCRIPTOR		= 0x06
USB_SET_DESCRIPTOR		= 0x07
USB_GET_CONFIGURATION		= 0x08
USB_SET_CONFIGURATION		= 0x09
USB_GET_INTERFACE		= 0x0A
USB_SET_INTERFACE		= 0x0B
USB_SYNC_FRAME			= 0x0C

; Standard Descriptor Types
USB_DESCRIPTOR_DEVICE		= 0x01
USB_DESCRIPTOR_CONFIGURATION	= 0x02
USB_DESCRIPTOR_STRING		= 0x03
USB_DESCRIPTOR_INTERFACE	= 0x04
USB_DESCRIPTOR_ENDPOINT		= 0x05

; USB Setup Packet Structure
USB_SETUP_REQUEST_FLAGS		= 0x00	; u8
USB_SETUP_REQUEST		= 0x01	; u8
USB_SETUP_VALUE			= 0x02	; u16
USB_SETUP_INDEX			= 0x04	; u16
USB_SETUP_LENGTH		= 0x06	; u16

align 4
usb_controllers			dd 0
usb_controller_count		dd 0
usb_setup_packet		dd 0

; usb_init:
; Initializes USB controllers

usb_init:
	mov esi, .msg
	call kprint

	mov ecx, MAXIMUM_USB_CONTROLLERS*USB_CONTROLLER_SIZE
	call kmalloc
	mov [usb_controllers], eax

	call uhci_detect
	;call ohci_detect
	;call ehci_detect
	;call xhci_detect

	mov eax, KERNEL_HEAP
	mov ecx, 1
	mov dl, PAGE_PRESENT or PAGE_WRITEABLE or PAGE_NO_CACHE
	call vmm_alloc
	mov [usb_setup_packet], eax

	ret

.msg				db "usb: detecting USB controllers...",10,0

; usb_register:
; Registers a USB device
; In\	DL = Device type
; In\	AL = PCI bus
; In\	AH = PCI slot
; In\	BL = PCI function
; In\	ECX = Base memory/IO port
; Out\	EAX = Controller number, -1 on error

usb_register:
	mov [.type], dl
	mov [.bus], al
	mov [.slot], ah
	mov [.function], bl
	mov [.base], ecx

	cmp [usb_controller_count], MAXIMUM_USB_CONTROLLERS
	jge .no

	mov edi, [usb_controller_count]
	shl edi, 3	; mul 8
	add edi, [usb_controllers]

	mov al, [.type]
	mov [edi+USB_CONTROLLER_TYPE], al

	mov al, [.bus]
	mov [edi+USB_CONTROLLER_BUS], al

	mov al, [.slot]
	mov [edi+USB_CONTROLLER_SLOT], al

	mov al, [.function]
	mov [edi+USB_CONTROLLER_FUNCTION], al

	mov eax, [.base]
	mov [edi+USB_CONTROLLER_BASE], eax

	mov esi, .msg
	call kprint

	cmp [.type], USB_UHCI
	je .uhci

	cmp [.type], USB_OHCI
	je .ohci

	cmp [.type], USB_EHCI
	je .ehci

	cmp [.type], USB_XHCI
	je .xhci

.unknown:
	mov esi, .unknown_msg
	call kprint
	jmp .continue

.uhci:
	mov esi, .uhci_msg
	call kprint
	jmp .continue

.ohci:
	mov esi, .ohci_msg
	call kprint
	jmp .continue

.ehci:
	mov esi, .ehci_msg
	call kprint
	jmp .continue

.xhci:
	mov esi, .xhci_msg
	call kprint

.continue:
	mov esi, .msg2
	call kprint
	mov eax, [usb_controller_count]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	mov eax, [usb_controller_count]
	inc [usb_controller_count]
	ret

.no:
	mov eax, -1
	ret

.type			db 0
.bus			db 0
.slot			db 0
.function		db 0
.base			dd 0
.msg			db "usb: registered USB ",0
.msg2			db " controller, device number ",0
.unknown_msg		db "unknown",0
.uhci_msg		db "UHCI",0
.ohci_msg		db "OHCI",0
.ehci_msg		db "EHCI",0
.xhci_msg		db "xHCI",0

; usb_reset:
; Resets a USB controller
; In\	EAX = Controller number
; Out\	Nothing

usb_reset:
	cmp eax, [usb_controller_count]
	jge .quit

	shl eax, 3		; mul 8
	add eax, [usb_controllers]

	cmp byte[eax], USB_UHCI
	je uhci_reset

	;cmp byte[eax], USB_OHCI
	;je ohci_reset

	;cmp byte[eax], USB_EHCI
	;je ehci_reset

	;cmp byte[eax], USB_XHCI
	;je xhci_reset

.quit:
	ret

; usb_control:
; Sends a control packet
; In\	EAX = Controller number
; In\	BL = Port number
; In\	BH = Request flags
; In\	CL = Request byte
; In\	DX = Request value
; In\	EDX (high word) = Request index
; In\	SI = Data size
; In\	EDI = If data size exists, pointer to data area
; Out\	EAX = 0 on success

usb_control:
	cmp eax, [usb_controller_count]
	jge .quit

	shl eax, 3		; mul 8
	add eax, [usb_controllers]

	cmp byte[eax], USB_UHCI
	je uhci_control

	;cmp byte[eax], USB_OHCI
	;je ohci_control

	;cmp byte[eax], USB_EHCI
	;je ehci_control

	;cmp byte[eax], USB_XHCI
	;je xhci_control

.quit:
	mov eax, -1
	ret

; usb_get_descriptor:
; Reads a USB descriptor
; In\	EAX = Controller number
; In\	BL = Port number
; In\	CX = Descriptor type and index
; In\	DX = Language ID
; In\	SI = Descriptor length
; In\	EDI = If SI != 0, buffer to store descriptor
; Out\	EAX = 0 on success

usb_get_descriptor:
	mov [.port], bl
	mov [.descriptor], cx
	mov [.language], dx
	mov [.length], si
	mov [.buffer], edi

	mov bl, [.port]
	mov bh, 0x80			; host to device setup packet
	mov cl, USB_GET_DESCRIPTOR

	mov dx, [.language]
	shl edx, 16
	mov dx, [.descriptor]

	mov si, [.length]
	mov edi, [.buffer]
	call usb_control

	ret

.port			db 0
.descriptor		dw 0
.language		dw 0
.length			dw 0
.buffer			dd 0

; USB Device Descriptor
align 16
usb_device_descriptor:
	.length			db 0	; 0x12
	.type			db 0	; USB_DESCRIPTOR_DEVICE
	.usb_version		dw 0	; BCD
	.class			db 0
	.subclass		db 0
	.protocol		db 0
	.max_packet		db 0
	.vendor			dw 0
	.device			dw 0
	.device_version		dw 0
	.manufacturer		db 0
	.product		db 0
	.serial_number		db 0
	.configurations		db 0




