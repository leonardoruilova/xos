
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; Control Flags
ACPI_SLEEP			= 0x2000
ACPI_ENABLED			= 0x0001

; acpi_sleep:
; Puts the system to sleep using ACPI
; In\	AL = Sleep type (0 - 5)
; Out\	Nothing

acpi_sleep:
	mov [.type], al

	mov esi, .starting_msg
	call kprint
	movzx eax, [.type]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	cmp [.type], 5
	jg .bad

	mov al, [.type]
	add al, 48
	mov byte[.package_name+2], al

	mov eax, dword[.package_name]	; package signature
	mov ebx, 0			; search everywhere in the AML and not a specific scope
	call acpi_get_package

	cmp eax, -1
	je .bad

	mov [.package], eax

	cli	; sensitive area of code
	nop

	mov eax, [.package]
	mov cl, 0		; SLP_TYPa
	call acpi_parse_package
	cmp ecx, -1
	je .bad

	mov bx, ax
	and bx, 7
	mov edx, [acpi_fadt.pm1a_control_block]
	in ax, dx
	and ax, 0xE3FF
	shl bx, 10
	or ax, bx
	or ax, ACPI_SLEEP
	out dx, ax

	cmp [acpi_fadt.pm1b_control_block], 0
	je .wait

	mov eax, [.package]
	mov cl, 1		; SLP_TYPb
	call acpi_parse_package
	cmp ecx, -1
	je .bad

	mov bx, ax
	and bx, 7
	mov edx, [acpi_fadt.pm1b_control_block]
	in ax, dx
	and ax, 0xE3FF
	shl bx, 10
	or ax, bx
	or ax, ACPI_SLEEP
	out dx, ax

.wait:
	call iowait
	call iowait
	call iowait
	call iowait
	call iowait
	call iowait

.bad:
	mov esi, .fail_msg
	call kprint

.hang:
	sti
	hlt
	jmp .hang

.package		dd 0
.type			db 0
.package_name		dd "_Sx_"
.starting_msg		db "acpi: entering sleep state S",0
.fail_msg		db "acpi: failed to sleep.",10,0



