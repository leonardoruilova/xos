
;; xOS -- libxwidget 1
;; Copyright (c) 2017 by Omar Mohammad.

use32

	; component IDs
	XWIDGET_CPNT_NONE	= 0x00
	XWIDGET_CPNT_BUTTON	= 0x01
	XWIDGET_CPNT_LABEL	= 0x02
	XWIDGET_CPNT_TEXTBOX	= 0x03
	XWIDGET_CPNT_WINDOW	= 0x04
	XWIDGET_CPNT_GBUTTON	= 0x05

; 
; typedef struct window_component
; {
;	u8 id;		// XWIDGET_CPNT_WINDOW
;	u32 color;
;	u8 reserved[251];
; }
;
;

; xwidget_window_set_color:
; Sets the background color of a window
; In\	EAX = Window handle
; In\	EBX = Color
; Out\	Nothing

xwidget_window_set_color:
	shl eax, 3
	add eax, xwidget_windows_data
	mov eax, [eax+4]	; components
	mov [eax+1], ebx	; window color

	ret

; xwidget_find_component:
; Finds a free component
; In\	EAX = Window handle
; Out\	EAX = Pointer to component data, -1 on error
align 4
xwidget_find_component:
	shl eax, 3
	add eax, xwidget_windows_data
	mov ebx, [eax+4]

	cmp ebx, 0
	je .no

	mov eax, ebx
	add ebx, 256*256	; points to end of array

.loop:
	cmp byte[eax], XWIDGET_CPNT_NONE
	je .found

	add eax, 256
	cmp eax, ebx		; check array bounds
	jge .no

	jmp .loop

.found:
	ret

.no:
	mov eax, -1
	ret

; xwidget_redraw:
; Redraws a window with its components
; In\	EAX = Window handle
; Out\	Nothing
align 4
xwidget_redraw:
	shl eax, 3
	add eax, xwidget_windows_data

	mov ebx, [eax]
	mov [.handle], ebx	; kernel window handle
	mov ebx, [eax+4]
	mov [.components], ebx

	add ebx, 256*256
	mov [.components_end], ebx 

	; first clear the window
	mov ebp, XOS_WM_CLEAR
	mov eax, [.handle]
	mov edi, [.components]
	mov ebx, [edi+1]
	int 0x60

	; now start going through the components
	mov esi, [.components]

.loop:
	cmp esi, [.components_end]
	jge .quit

	;cmp byte[esi], XWIDGET_CPNT_NONE
	;je .skip

	cmp byte[esi], XWIDGET_CPNT_BUTTON
	je .draw_button

	cmp byte[esi], XWIDGET_CPNT_LABEL
	je .draw_label

	cmp byte[esi], XWIDGET_CPNT_GBUTTON
	je .draw_gbutton

.skip:
	add esi, 256
	jmp .loop

.draw_button:
	mov [.tmp], esi
	mov edi, esi		; EDI = button component

	mov esi, [edi+1]
	call xwidget_strlen
	shl eax, 3	; mul 8
	add eax, 32
	mov bx, 32
	mov cx, [edi+5]
	mov dx, [edi+7]
	mov esi, [xwidget_button_color]
	mov edi, [.handle]
	call xwidget_fill_rect

	mov edi, [.tmp]
	mov esi, [edi+1]
	mov ebx, 0
	mov cx, [edi+5]
	mov dx, [edi+7]
	add cx, 16
	add dx, 8
	mov eax, [.handle]
	mov ebp, XOS_WM_DRAW_TEXT
	int 0x60

	mov esi, [.tmp]
	add esi, 256
	jmp .loop

.draw_gbutton:
	mov [.tmp], esi
	mov edi, esi

	mov ax, [edi+GBUTTON_WIDTH]
	mov bx, [edi+GBUTTON_HEIGHT]
	mov cx, [edi+GBUTTON_X]
	mov dx, [edi+GBUTTON_Y]
	mov esi, [edi+GBUTTON_BG]
	mov edi, [.handle]
	call xwidget_fill_rect

	mov edi, [.tmp]
	mov esi, [edi+GBUTTON_TEXT]
	call xwidget_strlen

	shl eax, 2	; mul 8/2
	mov cx, [edi+GBUTTON_WIDTH]
	shr cx, 1
	;shr ax, 1
	sub cx, ax
	add cx, [edi+GBUTTON_X]

	mov dx, [edi+GBUTTON_HEIGHT]
	shr dx, 1
	sub dx, 8
	add dx, [edi+GBUTTON_Y]

	mov ebx, [edi+GBUTTON_FG]
	mov eax, [.handle]
	mov ebp, XOS_WM_DRAW_TEXT
	int 0x60

	mov esi, [.tmp]
	add esi, 256
	jmp .loop

.draw_label:
	mov [.tmp], esi

	mov ebp, XOS_WM_DRAW_TEXT
	mov eax, [.handle]
	mov cx, [esi+5]
	mov dx, [esi+7]
	mov ebx, [esi+9]
	mov edi, esi
	mov esi, [edi+1]
	int 0x60

	mov esi, [.tmp]
	add esi, 256
	jmp .loop

.quit:
	; request a redraw from the kernel
	mov ebp, XOS_WM_REDRAW
	int 0x60
	ret

align 4
.handle			dd 0
.components		dd 0
.components_end		dd 0
.tmp			dd 0

; xwidget_destroy_component:
; Destroys a component on a window
; In\	EAX = Window handle
; In\	EBX = Component handle
; Out\	Nothing

xwidget_destroy_component:
	push eax

	mov edi, ebx
	xor al, al
	mov ecx, 256
	rep stosb

	pop eax
	call xwidget_redraw
	ret


