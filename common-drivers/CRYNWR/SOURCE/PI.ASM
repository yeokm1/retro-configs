;   PC/FTP Packet Driver source, conforming to version 1.09 of the spec,
;   for the Ottawa PI card.
;   Dave Perry, VE3IFB, October 16, 1991
;   Portions (C) Copyright 1991, 1992 David G Perry
; 
;   Copyright, 1988, 1989, 1990, 1991 Russell Nelson

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

; Change history:
; October 16, 1991 (dp) - Creation
; January 8, 1992 (dp) - Fixed bug in set_acc_delay (rewritten).
;	- Improved high speed performance by decreasing the amount
;	  of time DMA is disabled in scc routines.
;	- Added new options to command line to allow more clocking
;	  options (see documentation file).
;	- Added transmit buffer queue.
;	- Added command line option to specify number and size of
;	  DMA buffers.
;	- Optional support for "pseudo" ethernet class
;	- Fixed bug in internal clocking mode

	include 8530inc.asm
	include piinc.asm

ETHER	equ	1	; This driver will "pretend" the PI card is an ethernet
			; card. I have used this method to run QVT/NET
			; using back-to-back PI cards between
			; two PCs. Do not use this feature on a radio link,
			; as no call signs would be transmitted.
			; To use it, reassemble with MYCLASS equ ETHER
			; and etheraddr = desired ethernet address

AX25	equ	9	; Driver class
MYCLASS	equ	AX25

PITYPE	equ	1	; Driver type

; transmitter states
IDLE		equ	0 ; Transmitter off
TXDELAY		equ	1 ; Sending leading flags
ACTIVE		equ	2 ; Transmitter on, sending data
UNDERRUN	equ	3 ; Transmitter on, flushing CRC
FLAGOUT		equ	4 ; CRC sent - attempt to start next frame
DEFER		equ	5 ; DCD Active - DEFER Transmit
CRCOUT		equ	6 ; Waiting for CRC bytes to clear the fifo

DEFAULTBUFSIZE	equ	2048

version	equ	2

	include	defs.asm

code	segment	word public
	assume	cs:code, ds:code

etheraddr	db	00h,00h,00h,00h,00h,00h

tstate	db	0

; Short pointers to DMA buffers.
rxbufptr	dw	0 ; Current rx buffer
altbufptr	dw	0 ; Alternate receive buffer
bufptr1		dw	0 ; DMA approved buffer
bufptr2		dw	0 ; DMA approved buffer
txbufptr	dw	0 ; Current tx buffer
freelist	dw	0 ; Head of free list
txqueue		dw	0 ; Head of transmit queue

txlength	dw	0 ; Save area for length of incoming packet

	public	acc_delay
acc_delay dw	0,0
diff		dw	0,0
tick1		dw	0,0
tick2		dw	0,0
tx_tc	dw	0,0 ; Time constant for baud rate generator (transmit)
rx_tc	dw	0,0 ; Time constant for baud rate generator (receive)
random		db	0		; Pseudo random number

; The following values may be overridden from the command line.
; If they are omitted from the command line, these defaults are used.
; All of them occupy 4 bytes to satisfy the call to get_number.
	public	int_no, io_addr, dma_channel
int_no		db	7,0,0,0		; HW Interrupt
io_addr		dw	0380h,0		; I/O address for card (jumpers)
dma_channel	db	1,0,0,0 	; DMA channel for card (jumpers)
speed		dw	0,0		; Baud rate (0 for external clock)
txdelayparm	dw	15,0		; TX delay (length of flags before data)
persist		dw	128,0		; P - persistance probability out of 256
slottime	dw	10,0		; Slot time for backoff
tailtime	dw	1,0		; Depends on baud rate
clkmode		dw	0,0		; Clocking mode
bufsiz		dw	DEFAULTBUFSIZE,0; Buffer size
numbufs		dw	5,0		; Number of buffers

; The following 3 values are calculated at initialization and depend
; on which DMA channel has been selected
page_addr	dw	83h		; To be calculated from dma channel
dma_dest	dw	2		; Defaults are for channel 1
dma_wcr		dw	3

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	MYCLASS,0	; null terminated list of classes.(ax25)
driver_type	db	PITYPE		;Assigned by FTP Software Inc.
driver_name	db	'pi',0		;name of the driver.
driver_function	db	1		;Only basic functionality
parameter_list	label	byte
	db	1	;major rev of packet driver
	db	9	;minor rev of packet driver
	db	14	;length of parameter list
	db	0	;length of MAC-layer address
parm_mtu	label	word
	dw	DEFAULTBUFSIZE	; MTU, including MAC headers
	dw	MAX_MULTICAST * EADDR_LEN	;buffer size of multicast addrs
	dw	0	;(# of back-to-back MTU rcvs) - 1
	dw	0	;(# of successive xmits) - 1
int_num	dw	0	;Interrupt # to hook for post-EOI
			;processing, 0 == none,

	public	rcv_modes
rcv_modes	dw	4		;number of receive modes in our table.
		dw	0,0,0,rcv_mode_3

; Switch receive buffers so we can quickly set up DMA again
	public	switchbuffers
switchbuffers:
	mov	ax,rxbufptr
	cmp	ax,bufptr1
	jnz	sw_1
	mov	ax,bufptr2
	mov	rxbufptr,ax
	mov	ax,bufptr1
	mov	altbufptr,ax
	ret
sw_1:
	mov	ax,bufptr1
	mov	rxbufptr,ax
	mov	ax,bufptr2
	mov	altbufptr,ax
	ret

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

; Append buffer pointed to by ax to queue specified by bx
	public	enqueue
enqueue:
	pushf
	cli
	push	si
	push	bp

	mov	si,cs:bufsiz
	mov	bp,ax
	mov	word ptr cs:[bp+si],0	; Make sure next pointer is null

	cmp	word ptr cs:[bx],0	; Is list empty?
	jne	en1			; No - find the end
	mov	cs:[bx],ax		; Yes - add it

	pop	bp
	pop	si
	popf
	ret

en1:	mov	bp,word ptr cs:[bx] ; get pointer to first element
en2:
	cmp	word ptr cs:[bp+si],0	; Is next pointer null?
	je	en3		; Yes, append our buffer
	mov	bp,cs:[bp+si]	; No - advance to next element
	jmp	en2	
en3:	mov	cs:[bp+si],ax

	pop	bp
	pop	si
	popf
	ret

	public	dequeue
dequeue:
	pushf
	cli
	push	si
	mov	si,cs:bufsiz
	cmp	word ptr cs:[bx],0	; Is list empty?
	jne	deq1
	xor	ax,ax		; Yes, return error
	pop	si
	popf
	stc
	ret
deq1:
	push	bp
	mov	bp,cs:[bx]		; No, dequeue buffer
	mov	ax,cs:[bp+si]
	mov	cs:[bx],ax
	mov	ax,bp

	pop	bp
	pop	si
	popf
	clc
	ret

; Check to see if we should transmit or DEFER
; Return: Carry set - DEFER
	public check_dcd
check_dcd:
; Check DCD - see if we should DEFER transmission
	cmp	tstate,FLAGOUT
	je	go		; The transmitter is already on - don't defer
	mov	bx,R0+RES_EXT_INT
	call	wrtscc
	mov	bx,R0+RES_EXT_INT
	call	wrtscc
	mov	bx,R0
	call	rdscc
	test	al,DCD
	jne	check_dcd_1	; Carrier detected - we have to DEFER


	mov	al,21		; Generate pseudo random number
	mul	cs:random
	add	ax,53
	mov	cs:random,al	; Save it for next one in sequence

	xor	ah,ah
	cmp	ax,cs:persist	; Should we DEFER?
	jle	go		; No
	mov	cs:tstate,DEFER	; We have to wait
	mov	ax,cs:slottime	; Yes - DEFER 1 slot time
	call	tdelay
	stc			; We are DEFERring
	ret

go:	clc			; We don't have to wait
	ret

check_dcd_1:
	mov	cs:tstate,DEFER	; We have to wait
	mov	ax,1000		; In case DCD int. missed (shouldn't happen)
	call	tdelay
; Defer until dcd transition or 1S timeout or abort
	mov	bx,R15+CTSIE+DCDIE+BRKIE
	call	wrtscc
	stc			; We are DEFERring
	ret

	public	send_pkt
send_pkt:
;enter with es:di->upcall routine, (0:0) if no upcall is desired.
;  (only if the high-performance bit is set in driver_function)
;enter with ds:si -> packet, cx = packet length.
;if we're a high-performance driver, es:di -> upcall.
;exit with nc if ok, or else cy if error, dh set to error number.
	assume	ds:nothing
; Copy packet into local DMA approved buffer
; Enqueue it for transmission. If the queue is full, return error.
; If the transmitter is not active and the channel is free, start
; transmission, else defer. Return as soon as buffer can be released.
	
	pushf
	cli

	mov	ax,cs		;  Point es at the code segment
	mov	es,ax

	mov	bx,offset freelist	; Get a buffer from the freelist
	call	dequeue
	jc	send_error	; None left

	mov	di,ax		; Use newly aquired DMA buffer
	push	bp
	push	si
	mov	bp,ax
	mov	si,cs:bufsiz
	mov	cs:[bp+si+2],cx	; Tack on length
	pop	si
	pop	bp	
	
	cld
	rep	movsb		; Copy packet

	mov	bx,offset txqueue	; Append it to the tx queue
	call	enqueue

	mov	al,cs:tstate	; Is transmitter idle?
	cmp	al,IDLE
	je	send_pkt_1	; Yes - start transmitting
	popf			; Else return without error
	clc
	ret	

send_error:
	popf
	stc			; Return error
	ret
	
send_pkt_1:
	cli

	mov	bx,offset txqueue; Get a buffer from the txqueue
	call	dequeue
	jc	none_to_send	; None left
	mov	cs:txbufptr,ax	; Make it the active tx buffer

	push	bp
	push	si
	mov	bp,ax
	mov	si,cs:bufsiz
	mov	cx,cs:[bp+si+2]	; Get length
	pop	si
	pop	bp	

	mov	cs:txlength,cx

; Check DCD - see if we should DEFER transmission
	call	check_dcd
	jc	send_pkt_exit	; DEFER
	mov	ax,cs		; Set up for TX DMA
	mov	cx,ax
	mov	bx,cs:txbufptr
	mov	ax,cs:txlength
	call	setup_tx_dma

	mov	cs:tstate,TXDELAY
	call	tx_on	; Start sending flags
	mov	ax,cs:txdelayparm	; generate an exint after TXDELAY
	call	tdelay

send_pkt_exit:
	popf
	clc	;  No error
	ret

none_to_send:
	call	tx_off
	mov	cs:tstate,IDLE
	popf
	clc	;  No error
	ret

	public	set_address
set_address:
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
	assume	ds:nothing
	ret


rcv_mode_3:
;receive mode 3 is the only one we support, so we don't have to do anything.
	ret


	public	set_multicast_list
set_multicast_list:
;enter with ds:si ->list of multicast addresses, cx = number of addresses.
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

;enter with dx = amount of memory desired.
;exit with nc, dx -> that memory, or cy if there isn't enough memory.
	extrn	malloc: near

	extrn	count_in_err: near
	extrn	count_out_err: near

wcrsave	dw	0
rsesave	db	0

	public rxint
rxint:
	assume	ds:code

	mov	bx,R1 ; Get special condition bits from R1
	call	rdscc
	mov	rsesave,al

; save length of frame from 8237 */
	xor	al,al
	out	DMA_RESETFF,al	; Reset byte pointer flipflop
	mov	dx,dma_wcr	; Get address of word count register
	in	al,dx		; Input low byte of word
	mov	bl,al		; Save it
	in	al,dx		; Input high byte
	mov	bh,al		; Save it - bx = bytes left
	mov	wcrsave,bx
	call	switchbuffers	; Switch buffers so we can get DMA happening
; Error reset lets the receive fifo empty out using dma. There can be a few
; garbage bytes left in there so it is important to 'drain' them by
; issuing the error reset *before* we set up DMA for the next receive.
	mov	bx,R0+ERR_RES	; Error reset
	call	wrtscc

	mov	ax,cs		; Setup for next receive
	mov	cx,ax
	mov	bx,rxbufptr
	mov	ax,cs:bufsiz
	call	setup_rx_dma

	mov	al,rsesave	; Recover status
	test	al,END_FR	; Is this an end of packet int?
	jz	rxint_exit	; no
	test	al,CRC_ERR	; CRC ok?
	jnz	rxint_exit	; No - toss frame

	mov	bx,wcrsave	; Recover frame length
	mov	ax,cs:bufsiz	; ax = buf size - 1
	sub	ax,1
	sub	ax,bx		; minus bytes left = byte count
	cmp	ax,10		; Runt?
	jl	rxint_exit	; Yes, ignore it
; Valid frame
	sub	ax,2		; Subtract 2 CRC bytes from byte count

	mov	cx,ax		; Load packet length
	mov	dl,MYCLASS	; Load packet class

	mov	ax,cs		; Get our segment
	mov	es,ax		; into es
	mov	di,rxbufptr	; Point to type field (not needed for AX25)
	add	di,12

	call	recv_find	; Try to get a buffer to send it up in.
	mov ax,	es		; Did recv_find give us a null pointer?
	or ax,	di		; ..
	je	rxint_exit	; If null, we must throw this one away
	
	cld			; Copies which follow are forward

	push	ds		; Save our data seg
	push	cx		; We will want the count and pointer
	push	es		;  to hand to client after copying,
	push	di		;  so save them at this point

	mov	si,altbufptr
	rep	movsb		; Do the copy

	pop	si		; Recover pointer to destination
	pop	ds		; Tell client it's his source
	pop	cx		; And it's this long
	call	recv_copy	; Give it to him
	pop	ds		; Recover our data seg

rxint_exit:

	ret

txint:
	assume	ds:code

	ret

exint:
	assume	ds:code
	pushf
	cli

	mov	bx,R0	; Get status
	call	rdscc

; reset external status latch
	mov	bx,R0+RES_EXT_INT
	call	wrtscc

	mov	al,cs:tstate	; Is transmit IDLE?
	cmp	al,IDLE	
	jnz	exint_1		; No

	mov	bx,R0+ERR_RES	; TX IDLE - unlock fifo to flush any garbage
	call	wrtscc
	mov	ax,cs		; Assume abort - Reset receive DMA
	mov	cx,ax
	mov	bx,rxbufptr
	mov	ax,cs:bufsiz
	call	setup_rx_dma
	jmp	exint_exit	; exit
	
exint_1:
	mov	al,cs:tstate	
	cmp	al,ACTIVE
	jne	exint_2
				; Transmitter is ACTIVE
	mov	cs:tstate,FLAGOUT
	mov	ax,tailtime
	call	tdelay
	jmp	exint_exit
exint_2:
	cmp	al,FLAGOUT
	jne	exint_3
				; Transmitter in FLAGOUT state
	mov	ax,cs:txbufptr	; Free the tx buffer
	mov	bx, offset freelist
	call enqueue
	jmp	send_pkt_1	; Go see if there are more to send
exint_3:
	cmp	al,TXDELAY
	jne	exint_4
				; Transmitter is in TXDELAY
	mov	bx,R0+RES_Tx_CRC+RES_Tx_P ; reset CRC, txint pending
	call	wrtscc
	mov	bx,R15+TxUIE	; Allow underrun int only
	call	wrtscc
				; Enable TX DMA
	mov	bx,R1+WT_RDY_ENAB+WT_FN_RDYFN+EXT_INT_ENAB
	call	wrtscc
				; Unmask channel n (enable DMA controller chip)
	mov	al,Byte Ptr dma_channel ; Enable DMA for this channel
	add	al,DMA_ENABLE
	out	DMA_MASK,al
	
	mov	bx,R0+RES_EOM_L ; Send CRC on underrun
	call	wrtscc
	mov	cs:tstate,ACTIVE	; Packet going out now
	jmp	exint_exit

exint_4:
				; Transmitter must be in DEFER
	call	check_dcd	; See if we should DEFER again
	jc	exint_exit	; DEFER

	mov	ax,cs		; Set up for TX DMA
	mov	cx,ax
	mov	bx,txbufptr
	mov	ax,txlength
	call	setup_tx_dma

	mov	cs:tstate,TXDELAY
	call	tx_on		; Start sending flags
	mov	ax,txdelayparm	; generate an exint after TXDELAY
	call	tdelay
	popf
	ret

exint_exit:
	popf
	ret

	public	recv
recv:
;called from the recv isr.  All registers have been saved, and ds=cs.
;Upon exit, the interrupt will be acknowledged.
	assume	ds:code
; Read interrupt status register from channel A
; Process all pending interrupts in a loop

recv_1:

	mov	bx,R3
	call	rdscc
	cmp	al,0
	jz	recv_exit
	test	al,CHARxIP	; Is channel A receive int pending?
	jz	recv_2		; no
	call	rxint		; yes
	jmp	recv_eoi
recv_2:	test	al,CHATxIP	; Is channel A tx int pending?
	jz	recv_3		; no
	call	txint		; yes
	jmp	recv_eoi
recv_3:	test	al,CHAEXT	; Is channel external/status int pending?
	jz	recv_eoi	; no
	call	exint		; yes
; Reset highest interrupt under service
recv_eoi:
	mov	bx,R0+RES_H_IUS
	call	wrtscc
	jmp	recv_1 ; Loop for more int processing
recv_exit:	
	ret

; This routine is used for all writes to the SCC. It satisfies the
; The SCCs access time restriction by using delay loops. These loops
; are processor speed dependent and are determined by acc_delay.

; Enter with bh = register, bl = value

	public	wrtscc
wrtscc:
	pushf		; Save current interrupt state
	cli		; Wouldn't do to be interrupted now
	push ax
	push cx
	push dx
	push di
	push si
	push bp

	mov di,acc_delay; Load this into a register for speed

	mov dx,io_addr	; Get card address
	add dx,CTL_A	; Point to channel A control reg
	mov bp,dx	; Save it

	mov dx,io_addr	; get address of dma enable port
	add dx,DMAEN
	mov si,dx	; save it

	mov cx,di	; For loop below

	mov ax,100h	; Write a 0 to disable DMA while we touch the scc
	out dx,al
; ******** DMA off

Loop1: loop Loop1	;[5]

	mov dx,bp	;[2] Get pointer to ch A control reg
	mov al,bh	;[2] Select register
	out dx,al	;[8]

	mov cx,di	;[2]
Loop2:	loop Loop2	;[5]

	mov dx,si	;[2] get address of dma enable port
	mov al,ah	;[2] Enable DMA in between accesses
	out dx,al	;[8]
; ******** DMA on - was off for 36 cycles
	nop		; Leave extra time for XT ram refresh cycle to finish
	nop
	nop
	mov cx,di	; For loop below
	mov al,0	; now disable DMA in between accesses
	out dx,al	;
; ******** DMA off

Loop2a:	loop Loop2a	;[5]

	mov dx,bp	;[2] Get pointer to ch A control reg
	mov al,bl	;[2] Output value
	out dx,al	;[8]

	mov cx,di	;[2]
Loop3:	loop Loop3	;[5]

	mov dx,si	;[2] get address of dma enable port
	mov al,ah	;[2] Enable DMA
	out dx,al	;[8]
; ******** DMA on - was off for 36 cycles

	pop bp
	pop si
	pop di 
	pop dx
	pop cx
	pop ax
	popf
	ret

; Enter with bh = reg

	public	rdscc
rdscc:
	pushf
	cli
	push cx
	push dx
	push di
	push si
	push bp

	mov di,acc_delay; Save it

	mov dx,io_addr	; Get card address
	add dx,CTL_A	; Point to channel A control reg
	mov bp,dx	; Save it

	mov dx,io_addr	; get address of dma enable port
	add dx,DMAEN
	mov si,dx	; save it

	mov cx,di	; For loop below

	mov ax,100h	; Disable DMA while we touch the scc
	out dx,al
; ******** DMA off
Loop4:	loop Loop4	;[5]

	mov dx,bp	;[2] Get address of SCC control reg
	mov al,bh	;[2] Select register
	out dx,al;	;[8]

	mov cx,di	;[2]
Loop5:	loop Loop5	;[5]

	mov dx,si	;[2] get address of dma enable port
	mov al,ah	;[2] Enable DMA
	out dx,al	;[8]
;********* DMA on - was off for 36 cycles
	nop		; Leave extra time for XT ram refresh cycle to finish
	nop
	nop
	mov cx,di	; For loop below
	mov al,0
	out dx,al
;********* DMA off
Loop5a:	loop Loop5a	;[5]

	mov dx,bp	;[2] Get address of SCC control reg
	in al,dx	;[8] read register
	mov bl,al	;[2] save return value

	mov cx,di	;[2]
Loop6:	loop Loop6	;[5]

	mov dx,si	;[2] get address of dma enable port
	mov al,ah	;[2] Enable DMA
	out dx,al	;[8]
; ******** DMA on - was off for 36 cycles
 
	mov	al,bl	; recover return value

	pop	bp
	pop	si
	pop	di
	pop	dx
	pop	cx
	popf
	ret

	public delay8253
delay8253:
	nop
	nop
	nop
	nop
	nop
	ret

; Setup for DMA
; Initializes certain DMA chip registers - called by setup_rx_dma
; and setup_tx_dma
; Enter with cx:bx = buffer, ax = length
; Writes the dma chip word count reg, dest reg, and the dma page reg
;
	public setup_dma
setup_dma:
	
	pushf	; Save interrupt state
	cli	; Disable interrupts

	sub	ax,1	; adjust length for DMA chip
	push	ax	; Save it for later
	
	mov	al,Byte Ptr dma_channel ; Disable DMA for this channel
	add	al,DMA_DISABLE
	out	DMA_MASK,al

	xor	al,al
	out	DMA_RESETFF,al	; Reset byte pointer flipflop

; Calculate high order 4 bits of the buffer area and store
; them in the DMA page register
	mov	ax,cx	; Make a working copy of the seg reg
	shl	ax,1
	shl	ax,1
	shl	ax,1
	shl	ax,1
	add	ax,bx	; add offset - we have bottom word of abs. address
	pushf		; Save carry bit
	mov	dx,dma_dest	; Output buf start (source) address
	out	dx,al
	mov	al,ah
	out	dx,al
	mov	ax,cx	; Get another copy of the seg reg
	mov	cl,12	; shift it down
	shr	ax,cl	; to get page register
	popf		; Recover carry bit
	adc	ax,0	; add any carry from previous add

	mov	dx,page_addr	; Set up DMA page register
	out	dx,al

	mov	dx,dma_wcr	; Get address of word count register
	pop	ax		; Recover length and output it
	out	dx,al
	mov	al,ah
	out	dx,al

	popf	; restore interrupt state
	ret

; Setup receive dma
; Enter with cx:bx = buffer, ax = length
;
	public	setup_rx_dma
setup_rx_dma:
	pushf	; Save interrupt state
	cli	; Disable interrupts

	call	setup_dma

; Get ready for RX DMA
	mov	bx,R1+WT_FN_RDYFN+WT_RDY_RT+INT_ERR_Rx+EXT_INT_ENAB
	call	wrtscc

; Set DMA mode register to single transfers, incrementing address,
; auto init, writes
	mov	al,dma_channel	; Put dma chip in transmit for this channel
	add	al,DMA_RX_MODE
	out	DMA_MODE,al

; Unmask channel n (enable DMA controller chip)
	mov	al,Byte Ptr dma_channel ; Enable DMA for this channel
	add	al,DMA_ENABLE
	out	DMA_MASK,al

; If a packet is already coming in, this line is supposed
; to mess up the crc to avoid receiving a partial packet
	mov	bx,R0+RES_Rx_CRC
	call	wrtscc

; Enable RX dma in SCC chip
	mov	bx,R1+WT_RDY_ENAB+WT_FN_RDYFN+WT_RDY_RT+INT_ERR_Rx+EXT_INT_ENAB
	call	wrtscc
	popf
	ret

;
; Set up for transmit DMA
; Enter with cx:bx = buffer, ax = length
;
	public	setup_tx_dma
setup_tx_dma:
	pushf	; Save interrupt state
	cli	; Disable interrupts
	call	setup_dma
; Set DMA mode register to single transfers, incrementing address,
; no auto init, reads
	mov	al,dma_channel	; Put dma chip in transmit for this channel
	add	al,DMA_TX_MODE
	out	DMA_MODE,al
	popf
	ret


; Set up 8253 chip for time delay
; enter with time to delay (mS) in ax
;
	public	tdelay
tdelay:
	push	bx
	push	cx
	push	dx

	push	ax			; Save delay time
	mov	dx,io_addr
	add	dx,TMRCMD
	mov	al,SC1+LSB_MSB+MODE0	; Setup timer sc
	out	dx,al
	call delay8253			; Satisy access time restriction

	mov	dx,io_addr
	add	dx,TMR1
	pop	ax			; Recover delay time
	sal	ax,1			; Times 2 to make milliseconds
	out	dx,al			; Write low byte
	call delay8253
	mov	al,ah
	out	dx,al			; then high byte

	mov	bx,R15+CTSIE	 	; Enable interrupt for timeout
	call	wrtscc
	mov	bx,R1+EXT_INT_ENAB
	call	wrtscc
	mov	bx,R0+RES_EXT_INT
	call	wrtscc
	
	pop	dx
	pop	cx
	pop	bx
	ret

	public	tx_off
tx_off:
	pushf
	cli
	push	bx

	mov	bx,R5+Tx8+DTR			; TX off
	call	wrtscc

	mov	ax,speed	; Internally clocked?
	cmp	ax,0
	jz	tx_off_1	; Externally clocked, don't change BRG
	mov	ax,clkmode	; Clocking mode 1?
	cmp	ax,1
	jz	tx_search	; Mode 1, don't change BRG
				; But enter search mode
; Reprogram BRG for 32x clock for receive DPLL
	mov	bx,R14+BRSRC	; BRG off, keep Pclk source
	call	wrtscc
	mov	ax,rx_tc	; Get receive time constant for BRG
	mov	bx,R12		; Write low byte of time constant to R12
	mov	bl,al
	call	wrtscc
	mov	ax,rx_tc	; Get receive time constant for BRG
	mov	bx,R13		; Write high byte of time constant to R13
	mov	bl,ah
	call	wrtscc
tx_search:
	mov	bx,R14+BRSRC+SEARCH ; SEARCH mode, BRG source
	call	wrtscc
	mov	bx,R14+BRSRC+BRENABL ; Enable the baud rate generator
	call	wrtscc
tx_off_1:
	mov	bx,R3+RxENABLE+RxCRC_ENAB+Rx8	; RX on
	call	wrtscc
	
	push	cs		; Set up RX DMA
	pop	cx
	mov	bx,rxbufptr
	mov	ax,cs:bufsiz
	call	setup_rx_dma

	mov	bx,R15+BRKIE
	call	wrtscc		; allow abort interrupt

	pop	bx
	popf
	ret

	public	tx_on
tx_on:
	pushf
	cli
	push	bx

	mov	bx,R15+0	; Exints off first to avoid abort interrupt
	call	wrtscc
	mov	bx,R3+Rx8	; Rx off
	call	wrtscc
	mov	bx,R1+WT_FN_RDYFN+EXT_INT_ENAB	; Set up for TX DMA
	call	wrtscc
	mov	ax,speed	; Internally clocked?
	cmp	ax,0
	jz	tx_on_1		; Externally clocked, don't change BRG
	mov	ax,clkmode	; Clocking mode 1?
	cmp	ax,1
	jz	tx_on_1		; Clocking mode 1, don't change BRG
	mov	ax,tx_tc	; Get transmit time constant for BRG
	mov	bx,R12		; Write low byte of time constant to R12
	mov	bl,al
	call	wrtscc
	mov	ax,tx_tc	; Get transmit time constant for BRG
	mov	bx,R13		; Write high byte of time constant to R13
	mov	bl,ah
	call	wrtscc
tx_on_1:
	mov	bx,R5+TxCRC_ENAB+RTS+TxENAB+Tx8+DTR
	call	wrtscc

	pop	bx
	popf
	ret

	include	popf.asm

	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret

;any code after this will not be kept.  Buffers used by the program, if any,
;are allocated from the memory between end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
	db	30000 dup(?)
end_free_mem	label	byte


; Initialize the SCC registers
	public scc_init
scc_init:
	pushf
	cli

	mov	cs:tstate,IDLE
	mov	bx,R9+CHRA	; reset channel A
	call	wrtscc
	mov	bx,R2+0ffh	; Set interrupt vector
	call	wrtscc
	mov	bx,R1+0		; Deselect all Rx and Tx interrupts
	call	wrtscc
	mov	bx,R15+0	; Turn off external interrupts
	call	wrtscc
	mov	bx,R4+SDLC+X1CLK ; SDLC mode and times 1 clock
	call	wrtscc

	mov	ax,speed	; Get baud rate
	cmp	ax,0
	jz	scc_init_1	; Jump if externally clocked
	mov	ax,clkmode	; Clocking mode 1?
	cmp	ax,1
	jnz	scc_init_5	; No - must be internal clocking

	mov	bx,R10+CRCPS ; Clock mode 1, CRC preset, not NRZI mode
	call	wrtscc
			; Receive clock = RTxC pin
			; Transmit clock = baud rate generator
			; Transmit clock is output on TRxC pin 
	mov	bx,R11+TCBR+RCRTxCP+TRxCOI+TRxCTC
	call	wrtscc 	
	jmp	scc_init_2

scc_init_5:
	mov	bx,R10+CRCPS+NRZI ; Internal clock, CRC preset, NRZI mode
	call	wrtscc
			; Receive clock = DPLL
			; Transmit clock = baud rate generator
			; Transmit clock is output on TRxC pin 
	mov	bx,R11+TCBR+RCDPLL+TRxCOI+TRxCTC
	call	wrtscc 	
	jmp	scc_init_2
scc_init_1:			; Externally clocked
	mov	bx,R10+CRCPS	; CRC preset
	call	wrtscc
			; Receive clock = RTxC pin
			; TRxC pin is input for transmit clock
	mov	bx,R11+TCTRxCP	; Rcv clk is from Rtxcl, TRxC pin is input
	call	wrtscc

scc_init_2:
	mov	bx,R6+0		; Null out SDLC start address
	call	wrtscc
	mov	bx,R7+FLAG	; SDLC flag
	call	wrtscc
	mov	bx,R5+Tx8+DTR	; Set up tx but don't enable it yet
	call	wrtscc
	mov	bx,R3+Rx8	; Initial rx setup
	call	wrtscc
	mov	bx,R14+BRSRC
	call	wrtscc

	mov	ax,rx_tc	; Get receive time constant for BRG
	mov	bx,R12		; Write low byte of time constant to R12
	mov	bl,al
	call	wrtscc
	mov	ax,rx_tc	; Get receive time constant for BRG
	mov	bx,R13		; Write high byte of time constant to R13
	mov	bl,ah
	call	wrtscc

	mov	ax,speed	; Internal clocking?
	cmp	ax,0
	jz	scc_init_3	; Jump if External
	mov	ax,clkmode
	cmp	ax,1
	jnz	t1

	mov	bx,R14+BRSRC+SSRTxC+BRENABL
	call	wrtscc
	jmp scc_init_4
	
t1:
	mov	bx,R14+BRSRC+SSBR+BRENABL
	call	wrtscc
	jmp scc_init_4
scc_init_3:
	mov	bx,R14+BRSRC+SSRTxC ; Set DPLL source = RTxC
	call	wrtscc
scc_init_4:
	call	tx_off		; Set up and enable RX

	popf
	ret

;  This routine calculates the constant to be used in the delay loops
;  which satisfy the SCC's access recovery time.  This needs to be timed and
;  calculated because a fixed value would not work in a 4.77mhz XT
;  to a 40mhz 486 (and beyond).
	public set_acc_delay
set_acc_delay:
	pushf
	cli
	push	ax
	push	bx
	push	cx
	push	dx

	mov	cx,1000

	mov	al,0			;latch counter zero.
	out	43h,al
	in	al,40h			;read counter zero.
	mov	ah,al
	in	al,40h
	xchg	ah,al
	mov	tick1,ax

h1:	loop	h1

	mov	al,0			;latch counter zero.
	out	43h,al
	in	al,40h			;read counter zero.
	mov	ah,al
	in	al,40h
	xchg	ah,al
	mov	tick2,ax
	mov	ax,tick1
	sub	ax,tick2
	mov	diff,ax	; Elapsed counts
	mov	bx,ax
	mov	dx,0
	mov	ax,5000	; Divide by
	div	bx	; the number of counts elapsed
	cmp	al,0
	jne	set_acc_2
	mov	al,1	; Delay constant must be at least 1
set_acc_2:
	xor	ah,ah
	mov	acc_delay,ax

	mov di, offset acc_delay	; Processor speed constant
	mov dx,	offset acc_delay_name	; Message for it
	call	print_number

	pop	dx
	pop	cx
	pop	bx
	pop	ax
	popf
	ret

	public	usage_msg
usage_msg	db	"usage: pi <packet_int_no> [hardware_irq] [io_addr] [dma] [baud] [TXD] [P] [slot] [tail] [clock mode] [buf size] [number of buffers]",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for the Ottawa PI card, version ",'0'+majver,".",'0'+version,CR,LF
		db	"Portions Copyright 1991, 1992 Dave Perry",CR,LF,'$'

int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'
dma_name	db	"DMA channel ",'$'
acc_delay_name	db	"Processor constant ",'$'
diff_name	db	"diff ",'$'
tick1_name	db	"tick1 ",'$'
tick2_name	db	"tick2 ",'$'
speed_name	db	"Baud rate ",'$'
txdelay_name	db	"TX delay ",'$'
persist_name	db	"P value ",'$'
slottime_name	db	"Slot time ",'$'
tailtime_name	db	"Tail time ",'$'
clkmode_name	db	"Clocking mode ",'$'
bufsiz_name	db	"Buffer size ",'$'
numbufs_name	db	"Number of buffers ",'$'
baud_err_msg	db	"Error: Selected baud rate is out of range",CR,LF,'$'
no_memory_msg	db	"Unable to allocate enough memory, look at end_resident in PI.ASM",CR,LF,'$'

	extrn	set_recv_isr: near

;enter with si -> argument string, di -> wword to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> argument string, di -> wword to print.
	extrn	print_number: near

;-> the assigned Ethernet address of the card.
	extrn	rom_address: byte

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	mov	di,offset int_no	; May override interrupt channel
	call	get_number
	mov	di,offset io_addr	; May override I/O address
	call	get_number
	mov	di,offset dma_channel	; May override channel
	call	get_number
	mov	di,offset speed		; May override speed
	call	get_number
	mov	di,offset txdelayparm	; May override TX delay time
	call	get_number
	mov	di,offset persist	; May override P value
	call	get_number
	mov	di,offset slottime	; May override Slot time
	call	get_number

; Calculate address of dma page register
	mov	al,Byte Ptr dma_channel
	cmp	al,2
	jne	parse_1
	mov	ax,81h
	jmp	parse_3
parse_1:
	cmp	al,3
	jne	parse_2
	mov	ax,82h
	jmp	parse_3
parse_2:
	mov	ax,83h
parse_3:
	mov	page_addr,ax

; Calculate address of dma destination and dma word count regs
	mov	ax,Word Ptr dma_channel
	shl	ax,1
	mov	dma_dest,ax
	add	ax,1
	mov	dma_wcr,ax
	
; Calculate time constants for baud rate generator
	mov	ax,word ptr speed
	cmp	ax,0
	jz	parse_4

	mov	dx,1ch		; Load SCC clock freq into dx:ax
	mov	ax,2000h	
	div	speed		; Divide by baud rate
	sub	ax,2		; sub 2 - this is the BRG time constant
	mov	tx_tc,ax	; for Transmit - save it

	mov	dx,0h		; Load SCC clock freq/32 into dx:ax
	mov	ax,0e100h	
	div	speed		; Divide by baud rate
	sub	ax,2		; sub 2 - this is the BRG time constant
	mov	rx_tc,ax	; for receive - save it

; Calculate tail time. This is the time required for the CRC and closing
; flag to be sent, during which the transmitter must be held on.
	mov	dx,0		; Magic number
	mov	ax,8ca0h
	div	speed
	add	ax,1		; Tail time is at least 1 ms
	mov	tailtime,ax
parse_4:
	mov	di,offset tailtime	; May override Tail time
	call	get_number

	mov	di,offset clkmode	; May override clocking mode
	call	get_number

	mov	di,offset bufsiz	; May override buffer size
	call	get_number
	mov	ax,bufsiz
	mov	parm_mtu,ax

	mov	di,offset numbufs	; May override number of buffers
	call	get_number
	cmp	numbufs,3		; But we need at least 3
	jge	parse_4a
	mov	numbufs,3
parse_4a:

	clc	; Return without error
	ret

baud_error:
	mov	dx,offset baud_err_msg
	mov	ah,9
	int	21h
	stc
	ret

; Return offset of a buffer which does not cross a DMA page boundary.
; Returns nc, ax=offset of buffer, or cy if no mem. Buffers are in code segment.
	public getbuffer
getbuffer:
	push	dx
	push	cx
	push	bx

	mov	ax,cs		; get buffer segment
	mov	cx,ax

get1:	mov	ax,cs:bufsiz
	add	ax,4		; Leave room for next pointer and length
	mov	dx,ax
	call	malloc
	jc	get_exit
	mov	bx,dx
	call	test_buffer
	jnc	get_exit	; found one
	add	numbufs,1	; Account for it
	
	pop	bx
	pop	cx
	pop	dx
	jmp	getbuffer
get_exit:
	mov	ax,dx		; recover pointer

	pop	bx
	pop	cx
	pop	dx
	ret			; return buffer found

	public	etopen
etopen:

; Not meaningful for AX25 class - this code assumes DIX ethernet
;get the address of the interface.
	mov	si,offset etheraddr
	movseg	es,ds
	mov	di,offset rom_address
	mov	cx,EADDR_LEN
	rep	movsb

; Set up DMA buffer pool
	mov	cx,numbufs	; We want this many
et1:
	call	getbuffer	; Get a DMA buffer
	jc	etopen_error
	mov	bx,offset freelist	; Append it to the free list
	call	enqueue
	loop	et1

	mov	bx,offset freelist	; Get a buffer from the freelist
	call	dequeue
	jc	etopen_error	; None left
	mov	bufptr1,ax	; Remember as primary
	mov	rxbufptr,ax	; Make it current

	mov	bx,offset freelist	; Get a buffer from the freelist
	call	dequeue
	jc	etopen_error	; None left
	mov	bufptr2,ax	; Use it for secondary rx buffer

; Adjust scc delay for speed of host cpu
	call	set_acc_delay

	mov	bx,R9+FHWRES	; Hardware reset SCC
	call	wrtscc

; Disable interrupts with Master interrupt ctrl reg */
	mov	bx,R9+0
	call	wrtscc
	call	scc_init
	mov	bx,R9+MIE+NV ; master interrupt enable
	call	wrtscc

; Set up counter chip
	mov	dx,io_addr
	add	dx,TMRCMD
	mov	al,SC0+LSB_MSB+MODE3 ; 500 uS square wave
	out	dx,al
	call delay8253		; Satisfy access time restriction
	mov	ax,922		; time constant
	mov	dx,io_addr
	add	dx,TMR0
	out	dx,al		; LSB
	call delay8253		; Satisy access time restriction
	mov	al,ah
	out	dx,al		; MSB
	call delay8253		; Satisy access time restriction

	call	set_recv_isr	; Hook the board int
;if all is okay,
	clc
	ret
etopen_error:
	mov	dx,offset no_memory_msg
	stc
	ret

dma_page_save	dw	0
dma_dest_save	dw	0
dma_wcr_save	dw	0
; Test a buffer to see if it crosses a DMA page boundary.
; Enter with cx:bx = buffer, ax = length
	public test_buffer
test_buffer:
	sub	ax,1	; adjust length for DMA chip
	mov	dma_wcr_save,ax ; Save it for the dma_wcr register
	
; Calculate high order 4 bits of the buffer area and store
; them in the DMA page register
	mov	ax,cx	; Make a working copy of the seg reg
	shl	ax,1
	shl	ax,1
	shl	ax,1
	shl	ax,1
	add	ax,bx	; add offset - we have bottom word of abs. address
	pushf		; Save carry bit
	mov	dma_dest_save,ax ; save this for the dma_dest register

	mov	ax,cx	; Get another copy of the seg reg
	mov	cl,12	; shift it down
	shr	ax,cl	; to get page register
	popf		; Recover carry bit
	adc	ax,0	; add any carry from previous add
	mov	dma_page_save,ax ; Save this for the dma_page register

; Now do the test: add the buffer size to the destination address
; and see if we're still in the same page
	mov	ax,dma_dest_save ; recover bottom 16 bits of absolute addr
	add	ax,cs:bufsiz	; add the buffer size
				; if carry is set, we spilled over the page
	ret			; return carry clear on success

	public	print_parameters
print_parameters:
;echo our command-line parameters
	mov di,	offset int_no		; Interrupt channel
	mov dx,	offset int_no_name	; Message for it
	call	print_number
	mov di,	offset io_addr		; I/O address
	mov dx,	offset io_addr_name	; Message for it
	call	print_number
	mov di,	offset dma_channel	; DMA channel
	mov dx,	offset dma_name		; Message for it
	call	print_number
	mov di, offset speed		; Baud rate
	mov dx,	offset speed_name 
	call	print_number
	mov di, offset txdelayparm	; TX delay
	mov dx,	offset txdelay_name
	call	print_number
	mov di, offset persist		; P persistance 
	mov dx,	offset persist_name
	call	print_number
	mov di, offset slottime		; Slot time
	mov dx,	offset slottime_name
	call	print_number
	mov di, offset tailtime		; Tail time
	mov dx,	offset tailtime_name
	call	print_number
	mov di, offset clkmode		; Clocking mode
	mov dx,	offset clkmode_name
	call	print_number
	mov di, offset bufsiz		; Buffer size
	mov dx,	offset bufsiz_name
	call	print_number
	mov di, offset numbufs		; Number of buffers
	mov dx,	offset numbufs_name
	call	print_number

	ret

code	ends

	end
