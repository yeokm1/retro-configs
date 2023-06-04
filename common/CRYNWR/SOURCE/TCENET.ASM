version	equ	0
;History:916,1

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

	.286				;the tcenet requires a 286.

comment \

We have to lock all the data structures accessed by the board.  We
also have to keep track of which ones have been locked and which have not.

\

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
	in	ax, 61h
	pop	ax
;
endm

DMA_8MASK_REG	equ	0Ah
DMA_8MODE_REG	equ	0Bh
DMA_16MASK_REG	equ	0D4h
DMA_16MODE_REG	equ	0D6h

CASCADE_MODE      equ	0C0h
SET_DMA_MASK      equ	4
DMA_CHANNEL_FIELD equ	3

;tcenet registers.
EBASE		equ	0
CONFIG		equ	0eh
PORTPAGE	equ	0fh
SONICREG	equ	10h

;we don't use setport to refer to Sonic registers, because of the crufty
;port paging.
sncport	macro	new_port_no
;	if ((new_port_no xor port_no) and (not 0fh)) or (port_no EQ 0)

	loadport
		setport	PORTPAGE
		push	ax
		mov	al, (new_port_no shr 1)
		out	dx,al
		in	al,61h		;see pause_ macro.
		pop	ax

;	endif

	setport	<(SONICREG+(new_port_no and 0fh))>
	endm


RDA_COUNT	equ	8

TRANSMIT_BUF_COUNT	equ	1
RECEIVE_BUF_COUNT	equ	2
TRANSMIT_BUF_SIZE	equ	1520
RECEIVE_BUF_SIZE	equ	1522*2

EOL		equ	1		;descriptor EOL flag

;-----------------------------------------------------------------------------
;
;	Sonic Register Definitions

;	Sonic command register bits

LCAM	equ	0200h			;Load CAM
RRRA	equ	0100h			;Read RRA
RST	equ	0080h			;Software Reset
ST	equ	0020h			;Start Timer
STP	equ	0010h			;Stop Timer
RXEN	equ	0008h			;Receiver Enable
RXDIS	equ	0004h			;Receiver Disable
TXP	equ	0002h			;Transmit packets
HTX	equ	0001h			;Halt transmission

;	Sonic Data Configuration Register Bits

EXBUS	equ	8000h			;Extended Bus mode
LBR	equ	2000h			;Latched Bus Retry
PO1	equ	1000h			;Programmable Outputs
PO0	equ	0800h			;. .
SBUS	equ	0400h			;Synchronous Bus Mode
USR1	equ	0200h			;User Definable Pins
USR0	equ	0100h			;. .
WC1	equ	0080h			;Wait State Control
WC0	equ	0040h			;. .
DW32	equ	0020h			;Data Width Select
BMS	equ	0010h			;Block Mode Select for DMA
RFT1	equ	0008h			;Receive FIFO Threshold
RFT0	equ	0004h			;. .
TFT1	equ	0002h			;Transmit FIFO Threshold
TFT0	equ	0001h			;. .

;	Sonic Receive Control Register bits

ERR	equ	8000h			;Accept Packet with Errors
RNT	equ	4000h			;Accept Runt Packets
BRD	equ	2000h			;Accept Broadcast Packets
PRO	equ	1000h			;Accept all Physical Packets (Promiscuous Mode)
AMC	equ	0800h			;Accept all Multicast Packets
LB1	equ	0400h			;Loopback Control 1
LB0	equ	0200h			;Loopback Control 0
MCRx	equ	0100h			;Multicast Packet Received
BCRx	equ	0080h			;Broadcast Packet Received
LPKT	equ	0040h			;Last Packet in RBA
CRS	equ	0020h			;Carrier Sense Activity
COL	equ	0010h			;Collision Activity
CRCR	equ	0008h			;CRC Error
FAER	equ	0004h			;Frame Alignment Error
LBK	equ	0002h			;LoopBack Packet Received
PRX	equ	0001h			;Packet Received OK

;	Transmit Control Register bits

PINTR	equ	8000h			;Programmable Interrupt
POWC	equ	4000h			;Program 'Out of Window Collision' Timer
CRCI	equ	2000h			;CRC Inhibit
EXDIS	equ	1000h			;Disable Excessive Deferral Timer
EXD	equ	0400h			;Excessive Deferral
DEF	equ	0200h			;Deferred Transmission
NCRS	equ	0100h			;No CRS
CRSL	equ	0080h			;CRS Lost
EXC	equ	0040h			;Excessive Collisions
OWC	equ	0020h			;Out of Window Collision
PMB	equ	0008h			;Packet Monitored Bad
FU	equ	0004h			;Tx FIFO UnderRun
BCM	equ	0002h			;Byte Count Mismatch
PTX	equ	0001h			;Packet Transmitted OK

TXDONE	equ	EXD or CRSL or EXC or PTX	;nonzero when transmit done.

;	Interrupt Mask Register bits

BREN	equ	4000h			;Bus Retry Occurred Enable
HBLEN	equ	2000h			;HeartBeat Lost Enable
LCDEN	equ	1000h			;Load CAM Done Interrupt Enable
PINTEN	equ	0800h			;Programmable Interrupt Enable
PRXEN	equ	0400h			;Packet Received Enable
PTXEN	equ	0200h			;Packet Transmitted OK Enable
TXEREN	equ	0100h			;Transmit Error Enable
TCEN	equ	0080h			;Timer Complete Enable
RDEEN	equ	0040h			;Receive Descriptors Exhausted Enable
RBEEN	equ	0020h			;Receive Buffers Exhausted Enable
RBAEEN	equ	0010h			;Receive Buffer Area Exceeded Enable
CRCEN	equ	0008h			;CRC Tally Counter Warning Enable
FAEEN	equ	0004h			;FAE Tally Counter Warning Enable
MPEN	equ	0002h			;MP Tally Counter Warning Enable
RFOEN	equ	0001h			;Receive FIFO Overrun Enable

; these are the interrupts we enable:
enabled_IMR	equ	(PTXEN or TXEREN or PRXEN or RBEEN or BREN)

;	Interrupt Status Register bits

BR	equ	4000h			;Bus Retry Occurred
HBL	equ	2000h			;HeartBeat Lost
LCD	equ	1000h			;Load CAM Done
PINT	equ	0800h			;Programmable Interrupt
PKTRX	equ	0400h			;Packet Received
TXDN	equ	0200h			;Transmission Done
TXER	equ	0100h			;Transmit Error
TC	equ	0080h			;Timer Complete
RDE	equ	0040h			;Receive Descriptors Exhausted
RBE	equ	0020h			;Receive Buffers Exhausted
RBAE	equ	0010h			;Receive Buffer Area Exceeded
CRC	equ	0008h			;CRC Tally Counter Rollover
FAE	equ	0004h			;FAE Tally Counter Rollover
MP	equ	0002h			;Missed Packet Tally Counter Rollover
RFO	equ	0001h			;Receive FIFO Overrun

;SONIC registers.  The registers are sixteen-bit registers that are also
;byte-addressable.  So, the word addresses must be multiplied by two.

;	Command and Status Register Offsets

SonicCR		equ	(0 * 2)
SonicDCR	equ	(1 * 2)
SonicRCR	equ	(2 * 2)
SonicTCR	equ	(3 * 2)
SonicIMR	equ	(4 * 2)
SonicISR	equ	(5 * 2)

;	Transmit Registers

SonicUTDA	equ	(6 * 2)
SonicCTDA	equ	(7 * 2)

;	Receive Registers

SonicURDA	equ	(0dh * 2)
SonicCRDA	equ	(0eh * 2)
SonicEOBC	equ	(13h * 2)
SonicURRA	equ	(14h * 2)
SonicRSA	equ	(15h * 2)
SonicREA	equ	(16h * 2)
SonicRRP	equ	(17h * 2)
SonicRWP	equ	(18h * 2)
SonicRSC	equ	(2bh * 2)

;	CAM Registers

SonicCEP	equ	(21h * 2)
SonicCAP2	equ	(22h * 2)
SonicCAP1	equ	(23h * 2)
SonicCAP0	equ	(24h * 2)
SonicCE		equ	(25h * 2)
SonicCDP	equ	(26h * 2)
SonicCDC	equ	(27h * 2)

;	Tally Counters

SonicCRCT	equ	(2ch * 2)
SonicFAET	equ	(2dh * 2)
SonicMPT	equ	(2eh * 2)

;	Watchdog Counters

SonicWT0	equ	(29h * 2)
SonicWT1	equ	(2ah * 2)

;	Silicon Revision

SonicSR		equ	(28h * 2)

;Receiver Resource Area

rra_struc	struc
rra_ptr		dd	?
rra_cnt		dd	?
rra_struc	ends

;Receiver Descriptor Area

rda_struc	struc
rda_status	dw	?
rda_byte_count	dw	?
rda_ptr		dd	?
rda_seq_number	dw	?
rda_link	dw	?
rda_in_use	dw	?
rda_backlink	dw	?		;for our own purposes, not SONIC's.
rda_forelink	dw	?		;for our own purposes, not SONIC's.
rda_struc	ends

;	Transmit Descriptor structure

tda_struc	struc
tda_status	dw	?
tda_config	dw	?
tda_size	dw	?
tda_frag_count	dw	?
tda_frag_ptr	dd	?
tda_frag_size	dw	?
tda_link	dw	?
tda_struc	ends

; Content-Addressible Memory descriptor.

cam_struc	struc
cam_entry_ptr	dw	0
cam_addr0	dw	0
cam_addr1	dw	0
cam_addr2	dw	0
cam_struc	ends

dds_struc	struc
dds_size	dd	0		;region size.
dds_offset	dd	0		;offset (using 32 bits)
dds_seg		dw	0		;segment or selector
dds_buffer_id	dw	0
dds_physical	dd	0		;physical address
dds_struc	ends

;MAX8023LENGTH		equ	1514
MAX8023LENGTH		equ	1520

code	segment	para public
	assume	cs:code, ds:code

	public	int_no
int_no		db	3,0,0,0		;must be four bytes long for get_number.
io_addr		dw	-1,-1
port_addr	dw	?
dma_no		db	?

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
driver_type	db	89		;from the packet spec
driver_name	db	'TCENET',0	;name of the driver.
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

		align	2
	public	rcv_modes
rcv_modes	dw	7		;number of receive modes in our table.
		dw	0               ;There is no mode zero
		dw	rcv_mode_1
		dw	rcv_mode_2	;only ours.
		dw	rcv_mode_3	;ours plus broadcast
		dw	0		;some multicasts
		dw	rcv_mode_5	;all multicasts
		dw	rcv_mode_6	;all packets

my_dds		dds_struc<>
vds_active	db	?		;<>0 if memory mapping is on.

tdaptr		dw	tda1		;-> the TDA's we're using.
rraptr		dw	rra1
camptr		dw	cam1		;-> the CAM we're using.
camcount	dw	1		;always has our address.
rdaptr		dw	rda1
next_rda	dw	?

	include	timeout.asm
	include	movemem.asm

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
;enter with ds:si -> packet, cx = packet length.
;exit with nc if ok, or else cy if error, dh set to error number.
	assume	ds:nothing

	mov	bx,tdaptr

	mov	ax,18
	call	set_timeout
	loadport
	sncport	SonicCR
send_pkt_1:
	in	ax,dx
	test	ax,TXP
	je	send_pkt_2		;zero means yes, done transmitting.
;	test	code:[bx].tda_status,TXDONE	;Is the SONIC done transmitting it?
;	jne	send_pkt_2		;any non-zero means yes.
	call	do_timeout
	jne	send_pkt_1
	mov	dh,CANT_SEND
	stc
	ret
send_pkt_2:

	mov	ax,cx			;store the count.
	cmp	ax,RUNT			; minimum length for Ether
	ja	oklen
	mov	ax,RUNT			; make sure size at least RUNT
oklen:
	mov	code:[bx].tda_frag_size,cx
	mov	code:[bx].tda_size,cx

	mov	code:[bx].tda_config,0

	mov	ax,code:[bx].tda_frag_ptr.offs	;store the packet.
	mov	dx,code:[bx].tda_frag_ptr.segm
	call	phys_to_segmoffs
	call	movemem

	lea	di,code:[bx].tda_status	;get the address of the TDA.
	movseg	es,cs
	call	segmoffs_to_phys
	loadport			;point the CTDA to the TDA.
	sncport	SonicCTDA
	out	dx,ax
	sncport	SonicCR			;command SONIC to transmit.
	mov	ax,TXP
	out	dx,ax
	clc
	ret


	public	get_address
get_address:
;get the address of the interface.
;enter with es:di -> place to get the address, cx = size of address buffer.
;exit with nc, cx = actual size of address, or cy if buffer not big enough.
	assume	ds:code
	cmp	cx,EADDR_LEN		;make sure that we have enough room.
	jb	get_address_2
	mov	cx,EADDR_LEN
	loadport			; Get our Ethernet address base.
	setport	EBASE
	cld
get_address_1:
	insb				; get a byte of the eprom address
	inc	dx			; next register
	loop	get_address_1		; go back for rest
	mov	cx,EADDR_LEN
	clc
	ret
get_address_2:
	stc
	ret


	public	set_address
set_address:
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
	assume	ds:nothing
	cmp	cx,EADDR_LEN		;ensure that their address is okay.
	je	set_address_4
	mov	dh,BAD_ADDRESS
	stc
	jmp	short set_address_done
set_address_4:

	movseg	es,cs
	mov	di,camptr		;point di to our Ethernet adddr.
	add	di,2
	rep	movsb

	movseg	ds,cs
	assume	ds:code

	call	load_cam		;initialize with our new address.
	mov	dh,CANT_SET		;just in case.
	jc	set_address_done
set_address_okay:
	mov	cx,EADDR_LEN		;return their address length.
	clc
set_address_done:
	ret

load_cam:
	loadport
	sncport	SonicCR
load_cam_1:
	in	ax,dx			;wait for transmit done.
	test	ax,TXP
	jne	load_cam_1		;nonzero means still transmitting.

	movseg	es,ds
	mov	di,camptr		;point the Descriptor Pointer Register
	call	segmoffs_to_phys
	sncport	SonicCDP		;  to our CAM area.
	out	dx,ax
	pause_

	sncport	SonicCDC		;load the CAM descriptor table length.
	mov	ax,camcount
	out	dx,ax
	pause_

	sncport	SonicCR
	mov	ax,LCAM			;load the CAM.
	out	dx,ax

	ret


rcv_mode_2:
	mov	ax,0			;accept only mine
	jmp	short rcv_mode_set
rcv_mode_3:
	mov	ax,BRD			;accept mine + broadcast
	jmp	short rcv_mode_set
rcv_mode_5:
	mov	ax,AMC			;accept any multicast frames.
	jmp	short rcv_mode_set
rcv_mode_6:
	mov	ax,RNT or PRO or BRD or AMC	;promiscuous mode (runts also)
rcv_mode_set:
	loadport
	sncport	SonicRCR
	out	dx,ax
	pause_
	mov	ax,RXEN			;enable reception.
	jmp	short rcv_mode_set_1
rcv_mode_1:
	mov	ax,RXDIS		;disable the receiver.
rcv_mode_set_1:
	loadport			;enable or disable reception.
	sncport	SonicCR
	out	dx,ax
	pause_
	ret


	public	set_multicast_list
set_multicast_list:
;enter with ds:si ->list of multicast addresses, ax = number of addresses,
;  cx = address byte count.
;return nc if we set all of them, or cy,dh=error if we didn't.

	mov	cx,ax
	inc	ax			;one more for our Ethernet address.
	mov	camcount,ax
	mov	ax,1
	mov	di,camptr
	add	di,8			;skip first entry (our address).
set_multicast_list_1:
	stosw				;store the CAM entry number.
	movsw				;move the address over.
	movsw
	movsw
	loop	set_multicast_list_1

	mov	cx,camcount		;compute the enable mask.
	mov	ax,-1			;shift zeroes in, then turn them
	shl	ax,cl
	not	ax			;  into ones.
	stosw				;store the enable mask.

	call	load_cam		;now stick it to the hardware.

	mov	dh,NO_MULTICAST		;for some reason we can't do multi's.
	stc
	ret


	public	terminate
terminate:
	loadport
	sncport SonicCR
	mov	ax,RST or STP or RXDIS	;reset the sonic, stop timer, stop rcv.
	out	dx,ax

;This routine will remove the (host) DMA controller from
;cascade mode of operation.
	mov	al,dma_no
	or	al,SET_DMA_MASK
	cmp	dma_no,4		;If channel 5 or 6,
	ja	terminate_16		;  use sixteen bit dma.
terminate_8:
	out	DMA_8MASK_REG,al
	jmp	short terminate_done
terminate_16:
	out	DMA_16MASK_REG,al
terminate_done:

; unlock the dma block.
	mov	di,offset my_dds
	mov	ax,cs
	mov	es,ax
	mov	dx,0
	mov	ax,8104h
	int	4bh

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

;call this routine to schedule a subroutine that gets run after the
;recv_isr.  This is done by stuffing routine's address in place
;of the recv_isr iret's address.  This routine should push the flags when it
;is entered, and should jump to recv_exiting_exit to leave.
;enter with ax = address of routine to run.
	extrn	schedule_exiting: near

;recv_exiting jumps here to exit, after pushing the flags.
	extrn	recv_exiting_exit: near

;enter with dx = amount of memory desired.
;exit with nc, dx -> that memory, or cy if there isn't enough memory.
	extrn	malloc: near

	extrn	count_in_err: near
	extrn	count_out_err: near

	public	recv
recv:
;called from the recv isr.  All registers have been saved, and ds=cs.
;Upon exit, the interrupt will be acknowledged.
	assume	ds:code

	loadport
	sncport	SonicIMR
	in	ax,dx
	pause_
	mov	cx,ax			;remember the interrupt mask.
	xor	ax,ax			;clear interrupt requests.
	out	dx,ax
	pause_
	sncport	SonicISR
	in	ax,dx			;now match the IMR against the ISR.
	and	cx,ax
	jnz	recv_1			;if they overlap, then we have a real interrupt.
	ret				;spurious interrupt.

recv_1:
;check out and get rid of interrupt causes.

	test	ax,PKTRX		;packet received?
	jne	recv_2			;yes.
	jmp	recv_rbe		;no, go see if we ran out of buffers.
recv_2:
	and	ax,PKTRX or RBAE	;clear the PKTRX and RBAE flags.
	out	dx,ax

; handle received packet

recv_do_next:
	mov	bx,next_rda		;point to the rda that the sonic filled.
	cmp	[bx].rda_in_use,0	;did they really fill it?
	je	recv_do_next_1		;yes.
	jmp	recv_rbe
recv_do_next_1:
  if 0
	cmp	TossRxFlag,0		;should we toss this one?
	je	recv_do_next_2		;no.
	mov	TossRxFlag,0		;yes, just toss it.
	jmp	recv_err
recv_do_next_2:
  endif
	test	ax,RBAE			;did we exceed the size of the buffer?
	je	recv_do_next_3		;no.
;;;	inc	ReceiveBufferExceeded	;yes.
	jmp	recv_err
recv_do_next_3:
	mov	ax,[bx].rda_status
	test	ax,CRCR			;checksum error?
	je	recv_do_next_4		;no.
;;;	inc	CRCErrors
	jmp	recv_err
recv_do_next_4:
	test	ax,FAER			;alignment error?
	je	recv_do_next_5		;no.
;;;	inc	FrameAlignmentErrors
	jmp	recv_err

recv_do_next_5:
	test	ax,PRX			;otherwise okay?
	jne	recv_do_next_6		;yes.
	jmp	recv_err

recv_do_next_6:

; get logical address of the buffer.

	mov	cx,[bx].rda_byte_count		; bp := # of bytes received
	sub	cx,4			;leave the FCS behind.
	mov	ax,[bx].rda_ptr.offs
	mov	dx,[bx].rda_ptr.segm
	call	phys_to_segmoffs	;make es:di -> packet.

	push	bx
	push	es
	push	di

	add	di,EADDR_LEN+EADDR_LEN	;skip the ethernet addreses and
					;  point to the packet type.
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

	pop	si
	pop	ds
	pop	bx
	assume	ds:nothing

	mov	ax,es			;is this pointer null?
	or	ax,di
	je	recv_free		;yes - just free the frame.

	push	es
	push	di
	push	cx
	call	movemem
	pop	cx
	pop	si
	pop	ds
	assume	ds:nothing

	call	recv_copy

	jmp	short recv_free

recv_err:
	call	count_in_err
recv_free:
	movseg	ds,cs
	assume	ds:code

	test	[bx].rda_status,LPKT	;is it the last packet in the RBA?
	je	recv_not_last		;no, go deal with it.

	push	bx			;we filled up all the RDAs, have
	call	update_rwp		;  to clean up.
	pop	bx

recv_not_last:
	or	[bx].rda_link,EOL	; this RDA is now new EOL.
	mov	[bx].rda_in_use,0ffffh	; sonic now has this one.

	mov	si,[bx].rda_backlink
	and	[si].rda_link,not EOL	;clear EOL in previous RDA.

	sncport	SonicCR
	mov	ax,RXEN
	out	dx,ax			; re-enable Receive

	mov	bx,[bx].rda_forelink	; now move to next rda.
	mov	next_rda,bx

	sncport	SonicISR		; setup for next check
	in	ax,dx
	jmp	recv_do_next

recv_rbe:
;we get here with dx = SonicISR
	in	ax,dx			; get interrupt status
	test	ax,RBE			; is it a Receive Buf Exhaust?
	jz	recv_txdn

; SONIC thinks its out of receive bufs.  ReRead the RDA

;	inc	RxBufferExhaustedCount
	call	update_rwp

	loadport
	sncport	SonicISR
	mov	ax,RBE
	out	dx,ax				; clr int & reread the RDA
	pause_

recv_txdn:
;we get here with dx = SonicISR
	in	ax,dx
	and	ax, (TXDN or TXER)	;done sending pkts?
	jz	recv_txdn_1		;go if not.
	pause_
	out	dx,ax			;clear this cause.
recv_txdn_1:
;we get here with dx = SonicISR
;	cli
	add	dx,-2			;point dx to SonicIMR
	mov	ax,enabled_IMR		;re-enable our ints.
	out	dx,ax

	ret


update_rwp:
	loadport
	sncport	SonicRSA
	in	ax,dx
	pause_
	mov	si,ax			;get the RSA into si.

	sncport	SonicREA
	in	ax, dx
	pause_
	mov	di,ax			;get the REA into di.

	sncport	SonicRWP
	in	ax,dx			; get RWP

	add	si,(RECEIVE_BUF_COUNT * (size rra_struc))/2
					; assume we'll set @ 1/2
	cmp	ax,di			; if at end set to 1/2
	je	update_rwp_1
	mov	si,di			; else its at 1/2 - set to end
update_rwp_1:
	mov	ax,si
	out	dx,ax			; update RWP
	pause_

	ret


phys_to_segmoffs:
;enter with dx:ax as the physical address of the buffer,
;exit with es:di -> buffer.
	cmp	vds_active,0
	jne	phys_to_segmoffs_1
	shl	dx,16-4			;move the upper four bits into position.
	mov	di,ax			;now get the low 12 bits of the segment.
	shr	di,4
	or	dx,di			;combine them.
	mov	es,dx
	mov	di,ax
	and	di,0fh			;now compute the offset.
	ret
phys_to_segmoffs_1:
	sub	ax,my_dds.dds_physical.offs	;make into physical addresses.
	add	ax,offset begin_dma
	mov	di,ax			;make dx:ax be offset into dma region.
	movseg	es,cs
	ret


segmoffs_to_phys:
;enter with es:di -> buffer.
;exit with dx:ax as the physical address of the buffer,
	cmp	vds_active,0
	jne	segmoffs_to_phys_1
	mov	dx,es			;get the high 4 bits of the segment,
	shr	dx,16-4
	mov	ax,es			;and the low 12 bits of the segment.
	shl	ax,4
	add	ax,di			;add in the offset.
	adc	dx,0
	ret
segmoffs_to_phys_1:
	xor	dx,dx			;make dx:ax be offset into dma region.
	mov	ax,di
	sub	ax,offset begin_dma
	add	ax,my_dds.dds_physical.offs	;make into physical addresses.
	adc	dx,my_dds.dds_physical.segm
	ret

	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret

;beginning of the area of memory that the SONIC knows about (and that we will
;  have to lock down for DMA).
begin_dma	label	byte

;we have two tda's because one of them might cross a physical 64K boundary.
;If that happens, then we use the other.
	align	2
tda1	db	(TRANSMIT_BUF_COUNT * size tda_struc) dup(?)
	align	2
tda2	db	(TRANSMIT_BUF_COUNT * size tda_struc) dup(?)

;the rra and cam share a common upper 16 bits of address, therefore they
;must be on the same 64K physical segment.  There's also alignment
;considerations.
	align	2
rra1	dw	RECEIVE_BUF_COUNT * 4 dup(?)
cam1	dw	0			;our address is always zero.
	db	EADDR_LEN dup(?)	;leave room for our address.
	dw	1			;for the CAM Enable register.
	db	(EADDR_LEN+2)*15 dup(?)		;leave room for up to 15 more.
RRA1SIZE	equ	$ - rra1

	align	2
rra2	dw	RECEIVE_BUF_COUNT * 4 dup(?)
cam2	dw	0			;our address is always zero.
	db	EADDR_LEN dup(?)	;leave room for our address.
	dw	1			;for the CAM Enable register.
	db	(EADDR_LEN+2)*15 dup(?)		;leave room for up to 15 more.

;we have two rda's because one of them might cross a physical 64K boundary.
;If that happens, then we use the other.
	align	2
rda1	db	(RDA_COUNT * size rda_struc) dup(?)
	align	2
rda2	db	(RDA_COUNT * size rda_struc) dup(?)

;any code after this will not be kept.  Buffers used by the program, if any,
;are allocated from the memory between end_resident and end_free_mem.
	public end_resident,end_free_mem
	align	4			;just for efficiency's sake.
end_resident	label	byte
	db	(RECEIVE_BUF_COUNT*RECEIVE_BUF_SIZE) + (TRANSMIT_BUF_COUNT*TRANSMIT_BUF_SIZE) dup(?)
end_free_mem	label	byte
;end of the area of memory that the SONIC knows about (and that we will
;  have to lock down for DMA).


	public	usage_msg
usage_msg	db	"usage: tcenet [options] <packet_int_no> <int_no> <io_addr>",CR,LF,'$'
no_board_msg	db	"No tcenet detected.",CR,LF,'$'
io_addr_funny_msg	label	byte
		db	"No tcenet detected, continuing anyway.",CR,LF,'$'
bad_reset_msg	db	"Unable to reset the tcenet.",CR,LF,'$'
bad_init_msg	db	"Unable to initialize the tcenet.",CR,LF,'$'
vds_ver_msg	db	"Using VDS version ",'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for a Thomas-Conrad tcenet, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
		db	'$'

io_addrs	dw	100h,120h,140h,160h,300h,320h,340h,0
io_addrs_end	label	word
int_nos		db	2,3,5,7,10,11,12,15	;interrupt numbers.
dma_nos		db	1,5,6,7		;dma channel numbers

our_address	db	6 dup(?)	;temporarily hold our address

int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'

	extrn	set_recv_isr: near
	extrn	maskint: near

;enter with si -> argument string, di -> dword to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> name of word, di -> dword to print.
	extrn	print_number: near

	extrn	decout: near
	extrn	chrout: near

;print a crlf
	extrn	crlf: near

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


	public	etopen
etopen:
	assume	ds:code

	cmp	io_addr,-1		;Did they ask for auto-detect?
	je	find_board

	call	detect_board		;no, just verify its existance.
	je	find_board_found

	mov	dx,offset io_addr_funny_msg
	mov	ah,9
	int	21h

	jmp	find_board_found

find_board:
	mov	bx,offset io_addrs	;Search for the Ethernet address.
	mov	io_addr+2,0
find_board_0:
	mov	ax,[bx]
	mov	io_addr,ax
	call	detect_board
	je	find_board_found
find_board_again:
	add	bx,2			;not at this port, try another.
	cmp	bx,offset io_addrs_end	;last address?
	jb	find_board_0

	mov	dx,offset no_board_msg	;Tell them that we can't find it.
	mov	ah,9
	int	21h

	stc
	ret
find_board_found:

	loadport
	sncport SonicCR
	mov	ax,RST or STP or RXDIS	;reset the sonic, stop timer, stop rcv.
	out	dx,ax
	pause_

	setport	CONFIG			;get the configuration register and
	in	ax,dx			;  determine the interrupt number.
	and	ax,7
	mov	bx,ax
	mov	al,int_nos[bx]
	mov	int_no,al

;This routine will put the (host) DMA controller into
;cascade mode of operation.

	in	ax,dx			;get the dma channel field.
	shr	ax,3
	and	ax,3
	mov	bx,ax
	mov	al,dma_nos[bx]
	mov	dma_no,al
	mov	ah,al			;save a copy.
	and	al,DMA_CHANNEL_FIELD
	or	al,SET_DMA_MASK
	cmp	ah,4			;If channel 5 or 6,
	ja	dma_16			;  use sixteen bit dma.
dma_8:
	out	DMA_8MASK_REG,al	;mask the channel off.
	mov	al,ah
	or	al,CASCADE_MODE		;put it into cascade mode.
	out	DMA_8MODE_REG,al
	mov	al,ah			;turn the channel on.
	out	DMA_8MASK_REG,al
	jmp	short dma_done
dma_16:
	and	ah,DMA_CHANNEL_FIELD	;turn off the extra bits.
	out	DMA_16MASK_REG,al	;mask the channel off.
	mov	al,ah
	or	al,CASCADE_MODE		;put it into cascade mode.
	out	DMA_16MODE_REG,al
	mov	al,ah			;turn the channel on.
	out	DMA_16MASK_REG,al
dma_done:

	mov	al, int_no		; Get board's interrupt vector
	add	al, 8
	cmp	al, 8+8			; Is it a slave 8259 interrupt?
	jb	set_int_num		; No.
	add	al, 70h - 8 - 8		; Map it to the real interrupt.
set_int_num:
	xor	ah, ah			; Clear high byte
	mov	int_num, ax		; Set parameter_list int num.

	mov	al,int_no
	call	maskint			;disable these interrupts.

	loadport
	sncport SonicCR
	xor	ax,ax			;take sonic out of reset.
	out	dx,ax
	pause_

	sncport	SonicDCR
	mov	ax,PO1 or USR1 or WC1 or WC0 or BMS or RFT1 or TFT0
	out	dx,ax
	pause_

	sncport	SonicRCR
	mov	ax,BRD			; accept broadcast
	out	dx,ax
	pause_

	sncport	SonicTCR
;;;voodoo programming -- these bits are read-only.
;;;	mov	ax,04eh 			; national's value
	xor	ax,ax			;normal Ethernet.
	out	dx,ax
	pause_

	sncport	SonicIMR
	xor	ax,ax			; disable all, for now.
	out	dx,ax
	pause_

	sncport	SonicISR
	mov	ax,-1			; clear all
	out	dx,ax
	pause_

;
; now we lock down the memory that we'll be using for DMA.  That is,
; assuming we're running under some sort of memory mapper.
;
	mov	ax,40h			;is some program providing VDS?
	mov	es,ax
	test	byte ptr es:[7bh],20h
	jz	memory_locked		;no.

	mov	ax,08102h		;get version information.
	mov	dx,1010b		;no auto-remap, copy data into buffer.
	int	4bh
	cmp	ax,8102h		;did it change into version number?
	je	memory_locked		;no, must not be there...

	push	ax
	mov	dx,offset vds_ver_msg
	mov	ah,9
	int	21h
	pop	ax

	push	ax
	mov	al,ah			;print major version number.
	xor	ah,ah
	xor	dx,dx
	call	decout
	mov	al,'.'
	call	chrout
	pop	ax			;print minor version number.
	xor	ah,ah
	xor	dx,dx
	call	decout
	call	crlf

	mov	vds_active,1

	movseg	es,cs
	mov	di,offset my_dds
	mov	dx,0
	call	malloc
	sub	dx,offset begin_dma
	mov	[di].dds_size.offs,dx
	mov	[di].dds_size.segm,0
	mov	[di].dds_offset.offs,offset begin_dma
	mov	[di].dds_offset.segm,0
	mov	[di].dds_seg,cs
	mov	[di].dds_buffer_id,0
	mov	ax,08103h		;request that the memory be locked.
	mov	dx,1010b		;no auto-remap, copy data into buffer.
	int	4bh

memory_locked:


;
; We need to keep the all the TDAs in the same physical 64K segment.  So, if the
; first crosses a segment, the second cannot, so we'll use it.
;
	mov	di,offset tda1
	movseg	es,cs
	call	segmoffs_to_phys
	add	ax,TRANSMIT_BUF_COUNT * (size tda_struc)
	jnc	no_tda_overflow
	mov	di,offset tda2
no_tda_overflow:
	mov	tdaptr,di		;remember where the tda's are.

	mov	cx,TRANSMIT_BUF_COUNT
	mov	bx,di
init_tdas:
	mov	dx,TRANSMIT_BUF_SIZE
	call	malloc
	mov	di,dx
	mov	[bx].tda_size,0
	mov	[bx].tda_status,0
	mov	[bx].tda_frag_count,1	;packet driver spec only allows one.
	mov	[bx].tda_link,EOL

	call	segmoffs_to_phys	;convert es:di into physical address.
	mov	[bx].tda_frag_ptr.offs,ax	;store the packet's physical address.
	mov	[bx].tda_frag_ptr.segm,dx
	add	bx,(size tda_struc)
	loop	init_tdas

; init transmit regs UTDA

	mov	di,tdaptr
	call	segmoffs_to_phys	; get physical
	push	dx			;save the high word.
	loadport
	sncport	SonicUTDA
	pop	ax			; hi word phys
	out	dx,ax

;
; We need to keep the all the RDAs in the same physical 64K segment.  So, if the
; first crosses a segment, the second cannot, so we'll use it.
;
	mov	si,offset rda1
	mov	ax,si
	call	segmoffs_to_phys
	add	ax,RDA_COUNT * (size rda_struc)
	jnc	no_rda_overflow
	mov	si,offset rda2
no_rda_overflow:
	mov	rdaptr,si		;remember which one we're using
	mov	next_rda,si

	mov	di,rdaptr
	mov	cx,RDA_COUNT
	xor	si,si
init_rda_1:
	push	di
	add	di,(size rda_struc)
	call	segmoffs_to_phys	;get physical offset of next link.
	pop	di

	mov	[di].rda_link,ax	;make a pointer to the next.
	mov	[di].rda_backlink,si	;make a pointer to the previous.
	mov	[di].rda_in_use,0ffffh	;set ownership to SONIC.
	lea	ax,[di]+(size rda_struc)
	mov	[di].rda_forelink,ax	;make a pointer to the next.
	mov	si,di			;remember where we were.
	add	di,(size rda_struc)	;point di to next.
	loop	init_rda_1

	mov	di,rdaptr
	mov	[si].rda_forelink,di	;succ(end) = begin.
	mov	[di].rda_backlink,si	;prev(begin) = end.
	call	segmoffs_to_phys	;get physical offset of first link.

	mov	[si].rda_link,ax
	or	[si].rda_link,EOL	;mark this one as the last.

;set SONIC receive descriptor area pointers.

	push	dx			;save upper word.
	loadport
	sncport	SonicCRDA		;set current
	out	dx,ax
	pause_
	sncport	SonicURDA		;set upper.
	pop	ax			;restore upper word (pushed as dx).
	out	dx,ax

; Init the RRA.  The RRA and CAM share the same upper address bits, so they,
; like all the TDAs and RDAs, must be in the same physical segment.

	mov	si,offset rra1
	mov	ax,si
	call	segmoffs_to_phys	;get the physical address
	add	ax,RRA1SIZE		;fits in one segment?
	jnc	no_rra_overflow		;yes.
	mov	si, offset rra2		;no, the second *must*.
no_rra_overflow:
	mov	rraptr,si		;save the pointer to the right rra.
	add	si,cam1-rra1		;compute the pointer to the CAM.
	mov	camptr,si

	mov	bx,rraptr		;point di to our rra.
	mov	cx,RECEIVE_BUF_COUNT
InitRRALoop:
	mov	dx,RECEIVE_BUF_SIZE
	call	malloc
	mov	di,dx
	call	segmoffs_to_phys	; get physical

	mov	[bx].rra_ptr.offs,ax	;low word address
	mov	[bx].rra_ptr.segm,dx	;high word address
	mov	[bx].rra_cnt.offs,MAX8023LENGTH	;count low word
	mov	[bx].rra_cnt.segm,0	;count high word.
	add	bx,(size rra_struc)
	loop	InitRRALoop

	loadport
	sncport	SonicEOBC
	mov	ax, (MAX8023LENGTH)/2	;count of words.
	out	dx,ax
	pause_

	mov	di,rraptr		;init the pointers.
	call	segmoffs_to_phys

	push	ax			;preserve the low word.
	mov	ax,dx
	loadport
	sncport	SonicURRA
	out	dx,ax			;high word.
	pause_
	pop	ax

	sncport	SonicRSA		;output the low word.
	out	dx,ax

	sncport	SonicRRP
	out	dx,ax

	add	ax,cam1-rra1		;point to the end of the RRA.
	sncport	SonicREA
	out	dx,ax			;set the end pointer.

	setport	SonicRWP
	out	dx,ax			; write reg gets it

; Init SONIC internal counters

	mov	ax,-1			;clear registers (inverted on write)
	sncport	SonicCRCT
	out	dx,ax			;CRC Tally
	sncport	SonicFAET
	out	dx,ax			;FAE Tally
	sncport	SonicMPT
	out	dx,ax			;Missed Packet Tally
;take SONIC out of reset.
	sncport	SonicCR
	xor	ax,ax
	out	dx,ax
	pause_

	mov	ax, RRRA		;Start the RRA.
	out	dx,ax

; get our address out of ROM, and stuff it into the CAM.
	movseg	es,ds
	mov	di,offset our_address
	mov	cx,EADDR_LEN
	call	get_address
	mov	si,offset our_address
	mov	cx,EADDR_LEN
	call	set_address

	loadport
	sncport	SonicCR
	mov	ax,RXEN			;Enable receive.
	out	dx,ax

	sncport	SonicIMR		;Enable interrupts.
	mov	ax,enabled_IMR
	out	dx,ax

	call	set_recv_isr

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
	ret

;TCC's manufacturer prefix is 13:80:00.  They've also used the token
;ring version of the prefix (bit-reversed) , which is 00:01:8c.  Oops.

detect_board:
;test to see if a board is located at io_addr.
;return nz if not.
	loadport
	setport	EBASE
	in	ax,dx
	setport	EBASE+2
	cmp	ax,00h + 01h*256
	jne	detect_board_1
	in	al,dx
	cmp	al,0c8h
	ret
detect_board_1:
	cmp	ax,13h + 80h*256
	jne	detect_board_exit
	in	al,dx
	cmp	al,0
detect_board_exit:
	ret

code	ends

	end
