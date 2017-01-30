
;; xOS -- libxwidget 1
;; Copyright (c) 2017 by Omar Mohammad.

use32

;
; typedef struct button_component
; {
;	u8 id;			// XWIDGET_CPNT_BUTTON
;	u32 text;		// pointer
;	u16 x;
;	u16 y;
;	u8 reserved[247];
; } button_component;
;

; xwidget_create_button:
; Adds a button to the window
; In\	EAX = Window handle
; In\	CX/DX = X/Y pos
; In\	ESI = Text
; Out\	EAX = Button handle, -1 on error
align 4
xwidget_create_button:
	mov [.window], eax
	mov [.text], esi
	mov [.x], cx
	mov [.y], dx

	mov eax, [.window]
	call xwidget_find_component

	cmp eax, -1
	je .error

	mov [.component], eax

	; make the button there
	mov byte[eax], XWIDGET_CPNT_BUTTON
	mov ebx, [.text]
	mov [eax+1], ebx
	mov bx, [.x]
	mov [eax+5], bx
	mov bx, [.y]
	mov [eax+7], bx

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
.component		dd 0
.x			dw 0
.y			dw 0

