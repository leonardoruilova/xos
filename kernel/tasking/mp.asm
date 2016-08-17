
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

; spinlock_aqcuire:
; Aqcuires the spinlock
; In\	EAX = Address of spinlock byte
; Out\	Nothing

spinlock_aqcuire:
	bt byte[eax], 0			; if the spinlock is already aqcuired --
	jc spinlock_acquire		; -- wait for it to be released
	lock bts byte[eax], 0
	jc spinlock_acquire
	;clflush [eax]
	pause
	ret

; spinlock_release:
; Releases the spinlock
; In\	EAX = Address of spinlock byte
; Out\	Nothing

spinlock_release:
	btr byte[eax], 0
	;clflush [eax]
	pause
	ret



