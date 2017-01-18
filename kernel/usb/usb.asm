
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

align 4
usb_controllers			dd 0
usb_controller_count		dd 0

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


