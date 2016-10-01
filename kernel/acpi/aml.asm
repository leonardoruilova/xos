
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

; AML Opcodes
AML_OPCODE_ZERO			= 0x00
AML_OPCODE_ONE			= 0x01
AML_OPCODE_ALIAS		= 0x06
AML_OPCODE_NAME			= 0x08
AML_OPCODE_BYTEPREFIX		= 0x0A
AML_OPCODE_WORDPREFIX		= 0x0B
AML_OPCODE_DWORDPREFIX		= 0x0C
AML_OPCODE_STRINGPREFIX		= 0x0D
AML_OPCODE_QWORDPREFIX		= 0x0E
AML_OPCODE_SCOPE		= 0x10
AML_OPCODE_PACKAGE		= 0x12
AML_OPCODE_METHOD		= 0x14
AML_OPCODE_EXT			= 0x5B
AML_OPCODE_STORE		= 0x70
AML_OPCODE_RETURN		= 0xA4
AML_OPCODE_ONES			= 0xFF

; AML Extended Opcodes
AML_OPCODE_OPREGION		= 0x80
AML_OPCODE_FIELD		= 0x81
AML_OPCODE_DEVICE		= 0x82

; AML Operation Region Spaces
AML_SYSTEM_MEMORY		= 0x00
AML_SYSTEM_IO			= 0x01
AML_SYSTEM_PCI			= 0x02
AML_SYSTEM_EC			= 0x03
AML_SYSTEM_SMBUS		= 0x04

aml_code			dd 0	; pointer to all the AML code, DSDT and then SSDT
aml_code_size			dd 0
aml_system_bus			dd 0	; pointer to \_SB scope
aml_system_bus_size		dd 0
aml_stack			dd 0
aml_sp				dd 0

; acpi_aml_init:
; Initializes the AML interpreter

acpi_aml_init:
	mov ecx, 4096
	call kmalloc
	mov [aml_stack], eax
	add eax, 4096
	mov [aml_sp], eax

	call acpi_enter

	; first get size of dsdt
	mov eax, [acpi_fadt.dsdt]
	mov eax, [eax+4]
	mov [.dsdt_size], eax
	mov [aml_code_size], eax

	mov esi, .dsdt_msg
	call kprint
	mov eax, [aml_code_size]
	call int_to_string
	call kprint
	mov esi, .bytes
	call kprint

	; get size and pointer to SSDT
	mov eax, "SSDT"
	call acpi_find_table
	mov [.ssdt], eax

	; get size of SSDT
	mov eax, [.ssdt]
	cmp eax, -1
	je .only_dsdt

	mov eax, [eax+4]
	mov [.ssdt_size], eax
	add [aml_code_size], eax

	mov esi, .ssdt_msg
	call kprint
	mov eax, [.ssdt_size]
	call int_to_string
	call kprint
	mov esi, .bytes
	call kprint

	; allocate memory
	mov ecx, [aml_code_size]
	call kmalloc
	mov [aml_code], eax
	and eax, 0xFFFFF000

	call vmm_get_page
	add eax, 16		; sse-aligned ;)
	mov edi, eax
	mov esi, [acpi_fadt.dsdt]
	add esi, ACPI_SDT_SIZE
	mov ecx, [.dsdt_size]
	sub ecx, ACPI_SDT_SIZE
	rep movsb

	; and the SSDT right after
	mov esi, [.ssdt]
	add esi, ACPI_SDT_SIZE
	mov ecx, [.ssdt_size]
	sub ecx, ACPI_SDT_SIZE
	rep movsb

	; we're finished ;')
	call acpi_leave

	mov esi, .done_msg
	call kprint
	mov eax, [aml_code_size]
	call int_to_string
	call kprint
	mov esi, .done_msg2
	call kprint

	call acpi_detect_sb
	ret

.only_dsdt:
	; allocate memory
	mov ecx, [aml_code_size]
	call kmalloc
	mov [aml_code], eax
	and eax, 0xFFFFF000

	call vmm_get_page
	add eax, 16		; sse-aligned ;)
	mov edi, eax
	mov esi, [acpi_fadt.dsdt]
	add esi, ACPI_SDT_SIZE
	mov ecx, [.dsdt_size]
	sub ecx, ACPI_SDT_SIZE
	rep movsb

	; we're finished ;')
	call acpi_leave

	mov esi, .done_msg
	call kprint
	mov eax, [aml_code_size]
	call int_to_string
	call kprint
	mov esi, .done_msg2
	call kprint

	call acpi_detect_sb
	ret


.ssdt_msg		db "SSDT is ",0
.bytes			db " bytes.",10,0
.dsdt_msg		db "DSDT is ",0
.ssdt			dd 0
.dsdt_size		dd 0
.ssdt_size		dd 0
.done_msg		db "AML interpreter started; ",0
.done_msg2		db " bytes of AML code provided by the firmware.",10,0

; acpi_parse_size:
; Parses a package size
; In\	ESI = Pointer to package size data
; Out\	EAX = Size of package

acpi_parse_size:
	pusha
	mov [.data], esi
	mov [.size], 0

	mov al, [esi]		; lead byte
	shr al, 6
	and al, 3
	mov [.bytedata], al

	cmp al, 0
	je .no_bytedata

	; lowest 4 bits
	mov al, [esi]
	and eax, 15
	mov [.size], eax

	mov al, [esi+1]
	shl ax, 4
	or byte[.size], al		; next 4 bits

	mov al, [esi+1]
	shr ax, 4
	and al, 15
	or byte[.size+1], al		; next 4 bits

	cmp [.bytedata], 1
	je .return

	mov al, [esi+2]
	shl ax, 4
	or byte[.size+1], al		; next 4 bits

	mov al, [esi+2]
	shr ax, 4
	and al, 15
	or byte[.size+2], al

	cmp [.bytedata], 2
	je .return

	mov al, [esi+3]
	shl ax, 4
	or byte[.size+2], al

	mov al, [esi+3]
	shr ax, 4
	and al, 15
	or byte[.size+3], al

.return:
	popa
	mov eax, [.size]
	ret

.no_bytedata:
	popa
	mov al, [esi]
	and eax, 63
	ret

.data			dd 0
.size			dd 0
.bytedata		db 0

; acpi_get_scope:
; Returns a pointer to an ACPI scope
; In\	EAX = 4-byte scope name
; Out\	EAX = Pointer to scope within ACPI AML, -1 on error
; Out\	ECX = Size of scope in bytes

acpi_get_scope:
	mov [.scope_str], eax

	mov eax, [aml_code]
	mov [.return], eax

	; scan the aml code for scope opcode
	; then skip over the AML package size and check the name

	mov esi, [.return]
	mov edi, [aml_code]
	add edi, [aml_code_size]

.loop:
	cmp esi, edi
	jge .no

	lodsb
	cmp al, AML_OPCODE_SCOPE
	je .check_scope

	jmp .loop

.check_scope:
	; test how many package bytes
	mov [.return], esi

	mov al, [esi]
	shr al, 6
	and eax, 3
	add esi, eax
	inc esi

	; name of scope
	mov edi, .scope_str
	cmpsd
	je .found_scope

	mov esi, [.return]
	mov edi, [aml_code]
	add edi, [aml_code_size]
	jmp .loop

.found_scope:
	mov esi, .done_msg
	call kprint
	mov esi, .scope_str
	call kprint
	mov esi, newline
	call kprint

	mov esi, [.return]
	call acpi_parse_size

	mov ecx, eax
	mov eax, [.return]
	dec eax
	ret

.no:
	mov esi, .err_msg
	call kprint
	mov esi, .scope_str
	call kprint
	mov esi, .err_msg2
	call kprint

	mov eax, -1
	ret

.scope_str		dd 0
			db 0
.return			dd 0
.done_msg		db "acpi: found named scope ",0
.err_msg		db "ACPI ERROR: scope ",0
.err_msg2		db " was not found.",10,0

; acpi_get_method:
; Returns an ACPI control method
; In\	EAX = 4-byte name
; In\	EBX = Scope
; Out\	EAX = Pointer to method, -1 on error

acpi_get_method:
	mov [.method_str], eax
	mov [.return], ebx		; scope

	mov esi, ebx
	inc esi
	call acpi_parse_size	; size of scope
	add eax, [.return]
	mov [.end_scope], eax

	; scan the scope for the method opcode
	; then skip over the package size and scan for the name demanded

	mov esi, [.return]
	mov edi, [.end_scope]

.loop:
	cmp esi, edi
	jge .no

	lodsb
	cmp al, AML_OPCODE_METHOD
	je .check_method

	jmp .loop

.check_method:
	; test how many package bytes
	mov [.return], esi

	mov al, [esi]
	shr al, 6
	and eax, 3
	add esi, eax
	inc esi

	; name of method
	mov edi, .method_str
	cmpsd
	je .found_method

	mov esi, [.return]
	mov edi, [.end_scope]
	jmp .loop

.found_method:
	mov esi, .done_msg
	call kprint
	mov esi, .method_str
	call kprint
	mov esi, newline
	call kprint

	mov eax, [.return]
	dec eax
	ret

.no:
	mov esi, .err_msg
	call kprint
	mov esi, .method_str
	call kprint
	mov esi, .err_msg2
	call kprint

	mov eax, -1
	ret

.method_str		dd 0
			db 0
.return			dd 0
.end_scope		dd 0
.done_msg		db "acpi: found control method ",0
.err_msg		db "ACPI ERROR: method ",0
.err_msg2		db " was not found.",10,0

; acpi_detect_sb:
; Detects the ACPI system bus

acpi_detect_sb:
	mov [aml_code], test_aml+ACPI_SDT_SIZE
	mov [aml_code_size], end_of_test_aml - test_aml - ACPI_SDT_SIZE

	mov eax, "_SB_"
	call acpi_get_scope
	cmp eax, -1
	je .error
	mov [aml_system_bus], eax
	mov [aml_system_bus_size], eax

	mov eax, "WRTT"
	mov ebx, [aml_system_bus]
	call acpi_get_method

	mov ebx, [aml_system_bus]
	call acpi_execute_method

	cli
	hlt

.error:
	mov esi, .error_msg
	jmp early_boot_error

.error_msg		db "Failed to find the ACPI System Bus.",0

; acpi_get_field_member:
; Returns a member of a field region within an operation region
; In\	EAX = 4-byte name
; In\	EBX = Scope
; Out\	EAX = offset, -1 on error
; Out\	BL = Address space
; Out\	BH = Size in bits

acpi_get_field_member:
	mov [.name], eax
	mov [.scope], ebx
	mov esi, ebx
	inc esi
	call acpi_parse_size

	mov [.end_scope], eax
	mov eax, [.scope]
	add [.end_scope], eax

	mov esi, [.scope]

.loop:
	push esi
	mov edi, .name
	cmpsd
	pop esi
	je .found

	inc esi
	cmp esi, [.end_scope]
	jge .not_found

	jmp .loop

.found:
	mov [.field], esi
	mov bh, [esi+4]
	mov [.size], bh

	; go back and look for the operation region name
	mov esi, [.field]

.find_opregion:
	dec esi
	cmp byte[esi], AML_OPCODE_OPREGION
	je .found_opregion

	cmp esi, [.scope]
	jl .not_found
	jmp .find_opregion

.found_opregion:
	add esi, 5		; skip OpRegion and name
	mov al, [esi]
	mov [.regionspace], al

	inc esi

	; get the base address
	lodsb
	cmp al, AML_OPCODE_BYTEPREFIX
	je .base_byte

	cmp al, AML_OPCODE_WORDPREFIX
	je .base_word

	cmp al, AML_OPCODE_DWORDPREFIX
	je .base_dword

	;cmp al, AML_OPCODE_QWORDPREFIX
	;je .base_qword

	jmp .not_found

.base_byte:
	movzx eax, byte[esi]
	mov [.base], eax
	jmp .done

.base_word:
	movzx eax, word[esi]
	mov [.base], eax
	jmp .done

.base_dword:
	mov eax, [esi]
	mov [.base], eax

.done:
	mov eax, [.base]
	mov bl, [.regionspace]
	mov bh, [.size]
	ret

.not_found:
	mov esi, .not_found_msg
	call kprint
	mov esi, .name
	call kprint
	mov esi, .not_found_msg2
	call kprint

	mov eax, -1
	ret

.name			dd 0
			db 0
.scope			dd 0
.end_scope		dd 0
.field			dd 0
.size			db 0
.regionspace		db 0
.base			dd 0
.not_found_msg		db "ACPI ERROR: field member ",0
.not_found_msg2		db " was not found.",10,0

; acpi_execute_method:
; Executes an AML control method
; In\	EAX = Pointer to method
; In\	EBX = Scope which contains method
; Out\	EDX:EAX = Return value of method
; Out\	EBX = 0 on success

acpi_execute_method:
	mov edx, [aml_stack]
	mov [aml_sp], edx

.start:
	mov [.tmp], eax
	mov edx, [aml_sp]

	; this data stack always has the end of the method at offset 0
	; current instruction at offset 4
	; return address after, zero to indicate nothing
	; and then the ACPI scope at offset 12
	mov dword[edx+8], 0
	mov [edx+12], ebx

	mov esi, [.tmp]
	lodsb
	cmp al, AML_OPCODE_METHOD
	jne .not_method

	lodsb		; pkgsize lead
	shr al, 6
	and eax, 3
	add esi, eax
	add esi, 5		; start of executable code

	mov edx, [aml_sp]
	mov [edx+4], esi

	mov esi, [.tmp]
	inc esi
	call acpi_parse_size
	add eax, [.tmp]
	mov edx, [aml_sp]
	mov [edx], eax

.execute_loop:
	mov edx, [aml_sp]
	mov esi, [edx+4]
	cmp esi, [edx]
	jge .no_return

	lodsb
	cmp al, AML_OPCODE_RETURN
	je acpi_do_return

	cmp al, AML_OPCODE_NAME
	je acpi_do_name

	cmp al, AML_OPCODE_PACKAGE
	je acpi_do_package

	cmp al, AML_OPCODE_STORE
	je acpi_do_store

	jmp .bad_opcode

.not_method:
	mov esi, .not_method_msg
	call kprint

	mov ebx, -1
	ret

.no_return:
	mov esi, .no_return_msg
	call kprint

	mov ebx, -1
	ret

.bad_opcode:
	mov [.opcode], al

	mov esi, .bad_opcode_msg
	call kprint
	mov al, [.opcode]
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

	mov ebx, -1
	ret

.tmp			dd 0
.opcode			db 0
.not_method_msg		db "ACPI ERROR: attempted to execute unexecutable code.",10,0
.no_return_msg		db "ACPI ERROR: control method didn't return.",10,0
.bad_opcode_msg		db "ACPI ERROR: undefined opcode 0x",0

;
; INTERNAL ROUTINES
;

acpi_do_return:
	lodsb
	cmp al, AML_OPCODE_ZERO
	je .return_zero

	cmp al, AML_OPCODE_ONE
	je .return_one

	cmp al, AML_OPCODE_ONES
	je .return_ones

	cmp al, AML_OPCODE_BYTEPREFIX
	je .return_byte

	cmp al, AML_OPCODE_WORDPREFIX
	je .return_word

	cmp al, AML_OPCODE_DWORDPREFIX
	je .return_dword

	cmp al, AML_OPCODE_QWORDPREFIX
	je .return_qword

	mov eax, [esi]
	xor edx, edx
	xor ebx, ebx
	ret

.return_zero:
	xor eax, eax
	xor edx, edx
	xor ebx, ebx
	ret

.return_one:
	mov eax, 1
	xor edx, edx
	xor ebx, ebx
	ret

.return_ones:
	mov eax, -1
	mov edx, -1
	xor ebx, ebx
	ret

.return_byte:
	movzx eax, byte[esi]
	xor edx, edx
	xor ebx, ebx
	ret

.return_word:
	movzx eax, word[esi]
	xor edx, edx
	xor ebx, ebx
	ret

.return_dword:
	mov eax, [esi]
	xor edx, edx
	xor ebx, ebx
	ret

.return_qword:
	mov eax, [esi]
	mov edx, [esi+4]
	xor ebx, ebx
	ret

acpi_do_name:
	add dword[edx+4], 5
	jmp acpi_execute_method.execute_loop

acpi_do_package:
	call acpi_parse_size
	add dword[edx+4], eax
	inc dword[edx+4]
	jmp acpi_execute_method.execute_loop

acpi_do_store:
	lodsb
	cmp al, AML_OPCODE_ZERO
	je .zero

	cmp al, AML_OPCODE_ONE
	je .one

	cmp al, AML_OPCODE_ONES
	je .ones

	cmp al, AML_OPCODE_BYTEPREFIX
	je .byte

	cmp al, AML_OPCODE_WORDPREFIX
	je .word

	cmp al, AML_OPCODE_DWORDPREFIX
	je .dword

	cmp al, AML_OPCODE_QWORDPREFIX
	je .qword

	jmp acpi_bad_store

.zero:
	mov dword[.data], 0
	mov dword[.data+4], 0
	inc esi
	jmp .get_destination

.one:
	mov dword[.data], 1
	mov dword[.data+4], 0
	inc esi
	jmp .get_destination

.ones:
	mov dword[.data], -1
	mov dword[.data+4], -1
	inc esi
	jmp .get_destination

.byte:
	movzx eax, byte[esi]
	mov dword[.data], eax
	mov dword[.data+4], 0
	inc esi
	jmp .get_destination

.word:
	movzx eax, word[esi]
	mov dword[.data], eax
	mov dword[.data+4], 0
	add esi, 2
	jmp .get_destination

.dword:
	mov eax, [esi]
	mov dword[.data], eax
	mov dword[.data+4], 0
	add esi, 4
	jmp .get_destination

.qword:
	mov eax, [esi]
	mov dword[.data], eax
	mov eax, [esi+4]
	mov dword[.data+4], eax
	add esi, 8

.get_destination:
	mov eax, [esi]
	mov [.dest], eax
	add esi, 4
	mov edx, [aml_sp]
	mov [edx+4], esi

	; scan for the object
	mov edx, [aml_sp]
	mov ebx, [edx+12]
	call acpi_get_field_member
	cmp eax, -1
	je acpi_bad_store

	; do the i/o requested
	cmp bl, AML_SYSTEM_MEMORY
	je .memory

	cmp bl, AML_SYSTEM_IO
	je .io

	jmp acpi_bad_store

.memory:
	cmp bh, 8
	jle .memory_byte
	cmp bh, 16
	jle .memory_word
	cmp bh, 32
	jle .memory_dword

	jmp acpi_bad_store

.memory_byte:
	call acpi_enter
	mov edx, dword[.data]
	mov [eax], dl
	call acpi_leave

	jmp acpi_execute_method.execute_loop

.memory_word:
	call acpi_enter
	mov edx, dword[.data]
	mov [eax], dx
	call acpi_leave

	jmp acpi_execute_method.execute_loop

.memory_dword:
	call acpi_enter
	mov edx, dword[.data]
	mov [eax], edx
	call acpi_leave

	jmp acpi_execute_method.execute_loop

.io:
	cmp bh, 8
	jle .io_byte
	cmp bh, 16
	jle .io_word
	cmp bh, 32
	jle .io_dword

	jmp acpi_bad_store

.io_byte:
	mov dx, ax
	mov eax, dword[.data]
	out dx, al

	jmp acpi_execute_method.execute_loop

.io_word:
	mov dx, ax
	mov eax, dword[.data]
	out dx, ax

	jmp acpi_execute_method.execute_loop

.io_dword:
	mov dx, ax
	mov eax, dword[.data]
	out dx, eax

	jmp acpi_execute_method.execute_loop

.data		dq 0
.dest		dd 0

acpi_bad_store:
	mov esi, .msg
	call kprint

	mov ebx, -1
	ret

.msg		db "ACPI ERROR: undefined usage of Store() opcode.",10,0


;; TEST AML CODE
test_aml:
	file "kernel/acpi/test.aml"
end_of_test_aml:



