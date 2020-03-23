version	equ	0

;History:239,1

;  Copyright 1990-1992, Russell Nelson, Crynwr Software

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
 db "Packet watcher version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version," copyright 1990-92, Russell Nelson.",CR,LF
 db "This program is free software; see the file COPYING for details.",CR,LF
 db "NO WARRANTY; see the file COPYING for details.",CR,LF
crlf_msg	db	CR,LF,'$'

their_isr	dd	?
entry_point	db	?,?,?,?
handle		dw	?

int_pkt:
	push	ds
	push	es
	pushf
	cli
	call	their_isr
	pop	es
	pop	ds
	ret

no_sig_msg	db	"No packet driver at that address",'$'
usage_msg	db	"usage: pktwatch <packet_int_no>",'$'

cursor_size	dw	?		;save the cursor size here.
cursor_locn	dw	?		;save the cursor location here.

address_switch	db	0
ether_addr	db	EADDR_LEN dup(-1)

usage_error:
	mov	dx,offset usage_msg
error:
	mov	ah,9
	int	21h
	int	20h

start_1:
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
	cmp	byte ptr [si+1],'a'	;did they specify '-a'?
	je	got_addr_switch
	jmp	usage_error		;no, must be an error.
got_addr_switch:

	add	si,2

	mov	di,offset ether_addr
	movseg	es,ds
	call	get_eaddr

	mov	address_switch,1
	jmp	another_switch
not_switch:
	call	skip_blanks
	cmp	al,CR
	jne	usage_error

	call	verify_packet_int
	jc	error
	mov	dx,offset no_sig_msg
	jne	error

	mov	their_isr.offs,bx
	mov	their_isr.segm,es

;save the current screen.
	push	ds
	mov	ax,0b800h
	mov	ds,ax
	xor	si,si
	movseg	es,cs
	mov	di,offset screen_buffer
	mov	cx,25*80
	rep	movsw
	pop	ds

	mov	ah,3			;get the current cursor position.
	mov	bh,0
	int	10h
	mov	cursor_size,cx
	mov	cursor_locn,dx

	mov	ah,1			;disable the hardware cursor.
	mov	cx,2000h
	int	10h

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

	mov	ah,20			;set receive mode.
	mov	bx,handle
	mov	cx,6			;receive all packets.
	call	int_pkt
	call	fatal_error

	mov	ah,0fh			;get the video mode.
	int	10h
	mov	ah,0			;set the video mode (clear the screen).
	int	10h

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
	call	int_pkt
	call	fatal_error

	mov	ah,3
	mov	bx,handle
	call	int_pkt
	call	fatal_error

	mov	ax,0b800h
	mov	es,ax
	xor	di,di
	mov	si,offset screen_buffer
	mov	cx,25*80
	rep	movsw

	mov	ah,1
	mov	cx,cursor_size
	int	10h

	mov	ah,2
	mov	bh,0
	mov	dx,cursor_locn
	int	10h

	mov	dx,offset copyleft_msg
	mov	ah,9
	int	21h

	int	20h


our_recv:
	or	ax,ax			;first or second call?
	jne	our_recv_1		;second -- bump the packet flag.
	movseg	es,cs
	mov	di,offset our_buffer
	retf
our_recv_1:
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	bp
	push	ds
	push	es

	cld

	mov	ax,cs
	mov	ds,ax
	mov	es,ax

	cmp	address_switch,0	;are we looking for an address?
	je	our_recv_save		;no.

	cmp	word ptr [si][0],-1	;always receive broadcasts.
	jne	our_recv_2
	cmp	word ptr [si][2],-1
	jne	our_recv_2
	cmp	word ptr [si][4],-1
	je	our_recv_save
our_recv_2:

	mov	di,offset ether_addr	;is the destination our address?
	mov	cx,EADDR_LEN/2
	repe	cmpsw
	je	our_recv_save		;yes, display it.

	add	si,cx			;move to source address.  CX is in
	add	si,cx			;  words, not bytes, so add it twice.
	mov	di,offset ether_addr	;is the source our address?
	mov	cx,EADDR_LEN/2
	rep	cmpsw
	jne	our_recv_exit		;no, skip it.

our_recv_save:
	call	receive
our_recv_exit:

	pop	es
	pop	ds
	pop	bp
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	retf

receive_ptr	dw	0

receive:
	mov	si,offset our_buffer	;get the "to" address.
	mov	ax,0b800h
	mov	es,ax
	mov	di,receive_ptr
	mov	bx,[si][EADDR_LEN][EADDR_LEN]
	xchg	bh,bl
	mov	ah,20h			;IP
	cmp	bx,800h
	je	receive_2
	mov	ah,30h			;ARP
	cmp	bx,806h
	je	receive_2
	mov	ah,40h			;Novell
	cmp	bx,8137h
	je	receive_2
	mov	ah,50h			;all IEEE 802.3
	cmp	bx,1500
	jbe	receive_2
	mov	ah,70h
receive_2:
	lodsb

	mov	bl,al
	shr	al,1
	shr	al,1
	shr	al,1
	shr	al,1

	and	al,0fh
	add	al,90h			;binary digit to ascii hex digit.
	daa
	adc	al,40h
	daa
	stosw

	mov	al,bl
	and	al,0fh
	add	al,90h			;binary digit to ascii hex digit.
	daa
	adc	al,40h
	daa
	stosw

	cmp	si,offset our_buffer+40	;can only dump first 40 bytes.
	loopne	receive_2

	add	receive_ptr,2*80

	cmp	receive_ptr,25*2*80
	jb	receive_1
	mov	receive_ptr,0
receive_1:
	mov	di,receive_ptr
	mov	cx,80
	mov	ax,0
	rep	stosw

	ret



	include	pkterr.asm
	include	getnum.asm
	include	getdig.asm
	include	skipblk.asm
	include	chrout.asm
	include	verifypi.asm
	include	getea.asm

	align	4
our_buffer	label	byte

screen_buffer	equ	our_buffer + GIANT + 2

code	ends

	end	start
