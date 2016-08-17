
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

; mm_init:
; Initializes the memory manager

mm_init:
	call pmm_init
	call vmm_init

	; set the framebuffer to write-combine
	;mov eax, [screen.framebuffer]
	;mov ecx, 0x800000
	;mov dl, MTRR_WRITE_COMBINE
	;call mtrr_set_range

	; allocate a stack for the kernel API and usermode IRQs/exceptions
	mov ecx, 32768		; 32kb should be much more than enough
	call kmalloc
	add eax, 32768
	mov [tss.esp0], eax
	;mov [tss.esp], eax

	; load the tss
	mov eax, 0x3B
	ltr ax
	nop

	; allocate memory for the VESA framebuffer
	mov ecx, 2048		; 8 MB
	call pmm_alloc
	cmp eax, 0
	je .no_mem_fb

	mov ebx, eax
	mov eax, VBE_BACK_BUFFER
	mov ecx, 2048
	mov dl, PAGE_PRESENT OR PAGE_WRITEABLE
	call vmm_map_memory

	ret

.no_mem_fb:
	mov esi, .no_mem_msg
	jmp early_boot_error

.no_mem_msg			db "Not enough memory to initialize a VBE back buffer.",0

; memxchg:
; Exchanges memory
; In\	ESI = Memory location #1
; In\	EDI = Memory location #2
; In\	ECX = Bytes to exchange
; Out\	Nothing

memxchg:
	pusha

	cmp ecx, 4
	jl .just_bytes

	push ecx
	shr ecx, 2

.loop:
	mov eax, [esi]
	mov [.tmp], eax
	mov eax, [edi]
	mov [esi], eax
	mov eax, [.tmp]
	mov [edi], eax

	add esi, 4
	add edi, 4
	loop .loop

	pop ecx
	and ecx, 3
	cmp ecx, 0
	je .done

.just_bytes:
	mov al, [esi]
	mov byte[.tmp], al
	mov al, [edi]
	mov [esi], al
	mov al, byte[.tmp]
	mov [edi], al

	inc esi
	inc edi
	loop .loop

.done:
	popa
	ret

.tmp				dd 0

; memcpy:
; Like name says
; In\	ESI = Source
; In\	EDI = Destination
; In\	ECX = Byte count
; Out\	Nothing
align 32
memcpy:
	push ecx
	shr ecx, 2	; div 4
	rep movsd

	pop ecx
	and ecx, 3
	rep movsb
	ret


