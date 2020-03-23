version	equ	1

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
 db "Packet address version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version," copyright 1990, Russell Nelson.",CR,LF
 db "This program is free software; see the file COPYING for details.",CR,LF
 db "NO WARRANTY; see the file COPYING for details.",CR,LF
crlf_msg	db	CR,LF,'$'

their_isr	dd	?
entry_point	db	?,?,?,?
ether_bdcst	db	EADDR_LEN dup(-1)	;ethernet broadcast address.
brd_ether_addr	db	EADDR_LEN dup(-1)	;board's ethernet address
our_ether_addr	db	EADDR_LEN dup(-1)	;our ethernet address

errorlevel	db	0		;result to return when we quit.
check_switch	db	0		;=1 if to compare against a given address.

handle		dw	?

bogus_type	db	0,0		;totally bogus type code.

signature	db	'PKT DRVR',0
signature_len	equ	$-signature
no_signature_msg	db	"No packet driver at that address",'$'
usage_msg	db	"usage: pktaddr [-c] <packet_int_no> [<addr>]",'$'

eaddr_msg	db	"My Ethernet address is ",'$'
mismatch_msg	db	"Address mismatch",CR,LF,'$'

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
	cmp	byte ptr [si],CR	;end of line?
	je	usage_error

another_switch:
	call	skip_blanks
	cmp	al,'-'			;did they specify a switch?
	je	have_switch
	jmp	not_switch
have_switch:
	cmp	byte ptr [si+1],'c'	;did they specify '-c'?
	je	got_check_switch
	jmp	usage_error		;no, must be an error.
got_check_switch:
	mov	check_switch,1
	add	si,2
	jmp	another_switch
not_switch:

	mov	di,offset entry_point
	call	get_number

	mov	di,offset our_ether_addr
	movseg	es,ds
	call	get_eaddr

	mov	ah,35h			;get their packet interrupt.
	mov	al,entry_point
	int	21h
	mov	their_isr.offs,bx
	mov	their_isr.segm,es

	lea	di,3[bx]
	mov	si,offset signature
	mov	cx,signature_len
	repe	cmpsb
	je	have_signature
	mov	dx,offset no_signature_msg
	jmp	error
have_signature:

	cmp	check_switch,0		;in check mode, we get the address,
	jne	get_mode		;  then compare.

	movseg	es,ds
	mov	cx,EADDR_LEN
	mov	si,offset our_ether_addr
	mov	di,offset ether_bdcst
	repe	cmpsb
	je	get_mode		;no address specified.

	mov	ah,25			;set the ethernet address.
	mov	di,offset our_ether_addr
	mov	cx,EADDR_LEN
	call	int_pkt
	call	fatal_error
	jmp	okay
get_mode:
	mov	ah,2			;access all packets.
	mov	al,1			;Ethernet class.
	mov	bx,-1			;generic type.
	mov	dl,0			;generic number.
	mov	cx,2			;use a type length of 2
	mov	si,offset bogus_type
	movseg	es,cs
	mov	di,offset our_recv
	call	int_pkt
	call	fatal_error
	mov	handle,ax

	mov	ah,6			;get the ethernet address.
	mov	di,offset brd_ether_addr
	mov	cx,EADDR_LEN
	mov	bx,handle
	call	int_pkt
	jc	bad

	mov	dx,offset eaddr_msg
	mov	ah,9
	int	21h

	mov	si,offset brd_ether_addr
	call	print_ether_addr

	mov	dx,offset crlf_msg	;can't depend on DOS to newline for us.
	mov	ah,9
	int	21h

	cmp	check_switch,0
	je	now_close

	movseg	es,ds
	mov	cx,EADDR_LEN
	mov	si,offset our_ether_addr
	mov	di,offset brd_ether_addr
	repe	cmpsb
	je	now_close		;yes, addresses are equal, return zero.

	mov	errorlevel,1		;different - return 1.

	mov	dx,offset mismatch_msg
	mov	ah,9
	int	21h

	jmp	short now_close
bad:
	call	print_error
	mov	errorlevel,2
now_close:
	mov	ah,3			;release_type
	mov	bx,handle
	call	int_pkt
	call	fatal_error

okay:
	mov	ah,4ch
	mov	al,errorlevel
	int	21h

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

	include	printea.asm

	assume	ds:code

	include	pkterr.asm
	include	getea.asm
	include	getnum.asm
	include	skipblk.asm
	include	getdig.asm
	include	digout.asm
	include	chrout.asm

	align	4
our_buffer	label	byte

code	ends

	end	start
