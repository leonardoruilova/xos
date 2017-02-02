
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; floor:
; Returns the greatest integer equal to or less than the parameter
; In\	XMM0 = Double precision number
; Out\	EAX = Integer

floor:
	cvtsd2si eax, xmm0
	ret


