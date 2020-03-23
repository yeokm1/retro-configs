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


	.286				;the NE2100 requires a 286.

	include	defs.asm

EBASE		equ	0
DATA_REG	equ	10h
ADDR_REG	equ	DATA_REG+2

code	segment	para public
	assume	cs:code, ds:code

	public	int_no
int_no	db	3,0,0,0			;must be four bytes long for get_number.
io_addr	dw	300h,0
dma_no	db	5,0,0,0

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
driver_type	db	97		;from the packet spec
driver_name	db	'NE2100',0	;name of the driver.
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
	mov	ax,0ff7ch		;stop LANCE
	outport CSR0			;should use hardware reset here
	endm

	include	lance.asm

	public	usage_msg
usage_msg	db	"usage: ne2100 [options] <packet_int_no> <hardware_irq> <io_addr> <dma_no>",CR,LF,'$'
bad_reset_msg	db	"Unable to reset the NE2100.",CR,LF,'$'
bad_init_msg	db	"Unable to initialize the NE2100.",CR,LF,'$'
no_memory_msg	db	"Unable to allocate enough memory, look at end_resident in NE2100.ASM",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for an NE2100, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+lance_version,".",'0'+version,CR,LF
		db	'$'

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	assume	ds:code
	mov	di,offset int_no
	call	get_number
	mov	di,offset io_addr
	call	get_number
	mov	di,offset dma_no
	call	get_number
	clc
	ret

check_board:
	clc
	ret

code	ends

	end

