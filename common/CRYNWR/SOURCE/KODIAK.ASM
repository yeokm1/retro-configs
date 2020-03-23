LED_TEST	equ	0

;Kodiak packet driver code.

buffer_pointer	dw	?		;points to receive buffer.
next_pointer	dw	?		;points to next receive packet.

;
;	a temp buffer for the received header
;
RCV_HDR_SIZE	equ	26		; header @4 + 2 ids @6 + protocol @2+8,
rcv_hdr		db	RCV_HDR_SIZE dup(0)

	public	int_no
int_no		db	3,0,0,0		;must be four bytes long for get_number.
io_addr		dw	300h,0

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK,IEEE8023,0	;null terminated list of classes.
  ifndef KOMBO
driver_type	db	0		;from the packet spec
driver_name	db	"Raven ",10 dup(?)	;name of the driver.
  else
driver_type	db	101		;from the packet spec
driver_name	db	"Kodiak Kombo",10 dup(?)	;name of the driver.
  endif
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

;-> current address
	extrn	my_address: byte

received_ours	db	0

	public	rcv_modes
rcv_modes	dw	7		;number of receive modes in our table.
		dw	0               ;There is no mode zero
		dw	0
		dw	rcv_mode_2
		dw	rcv_mode_3
		dw	0
		dw	rcv_mode_5
		dw	rcv_mode_6

cmd_reg		dw	?		;copy of the I/O port.
config1_reg	dw	?		;copy of the I/O port.
config2_reg	dw	REA_UPDATE_ON or CRC_ERROR_ENABLE or SHORT_FRAME_ENABLE or DRIBBLE_ERROR_ENABLE
  ifdef KOMBO
setup2_reg	db	MODESELECT or COAXDIS
  endif

wait_fifo_empty:
;	Wait for FIFO to be EMPTY. Uses AX,CX,DX
	push	ax
	push	bx
	push	cx
	push	dx
	mov	cx,FIFO_Count		;wait a while for the fifo to get ready
	loadport
	setport	STAT
wait_fifo_empty_1:
	inw				;read status register
	test	ax,FIFO_EMPTY		;check for FIFO EMPTY
	jnz	wait_fifo_empty_2	;jump when empty detected
	loop	wait_fifo_empty_1	;keep polling
;	call	FATAL_ERROR		;never became EMPTY
wait_fifo_empty_2:
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret


	public bad_command_intercept
bad_command_intercept:
;called with ah=command, unknown to the skeleton.
;exit with nc if okay, cy, dh=error if not.
  ifdef KOMBO
	cmp	ah,0e9h
	jne	bad_command_intercept_1
	jmp	autosense
bad_command_intercept_1:
  endif
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


send_pkt_toobig:
	mov	dh,NO_SPACE
	stc
	ret
	public	send_pkt
send_pkt:
;enter with es:di->upcall routine, (0:0) if no upcall is desired.
;  (only if the high-performance bit is set in driver_function)
;enter with ds:si -> packet, cx = packet length.
;if we're a high-performance driver, es:di -> upcall.
;exit with nc if ok, or else cy if error, dh set to error number.
	assume	ds:nothing

  if LED_TEST
	mov	dx,378h
	mov	al,4
	out	dx,al
  endif
	cmp	cx,GIANT		; Is this packet too large?
	ja	send_pkt_toobig

	cmp	cx,RUNT		; minimum length for Ether
	jae	oklen
	mov	cx,RUNT		; make sure size at least RUNT
oklen:
	loadport
	setport	STAT
	mov	ax,1
	call	set_timeout
wait_send:
	inw				;read status register
	test	ax,TX_ON		;is the transmitter still on?
	je	wait_send_done
	call	do_timeout
	jnz	wait_send
	mov	dh,CANT_SEND		;indicate an error.
	stc
	ret
wait_send_done:
	setport	CMD
	mov	ax,cmd_reg
	or	ax,ACK_TX_INT
	outw

	push	cx
	mov	ax,TX_AREA_BEG
	call	set_fifo_write
	pop	cx

;The next packet pointer equals the current packet address plus
;the packet header length plus the packet data length. The
;address must be adjusted for buffer wrap around. Since the
;single transmit packet is always loaded at address zero in
;this version, wrap around can be ignored and the next packet
;pointer equals 0000 + 18 + data length. Data length refers to
;the adjusted packet length.

	loadport
	setport	BWIND
	mov	ax,cx			;restore adjusted length
	add	ax,4			;base address + header length
	xchg	ah,al			;correct byte order
	outw

;The packet header consists of the Header Command and Packet
;Status bytes. The Packet Status byte is filled in by the EDLC,
;and so will be set to zero. The Header Command byte will be
;set to indicate that this packet is a data packet and is the
;last (only) packet in the chain. The XmitSuccessEnable bit in
;the Header Command byte is set so that a successful transmission
;can be identified simply by reading the TXInt bit in the EDLC
;status register. This strategy must be modified when transmit
;packets are chained.

	mov	ax,TX_COMMAND + 0*256	;command, status bytes.
	outw				;write command, then status

;write the contents of the packet.

	call	repouts

; Next Frame header should be NULL.

	xor	ax,ax
	outw
	outw

;Load Transmit Pointer Register.
	setport	TXPTR
	mov	ax,TX_AREA_BEG		;start of transmit buffer
	outw

;initiate the transmission.

	setport	CMD
	mov	ax,cmd_reg
	or	ax, TX_ON			;set bit
	outw					;turn on the transmitter

  if LED_TEST
	mov	dx,378h
	mov	al,2
	out	dx,al
  endif
	ret					; return to caller


	public	set_address
set_address:
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
	assume	ds:nothing
	mov	dh,CANT_SET
	stc
	ret


rcv_mode_2:
	mov	bx,MATCH_ID
	jmp	short set_rcv_mode
rcv_mode_3:
	mov	bx,MATCH_BRDCAST
	jmp	short set_rcv_mode
rcv_mode_5:
	mov	bx,MATCH_MULTICAST
	jmp	short set_rcv_mode
rcv_mode_6:
	mov	bx,MATCH_ALL
set_rcv_mode:
	mov	ax,config1_reg
	and	ax,not 0c000h		;clear the existing bits.
	or	ax,bx
	mov	config1_reg,ax
	loadport
	setport	CONFIG1
	outw
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
	loadport
  ifdef KOMBO
	setport	K2WR
	mov	al,COAXDIS		;PROM mode, no interrupt, COAX turned off.
	out	dx,al
	mov	ax,RESET_BIT or UTPDIS	;reset the board, turn off UTP, enter 8-bit mode.
  else
	mov	ax,RESET_BIT		;reset the board.
  endif

	setport	CONFIG2
	outw

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

	extrn	count_in_err: near
	extrn	count_out_err: near

;this macro writes the given character to the given row and column on
;  an CGA.
to_scrn	macro	r, c, ch
	local	black,done
  if 0
	push	bx
	push	es
	mov	bx,0b800h
	mov	es,bx
	mov	bx,es:[r*160+c*2]
	test	bh,1
	jne	black
	mov	bh,07h
	jmp	short done
black:
	mov	bh,70h
done:
	mov	bl,ch
	mov	es:[r*160+c*2],bx
	pop	es
	pop	bx
  endif
	endm


	public	recv
recv:
;called from the recv isr.  All registers have been saved, and ds=cs.
;Upon exit, the interrupt will be acknowledged.
	assume	ds:code
  if LED_TEST
	mov	dx,378h
	mov	al,1
	out	dx,al
  endif
	to_scrn	23,74,'R'
	loadport
	setport	CMD
	mov	ax,cmd_reg		;get copy of command register
	and	ax,not ENABLE_RX_INT
	mov	cmd_reg,ax		;keep it.
	outw

recv_0:
	loadport
	setport	STAT
	inw				;get status in AX

	test	ax,RX_INT		;did we get a packet?
	jne	recv_1
	jmp	recv_exit
recv_1:
	and	ax,RX_INT		;acknowledge the interrupt.
	outw

	mov	ax,buffer_pointer
	call	set_fifo_read

	loadport
	setport	BWIND			;get the length of the frame.

	mov	cx,RCV_HDR_SIZE		;read the header in.
	mov	ax,cs
	mov	es,ax
	mov	di,offset rcv_hdr
	call	repins

	mov	ah,rcv_hdr[RBUF_SIZE_HI]
	mov	al,rcv_hdr[RBUF_SIZE_LO]
	or	ax,ax			;end of chain?
	jne	recv_this_one		;no.
	to_scrn	23,76,'X'
	jmp	recv_exit		;yes.
recv_this_one:
	mov	next_pointer,ax		;remember where the next one is.

;did we receive our own broadcast?
	mov	di,offset rcv_hdr+RBUF_NHDR+EADDR_LEN
	mov	si,offset my_address
	mov	cx,EADDR_LEN/2
	repe	cmpsw
	je	recv_our_own		;yes, we did.

	mov	ax,next_pointer
	sub	ax,buffer_pointer	;compute the length of the frame
	jae	recv_nowrap
	add	ax,RX_AREA_SIZE		;adjust for wrapping around.
recv_nowrap:
	sub	ax,RBUF_NHDR		;subtract off the header.
	mov	cx,ax

	mov	ah,rcv_hdr[RBUF_STAT]	;get the status of the frame,
	and	ah,RX_DONE or RX_ERROR	;  check for errors.
	cmp	ah,RX_DONE
	je	recv_noerrs

	mov	ah,rcv_hdr[RBUF_STAT]	;get the status of the frame,
	call	report_rx_errs

	call	count_in_err

	to_scrn	23,72,'E'
	jmp	recv_update
recv_our_own:
	to_scrn	23,79,'O'
	inc	received_ours		;remember that we received it.
	jmp	short recv_update

recv_noerrs:
	push	cx

	mov	ax,cs			; Set ds = code
	mov	ds,ax
	mov	es,ax
	assume	ds:code
	mov	di,offset rcv_hdr+RBUF_NHDR+EADDR_LEN+EADDR_LEN

	mov	dl, BLUEBOOK		;assume bluebook Ethernet.
	mov	ax, es:[di]
	xchg	ah, al
	cmp 	ax, 1500
	ja	BlueBookPacket
	inc	di			;set di to 802.2 header
	inc	di
	mov	dl, IEEE8023
BlueBookPacket:

	call	recv_find		; See if type and size are wanted
	pop	cx

	mov	ax,es			; Did recv_find give us a null pointer?
	or	ax,di			; ..
	je	recv_update_discard	; If null, don't copy the data

	push	cx			; We will want the count and pointer
	push	es			;  to hand to client after copying,
	push	di			;  so save them at this point

	push	cx			;move the receive header in.
	mov	si,offset rcv_hdr + RBUF_NHDR
	mov	cx,(RCV_HDR_SIZE - RBUF_NHDR)/2
	rep	movsw			;move rest of packet
	pop	cx

	sub	cx,RCV_HDR_SIZE - RBUF_NHDR ;subtract off what we've already copied.
	loadport
	setport	BWIND
	call	repins			;read the rest of the packet in.

	pop	si			; Recover pointer to destination
	pop	ds			; Tell client it's his source
	pop	cx			; And it's this long
	assume	ds:nothing
	call	recv_copy		; Give it to him
	mov     ax, cs
	mov     ds, ax
	assume  ds: code

	jmp	short recv_update
recv_update_discard:
	to_scrn	23,73,'D'
recv_update:
;Are there more interrupts ?
	loadport
	setport	STAT
	in	ax,dx

; Reenable receiver and interrupts.
	test	ax,RX_ON		;is the receiver still on?
	jnz	DISR_30			;yes, no need to turn it on.

; Receive unit is off.  Reset the receive buffer pointer and continue.
	setport	RXPTR
	inw
	mov	buffer_pointer,ax
;	add	PacketRxOverflowCount,1
DISR_30:

	loadport			;indicate that this packet is snarfed.
	setport	RXAREA
	mov	ax,next_pointer
	mov	buffer_pointer,ax
	mov	al,ah
	out	dx,al

	to_scrn	23,75,'A'
	jmp	recv_0			;go back and get more packets.

recv_exit:
	loadport
	setport	CMD
	mov	ax,cmd_reg		;get copy of command register
	or	ax,ENABLE_RX_INT
	mov	cmd_reg,ax		;keep it.
	outw

	to_scrn	23,74,' '
  if LED_TEST
	mov	dx,378h
	mov	al,2
	out	dx,al
  endif
	ret


report_rx_errs:
	test	ah,8
	je	report_rx_errs_1
	to_scrn	23,71,'s'
report_rx_errs_1:
	test	ah,4
	je	report_rx_errs_2
	to_scrn	23,70,'d'
report_rx_errs_2:
	test	ah,2
	je	report_rx_errs_3
	to_scrn	23,69,'c'
report_rx_errs_3:
	test	ah,1
	je	report_rx_errs_4
	to_scrn	23,68,'o'
report_rx_errs_4:
	ret


set_fifo_read:
	call	set_fifo_write
	loadport

; Set FIFO to read.

	setport	CMD
	mov	ax,cmd_reg		;get copy of command register
	and	ax,not FIFO_WRITE	;put the FIFO into read mode.
	or	ax,FIFO_READ
	mov	cmd_reg,ax		;keep it.
	or	ax,ACK_BUF_INT
	outw

	;
	; Wait for FIFO to be ready.
	;
sfr_30:
	inw
	test	ax,BUF_INT
	jz	sfr_30

	ret


set_fifo_write:
	assume	ds:nothing

	push	ax
	;
	; Read in status.
	;
	loadport
	setport	STAT
	inw

	;
	; Is 8005 set for write ?
	;
	test	ax,FIFO_DIR
	jz	sfw_10

	;
	; No, set FIFO for write.
	;
	setport	CMD
	mov	ax,cmd_reg
	and	ax, not FIFO_READ	;turn FIFO read off
	or	ax, FIFO_WRITE		;turn FIFO write on
	mov	cmd_reg, ax		;save modified command register
	outw

	setport STAT
sfw_00:
	inw
	test	ax,FIFO_DIR
	jnz	sfw_00
sfw_10:
	;
	; Wait for FIFO to be empty.
	;
	test	ax,FIFO_EMPTY
	jnz	sfw_x
	inw
	jmp	sfw_10
sfw_x:

	setport	DMAADR
	pop	ax				;get load address from AX
	outw					;adjust DMA pointer

	ret

	include	timeout.asm

	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret

;any code after this will not be kept after initialization. Buffers
;used by the program, if any, are allocated from the memory between
;end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
end_free_mem	label	byte


	public	usage_msg
usage_msg	db	"usage: kodiak [options] <packet_int_no> <hardware_irq> <io_addr>",CR,LF,'$'

	public	copyright_msg
  ifdef KOMBO
copyright_msg	db	"Packet driver for the Kodiak Kombo, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
  else
copyright_msg	db	"Packet driver for the Kodiak Raven, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
  endif
		db	"Portions Copyright Russell Nelson",CR,LF,'$'

this_board_msg	db	"This board is a Raven ",'$'
bad_prom_msg	db	"Ethernet address PROM is invalid (check I/O address)",'$'
  ifdef KOMBO
memory_bad_msg	db	"Ethernet buffer memory bad",CR,LF,'$'
int_bad_msg	db	"That interrupt number is not supported,",CR,LF
		db	"Try one of 3,4,7,10,11,12 or 15",CR,LF,'$'
testing_mem_msg	db	"Testing memory.",'$'
xcvr_msgs	dw	tp_xcvr_msg,bnc_xcvr_msg,aui_xcvr_msg,no_xcvr_msg
xcvr_ptr	dw	?
tp_xcvr_msg	db	"Using Twisted Pair (10BaseT) transceiver",CR,LF,'$'
bnc_xcvr_msg	db	"Using BNC (10Base2) transceiver",CR,LF,'$'
aui_xcvr_msg	db	"Using AUI transceiver",CR,LF,'$'
no_xcvr_msg	db	"Not connected to any cable",CR,LF,'$'
  endif

int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'

  ifdef KOMBO
prom_contents	db	16 dup(?)
  else
prom_contents	db	32 dup(?)
  endif

; Sometimes a Kodiak-compatible adapter is used in an embedded system,
; and that embedded system doesn't have an Ethernet address PROM.  The
; Ethernet address is included on the packet driver's command line, and
; is stuffed into the device when the boot PROM is programmed.
no_prom		db	0		;<>0 if we don't have a prom.

  ifdef KOMBO
irq_table	db	0
		db	0
		db	0
		db	1 shl 1		;3
		db	2 shl 1		;4
		db	0
		db	0
		db	3 shl 1		;7
		db	0
		db	0
		db	4 shl 1		;10
		db	5 shl 1		;11
		db	6 shl 1		;12
		db	0
		db	0
		db	7 shl 1		;15

  endif
	extrn	set_recv_isr: near

;enter with si -> argument string, di -> wword to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> argument string, di -> wword to print.
	extrn	print_number: near

;-> the Ethernet address of the card.
	extrn	rom_address: byte

;print the character in al.
	extrn	chrout: near

;print a crlf
	extrn	crlf: near

;enter with si -> argument string.
;skip spaces and tabs.  Exit with si -> first non-blank char.
	extrn	skip_blanks: near

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	mov	di,offset int_no
	call	get_number
	mov	di,offset io_addr
	call	get_number
	call	skip_blanks
	cmp	al,CR			;does an Ethernet address follow?
	je	parse_args_1		;no.
	inc	no_prom			;we don't have an Ethernet PROM.
;enter with ds:si -> Ethernet address to parse, es:di -> place to put it.
	movseg	es,ds
	mov	di,offset rom_address
	call	get_eaddr
parse_args_1:
	clc
	ret


board_name_list	dw	board_00, board_01, board_11, board_21
		dw	board_02, board_03, board_unk

board_00	db	01h, "",0,47
board_01	db	02h, "Quad",0,48
board_11	db	03h, "UTP",0,48
board_21        db      04h, "Quad UTP",0,48
board_02	db	05h, "Media Adaptor",0,49
board_03	db	06h, "286 FileServer",0,55
board_unk	db	-1h, "Unknown",0,48	;just a guess.

wait_27ms:
	mov	ax,1			;only have to wait 4us.
	call	set_timeout
wait_27ms_1:
	call	do_timeout
	jne	wait_27ms_1
	ret


	public	etopen
etopen:
;initialize the driver.  Fill in rom_address with the assigned address of
;the board.
;
	cmp	no_prom,0		;do we even *have* a prom??
	je	have_prom
	jmp	adapter_ok		;no, don't even *try* to read it.
have_prom:

	assume	ds:code
	loadport
  ifdef KOMBO
	setport	K2WR			;select PROM mode (should already be selected).
	xor	al,al
	out	dx,al
  else
	setport	CONFIG2
	mov	ax,RESET_BIT
	outw

	call	wait_27ms

	setport	CMD			; set the fifo direction.
	mov	ax,FIFO_WRITE
	outw

	setport	CONFIG1			;select the address prom.
	mov	ax,ADDR_PROM
	outw

	setport	CONFIG2
	mov	ax,config2_reg
	or	ax,WATCH_TIME_DIS	;kill the watchdog
	outw
  endif

	movseg	es,cs
	mov	di,offset prom_contents
  ifdef KOMBO
	setport	0			;on the Kombo, you change all the
	mov	cx,16			;  registers to read the PROM.
  else
	mov	cx,32			;on the Ravens, you read the PROM
	setport	BWIND			;  through the window.
  endif
	xor	bl,bl			;zero checksum
etopen_4:
	in	al, dx			;the prom only has 8 bits...
	add	bl,al			;accumulate the checksum.
	stosb
  ifdef KOMBO
	inc	dx			;go to next register.
  endif
	loop	etopen_4
  ifdef KOMBO
	sub	bl,prom_contents[5]	;the following are not included in the
	sub	bl,prom_contents[6]	;  checksum, contrary to the spec.
	sub	bl,prom_contents[7]
	sub	bl,prom_contents[14]
	sub	bl,prom_contents[15]
  endif

	cmp	bl,0			;must always be zero
	je	etopen_2		;go if it is.
etopen_3:
	mov	dx,offset bad_prom_msg
	stc
	ret
etopen_2:

  ifdef KOMBO

	mov	si,offset prom_contents[8]
	mov	di,offset rom_address	;set the rom address
	repmov	EADDR_LEN

	mov	al,int_no
	mov	bl,al
	and	bx,0fh
	mov	al,irq_table[bx]
	or	al,al
	jne	int_no_ok
	mov	dx,offset int_bad_msg
	stc
	ret
int_no_ok:
	or	setup2_reg,al

	loadport
	setport	K2WR			;select RUN mode, interrupt, and not coax.
	mov	al,setup2_reg
	out	dx,al

	setport	CONFIG2
	mov	ax,RESET_BIT
	outw

	call	wait_27ms

	mov	ax,config2_reg
	or	ax,SELECT_16_BIT	;16-bit driver.
	outw

;set the initial fifo direction, and enable receive interrupts.
	setport	CMD
	mov	ax,FIFO_WRITE
	mov	cmd_reg,ax		;keep a copy.
	outw

	mov	dx,offset testing_mem_msg
	mov	ah,9
	int	21h

adapter_verify:
	mov	al,'.'
	call	chrout
	mov	bx,0aa55h		;aa55
	xor	si,si
	call	test_memory
	jc	adapter_verify_fail

	mov	al,'.'
	call	chrout

	mov	bx,055aah		;55aa
	xor	si,si
	call	test_memory
	jc	adapter_verify_fail

	mov	al,'.'
	call	chrout

	mov	bx,0			;incrementing
	mov	si,1
	call	test_memory
	jc	adapter_verify_fail
	jmp	short adapter_ok

adapter_verify_fail:
	mov	al,setup2_reg		;did we already try compatibility?
	test	al,COMPATIBILITY
	jnz	adapter_verify_bad	;yes, it's bad memory
	or	al,COMPATIBILITY	;no, try compatibility.
	mov	setup2_reg,al

	loadport			;output it,
	setport	K2WR
	out	dx,al
	jmp	adapter_verify		;and try again.

adapter_verify_bad:
	mov	dx,offset memory_bad_msg
	stc
	ret
  else
;ensure that the prom has valid contents.
	cmp	prom_contents,0aah	;first byte must be 0aah.
	jne	etopen_3
	cmp	prom_contents[31],055h	;last byte must be 055h.
	jne	etopen_3

	mov	al,prom_contents[4]	;get the name of this board.
	mov	bx,offset board_name_list
check_board_name:
	mov	si,[bx]			;get a pointer to a string.
	add	bx,2
	cmp	byte ptr [si],-1	;is this the end?
	je	check_board_found
	cmp	al,[si]			;is this the right one?
	jne	check_board_name
check_board_found:
	inc	si			;skip the board revision number.

	mov	dx,offset this_board_msg
	mov	ah,9
	int	21h

	movseg	es,ds			;copy the driver name to where we need it.
	mov	di,offset driver_name+6	;skip the "Raven " part...
check_board_copy:
	lodsb
	stosb
	or	al,al
	je	check_board_done_print
	call	chrout			;print the character.
	jmp	check_board_copy
check_board_done_print:
	lodsb				;copy the driver type number over
	mov	driver_type,al

	mov	rom_address[0],000h	;Put in Kodiak's high three bytes.
	mov	rom_address[1],080h
	mov	rom_address[2],01bh
	mov	ax,word ptr prom_contents[1] ;copy over the low three bytes.
	mov	word ptr rom_address[3],ax
	mov	al,prom_contents[3]
	mov	rom_address[5],al
  endif

adapter_ok:
	call	crlf

;reset again.
	loadport
	setport	CONFIG2
	mov	ax,RESET_BIT
	outw

	call	wait_27ms

;set the packet we will accept.
	mov	ax,config2_reg
  ifdef KOMBO
	or	ax,SELECT_16_BIT	;16-bit driver.
	or	ax,UTPDIS		;turn off UTP driver.
	mov	config2_reg,ax
  endif
	outw

;re-initialize the command register.
	setport	CMD
  ifdef KOMBO
	mov	ax,cmd_reg
  else
	mov	ax,FIFO_WRITE or ENABLE_RX_INT ;start fifo in write, enable ints
	mov	cmd_reg,ax		;keep a copy.
  endif
	outw

;Copy the station address from the table to station number zero.
;We only use station number zero.
	setport	CONFIG1
	xor	al, al			;select station number zero
	out	dx, al

	setport	BWIND
	mov	si,offset rom_address	;The address we just got from the rom.
	mov	cx,EADDR_LEN
set_address_1:
	lodsb				;Station address requires byte writes.
	out	dx,al
	loop	set_address_1

;Set the Transmit End Area register.
	setport	CONFIG1
	mov	al,TEA_REG		;select transmit end area reg
	out	dx,al
	setport	BWIND			;point to the window.
	mov	al,TX_AREA_END shr 8	;start of receive buffer
	out	dx,al

;select station zero address (only), match our address and broadcasts,
;and select buffer memory at the BWIND port.
	setport	CONFIG1
	mov	ax,MATCH_BRDCAST or ID_0_ENABLE or BUFFER_MEMORY
	outw
	mov	config1_reg,ax		;keep a copy.

;Load Receive End Area Register.
	setport	RXAREA
	mov	al,RX_AREA_END shr 8		;REA pointer
	out	dx,al			;only output the low 7 bits.

;Load Receive Pointer Register.
	setport	RXPTR
	mov	ax,RX_AREA_BEG		;start of receive buffer
	outw
	mov	buffer_pointer,ax	;init packet buffer pointer

;Turn receiver on.
	setport	CMD
	mov	ax,cmd_reg
  ifdef KOMBO
	or	ax,RX_ON or ENABLE_RX_INT
  else
	or	ax,RX_ON		;set bit
  endif
	mov	cmd_reg,ax		;remember it.
	outw

	mov	al, int_no		; Get board's interrupt vector
	add	al, 8
	cmp	al, 8+8			; Is it a slave 8259 interrupt?
	jb	set_int_num		; No.
	add	al, 70h - 8 - 8		; Map it to the real interrupt.
set_int_num:
	xor	ah, ah			; Clear high byte
	mov	int_num, ax		; Set parameter_list int num.

  ifdef KOMBO
	movseg	es,ds
	mov	si,offset rom_address
	mov	di,offset my_address
	repmov	EADDR_LEN

	call	autosense_1
	and	bl,3
	xor	bh,bh
	shl	bx,1
	mov	dx,xcvr_msgs[bx]
	mov	xcvr_ptr,dx

  endif
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
  ifdef KOMBO
	mov	dx,xcvr_ptr
	mov	ah,9
	int	21h
  endif
	ret

test_memory:
;enter with bx = pattern to write, si = increment for pattern.

;set TEA to the end of memory.
	loadport
	setport	CONFIG1
	mov	al,TEA_REG		;select transmit end area reg
	out	dx,al
	setport	BWIND
	mov	al,0ffh			;start of receive buffer
	out	dx,al

;write our pattern.
	xor	ax, ax			;start at zero.
	call	set_fifo_write
	loadport
	setport	CONFIG1			;select the buffer memory.
	mov	ax,BUFFER_MEMORY
	outw

	setport	BWIND
	mov	ax,bx			;get the pattern word
	mov	cx,8000h		;number of words to write
test_memory_write:
	outw				;write our pattern.
	add	ax,si			;increment the pattern.
	loop	test_memory_write

	xor	ax,ax			;start at zero again.
	call	set_fifo_read
	loadport
	setport	CONFIG1
	mov	ax,BUFFER_MEMORY	;select buffer memory
	outw				; execute command
	setport	BWIND
	mov	cx,8000h		;number of words to read

test_memory_read:
	inw
	cmp	ax,bx			;does it compare correctly?
	jne	test_memory_fail	;no, quit.
	add	bx,si			;increment the pattern.
	loop	test_memory_read	; Otherwise, continue
	clc
	ret

test_memory_fail:
	stc
	ret

	extrn	get_hex: near
	include	getea.asm

