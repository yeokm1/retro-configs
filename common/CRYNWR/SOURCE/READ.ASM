	COM EQU 1
	EXE EQU 2
	FILE_TYPE EQU EXE
	PKT_INT	EQU 7eh

DARK_BACK	equ 3H
SAVE_ALL	MACRO
		push	ax
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		push	bp
		push	ds
		push	es
	ENDM

UNSAVE_ALL	MACRO
		pop		es
		pop		ds
		pop		bp
		pop		di
		pop		si
		pop		dx
		pop		cx
		pop		bx
		pop		ax
	ENDM

code	segment word public
	assume	cs:code, ds:code
	org	100h
start:
;	call	hold_it
	mov		ax, cs
	mov		ds, ax
	mov		es, ax
	call	test_it
	xor		ax, ax
	mov		count, ax
	mov		cx, 0F00h
send_more:
	call	send_it
;	cmp		cx, 0C30h
;	je		fred2
fred1:
	jc		send_problem
	loop	send_more
send_problem:
	call	hold_it
fred2:
	jmp		fred1


	public	send_it
send_it	PROC	NEAR
	push	cx
	mov	cx, 400h
;	mov	cx, count
	inc	count
	mov	ax, cs
	mov	ds, ax
	mov	si, offset ether_pack
	mov	ah, 04h
	int	PKT_INT
	pop	cx
	ret
send_it	ENDP


	public	test_it
test_it	PROC	NEAR
if	FILE_TYPE EQ COM
	ret
endif
	mov		ax,1ffh			;driver_info
	int		PKT_INT
	mov		ah,2			;access all packets.
	mov		al,ch			;their class from driver_info().
	mov		bx,dx			;their type from driver_info().
	mov		dl,cl			;their number from driver_info().
	mov		cx,0			;type length of zero.
	mov		di, offset give_buffer
	int		PKT_INT
	mov		handle,ax

	mov		ah,20			;set receive mode.
	mov		bx,handle
	mov		cx,6			;receive all packets.
	int		PKT_INT

wait_for_key:
	mov	ah,1			;check for any key.
	int	16h
	je	wait_for_key		;no key -- keep waiting.

	mov	ah,0			;fetch the key.
	int	16h

all_done:

	mov	ah,20			;set receive mode.
	mov	bx,handle
	mov	cx,3			;receive ours + broadcasts.
	int		PKT_INT

	mov	ah,3
	mov	bx,handle
	int		PKT_INT

	int	20h

;	call	setup_reads
	call	hold_it

	mov		cx, 2
send_again:
	call	send_it
	loop	send_again
	call	send_it
	call	send_it
	call	hold_it
test_it	ENDP

	public	setup
setup	PROC	NEAR
	call	setcmd
	ret
setup	ENDP

	public mark_it
mark_it	PROC	NEAR
	ret
mark_it	ENDP

	public hold_it
hold_it	PROC	NEAR
hold_up:
	jmp	hold_up
	ret
hold_it	ENDP

	public setcmd
setcmd PROC	NEAR
if FILE_TYPE EQ EXE
	mov		ax, cs
	mov		ds, ax
	mov		es, ax
	mov		cx, offset ether_pack - offset cmd_string
;extrn phd_dioa : byte
;	mov		di, offset phd_dioa+1
	mov		si, offset cmd_string
	rep		movsb
endif
;	call	waste_time
	ret
setcmd	ENDP


CR	equ	0dh
LF	equ	0ah
handle		dw ?
hexout_color	db	70h
base_addr	dw	300h
byte_count	dw	0
buff_ptr	dw	offset	big_buffer
small_buffer	db	100h dup (33h)
cmd_string	db " 100 5 0x300 12:13:14:15:16:17",CR,LF,0,0,0,0,0,0,0
;cmd_string	db " -u 100 5 0x300 12:13:14:15:16:17",CR,LF,0,0,0,0,0,0,0
dummy_str	db "*********************"
big_buffer	db	300h dup (0h)
count		dw	0
padding		dw, 00, 00,00,00
ether_pack	db 255, 255, 255, 255, 255, 255
			db 	6, 5, 4, 3, 2, 1
			db 10, 10
			db 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
			db 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
			db 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
			db 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
			db 77h, 77h, 77h, 77h, 77h, 77h, 77h, 77h, 77h,77h	
			db 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
			db 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
			db 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
			db 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
			db 1, 2, 3, 4, 5, 6, 7, 8, 9, 10

setup_reads	PROC	NEAR
		mov		ax, cs
		mov		es, ax
		mov		di, offset give_buffer
		mov		ah, 02h		; Access_type function
		mov		al, 01h		; Bluebook
;		mov		al, 03h		; IEEE8025
;		mov		al, 11		; IEEE8023
		mov		bx, -1
		mov		cx, 00h		; Type length
		mov		dl, 00h
		SAVE_ALL
		cld
		mov		bp,sp			;we use bp to access the original regs.
		int		PKT_INT
		UNSAVE_ALL
		ret
setup_reads	ENDP

give_buffer:
		cmp		ax, 00h
		jne		got_it
		mov		ax, cs
		mov		es,	ax
		mov		di, offset small_buffer
		retf
got_it:
		add		byte_count, cx
		push	cx
		mov		di, buff_ptr
		rep		movsb
		pop		cx
		mov		ax, cx
		stosw
		mov		cx, 8h
		mov		si, offset dummy_str
		rep		movsb
		mov		buff_ptr, di
		cmp		byte_count, 240h
		jl		not_yet
		call	dump_hexout
		mov		byte_count, 0
		mov		buff_ptr, offset big_buffer
not_yet:
		retf

		public	waste_time
waste_time	PROC	NEAR
		SAVE_ALL
		mov		dx, 1h
waste0:
;		mov		cx, 0ffffh
		mov		cx, 0fffh
waste1:
		SAVE_ALL
		UNSAVE_ALL
		loop	waste1
		dec		dx
		jnz		waste0
		UNSAVE_ALL
		ret
waste_time	ENDP
	
dump_hexout:
	push	ax
	push	cx
	push	es
	push	di
	mov		di, 0b850h
	mov		es, di
	mov		ah, cs:hexout_color
	mov		di, 0
	mov		cx, byte_count
	mov		si, offset big_buffer
dump1:
	lodsb
	push	ax
	shr		al, 4
	and		al, 0Fh
	add		al, '0'
	cmp		al, '9'
	jbe		dump2
	add		al, 'A' - '9' - 1
dump2:
	mov	ah,DARK_BACK
	stosw
	pop		ax
	and		al, 0Fh
	add		al, '0'
	cmp		al, '9'
	jbe		dump3
	add		al, 'A' - '9' - 1
dump3:
	mov	ah,DARK_BACK
	stosw
	loop	dump1
	pop		di
	pop		es
	pop		cx
	pop		ax
	ret


code	ENDS

		END	start
