
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; Note: If you're looking for the sources of multi-core task management --
; -- see tasking/smp.asm instead. This file contains an I/O APIC driver and SMP initialization.

IA32_MSR_APICBASE	= 0x1B	; this MSR contains the base of the local apic, and also if it is enabled

; ACPI MADT types
MADT_LOCAL_APIC		= 0x00
MADT_IOAPIC		= 0x01
MADT_OVERRIDE		= 0x02

; where the APICs will be mapped
LOCAL_APIC		= 0xFFE00000
IOAPIC			= 0xFFC00000

IOAPIC_FIXED_DEST	= 0x000
IOAPIC_LOW_DEST		= 0x100
IOAPIC_LOGICAL_DEST	= 0x800
IOAPIC_ACTIVE_HIGH	= 0x2000
IOAPIC_LEVEL_TRIGGER	= 0x8000
IOAPIC_MASK		= 0x10000

MAXIMUM_CPUS		= 16		; up to 16 physical cpus

madt_table		dd 0		; acpi madt address
using_apic		db 0		; used to determine whether or not apic initialization was successful
local_apic_phys		dd 0
ioapic_phys		dd 0

list_of_cpus:		times MAXIMUM_CPUS+1 db 0xFF		; apic ids of the CPUs

; irq_mask:
; Masks an IRQ
; In\	AL = IRQ number
; Out\	Nothing

irq_mask:
	call pic_mask
	ret

; irq_unmask:
; Unmasks an IRQ
; In\	AL = IRQ number
; Out\	Nothing

irq_unmask:
	call pic_unmask
	ret

; apic_init:
; Detects and initializes local APIC and I/O APIC

apic_init:
	; find the madt table
	call acpi_enter
	mov eax, "APIC"		; madt signature
	call acpi_find_table
	cmp eax, -1
	je .no_apic

	mov [madt_table], eax

	; parse the madt, detect local apics and ioapics, re-enable paging
	; map them in to the virtual address space, and then initialize them
	call apic_parse

	jmp $

.no_apic:
	call acpi_leave
	mov esi, .no_apic_msg
	call kprint

	ret

.no_apic_msg		db "ACPI MADT not present.",10,0

; apic_parse:
; Parses the MADT table

apic_parse:
	; first grab the address of the local apic
	mov esi, [madt_table]
	add esi, ACPI_SDT_SIZE
	mov eax, [esi]
	mov [local_apic_phys], eax

	call lapic_enable		; enable the local apic if it not already enabled

	; now detect the cpus and ioapic
	;call apic_detect_cpu
	;call apic_detect_ioapic
	ret

; lapic_enable:
; Enables the local APIC

lapic_enable:
	mov ecx, IA32_MSR_APICBASE
	rdmsr

	; only write to the register if we have to!
	test eax, 0x800		; enabled?
	jz .write

	and eax, 0xFFFF0000
	cmp eax, [local_apic_phys]
	jne .write

	cmp edx, 0
	jne .write

	ret

.write:
	mov eax, [local_apic_phys]
	or eax, 0x800
	mov edx, 0
	wrmsr

	ret






