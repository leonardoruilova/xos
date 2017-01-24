
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad, all rights reserved.

use32

; Registers
UHCI_REGISTER_COMMAND		= 0x0000	; u16
UHCI_REGISTER_STATUS		= 0x0002	; u16
UHCI_REGISTER_IRQ		= 0x0004	; u16
UHCI_REGISTER_FRAME_NUMBER	= 0x0006	; u16
UHCI_REGISTER_FRAME_BASE	= 0x0008	; u32
UHCI_REGISTER_START_OF_FRAME	= 0x000C	; u8
UHCI_REGISTER_PORT1		= 0x0010	; u16
UHCI_REGISTER_PORT2		= 0x0012	; u16

; UHCI Command Register
UHCI_COMMAND_RUN		= 0x0001
UHCI_COMMAND_HOST_RESET		= 0x0002
UHCI_COMMAND_GLOBAL_RESET	= 0x0004

; UHCI Status Register
UHCI_STATUS_HALTED		= 0x0020
UHCI_STATUS_PROCESS_ERROR	= 0x0010
UHCI_STATUS_PCI_ERROR		= 0x0008
UHCI_STATUS_ERROR_INTERRUPT	= 0x0002

; UHCI Port Command/Status
UHCI_PORT_CONNECT		= 0x0001
UHCI_PORT_CONNECT_CHANGE	= 0x0002
UHCI_PORT_ENABLE		= 0x0004
UHCI_PORT_ENABLE_CHANGE		= 0x0008
UHCI_PORT_DEVICE_SPEED		= 0x0100	; set = low speed; clear = high speed
UHCI_PORT_RESET			= 0x0200
UHCI_PORT_SUSPEND		= 0x1000

; UHCI Packet Types
UHCI_PACKET_IN			= 0x69
UHCI_PACKET_OUT			= 0xE1
UHCI_PACKET_SETUP		= 0x2D

align 4
uhci_pci		dd 0
uhci_count		dd 0

; uhci_detect:
; Detects and initializes UHCI controllers

uhci_detect:
	mov esi, .msg
	call kprint

	; generate device list
	mov ax, 0x0C03
	mov bl, 0x00
	call pci_generate_list

	cmp ecx, 0
	je .no

	mov [uhci_pci], eax
	mov [uhci_count], ecx

	mov esi, .count_msg
	call kprint
	mov eax, [uhci_count]
	call int_to_string
	call kprint
	mov esi, .count_msg2
	call kprint

	mov [.current_count], 0

.initialize_loop:
	mov eax, [.current_count]
	shl eax, 2	; mul 4
	add eax, [uhci_pci]
	call uhci_init_controller

	inc [.current_count]
	mov ecx, [uhci_count]
	cmp [.current_count], ecx
	jge .finish

	jmp .initialize_loop

.finish:
	ret

.no:
	mov esi, .no_msg
	call kprint
	ret

.msg			db "usb-uhci: detecting UHCI controllers...",10,0
.no_msg			db "usb-uhci: UHCI controllers not present.",10,0
.count_msg		db "usb-uhci: found ",0
.count_msg2		db " UHCI controllers; initializing in order...",10,0
.current_count		dd 0

; uhci_init_controller:
; Initializes an UHCI controller
; In\	EAX = Pointer to PCI device
; Out\	Nothing

uhci_init_controller:
	mov [.device], eax

	mov esi, .msg
	call kprint

	mov eax, [.device]
	mov al, [eax+PCI_DEVICE_BUS]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint

	mov eax, [.device]
	mov al, [eax+PCI_DEVICE_SLOT]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint

	mov eax, [.device]
	mov al, [eax+PCI_DEVICE_FUNCTION]
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

	; read the IO port
	mov edx, [.device]
	mov al, [edx+PCI_DEVICE_BUS]
	mov ah, [edx+PCI_DEVICE_SLOT]
	mov bl, [edx+PCI_DEVICE_FUNCTION]
	mov bh, PCI_BAR4
	call pci_read_dword

	mov [.pci_base], eax
	and eax, 0xFFFC
	mov [.io], ax

	mov esi, .io_msg
	call kprint
	mov ax, [.io]
	call hex_word_to_string
	call kprint
	mov esi, newline
	call kprint

	; enable the device functionalities
	mov edx, [.device]
	mov al, [edx+PCI_DEVICE_BUS]
	mov ah, [edx+PCI_DEVICE_SLOT]
	mov bl, [edx+PCI_DEVICE_FUNCTION]
	mov bh, PCI_STATUS_COMMAND
	call pci_read_dword

	or eax, 0x405	; disable IRQs, enable IO and DMA

	push eax

	mov edx, [.device]
	mov al, [edx+PCI_DEVICE_BUS]
	mov ah, [edx+PCI_DEVICE_SLOT]
	mov bl, [edx+PCI_DEVICE_FUNCTION]
	mov bh, PCI_STATUS_COMMAND

	pop edx
	call pci_write_dword

	; register the device
	mov edx, [.device]
	mov al, [edx+PCI_DEVICE_BUS]
	mov ah, [edx+PCI_DEVICE_SLOT]
	mov bl, [edx+PCI_DEVICE_FUNCTION]
	mov ecx, [.pci_base]
	mov dl, USB_UHCI
	call usb_register

	; eax already contains device number
	call usb_reset
	ret

.device			dd 0
.msg			db "usb-uhci: initializing UHCI device on PCI slot ",0
.colon			db ":",0
.io_msg			db "usb-uhci: base IO port is 0x",0
.pci_base		dd 0
.io			dw 0

; uhci_reset:
; Resets an UHCI controller
; In\	EAX = Pointer to USB device
; Out\	Nothing

uhci_reset:
	mov eax, [eax+USB_CONTROLLER_BASE]
	and eax, 0xFFFC
	mov [.io], ax

	; do a host controller reset first
	mov dx, [.io]
	mov ax, UHCI_COMMAND_HOST_RESET
	out dx, ax
	call iowait

.wait_for_host:
	call iowait
	in ax, dx
	test ax, UHCI_COMMAND_HOST_RESET
	jnz .wait_for_host

	; global reset
	mov dx, [.io]
	mov ax, UHCI_COMMAND_GLOBAL_RESET
	out dx, ax
	call iowait

	mov eax, 10
	call pit_sleep

	mov dx, [.io]
	mov ax, 0
	out dx, ax
	call iowait

	; disable interrupts
	mov dx, [.io]
	add dx, UHCI_REGISTER_IRQ
	mov ax, 0
	out dx, ax

	; reset the two ports
	mov dx, [.io]
	add dx, UHCI_REGISTER_PORT1
	mov ax, UHCI_PORT_RESET or UHCI_PORT_ENABLE
	out dx, ax
	call iowait

	mov eax, 10
	call pit_sleep

	mov dx, [.io]
	add dx, UHCI_REGISTER_PORT1
	mov ax, UHCI_PORT_ENABLE
	out dx, ax
	call iowait

	mov dx, [.io]
	add dx, UHCI_REGISTER_PORT2
	mov ax, UHCI_PORT_RESET or UHCI_PORT_ENABLE
	out dx, ax
	call iowait

	mov eax, 10
	call pit_sleep

	mov dx, [.io]
	add dx, UHCI_REGISTER_PORT2
	mov ax, UHCI_PORT_ENABLE
	out dx, ax
	call iowait

	mov dx, [.io]
	add dx, UHCI_REGISTER_START_OF_FRAME
	mov ax, 0x40
	out dx, al

	mov dx, [.io]
	mov ax, 0x80
	out dx, ax

	mov dx, [.io]
	add dx, UHCI_REGISTER_STATUS
	mov ax, 0x3F
	out dx, ax

	ret

.io			dw 0

; uhci_control:
; Sends a control packet
; In\	EAX = Pointer to USB device
; In\	BL = Port number
; In\	BH = Request flags
; In\	CL = Request byte
; In\	DX = Request value
; In\	EDX (high word) = Request index
; In\	SI = Data size
; In\	EDI = If data size exists, pointer to data area
; Out\	EAX = 0 on success

uhci_control:
	mov [.port], bl

	; construct setup packet
	mov [usb_setup_packet.request_flags], bh
	mov [usb_setup_packet.request], cl
	mov [usb_setup_packet.value], dx
	shr edx, 16
	mov [usb_setup_packet.index], dx
	mov [usb_setup_packet.length], si

	mov [.buffer], edi

	mov dx, [eax+USB_CONTROLLER_BASE]
	and dx, 0xFFFC
	mov [.io], dx		; uhci io base

	; construct the first TD
	mov [uhci_td1.next], 0x00000001		; invalid entry
	mov [uhci_td1.status], 1 shl 26
	mov eax, 7	; size of packet - 1
	shl eax, 21

	movzx ebx, [.port]
	shl ebx, 8
	or eax, ebx
	or eax, UHCI_PACKET_SETUP
	mov [uhci_td1.size_id], eax
	mov [uhci_td1.buffer], usb_setup_packet

	; if there is a data packet, construct the second TD
	cmp [usb_setup_packet.length], 0
	je .start

	mov [uhci_td1.next], uhci_td2
	mov [uhci_td2.next], 0x00000001		; invalid entry
	mov [uhci_td2.status], 1 shl 26
	movzx eax, [usb_setup_packet.length]
	dec eax		; size - 1
	shl eax, 21
	or eax, UHCI_PACKET_IN

	movzx ebx, [.port]
	shl ebx, 8
	or eax, ebx
	mov [uhci_td2.size_id], eax
	mov eax, [.buffer]
	mov [uhci_td2.buffer], eax

.start:
	wbinvd

	; construct the frame list
	mov dword[uhci_frame_list], uhci_td1
	mov dword[uhci_frame_list+4], 0x00000001	; invalid entry

	mov dx, [.io]
	add dx, UHCI_REGISTER_STATUS
	mov ax, 0x3F
	out dx, ax

	; tell the uhci where the frame list is
	mov dx, [.io]
	add dx, UHCI_REGISTER_FRAME_NUMBER
	xor ax, ax	; first TD
	out dx, ax

	mov dx, [.io]
	add dx, UHCI_REGISTER_FRAME_BASE
	mov eax, uhci_frame_list
	out dx, eax
	call iowait

	; execute the schedule
	mov dx, [.io]
	in ax, dx
	or ax, UHCI_COMMAND_RUN
	out dx, ax

	jmp $

.finish:
	mov dx, [.io]
	in ax, dx
	and ax, not UHCI_COMMAND_RUN
	out dx, ax
	call iowait

	mov esi, .finish_msg
	call kprint

	mov eax, 0
	ret

.process_error:
	mov esi, .process_error_msg
	call kprint

	mov eax, 0
	ret

.pci_error:
	mov esi, .pci_error_msg
	call kprint

	mov eax, 0
	ret

.interrupt_error:
	mov esi, .interrupt_error_msg
	call kprint

	mov eax, 0
	ret

.port			db 0
.buffer			dd 0
.io			dw 0	; io port
.finish_msg		db "usb-uhci: sent control packet successfully...",10,0
.process_error_msg	db "usb-uhci: process error in control packet.",10,0
.pci_error_msg		db "usb-uhci: PCI error in control packet.",10,0
.interrupt_error_msg	db "usb-uhci: interrupt error in control packet.",10,0


; UHCI Transfer Descriptors... ;)

align 32
uhci_td1:
	.next		dd 0x00000001
	.status		dd 0x4000000	; low speed device for now
	.size_id	dd 0
	.buffer		dd 0
	times 4		dd 0

align 32
uhci_td2:
	.next		dd 0x00000001
	.status		dd 0x4000000
	.size_id	dd 0
	.buffer		dd 0
	times 4		dd 0

align 32
uhci_td3:
	.next		dd 0x00000001
	.status		dd 0x4000000
	.size_id	dd 0
	.buffer		dd 0
	times 4		dd 0

align 32
uhci_td4:
	.next		dd 0x00000001
	.status		dd 0x4000000
	.size_id	dd 0
	.buffer		dd 0
	times 4		dd 0

align 4096
uhci_frame_list:
	dd uhci_td1
	dd 1



