
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; CMOS Registers Index
CMOS_REGISTER_SECOND		= 0x00
CMOS_REGISTER_MINUTE		= 0x02
CMOS_REGISTER_HOUR		= 0x04
CMOS_REGISTER_DAY		= 0x07
CMOS_REGISTER_MONTH		= 0x08
CMOS_REGISTER_YEAR		= 0x09
CMOS_REGISTER_STATUS_A		= 0x0A
CMOS_REGISTER_STATUS_B		= 0x0B
CMOS_REGISTER_DEFAULT_CENTURY	= 0x32

cmos_century			db CMOS_REGISTER_DEFAULT_CENTURY	; should read this from acpi fadt..

; bcd_byte_to_dec:
; Converts a BCD byte to a decimal integer
; In\	AL = BCD
; Out\	AL = Decimal

bcd_byte_to_dec:
	mov [.bcd], al

	mov [.dec], al
	and [.dec], 0xF

	shr al, 4
	movzx eax, al
	mov ebx, 10
	mul ebx
	add [.dec], al

	mov al, [.dec]
	ret

.bcd				db 0
.dec				db 0

; cmos_read:
; Reads a CMOS register
; In\	CL = Index
; Out\	AL = Value

cmos_read:
	mov al, cl
	out 0x70, al
	call iowait
	in al, 0x71
	ret

; cmos_write:
; Writes to a CMOS register
; In\	AL = Value
; In\	CL = Index
; Out\	Nothing

cmos_write:
	push eax
	mov al, cl
	out 0x70, al
	call iowait
	pop eax
	out 0x71, al
	call iowait

	ret

; cmos_get_time:
; Returns the current time
; In\	Nothing
; Out\	AH:AL:BL = Hours:Minutes:Seconds

cmos_get_time:
	mov cl, CMOS_REGISTER_SECOND
	call cmos_read
	call bcd_byte_to_dec
	mov [.second], al

	mov cl, CMOS_REGISTER_MINUTE
	call cmos_read
	call bcd_byte_to_dec
	mov [.minute], al

	mov cl, CMOS_REGISTER_HOUR
	call cmos_read
	mov [.hour_bcd], al

	; check for 24 hour or 12 hour time
	mov cl, CMOS_REGISTER_STATUS_B
	call cmos_read
	test al, 2
	jnz .24_hour

.12_hour:
	; for 12 hour, determine AM or PM
	test [.hour_bcd], 0x80
	jnz .pm

.am:
	cmp [.hour_bcd], 0x12
	je .12_am

	mov al, [.hour_bcd]
	call bcd_byte_to_dec
	mov [.hour], al
	jmp .done

.12_am:
	mov [.hour], 0
	jmp .done

.pm:
	mov al, [.hour_bcd]
	and al, not 0x80	; mask off the highest bit
	call bcd_byte_to_dec
	add al, 12		; to PM
	mov [.hour], al
	jmp .done

.24_hour:
	mov al, [.hour_bcd]
	call bcd_byte_to_dec
	mov [.hour], al

.done:
	mov ah, [.hour]
	mov al, [.minute]
	mov bl, [.second]
	ret

.hour			db 0
.minute			db 0
.second			db 0
.hour_bcd		db 0



