
;; xOS -- libxwidget 1
;; Copyright (c) 2017 by Omar Mohammad.

use32

;
; typedef struct label_component
; {
;	u8 id;			// XWIDGET_CPNT_LABEL
;	u32 text;		// pointer
;	u16 x;
;	u16 y;
;	u32 color;
;	u8 reserved[243];
; } label_component;
;

; xwidget_create_label:
; Adds a label to the window
; In\	EAX = Window handle
; In\	CX/DX = X/Y pos
; In\	ESI = Text
; In\	EBX = Color
; Out\	EAX = Label handle, -1 on error
align 4
xwidget_create_label:
	mov [.window], eax
	mov [.text], esi
	mov [.x], cx
	mov [.y], dx
	mov [.color], ebx

	mov eax, [.window]
	call xwidget_find_component

	cmp eax, -1
	je .error

	mov [.component], eax

	; make the label here
	mov byte[eax], XWIDGET_CPNT_LABEL
	mov ebx, [.text]
	mov [eax+1], ebx
	mov bx, [.x]
	mov [eax+5], bx
	mov bx, [.y]
	mov [eax+7], bx
	mov ebx, [.color]
	mov [eax+9], ebx

	; request a redraw
	mov eax, [.window]
	call xwidget_redraw

	mov eax, [.component]
	ret

.error:
	mov eax, -1
	ret

align 4
.window			dd 0
.text			dd 0
.color			dd 0
.component		dd 0
.x			dw 0
.y			dw 0


