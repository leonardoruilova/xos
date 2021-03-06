
; Default Window Theme ;)

align 4
wm_color			dd 0x808080
;wm_color			dd 0x004288
window_title			dd 0xFFFFFF
window_inactive_title		dd 0xC0C0C0
window_border			dd 0x303030
window_active_border		dd 0x303030
window_active_outline		dd 0x00A2E8
window_close_color		dd 0xD80000
window_background		dd 0xD0D0D0
window_opacity			db 1		; valid values are 0 to 4, 0 = opaque, 1 = less transparent, 4 = most transparent.

align 4
window_border_x_min		dw 0		; min x pos for a 0 width window
window_border_y_min		dw 24		; min y pos for a 0 height window
window_close_position		db 0		; 0 = left, 1 = right, for now this has no effect

align 4
window_close_x			dw 4
window_close_y			dw 4
window_close_width		dw 16
window_close_height		dw 16

window_title_x			dw 24
window_title_y			dw 4
window_canvas_x			dw 0
window_canvas_y			dw 24

