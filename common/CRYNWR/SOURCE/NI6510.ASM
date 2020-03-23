version	equ	1

; Copyright, 1990-1992, Russell Nelson, Crynwr Software

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

comment /

I found a problem when using the Interlan NI6510 Packet Driver with 16 bit DMA.
I looked at the source and I think I found the bug.  I've tested the fixed code
and it seems to work fine for all possible DMA settings, at least over here.

Anto Prijosoesilo,
Network & Microcomputer Consultant,
University of North Texas Computing Center,
Denton, Texas

/

	.286				;the 6510 requires a 286.

	include	defs.asm

DATA_REG	equ	0
ADDR_REG	equ	2
RESET		equ	4
CONFIG		equ	5
EBASE		equ	8

code	segment	para public
	assume	cs:code, ds:code

	public	int_no
int_no	db	2,0,0,0			;must be four bytes long for get_number.
io_addr	dw	-1,-1
dma_no	db	?,0,0,0

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
driver_type	db	35		;from the packet spec
driver_name	db	'NI6510',0	;name of the driver.
driver_function	db	2		;basic, extended
parameter_list	label	byte
	db	1	;major rev of packet driver
	db	9	;minor rev of packet driver
	db	14	;length of parameter list
	db	EADDR_LEN	;length of MAC-layer address
	dw	GIANT	;MTU, including MAC headers
	dw	MAX_MULTICAST * EADDR_LEN	;buffer size of multicast addrs
	dw	RECEIVE_BUF_COUNT-1	;(# of back-to-back MTU rcvs) - 1
	dw	TRANSMIT_BUF_COUNT-1	;(# of successive xmits) - 1
int_num	dw	0	;Interrupt # to hook for post-EOI
			;processing, 0 == none,

reset_lance	macro
	loadport
	setport	RESET
	out	dx,al
	endm

	include	lance.asm

	public	usage_msg
usage_msg	db	"usage: ni6510 [options] <packet_int_no> <hardware_irq> <io_addr>",CR,LF,'$'
no_board_msg	db	"No NI6510 detected.",CR,LF,'$'
have_eb_msg	db	"Use the NE2100 packet driver instead.",CR,LF,'$'
io_addr_funny_msg	label	byte
		db	"No NI6510 detected, continuing anyway.",CR,LF,'$'
bad_reset_msg	db	"Unable to reset the NI6510.",CR,LF,'$'
bad_init_msg	db	"Unable to initialize the NI6510.",CR,LF,'$'
no_memory_msg	db	"Unable to allocate enough memory, look at end_resident in NI6510.ASM",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for a Racal Interlan NI6510, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+lance_version,".",'0'+version,CR,LF
		db	'$'

int_nos		db	9, 12, 15, 5	;interrupt numbers.
dma_nos		db	0, 3, 5, 6	;dma channel numbers

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	assume	ds:code
	mov	di,offset int_no
	call	get_number
	mov	di,offset io_addr
	call	get_number
	clc
	ret


check_board:
	cmp	io_addr,-1		;Did they ask for auto-detect?
	je	find_board

	call	detect_ni6510		;no, just verify its existance.
	je	find_board_found
	call	detect_eb
	je	find_board_eb

	mov	dx,offset io_addr_funny_msg
	mov	ah,9
	int	21h

	jmp	find_board_found

find_board:
	mov	io_addr,300h		;Search for the Ethernet address.
	mov	io_addr+2,0
find_board_0:
	call	detect_ni6510
	je	find_board_found
	call	detect_eb
	je	find_board_eb
find_board_again:
	add	io_addr,20h		;not at this port, try another.
	cmp	io_addr,360h
	jbe	find_board_0

	mov	dx,offset no_board_msg	;Tell them that we can't find it.
	stc
	ret
find_board_eb:
	mov	dx,offset have_eb_msg	;Tell them to use ne2100.
	stc
	ret
find_board_found:

	loadport			;get the configuration register and
	setport	CONFIG			;  determine the interrupt number.
	in	al,dx
	shr	al,2
	and	al,3
	mov	bl,al
	xor	bh,bh
	mov	al,int_nos[bx]
	mov	int_no,al

;This routine will put the (host) DMA controller into
;cascade mode of operation.

	in	al,dx			;get the dma channel field.
	and	al,3
	mov	bl,al
	xor	bh,bh
	mov	al,dma_nos[bx]
	mov	dma_no,al

	clc
	ret

detect_ni6510:
;test to see if a board is located at io_addr.
;return nz if not.
	loadport
	setport	EBASE
	in	al,dx			;Check for Interlan's prefix word.
	cmp	al,2
	jne	detect_ni6510_exit

	setport	EBASE+1
	in	al,dx
	cmp	al,7
	jne	detect_ni6510_exit

	setport	EBASE+EADDR_LEN		;first byte following should be 0
	in	al,dx
	cmp	al,0
	jne	detect_ni6510_exit

	setport	EBASE+EADDR_LEN+1	;second byte should be 55h
	in	al,dx
	cmp	al,55h
detect_ni6510_exit:
	ret

detect_eb:
;test to see if an EtherBlaster board is located at io_addr.
;return nz if not.
	loadport
	setport	0
	in	al,dx			;Check for Interlan's prefix word.
	cmp	al,2
	jne	detect_eb_exit

	setport	1
	in	al,dx
	cmp	al,7
detect_eb_exit:
	ret


code	ends

	end
