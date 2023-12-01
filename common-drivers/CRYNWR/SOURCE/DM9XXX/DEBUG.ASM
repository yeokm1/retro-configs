

init_disp_flag	db	0
intr08_sem	db	0

attr		db	07h
debug_mode	db	0

disp_seg	dw	?
active_page	db	?
debug_page	db	?
cur_ptr 	dw	?
start_ptr	dw	?
end_ptr 	dw	?
ap_start_ptr	dw	?

pc_model	db	?
old_int08	dd	?
old_int09	dd	?
old_int10	dd	?
old_int13	dd	?

disk_busy	db	0
video_busy	db	0

key_request	db	?
hot_key 	db	?

debug_cnt	db	0

	PUBLIC	init_debug
init_debug     proc  near
	cmp	cs:init_disp_flag, 0
	je	do_initdisp
	ret
do_initdisp:
	push	ax
	push	bx
	push	cx
	push	dx

	; get current video mode
	mov	ah, 0Fh
	int	10h
;	int	11h

	mov	cs:disp_seg, 0B000H
	cmp	al, 7
	je	set_active_page
	mov	cs:disp_seg, 0B800H
set_active_page:
	mov	cs:active_page, bh

	xor	bl, bl
	xchg	bl, bh

	mov	ax, 4096
	mul	bx
	mov	cs:ap_start_ptr, ax

	inc	bl
	cmp	bl, 4
	jne	set_debug_page
	mov	bl, 0

set_debug_page:
	mov	cs:debug_page, bl

	mov	ax, 4096
	mul	bx
	mov	cs:start_ptr, ax
	mov	cs:cur_ptr, ax

	add	ax, 4000
	mov	cs:end_ptr, ax

	call	setup_intr

	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
init_debug     endp

	PUBLIC	b_char
b_char	proc  near
	push	ax
	push	bx
	push	es

	mov	ah, cs:attr
	mov	bx, cs:disp_seg
	mov	es, bx
	mov	bx, cs:cur_ptr
	mov	word ptr es:[bx], ax
	mov	al, '*'
	mov	word ptr es:[bx+2], ax
	add	bx, 2
	cmp	bx, cs:end_ptr
	jna	@F
	mov	bx, cs:start_ptr
	cmp	ah, 07h
	je	inver_attr
	mov	cs:attr, 07h
	jmp	@F
inver_attr:
	mov	cs:attr, 70h
@@:
	mov	cs:cur_ptr, bx

	pop	es
	pop	bx
	pop	ax
	ret
b_char	endp

debug_char_tab	db	'0123456789ABCDEF'

	PUBLIC	b_byte
b_byte	proc	near
	push	ax
	push	bx

	xor	bx, bx
	mov	ah, al
	mov	bl, ah
	shr	bl, 1
	shr	bl, 1
	shr	bl, 1
	shr	bl, 1
	mov	al, cs: debug_char_tab[bx]
	call	b_char
	mov	bl, ah
	and	bl, 0FH
	mov	al, cs: debug_char_tab[bx]
	call	b_char

	pop	bx
	pop	ax
	ret
b_byte	endp


;************************************************************************
;
; Display a character on the sreen with specified postiton and attribute
;
; Input:
;	DH = row (0 is top)
;	DL = column (0 is left)
;	BL = color attribute
;	AL = character
;
	PUBLIC	d_char
d_char	proc near
	push	es
	push	ax
	push	bx
	push	dx
	push	di

	mov	ah, bl
	push	ax		; save (character, attribute) in stack

	mov	al, 80
	mul	dh
	xor	dh, dh
	add	ax, dx
	shl	ax, 1

	mov	bx, cs:disp_seg
	mov	es, bx
	mov	bx, ax

	add	bx, cs:start_ptr

	pop	ax		; (AL, AH) = (character, attribute)
	mov	es:[bx], ax

	pop	di
	pop	dx
	pop	bx
	pop	ax
	pop	es
	ret
d_char	     endp

;************************************************************************
;
; Display a byte value in hexdecimal on the sreen
; with specified postiton and attribute
;
; Input:
;	DH = row (0 is top)
;	DL = column (0 is left)
;	BL = color attribute
;	AL = byte value
;
	PUBLIC	d_byte
d_byte	proc near
	push	ax
	push	cx

	xor	cx, cx
	mov	ah, al
	mov	cl, ah
	shr	cl, 1
	shr	cl, 1
	shr	cl, 1
	shr	cl, 1
	mov	al, cs: debug_char_tab[bx]
	call	d_char
	mov	cl, ah
	and	cl, 0FH
	mov	al, cs: debug_char_tab[bx]
	call	d_char

	pop	cx
	pop	ax
	ret
d_byte	endp

get_pc_model proc  near
	push	ds
	push	dx
	mov	cs:pc_model, 2
	stc
	mov	ah, 0c4h
	int	15h
	jnc	ps2_model			;PS2 model (50 or 80)
	mov	ax,0f000h
	mov	ds,ax
	cmp	byte ptr ds:[0fffeh], 0fch
	pop	dx
	pop	ds
	je	at_model
	mov	cs:pc_model, 1			;XT model
at_model:
	ret
ps2_model:
	pop	dx
	pop	ds
	ret
get_pc_model endp
;
;
DIS_KBD EQU	0adh
ENA_KBD EQU	0aeh
disable_keyboard proc
	push	ax
	cmp	cs:pc_model, 1
	je	is_xt_0
	mov	al, DIS_KBD
	call	ship_it
is_xt_0:
not_int9_bottom_0:
	pop	ax
	ret
disable_keyboard endp
;
;
enable_keyboard proc
	push	ax
	cmp	cs:pc_model, 1
	je	is_xt_1
	mov	al, ENA_KBD
	call	ship_it
is_xt_1:
not_int9_bottom_1:
	pop	ax
	ret
enable_keyboard endp
;
;
ship_it proc
	pushf
	push	cx
	push	ax
	cli
	sub	cx,cx
ship_1:
	in	al, 64h
	test	al, 02h
	loopnz	ship_1
	pop	ax
	pop	cx
	out	64h, al
	popf
	ret
ship_it endp


intr13	proc  far
	cli
	mov	cs:disk_busy, 1
	pushf
	call	cs:old_int13
	mov	byte ptr cs:disk_busy,0
	ret	2
intr13 endp

intr10	proc  far
	cli
	mov	byte ptr cs:video_busy, 1
	pushf
	call	cs:old_int10
	mov	byte ptr cs:video_busy, 0
	iret
intr10	endp

intr09	proc  far
	cli

	push	ax
	push	ds

	in	al, 60h

	cmp	al, 2bh 		; '|'
	jne	hook_old_intr09

	mov	cs:hot_key, al

	; Get keyboard flag from BIOS data
	push	ds
	mov	ax, 40h
	mov	ds, ax
	mov	al, ds:[17h]
	pop	ds

	mov	ah, al
	and	ah, 00001111b
	cmp	ah, 00001100b		; ALT_FLAG=08h, CTRL_FLAG=04h
	jne	hook_old_intr09

	mov	cs:key_request, 1

hook_old_intr09:
	cli
	pushf
	call	cs:old_int09

intr09_exit:
	cli

	pop	ds
	pop	ax

	iret
intr09	endp

intr08	proc far
	cli

	inc	cs:debug_cnt

	pushf
	call	cs:old_int08

	cli
	inc	cs:intr08_sem
	cmp	cs:intr08_sem, 1
	je	do_intr08

	iret

do_intr08:
	cli

	push	ds
	push	es

	push	ax
	push	bx
	push	cx
	push	dx

	push	cs
	pop	ds

;-- check if hot key pressed
;------------------------------------------------------------------------
	cmp	key_request, 0
	je	intr08_exit
	cmp	disk_busy, 1
	je	intr08_exit
	cmp	video_busy, 1
	je	intr08_exit

;-- hot key action here
;------------------------------------------------------------------------
	; toggle between debug/active page
	mov	cx, start_ptr
	cmp	debug_mode, 0
	je	toggle_page
	mov	cx, ap_start_ptr

toggle_page:
;;;;;	mov	ah, 05h
;;;;;	int	10h

	shr	cx, 1

	mov	dx, 03D4h
	mov	al, 12
	out	dx, al

	mov	dx, 03D5h
	mov	al, ch
	out	dx, al

	mov	dx, 03D4h
	mov	al, 13
	out	dx, al

	mov	dx, 03D5h
	mov	al, cl
	out	dx, al

	not	debug_mode

	mov	key_request, 0

intr08_exit:
	pop	dx
	pop	cx
	pop	bx
	pop	ax

	pop	es
	pop	ds

	cli
	mov	cs:intr08_sem, 0

	iret
intr08	endp

setup_intr	  proc	near
	push	ax
	push	bx
	push	cx
	push	dx

	push	ds
	push	es

	call	get_pc_model

	cli

	push	cs
	pop	ds

; setup INT 13
	mov	ax, 3513h
	int	21h
	mov	word ptr old_int13, bx
	mov	word ptr old_int13+2, es

	mov	ax, 2513h
	lea	dx, intr13
	int	21h

; setup INT 10
	mov	ax, 3510h
	int	21h
	mov	word ptr old_int10, bx
	mov	word ptr old_int10+2, es

	mov	ax, 2510h
	lea	dx, intr10
	int	21h

; setup INT 9
	mov	ax, 3509h
	int	21h
	mov	word ptr old_int09, bx
	mov	word ptr old_int09+2, es

	mov	ax, 2509h
	lea	dx, intr09
	int	21h

; setup INT 8
	mov	ax, 3508h
	int	21h
	mov	word ptr old_int08, bx
	mov	word ptr old_int08+2, es

	mov	ax, 2508h
	lea	dx, intr08
	int	21h

	sti

	pop	es
	pop	ds

	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
setup_intr  endp

