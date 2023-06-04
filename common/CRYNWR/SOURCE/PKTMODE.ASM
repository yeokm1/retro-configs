version	equ	2

;  Copyright, 1989-1992, Russell Nelson, Crynwr Software

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
 db "Packet mode version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version," copyright 1990, Russell Nelson.",CR,LF
 db "This program is free software; see the file COPYING for details.",CR,LF
 db "NO WARRANTY; see the file COPYING for details.",CR,LF
crlf_msg	db	CR,LF,'$'

their_isr	dd	?
entry_point	db	?,?,?,?
packet_mode	dw	-1,?

handle		dw	0
this_mode	dw	?
bogus_type	db	0,0		;totally bogus type code.

signature	db	'PKT DRVR',0
signature_len	equ	$-signature
no_signature_msg	db	"No packet driver at that address",'$'
usage_msg	db	"usage: pktmode <packet_int_no> [<mode>]",'$'
bad_handle_msg	db	"Bad handle error",'$'
bad_mode_msg	db	"Bad mode error",'$'
bad_error_msg	db	"Unknown error",'$'

not_implemented	db	"no      ",'$'
current_mode	db	"current ",'$'
two_spaces	db	"yes     ",'$'

mode_names	dw	mode_1_msg,mode_2_msg,mode_3_msg,mode_4_msg
		dw	mode_5_msg,mode_6_msg,mode_7_msg

mode_1_msg	db	"1) Turn off receiver",CR,LF,'$'
mode_2_msg	db	"2) Receive only packets sent to this interface",CR,LF,'$'
mode_3_msg	db	"3) Mode 2 plus broadcast",CR,LF,'$'
mode_4_msg	db	"4) Mode 3 plus limited multicast",CR,LF,'$'
mode_5_msg	db	"5) Mode 3 plus all multicast",CR,LF,'$'
mode_6_msg	db	"6) All packets",CR,LF,'$'
mode_7_msg	db	"7) Raw mode",CR,LF,'$'


usage_error:
	mov	dx,offset usage_msg
error:
	mov	ah,9
	int	21h
	jmp	all_done

start_1:
	cld

	mov	dx,offset copyleft_msg
	mov	ah,9
	int	21h

	mov	si,offset phd_dioa+1
	cmp	byte ptr [si],CR	;end of line?
	je	usage_error

	mov	di,offset entry_point
	call	get_number
	mov	di,offset packet_mode
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
	je	signature_ok
	mov	dx,offset no_signature_msg
	jmp	error
bad_j_1:
	jmp	bad
signature_ok:

	mov	ax,1ffh			;driver_info
	call	int_pkt
	call	fatal_error

	mov	ah,2			;access all packets.
	mov	al,ch			;their class from driver_info().
	mov	bx,dx			;their type from driver_info().
	mov	dl,cl			;their number from driver_info().
	mov	cx,2			;use a type length of 2.
	mov	si,offset bogus_type
	movseg	es,cs
	mov	di,offset our_recv
	call	int_pkt
	call	fatal_error
	mov	handle,ax

	mov	cx,packet_mode
	cmp	cx,-1
	je	get_mode

	mov	ah,20			;set the receive mode.
	mov	bx,handle
	call	int_pkt
	jc	bad_j_1

	mov	bx,cx			;print the name of this mode.
	shl	bx,1
	mov	ah,9
	mov	dx,mode_names[bx-2]
	int	21h

	jmp	okay
;now print the current mode.

get_mode:
	mov	ah,21			;get the receive mode.
	mov	bx,handle
	call	int_pkt
	jc	bad
	mov	packet_mode,ax

	mov	this_mode,1		;start trying with mode 1.
try_mode:
	cmp	this_mode,6		;have we hit the last mode?
	ja	no_more_modes		;yes.

	mov	ah,20			;set the receive mode.
	mov	bx,handle
	mov	cx,this_mode
	call	int_pkt
	mov	dx,offset not_implemented
	jc	tried_mode		;we tried it, and it didn't work.
	mov	dx,offset current_mode
	mov	cx,this_mode		;is this the current mode?
	cmp	packet_mode,cx
	je	tried_mode
	mov	dx,offset two_spaces
tried_mode:
	mov	ah,9			;print either "  ", "xx", or "->"
	int	21h

	mov	bx,this_mode		;print the name of this mode.
	shl	bx,1
	mov	ah,9
	mov	dx,mode_names[bx-2]
	int	21h

	inc	this_mode		;try the next mode.
	jmp	try_mode

no_more_modes:

	mov	ah,20			;set the receive mode.
	mov	bx,handle
	mov	cx,packet_mode
	call	int_pkt

all_done:
	xor	bx,bx			;only release the handle once.
	xchg	bx,handle
	or	bx,bx
	je	all_done_1		;we've already released it.
	mov	ah,3			;release_type
	call	int_pkt
	jc	bad
all_done_1:
	int	20h

bad:
	call	print_error
okay:
	jmp	all_done


our_recv:
	or	ax,ax			;first or second call?
	jne	our_recv_1		;second -- we ignore the packet
	movseg	es,cs
	mov	di,offset our_buffer
our_recv_1:
	retf


int_pkt:
	push	ds
	push	es
	pushf
	cli
	call	their_isr
	pop	es
	pop	ds
	ret

	include	getnum.asm
	include	skipblk.asm
	include	getdig.asm
	include	pkterr.asm
	include	chrout.asm

	align	4
our_buffer	label	byte

code	ends

	end	start
