	COM EQU 1
	EXE EQU 2
	FILE_TYPE EQU COM


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

cgroup	group code, _text, init

code	segment para public 'code'
	assume	cs:cgroup, ds:cgroup
	
	public	setup
setup	PROC	NEAR
	call	setcmd
	ret
setup	ENDP

	public mark_it
mark_it	PROC	NEAR
	ret
mark_it	ENDP


	public	send_it
send_it	PROC	NEAR
	push	cx
	mov	cx, 40h
	mov	ax, cs
	mov	ds, ax
	mov	si, offset ether_pack
	mov	ah, 04h
	int	100
	pop	cx
	ret
send_it	ENDP


	public	test_it
test_it	PROC	NEAR
if	FILE_TYPE EQ COM
	ret
endif

	call	setup_reads
	call	hold_it

	mov		cx, 2
send_again:
	call	send_it
	loop	send_again
	call	send_it
	call	send_it
	call	hold_it
test_it	ENDP

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
extrn phd_dioa : byte
	mov		di, offset phd_dioa+1
	mov		si, offset cmd_string
	rep		movsb
endif
;	call	waste_time
	ret
setcmd	ENDP


CR	equ	0dh
LF	equ	0ah
small_buffer	db	100h dup (33h)
cmd_string	db " 100 5 0x300 12:13:14:15:16:17",CR,LF,0,0,0,0,0,0,0
;cmd_string	db " -u 100 5 0x300 12:13:14:15:16:17",CR,LF,0,0,0,0,0,0,0
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
		mov		bx, -1
		mov		cx, 00h		; Type length
		mov		dl, 00h
		SAVE_ALL
		cld
		mov		bp,sp			;we use bp to access the original regs.
		int		100
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

code	ENDS

_text	segment para public 'code'
_text	ends

init	segment para public 'code'
init	ends

		END
