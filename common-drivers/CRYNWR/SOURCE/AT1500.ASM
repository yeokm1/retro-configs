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


	.286				;the at1500 requires a 286.

	include	defs.asm

EBASE		equ	0
DATA_REG	equ	10h
ADDR_REG	equ	DATA_REG+2
ISAC_REG	equ	DATA_REG+6

code	segment	para public
	assume	cs:code, ds:code

	public	int_no
int_no	db	?,0,0,0			;must be four bytes long for get_number.
io_addr	dw	-1,-1
dma_no	db	?,0,0,0

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
driver_type	db	98		;from the packet spec
driver_name	db	'Allied Telesis 1500',0	;name of the driver.
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
	mov	ax,CSR0_STOP
	outport CSR0			;should use hardware reset here
	endm

	include	lance.asm

	public	usage_msg
usage_msg	db	"usage: at1500 [options] <packet_int_no> <io_addr>",CR,LF,'$'
no_board_msg	db	"No at1500 detected.",CR,LF,'$'
bad_reset_msg	db	"Unable to reset the at1500.",CR,LF,'$'
bad_init_msg	db	"Unable to initialize the at1500.",CR,LF,'$'
no_memory_msg	db	"Unable to allocate enough memory, look at end_resident in at1500.ASM",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for an at1500, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+lance_version,".",'0'+version,CR,LF
		db	'$'

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	assume	ds:code
	mov	di,offset io_addr
	call	get_number
	clc
	ret

check_board:
	assume	ds:code
	cmp	io_addr,-1		;Did they ask for auto-detect?
	je	find_board

	mov	di,io_addr
	call	verifyboard
	jnc	find_board_found

	mov	dx,offset no_board_msg	;Tell them that we can't find it.
	stc
	ret

find_board:
	mov	io_addr,300h		;Search for the Ethernet address.
	mov	io_addr+2,0
find_board_0:
	mov	di,io_addr
	call	verifyboard
	jnc	find_board_found
find_board_again:
	add	io_addr,20h		;not at this port, try another.
	cmp	io_addr,360h
	jbe	find_board_0

	mov	dx,offset no_board_msg	;Tell them that we can't find it.
	stc
	ret
find_board_found:
	mov	int_no,bl
	mov	dma_no,bh

	loadport			;CX = value to be output to ISACR 2.
	setport	ADDR_REG
	mov	ax,2
	out	dx,ax
	in	ax,dx
	setport	ISAC_REG
	mov	ax,cx
	out	dx,ax
	in	ax,dx
	clc
check_board_1:
	ret

code	ends

CODESEG		EQU	<code>
DATASEG		EQU	<code>
DATAGROUP	EQU	<code>
	include	eep15.inc

	end

