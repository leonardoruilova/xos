
;; xOS Text Editor
;; Copyright (c) 2017 by Omar Mohammad

use32
org 0x8000000		; programs are loaded to 128 MB, drivers to 2048 MB

application_header:
	.id			db "XOS1"	; tell the kernel we are a valid application
	.type			dd 0		; 32-bit application
	.entry			dd main		; entry point
	.reserved0		dq 0
	.reserved1		dq 0

	include			"libxwidget/src/libxwidget.asm"		; widget library ;)

	MAXIMUM_TEXT_SIZE	= 0x100000	; I doubt anyone has a 1 MB text file
						; TO-DO: auto-resize the buffer as text is entered

; xwidget_yield_handler:
; xwidget calls this every time it is idle

xwidget_yield_handler:
	ret

; main:
; Program entry point

main:
	; have to run this...
	call xwidget_init

	; make a window
	mov ax, 32
	mov bx, 32
	mov si, 720
	mov di, 480
	mov dx, 0
	mov ecx, window_title
	call xwidget_create_window
	mov [window_handle], eax

	mov ebp, XOS_MALLOC
	mov ecx, MAXIMUM_TEXT_SIZE
	int 0x60
	mov [text_limit.text], eax

	; make a textbox in the window
	mov eax, [window_handle]
	mov cx, 0
	mov dx, 32
	mov si, 720
	mov di, 480-32
	mov bl, XWIDGET_TEXTBOX_MULTILINE or XWIDGET_TEXTBOX_FOCUSED	; flags
	mov ebp, text_limit
	call xwidget_create_textbox

hang:
	call xwidget_wait_event
	cmp eax, XWIDGET_CLOSE
	je close
	jmp hang

close:
	call xwidget_destroy	; must call this before exit

	mov ebp, XOS_TERMINATE
	int 0x60

	jmp $


	; Data area
	align 4
	window_handle		dd 0
	textbox_handle		dd 0
	text_limit:
		.text		dd 0
		.limit		dd MAXIMUM_TEXT_SIZE

	text		db "HELLO!",0

	window_title		db "Text Editor",0


