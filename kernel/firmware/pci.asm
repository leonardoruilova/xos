
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

;
;
; struct pci_device
; {
;	u8 bus;
;	u8 slot;
;	u8 function
;	u8 reserved;
; }
;
;
; sizeof(pci_device) = 4;
;

PCI_DEVICE_BUS		= 0x00
PCI_DEVICE_SLOT		= 0x01
PCI_DEVICE_FUNCTION	= 0x02
PCI_DEVICE_RESERVED	= 0x03
PCI_DEVICE_SIZE		= 0x04

; Maximum Buses/Device/Functions
PCI_MAX_BUS		= 255	; 256 buses
PCI_MAX_SLOT		= 31	; up to 32 devices per bus
PCI_MAX_FUNCTION	= 7	; up to 8 functions per device

; PCI Configuration Registers
PCI_DEVICE_VENDOR	= 0x00
PCI_STATUS_COMMAND	= 0x04
PCI_CLASS		= 0x08
PCI_HEADER_TYPE		= 0x0C
PCI_BAR0		= 0x10
PCI_BAR1		= 0x14
PCI_BAR2		= 0x18
PCI_BAR3		= 0x1C
PCI_BAR4		= 0x20
PCI_BAR5		= 0x24
PCI_CARDBUS		= 0x28
PCI_SUBSYSTEM		= 0x2C
PCI_EXPANSION_ROM	= 0x30
PCI_CAPABILITIES	= 0x34
PCI_RESERVED		= 0x38
PCI_IRQ			= 0x3C

pci_last_bus		db 0

; pci_read_dword:
; Reads a DWORD from the PCI bus
; In\	AL = Bus number
; In\	AH = Device number
; In\	BL = Function
; In\	BH = Offset
; Out\	EAX = DWORD from PCI bus

pci_read_dword:
	pusha
	mov [.bus], al
	mov [.slot], ah
	mov [.function], bl
	mov [.offset], bh

	mov eax, 0
	movzx ebx, [.bus]
	shl ebx, 16
	or eax, ebx
	movzx ebx, [.slot]
	shl ebx, 11
	or eax, ebx
	movzx ebx, [.function]
	shl ebx, 8
	or eax, ebx
	movzx ebx, [.offset]
	and ebx, 0xFC
	or eax, ebx
	or eax, 0x80000000

	mov edx, 0xCF8
	out dx, eax

	call iowait
	mov edx, 0xCFC
	in eax, dx
	mov [.tmp], eax
	popa
	mov eax, [.tmp]
	ret

.tmp				dd 0
.bus				db 0
.function			db 0
.slot				db 0
.offset				db 0

; pci_write_dword:
; Writes a DWORD to the PCI bus
; In\	AL = Bus number
; In\	AH = Device number
; In\	BL = Function
; In\	BH = Offset
; In\	EDX = DWORD to write
; Out\	Nothing

pci_write_dword:
	pusha
	mov [.bus], al
	mov [.slot], ah
	mov [.func], bl
	mov [.offset], bh
	mov [.dword], edx

	mov eax, 0
	mov ebx, 0
	mov al, [.bus]
	shl eax, 16
	mov bl, [.slot]
	shl ebx, 11
	or eax, ebx
	mov ebx, 0
	mov bl, [.func]
	shl ebx, 8
	or eax, ebx
	mov ebx, 0
	mov bl, [.offset]
	and ebx, 0xFC
	or eax, ebx
	mov ebx, 0x80000000
	or eax, ebx

	mov edx, 0xCF8
	out dx, eax

	call iowait
	mov eax, [.dword]
	mov edx, 0xCFC
	out dx, eax

	call iowait
	popa
	ret

.dword				dd 0
.tmp				dd 0
.bus				db 0
.func				db 0
.slot				db 0
.offset				db 0

; pci_init:
; Initializes PCI

pci_init:

.loop:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, 0
	mov bh, PCI_DEVICE_VENDOR
	call pci_read_dword
	cmp eax, 0xFFFFFFFF
	je .done

	inc [.device]
	cmp [.device], PCI_MAX_SLOT
	jg .next_bus
	jmp .loop

.next_bus:
	mov [.device], 0
	inc [.bus]
	jmp .loop

.done:
	cmp [.device], 0
	jne .yes

	cmp [.bus], 0
	jne .yes

.no:
	mov esi, .no_msg
	call kprint
	ret

.yes:
	mov al, [.bus]
	mov [pci_last_bus], al

	mov esi, .msg
	call kprint
	movzx eax, [pci_last_bus]
	inc eax
	call int_to_string
	call kprint
	mov esi, .msg2
	call kprint
	ret
	

.msg			db "Found ",0
.msg2			db " PCI buses.",10,0
.no_msg			db "No PCI devices/buses found.",10,0
.bus			db 0
.device			db 0

; pci_get_device_class:
; Gets the bus and device number of a PCI device from the class codes
; In\	AH = Class code
; In\	AL = Subclass code
; Out\	AL = Bus number (0xFF if invalid)
; Out\	AH = Device number (0xFF if invalid)
; Out\	BL = Function number (0xFF if invalid)

pci_get_device_class:
	mov [.class], ax
	mov [.bus], 0
	mov [.device], 0
	mov [.function], 0

.find_device:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]
	mov bh, PCI_CLASS
	call pci_read_dword

	shr eax, 16
	cmp ax, [.class]
	je .found_device

.next:

.next_function:
	inc [.function]
	cmp [.function], PCI_MAX_FUNCTION
	jg .next_device
	jmp .find_device

.next_device:
	mov [.function], 0
	inc [.device]
	cmp [.device], PCI_MAX_SLOT
	jg .next_bus
	jmp .find_device

.next_bus:
	mov [.device], 0
	inc [.bus]
	mov al, [pci_last_bus]
	cmp [.bus], al
	jl .find_device

.not_found:
	mov ax, 0xFFFF
	mov bl, 0xFF
	ret

.found_device:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]

	ret

.class				dw 0
.bus				db 0
.device				db 0
.function			db 0

; pci_get_device_class_progif:
; Gets the bus and device number of a PCI device from the class codes and Prog IF code
; In\	AH = Class code
; In\	AL = Subclass code
; In\	BL = Prog IF
; Out\	AL = Bus number (0xFF if invalid)
; Out\	AH = Device number (0xFF if invalid)
; Out\	BL = Function number (0xFF if invalid)

pci_get_device_class_progif:
	mov [.class], ax
	mov [.progif], bl
	mov [.bus], 0
	mov [.device], 0
	mov [.function], 0

.find_device:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]
	mov bh, 8
	call pci_read_dword

	shr eax, 8
	cmp al, [.progif]
	jne .next

	shr eax, 8
	cmp ax, [.class]
	jne .next
	jmp .found_device

.next:

.next_function:
	inc [.function]
	cmp [.function], PCI_MAX_FUNCTION
	jg .next_device
	jmp .find_device

.next_device:
	mov [.function], 0
	inc [.device]
	cmp [.device], PCI_MAX_SLOT
	jg .next_bus
	jmp .find_device

.next_bus:
	mov [.device], 0
	inc [.bus]
	mov al, [pci_last_bus]
	cmp [.bus], al
	jl .find_device

.not_found:
	mov ax, 0xFFFF
	mov bl, 0xFF
	ret

.found_device:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]

	ret

.class				dw 0
.bus				db 0
.device				db 0
.function			db 0
.progif				db 0

; pci_get_device_vendor:
; Gets the bus and device and function of a PCI device from the vendor and device ID
; In\	EAX = Vendor/device combination (low word vendor ID, high word device ID)
; Out\	AL = Bus number (0xFF if invalid)
; Out\	AH = Device number (0xFF if invalid)
; Out\	BL = Function number (0xFF if invalid)

pci_get_device_vendor:
	mov [.dword], eax
	mov [.bus], 0
	mov [.device], 0
	mov [.function], 0

.find_device:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]
	mov bh, 0
	call pci_read_dword

	cmp eax, [.dword]
	je .found_device

.next:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]
	mov bh, 0xC
	call pci_read_dword
	shr eax, 16
	test al, 0x80		; is multifunction?
	jz .next_device

.next_function:
	inc [.function]
	cmp [.function], PCI_MAX_FUNCTION
	jle .find_device

.next_device:
	mov [.function], 0
	inc [.device]
	cmp [.device], PCI_MAX_SLOT
	jle .find_device

.next_bus:
	mov [.device], 0
	inc [.bus]
	mov al, [pci_last_bus]
	cmp [.bus], al
	jl .find_device

.no_device:
	mov ax, 0xFFFF
	mov bl, 0xFF
	ret

.found_device:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]

	ret

.dword				dd 0
.bus				db 0
.device				db 0
.function			db 0

; pci_map_memory:
; Maps PCI memory space in the virtual address space
; In\	AL = Bus
; In\	AH = Device
; In\	BL = Function
; In\	DL = BAR number (0 for BAR0, 1 for BAR1, etc...)
; Out\	EAX = Address of memory in virtual address space, 0 on error
; Out\	ECX = Bytes of memory used by PCI device

pci_map_memory:
	mov [.bus], al
	mov [.dev], ah
	mov [.function], bl

	shl dl, 2		; mul 4
	add dl, PCI_BAR0
	mov [.reg], dl
	mov bh, dl
	call pci_read_dword
	cmp eax, 0
	je .quit_fail
	mov [.data], eax

	test eax, 1		; I/O space or memory?
	jnz .quit_fail

	; calculate size of the memory
	mov al, [.bus]
	mov ah, [.dev]
	mov bl, [.function]
	mov bh, [.reg]
	mov edx, 0xFFFFFFFF	; request bar size
	call pci_write_dword

	call pci_read_dword
	not eax
	mov [.memory_size], eax

	; replace original bar
	mov al, [.bus]
	mov ah, [.dev]
	mov bl, [.function]
	mov bh, [.reg]
	mov edx, [.data]
	call pci_write_dword

	; grab some virtual memory
	mov eax, KERNEL_HEAP
	mov ecx, [.memory_size]
	add ecx, 4095
	shr ecx, 12		; bytes -> to pages
	inc ecx
	call vmm_alloc_pages
	mov [.return], eax
	cmp eax, 0
	je .quit_fail

	; map it
	mov eax, [.return]
	mov ebx, [.data]
	and ebx, 0xFFFFF000	; force page alignment
	mov ecx, [.memory_size]
	add ecx, 4095
	shr ecx, 12
	inc ecx
	mov dl, PAGE_PRESENT OR PAGE_WRITEABLE OR PAGE_NO_CACHE	; it's all a driver needs
	call vmm_map_memory

	mov eax, [.data]
	and eax, 0xFF0		; memory space is always 16-byte aligned
	add [.return], eax

	mov esi, .done_msg
	call kprint
	mov al, [.bus]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [.dev]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [.function]
	call hex_byte_to_string
	call kprint
	mov esi, .done_msg2
	call kprint

	mov eax, [.data]
	and eax, 0xFFFFFFF0
	call hex_dword_to_string
	call kprint

	mov esi, .done_msg3
	call kprint
	mov eax, [.return]
	call hex_dword_to_string
	call kprint

	mov esi, .done_msg4
	call kprint
	mov eax, [.return]
	add eax, [.memory_size]
	call hex_dword_to_string
	call kprint
	mov esi, newline
	call kprint

	mov eax, [.return]
	mov ecx, [.memory_size]
	ret

.quit_fail:
	mov esi, .fail_msg
	call kprint

	xor eax, eax
	xor ecx, ecx
	ret

.bus				db 0
.dev				db 0
.function			db 0
.reg				db 0
.data				dd 0
.memory_size			dd 0
.return				dd 0
.fail_msg			db "Warning: unable to map PCI MMIO into virtual memory.",10,0
.done_msg			db "PCI device ",0
.colon				db ":",0
.done_msg2			db " MMIO at 0x",0
.done_msg3			db ", mapped at 0x",0
.done_msg4			db " -> 0x",0

; pci_generate_list:
; Generates a device list
; In\	AH = Class
; In\	AL = Subclass
; In\	BL = Progamming interface
; Out\	EAX = Pointer to list, only valid if ECX != 0
; Out\	ECX = Size of list in entries, 0 if not found

pci_generate_list:
	mov [.class], ax
	mov [.progif], bl

	mov ecx, 4096
	call kmalloc

	mov [.return], eax
	mov [.pointer_return], eax

	mov [.bus], 0
	mov [.slot],0
	mov [.function], 0
	mov [.count], 0

.loop:
	mov al, [.bus]
	mov ah, [.slot]
	mov bl, [.function]
	mov bh, PCI_CLASS
	call pci_read_dword

	push eax
	shr eax, 16
	cmp ax, [.class]
	pop eax
	jne .next

	;pop eax
	shr eax, 8
	cmp al, [.progif]
	jne .next

	mov edi, [.pointer_return]
	mov al, [.bus]
	stosb
	mov al, [.slot]
	stosb
	mov al, [.function]
	stosb
	xor al, al
	stosb

	mov [.pointer_return], edi
	inc [.count]

.next:
	inc [.function]
	cmp [.function], PCI_MAX_FUNCTION
	jge .next_slot

	jmp .loop

.next_slot:
	mov [.function], 0
	inc [.slot]
	cmp [.slot], PCI_MAX_SLOT
	jge .next_bus

	jmp .loop

.next_bus:
	mov [.slot], 0
	inc [.bus]
	cmp [.bus], PCI_MAX_BUS
	jge .finish

	jmp .loop

.finish:
	cmp [.count], 0
	je .no

	mov eax, [.return]
	mov ecx, [.count]
	ret

.no:
	mov eax, [.return]
	call kfree

	xor ecx, ecx
	xor eax, eax
	ret

.return			dd 0
.pointer_return		dd 0
.count			dd 0
.class			dw 0
.progif			db 0
.bus			db 0
.slot			db 0
.function		db 0



