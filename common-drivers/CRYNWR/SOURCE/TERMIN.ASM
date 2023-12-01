version	equ	1

;  Copyright, 1988-1992, Russell Nelson, Crynwr Software

;   This program is free software; you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation, version 1.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License
;   along with this program; if not, write to the Free Software
;   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

	include	defs.asm

code	segment word public
	assume	cs:code, ds:code

	org	80h
phd_dioa	label	byte

	org	100h
start:
	jmp	start_1

copyleft_msg	label	byte
 db "Packet driver terminator version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version," copyright 1988-1992, Russell Nelson.",CR,LF
 db "This program is free software; see the file COPYING for details.",CR,LF
 db "NO WARRANTY; see the file COPYING for details.",CR,LF
crlf_msg	db	CR,LF,'$'

their_isr	dd	?
entry_point	db	?,?

handle		dw	?

bogus_type	db	0,0		;totally bogus type code.

signature	db	'PKT DRVR',0
signature_len	equ	$-signature

flagbyte	db	0
S_OPTION	equ	8

usage_msg		db	"usage: termin [-s] <packet_int_no>",'$'
no_signature_msg	db	"termin: no packet driver at that address",'$'
ok_msg			db	"termin: terminate completed",'$'

usage_error:
	mov	dx,offset usage_msg
error:
	mov	ah,9
	int	21h
	int	20h

start_1:
	cld

	mov	dx,offset copyleft_msg
	mov	ah,9
	int	21h

	mov	si,offset phd_dioa+1
	call	skip_blanks		;end of line?
	cmp	al,CR
	je	usage_error

chk_options:
	call   skip_blanks
	cmp	al,'-'			; any options?
	je	more_opt
	cmp	al,'/'
	jne	no_more_opt
more_opt:
	inc	si			; skip past option char
	lodsb				; read next char
	or	al,20h			; convert to lower case
	cmp	al,'s'
	jne	usage_error
	or	flagbyte,S_OPTION
	jmp	chk_options
no_more_opt:

	mov	di,offset entry_point
	call	get_number

	mov	ah,35h			;get their packet interrupt.
	mov	al,entry_point
	int	21h
	mov	their_isr.offs,bx
	mov	their_isr.segm,es

	lea	di,3[bx]
	mov	si,offset signature
	mov	cx,signature_len
	repe	cmpsb
	jne	no_signature_err

	mov	ax,1ffh			;driver_info
	call	int_pkt
	call	fatal_error

	mov	ah,2			;access_type
	mov	al,ch			;their class from driver_info().
	mov	bx,dx			;their type from driver_info().
	mov	dl,cl			;their number from driver_info().
	mov	cx,2			;use type length 2.
	mov	si,offset bogus_type
	movseg	es,cs
	mov	di,offset our_recv
	call	int_pkt
	call	fatal_error
	mov	handle,ax

	test	flagbyte,S_OPTION
	jz	not_stop
	mov	ah,8			; f_stop
	call	int_pkt
	jmp	now_done
not_stop:


	mov	ah,5			;terminate the driver.
	mov	bx,handle
	call	int_pkt
	jnc	now_close
	call	print_error
now_close:
	mov	ah,3			;release_type
	mov	bx,handle
	call	int_pkt
	jnc	now_done		;if ok, we're done.
	cmp	dh,BAD_HANDLE		;if it succeeded, we'll get a bad handle.
	je	now_done		;it worked.
	stc
	call	fatal_error
	int	20h
now_done:
        push    cs
        pop     ds
        lea     dx,ok_msg
        mov     ah,9
        int     21h
        int     20h


our_recv:
	or	ax,ax			;first or second call?
	jne	our_recv_1		;second -- we ignore the packet
	movseg	es,cs
	mov	di,offset our_buffer
our_recv_1:
	retf


no_signature_err:
	mov	dx,offset no_signature_msg
	mov	ah,9
	int	21h
	int	20h


int_pkt:
	push	ds
	push	es
	pushf
	cli
	call	their_isr
	pop	es
	pop	ds
	ret


	include	pkterr.asm
	include	getnum.asm
	include	skipblk.asm
	include	getdig.asm
	include	chrout.asm

our_buffer	label	byte

code	ends

	end	start
