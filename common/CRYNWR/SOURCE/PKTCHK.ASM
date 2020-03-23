version	equ	1

;  Copyright, 1988-1992, Russell Nelson, Crynwr Software
;  Modified TERMIN.ASM to be PKTCHK.ASM return errorlevel, don't terminate
;	07/24/89 Glen Marianko, Albert Einstein College of Medicine

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
 db "Packet checker version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version," copyright 1990, Russell Nelson.",CR,LF
 db "This program is free software; see the file COPYING for details.",CR,LF
 db "NO WARRANTY; see the file COPYING for details.",CR,LF

their_isr	dd	?
entry_point	db	0,?,?,?
packet_int_end  db	0,?,?,?
signature	db	'PKT DRVR',0
signature_len	equ	$-signature
got_int		db	0
no_signature_msg	db	"Packet driver not found.",CR,LF,'$'
signature_msg	db	"Packet driver found at ",'$'
no_signatures_msg	db	"No packet driver found in specified range.",CR,LF,'$'
usage_msg	db	"usage: pktchk <packet_int_no> [<packet_int_no_end>]",CR,LF,'$'

usage_error:
	mov	dx,offset usage_msg
error:
	mov	ah,9
	int	21h
err_quit:
	mov	al,1
        mov     ah,04ch                 ; exit with errorlevel 1
        int     21h

start_1:
	mov	si,offset phd_dioa+1
	call	skip_blanks
	cmp	al,CR			;end of line?
	je	usage_error

	mov	di,offset entry_point
	call	get_number
	cmp	entry_point+1,0
	jne	usage_error

	mov	di,offset packet_int_end
	call	get_number
	cmp	packet_int_end+1,0
	jne	usage_error
	mov	di,si
	call	skip_blanks
	cmp	al,CR			;end of line?
	jne	usage_error

	cmp	packet_int_end,0
	jne	chk_range		; second arg specified

	call	chk_int
	jne	no_signature_err
	call	pkt_found
all_done:
	mov	al,0
	mov	ah,04ch
	int	21h			; exit with errorlevel 0

no_signature_err:
	mov	dx,offset no_signature_msg
	jmp	error

chk_range:
	mov	al,packet_int_end
	sub	al,entry_point
	jc	usage_error

chk_loop:
	call	chk_int
	jne	chk_none
	call	pkt_found
	inc	got_int			; flag we got one
chk_none:
	mov	al,entry_point
	cmp	packet_int_end,al
	jz	no_signatures_chk
	inc	entry_point		; increment
	jmp	chk_loop

no_signatures_chk:
	cmp	got_int,0
	jnz	all_done

no_signatures:
	mov	dx,offset no_signatures_msg
	jmp	error

	public	chk_int
chk_int:
	mov	ah,35h			;get their packet interrupt.
	mov	al,entry_point
	int	21h
	mov	their_isr.offs,bx
	mov	their_isr.segm,es
	lea	di,3[bx]
	mov	si,offset signature
	mov	cx,signature_len
	repe	cmpsb
	ret

	public	pkt_found
pkt_found:
	mov	dx,offset signature_msg
	mov	di,offset entry_point
	jmp	print_number

	include	getnum.asm
	include	skipblk.asm
	include	getdig.asm
	include	decout.asm
	include	digout.asm
	include	chrout.asm
	include	printnum.asm
	include	crlf.asm

code	ends

	end	start
