
;; xOS Shell
;; Copyright (c) 2017 by Omar Mohammad, all rights reserved.

use32
org 0x8000000

application_header:
	.id			db "XOS1"	; tell the kernel we are a valid application
	.type			dd 0		; 32-bit application
	.entry			dd main		; entry point
	.reserved0		dq 0
	.reserved1		dq 0

	title			db "xOS Shell",0

	include			"libxwidget/src/libxwidget.asm"		; widget library ;)

main:
	call xwidget_init

	mov ebp, XOS_GET_SCREEN_INFO
	int 0x60
	mov [width], ax
	mov [height], bx

	mov ax, 0
	mov bx, [height]
	sub bx, 32
	mov si, [width]
	mov di, 32
	mov dx, WM_TRANSPARENT
	mov ecx, title
	call xwidget_create_window
	mov [window_handle], eax

	mov eax, [window_handle]
	mov cx, 0
	mov dx, 0
	mov esi, menu_text
	call xwidget_create_button
	mov [menu_handle], eax

.hang:
	call xwidget_wait_event
	cmp eax, XWIDGET_BUTTON
	je .button
	jmp .hang

.button:
	cmp ebx, [menu_handle]
	je .menu

	jmp .hang

.menu:
	cli
	hlt

	; screen resolution
	align 2
	width			dw 0
	height			dw 0

	align 4
	window_handle		dd 0
	menu_handle		dd 0

	menu_text		db "MENU",0

