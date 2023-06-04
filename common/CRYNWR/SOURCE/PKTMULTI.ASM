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
 db "Packet multicast version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version," copyright 1990, Russell Nelson.",CR,LF
 db "This program is free software; see the file COPYING for details.",CR,LF
 db "NO WARRANTY; see the file COPYING for details.",CR,LF
crlf_msg	db	CR,LF,'$'

their_isr	dd	?
entry_point	db	?,?
handle		dw	?
their_es	dw	?

multi_count	dw	-1		;default to not setting any.

signature	db	'PKT DRVR',0
signature_len	equ	$-signature

no_signature_msg	db	"No packet driver at that address",'$'
usage_msg	db	"usage: pktmulti <packet_int_no> [-f <filename> | <address> ...]",'$'
file_not_found	db	"File not found",'$'
read_trouble	db	"Trouble reading the file",'$'

line_buffer	db	128 dup(?)

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
	call	skip_blanks
	cmp	al,CR			;end of line?
	je	usage_error

	mov	di,offset entry_point
	call	get_number

	call	skip_blanks
	cmp	al,CR			;did they just give an interrupt?
	jne	have_arguments
	jmp	start_noset		;yes, don't set any addresses.
have_arguments:

	mov	al,[si]			;did the give the packet inline?
	cmp	al,'-'			;did they specify a switch?
	jne	not_switch
	cmp	byte ptr [si+1],'f'	;did they specify '-f'?
	jne	usage_error		;no, must be an error.
	add	si,2
	call	skip_blanks
	jmp	start_file
not_switch:
	jmp	start_inline		;yes.

start_file:
	mov	dx,si			;remember where the filename starts.
start_3:
	lodsb
	cmp	al,' '
	je	start_4
	cmp	al,CR
	jne	start_3
start_4:
	dec	si
	mov	byte ptr [si],0

;read the packet bytes from the named file.

	mov	ax,3d00h		;open for reading.
	int	21h
	mov	dx,offset file_not_found
	jc	error
	mov	handle,ax

	mov	di,offset our_buffer
start_line:
	mov	si,offset line_buffer
again_line:
	mov	ah,3fh			;read a single character.
	mov	bx,handle
	mov	cx,1
	mov	dx,si
	int	21h
	mov	dx,offset read_trouble
	jc	error
	cmp	ax,1			;did we actually read one?
	jne	start_file_eof

	lodsb				;get the character we just read.
	cmp	al,LF			;got the LF?
	jne	again_line		;no, read again.

	mov	si,offset line_buffer
again_chars:
	movseg	es,ds
	call	get_eaddr		;get_eaddr increments di.
	call	skip_blanks
	cmp	al,CR
	jne	again_chars		;keep going to the end.

	jmp	start_line

start_file_eof:
	mov	[si],byte ptr CR	;add an extra LF, just in case.
	mov	si,offset line_buffer	;and get the last address, just
	movseg	es,ds
	call	get_eaddr		;  in case they didn't CRLF after it.
start_file_1:
	mov	ah,3eh			;close the file.
	mov	bx,handle
	int	21h
	jmp	short start_gotit

start_inline:
;read the multicast addresses off the command line.
	mov	di,offset our_buffer
start_2:
	movseg	es,ds
	call	get_eaddr		;get an address.
	call	skip_blanks
	cmp	al,CR
	jne	start_2			;keep going to the end.

start_gotit:

	sub	di,offset our_buffer
	mov	multi_count,di

start_noset:

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
	jmp	no_signature_err
signature_ok:

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

	cmp	multi_count,-1		;should we not set any?
	je	just_print		;yes, just print the current list.

	mov	ah,22			;set_multicast_list
	movseg	es,ds
	mov	di,offset our_buffer	;ds:si -> buffer.
	mov	cx,multi_count
	call	int_pkt
	call	print_error

just_print:
	mov	ah,23			;get_multicast_list
	call	int_pkt
	call	print_error

	push	ds
	mov	ds,their_es
	mov	si,di
	jmp	short print_countdown
print_another_address:
	push	cx

	call	print_ether_addr

	push	ds
	mov	ax,cs
	mov	ds,ax
	mov	dx,offset crlf_msg
	mov	ah,9
	int	21h
	pop	ds

	pop	cx
print_countdown:
	sub	cx,EADDR_LEN
	jae	print_another_address

	pop	ds

	mov	ah,3			;release the handle.
	mov	bx,handle
	call	int_pkt
	call	print_error

	int	20h

no_signature_err:
	mov	dx,offset no_signature_msg
	mov	ah,9
	int	21h
	int	20h


our_recv:
	or	ax,ax			;first or second call?
	jne	our_recv_1		;second -- we ignore the packet
	movseg	es,cs
	mov	di,offset our_buffer
our_recv_1:
	retf


	assume	ds:code

int_pkt:
	push	ds
	push	es
	pushf
	cli
	call	their_isr
	mov	cs:their_es,es
	pop	es
	pop	ds
	ret

	include	getea.asm
	include	printea.asm
	include	getnum.asm
	include	skipblk.asm
	include	getdig.asm
	include	digout.asm
	include	chrout.asm
	include	pkterr.asm

	align	4
our_buffer	label	byte

code	ends

	end	start
