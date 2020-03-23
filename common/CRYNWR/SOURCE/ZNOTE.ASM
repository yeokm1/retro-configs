version	equ	5
;History:183,1

comment \

On a 386/33, run 2.03 as a server.

e=137.143.201.3,1500,5 f=1 gives 1 % loss with a colon and MUCH delay.
e=137.143.201.3,1500,6 f=1 gives 17 % loss and hard-crashes the machine.
e=137.143.201.3,1500,7 f=1 gives zero packet loss.

\


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

	.286				;it's a 16-bit adapter.

	include	defs.asm

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
	in	al, 61h
	pop	ax
;
endm

; DMA controller registers
DMA_BASE	equ	0c0h		; DMA controller base
DMA_STAT	equ	0D0h		; DMA controller status register
DMA_MASK        equ	0D4h		; DMA controller mask register
DMA_MODE        equ	0D6h		; DMA controller mode register
DMA_RESETFF	equ	0D8h		; DMA controller first/last flip flop

; DMA data
DMA_DISABLE 	equ	04h		; Disable channel n
DMA_ENABLE	equ	00h		; Enable channel n
; Demand transfers, incr. address, auto init, writes, ch. n
DMA_RX_MODE	equ	14h
; Demand transfers, incr. address, auto init, reads, ch. n
DMA_TX_MODE 	equ	18h

;82593 port 0 bits
CMD0_CHNL_0	equ	0
CMD0_CHNL_1	equ	10h
CMD0_ACK	equ	80h
CMD0_STAT0	equ	0
CMD0_STAT1	equ	20h
CMD0_STAT2	equ	40h
CMD0_STAT3	equ	60h
;commands (bits 3-0)
CMD0_NOP	equ	0+CMD0_CHNL_0
CMD0_PORT_1	equ	0+CMD0_CHNL_1
CMD0_IA_SETUP	equ	1
CMD0_CONFIGURE	equ	2
CMD0_MC_SETUP	equ	3
CMD0_TRANSMIT	equ	4
CMD0_TDR	equ	5
CMD0_DUMP	equ	6
CMD0_DIAGNOSE	equ	7
CMD0_RCV_ENABLE	equ	8
CMD0_TRANSMIT_NC	equ	9
CMD0_RCV_DIABLE	equ	10
CMD0_STOP_RCV	equ	11
CMD0_RETRANSMIT	equ	12
CMD0_ABORT	equ	13
CMD0_RESET	equ	14
CMD0_RLS_PTR	equ	15+CMD0_CHNL_0
CMD0_FIX_PTR	equ	15+CMD0_CHNL_1

;82593 port 1 commands
CMD1_NOP	equ	0
CMD1_PORT_0	equ	1
CMD1_DISABLE	equ	2
CMD1_ENABLE	equ	3
CMD1_SET_TS	equ	5
CMD1_RST_TS	equ	7
CMD1_POWER_DN	equ	8
CMD1_RST_RING	equ	11
CMD1_RESET	equ	14

;82593 events
IA_SETUP_DONE		equ	1
CONFIGURE_DONE		equ	2
MC_SETUP_DONE		equ	3
TRANSMIT_DONE		equ	4
TDR_DONE		equ	5
DUMP_DONE		equ	6
DIAGNOSE_PASSED		equ	7
END_OF_FRAME		equ	8
TRANSMIT_NC_DONE	equ	9
RECEPTION_ABORTED	equ	10
STOP_REG_HIT		equ	11
RETRANSMIT_DONE		equ	12
EXECUTION_ABORTED	equ	13
DIAGNOSE_FAILED		equ	15

;ID block contained in memory in the 64K block at f000:0
id_block	struc
header		db 8 dup (?)
netid		db 8 dup (?)
nettype 	db ?
globalopt	db ?
vendor		db 8 dup (?)
product 	db 8 dup (?)
intr1		db ?
intr2		db ?
dma1		db ?
dma2		db ?
membase1	dw 2 dup (?)
memsize1	dw 2 dup (?)
membase2	dw 2 dup (?)
memsize2	dw 2 dup (?)
iobase1 	dw ?
iosize1 	dw ?
iobase2 	dw ?
iosize2 	dw ?
driveropt	db ?
reservednib	db ?
id_block	ends


GOODRECEIVE	equ  2000h
CRCERROR	equ  0800h
ALIGNMENT	equ  0400h
FIFOOVERRUN	equ  0100h
SHORTFRAME	equ  0080h
RXCOLLISION	equ  0001h

;buffer sizes.
TRANSMIT_BUF_SIZE	equ	2+GIANT+2	;count plus data plus chain cmd.
RECEIVE_BUF_BITS	equ	12
RECEIVE_BUF_SIZE	equ	2 shl RECEIVE_BUF_BITS
RECEIVE_BUF_2K		equ	(1 shl RECEIVE_BUF_BITS) / 2048	;in words.

code	segment	dword public
	assume	cs:code, ds:code

	public	int_no
int_no	db	10,0,0,0		;must be four bytes long for get_number.
io_addr	dw	300h,0			;must be four bytes long for get_number.

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
driver_type	db	93		;assigned by FTP Software, <jbvb@ftp.com>
driver_name	db	'Z-Note',0	;name of the driver.
driver_function	db	2
parameter_list	label	byte
	db	1	;major rev of packet driver specification
	db	9	;minor rev of packet driver specification
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
		dw	0
		dw	rcv_mode_2
		dw	rcv_mode_3
		dw	0
		dw	rcv_mode_5
		dw	rcv_mode_6

;b05
rx_channel	db	?		;0-3 (really 4-7).
rx_dma_dest	dw	?
rx_page_addr	dw	?

tx_channel	db	?		;0-3 (really 4-7)
tx_dma_dest	dw	?
tx_page_addr	dw	?

;b0f = 0efc
transmit_buf	dw	?		;points to transmit buffer.
receive_buf	dw	?		;points to receive buffer.
receive_buf_end	dw	?		;points to first byte after recv buf.
recv_buf_cnt	dw	?

this_rfp_ptr	dw	?		;->rfp we started with
last_rfp_ptr	dw	?		;->rfp we from last time.

	align	4			;for efficiency's sake.
packet_type	db	MAX_P_LEN dup(?)

; Standard Ethernet values.  Intel makes them configurable in case Ethernet
; ever changes.
CBCONF	label	byte
	db	0AAh		; 1:  16-byte input & 80-byte output FIFO
				;     threshhold, 96-byte FIFO, 82593 mode.
	db	088h		; 2:  Continuous w/interrupts, 128-clock DMA.
	db	02Eh		; 3:  7-byte preamble, NO address insertion,
				;     6-byte Ethernet address, loopback off.
	db	000h		; 4:  Default priorities & backoff methods.
	db	060h		; 5:  96-bit interframe spacing.
	db	000h		; 6:  512-bit slot time (low-order).
	db	0F2h		; 7:  Slot time (high-order), 15 COLL retries.
CBCONF_FLAGS	label	byte
	db	000h		; 8:  Promisc-off, broadcast-on, default CRC.
	db	000h		; 9:  Default carrier-sense, collision-detect.
CBCONF_MINLEN	label	byte
	db	040h		;10:  64-byte minimum frame length.
	db	05Fh		;11:  Type/length checks OFF, no CRC input,
				;     "jabber" termination, etc.
	db	000h		;12:  Full-duplex disabled.
	db	03Fh		;13:  Default multicast addresses & backoff.
CBCONF_MC	label	byte
	db	007h		;14:  Default IFS retriggering.
	db	031h		;15:  Internal retransmit, drop "runt" packets,
				;     synchr. DRQ deassertion, 6 status bytes.
	db	020h+RECEIVE_BUF_2K	;16:  Receive ring-buffer size (8K),
					;     receive-stop register enable.
CBCONF_LEN	equ	$-CBCONF
.erre	(CBCONF_LEN and 1) eq 0		;must be an even # of words.

	include	movemem.asm
	include	timeout.asm
	.286

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
;if we're a high-performance driver, es:di -> upcall.
;exit with nc if ok, or else cy if error, dh set to error number.
	assume	ds:nothing
	cmp	cx,GIANT		; Is this packet too large?
	ja	send_pkt_toobig

	mov	dx,io_addr
	mov	al,CMD0_NOP+CMD0_STAT0	;point to status 0.
	out	dx,al
	in	ax,dx			;has the device gotten reset?
	cmp	ax,0010h		;is the status 10 00 00 00?
	jne	send_pkt_ok		;no.
	in	ax,dx
	cmp	ax,0000h
	jne	send_pkt_ok		;no.
	in	ax,dx			;four bytes of status?
	cmp	ax,0010h		;do we read 10 00 again?
	jne	send_pkt_ok		;no.
	push	ds
	push	cx
	push	si
	push	cs
	pop	ds
	call	init_82593
	pop	si
	pop	cx
	pop	ds
send_pkt_ok:
	mov	dx,io_addr
	call	wait_for_done
	push	cs
	pop	es
	mov	di,transmit_buf
	add	di,2			;leave room for count.
	push	cx
	call	movemem
	pop	cx
	cmp	cx,RUNT			; minimum length for Ether
	ja	oklen
	mov	cx,RUNT			; make sure size at least RUNT
oklen:
	mov	di,transmit_buf
	mov	bx,cx
	add	bx,2			;compute the end of the packet.
					;store a NOP for chaining.
	mov	word ptr es:[di][bx],CMD0_NOP*256+CMD0_NOP
	mov	al,CMD0_TRANSMIT + CMD0_CHNL_1
	mov	es:[di],cx
	add	cx,2			; one more word for chain command.
	call	do_write_command

	clc
	ret
send_pkt_toobig:
	mov	dh,NO_SPACE
	stc
	ret


	public	set_address
set_address:
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
	assume	ds:code
	push	cs
	pop	es
	mov	di,transmit_buf
	add	di,2			;leave room for count.
	repmov	EADDR_LEN
	mov	di,transmit_buf
	mov	al,CMD0_IA_SETUP + CMD0_CHNL_1
	call	do_write_command_cx
	call	wait_for_done
	ret


rcv_mode_6:
	mov	ax,1			;set promiscuous mode.
	mov	CBCONF_MINLEN,0		;allow runts.
	jmp	short reconfigure
rcv_mode_2:
	mov	ax,2			;disable broadcasts.
	jmp	short reconfigure_min
rcv_mode_5:
	mov	ax,8*256+0		;clear promiscuous mode, set MC-all.
	jmp	short reconfigure_min
rcv_mode_3:
	mov	ax,0			;clear promiscuous mode.
reconfigure_min:
	mov	CBCONF_MINLEN,40h
reconfigure:
	and	CBCONF_FLAGS,not 3	;clear existing,
	or	CBCONF_FLAGS,al		;  or in new
	and	CBCONF_MC,not 8		;clear existing,
	or	CBCONF_MC,ah		;  or in new.

	mov	si,offset CBCONF	;copy the cbconf block in.
	push	cs
	pop	es
	mov	di,transmit_buf
	add	di,2			;leave room for count.
	mov	cx,CBCONF_LEN/2		;we already check to be sure it's zero.
	rep	movsw

	mov	di,transmit_buf		;configure from the cbconf.
	mov	cx,CBCONF_LEN
	mov	al,CMD0_CONFIGURE + CMD0_CHNL_1
	call	do_write_command_cx
	call	wait_for_done
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
	mov	dx,io_addr
	mov	al,CMD0_RESET
	out	dx,al
;
; Turn off 82501
;
	mov	al,10h
	out	0e6h,al
	in	al,0e7h
	and	al,not (10000100b)	;Turn off both LAN power and reset bit
	out	0e7h,al

	ret


	public	reset_interface
reset_interface:
;reset the interface.
	assume	ds:code
	ret


;called when we want to determine what to do with a received packet.
;enter with cx = packet length, es:di -> packet type, dl = packet class.
	extrn	recv_find: near

;called after we have copied the packet into the buffer.
;enter with ds:si ->the packet, cx = length of the packet.
	extrn	recv_copy: near

;enter with dx = amount of memory desired.
;exit with nc, dx -> that memory, or cy if there isn't enough memory.
	extrn	malloc: near

	extrn	count_in_err: near
	extrn	count_out_err: near

	public	recv
recv:
;called from the recv isr.  All registers have been saved, ds=cs,
;our interrupt has been acknowledged, and our interrupts have been
;masked at the interrupt controller.
	assume	ds:code
	mov	dx,io_addr
	mov	al,CMD0_NOP + CMD0_STAT0	;reset pointer to 0
	out	dx,al
	in	al,dx			;get the event.
	test	al,CMD0_ACK		;an actual interrupt?
	jne	recv_interrupt
	jmp	recv_exit		;no.
recv_interrupt:
	test	al,40h			;recv?
	jne	recv_packet
;we also need to check for a stop register hit, because the 593 might only
;report that to us, and not report a received frame.
	and	al,0fh
	cmp	al,STOP_REG_HIT		;did we overflow the buffer?
	je	recv_packet		;yes, suck all the packets out.
	mov	al,CMD0_ACK or CMD0_NOP	;ack the interrupt and leave.
	out	dx,al
	jmp	recv_exit
recv_packet:
	mov	al,CMD0_NOP or CMD0_STAT2;get receive frame pointer (RFP).
	out	dx,al
	in	ax,dx			;RFP is actually a count of words, so
	shl	ax,1			;  convert it to a byte count.

	mov	di,receive_buf		;make di -> buffer.
	add	di,ax
	mov	recv_buf_cnt,RECEIVE_BUF_SIZE/64
	mov	this_rfp_ptr,di
	xor	si,si			;no previous.
;now we traverse the buffer, looking backwards from the current RFP back
;to the previous RFP.  When we find a packet, we make a forward pointer
;by storing si.  We also un-wrap the packet trailer by storing it in place.
;This is cool because we've allocated an extra 8 bytes of memory
;to the receive buffer.  We're not being particularly paranoid--if
;something very bad happens, we might loop forever here.
recv_rfp:
	dec	recv_buf_cnt	; are we lost in the forest?
	jnz	recv_no_loop

	to_scrn	23,79,'g'	; This occurs now and then!!!

	jmp	recv_next	; a life-saver, otherwise we'll get a hang

recv_no_loop:
	call	receive_word		;get the word of high count.
	mov	ch,al
	call	receive_word		;get the word of low count.
	mov	cl,al
	call	receive_word		;get the word of high status.
	mov	bh,al
	call	receive_word		;get the word of low status.
	mov	bl,al
	sub	cx,2			;remove the status bytes from count.
	mov	[di+2],bx		;save the whole status
	mov	[di+4],cx		;save the whole count.
	mov	[di+6],si		;store the pointer to the end.
	lea	si,[di+8]		;remember where block started.

	inc	cx			;round up.
	and	cx,not 1
	sub	di,cx
	cmp	di,receive_buf		;does it wrap around?
	jae	recv_buf_ok		;no.
	add	di,RECEIVE_BUF_SIZE	;yes, wrap it around.
recv_buf_ok:
	cmp	di,last_rfp_ptr		;did we hit the last one we did?
	jne	recv_rfp		;no, keep going.

;we get here after making a linked list of packets.  Now we loop forwards
;processing packets and returning their memory to the 593.

recv_again:
;here with di -> beginning of data, si -> after header.
	mov	cx,[si-4]		;get the count
	mov	bx,[si-6]		;get the status.

	test	bx,GOODRECEIVE		;received ok?
	je	recv_err		;no, discard it.

	push	ds
	pop	es

	push	si
	push	di

;make a pointer to the packet type
	add	di,EADDR_LEN+EADDR_LEN	;skip the ethernet addreses and
					;  point to the packet type.
	cmp	di,receive_buf_end	;do we need to wrap?
	jb	recv_type_wrap
	sub	di,RECEIVE_BUF_SIZE
recv_type_wrap:

;does our type overlap the end?
	lea	ax,[di+MAX_P_LEN]
	cmp	ax,receive_buf_end
	jb	recv_type_ok		;no, we're cool.

	push	cx
	mov	si,di			;uh-oh, we've got to make a copy.
	mov	di,offset packet_type
	mov	cx,MAX_P_LEN
	call	receive_move		;copy in, wrapping as needed.
	pop	cx

	mov	di,offset packet_type
recv_type_ok:
	mov	dl, BLUEBOOK		;assume bluebook Ethernet.
	mov	ax, es:[di]
	xchg	ah, al
	cmp 	ax, 1500
	ja	BlueBookPacket
	inc	di			;set di to 802.2 header
	inc	di
	mov	dl, IEEE8023
BlueBookPacket:
	push	cx
	call	recv_find
	pop	cx

	pop	si			;(pushed as di).
	pop	bp			;(pushed as si).

	mov	ax,es			;is this pointer null?
	or	ax,di
	je	recv_free		;yes - just free the frame.

	push	es
	push	di
	push	cx
	call	receive_move		;copy in, wrapping as needed.
	pop	cx
	pop	si
	pop	ds
	assume	ds:nothing

	push	bp
	call	recv_copy
	pop	bp			;pushed as si originally.

	jmp	short recv_free

recv_err:
	mov	bp,si
	call	count_in_err
recv_free:
	push	cs
	pop	ds
	assume	ds:code

;We update the stop register now.  We're done with the memory we
;just sucked the packet out of.  Since we will never look at that packet
;again, we should release it's memory back to the hardware.

	mov	di,bp			;make di ->new data,
	cmp	bp,receive_buf_end	;did our packet trailer wrap?
	jb	recv_free_nowrap	;no.
	sub	bp,RECEIVE_BUF_SIZE	;yes,
recv_free_nowrap:

	mov	dx,io_addr
	mov	ax,bp			;compute the new stop register.
	sub	ax,receive_buf
	call	update_stop_hit

	mov	si,[di-2]		;make si ->new header.
	or	si,si
	je	recv_next

	mov	di,bp			;make di -> beginning of new data.
	jmp	recv_again
recv_next:
	mov	ax,this_rfp_ptr
	mov	last_rfp_ptr,ax		;remember where the most recent was.
	mov	al,CMD0_ACK or CMD0_NOP or CMD0_STAT0	;ack the interrupt.
	out	dx,al
	in	al,dx			;is there another interrupt?
	test	al,CMD0_ACK
	je	recv_exit		;no.
	jmp	recv_interrupt
recv_exit:
	ret

receive_word:
;enter with di -> after word to fetch
	assume	ds:code
	sub	di,2
	cmp	di,receive_buf		;time to wrap around?
	jae	receive_buf_1		;no.
	add	di,RECEIVE_BUF_SIZE	;yes, wrap round.
receive_buf_1:
	mov	al,[di]			;fetch the word.
	ret

receive_move:
;enter with ds:si,cx -> packet that might wrap.  Copy it to es:di.
	assume	ds:code
	mov	ax,si			;does it wrap?
	add	ax,cx
	cmp	ax,receive_buf_end
	jbe	receive_move_1		;no, just copy it.
	mov	ax,receive_buf_end	;compute the size of first half.
	sub	ax,si
	sub	cx,ax			;move the rest in second part.
	push	cx
	mov	cx,ax			;set the count for the first move.
	call	movemem
	pop	cx
	mov	si,receive_buf		;and point to the wrapped part.
receive_move_1:
	call	movemem
	ret


segmoffs_to_phys:
;enter with es:di -> buffer.
;exit with dx:ax as the physical address of the buffer,

	mov	dx,es			;get the high 4 bits of the segment,
	shr	dx,16-4
	mov	ax,es			;and the low 12 bits of the segment.
	shl	ax,4
	add	ax,di			;add in the offset.
	adc	dx,0
	ret


do_write_command_cx:
;enter with al=command, es:di -> buffer, cx = length in bytes (must be even)
;  of command AND DMA transfer size.
	mov	es:[di],cx		;set the count to the DMA count.
do_write_command:
;enter with al=command, es:di -> buffer, cx = DMA length in bytes (must be
;  even), word ptr es:[di] set to command size.
	assume	ds:nothing
	push	ax			;save the command

; *just* in case, we wait here for the previous command to finish.
	mov	dx,io_addr
	call	wait_for_done

	add	cx,2+1			;include the command's count in the
					;DMA count.
	and	cl,0feh			;round up.

	mov	al,DMA_DISABLE		; Disable DMA for this channel
	or	al,tx_channel
	out	DMA_MASK,al
	pause_

	out	DMA_RESETFF,al		; Reset byte pointer flipflop
	pause_

; The 16-bit DMA controller ties the low address bit low, and drives
; a1-16.  The low bit of the page register is discarded.

	call	segmoffs_to_phys
	shr	dx,1			;convert to words.
	rcr	ax,1

	mov	dx,tx_dma_dest		; Output buf start (source) address
	out	dx,al
	pause_
	mov	al,ah
	out	dx,al
	pause_

	mov	ax,cx			;convert the byte count into word count.
	shr	ax,1
	dec	ax			;DMA controller does one count less.
	add	dx,2			;point to count registers.
	out	dx,al
	pause_
	mov	al,ah
	out	dx,al
	pause_

; Set DMA mode register to single transfers, incrementing address,
; no auto init, reads
	mov	al,DMA_TX_MODE
	or	al,tx_channel
	out	DMA_MODE,al
	pause_

; Unmask channel n (enable DMA controller chip)
	mov	al,DMA_ENABLE		; Enable DMA for this channel
	or	al,tx_channel
	out	DMA_MASK,al

;now issue the command
	pop	ax
	mov	dx,io_addr
	out	dx,al

	ret

wait_for_done:
;enter with dx set to io_addr.
;exit with cy if we timed out.
	assume	ds:nothing
;first check to see if we're busy at all.
	mov	al,CMD0_NOP + CMD0_STAT3
	out	dx,al
	in	al,dx
	and	al,3			;get the status of the execution
	je	wait_for_done_3		;not busy -- just exit.

	mov	ax,18			;wait half a second, max.
	call	set_timeout
wait_for_done_1:
	mov	al,CMD0_NOP + CMD0_STAT3
	out	dx,al
	in	al,dx
	and	al,3			;get the status of the execution
	je	wait_for_done_2
	call	do_timeout
	jne	wait_for_done_1
	mov	al,CMD0_ABORT		;abort the current command.
	out	dx,al
	stc
	ret
wait_for_done_2:
	mov	al,CMD0_ACK or CMD0_NOP	;ack the interrupt we just got.
	out	dx,al
wait_for_done_3:
	ret

update_stop_hit:
;enter with dx set to io_addr, ax=RFP
	assume	ds:code
	push	ax
	mov	al,CMD0_PORT_1		;switch to port 1.
	out	dx,al
	pop	ax
;delete all the bits from the pointer but leave seven.  Also, RECEIVE_BUF_BITS
;is in terms of bytes, so convert it to words by shift it right once more.
	mov	cl,RECEIVE_BUF_BITS - 7	+ 1	;move over to right position.
	shr	ax,cl
	or	al,80h			;make into CMD1_STOP_REG_UPDATE.
	out	dx,al
	mov	al,CMD1_PORT_0		;switch back to port 0.
	out	dx,al
	ret

init_82593:
	push	ds
	pop	es
	mov	di,transmit_buf
	mov	es:[di+2],word ptr 0	;we're still in byte mode, so zero
					;the second word also.

	xor	cx,cx			;zero length.
	mov	al,CMD0_CONFIGURE + CMD0_CHNL_1
	call	do_write_command_cx
	call	wait_for_done

	call	rcv_mode_3		;configure the 82593.

	mov	si,offset rom_address
	mov	cx,EADDR_LEN
	call	set_address

	mov	dx,io_addr
	mov	ax,RECEIVE_BUF_SIZE
	call	update_stop_hit

	mov	dx,io_addr
	mov	al,CMD0_RCV_ENABLE + CMD0_CHNL_0
	out	dx,al

	ret


	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret

;any code after this will not be kept.  Buffers used by the program, if any,
;are allocated from the memory between end_resident and end_free_mem.
	public end_resident,end_free_mem
	align	4
end_resident	label	byte
	db	(RECEIVE_BUF_SIZE+8 + 2*TRANSMIT_BUF_SIZE) dup(?)
end_free_mem	label	byte

	public	usage_msg
usage_msg	db	"usage: znote [options] <packet_int_no>",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for the ZDS Z-Note, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
		db	'$'

not_here_msg	label	byte
db "Cannot run the Z-Note packet driver at this segment address.  Try",CR,LF
db "running it at a different point in your AUTOEXEC.BAT",CR,LF,'$'
no_sig_msg	db	"This machine does not have built-in networking (no NETIDBLK found)",CR,LF,'$'
no_memory_msg	db	"Unable to allocate enough memory, look at end_resident in ZNOTE.ASM",CR,LF,'$'
no_power_msg	db	"Networking is disabled.  Use Fn-Setup/Devices Control to enable HSC Port.",CR,LF,'$'

netidblk_sig	db	"NETIDBLK"
NETIDBLK_SIG_LEN	equ	$-netidblk_sig	;we assume this is even.

dma_page_addrs	db	0, 8bh, 89h, 8ah

;called when you're ready to receive interrupts.
	extrn	set_recv_isr: near

;enter with si -> argument string, di -> dword to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> argument string, di -> dword to print.
	extrn	print_number: near

;-> the unique Ethernet address of the card.  Filled in by the etopen routine.
	extrn	rom_address: byte

;-> current address.  Normally the same as rom_address, unless changed
;by the set_address() call.
	extrn	my_address: byte

;parse_args is called with si -> first parameter (CR if none).
	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	clc
	ret


	public	etopen
etopen:
;initialize the driver.  Fill in rom_address with the assigned address of
;the board.  Exit with nc if all went well, or cy, dx -> $ terminated error msg.
;if all is okay,
	assume	ds:code

	mov	ax,0f000h
	mov	es,ax
	xor	di,di
find_signature:
	mov	si,offset netidblk_sig
	mov	cx,NETIDBLK_SIG_LEN/2	;we happen to know it's even.
	push	di
	repe	cmpsw
	pop	di
	je	find_signature_1
	inc	di
	cmp	di,-(size id_block)	;enough room for one more?
	jb	find_signature
	mov	dx,offset no_sig_msg
	stc
	ret
no_memory:
	mov	dx,offset no_memory_msg
	stc
	ret
find_signature_1:
	mov	ax,es:[di].iobase1
	mov	io_addr,ax
	mov	al,es:[di].intr1
	mov	int_no,al

	mov	al,es:[di].dma1
	and	al,3
	mov	rx_channel,al
	mov	dx,DMA_BASE
	shl	al,1
	shl	al,1
	add	dl,al
	mov	rx_dma_dest,dx

	mov	al,es:[di].dma2
	and	al,3
	mov	tx_channel,al
	mov	dx,DMA_BASE
	shl	al,1
	shl	al,1
	add	dl,al
	mov	tx_dma_dest,dx

	mov	bx,offset dma_page_addrs
	mov	al,rx_channel
	xlat
	xor	ah,ah
	mov	rx_page_addr,ax

	mov	al,tx_channel
	xlat
	xor	ah,ah
	mov	tx_page_addr,ax

	mov	si,offset rom_address
	mov	cx,EADDR_LEN
	push	di
	lea	di,[di].netid
copy_rom_address:
	mov	al,es:[di]
	inc	di
	mov	ds:[si],al
	inc	si
	loop	copy_rom_address
	pop	di

;
; Turn on 82501
;
	mov	al,10h			;LAN control port index
	out	0e6h,al			;Output index to E6 port
	in	al,0e7h			;Get data from E7 port
	or   	al,10000100b		;Turn off LAN reset and
					;  on bit 2: LAN power bit
	out	0e7h,al
	mov	ax,2			;delay 50 ms here to wait for LAN clock
	call	delay			;  to stablize.

	mov	dx,io_addr		;reset the 82593.
	mov	ax,CMD0_RESET
	out	dx,al
;Strictly speaking, the following code isn't needed, because we *just*
;turned the thing on!  But it's small and straightforward and unlikely
;to break anything, so we'll leave it in.
	in	ax,dx
	cmp	ax,0010h
	jne	powered_off
	in	ax,dx
	cmp	ax,0000h
	je	powered_on
powered_off:
	mov	dx,offset no_power_msg
	stc
	ret
powered_on:

;Here we get a transmit buffer.  If it wraps around a segment, we
;discard it and get another transmit buffer.  Note that we can't loop
;forever because the buffer is smaller than 64K, so if the first time
;it wraps, the second it definitely won't.
transmit_again:
	mov	dx,TRANSMIT_BUF_SIZE	;request a transmit buffer.
	call	malloc
	jnc	have_tx_mem
no_memory_1:
	jmp	no_memory
have_tx_mem:
	mov	transmit_buf,dx

	push	cs
	pop	es
	mov	di,transmit_buf
	call	segmoffs_to_phys
	add	ax,TRANSMIT_BUF_SIZE
	jc	transmit_again		;uh-oh, we'll go try again.

	mov	al,dl			; get the page part of the address.
	mov	dx,tx_page_addr		; Set up transmit DMA page register
	out	dx,al
	pause_

;we may need as many as 8 extra bytes following the end of the receive
;buffer, because we store a pointer to the next packet there.
	mov	dx,RECEIVE_BUF_SIZE+8	;request a receive buffer.
	call	malloc
	jc	no_memory_1
	mov	receive_buf,dx
	mov	last_rfp_ptr,dx
	add	dx,RECEIVE_BUF_SIZE
	mov	receive_buf_end,dx

	push	cs
	pop	es
	mov	di,receive_buf
	call	segmoffs_to_phys
	add	ax,RECEIVE_BUF_SIZE
	jnc	receive_ok
	mov	dx,offset not_here_msg
	stc
	ret
receive_ok:
	mov	al,dl			; get the page part of the address.
	mov	dx,rx_page_addr		; Set up receive DMA page register
	out	dx,al
	pause_

	push	cs
	pop	es
	mov	di,receive_buf
	mov	cx,RECEIVE_BUF_SIZE

	mov	al,DMA_DISABLE		; Disable DMA for this channel
	or	al,rx_channel
	out	DMA_MASK,al
	pause_

	out	DMA_RESETFF,al		; Reset byte pointer flipflop
	pause_

; The 16-bit DMA controller ties the low address bit low, and drives
; a1-16.  The low bit of the page register is discarded.

	call	segmoffs_to_phys
	shr	dx,1			;convert to words.
	rcr	ax,1

	mov	dx,rx_dma_dest		; Output buf start (source) address
	out	dx,al
	pause_
	mov	al,ah
	out	dx,al
	pause_

	mov	ax,cx			;convert the byte count into word count.
	shr	ax,1
	dec	ax			;DMA controller does one count less.
	add	dx,2			;point to count registers.
	out	dx,al
	pause_
	mov	al,ah
	out	dx,al
	pause_

; Set DMA mode register to single transfers, incrementing address,
; no auto init, reads
	mov	al,DMA_RX_MODE
	or	al,rx_channel
	out	DMA_MODE,al
	pause_

; Unmask channel n (enable DMA controller chip)
	mov	al,DMA_ENABLE		; Enable DMA for this channel
	or	al,rx_channel
	out	DMA_MASK,al

	call	init_82593

	call	set_recv_isr

	clc
	ret

delay_27_5ms:
;delay one timeout period, which is 27.5 ms.
	mov	ax,1
delay:
;delay AX timeout periods, each of which is 27.5 ms.
	call	set_timeout
delay_1:
	call	do_timeout
	jnz	delay_1
	ret


	public	print_parameters
print_parameters:
;echo our command-line parameters
	ret

code	ends

	end
