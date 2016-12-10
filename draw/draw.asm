
; Draw Application for xOS
; Lets the user draw on the window by clicking and dragging

use32
org 0x8000000		; programs are loaded to 128 MB, drivers to 2048 MB

application_header:
	.id			db "XOS1"	; tell the kernel we are a valid application
	.type			dd 0		; 32-bit application
	.entry			dd main		; entry point
	.reserved0		dq 0
	.reserved1		dq 0

; Window Manager Events
WM_LEFT_CLICK			= 0x0001
WM_RIGHT_CLICK			= 0x0002
WM_KEYPRESS			= 0x0004

main:
	mov ebp, 0		; create the window
	mov ax, 8
	mov bx, 8
	mov si, 256
	mov di, 256
	mov dx, 0
	mov ecx, title
	int 0x60

	; eax = window handle
	mov [window_handle], eax

.wait:
	; wait for window event
	mov ebp, 4
	mov eax, [window_handle]
	int 0x60

	test ax, WM_LEFT_CLICK
	jnz .got_event		; if the user clicked, read the mouse status

	mov ebp, 1
	int 0x60
	jmp .wait

.got_event:
	mov ebp, 5		; read mouse status
	mov eax, [window_handle]
	int 0x60

	jcxz .check_zero
	jmp .work

.check_zero:
	cmp dx, 0
	je .wait

.work:
	mov ebp, 2		; get pixel offset
	mov eax, [window_handle]
	int 0x60

	cmp eax, -1
	je .wait

	mov edi, eax
	mov eax, 0
	stosd			; put four pixels
	stosd
	stosd
	stosd
	jmp .wait

	title			db "Draw",0
	window_handle		dd 0




