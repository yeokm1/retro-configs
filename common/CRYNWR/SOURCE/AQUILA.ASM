version	equ	0
;History:303,1

	page	55,120
	TITLE	Aquila Ethernet PC/TCP Packet Driver
;**********************************************************************
;
;	Aquila Communications, Inc. AQ-PCE 1xx PC/TCP Packet Driver
;	Copyright (c) Aquila Communications, Inc. 1989
;	All Rights Reserved
;
;	Author: Barry I. Kelman
;
;	Revision History:
;
;		11/7/89  bik	Adapted from Novell Shell Driver
;               11/30/89  bik   V1.0 Release
;
;*********************************************************************


	include	defs.asm

; I/O ports

EthRSel		equ	0
EthRSelOdd	equ	1
EthDSel		equ	8
EthDSelOdd	equ	9
EthCtlReg	equ	0eh

;these registers are accessible only through EthRsel and EthRSelOdd
DLCR_XMIT_STAT	equ	0
DLCR_XMIT_MASK	equ	1
DLCR_RECV_STAT	equ	2
DLCR_RECV_MASK	equ	3
DLCR_XMIT_MODE	equ	4
DLCR_RECV_MODE	equ	5
DLCR_ENABLE  	equ	6
DLCR_TDR_LOW	equ	7
DLCR_NODE_ID	equ	8		;(EthCtlBMP must be reset)
DLCR_TDR_HIGH	equ	0fh

;these registers are accessible only through EthDSel and EthDSelOdd
;that fact is indicated by the high bit being set.  The setreg macro
;takes care of selecting EthDSel and EthDSelOdd as needed.
BMPR_MEM_PORT	equ	8000h		;We never use this.
BMPR_PKT_LEN_LO	equ	8002h		;(EthCtlBMP must be set)
BMPR_PKT_LEN_HI	equ	8003h		;(EthCtlBMP must be set)
BMPR_DMA_ENABLE	equ	8004h		;(EthCtlBMP must be set)

;DLCR_XMIT_STAT bits:
EthTxBusWrErr	equ	00000001b
EthTx16Col	equ	00000010b
EthTxCol	equ	00000100b
EthTxUndrFlow	equ	00001000b
EthTxShort	equ	00010000b
EthTxXmitRcvd	equ	00100000b
EthTxNetBsy	equ	01000000b
EthTxOk		equ	10000000b
TxInterruptMask	equ	EthTxBusWrErr or EthTx16Col or EthTxUndrFlow

;DLCR_RECV_STAT bits:
EthRxOvrFlow	equ	00000001b
EthRxCRCErr	equ	00000010b
EthRxAlignErr	equ	00000100b
EthRxShort	equ	00001000b
EthRxRmtRst	equ	00010000b
EthRxBusRdErr	equ	01000000b
EthRxRdy	equ	10000000b
EthRxErrors     equ     01000111b
RxInterruptMask		equ	EthRxRdy or EthRxErrors

;DLCR_XMIT_MODE bits:
EthDisCar	equ	00000001b
EthLoopN	equ	00000010b
EthTestMode	equ	00000100b
EthChipTest	equ	00001000b

;DLCR_RECV_MODE bits:
EthAcceptNone	equ	00000000b
EthAcceptMult3	equ	00000001b
EthAcceptNorm	equ	00000010b
EthAcceptAll	equ	00000011b
EthEnaRemRst	equ	00000100b
EthEnaShort	equ	00001000b
EthAdrSize	equ	00010000b
EthBufFull	equ	00100000b
EthBufEmpty	equ	01000000b
EthTest		equ	10000000b

;BMPR_DMA_ENABLE bits:
EthDMAWrt       equ     00000001b
EthDMARd	equ     00000010b
EthDMADis       equ     00000000b

;DLCR_ENABLE bits:
DLCR_ENABLEN	equ	10000000b	;true if disabled.

;BMPR_PKT_LEN_LO bit:
EthXmitStart	equ	08000h

;EthCtlReg bits:
EthCtlReset	equ	00000000b
EthCtlBProm	equ	00000000b	;Boot Rom enabled, controller reset
EthCtlBPNoRes	equ	10000000b	;Boot Rom enabled.
EthCtlBMP	equ	10000001b	;Buffer Memory Pointer enabled.
EthCtlIDProm	equ	00000010b	;ID PROM enabled.
EthCtlHBDis	equ	00000100b	;High byte disabled (116 only).

setreg	macro	reg, map
	setport	EthCtlReg
	mov     al, (reg and 7fffh)*8 or EthCtlBMP
	out     dx, al			;switch to length high byte reg
  if     (reg and 8001h) eq 0000h
	setport	EthRSel
  elseif (reg and 8001h) eq 0001h
	setport	EthRSelOdd
  elseif (reg and 8001h) eq 8000h
	setport	EthDSel
  else	;(reg and 8001h) eq 8001h
	setport	EthDSelOdd
  endif
	endm


code	segment	word public
	assume	cs:code, ds:code

	public	int_no
int_no		db	3,0,0,0		;must be four bytes long for get_number.
io_addr		dw	0360h,0		; I/O address for card (jumpers)
base_addr	dw  	0d000h,0	; base segment for board (jumper set)

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0;from the packet spec
driver_type	db	52		;from the packet spec
driver_name	db	'Aquila',0	;name of the driver.
driver_function	db	2
parameter_list	label	byte
	db	1			;major rev of packet driver
	db	9			;minor rev of packet driver
	db	14			;length of parameter list
	db	EADDR_LEN		;length of MAC-layer address
	dw	GIANT			;MTU, including MAC headers
	dw	MAX_MULTICAST * EADDR_LEN;buffer size of multicast addrs
	dw	0			;(# of back-to-back MTU rcvs) - 1
	dw	0			;(# of successive xmits) - 1
int_num	dw	0			;Interrupt # to hook for post-EOI
					;processing, 0 == none,

	public  rcv_modes
rcv_modes	dw	7		;number of receive modes in our table.
		dw	0               ;There is no mode zero
		dw	rcv_mode_1
		dw	0
		dw	rcv_mode_3
		dw	0		;haven't set up perfect filtering yet.
		dw	0
		dw	rcv_mode_6

	even

RemainPacketLength	dw	?	;remaining after we read the header.

TxInProgress		db	0

;-> the assigned address of the card.
	extrn	rom_address: byte

;-> the current address of the card.
	extrn	my_address: byte

NodeAddress	     db      6 dup(0)

	even
bxSave	  dw      0

EthHeaderStructure	struc
	PH_DAdr		db	6 dup (?)
	PH_SAdr		db	6 dup (?)
	PH_length	dw	?,?,?,?	; max possible packet type.
EthHeaderStructure	ends

	even
EthHeaderBuf	EthHeaderStructure <>

even

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
;enter with es:di->upcall routine, (0:0) if no upcall is desired.
;  (only if the high-performance bit is set in driver_function)
;enter with ds:si -> packet, cx = packet length.
;if we're a high-performance driver, es:di -> upcall.
;exit with nc if ok, or else cy if error, dh set to error number.
	assume	ds:nothing

	cmp     cx, GIANT
	ja	send_pkt_toobig
	cmp     TxInProgress, 0
	je      TxNoErrs
	mov	ax,18
	call	set_timeout
TxLoop:
	loadport
	setreg	DLCR_XMIT_STAT
	in	al, dx			;get xmit stat
	out	dx, al			;clear error bits
;Check for transmitter available
	test	al, EthTxOk
	jne	TxLoopEnd
	call	do_timeout		;don't wait forever.
	jne	TxLoop
	mov	dh,CANT_SEND		;give up with an error.
	stc
	ret
TxLoopEnd:

	mov     TxInProgress, 0
	test	al, EthTxBusWrErr OR EthTx16Col OR EthTxUndrFlow
	jz      TxNoErrs
	call	count_out_err
TxNoErrs:
	mov     es, base_addr
	xor     di, di
	push	cx
	call	movemem
	pop	cx
	cmp	cx,RUNT
	ja	TxLenOk
	mov	cx,RUNT
TxLenOk:
	or	cx, EthXmitStart	;or in start bit
	loadport
	setport	EthCtlReg
	mov     al, (BMPR_PKT_LEN_LO and 7fffh)*8 or EthCtlHBDis or EthCtlBMP
	out     dx, al			;switch to length low byte reg
	setport	EthDSel
	mov     al, cl			;send low byte
	out	dx, al			;start backup going
	setreg	BMPR_PKT_LEN_HI
	mov     al, ch			;send high byte
	out	dx, al			;start backup going
	mov	TxInProgress, -1	;set xmit in progress
	clc
HandleTxInterrupt:
	ret
send_pkt_toobig:
	mov	dh,NO_SPACE
	stc
	ret


	public	set_address
set_address:
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
	mov	dh,CANT_SET
	stc
	ret

;for some reason, the following routine doesn't work after the driver is setup,
;but it works at initialization time.  So, we arrange things so that it's only
;called when it works.  Oh well.
set_address_0:
	assume	ds:nothing
	loadport
	setport	EthCtlReg
	mov     al, DLCR_ENABLE*8 or EthCtlIDProm
	out     dx, al			;set control reg to access ID Prom
					; leave HW Reset on
	setport	EthRSel			;disable controller while setting node
	in	al,dx
	push	ax			;remember whether it was disabled.

	mov	al, DLCR_ENABLEN
	out	dx, al

	mov     bx, DLCR_NODE_ID*8
	mov	cx, EADDR_LEN
set_node_addr_1:
	loadport
	setport	EthCtlReg		;get node port offset
	mov	al,bl
	or	al,EthCtlIDProm
	out     dx, al			;set up control reg
	setport	EthRSel			;assume an even port number.
	test    bx, 1*8			;is the port number odd?
	jz      set_node_addr_2
	setport	EthRSelOdd
set_node_addr_2:
	lodsb				;loop to move node in
	out	dx, al
	add	bx, 1*8			;advance to the next DLCR.
	loop	set_node_addr_1

	loadport
	setport	EthCtlReg
	mov     al, DLCR_ENABLE*8
	or	al,EthCtlIDProm
	out     dx, al			;set control reg to access ID Prom
					; leave HW Reset on
	setport	EthRSel			;restore original conditions...
	pop	ax
	out	dx,al

	clc
	ret


rcv_mode_1:
	mov	bl,EthAcceptNone	; don't receive any packets
	jmp	short	rcv_mode_set

rcv_mode_3:
	mov	bl,EthAcceptNorm	; receive mine, broads, and multis.
	jmp	short	rcv_mode_set

rcv_mode_6:
	mov	bl,EthAcceptAll		; receive all packets.
rcv_mode_set:
	loadport
	setreg	DLCR_RECV_MODE
	mov	al,bl
	out	dx,al
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

	public	recv
recv:
;called from the recv isr.  All registers have been saved, and ds=cs.
;Upon exit, the interrupt will be acknowledged.
	assume	ds:code
	loadport
	setreg	DLCR_RECV_STAT
	in	al, dx			;get recv stat
	and     al, RxInterruptMask
	out	dx, al			;clear error bits

	setreg	DLCR_RECV_MASK
	xor	ax, ax
	out	dx, al			;mask recv ints

;
;	HANDLE THE RECEIVE INTERRUPTS
;

CheckForReceiveInterrupt:
	loadport
	setreg	DLCR_RECV_MODE
	in	al, dx
	test	al, EthBufEmpty		;Is the buffer empty?
	jz      GotRecvPacket		;no, go read the packet in.
	jmp	ExitDriverISR

RxErrIgnore:
	call	count_in_err
	jmp	RxIgnore

;
;	Got a Receive Packet - Read in Control Byte & Length
;
GotRecvPacket:
	setreg	DLCR_RECV_STAT
	mov	al, EthRxRdy
	out     dx, al			;clear rx rdy bit
	setport	EthCtlReg
	mov     al, EthCtlBMP
	out     dx, al			;zero address to chip
	mov	ds, base_addr		;buffer segment in DS
	assume  ds: nothing
	mov	ax, ds:[0]		;get control byte
	mov	cx, ds:[0]		;get length
	test 	al, EthRxErrors
	jnz	RxErrIgnore		;check for errors
	cmp	cx, size EthHeaderStructure
	jb	RxErrIgnore		;packet too short
	cmp	cx, GIANT
	ja	RxErrIgnore		;or too long

	sub	cx, size EthHeaderStructure
	mov	RemainPacketLength, cx	;remember how much more we have to read.

	xor	si, si			;doesn't *really* matter where we start.
	mov 	bx, cs
	mov	es, bx
	mov	di, offset EthHeaderBuf
	assume	es:code
	mov	cx, size EthHeaderStructure/2
	rep	movsw			;move header into work buffer
	mov	ds,bx
	assume  ds:code

	mov	di,offset EthHeaderBuf.PH_SAdr
	mov	si,offset my_address
	mov	cx,EADDR_LEN/2
	repe	cmpsw			;make sure it's not from us
	jz	RxNotOursIgnore		;ignore our own broadcasts.

	mov	di,offset EthHeaderBuf.PH_length

	mov	cx,RemainPacketLength	;get the length of the packet back.
	add	cx, size EthHeaderStructure

	mov	dl, BLUEBOOK		;assume bluebook Ethernet.
	mov	ax, es:[di]
	xchg	ah, al
	cmp 	ax, 1500
	ja	BlueBookPacket
	inc	di			;set di to 802.2 header
	inc	di
	mov	dl, IEEE8023
BlueBookPacket:
	call	recv_find		;look up our type.
	assume	es:nothing

	mov     ax, es
	or      ax, di
	jnz	GotCompletePacketECB	;got one - go fill it up

RxNotOursIgnore:
	call	count_in_err		;none available - inc error count
	mov	cx, RemainPacketLength
RxIgnore:
	mov	ds, base_addr
	assume	ds:nothing
	xor	si, si
	shr     cx, 1
	rep	lodsw
	jnc     RxIgnReload
	lodsb
RxIgnReload:
	movseg	ds,cs
	jmp	CheckForReceiveInterrupt;go check for more.

GotCompletePacketECB:
	assume	ds:code

	push	es			;remember where the packet is going.
	push	di

	mov     si, offset EthHeaderBuf
	mov     cx, size EthHeaderStructure/2
	rep	movsw			;move header to FTP Buf

	mov	cx, RemainPacketLength
	mov     ds, base_addr
	assume	ds:nothing
	xor     si, si
	shr     cx, 1
	rep	movsw			;move rest of packet
	jnc     IncTotRx
	movsb
IncTotRx:
	pop	si
	pop	ds
	assume	ds:nothing

	mov	cx,RemainPacketLength	;get the length of the packet back.
	add	cx, size EthHeaderStructure

	call	recv_copy
	mov     ax, cs
	mov     ds, ax
	assume  ds: code
	jmp	CheckForReceiveInterrupt

ExitDriverISR:
	assume  ds: code
	loadport
	setreg	DLCR_XMIT_MASK
	mov	al, TxInterruptMask
	out	dx, al			;restore it
	setreg	DLCR_RECV_MASK
	mov	al, RxInterruptMask
	out	dx, al			;restore it
	setport	EthCtlReg
	mov     al, EthCtlBMP
	out     dx, al

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

	extrn	set_recv_isr: near
	extrn	maskint: near

;enter with si -> argument string, di -> word to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> name of word, di -> dword to print.
	extrn	print_number: near

	public	usage_msg
usage_msg	db	"usage: aquila [options] <packet_int_no> <hardware_irq> <io_addr> <base_addr>",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for the Aquila, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
	db	"Copyright (C) Aquila Communications, Inc., 1989. ",CR,LF
	db	"All Rights Reserved.",CR,LF, '$'

no_prom_msg	db	"The address PROM does not appear to be at that memory address",CR,LF,'$'
no_io_msg	db	"Unable to read/write I/O ports",CR,LF,'$'
addr_bad_msg	db	"Memory address should be less than 65536.",CR,LF,'$'


	public	parse_args
parse_args:
	mov	di,offset int_no
	call	get_number
	mov	di,offset io_addr
	call	get_number
	mov	di,offset base_addr
	call	get_number
	clc
	ret


	public	etopen
etopen:
;
;	INITIALIZE TRANSMIT QUEUE AND RX-HOLD LIST POINTERS
;
	assume	ds:code
	mov	al,int_no
	call	maskint			;disable these interrupts.

	cmp	base_addr.offs,0	;low word of segment can't be zero.
	je	etopen_1
	cmp	base_addr.segm,0	;high word of segment must be zero.
	je	etopen_2
etopen_1:
	mov	dx,offset addr_bad_msg
	stc
	ret
etopen_2:

	loadport
	setport	EthCtlReg
	mov     al, DLCR_ENABLE*8 or EthCtlIDProm
	out     dx, al			;set control reg to access ID Prom
					; leave HW Reset on
	setport	EthRSel			;disable controller while setting node
	mov	al, DLCR_ENABLEN
	out	dx, al

	mov	ds, base_addr
	assume  ds: nothing

	xor	si, si			;set DS:SI to node address prom
	mov	ax, [si]
	or	ax, ax			;Check for Aquila's manufacturer code.
	jnz	SetRandomJmp1		;not there -- give up.
	cmp	byte ptr [si+2],084h
	je	InitNodeAddr		;...
SetRandomJmp1:
	mov	dx,offset no_prom_msg
	movseg	ds,cs
	jmp     InitHwErr

InitNodeAddr:
	mov     ax, cs			;move the address over.
	mov	es, ax
	mov	di, offset rom_address	;set ES:DI to point to cs:rom_address
	mov	cx,EADDR_LEN/2
	rep	movsw

	movseg	ds,cs
	assume	ds:code
	mov	si,offset rom_address
	call	set_address_0

	push	cs
	pop     es
	assume  es: code

	loadport
	setreg	DLCR_XMIT_STAT
	in      al, dx
	out     dx, al			;clear xmit interrupts at controller
	setreg	DLCR_RECV_STAT
	in      al, dx
	out     dx, al			;clear recv interrupts at controller
	setreg	DLCR_XMIT_MASK
	mov     cx, 50
init_hw_1:
	in	al,61h
	loop    init_hw_1		;wait >15 usec
	xor	ax, ax
	out	dx, al
	in	al, dx			;make sure that we read the same thing
	cmp	al, ah			;  we just wrote.
	jne	InitHwErr1
	setreg	DLCR_RECV_MASK
	xor	ax, ax
	out	dx, al
	in	al, dx
	cmp	al, ah
	je      InitHwSetCtl
InitHwErr1:
	mov	dx,offset no_io_msg
InitHwErr:
	stc
	ret

InitHwSetCtl:
	setreg	BMPR_DMA_ENABLE
	mov	ax, EthDMAWrt or EthDMARd
	out	dx, al
	setreg	DLCR_XMIT_MODE
	mov	al, EthLoopN
	out	dx, al
	setreg	DLCR_RECV_MODE
	mov	al, EthAcceptNorm
	out	dx, al
	setreg	DLCR_ENABLE
	xor	ax, ax
	out	dx, al			;enable the controller
	mov     cx, 500
init_hw_2:
	in	al,61h
	loop    init_hw_2		; wait > 120 usec
	setreg	DLCR_XMIT_MASK
	mov	al, TxInterruptMask
	out 	dx, al			;set real interrupt masks
	setreg	DLCR_RECV_MASK
	mov	al, RxInterruptMask
	out 	dx, al
	setreg	DLCR_XMIT_MODE
	mov	al, EthLoopN
	out	dx, al

;
; Now hook in our interrupt
;
	call	set_recv_isr

	sti

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


int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'
base_addr_name	db	"Memory address ",'$'


	public	print_parameters
print_parameters:
	mov	di,offset int_no
	mov	dx,offset int_no_name
	call	print_number
	mov	di,offset io_addr
	mov	dx,offset io_addr_name
	call	print_number
	mov	di,offset base_addr
	mov	dx,offset base_addr_name
	call	print_number
	ret

code	ends

	end
