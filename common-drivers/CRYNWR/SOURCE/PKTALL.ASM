version	equ	0

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

code	segment para public
	assume	cs:code, ds:code

	org	80h
phd_dioa	label	byte

	org	100h
start:
	jmp	start_1

copyleft_msg	label	byte
 db "Packet receiver version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version," copyright 1990, Russell Nelson.",CR,LF
 db "This program is free software; see the file COPYING for details.",CR,LF
 db "NO WARRANTY; see the file COPYING for details.",CR,LF
crlf_msg	db	CR,LF,'$'

their_isr	dd	?
their_mode	dw	?
entry_point	db	?,?,?,?
handle		dw	?

no_signature_msg	db	"No packet driver at that address",'$'
usage_msg	db	"usage: pktall <packet_int_no> [-v] [-p] [-a <enet_addr>]",'$'
waiting_msg	label	byte
	db	"Now waiting for packets to be received.  Press any key to exit.",CR,LF,'$'

verbose_switch	db	0
pro_switch	db	0
address_switch	db	0
ether_addr	db	EADDR_LEN dup(-1)

queue_overflow	dw	0

usage_error:
	mov	dx,offset usage_msg
error:
	mov	ah,9
	int	21h
	int	20h

start_1:
	mov	dx,offset copyleft_msg
	mov	ah,9
	int	21h

	mov	si,offset phd_dioa+1
	cmp	byte ptr [si],CR	;end of line?
	je	usage_error

	mov	di,offset entry_point
	call	get_number

another_switch:
	call	skip_blanks
	cmp	al,'-'			;did they specify a switch?
	je	have_switch
	jmp	not_switch
have_switch:
	cmp	byte ptr [si+1],'v'	;did they specify '-v'?
	je	got_verbose_switch
	cmp	byte ptr [si+1],'p'	;did they specify '-p'?
	je	got_pro_switch
	cmp	byte ptr [si+1],'a'	;did they specify '-a'?
	je	got_addr_switch
	jmp	usage_error		;no, must be an error.
got_pro_switch:
	add	si,2
	mov	pro_switch,1
	jmp	another_switch
got_verbose_switch:
	add	si,2
	mov	verbose_switch,1
	jmp	another_switch
got_addr_switch:

	add	si,2

	mov	di,offset ether_addr
	movseg	es,ds
	call	get_eaddr

	mov	address_switch,1
	mov	pro_switch,1		;-a implies -p.
	jmp	another_switch
not_switch:
	call	skip_blanks
	cmp	al,CR
	jne	usage_error

	call	queue_init

	call	verify_packet_int
	jc	error
	mov	dx,offset no_signature_msg
	jne	error

	mov	their_isr.offs,bx
	mov	their_isr.segm,es

	mov	ax,1ffh			;driver_info
	call	int_pkt
	call	fatal_error

	mov	ah,2			;access all packets.
	mov	al,ch			;their class from driver_info().
	mov	bx,dx			;their type from driver_info().
	mov	dl,cl			;their number from driver_info().
	mov	cx,0			;type length of zero.
	movseg	es,cs
	mov	di,offset our_recv
	call	int_pkt
	call	fatal_error
	mov	handle,ax

	mov	ah,21			;get the receive mode.
	mov	bx,handle
	call	int_pkt
	call	fatal_error
	mov	their_mode,ax

	cmp	pro_switch,0
	je	not_pro

	mov	ah,20			;set it to promiscuous mode.
	mov	bx,handle
	mov	cx,6
	call	int_pkt
	call	fatal_error
not_pro:

	mov	dx,offset waiting_msg
	mov	ah,9
	int	21h

wait_for_key:
	cmp	queue_overflow,0	;did we drop a packet?
	je	not_overflow
	mov	queue_overflow,0
	mov	al,'O'
	call	chrout
not_overflow:

	call	queue_pull
	jc	no_packet

	cmp	verbose_switch,0
	je	not_verbose
	call	dump_hex
	call	crlf
	jmp	short no_packet
not_verbose:
	mov	al,'R'
	call	chrout

no_packet:
	mov	ah,1			;check for any key.
	int	16h
	je	wait_for_key		;no key -- keep waiting.

	mov	ah,0			;fetch the key.
	int	16h

	mov	ah,20			;reset the receive mode.
	mov	bx,handle
	mov	cx,their_mode
	call	int_pkt

	mov	ah,3
	mov	bx,handle
	call	int_pkt
	call	fatal_error

	int	20h

	assume	ds:nothing

our_recv:
	push	ds
	push	cs
	pop	ds
	or	ax,ax			;first or second call?
	jne	our_recv_1		;second -- bump the packet flag.
	movseg	es,cs
	call	queue_push
	jnc	our_recv_exit
	inc	queue_overflow
	xor	di,di
	mov	es,di
	jmp	short our_recv_exit
our_recv_1:
	cmp	address_switch,0	;are we looking for an address?
	je	our_recv_exit		;no.
	push	es
	push	di
	push	si
	mov	ax,cs
	mov	es,ax
	mov	di,offset ether_addr	;is the destination our address?
	mov	cx,EADDR_LEN/2
	repe	cmpsw
	je	our_recv_2
	add	si,cx			;move to source address.
	mov	di,offset ether_addr	;is the source our address?
	mov	cx,EADDR_LEN/2
	rep	cmpsw
our_recv_2:
	pop	si
	pop	di
	pop	es
	je	our_recv_exit		;yes.

	cmp	word ptr [si][0],-1	;always receive broadcasts.
	jne	our_recv_drop
	cmp	word ptr [si][2],-1
	jne	our_recv_drop
	cmp	word ptr [si][4],-1
	je	our_recv_exit
our_recv_drop:
	call	queue_unpush
our_recv_exit:
	pop	ds
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

	include	queue.asm
	include	pkterr.asm
	include	getnum.asm
	include	getdig.asm
	include	skipblk.asm
	include	digout.asm
	include	chrout.asm
	include	verifypi.asm
	include	getea.asm
	include	dumphex.asm
	include	crlf.asm

	align	4
queue_begin	label	byte

code	ends

	end	start
