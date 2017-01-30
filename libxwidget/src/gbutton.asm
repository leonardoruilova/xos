
;; xOS -- libxwidget 1
;; Copyright (c) 2017 by Omar Mohammad.

use32

;
; typedef struct gbutton_component
; {
;	u8 id;		// XWIDGET_CPNT_GBUTTON
;	u32 text;
;	u16 x;
;	u16 y;
;	u16 width;
;	u16 height;
;	u16 end_x;
;	u16 end_y;
;	u32 fg;
;	u32 bg;
;	u8 reserved[231];
; }
;

GBUTTON_TEXT			= 0x01
GBUTTON_X			= 0x05
GBUTTON_Y			= 0x07
GBUTTON_WIDTH			= 0x09
GBUTTON_HEIGHT			= 0x0B
GBUTTON_END_X			= 0x0D
GBUTTON_END_Y			= 0x0F
GBUTTON_FG			= 0x11
GBUTTON_BG			= 0x15

; xwidget_create_gbutton:
; Creates a graphical button component
; In\	EAX = Window
; In\	ESI = Text
; In\	CX/DX = X/Y pos
; In\	BX/DI = Width/Height
; In\	EBP = Pointer to color (low DWORD FG, high DWORD BG)
; Out\	EAX = component handle
align 4
xwidget_create_gbutton:
	mov [.window], eax
	mov [.text], esi
	mov [.x], cx
	mov [.y], dx
	mov [.width], bx
	mov [.height], di

	mov eax, [ebp]
	mov [.fg], eax
	mov eax, [ebp+4]
	mov [.bg], eax

	mov eax, [.window]
	call xwidget_find_component

	cmp eax, -1
	je .error

	mov [.component], eax

	; make a button
	mov byte[eax], XWIDGET_CPNT_GBUTTON
	mov edx, [.text]
	mov dword[eax+GBUTTON_TEXT], edx

	mov dx, [.x]
	mov [eax+GBUTTON_X], dx

	mov dx, [.y]
	mov [eax+GBUTTON_Y], dx

	mov dx, [.width]
	mov [eax+GBUTTON_WIDTH], dx

	mov dx, [.height]
	mov [eax+GBUTTON_HEIGHT], dx

	mov dx, [.x]
	add dx, [.width]
	mov [eax+GBUTTON_END_X], dx

	mov dx, [.y]
	add dx, [.height]
	mov [eax+GBUTTON_END_Y], dx

	mov edx, [.fg]
	mov [eax+GBUTTON_FG], edx

	mov edx, [.bg]
	mov [eax+GBUTTON_BG], edx

	; request a redraw
	mov eax, [.window]
	call xwidget_redraw

	mov eax, [.component]	; return the component
	ret

.error:
	mov eax, -1
	ret

align 4
.window				dd 0
.text				dd 0
.x				dw 0
.y				dw 0
.width				dw 0
.height				dw 0
.bg				dd 0
.fg				dd 0
.component			dd 0


