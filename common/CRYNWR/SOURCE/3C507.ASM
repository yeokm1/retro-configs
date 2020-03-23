version	equ	1

	include	defs.asm

;Ported from Tim Krauskopf's micnet.asm, an assembly language
;driver for the MICOM-Interlan NI5210 by Russell Nelson.  Any bugs
;are due to Russell Nelson.

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

	.286				;the 3c507 requires a 286.

code	segment	word public
	assume	cs:code, ds:code

;
;  Equates for controlling the 3c507 board
;
IO_CONTROL	equ	06h
IO_INTCLR	equ	0ah
IO_CA		equ	0bh
IO_RAM		equ	0eh
IO_INT		equ	0fh

;IO_CONTROL bits:
_RST	equ	80h			;not reset
LBK	equ	20h			;loopback
IEN	equ	04h			;interrupt enable
VB0	equ	01h			;vb0.

	public	int_no
int_no		db	3,0,0,0		; interrupt number
io_addr		dw	300h,0		; I/O address for card
base_addr	dw  	0c000h,0	; base segment for board

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
driver_type	db	13		;from the packet spec
driver_name	db	"3c507",0	;name of the driver.
driver_function	db	2
parameter_list	label	byte
	db	1	;major rev of packet driver
	db	9	;minor rev of packet driver
	db	14	;length of parameter list
	db	EADDR_LEN	;length of MAC-layer address
	dw	GIANT	;MTU, including MAC headers
	dw	MAX_MULTICAST * EADDR_LEN	;buffer size of multicast addrs
	dw	0	;(# of back-to-back MTU rcvs) - 1
	dw	0	;(# of successive xmits) - 1
int_num	dw	0	;Interrupt # to hook for post-EOI
			;processing, 0 == none,

enable_network:
;  connect to network
	loadport
	setport	IO_CONTROL
	mov	al,_RST or IEN or VB0
	out	dx,al
	ret


reset_586:
;  Reset the chip
	loadport
	setport	IO_CONTROL
	mov	al,LBK
	out	dx,al
	jmp	$+2
	jmp	$+2
	mov	al,_RST or LBK or VB0
	out	dx,al
	setport	IO_INTCLR		;clear the interupt latch.
	out	dx,al
	ret


doca:
;we may be called from places in which ds is unknown.
	assume	ds:nothing
	loadport
	setport IO_CA
	out	dx, al
	ret
	assume	ds:code
;yet, we really should assume ds==code for the rest of this stuff.


;
; Here we include the code that is common between 82586 implementations.
; Everything above this is resident.
	include	82586.asm
; Everything below this is discarded upon installation.

	public	usage_msg
usage_msg	db	"usage: 3c507 [options] <packet_int_no> <io_addr>",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for the 3C507, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,".",'0'+i82586_version,CR,LF,'$'

main_memory_only	label	byte
	db	"Memory window must be in the 0xc000 -> 0xd800 range.",CR,LF,'$'

signature	db	'PKT DRVR',0
signature_len	equ	$-signature

their_int	dd	?
found_3c507	db	0

check_board:
	mov	SCP,0			; 16 bit bus type in scb.

;we look for another 3c507 packet driver.  If there is one, we don't write
;the ID pattern, because that resets the board's bus interface.
	mov	al,60h
check_ints:
	push	ax
	mov	ah,35h			;get their packet interrupt.
	int	21h

	lea	di,3[bx]		;see if there is already a signature
	mov	si,offset signature	;  there.
	mov	cx,signature_len
	repe	cmpsb
	jne	check_ints_1

	mov	their_int.offs,bx
	mov	their_int.segm,es

	push	ds
	mov	ax,1ffh			;get the board's parameters
	pushf
	cli
	call	their_int
	pop	ds
	cmp	dl,driver_type
	jne	check_ints_1

	inc	found_3c507		;yes!  We found another 3c507.
check_ints_1:
	pop	ax
	inc	al
	cmp	al,80h
	jbe	check_ints

	cmp	found_3c507,0
	jne	check_ints_2
	call	write_id_pat
check_ints_2:

	loadport
	setport	IO_RAM
	in	al,dx
	test	al,20h			;8088 address or 80286 address?
	je	check_board_3
	mov	dx,offset main_memory_only
	stc
	ret
check_board_3:
	and	al,18h
;00 = 0c000h, 08 = 0c800h, 10 = 0d000h, 18 = 0d800h.
	mov	ah,al
	xor	al,al
	add	ah,0c0h
	mov	base_addr,ax

	setport	IO_INT
	in	al,dx
	and	al,0fh
	mov	int_no,al

	setport	IO_CONTROL
	mov	al,_RST or IEN or VB0
	out	dx,al

	clc
	ret


write_id_pat:
	mov	dx,100h
	xor	al,al
	out	dx,al			;reset hardware pattern generator
	mov	cx,0ffh
	mov	al,0ffh
write_id_pat_1:
	out	dx,al			;keep writing matching values...
	shl	al,1
	jnc	write_id_pat_2
	xor	al,0e7h
write_id_pat_2:
	loop	write_id_pat_1
	xor	al,al
	out	dx,al			;now put adapter in RUN state.
	ret


get_address:
;get the address of the interface.
;enter with es:di -> place to get the address, cx = size of address buffer.
;exit with nc, cx = actual size of address, or cy if buffer not big enough.
	assume	ds:code
	mov	dx,io_addr		; Get our IO base address.
	cld
get_address_1:
	in	al,dx			; get a byte of the eprom address
	stosb				; put it away
	inc	dx			; next register
	loop	get_address_1		; go back for rest
	ret


	public	parse_args
parse_args:
	mov	di,offset io_addr
	call	get_number
	clc
	ret


int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'
base_addr_name	db	"Memory address ",'$'


	public	print_parameters
print_parameters:
	mov	di,offset int_no
	mov	dx,offset int_no_name
	call	print_number
	mov	di,offset io_addr
	mov	dx,offset io_addr_name
	call	print_number
	mov	ax,memory_begin
	mov	cl,4
	shr	ax,cl
	add	base_addr,ax
	push	ax
	mov	di,offset base_addr
	mov	dx,offset base_addr_name
	call	print_number
	pop	ax
	sub	base_addr,ax
	ret

	include	memtest.asm

code	ends

	end

