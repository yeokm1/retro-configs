version	equ	0
;History:201,1
;Mon Feb 22 15:40:28 1993 es

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
;	Mylex LNE390 controller board offsets
;	IO port definition (BASE in io_addr)
;*****************************************************************************
NE_RESET	equ	0c84h		;board control bits.
NE_CONFIG	equ	0c90h		;configuration register
EBASE		equ	16h		;Ethernet address starts here.
EN_OFF		equ	0h		;8390 starts here

	include	8390.inc

; Shared memory management parameters

SM_TSTART_PG	equ	000h	; First page of TX buffer
SM_RSTART_PG	equ	006h	; Starting page of RX ring
SM_RSTOP_PG	equ	080h	; Last page +1 of RX ring

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
	mov	al,0			;reset the board.
	out	dx,al
	longpause
	mov	al,1			;unreset the board.
	out	dx,al

	endm

terminate_board	macro
	loadport
	setport	NE_RESET
	mov	al,0			;reset the board.
	out	dx,al
	setport	NE_CONFIG
	in	ax,dx
	and	ax,not 3700h		;turn of xcvr, memory, and ints.
	out	dx,ax
	endm

	public	int_no, io_addr, mem_base
int_no		db	?,0,0,0		;must be four bytes long for get_number.
io_addr		dw	?,0		; I/O address for card
mem_base	dw	?,0		; Shared memory addr

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
driver_type	dw	95		;from the packet spec
driver_name	db	'LNE390',0	;name of the driver.
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

	even
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
usage_msg	db	"usage: mylex [options] <packet_int_no> <int_level> <io_addr> <mem_base>",CR,LF,'$'
no_board_msg	db	"No Mylex LNE390 detected.",CR,LF,'$'
bad_memory_msg	db	"This adapter must be addressed at 0xd000 or 0xe000",CR,LF,'$'
no_network_msg	db	"Check network connector - no network connection detected.",CR,LF,'$'
tp_xcvr_msg	db	"Using Twisted Pair (10BaseT) transceiver",CR,LF,'$'
bnc_xcvr_msg	db	"Using BNC (10Base2) transceiver",CR,LF,'$'
aui_xcvr_msg	db	"Using AUI transceiver",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for Mylex, version "
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

irq_table	db	15, 12, 11, 10, 9, 7, 5, 3

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	.386
	mov	cx,0fh
eisa_search:
	mov	dx,cx			;move it into the first nibble.
	shl	dx,12
	or	dx,0c80h
  if 0
	in	eax,dx
	cmp	eax,11009835h
  else
	in	ax,dx			;look for the manufacturer's ID
	cmp	ax,9835h
	jne	eisa_search_1
	add	dx,2
	in	ax,dx
	cmp	ax,1100h
  endif
	je	eisa_found
eisa_search_1:
	loop	eisa_search

	mov	dx,offset no_board_msg
	stc
	ret

eisa_found:
	.8086
	and	dx,0f000h
	mov	io_addr,dx

	loadport
	setport	NE_RESET
	mov	al,1
	out	dx,al

	setport	NE_CONFIG		;point to configuration register.
	in	ax,dx
	mov	bx,ax
	and	ax,7
	mov	mem_base,0e000h
	cmp	ax,2
	je	eisa_memory_ok
	mov	mem_base,0d000h
	cmp	ax,6
	je	eisa_memory_ok
	mov	dx,offset bad_memory_msg
	stc
	ret
eisa_memory_ok:

	mov	cl,3
	shr	bx,cl
	and	bx,7
	mov	bl,irq_table[bx]
	mov	int_no,bl

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

test_packet	label	byte
	db	EADDR_LEN dup(?)
	db	EADDR_LEN dup(?)
	db	00h,2eh			;A 46 in network order
	db	0,0			;DSAP=0 & SSAP=0 fields
	db	0f3h,0			;Control (Test Req + P bit set)

iface_bit	db	4		;start with AUI.

	public	print_parameters
print_parameters:
;but on *this* adapter, try sending a test packet.

;first try with the AUI port.
	mov	si,offset rom_address	;set the destination address.
	movseg	es,cs
	mov	di,offset test_packet
	movsw
	movsw
	movsw
	mov	si,offset rom_address	;set the source address.
	movsw
	movsw
	movsw

send_test:
	loadport			;store the current thin_bit to the board.
	setport	NE_CONFIG
	in	ax,dx
	and	ax,not 700h
	or	ax,3000h		;enable memory and interrupts.
	or	ah,iface_bit
	out	dx,ax

	mov	ax,18			;wait a little while for the powerdown/up to take effect.
	call	set_timeout
send_test_power:
	call	do_timeout
	jne	send_test_power

	mov	cx,6			;try six times
send_test_again:
	push	cx
	mov	cx,60
	mov	si,offset test_packet
	call	send_pkt
	pop	cx

	mov	ax,3
	call	set_timeout

	loadport
	setport	EN0_ISR
send_test_wait:
	in	al,dx
	test	al,ENISR_TX or ENISR_TX_ERR	;did it finish?
	jne	send_test_done

	call	do_timeout
	jnz	send_test_wait
	jmp	short send_test_loop

send_test_done:
	mov	al,0ffh			;clear all interrupts.
	out	dx,al

	loadport
	setport	EN0_TSR
	in	al,dx			;get the transmit status
	test	al,ENTSR_COLL16 or ENTSR_CRS or ENTSR_FU	;any problems?
	je	send_test_exit		;no, it worked.

send_test_loop:
	loop	send_test_again

;it failed all six times.  Try again on a different interface.
	shr	iface_bit,1
	cmp	iface_bit,0		;did we try them all?
	je	send_test_fail		;yes, we can't send any packets!

	jmp	send_test

send_test_fail:
	mov	dx,offset no_network_msg
	mov	ah,9
	int	21h

	mov	iface_bit,1
	jmp	send_test_exit

send_test_exit:
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
	mov	dx,offset tp_xcvr_msg
	cmp	iface_bit,1
	je	print_parameters_1
	mov	dx,offset bnc_xcvr_msg
	cmp	iface_bit,2
	je	print_parameters_1
	mov	dx,offset aui_xcvr_msg
print_parameters_1:
	mov	ah,9
	int	21h
	ret

code	ends

	end
