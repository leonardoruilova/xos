
;; xOS -- libxwidget 1
;; Copyright (c) 2017 by Omar Mohammad.

use32

;
; typedef struct textbox_component
; {
;	u8 id;			// XWIDGET_CPNT_TEXTBOX
;	u8 flags;		// described below
;	u16 x;
;	u16 y;
;	u16 width;
;	u32 text;
;	u8 reserved[242];
; } textbox_component;
;

XWIDGET_TEXTBOX_ID		= 0x00
XWIDGET_TEXTBOX_FLAGS		= 0x01
XWIDGET_TEXTBOX_X		= 0x02
XWIDGET_TEXTBOX_Y		= 0x04
XWIDGET_TEXTBOX_WIDTH		= 0x06
XWIDGET_TEXTBOX_TEXT		= 0x08

; Flags
XWIDGET_TEXTBOX_FOCUSED		= 0x01

; xwidget_create_textbox:
; Creates a textbox
; In\	EAX = Window handle
; In\	CX/DX = X/Y pos
; In\	SI/DI = Width/Height
; In\	EBX = Pointer to text
; Out\	EAX = Component handle
align 4
xwidget_create_textbox:


