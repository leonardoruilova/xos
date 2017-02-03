
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use16

VBE_BUFFER_SIZE			= 0x1000000	; maximum buffer size is 16 MB
VBE_PHYSICAL_BUFFER		= 0xD0000000
VBE_BACK_BUFFER			= VBE_PHYSICAL_BUFFER + VBE_BUFFER_SIZE

; default width/height when EDID is unavailable or unusable
DEFAULT_WIDTH			= 800
DEFAULT_HEIGHT			= 600

align 32
vbe_width			dw DEFAULT_WIDTH
vbe_height			dw DEFAULT_HEIGHT

align 16			; Not sure if this has to be aligned, but it doesn't hurt.
vbe_info_block:
	.signature		db "VBE2"	; tell BIOS we support VBE 2.0+
	.version		dw 0
	.oem			dd 0
	.capabilities		dd 0
	.video_modes		dd 0
	.memory			dw 0
	.software_rev		dw 0
	.vendor			dd 0
	.product_name		dd 0
	.product_rev		dd 0
	.reserved:		times 222 db 0
	.oem_data:		times 256 db 0

align 16
mode_info_block:
	.attributes		dw 0
	.window_a		db 0
	.window_b		db 0
	.granularity		dw 0
	.window_size		dw 0
	.segmentA		dw 0
	.segmentB		dw 0
	.win_func_ptr		dd 0
	.pitch			dw 0

	.width			dw 0
	.height			dw 0

	.w_char			db 0
	.y_char			db 0
	.planes			db 0
	.bpp			db 0
	.banks			db 0

	.memory_model		db 0
	.bank_size		db 0
	.image_pages		db 0

	.reserved0		db 0

	.red			dw 0
	.green			dw 0
	.blue			dw 0
	.reserved_mask		dw 0
	.direct_color		db 0

	.framebuffer		dd 0
	.off_screen_mem		dd 0
	.off_screen_mem_size	dw 0
	.reserved1:		times 206 db 0

align 16
vbe_edid:
	.padding:		times 8 db 0
	.manufacturer_id	dw 0
	.edid_code		dw 0
	.serial_number		dd 0
	.week_number		db 0
	.manufacturer_year	db 0
	.edid_version		db 0
	.edid_revision		db 0
	.video_input		db 0
	.width_cm		db 0
	.height_cm		db 0
	.gamma_factor		db 0
	.dpms_flags		db 0
	.chroma:		times 10 db 0
	.timings1		db 0
	.timings2		db 0
	.reserved_timing	db 0
	.standard_timings:	times 8 dw 0
	.timing_desc1:		times 18 db 0
	.timing_desc2:		times 18 db 0
	.timing_desc3:		times 18 db 0
	.timing_desc4:		times 18 db 0
	.reserved		db 0
	.checksum		db 0

align 32
screen:
	.width			dd 0
	.height			dd 0
	.bpp			dd 0
	.bytes_per_pixel	dd 0
	.bytes_per_line		dd 0
	.screen_size		dd 0
	.screen_size_dqwords	dd 0	; in sets 8 DQWORDs, for SSE copying
	.framebuffer		dd 0
	.x			dd 0
	.y			dd 0
	.x_max			dd 0
	.y_max			dd 0

; do_vbe:
; Does the VBE initialization

do_vbe:
	push es					; some VESA BIOSes destroy ES, or so I read
	mov dword[vbe_info_block], "VBE2"
	mov ax, 0x4F00				; get VBE BIOS info
	mov di, vbe_info_block
	int 0x10
	pop es

	cmp ax, 0x4F
	jne .no_vbe

	cmp dword[vbe_info_block], "VESA"
	jne .no_vbe

	cmp [vbe_info_block.version], 0x200
	jl .old_vbe

	; read the EDID and determine proper mode for this monitor
	push es
	mov ax, 0x4F15
	mov bl, 1
	mov cx, 0
	mov dx, 0
	mov di, vbe_edid
	int 0x10
	pop es

	cmp ax, 0x4F	; function succeeded?
	jne .use_default

	; determine the preferred mode
	; the first timing descriptor should contain the preferred resolution
	; if it doesn't contain a timing descriptor, ignore the edid and use the defaults
	cmp byte[vbe_edid.timing_desc1], 0x00
	je .use_default

	movzx ax, byte[vbe_edid.timing_desc1+2]	; low byte of preferred width
	mov [vbe_width], ax
	movzx ax, byte[vbe_edid.timing_desc1+4]
	and ax, 0xF0
	shl ax, 4
	or [vbe_width], ax

	movzx ax, byte[vbe_edid.timing_desc1+5]	; low byte of preferred height
	mov [vbe_height], ax
	movzx ax, byte[vbe_edid.timing_desc1+7]
	and ax, 0xF0
	shl ax, 4
	or [vbe_height], ax

	; ensure they are valid
	cmp [vbe_width], 0
	je .use_default

	cmp [vbe_height], 0
	je .use_default

	; set the mode
	mov ax, [vbe_width]
	mov bx, [vbe_height]
	mov cl, 32
	call vbe_set_mode
	jc .use_default		; if it failed, try to use the default

	ret

.use_default:
	mov [vbe_width], DEFAULT_WIDTH
	mov [vbe_height], DEFAULT_HEIGHT

.set_mode:
	mov ax, [vbe_width]
	mov bx, [vbe_height]
	mov cl, 32
	call vbe_set_mode
	jc .bad_mode		; removed support for 24bpp modes...

	ret

;.try_24bpp:
;	; use 24bpp as a fallback
;	mov ax, [vbe_width]
;	mov bx, [vbe_height]
;	mov cl, 24
;	call vbe_set_mode
;	jc .bad_mode
;
;	ret

.no_vbe:
	mov si, .no_vbe_msg
	call print16
	cli
	hlt

.old_vbe:
	mov si, .old_vbe_msg
	call print16
	cli
	hlt

.bad_mode:
	mov si, .bad_mode_msg
	call print16
	cli
	hlt

.no_vbe_msg			db "Boot error: VBE BIOS not found.",0
.old_vbe_msg			db "Boot error: xOS requires VBE BIOS 2.0 or newer.",0
.bad_mode_msg			db "Boot error: Failed to set a VBE mode.",0

; vbe_set_mode:
; Sets a VBE mode
; In\	AX = Width
; In\	BX = Height
; In\	CL = Bpp
; Out\	FLAGS.CF = 0 on success, 1 on error

vbe_set_mode:
	mov [.width], ax
	mov [.height], bx
	mov [.bpp], cl

	push es					; some VESA BIOSes destroy ES, or so I read
	mov dword[vbe_info_block], "VBE2"
	mov ax, 0x4F00				; get VBE BIOS info
	mov di, vbe_info_block
	int 0x10
	pop es

	cmp ax, 0x4F				; BIOS doesn't support VBE?
	jne .error

	mov ax, word[vbe_info_block.video_modes]
	mov [.offset], ax
	mov ax, word[vbe_info_block.video_modes+2]
	mov [.segment], ax

	mov ax, [.segment]
	mov fs, ax
	mov si, [.offset]

.find_mode:
	mov dx, [fs:si]
	add si, 2
	mov [.offset], si
	mov [.mode], dx
	mov ax, 0
	mov fs, ax

	cmp [.mode], 0xFFFF			; end of list?
	je .error

	push es
	mov ax, 0x4F01				; get VBE mode info
	mov cx, [.mode]
	mov di, mode_info_block
	int 0x10
	pop es

	cmp ax, 0x4F
	jne .error

	mov ax, [.width]
	cmp ax, [mode_info_block.width]
	jne .next_mode

	mov ax, [.height]
	cmp ax, [mode_info_block.height]
	jne .next_mode

	mov al, [.bpp]
	cmp al, [mode_info_block.bpp]
	jne .next_mode

	; does the mode support LFB and is it supported by hardware?
	test [mode_info_block.attributes], 0x81
	jz .next_mode

	; if we make it here, we've found the correct mode!

	; set the mode!
	push es
	mov ax, 0x4F02
	mov bx, [.mode]
	or bx, 0x4000
	mov cx, 0
	mov dx, 0
	mov di, 0
	int 0x10
	pop es

	cmp ax, 0x4F
	jne .error

	; save the mode information
	movzx eax, [.width]
	mov [screen.width], eax
	movzx eax, [.height]
	mov [screen.height], eax
	movzx eax, [.bpp]
	mov [screen.bpp], eax
	add eax, 7
	shr eax, 3
	mov [screen.bytes_per_pixel], eax

	movzx eax, [mode_info_block.pitch]
	mov [screen.bytes_per_line], eax

	mov eax, [mode_info_block.framebuffer]
	mov [screen.framebuffer], eax

	movzx eax, [.width]
	shr eax, 3		; div 8
	dec eax
	mov [screen.x_max], eax

	movzx eax, [.height]
	shr eax, 4		; div 16
	dec eax
	mov [screen.y_max], eax

	mov [screen.x], 0
	mov [screen.y], 0

	clc
	ret

.next_mode:
	mov ax, [.segment]
	mov fs, ax
	mov si, [.offset]
	jmp .find_mode

.error:
	mov ax, 0
	mov fs, ax
	stc
	ret

.width				dw 0
.height				dw 0
.bpp				db 0
.segment			dw 0
.offset				dw 0
.mode				dw 0





