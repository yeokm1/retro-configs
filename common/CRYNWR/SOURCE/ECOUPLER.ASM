;   Copyright (C) 1993, RF Nets, Cupertino, CA 
;   All Rights Reserved
;   Author:kevinr@Solaris.com
;
;   ecoupler -
;   TSR compatible with the FTP Software, inc packet driver interface
;   specification for any card using the Fujitsu MB86965 EtherCoupler.
;
version	equ	1

;   $Id: ecoupler.s%v 1.3 1993/02/10 06:30:26 N6RCE Rel $
;
	.286
	
	include	defs.asm
	include f965.inc		;Fujitsu 86965 definitions

code	segment	word public
	assume	cs:code, ds:code

	public	int_no
int_no	db	0,0,0,0			;must be four bytes long for get_number.
io_addr	dw	-1,-1			;selected I/O base address

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
				;supported classes from pkt drv spec
driver_class	db	BLUEBOOK,IEEE8023,0  
driver_type	db	DR_TYPE		;per the spec.
driver_name	db	DR_NAME,0	;name of the driver.
driver_function	db	2		;basic and extended only
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

	public  rcv_modes
rcv_modes	dw	7		;number of receive modes in our table.
		dw	0               ;There is no mode zero
		dw	rcv_mode_1
		dw	0
		dw	rcv_mode_3
		dw	rcv_mode_4
		dw	rcv_mode_5
		dw	rcv_mode_6

WEC_reg	Macro	reg,val		;write to an ethercoupler register
	Mov	DX,io_addr
	Add	DX,reg
  IFNB <val>
	Mov	AL,val
  ENDIF
	Out	DX,AL
	endm

REC_reg	Macro	reg		;read a designated ethercoupler register
				;result into AL
	Mov	DX,io_addr
	Add	DX,reg
	In	AL,DX
	endm

;
;-------------------------------------------------------------------------
;   Misc. data variables needed by driver
;-------------------------------------------------------------------------
;

mcast_list_bits db      0,0,0,0,0,0,0,0 ;Bit mask from last set_multicast_list
mcast_none	db	8 dup(0)
mcast_all	db	8 dup(0ffh)

;------------------------------------------------------------------
; keep the following together
recv_pkt_hdr Equ pkt_status	;
pkt_status Db	0		;etherCoupler status byte
pkt_rsvd1  Db	0		;reserved byte
pkt_count  Dw	0		;actual bytes received
pkt_dst_MAC Db	EADDR_LEN dup(0)	;destination MAC addr
pkt_src_MAC Db	EADDR_LEN dup(0)	;source MAC addr
pkt_type   Db	MAX_P_LEN dup(?) ;ethernet type field -or- 802.3 length field
; keep the above together
;------------------------------------------------------------------

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
	ret

	public	send_pkt
send_pkt:
;enter with es:di->upcall routine, (0:0) if no upcall is desired.
;  (only if the high-performance bit is set in driver_function)
;enter with ds:si -> packet, cx = packet length.
;if we're a high-performance driver, es:di -> upcall.
;exit with nc if ok, or else cy if error, dh set to error number.
	assume	ds:nothing
	cmp	cx,RUNT		; minimum length for Ether
	jae	oklen
	mov	cx,RUNT		; make sure size at least RUNT
oklen:
	Mov	AX,CX
	Mov	DX,io_addr
	Add	DX,BMPR8		;output buffer reg addr
	Out	DX,AX			;write count into xmit buffer reg
	inc	cx			;round up.
	shr	CX,1			;bytes to words
	rep OutSW			;copy pkt buffer to EC xmit buffer

	mov	ax,18
	call	set_timeout
send_buffer_1:
	REC_reg	DLCR0			;get the transmit status
	test	al,TX_DONE		;is it done?
	jne	send_buffer_2		;yes.
	call	do_timeout
	jne	send_buffer_1
;send the packet anyway -- we *can't* be waiting to send a packet *this* long.
send_buffer_2:

	WEC_reg	DLCR0,TX_DONE		;clear TX status
	mov	Al,TX_START + 1		;start command + packet_count
	WEC_reg	BMPR10			;and we're off
	Clc
	ret

	public	set_address
set_address:
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
;
;   NOTE: this routine alters (and restores on exit) the 
;   DLCR8-15 register set.  It also disables DLC then enables it on exit.
;
;-----------------------------------------------------------------
	assume	ds:code

	cmp	cx,6			;chk for correct length
	je	sa_01			;if okay, jmp to continue
	mov	dl,BAD_ADDRESS
	stc
	ret
sa_01:					;come here to continue with setting new MAC address
	mov	bl,RBS_DLCRH
	call	set_reg_block
	mov	cx,6			;restore length
	clc
	ret

	assume	ds:code
rcv_mode_1:
	mov	al,0			;disable the receiver and transmitter.
	jmp	initialize_nomulti
rcv_mode_6:
	mov	al,3			;promiscuous mode
	jmp	short initialize_nomulti
rcv_mode_3:
	mov	si,offset mcast_none	;don't accept any multicast frames.
	jmp	short initialize_multi
rcv_mode_4:
	mov	si,offset mcast_list_bits	;accept our multicast frames.
	jmp	short initialize_multi
rcv_mode_5:
	mov	si,offset mcast_all	;accept any multicast frames.
initialize_multi:
	call	set_hw_multi
	mov	al,AF1			; receive mine, broads, and multis.
initialize_nomulti:
	WEC_reg	DLCR5			;set the address match list.
	ret


set_hw_multi:
	mov	bl,RBS_HT
	mov	cx,8
;
;
set_reg_block:
;enter with si -> block of register values to set, bl = register set selection,
;  cx = count of registers to set (up to 8).
	loadport
	setport	DLCR6			;get register contents
	in	al,dx
	mov	ah,al			;save a copy.
	or	al,DLC_EN		;set DLC high (disable)
	out	dx,al			;disable EtherCoupler

	setport	DLCR7			;get config register 1
	in	al,dx
	push	ax			;save 6 and 7.

	and	al,not RBS		;clear current register setting
	or	al,bl			;include the one they want to select.
	out	dx,al

	setport	DLCR8
srb_01:
	lodsb
	out	dx,al			;output to Node ID register
	inc	dx
	loop	srb_01

	loadport
	setport	DLCR7			;restore config reg 1
	pop	ax
	out	dx,al

	setport	DLCR6			;restore it.
	mov	al,ah
	out	dx,al
	ret


	public	terminate
terminate:

;time to get out of Dodge
; maks interrupts from the hardware, and disable DLC
	WEC_reg	DLCR6,DLC_EN
	WEC_reg	DLCR2,0		;disable all Tx src's of inteerupts
	WEC_reg	DLCR3,0		;ditto for Rx

	Mov	DX,io_addr
	Add	DX,24		;IDRB0
	Out	DX,AL		;claims to reset the EC device

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

	extrn	count_in_err: near
	extrn	count_out_err: near

	public	recv
recv:
;called from the recv isr.  All registers have been saved, and ds=cs.
;a specific EOI has already been issued to the 8259. The IRQ line in the
;8259 is also masked.

	assume	ds:code

;technique:  read the status register, and write that back to register,
; thereby clearing it.
;Then, check for RX Buffer Overflow, if so, increment a counter.
;Next, loop on RX BUF not empty (DLCR5).
;
	REC_reg	DLCR1		;Rx Status register
	WEC_reg	DLCR1		;reset for next occurrance
		;we shouldn't ever loose an interrupt 'cause:
		;the PIC is already cleared, it's edge triggered
		;and we've now armed the EC to hit us again, after the
		;processor interrupt mask is turned off.
	Test	AL,RX_BUF_OVFL	;RX Buffer overflow?
	Jz	rcv_buf_chk	;jump if not buffer overflow
	Call	count_in_err
		;we don't test for pkt arrive interrupt, we'll figure it
		;out from the RX buffer empty status bit in DLCR5
		
rcv_buf_chk:		;check for packets in buffer
	REC_reg	DLCR5			;recv mode register
	Test	AX,RX_BUF_EMPTY		;any more pkts in buffer?
	Jz	rcv_not_empty			;jmp if so (RX_BUF_EMPTY off)
; no pkts in buffer..all done
;***	Jmp	rcv_empty			;
	
rcv_empty:		;come here after pkt buffer goes empty.

	Ret				;back to main ISR
	
	
rcv_not_empty:
		;We'll read 9 words from the EC.  The first two
		;contain the recv status and the count, the next
		;fourteen bytes contain the ethernet header.
		;we're interested in the type field in bytes at
		;offset 12 and 13.
	Mov	DX,io_addr
	Add	DX,BMPR8
	Mov	CX,(4+EADDR_LEN+EADDR_LEN+MAX_P_LEN)/2	;status, count, E hdr, all in words
	Push	DS
	Pop	ES
	Mov	DI,offset recv_pkt_hdr	;where to load
	rep Insw
	Cmp	pkt_status,20h		;good status
	Je	rcv_good_pkt 		;jump if good recv status
;  bad recv status...skip the packet, increment some counter

	jmp	rcv_skip_pkt		;go to dump packet routine
rcv_good_pkt:
;come here when good packet recv'ed
;prep and call recv_find to see if handler owner wants
;the blasted thing!
;DL = type (BLUEBOOK or IEEE8023)
;CX = length including MAC header
;ES:DI = ethernet type field
	mov	cx,pkt_count
	mov	di,offset pkt_type
	mov	dl, BLUEBOOK		;assume bluebook Ethernet.
	mov	ax, es:[di]
	xchg	ah, al
	cmp 	ax, 1500
	ja	BlueBookPacket
	inc	di			;set di to 802.2 header
	inc	di
	mov	dl, IEEE8023
BlueBookPacket:

	call	recv_find		;ES:DI points to buffer on rtn
					;or 0:0 if don't want packet
	mov	ax,es
	or	ax,di			;check for any bits on
	je	rcv_skip_pkt		;jump if don't want the packet

	push	es
	push	di

	mov	cx,(EADDR_LEN+EADDR_LEN+MAX_P_LEN)/2 ;header length (in words)
	mov	si,offset pkt_dst_mac
	rep	movsw
	mov	dx,io_addr
	add	dx,BMPR8
	mov	cx,pkt_count		;orig pkt length
	sub	cx,(EADDR_LEN+EADDR_LEN+MAX_P_LEN) ;hdr already taken
	shr	cx,1			;make it into words
	rep	insw			;copy remainder of pkt to callers buf
	jnc	rcv_not_odd_cnt
	in	ax,dx			;allow for odd length packets
	stosb
rcv_not_odd_cnt:

; notify handle owner the copy is finished
	pop	si
	pop	ds
	assume	ds:nothing
	mov	cx,pkt_count
	Call	recv_copy		;let caller know data loaded into his
					;buffer. 
					;DS:SI->his buffer
					;CX = packet length
	Push	CS
	Pop	DS			;data back to our segment
	assume	DS:code

	Jmp	rcv_buf_chk		;go check for more pkts in buffer
	
rcv_skip_pkt:		;come here to skip a packet
			;** need to increment some counter **
	REC_reg	BMPR14			;get skip pkt reg contents
	Or	AL,SKIP_PKT		;tell EC to skip this packet
	WEC_reg	BMPR14			;do it. Note: chip spec says
					;this could take up to 300ns
					;to complete.
	Jmp	rcv_buf_chk		;go check for more pkts in buffer

	public	recv_exiting
recv_exiting:
;called from the recv isr after interrupts have been acknowledged.
;Only ds and ax have been saved.
	assume	ds:nothing
	ret

	include	timeout.asm
	include	multicrc.asm

	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret

;any code after this will not be kept.  Buffers used by the program, if any,
;are allocated from the memory between end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
end_free_mem	label	byte


int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'

bmpr13_val	db	0

	extrn	set_recv_isr: near

;enter with si -> argument string, di -> wword to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> argument string, di -> wword to print.
	extrn	print_number: near

;-> the assigned Ethernet address of the card.
	extrn	rom_address: byte

;----------------------------------------------------------------------
;   initialize ethercoupler and prepare driver for operation
;----------------------------------------------------------------------
	public	etopen
etopen:
	call	get_board_parameters

	WEC_reg	DLCR6,DLC_EN	;disable data link ctrler prior to init
; DLC shut off, we can now safely init all reg values.
; DLCR6 is also config reg 0, so don't need to reload it
	Or	AL,SRAM_CYCLE_CLK + BUFFER_BUSW
			; 100NS SRAM cycle, 8 bit system bus width, 8 bit
			; buffer bus width
	Or	AL,TBS_2_2	;2 2K Tx Buffer
	Or	AL,BS_32	;total buffer size of 32K bytes
	Out	DX,AL

	WEC_reg	DLCR0,TX_DONE+TX_PKT_RCD+JABBER+COL+COL16
		;clear Tx status'es and the associated interrupts
	WEC_reg	DLCR1,0ffh	;rcv status reg - clear all condx
	WEC_reg	DLCR2,0		;disable all Tx src's of interrupts
	WEC_reg	DLCR3,RX_PKT_IE+RX_BUF_OVFL
	WEC_reg	DLCR4,LBC	;not loopback, Tx defer to carrier sense
				;no aloha here!
	WEC_reg	DLCR5,0		;receive mode 1, for now.
	WEC_reg	DLCR7,PWRON+RDYPNSEL+RBS_BMPR
	WEC_reg	BMPR11,0	;clear collison controls
	WEC_reg	BMPR12,0	;clear DMA enables
	mov	al,bmpr13_val
	WEC_reg	BMPR13
	WEC_reg	BMPR14,FILTER_SELF_RX
;
; registers are all set, now setup the station MAC address
;
	mov	di,io_addr
	mov	si,offset rom_address
	call	read_mac_addr

	mov	si,offset rom_address
	mov	cx,EADDR_LEN
	call	set_address		;turns on the DLC

	Call	set_recv_isr	;hook ourselves in

	REC_reg	DLCR6			;get register contents
	and	al,not DLC_EN		;set DLC low (Enable)
	WEC_reg	DLCR6			;enable EtherCoupler

;if all is okay,
	mov	dx,offset end_resident
	clc
	ret
;if we got an error,
EC_problem:
noEC:
	stc
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

