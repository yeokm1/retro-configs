version	equ	2

	include	defs.asm

;Ported from Phil Karn's ec.c, a C-language driver for the 3COM 3C501
;by Russell Nelson.  Any bugs are due to Russell Nelson.
;*  Updated to version 1.08 Feb. 17, 1989.

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

code	segment	word public
	assume	cs:code, ds:code

;The various IE command registers
EDLC_ADDR	equ	00h	;EDLC station address, 6 bytes
EDLC_RCV	equ	06h	;EDLC receive csr
EDLC_XMT	equ	07h	;EDLC transmit csr
IE_GP		equ	08h	;GP pointer
IE_RP		equ	0ah	;Receive buffer pointer
IE_SAPROM	equ	0ch	;window on station addr prom
IE_CSR		equ	0eh	;IE command/status
IE_BFR		equ	0fh	;window on packet buffer

;Bits in EDLC_RCV, interrupt enable on write, status when read
EDLC_NONE	equ	000h	;match mode in bits 5-6, write only
EDLC_ALL	equ	040h	;promiscuous receive, write only
EDLC_BROAD	equ	080h	;station address plus broadcast
EDLC_MULTI	equ	0c0h	;station address plus multicast

EDLC_STALE	equ	80h	;receive CSR status previously read
EDLC_GOOD	equ	20h	;well formed packets only
EDLC_ANY	equ	10h	;any packet, even those with errors
EDLC_SHORT	equ	08h	;short frame
EDLC_DRIBBLE	equ	04h	;dribble error
EDLC_FCS	equ	02h	;CRC error
EDLC_OVER	equ	01h	;data overflow

EDLC_RERROR	equ	EDLC_SHORT or EDLC_DRIBBLE or EDLC_FCS or EDLC_OVER
EDLC_RMASK	equ	EDLC_GOOD or EDLC_ANY or EDLC_RERROR

;bits in EDLC_XMT, interrupt enable on write, status when read
EDLC_IDLE	equ	08h	;transmit idle
EDLC_16		equ	04h	;packet experienced 16 collisions
EDLC_JAM	equ	02h	;packet experienced a collision
EDLC_UNDER	equ	01h	;data underflow

;bits in IE_CSR
IE_RESET	equ	80h	;reset the controller (wo)
IE_XMTBSY	equ	80h	;Transmitter busy (ro)
IE_RIDE		equ	40h	;request interrupt/DMA enable (rw)
IE_DMA		equ	20h	;DMA request (rw)
IE_EDMA		equ	10h	;DMA done (ro)

IE_BUFCTL	equ	0ch	;mask for buffer control field (rw)
IE_LOOP		equ	0ch	;2 bit field in bits 2,3, loopback
IE_RCVEDLC	equ	08h	;gives buffer to receiver
IE_XMTEDLC	equ	04h	;gives buffer to transmit
IE_SYSBFR	equ	00h	;gives buffer to processor

IE_CRC		equ	01h	;causes CRC error on transmit (wo)
IE_RCVBSY	equ	01h	;receive in progress (ro)

BFRSIZ		equ	2048	;number of bytes in a buffer

	public	int_no
int_no		db	3,0,0,0		; interrupt number.
io_addr		dw	0300h,0		; I/O address for card (jumpers)

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
driver_type	db	1		;from the packet spec
driver_name	db	'3C501',0	;name of the driver.
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

	public	rcv_modes
rcv_modes	dw	7		;number of receive modes in our table.
		dw	0               ;There is no mode zero
		dw	rcv_mode_1
		dw	0		;don't want to bother.
		dw	rcv_mode_3
		dw	0		;haven't set up perfect filtering yet.
		dw	rcv_mode_5
		dw	rcv_mode_6

ipkt_size	dw	?
opkt_size	dw	?

	extrn	is_186: byte		;=0 if 808[68], =1 if 80[123]86.
our_type	dw	?,?

	include	io8.asm

	public bad_command_intercept
bad_command_intercept:
;called with ah=command, unknown to the skeleton.
;exit with nc if okay, cy, dh=error if not.
	mov	dh,BAD_COMMAND
	stc
	ret

	public	as_send_pkt
; The Asynchronous Transmit Packet routine.
; Enter with es:di -> i/o control block, ds:si -> packet, cx = packet length,
;   interrupts possibly enabled.
; Exit with nc if ok, or else cy if error, dh set to error number.
;   es:di and interrupt enable flag preserved on exit.
as_send_pkt:
	ret

	public	drop_pkt
; Drop a packet from the queue.
; Enter with es:di -> iocb.
drop_pkt:
	assume	ds:nothing
	ret

	public	xmit
; Process a transmit interrupt with the least possible latency to achieve
;   back-to-back packet transmissions.
; May only use ax and dx.
xmit:
	assume	ds:nothing
	ret


	public	send_pkt
send_pkt:
;enter with es:di->upcall routine, (0:0) if no upcall is desired.
;  (only if the high-performance bit is set in driver_function)
;enter with ds:si -> packet, cx = packet length.
;exit with nc if ok, or else cy if error, dh set to error number.
	assume	ds:nothing
	cmp	cx,GIANT		; Is this packet too large?
	ja	send_pkt_toobig

	cmp	cx,RUNT		; minimum length for Ether
	jae	oklen
	mov	cx,RUNT		; make sure size at least RUNT
oklen:
	inc	cx			;round size up to next even number.
	and	cx,not 1

;Wait for transmitter ready, if necessary. IE_XMTBSY is valid
;only in the transmit mode, hence the initial check.

	loadport
	setport	IE_CSR
	in	al,dx
	and	al,IE_BUFCTL
	cmp	al,IE_XMTEDLC
	jne	send_pkt_2

	mov	bx,20000		;try this many times.
send_pkt_3:
	in	al,dx			;if not busy, exit.
	and	al,IE_XMTBSY
	je	send_pkt_2
	dec	bx
	jne	send_pkt_3
	mov	dh,CANT_SEND		;timed out, can't send.
	stc
	ret
send_pkt_toobig:
	mov	dh,NO_SPACE
	stc
	ret
send_pkt_2:

;Get control of the board buffer and disable receiver
	mov	al,IE_RIDE or IE_SYSBFR
	setport	IE_CSR
	out	dx,al

;Point GP at beginning of packet
	mov	ax,BFRSIZ
	sub	ax,cx
	setport	IE_GP
	out	dx,ax

	setport	IE_BFR

	mov	opkt_size,cx	; opkt_size = cx;
	call	repoutsb

;Start transmitter
;Point GP at beginning of packet
	mov	ax,BFRSIZ
	sub	ax,opkt_size
	setport	IE_GP
	out	dx,ax

	mov	al,IE_RIDE or IE_XMTEDLC
	setport	IE_CSR
	out	dx,al

  if 1
	mov	bx,20000		;try this many times.
send_pkt_4:
	in	al,dx			;if not busy, exit.
	and	al,IE_XMTBSY
	je	send_pkt_5
	dec	bx
	jne	send_pkt_4
	mov	dh,CANT_SEND		;timed out, can't send.
	stc
	ret
send_pkt_5:

  endif

	clc
	ret


;Set Ethernet address on controller
	public	set_address
set_address:
	assume	ds:nothing
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
;
	cmp	cx,EADDR_LEN		;ensure that their address is okay.
	je	set_address_4
	mov	dh,BAD_ADDRESS
	stc
	jmp	short set_address_done
set_address_4:

	loadport
	setport	EDLC_ADDR
set_address_1:
	lodsb
	out	dx,al
	inc	dx
	loop	set_address_1
set_address_okay:
	mov	cx,EADDR_LEN		;return their address length.
	clc
set_address_done:
	movseg	ds,cs
	assume	ds:code
	ret


rcv_mode_1:
;Set up the receiver interrupts and flush status
	mov	al,EDLC_NONE
	loadport
	setport	EDLC_RCV
	out	dx,al
	in	al,dx			;flush status.

	ret


rcv_mode_3:
;Set up the receiver interrupts and flush status
	mov	al,EDLC_BROAD or EDLC_GOOD or EDLC_ANY or EDLC_SHORT or EDLC_DRIBBLE or EDLC_FCS or EDLC_OVER
	loadport
	setport	EDLC_RCV
	out	dx,al
	in	al,dx			;flush status.

	ret


rcv_mode_5:
;Set up the receiver interrupts and flush status
	mov	al,EDLC_MULTI or EDLC_GOOD or EDLC_ANY or EDLC_SHORT or EDLC_DRIBBLE or EDLC_FCS or EDLC_OVER
	loadport
	setport	EDLC_RCV
	out	dx,al
	in	al,dx			;flush status.

	ret


rcv_mode_6:
;Set up the receiver interrupts and flush status
	mov	al,EDLC_ALL or EDLC_GOOD or EDLC_ANY or EDLC_SHORT or EDLC_DRIBBLE or EDLC_FCS or EDLC_OVER
	loadport
	setport	EDLC_RCV
	out	dx,al
	in	al,dx			;flush status.

	ret


	public	set_multicast_list
set_multicast_list:
;enter with ds:si ->list of multicast addresses, ax = number of addresses,
;  cx = number of bytes.
;return nc if we set all of them, or cy,dh=error if we didn't.
	mov	dh,NO_MULTICAST
	stc
	ret


	public	terminate
terminate:
;Pulse IE_RESET
	mov	al,IE_RESET
	loadport
	setport	IE_CSR
	out	dx,al
	mov	al,0
	out	dx,al

	ret

	public	reset_interface
reset_interface:
;reset the interface.
;we don't do anything.
	ret


;called when we want to determine what to do with a received packet.
;enter with cx = packet length, es:di -> packet type, dl = packet class.
	extrn	recv_find: near

;called after we have copied the packet into the buffer.
;enter with ds:si ->the packet, cx = length of the packet.
	extrn	recv_copy: near

;call this routine to schedule a subroutine that gets run after the
;recv_isr.  This is done by stuffing routine's address in place
;of the recv_isr iret's address.  This routine should push the flags when it
;is entered, and should jump to recv_exiting_exit to leave.
;enter with ax = address of routine to run.
	extrn	schedule_exiting: near

;recv_exiting jumps here to exit, after pushing the flags.
	extrn	recv_exiting_exit: near

	extrn	count_in_err: near
	extrn	count_out_err: near

	public	recv
recv:
;called from the recv isr.  All registers have been saved, and ds=cs.
;Upon exit, the interrupt will be acknowledged.
	assume	ds:code

;Check for transmit jam

	loadport
	setport	IE_CSR
	in	al,dx
	and	al,IE_XMTBSY
	jne	recv_isr_1

	setport	EDLC_XMT
	in	al,dx
	test	al,EDLC_16
	je	recv_isr_2
;ecp->estats.jam16++;
	call	rcv_fixup
	jmp	short 	recv_isr_3
recv_isr_2:
	test	al,EDLC_JAM
	je	recv_isr_3
;Crank counter back to beginning and restart transmit
;ecp->estats.jam++;
	mov	al,IE_RIDE or IE_SYSBFR
	setport	IE_CSR
	out	dx,al

	mov	ax,BFRSIZ
	sub	ax,opkt_size
	setport	IE_GP
	out	dx,ax

	mov	al,IE_RIDE or IE_XMTEDLC
	setport	IE_CSR
	out	dx,al

recv_isr_3:

recv_isr_1:
	loadport
	setport	EDLC_RCV
	in	al,dx
	test	al,EDLC_STALE
	jne	recv_isr_4_j_1
	test	al,EDLC_OVER
	je	recv_isr_5
;ecp->estats.over++;
	call	rcv_fixup
	jmp	recv_isr_1
recv_isr_5:
	test	al,EDLC_SHORT or EDLC_FCS or EDLC_DRIBBLE
	je	recv_isr_6
;ecp->estats.bad++;
	call	rcv_fixup
	jmp	recv_isr_1
recv_isr_4_j_1:
	jmp	recv_isr_4
recv_isr_6:
	test	al,EDLC_ANY
	je	recv_isr_4_j_1
;Get control of the buffer
	mov	al,IE_RIDE or IE_SYSBFR
	setport	IE_CSR
	out	dx,al

	setport	IE_RP
	in	ax,dx			;get the size.
	mov	ipkt_size,ax
	cmp	ax,RUNT			;less than RUNT?
	jb	recv_isr_7		;yes.
	cmp	ax,GIANT		;greater than GIANT?
	jbe	recv_isr_8		;no.
recv_isr_7:
	call	count_in_err
;ecp->estats.bad++;
	jmp	recv_isr_9
recv_isr_8:
;Put it on the receive queue

	mov	ax,EADDR_LEN+EADDR_LEN	;seek to the type word.
	setport	IE_GP
	out	dx,ax

	setport	IE_BFR
	in	al,dx			;read the type word out of the board.
	mov	ah,al
	in	al,dx
	xchg	al,ah			;should be in network byte order.
	mov	our_type,ax
	in	al,dx			;read the type word out of the board.
	mov	ah,al
	in	al,dx
	xchg	al,ah			;should be in network byte order.
	mov	our_type+2,ax

	movseg	es,ds			;look up our type.
	mov	di,offset our_type

	mov	dl, BLUEBOOK		;assume bluebook Ethernet.
	mov	ax, es:[di]
	xchg	ah, al
	cmp 	ax, 1500
	ja	BlueBookPacket
	inc	di			;set di to 802.2 header
	inc	di
	mov	dl, IEEE8023
BlueBookPacket:

	mov	cx,ipkt_size
	call	recv_find

	mov	ax,es			;is this pointer null?
	or	ax,di
	je	recv_isr_9		;yes - just free the frame.

	push	es			;remember where the buffer pointer is.
	push	di

	xor	ax,ax			;seek to the beginning again.
	loadport
	setport	IE_GP
	out	dx,ax

	mov	cx,ipkt_size
	setport	IE_BFR

	call	repinsb

	pop	si
	pop	ds
	assume	ds:nothing
	mov	cx,ipkt_size
	call	recv_copy		;tell them that we copied it.

	movseg	ds,cs
	assume	ds:code

recv_isr_9:
	mov	al,IE_RIDE or IE_RCVEDLC
	loadport
	setport	IE_CSR
	out	dx,al
	xor	al,al
	setport	IE_RP
	out	dx,al
recv_isr_4:
;Clear any spurious interrupts
	loadport
	setport	EDLC_RCV
	in	al,dx

	setport	EDLC_XMT
	in	al,dx

	ret


rcv_fixup:
	call	count_out_err

	mov	al,IE_RIDE or IE_SYSBFR
	loadport
	setport	IE_CSR
	out	dx,al

	mov	al,IE_RIDE or IE_RCVEDLC
	setport	IE_CSR
	out	dx,al

	mov	al,0
	setport	IE_RP
	out	dx,al

	ret


	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret

;any code after this will not be kept.  Buffers used by the program, if any,
;are allocated from the memory between end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
end_free_mem	label	byte

	public	usage_msg
usage_msg	db	"usage: 3C501 [options] <packet_int_no> <hardware_irq> <io_addr>",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for the 3COM 3C501, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
		db	"Portions Copyright 1988 Phil Karn",CR,LF,'$'

no_3c501_msg	db	"No 3C501 found at that address.",CR,LF,'$'
ether_bdcst	db	6 dup(-1)	;ethernet broadcast address.

int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'

	extrn	set_recv_isr: near

;enter with si -> argument string, di -> word to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> name of word, di -> dword to print.
	extrn	print_number: near

;-> the assigned Ethernet address of the card.
	extrn	rom_address: byte

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	mov	di,offset int_no
	call	get_number
	mov	di,offset io_addr
	call	get_number
	clc
	ret


	public	etopen
etopen:
;  Initialize the Ethernet board, set receive type.
;
;  check for correct EPROM location
;
;Pulse IE_RESET
	mov	al,IE_RESET
	loadport
	setport	IE_CSR
	out	dx,al

	call	set_recv_isr

	movseg	es,ds
	mov	di,offset rom_address
	mov	cx,EADDR_LEN
	xor	bx,bx
get_address_1:
	mov	ax,bx
	loadport
	setport	IE_GP
	out	dx,ax

	setport	IE_SAPROM
	in	al,dx
	stosb
	inc	bx
	loop	get_address_1

;See if there really is a 3c501 there.
	mov	cx,EADDR_LEN
	mov	si,offset rom_address
	mov	di,offset ether_bdcst
	repe	cmpsb
	jne	have_3c501		;not broadcast address -- must be real.
	mov	dx,offset no_3c501_msg
	stc
	ret
have_3c501:

	mov	si,offset rom_address
	mov	cx,EADDR_LEN
	call	set_address

;Enable DMA/interrupt request, gain control of buffer
	mov	al,IE_RIDE or IE_SYSBFR
	loadport
	setport	IE_CSR
	out	dx,al

;Enable transmit interrupts
	mov	al,EDLC_16 or EDLC_JAM
	setport	EDLC_XMT
	out	dx,al

;Set up the receiver interrupts and flush status
	mov	al,EDLC_MULTI or EDLC_GOOD or EDLC_ANY or EDLC_SHORT or EDLC_DRIBBLE or EDLC_FCS or EDLC_OVER
	setport	EDLC_RCV
	out	dx,al
	in	al,dx			;flush status.

;Start receiver
	mov	ax,0			;Reset read pointer
	setport	IE_RP
	out	dx,ax
	mov	al,IE_RIDE or IE_RCVEDLC
	setport	IE_CSR
	out	dx,al

	mov	al, int_no		; Get board's interrupt vector
	add	al, 8
	cmp	al, 8+8			; Is it a slave 8259 interrupt?
	jb	set_int_num		; No.
	add	al, 70h - 8 - 8		; Map it to the real interrupt.
set_int_num:
	xor	ah, ah			; Clear high byte
	mov	int_num, ax		; Set parameter_list int num.

	clc
	ret

	public	print_parameters
print_parameters:
	mov	di,offset int_no
	mov	dx,offset int_no_name
	call	print_number
	mov	di,offset io_addr
	mov	dx,offset io_addr_name
	call	print_number
	ret


code	ends

	end
