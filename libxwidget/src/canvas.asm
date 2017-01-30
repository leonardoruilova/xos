
;; xOS -- libxwidget 1
;; Copyright (c) 2017 by Omar Mohammad.

use32

;;
;; THESE ARE INTERNAL ROUTINES USED BY THE LIBRARY.
;; ALL WINDOW HANDLES HERE ARE KERNEL (GLOBAL) AND NOT SESSION-SPECIFIC.
;;

; xwidget_put_pixel:
; Puts a pixel
; In\	EAX = Window handle
; In\	CX/DX = X/Y pos
; In\	EBX = Color
; Out\	Nothing
align 4
xwidget_put_pixel:
	push ebx
	mov ebp, XOS_WM_PIXEL_OFFSET
	int 0x60

	pop ebx
	cmp eax, -1
	je .done

	mov [eax], ebx	; put a pixel

	;mov ebp, XOS_WM_REDRAW
	;int 0x60

.done:
	ret

; xwidget_read_pixel:
; Reads a pixel
; In\	EAX = Window handle
; In\	CX/DX = X/Y pos
; Out\	EAX = Color
align 4
xwidget_read_pixel:
	mov ebp, XOS_WM_PIXEL_OFFSET
	int 0x60

	cmp eax, -1
	je .done

	mov eax, [eax]

.done:
	ret

; xwidget_fill_rect:
; Draws a rectangle
; In\	AX/BX = Width/Height
; In\	CX/DX = X/Y pos
; In\	ESI = Color
; In\	EDI = Window handle
; Out\	Nothing
align 4
xwidget_fill_rect:
	mov [.width], ax
	mov [.height], bx
	mov [.x], cx
	mov [.y], dx
	mov [.color], esi
	mov [.window], edi

	add ax, cx
	add bx, dx
	mov [.end_x], ax
	mov [.end_y], bx

	; get window information
	mov ebp, XOS_WM_GET_WINDOW
	mov eax, [.window]
	int 0x60

	cmp si, [.end_x]	; window width
	jl .quit

	cmp di, [.end_y]	; window height
	jl .quit

	and esi, 0xFFFF
	shl esi, 2
	mov [.pitch], esi

	; start working
	mov ebp, XOS_WM_PIXEL_OFFSET
	mov eax, [.window]
	mov cx, [.x]
	mov dx, [.y]
	int 0x60

	cmp eax, -1
	je .quit

	mov [.offset], eax
	movzx ecx, [.height]

.loop:
	push ecx

	mov edi, [.offset]
	mov eax, [.color]
	movzx ecx, [.width]
	rep stosd

	pop ecx
	mov eax, [.pitch]
	add [.offset], eax

	loop .loop

.quit:
	ret

align 2
.width			dw 0
.height			dw 0
.x			dw 0
.y			dw 0
.end_x			dw 0
.end_y			dw 0
align 4
.color			dd 0
.window			dd 0
.pitch			dd 0
.offset			dd 0



