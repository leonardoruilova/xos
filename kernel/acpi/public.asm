
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad, all rights reserved.

use32

; shutdown:
; Shuts down the PC

shutdown:
	cmp [current_task], 1
	jg .no		; only the kernel and the shell can shut down the PC
			; when I support IPC, other programs can request shutdowns by sending --
			; -- a message to the shell

	mov al, 5
	call acpi_sleep

	cli
	hlt

.no:
	mov esi, .no_msg
	call kprint

	ret

.no_msg			db "acpi: application requested shut down; refused...",10,0

; reboot:
; Reboots the PC

reboot:
	cmp [current_task], 1
	jg .no

	;call acpi_reboot	; TO-DO!

.hang:
	mov al, 0xFE
	out 0x64, al
	call iowait

	mov al, 3
	out 0x92, al
	call iowait

	lgdt [.dt]
	lidt [.dt]
	int 0

.no:
	mov esi, .no_msg
	call kprint

	ret

.no_msg			db "acpi: application requested reboot; refused...",10,0
.dt:			dw 0	; null gdt/idt
			dd 0



