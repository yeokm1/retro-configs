version	equ	0
;History:78,1

;  The following people have contributed to this code: David Horne, Eric
;  Henderson, and Bob Clements.

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

code	segment	word public
	assume	cs:code, ds:code

;*****************************************************************************
;
;	es3210 controller board offsets
;	IO port definition (BASE in io_addr)
;*****************************************************************************
NE_RESET	equ	04h		;board control bits.
EBASE		equ	10h
EN_OFF		equ	20h
NE_DATAPORT	equ	60h		; es3210 Port Window.

	include	8390.inc

; Shared memory management parameters

SM_TSTART_PG	equ	000h	; First page of TX buffer
SM_RSTART_PG	equ	006h	; Starting page of RX ring
SM_RSTOP_PG	equ	040h	; Last page +1 of RX ring

pause_	macro
;	jmp	$+2
;
; The reason for the pause_ macro is to establish a minimum time between
; accesses to the card hardware. The assumption is that the fetch and execution
; of the jmp $+2 instruction will provide this time. In a fast cache machine
; this may be a false assumption. In a fast cache machine, there may be 
; NO REAL TIME DIFFERENCE between the two I/O instruction streams below:
;
;	in	al,dx		in	al,dx
;	jmp	$+2
;	in	al,dx		in	al,dx
;
; To establish a minimum delay, an I/O instruction must be used. A good rule of
; thumb is that ISA I/O instructions take ~1.0 microseconds and MCA I/O
; instructions take ~0.5 microseconds. Reading the NMI Status Register (0x61)
; is a good way to pause on all machines.
;
; The National 8390 Chip (NIC) requires 4 bus clocks between successive
; chip selects (National DP8390 Data Sheet Addendum, June 1990 -- it took them
; long enough to figure this out and tell everyone) or the NIC behaves badly.
; Therefor one I/O instruction should be inserted between each successive
; NIC I/O instruction that could occur 'back - to - back' on a fast cache
; machine.
;   - gft - 910529
;
	push	ax
	in	al, 61h			;EISA bus requires more delay.
	in	al, 61h
	pop	ax
;
endm

reset_8390	macro
	loadport
	setport	NE_RESET
	mov	al,4			;reset the board.
	out	dx,al
	longpause
	mov	al,1			;unreset the board.
	out	dx,al

	endm

terminate_board	macro
	endm

	public	int_no, io_addr, mem_base
int_no		db	2,0,0,0		;must be four bytes long for get_number.
io_addr		dw	0300h,0		; I/O address for card
mem_base	dw	00000h,0	; Shared memory addr

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
driver_type	dw	54		;from the packet spec
driver_name	db	'es3210',0	;name of the driver.
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

	include	movemem.asm

;
;	Block input routine
;	CX = byte count, es:di = buffer location, ax = buffer address

	public	block_input
block_input:
	.386
	push	ds
	push	eax
	assume	ds:nothing
	mov	ds,mem_base		; ds:si points at first byte to move
	mov	si,ax

	add	ax,cx			; Find the end of this frame.
	cmp	ah,byte ptr cs:sm_rstop_ptr ; Over the top of the ring?
	jb	rcopy_one_piece		; Go move it

rcopy_wrap:
; Copy in two pieces due to buffer wraparound.
	mov	ah,byte ptr cs:sm_rstop_ptr ; Compute length of first part
	xor	al,al
	sub	ax,si			;  as all of the pages up to wrap point
	sub	cx,ax			; Move the rest in second part
	push	cx			; Save count of second part
	mov	cx,ax			; Count for first move
	shr	cx,2			; convert byte count to dword count
	rep	movsd
	mov	si,SM_RSTART_PG*256	; Offset to start of first receive page
	pop	cx			; Bytes left to move
rcopy_one_piece:
;transfer all complete dwords.
	push	cx
	shr	cx,2			; convert byte count to dword count
	rep	movsd
	pop	cx

;now take take of any trailing words and/or bytes.
	lodsd

	test	cx,2
	je	rcopy_one_word
	stosw
	shr	eax,16
rcopy_one_word:

	test	cx,1
	je	rcopy_one_byte
	stosb
rcopy_one_byte:

	pop	eax
	pop	ds
	.8086
	ret

;
;	Block output routine
;	CX = byte count, ds:si = buffer location, ax = buffer address

block_output:
	assume	ds:nothing
	.386
	mov	es,mem_base		; Set up ES:DI at the shared RAM
	mov	di,ax			; ..
	add	cx,3			;round up to next highest dword.
	shr	cx,2
	rep	movsd
	clc
	.8086
	ret


	include	8390.asm

	public	usage_msg
usage_msg	db	"usage: es3210 [options] <packet_int_no> <hardware_irq> <io_addr> <mem_base>",CR,LF,'$'
no_board_msg	db	"No es3210 detected.",CR,LF,'$'
io_addr_funny_msg	label	byte
		db	"No es3210 detected, continuing anyway.",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for es3210, version "
		db	'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,".",'0'+dp8390_version,CR,LF,'$'

int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'
mem_base_name	db	"Memory address ",'$'

	extrn	is_386: byte		;=0 if 80[12]8[68], =1 if 80[34]86.

	extrn	set_recv_isr: near

;enter with si -> argument string, di -> word to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> name of word, di -> dword to print.
	extrn	print_number: near

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	mov	di,offset int_no
	call	get_number
	mov	di,offset io_addr
	call	get_number
	mov	di,offset mem_base
	call	get_number

	cmp	io_addr,-1		;Did they ask for auto-detect?
	je	find_board

	call	detect_board		;no, just verify its existance.
	je	find_board_found

	mov	dx,offset io_addr_funny_msg
	mov	ah,9
	int	21h

	jmp	find_board_found

find_board:
	mov	io_addr,0c80h		;Search for the Ethernet address.
	mov	io_addr+2,0
find_board_0:
	call	detect_board
	je	find_board_found
find_board_again:
	add	io_addr,1000h		;not at this port, try another.
	jnc	find_board_0

	mov	dx,offset no_board_msg	;Tell them that we can't find it.
	mov	ah,9
	int	21h

	stc
	ret
find_board_found:
	clc
	ret

	extrn	etopen_diagn: byte

init_card:
;get the board data. This is (16) bytes starting at remote
;dma address 0. Put it in a buffer called board_data.
	assume	ds:code

	or	endcfg,ENDCFG_WTS

	movseg	es,ds
	mov	di,offset board_data

	.386
	loadport			; Get our Ethernet address base.
	setport	EBASE
	mov	cx,EADDR_LEN
read_address_1:
	insb				; get a byte of the eprom address
	inc	dx			; next register
	loop	read_address_1		; go back for rest
	.8086

	push    ds              ; Copy from card's address to current address
	pop     es

	mov si, offset board_data	; address is at start
	mov di, offset rom_address
	mov cx, EADDR_LEN       ; Copy one address length
	rep     movsb           ; ..

	clc
	ret

	public	print_parameters
print_parameters:
;echo our command-line parameters
	mov	di,offset int_no
	mov	dx,offset int_no_name
	call	print_number
	mov	di,offset io_addr
	mov	dx,offset io_addr_name
	call	print_number
	mov	di,offset mem_base
	mov	dx,offset mem_base_name
	call	print_number
	ret

detect_board:
;test to see if a board is located at io_addr.
;return nz if not.
	loadport
	setport	EBASE
	in	al,dx			;Check for Interlan's prefix word.
	cmp	al,2
	jne	detect_board_exit

	setport	EBASE+1
	in	al,dx
	cmp	al,7
	jne	detect_board_exit

	setport	EBASE+EADDR_LEN		;first byte following should be 0
	in	al,dx
	cmp	al,0
	jne	detect_board_exit

	setport	EBASE+EADDR_LEN+1	;second byte should be 55h
	in	al,dx
	cmp	al,55h
detect_board_exit:
	ret

code	ends

	end
