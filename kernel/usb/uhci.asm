
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
UHCI_STATUS_INTERRUPT_ERROR	= 0x0002
UHCI_STATUS_IOC			= 0x0001

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

; UHCI Descriptor Size
UHCI_TD_SIZE			= 32

align 4
uhci_pci			dd 0
uhci_count			dd 0

; UHCI Descriptors... ;)

align 4
uhci_td				dd 0
uhci_td_physical		dd 0
uhci_frame_list			dd 0
uhci_frame_list_physical	dd 0

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

	; allocate memory
	mov eax, KERNEL_HEAP
	mov ecx, 1
	mov dl, PAGE_PRESENT or PAGE_WRITEABLE or PAGE_NO_CACHE
	call vmm_alloc
	mov [uhci_frame_list], eax

	call vmm_get_page
	mov [uhci_frame_list_physical], eax

	mov eax, KERNEL_HEAP
	mov ecx, 1
	mov dl, PAGE_PRESENT or PAGE_WRITEABLE or PAGE_NO_CACHE
	call vmm_alloc
	mov [uhci_td], eax

	call vmm_get_page
	mov [uhci_td_physical], eax

	; fill frame list with invalid pointers
	mov edi, [uhci_frame_list]
	mov eax, 0x00000001
	mov ecx, 1024
	rep stosd

	; initialize each uhci controller in order
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

	; turn off the uhci
	mov dx, [.io]
	mov ax, 0
	out dx, ax

.wait_halt:
	mov dx, [.io]
	add dx, UHCI_REGISTER_STATUS
	in ax, dx
	test ax, UHCI_STATUS_HALTED
	jnz .start
	jmp .wait_halt

.start:
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
	add dx, UHCI_REGISTER_FRAME_BASE
	mov eax, [uhci_frame_list_physical]
	out dx, eax	; frame list base

	mov dx, [.io]
	add dx, UHCI_REGISTER_START_OF_FRAME
	mov ax, 0x40	; 1ms
	out dx, al

	mov dx, [.io]
	mov ax, 0x80	; max packet = 64 bytes
	out dx, ax

	mov dx, [.io]
	add dx, UHCI_REGISTER_STATUS
	mov ax, 0x3F	; clear status
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
	mov [.buffer], edi

	; construct setup packet
	mov edi, [usb_setup_packet]
	mov [edi+USB_SETUP_REQUEST_FLAGS], bh
	mov [edi+USB_SETUP_REQUEST], cl
	mov [edi+USB_SETUP_VALUE], dx
	shr edx, 16
	mov [edi+USB_SETUP_INDEX], dx
	mov [edi+USB_SETUP_LENGTH], si

	mov dx, [eax+USB_CONTROLLER_BASE]
	and dx, 0xFFFC
	mov [.io], dx		; uhci io base

	; if using port 1, disable port 2
	; if using port 2, vice versa
	cmp [.port], 1
	je .use_port1

.use_port2:
	mov dx, [.io]
	add dx, UHCI_REGISTER_PORT1
	in ax, dx
	and ax, not UHCI_PORT_ENABLE
	out dx, ax

	mov dx, [.io]
	add dx, UHCI_REGISTER_PORT2
	in ax, dx
	or ax, UHCI_PORT_ENABLE
	out dx, ax

	mov eax, 5
	call pit_sleep
	jmp .start

.use_port1:
	mov dx, [.io]
	add dx, UHCI_REGISTER_PORT2
	in ax, dx
	and ax, not UHCI_PORT_ENABLE
	out dx, ax

	mov dx, [.io]
	add dx, UHCI_REGISTER_PORT1
	in ax, dx
	or ax, UHCI_PORT_ENABLE
	out dx, ax

	mov eax, 5
	call pit_sleep

.start:
	; create the frame list
	mov edi, [uhci_frame_list]
	mov eax, [uhci_td_physical]
	or eax, 2		; point at QH not TD
	stosd
	mov eax, 0x00000001	; invalid entry
	stosd

	; create the first QH
	mov edi, [uhci_td]
	mov eax, 0x00000001	; invalid entry
	stosd
	mov eax, [uhci_td_physical]	; first transfer descriptor
	add eax, 32
	stosd
	mov eax, 0
	stosd
	stosd
	stosd
	stosd

	; construct first TD
	mov edi, [uhci_td]
	add edi, 32
	mov eax, [uhci_td_physical]
	add eax, 64		; second TD
	stosd
	mov eax, (1 shl 26) or (11b shl 27) or (1 shl 23)	; low speed, 3 error limit, active
	stosd
	mov eax, 7
	shl eax, 21
	or eax, UHCI_PACKET_SETUP
	stosd

	mov eax, [usb_setup_packet]
	call vmm_get_page

	stosd

	mov eax, 0
	stosd
	stosd
	stosd
	stosd

	; if there is a data packet, construct the second TD
	mov esi, [usb_setup_packet]
	cmp word[esi+USB_SETUP_LENGTH], 0
	je .no_data

	; construct second TD
	mov edi, [uhci_td]
	add edi, 64
	mov eax, [uhci_td_physical]
	add eax, 64+32		; third TD
	stosd
	mov eax, (1 shl 26) or (11b shl 27) or (1 shl 23)	; low speed, 3 error limit, active
	stosd
	mov esi, [usb_setup_packet]
	movzx eax, word[esi+USB_SETUP_LENGTH]
	dec eax
	shl eax, 21
	or eax, UHCI_PACKET_IN
	or eax, 1 shl 19	; data1
	stosd

	mov eax, [.buffer]
	and eax, 0xFFFFF000
	call vmm_get_page
	mov ebx, [.buffer]
	and ebx, 0xFFFF
	or eax, ebx
	stosd

	mov eax, 0
	stosd
	stosd
	stosd
	stosd

	; construct third TD
	mov edi, [uhci_td]
	add edi, 64+32
	mov eax, 0x00000001	; invalid entry
	stosd
	mov eax, (1 shl 26) or (11b shl 27) or (1 shl 23) or (1 shl 24)
	stosd
	mov eax, 0x7FF
	shl eax, 21
	or eax, UHCI_PACKET_OUT
	;or eax, 1 shl 19	; data1
	stosd

	mov eax, 0	; buffer..
	stosd

	mov eax, 0
	stosd
	stosd
	stosd
	stosd

	jmp .send_packet

.no_data:
	; construct second TD as a status packet
	mov edi, [uhci_td]
	add edi, 64
	mov eax, 0x00000001	; invalid entry
	stosd

	mov eax, (1 shl 26) or (11b shl 27) or (1 shl 23) or (1 shl 24)
	stosd
	mov eax, 0x7FF
	shl eax, 21
	or eax, UHCI_PACKET_IN	; when there is no data stage, status comes from device to host
	stosd

	mov eax, 0	; buffer..
	stosd

	mov eax, 0
	stosd
	stosd
	stosd
	stosd

.send_packet:
	wbinvd
	wbinvd

	; tell the uhci where the frame list is
	mov dx, [.io]
	add dx, UHCI_REGISTER_FRAME_BASE
	mov eax, [uhci_frame_list_physical]
	out dx, eax

	mov dx, [.io]
	add dx, UHCI_REGISTER_FRAME_NUMBER
	mov ax, 0
	out dx, ax

	call iowait
	call iowait

	mov dx, [.io]
	in ax, dx
	mov ax, UHCI_COMMAND_RUN
	out dx, ax
	call iowait

.wait_finish:
	mov dx, [.io]
	add dx, UHCI_REGISTER_STATUS
	in ax, dx

	test ax, UHCI_STATUS_PCI_ERROR
	jnz .pci_error

	test ax, UHCI_STATUS_INTERRUPT_ERROR
	jnz .interrupt_error

	test ax, UHCI_STATUS_PROCESS_ERROR
	jnz .process_error

	test ax, UHCI_STATUS_HALTED
	jnz .finish

	test ax, UHCI_STATUS_IOC
	jnz .finish

	jmp .wait_finish

.finish:
	mov dx, [.io]
	in ax, dx
	and ax, not UHCI_COMMAND_RUN
	out dx, ax

	mov dx, [.io]
	add dx, UHCI_REGISTER_STATUS
	mov ax, 0x3F	; clear status
	out dx, ax

	mov esi, .finish_msg
	call kprint

	mov eax, 0
	ret

.process_error:
	mov dx, [.io]
	in ax, dx
	and ax, not UHCI_COMMAND_RUN
	out dx, ax

	mov dx, [.io]
	add dx, UHCI_REGISTER_STATUS
	mov ax, 0x3F	; clear status
	out dx, ax

	mov esi, .process_error_msg
	call kprint

	mov eax, -1
	ret

.pci_error:
	mov dx, [.io]
	in ax, dx
	and ax, not UHCI_COMMAND_RUN
	out dx, ax

	mov dx, [.io]
	add dx, UHCI_REGISTER_STATUS
	mov ax, 0x3F	; clear status
	out dx, ax

	mov esi, .pci_error_msg
	call kprint

	mov eax, -1
	ret

.interrupt_error:
	mov dx, [.io]
	in ax, dx
	and ax, not UHCI_COMMAND_RUN
	out dx, ax

	mov dx, [.io]
	add dx, UHCI_REGISTER_STATUS
	mov ax, 0x3F	; clear status
	out dx, ax

	mov esi, .interrupt_error_msg
	call kprint

	mov eax, -1
	ret

.port			db 0
.buffer			dd 0
.io			dw 0	; io port
.finish_msg		db "usb-uhci: sent control packet successfully...",10,0
.process_error_msg	db "usb-uhci: process error in control packet.",10,0
.pci_error_msg		db "usb-uhci: PCI error in control packet.",10,0
.interrupt_error_msg	db "usb-uhci: interrupt error in control packet.",10,0



