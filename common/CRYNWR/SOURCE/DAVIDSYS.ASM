page 58, 132

;DBGINT3		equ	0
;DEBUG		equ	1		; FOR NOW
version		equ	5		; version of this file
s8005_version	equ	1		; SEEQ 8005 stuff (not separate (yet))

;version
; 1     = initially from Mark Dye
; 2     = Fix spin loop bug (cx=0 ->65536), broke on slower systems (6MHz)
; 3     = Fix '-n' bug, fix warnings
; 4     = Fix Compaq DOS bug (we must do STI after set_recv_isr)
;         Also, compile with DBGINT3 commmented out.
;         I thought that 0=false, 1=true, but they were IFDEFfed!
;         Also, Fix section to ignore broadcasts that we initiated
; 5     = Release version (nothing changed)

;s8005_version
;  0    = Initially from MD
;  1    = Fix  8-bit insb bug (broke on 8088 PCs)


; Copyright 1991  DAVID Systems, Inc (Sunnyvale, CA) and Marc S Dye
; (d.b.a. ayuda Company - Camarillo, CA).  Distribution of this code
; including any derivation thereof, shall be made so as to afford the
; recipient of such distribution a copy of this source code, including
; any alterations, at no charge (except for copying, media, and shipping
; costs).  Any distribution of this source or derivations must contain
; this copyright notice.  Documentation describing this work or its
; derivations must acknowledge the copyright holders herein.  The names
; of the copyright holders may not be used to advertise, signify, or
; otherwise characterize any derived work, except for the aforementioned
; copyright acknowledgement.  This work is provided AS IS, with NO
; WARRANTIES expressed or implied, NOR any representations made as to
; its suitability or fitness for any purpose whatsoever.  The recipient
; assumes full responsibility for use of this work.
; Some patches made by:
;   Jeff Douglass

ifdef	DEBUG
private		macro	SYM
		public	SYM
		endm
else
private		macro	SYM
		endm
endif

	include	defs.asm
; Ethernet-2 header length defined
;#
ENET_HDR	equ	2*EADDR_LEN + 4  ;was +2

; assemble a select few instructions (16-bit i/o) from the extended set
; otherwise, must do only 8086-compatible stuff!
		.286p


; Definitions of interface to the SEEQ 8005 EDLC.  See the SEEQ data book
; for complete details of this device.

; 8005 directly-addressable register offsets (from i/o base address)
COMSTAT_R	equ	0		; COMMAND / STATUS
CONFIG1_R	equ	2		; CONFIGURATION 1
CONFIG2_R	equ	4		; CONFIGURATION 2
REA_PTR_R	equ	6		; Receive End Area Pointer
BUFWIN_R	equ	8		; Buffer Window
RX_PTR_R	equ	10		; Receive Pointer
TX_PTR_R	equ	12		; Transmit Pointer
DMA_ADDR_R	equ	14		; DMA Address

; 8005 COMMAND register
DMA_INT_EN	equ	0001h
RX_INT_EN	equ	0002h
TX_INT_EN	equ	0004h
WINDOW_INT_EN	equ	0008h
DMA_INT_ACK	equ	0010h
RX_INT_ACK	equ	0020h
TX_INT_ACK	equ	0040h
WINDOW_INT_ACK	equ	0080h
SET_DMA_ON	equ	0100h
SET_RX_ON	equ	0200h
SET_TX_ON	equ	0400h
SET_DMA_OFF	equ	0800h
SET_RX_OFF	equ	1000h
SET_TX_OFF	equ	2000h
FIFO_READ	equ	4000h
FIFO_WRITE	equ	8000h

; 8005 STATUS register
DMA_INT		equ	0010h
RX_INT		equ	0020h
TX_INT		equ	0040h
WINDOW_INT	equ	0080h
DMA_ON		equ	0100h
RX_ON		equ	0200h
TX_ON		equ	0400h
FIFO_FULL	equ	2000h
FIFO_EMPTY	equ	4000h
FIFO_DIR	equ	8000h

; 8005 CONFIGURATION 1 register
MATCH_BITS_M	equ	0C000h
MATCH_ONLY	equ	0000h
MATCH_BROAD	equ	4000h
MATCH_MULTI	equ	8000h
MATCH_ALL	equ	0C000h
ALL_STATIONS	equ	3F00h
STATION_0_EN	equ	0100h
STATION_1_EN	equ	0200h
STATION_2_EN	equ	0400h
STATION_3_EN	equ	0800h
STATION_4_EN	equ	1000h
STATION_5_EN	equ	2000h
DMA_LENGTH_M	equ	00C0h
NBYTES_1	equ	0000h
NBYTES_2	equ	0040h
NBYTES_4	equ	0080h
NBYTES_8	equ	00C0h
DMA_INTERVAL_M	equ	0030h
CONTINUOUS	equ	0000h
DELAY_800	equ	0010h
DELAY_1600	equ	0020h
DELAY_3200	equ	0030h
BUFFER_CODE_M	equ	000Fh
STATION_0_SEL	equ	0000h
STATION_1_SEL	equ	0001h
STATION_2_SEL	equ	0002h
STATION_3_SEL	equ	0003h
STATION_4_SEL	equ	0004h
STATION_5_SEL	equ	0005h
PROM_SEL	equ	0006h
TEA_SEL		equ	0007h
BUFFER_MEM_SEL	equ	0008h
INT_VECTOR_SEL	equ	0009h
; Ether-T PC/AT device configuration register -- access is overloaded onto
; the set of registers accessible via the reserved range in CONFIGURATION 1
CARD_CONFIG_SEL	equ	000Fh
SET_16BITMODE_M	equ	0080h		; OR mask for 16 bit mode

; 8005 CONFIGURATION 2 register
BYTE_SWAP	equ	0001h
AUTO_UPDATE_REA	equ	0002h
CRC_ERR_EN	equ	0008h
DRIBBLE_EN	equ	0010h
SHORT_FRAME_EN	equ	0020h
SLOT_TIME_SEL	equ	0040h
XMIT_NO_PREAM	equ	0080h
ADDR_LENGTH	equ	0100h
RECEIVE_CRC	equ	0200h
XMIT_NO_CRC	equ	0400h
LOOPBACK_EN	equ	0800h
KILL_WATCHDOG	equ	1000h
RESET		equ	8000h

; 8005 TRANSMIT HEADER COMMAND BYTE  (byte 3 of transmit packet header)
BABBLE_INT_EN	equ	01h
COLL_INT_EN	equ	02h
COLL_16_INT_EN	equ	04h
XMIT_OK_INT_EN	equ	08h
DATA_FOLLOWS	equ	20h		; also in RECEIVE HEADER COMMAND BYTE
CHAIN_CONTINUE	equ	40h		; also in RECEIVE HEADER COMMAND BYTE
PACKET_PRESENT	equ	80h
TX_HEADER_Z	equ	4		; # of bytes in a TX header

; 8005 TRANSMIT HEADER STATUS BYTE  (byte 4 of transmit packet header)
BABBLE_ERR	equ	01h
COLL		equ	02h
COLL_16_ERR	equ	04h
HDR_DONE	equ	80h

; 8005 RECEIVE HEADER COMMAND BYTE (byte 3 of receive packet header)
;DATA_FOLLOWS		20h		from TRANSMIT HEADER COMMAND BYTE
;CHAIN_CONTINUE		40h		from TRANSMIT HEADER COMMAND BYTE

; 8005 RECEIVE HEADER STATUS BYTE (byte 4 of receive packet header)
OVERSIZE	equ	01h
CRC_ERR		equ	02h
DRIBBLE_ERR	equ	04h
SHORT_FRAME	equ	08h

; 8005 Receive Area Base Pointer
RCV_PTR		equ	((4 + GIANT + 4 + 255) AND NOT 0FFh)
; 8005 Transmit End Area Pointer (upper 8-bits)
TEA_INIT	equ	(((RCV_PTR - 1) / 256) AND 0FFh)

; macro to provide a delay after dinking w/ 8005 registers
io_delay	macro	CNTVAR
		local	io_delay_loop, skip_delay
		push	cx
		mov	cx, CNTVAR
                jcxz    skip_delay
io_delay_loop:	nop
		loop	io_delay_loop
skip_delay:	pop	cx
		endm

; macros to get and set the various device registers
; these assume that a proper 'loadport' context exists, that input/output
; register values are in AX (for word i/o) or AL (for byte i/o)
get_r		macro	R
		setport	R
		call	inb_8005
		endm

getw_r		macro	R
		setport	R
		call	[inw_fn]
		endm

set_r		macro	R
		setport	R
		call	outb_8005
		endm

setw_r		macro	R
		setport	R
		call	[outw_fn]
		endm

; wait for the 8005 FIFO to be free
fifo_wait	macro
		local	fifo_wait_loop
		setport	COMSTAT_R	; fix access within the loop
fifo_wait_loop:	getw_r	COMSTAT_R	; wait for the FIFO to be free to use
		and	ax, FIFO_EMPTY+FIFO_DIR
		cmp	ax, FIFO_EMPTY
		jne	fifo_wait_loop	; loop
		endm


CODE	segment	byte public
	assume	cs:CODE, ds:CODE

	public	INT_NO, IO_ADDR
INT_NO		db	3, 0, 0, 0	; interrupt number
IO_ADDR		dw	300h, 0		; (factory) i/o port address

	public	DRIVER_CLASS, DRIVER_TYPE, DRIVER_NAME, DRIVER_FUNCTION
	public	PARAMETER_LIST, INT_NUM
DRIVER_CLASS	db	BLUEBOOK, IEEE8023, 0
DRIVER_TYPE	db	70		; Ether-T PC/AT, specifically
DRIVER_NAME	db	"Ether-T PC/AT", 0  ; name of the driver
DRIVER_FUNCTION	db	2		; standard plus extensions (except
					;  specific multicast)
PARAMETER_LIST	label	byte
		db	1		; major rev of packet driver spec
		db	9		; minor rev of packet driver spec
		db	14		; length of parameter list
		db	EADDR_LEN	; length of MAC-layer address
		dw	GIANT		; MTU, including headers
		dw	MAX_MULTICAST * EADDR_LEN
					; buffer size of multicast addresses
		dw	0		; (# of back-to-back MTU recvs) - 1
		dw	0		; (# of successive xmits) - 1
INT_NUM		dw	0		; interrupt # to hook for post-EOI
					;  processing, 0 == none

	public	RCV_MODES
; Receive mode set-up dispatch table.  Refers to actual code frags below that 
; do the job.
RCV_MODES	dw	7		; number of receive modes in our table
		dw	0		; none exists
		dw	rcv_mode_1	; receiver off
		dw	rcv_mode_2	; only packets for this station
		dw	rcv_mode_3	; mode 2 plus broadcast
		dw	0		; mode 3 plus limited multicast
		dw	rcv_mode_5	; mode 3 plus all multicast
		dw	rcv_mode_6	; all packets

; per-device instance structures -- keep state of the device -- ones marked
; as (copy) are soft copies of things actually on the device
	private	command_r
command_r	dw	0		; COMMAND (copy, sort of)
	private	config1_r_copy
config1_r_copy	dw	0		; CONFIGURATION 1 (copy)
	private	config2_r_copy
config2_r_copy	dw	0		; CONFIGURATION 2 (copy)
	private	cardconfig_r
cardconfig_r	db	0		; CARD CONFIGURATION (copy)
	private	rcv_errors
rcv_errors	db	0		; want to receive even flawed packets
	private	rcv_ptr_copy
rcv_ptr_copy		dw	0		; current (next) received packet ptr
	private	transmit
transmit	db	0		; currently transmitting
		db	?
station_0       db      6 dup(0)        ;current address (for disallowing
                                        ; broadcast packets)(JLD)(9-25-91)

; i/o instruction processing variables
	private	delay_mult
delay_mult	dw	10, 0		; delay multiplier / divisor - is
					; a tens fraction: delay becomes
					; (calibrated_delay * delay_mult) / 10
	private	io_16
io_16		db	0		; do 16-bit i/o?
		db	?
	private	io_delay_cnt
io_delay_cnt	dw	1, 0		; # of NOP spins to do to effect the
					; required delay (2000 ns) for the
					; worst-case i/o access
	private	iowm_delay_cnt
iowm_delay_cnt	dw	1, 0		; # of NOP spins to effect the required
					; delay (800 ns) for a write to the
					; buffer memory in the window register
	private	inw_fn
inw_fn		dw	OFFSET inwb_8005  ; function to input a word (w/ delay)
	private	outw_fn
outw_fn		dw	OFFSET outwb_8005 ; function to output a word (w/ delay)

; interrupt processing variables
	private	int_test
int_test	db	0		; in the initial interrupt testing?
	private	int_tested
int_tested	db	0		; was initial interrupt test successful?

ifdef	DEBUG
	public	ghost_int_c, send_wait_c
ghost_int_c	dw	0		; ghost (empty) interrupt counter
rx_restart	dw	0		; stalled receiver restart counter
send_wait_c	dw	0		; previous send completion wait counter
endif

	extrn	THEIR_ISR : dword

	extrn	COUNT_IN_ERR : near
	extrn	COUNT_OUT_ERR : near
	extrn	GET_NUMBER : near
	extrn	MASKINT : near
	extrn	PRINT_NUMBER : near
	extrn	RECV_COPY : near
	extrn	RECV_FIND : near
	extrn	SET_RECV_ISR : near
	extrn	UNMASKINT : near


	public bad_command_intercept
bad_command_intercept:
;called with ah=command, unknown to the skeleton.
;exit with nc if okay, cy, dh=error if not.
	mov	dh,BAD_COMMAND
	stc
	ret

	public	AS_SEND_PKT
; Asynchronous packet transmit routine (high-performance drivers only).
; Entry with:
;	ES:DI	control block pointer
;	DS:SI	packet to send
;	CX	packet length
; Interrupts *may* be enabled.  Returns:
;	ES:DI	preserved from call (control block pointer)
;	   and
;	NC	if OK
;	   or
;	CY	if transmission error
;	DH	error code
; Interrupt disablement on entry is preserved on exit.
AS_SEND_PKT:
		assume	ds:nothing
		ret


	public	DROP_PKT
; Drop a packet from the queue (high-performance drivers only.)
DROP_PKT:
		assume	ds:nothing
		ret


	private	inb_8005
; input a byte from an arbitrary 8005 port
inb_8005:
		assume	ds:nothing
		in	al, dx
		io_delay  io_delay_cnt	; generic delay
		ret


	private	inwb_8005
; input a word from an arbitrary 8005 port -- 8 bit version
inwb_8005:
		assume	ds:nothing
		in	al, dx
		io_delay  io_delay_cnt	; generic delay
		inc	dx
		xchg	al, ah
		in	al, dx
		xchg	al, ah
		io_delay  io_delay_cnt	; generic delay
		dec	dx		; to keep 'setport' in synch
		ret


	private	inw_8005
; input a word from an arbitrary 8005 port -- 16 bit version
inw_8005:
		assume	ds:nothing
		in	ax, dx
		io_delay  io_delay_cnt	; generic delay
		ret


	private	outb_8005
; output a byte to an arbitrary 8005 port
outb_8005:
		assume	ds:nothing
		out	dx, al
		io_delay  io_delay_cnt	; generic delay
		ret


	private	outwb_8005
; output a word to an arbitrary 8005 port -- 8 bit version
outwb_8005:
		assume	ds:nothing
		out	dx, al
		io_delay  io_delay_cnt	; generic delay
		inc	dx
		xchg	al, ah
		out	dx, al
		xchg	al, ah
		io_delay  io_delay_cnt	; generic delay
		dec	dx		; to keep 'setport' in synch
		ret


	private	outw_8005
; output a word to an arbitrary 8005 port -- 16 bit version
outw_8005:
		assume	ds:nothing
		out	dx, ax
		io_delay  io_delay_cnt	; generic delay
		ret


	private	rcv_mode_1
	private	rcv_mode_2
	private	rcv_mode_3
	private	rcv_mode_5
	private	rcv_mode_6
; Receive mode set-up routines.  Dispatched to out of the RCV_MODES
; switch (above) or called directly by ETOPEN (once).
		assume	ds:CODE
rcv_mode_1:	; turn off receiver
		call	turn_rx_off
		ret
rcv_mode_2:	; only packets to this station address
		mov	ax, MATCH_ONLY	; config 1
		mov	dx, 0		; config 2
		jmp	SHORT rcv_mode_common
rcv_mode_3:	; mode 2 plus broadcast packets
		mov	ax, MATCH_BROAD	; config 1
		mov	dx, CRC_ERR_EN+DRIBBLE_EN+SHORT_FRAME_EN ; config 2
		jmp	SHORT rcv_mode_common
rcv_mode_5:	; mode 3 plus all multicast packets
		mov	ax, MATCH_MULTI	; config 1
		mov	dx, CRC_ERR_EN+DRIBBLE_EN+SHORT_FRAME_EN ; config 2
		jmp	SHORT rcv_mode_common
rcv_mode_6:	; all packets (promiscuous, including errors)
		mov	ax, MATCH_ALL	; config 1
		mov	dx, CRC_ERR_EN+DRIBBLE_EN+SHORT_FRAME_EN ; config 2
rcv_mode_common:
		push	dx		; save the changes while we
		push	ax		;   wang on the receiver
		call	turn_rx_off		; shut down whilst we play
		loadport
		pop	bx		; alter the CONFIGURATION 1 register
		mov	ax, config1_r_copy
		and	ax, NOT MATCH_BITS_M
		or	ax, bx
		mov	rcv_errors, 0
		cmp	bx, MATCH_ALL	; figure if we want to see errors
		jne	rcv_mode_common_1
		mov	rcv_errors, 1
rcv_mode_common_1:
		mov	config1_r_copy, ax
		setw_r	CONFIG1_R
		pop	bx		; alter the CONFIGURATION 2 register
		mov	ax, config2_r_copy
		and	ax, NOT (CRC_ERR_EN+DRIBBLE_EN+SHORT_FRAME_EN)
		or	ax, bx
		mov	config2_r_copy, ax
		setw_r	CONFIG2_R
		call	turn_rx_on		; drop trou now, brown cow
		ret


	private	turn_rcv_on
; turn the receiver back on, as per the COMMAND register atop the stack
; removes the COMMAND register upon return
rcv_on:
		assume	ds:CODE
		mov	bx, sp		; get former COMMAND register
		mov	ax, ss:[bx+2]
		test	ax, SET_RX_OFF	; see if it's to go back on
		jnz	rcv_on_1
		mov	command_r, ax	; restore it
		call	turn_rx_on
rcv_on_1:	ret	2		; clear stack of COMMAND register too


	private	rcvxmt_off
; forcibly turn off the receiver and/or transmitter -- if the transmitter
; is running, this will abort the transmission
; leaves the prior COMMAND register on top of the stack (for use by a
; matching 'rcv_on' call)
rcvxmt_off:
		assume	ds:CODE
		pop	bx		; return address
		push	command_r	; left for 'rcv_on'
		or	command_r, SET_TX_OFF
		mov	transmit, 0	; not doing it now
		call	turn_rx_off
		jmp	bx		; return


	public	RECV
; Part one of the ISR receive packet processing.  Called before interrupt
; acknowledgement.  All registers have been saved, DS == CS, and we're
; running on a private stack with interrupts disabled.
RECV:
		assume	ds:CODE
ifdef	DBGINT3
		int	03h		; Danger, Will Robinson!
endif
		loadport
		; check for and acknowledge the 8005 receive Interrupt
ifdef	DEBUG
		getw_r	COMSTAT_R
		test	ax, RX_INT
		jnz	recv_1
		inc	ghost_int_c	; ghost interrupt counter
recv_1:
endif
		mov	ax, command_r	; acknowledge the Rx Interrupt
		or	ax, RX_INT_ACK
		setw_r	COMSTAT_R
		cmp	int_test, 0	; is this interrupt a test one?
		je	recv_setup
		inc	int_tested	; indicated tested and be done
		ret

recv_setup:	; set-up DMA access of the buffer read memory
		mov	ax, config1_r_copy	; select BUFFER MEMORY in BUFWIN
		or	ax, BUFFER_MEM_SEL
		setw_r	CONFIG1_R

		setport	DMA_ADDR_R	; code block port state synch
; COME HERE w/ port @ DMA_ADDR_R
recv_rcvptr:	mov	ax, rcv_ptr_copy	; address the next RECEIVE HEADER
		setw_r	DMA_ADDR_R
		mov	ax, command_r	; set the FIFO to READ now
		or	ax, FIFO_READ
		setw_r	COMSTAT_R

		setport	BUFWIN_R	; code block port state synch
; COME HERE w/ port @ BUFWIN_R
recv_loop:	; check for an end-of-list header (0 next pointer)
		getw_r	BUFWIN_R	; get the HEADER pointer
		cmp	al, 0		; check for end of receive list
		je	recv_loop_1	;  looking only at first byte
		xchg	al, ah		; swap to proper host order
		mov	cx, ax		; save pointer away
		getw_r	BUFWIN_R	; get the HEADER & PACKET STATI
		test	al, CHAIN_CONTINUE  ; test for completion
		xchg	al, ah		; AL now holds PACKET STATUS byte
		jnz	recv_continue
recv_loop_1:	jmp	recv_done

recv_continue:	; process a new frame - compute length and check it
		push	cx		; squirrel away HEADER POINTER
		sub	cx, rcv_ptr_copy	; compute length, checking for wrappage
		jae	recv_continue_1
		sub	cx, RCV_PTR	; adjust for wrap, sans xmit area
recv_continue_1:
		sub	cx, 4		; less size of 8005 garf
		cmp	cx, ENET_HDR	; < a header is tallied and pitched
		jb	recv_continue_2
		cmp	cx, GIANT	; > GIANT likewise
		ja	recv_continue_2
		test	al, SHORT_FRAME+DRIBBLE_ERR+CRC_ERR
		jz	recv_alloc	; no error is a-OK
		cmp	rcv_errors, 0	; see if we have to allow bad ones
		jne	recv_alloc	; yes, keep this dreck too
recv_continue_2:
		call	COUNT_IN_ERR	; tally this error
		jmp	recv_sail_it

recv_alloc:	; this one we want - allocate enough space on the stack
		;  to hold the Ethernet-2 packet header (so we can upcall
		;  pointing at the type field)
		mov	bx, cx		; save the real length
		mov	cx, ENET_HDR
		sub	sp, cx		; allocate a header on the stack
		mov	di, sp		;   and point at it w/ DI
		mov	ax, ss		; set-up ES too
		mov	es, ax
		cmp	io_16, 0	; do we do it fast or slow?
		je	recv_8bit_hdr
		sar	cx, 1		; turn into words
;	rep	insw
recv_16bit_hdr:
		insw			; 16-bit input	
		io_delay iowm_delay_cnt	; reduced delay w/i loop
		loop	recv_16bit_hdr
		jmp	SHORT recv_upcall1
recv_8bit_hdr:				; 8-bit input
		in	al, dx
		mov	es:[di], al
		inc	di
		loop	recv_8bit_hdr

recv_upcall1:
;#              ; check to make sure this isn't our own broadcast(JLD)(9-25-91)
                push    di
	    	mov	di, sp		; point at the destination
                add     di, 2           ; which is 2 bytes away(remember push di?)
                mov     ax, 0ffffh
                mov     cx, 6/2
            repe scasw
                jne     NotBroadcast
            
                push    si
                mov     si, offset station_0
                mov     cx, 6/2
            repe cmps   word ptr cs:[si], word ptr es:[di]
                pop     si
            
                jne     NotBroadcast

                pop     di
		add	sp, ENET_HDR	; pop the Ethernet-2 header from stack
                                        ; I forgot this until it bit me (11-6)
                jmp     recv_sail_it    ; if it's us, bail out!
NotBroadcast:
                pop     di


                ; prepare an upcall with CX == length, ES:DI pointing at type,
		;  DL == packet class number (V8)
		mov	di, sp		; point at the type field
		add	di, EADDR_LEN*2
		mov	cx, bx		; get the real length for RECV_FIND
		push	bx		; save the real length
		push	dx		;  and save our precious port setup too
;#
	mov	dl, BLUEBOOK		;assume bluebook Ethernet.
	mov	ax, es:[di]
	xchg	ah, al
	cmp 	ax, 1500
	ja	BlueBookPacket
	inc	di			;set di to 802.2 header
	inc	di
	mov	dl, IEEE8023
BlueBookPacket:
;;;;		mov	dl, BLUEBOOK	; Ethernet-2 'Bluebook' (V8)
		call	RECV_FIND

		pop	dx		; get back port setup
		pop	bx		;  and true packet length
		mov	ax, es		; see if the client passed on this one
		or	ax, di
		jz	recv_sail_pop

		mov	si, sp		; prepare to MOVS the Ethernet-2 header
		mov	ax, ss
		mov	ds, ax
		assume	ds:nothing
		mov	cx, ENET_HDR
		push	di		; save client packet base pointer
	rep	movsb
		pop	si		; restore client packet base pointer
		add	sp, ENET_HDR	; pop the Ethernet-2 header from stack

		mov	cx, bx		; compute residual length to bring in
		sub	cx, ENET_HDR
		cmp	io_16, 0	; do we do it fast or slow?
		je	recv_8bit_data

		sar	cx, 1		; /2: compute # of words to transfer
;	rep	insw			; loosely termed "full-bandwidth i/o"
recv_16bit_data:
		insw
		io_delay iowm_delay_cnt	; reduced delay w/i loop
		loop	recv_16bit_data

		mov	cx, bx		; get length back one more time
		test	bl, 1		; see if there's a dangling byte
		jz	recv_upcall2
		mov	cx, 1		; set-up to fall through to 8-bit

recv_8bit_data:	in	al, dx
		mov	es:[di], al
		inc	di
		loop	recv_8bit_data
		mov	cx, bx		; get length back one more time
		xor	bl, bl		; for sail testing after upcall2

recv_upcall2:	; prepare an upcall with CX == length, DS:SI pointing at
		;  client-allocated and now filled packet
		mov	ax, es
		mov	ds, ax
		push	dx		; save our precious port setup

		call	RECV_COPY

		pop	dx		; get back port setup
		mov	ax, cs		;  and set DS back to CODE
		mov	ds, ax
		assume	ds:CODE

		; have to check if 16-bit i/o processed an odd-length packet
		;  - if so, we MAY have blown the harmony of the 8005 DMA
		;  (may now be off by one) so just sail it
		test	bl, 1
		jnz	recv_sail_it

		pop	cx		; pop squirreled next HEADER POINTER
		mov	rcv_ptr_copy, cx	;  and make that the new pointer
		mov	al, ch		; update the REA PTR register, making
		set_r	REA_PTR_R	;  room for more inbound packets
		setport	BUFWIN_R
		jmp	recv_loop

recv_sail_pop:	add	sp, ENET_HDR	; pop the Ethernet-2 header from stack

recv_sail_it:	; rid ourselves of this frame the hard way: by resetting the
		;   DMA, in addition to our own bookkeeping stuff
		loadport
		mov	ax, command_r	; release the DMA FIFO
		or	ax, FIFO_WRITE+DMA_INT_ACK
		setw_r	COMSTAT_R
		pop	cx		; pop squirreled next HEADER POINTER
		mov	rcv_ptr_copy, cx	;  and make that the new pointer
		mov	al, ch		; update the REA PTR register, making
		set_r	REA_PTR_R	;  room for more inbound packets
		setport	DMA_ADDR_R
		jmp	recv_rcvptr

recv_done:	; all inbound frames processed
		loadport
		mov	ax, command_r	; release the DMA FIFO
		or	ax, FIFO_WRITE+DMA_INT_ACK
		setw_r	COMSTAT_R
		; restart a stalled receiver
		getw_r	COMSTAT_R	; grab the STATUS register
		test	ax, RX_ON	; receiver still on?
		jnz	recv_done_1
ifdef	DEBUG
		inc	rx_restart
endif
		call	turn_rx_on
recv_done_1:
		ret


	public	RECV_EXITING
; Part two of the ISR receive packet processing.  Called after interrupts
; have been acknowledged.  Only DS and AX have been saved, DS == CS and
; we're running on the original stack (i.e. not the private one).  On
; entry, interrupts are still disabled but it is possible to intelligently
; turn them back on.
RECV_EXITING:
		assume	ds:CODE
		ret


	public	RESET_INTERFACE
; Reset the interface.
RESET_INTERFACE:
		assume	ds:CODE
		loadport
		mov	ax, RESET
		setw_r	CONFIG2_R
		; wait a good, long while
		mov	ax, 1
		call	set_timeout
RESET_INTERFACE_1:
		call	do_timeout
		jnz	RESET_INTERFACE_1
;;;;		; delay another 4 microseconds
;;;;		io_delay  io_delay_cnt	; generic delay
;;;;		io_delay  io_delay_cnt	; generic delay
		ret


	private	turn_rx_off
; Turn off the receiver portion of the device.  Undoes 'turn_rx_on'.
turn_rx_off:
		assume	ds:CODE
		loadport
		mov	ax, command_r
		and	ax, NOT RX_INT_EN
		or	ax, SET_RX_OFF
		mov	command_r, ax
		setw_r	COMSTAT_R
		ret


	private	turn_rx_on
; Turn on the receiver portion of the device.  Assumes the station address
; has already been programmed, receive ISR registered, etc.  Just brings it
; all to life on the wire.  Undone by 'turn_rx_off'.
turn_rx_on:
		assume	ds:CODE
		loadport
		; load up Receive End Area Pointer
		mov	al, TEA_INIT + 1
		set_r	REA_PTR_R
		; load up the Receive Pointer Register
		mov	ax, RCV_PTR
		setw_r	RX_PTR_R
		mov	rcv_ptr_copy, ax
		; now turn it on
		mov	ax, command_r
		and	ax, NOT SET_RX_OFF
		or	ax, RX_INT_EN
		mov	command_r, ax
		or	ax, SET_RX_ON
		setw_r	COMSTAT_R
		ret


	public	SEND_PKT
; Send one packet.  Entry with:
;	DS:SI	packet buffer to xmit
;	CX	packet length
; 	ES:DI	upcall routine (0:0 if no upcall is desired) -- only supported
;		if the high-performance bit is set in 'driver_function' byte
; Returns:
;	NC	if OK
;	   or
;	CY	if transmission error
;	DH	error code
SEND_PKT:
		assume	ds:nothing
ifdef	DBGINT3
		int	03h		; Danger, Will Robinson!
endif
		mov	ax, ds		; restore DS usage right here, saving
		mov	es, ax		;   it in ES (as we don't do upcalls)
		mov	ax, cs
		mov	ds, ax
		assume 	ds:CODE
		cmp	cx, ENET_HDR	; firewall against trivia
		jae	SEND_PKT_1
		jmp	send_pkt_ret
SEND_PKT_1:
		cmp	cx, GIANT	; see if too big
		jbe	SEND_PKT_2
		jmp	send_pkt_NOSPACE
SEND_PKT_2:
		cmp	cx, RUNT	; see if too small
		jae	SEND_PKT_3	; ... sounds like the Three Bears
		mov	cx, RUNT	; transmit at least this much
SEND_PKT_3:
		; mask receiver interrupts (note the receiver is still
		;   running however) -- this also arbitrates use of the FIFO
		push	cx		; push stuff so MASKINT won't bite us
		mov	al, INT_NO
		call	MASKINT

		loadport
		mov	ax, config1_r_copy	; select BUFFER MEMORY in BUFWIN
		or	ax, BUFFER_MEM_SEL
		setw_r	CONFIG1_R

		; check status of the previous transmission
		cmp	transmit, 0	; see if a transmit is incomplete
		je	send_pkt_load
send_pkt_wait:
		loadport		; synch for the loop
		mov	ax, 3		; address the TRANSMIT STATUS byte
		setw_r	DMA_ADDR_R
		mov	ax, command_r	; set the FIFO to READ now, also
		or	ax, FIFO_READ+TX_INT_ACK  ; ACKs any TX int bit
		setw_r	COMSTAT_R
		get_r	BUFWIN_R	; get the STATUS byte
		mov	bl, al		; save the gotten STATUS byte
		mov	ax, command_r	; set the FIFO back to WRITE (aborts,
		or	ax, FIFO_WRITE+DMA_INT_ACK  ; drains, ACKs FIFO int bit)
		setw_r	COMSTAT_R
		test	bl, HDR_DONE	; check for transmit done
ifdef	DEBUG
		jnz	send_pkt_wait_1
		inc	send_wait_c	; count send completion waits
		jmp	send_pkt_wait	; loop
send_pkt_wait_1:
else
		jz	send_pkt_wait	; loop
endif
		; done -- check for transmit error & count if so
		test	bl, BABBLE_ERR+COLL_16_ERR
		jz	send_pkt_load
		call	COUNT_OUT_ERR	; count the error

send_pkt_load:	; load the new packet into the transmit area
		pop	cx		; revive stuff pushed for MASKINT
		; load up the transmit buffer -- allows only a single
		;   transmit (doesn't chain 'em); however, this transmission
		;   is overlapped with the preparation of the next
		loadport		; synch the state
		xor	ax, ax		; TRANSMIT NEXT HEADER word
		setw_r	DMA_ADDR_R
		mov	ax, cx		; calculate xmit request length
		add	ax, 4		;   including 8005 garf
		xchg	ah, al		; SWAP
		setw_r	BUFWIN_R
		mov	al, PACKET_PRESENT+DATA_FOLLOWS ; TRANSMIT COMMAND byte
		xor	ah, ah		; TRANSMIT STATUS byte
		setw_r	BUFWIN_R	; both in one SWAPPED swoop

		; semi-quick programmed output here -- direct use of macros
		mov	ax, es		; go back to DS-relative packet data
		mov	ds, ax
		assume	ds:nothing
		cmp	io_16, 0	; can do 16-bit i/o?
		je	send_pkt_8bit
		test	cx, 1		; odd length?
		jz	send_pkt_load_1
		inc	cx		; make even for 16-bit mode output
send_pkt_load_1:
		sar	cx, 1		; /2: compute # of words to transfer
		cmp	iowm_delay_cnt, 0  ; check for full-tilt boogie
		jne	send_pkt_load_2	; nope, need delays
		rep	outsw		; blow-out clearance i/o
		jmp	SHORT send_pkt_xmt
send_pkt_load_2:
		mov	ax, [si]	; Note: DS-relative packet here
		out	dx, ax
		io_delay iowm_delay_cnt	; reduced delay w/i loop
		inc	si
		inc	si
		loop	send_pkt_load_2
		jmp	SHORT send_pkt_xmt	; done w/ buffer load

send_pkt_8bit:	; 8 bit packet load
		cmp	iowm_delay_cnt, 0  ; check for full-tilt boogie
		jne	UpHere_1	; nope, need delays

;the following replaces rep outsb, which doesn't work too well on 8088-based PCs
;;	rep	outsb			; blow-out clearance i/o

UpHere:		lodsb			; Note: DS-relative packet here
		out	dx, al
                loop    UpHere

		jmp	SHORT send_pkt_xmt
UpHere_1:
		mov	al, [si]	; Note: DS-relative packet here
		out	dx, al
		io_delay iowm_delay_cnt	; reduced delay w/i loop
		inc	si
		loop	UpHere_1

send_pkt_xmt:	; packet now loaded, finish up and transmit it
		mov	ax, cs		; restore our DS
		mov	ds, ax
		assume	ds:CODE
		; set TRANSMIT POINTER (overlap as FIFO drains)
		xor	ax, ax		; start chain at address 0
		setw_r	TX_PTR_R
		; wait for DMA FIFO to drain
		fifo_wait
		; now transmit it
		mov	ax, command_r	; remove default transmitter off cmd
		and	ax, NOT SET_TX_OFF
		mov	command_r, ax
		or	ax, SET_TX_ON
		setw_r	COMSTAT_R	; Send!
		mov	transmit, 1	; note to check completion next time
		; unmask receiver interrupts, releasing FIFO
		mov	al, INT_NO
		call	UNMASKINT
send_pkt_ret:
		clc			; OK
		ret

send_pkt_NOSPACE:
		mov	dh, NO_SPACE
		stc			; error
		ret


	public	SET_ADDRESS
; Set the MAC station receiver address.  Entry with:
;	DS:SI	the new MAC address to adopt
;	CX	length of address at DS:SI
; Returns:
;	DS	restored to point at CODE segment
;	   plus
;	NC	if OK
;	   or
;	CY	if error
;	DH	error code
SET_ADDRESS:
		assume	ds:nothing
		mov	ax, ds		; undo the twisted DS usage
		mov	es, ax		;   back to addressing our memory
		mov	ax, cs
		mov	ds, ax
		 assume	ds:CODE
		cmp	cx, EADDR_LEN	; check for proper address length
		jne	set_addr_BADADDRESS
		test	BYTE PTR es:[si], 1  ; deny broadcast or multicast
		jnz	set_addr_BADADDRESS

;#		; set the new station address (JLD)(9-25-91)
                mov     ax, ds:[si][0]
                mov     word ptr ds:station_0[0], ax

                mov     ax, ds:[si][2]
                mov     word ptr ds:station_0[2], ax

                mov     ax, ds:[si][4]
                mov     word ptr ds:station_0[4], ax

		; disable receiver and/or transmitter
		call	rcvxmt_off	; leaves COMMAND register on stack

		; set the new station address
		loadport
		mov	ax, config1_r_copy	; select STATION address reg 0
		or	ax, STATION_0_SEL
		setw_r	CONFIG1_R
		xor	ax, ax
		setw_r	DMA_ADDR_R
		setport	BUFWIN_R	; fix access within the loop
SET_ADDRESS_1:
		mov	al, es:[si]	; output bytes of the new address
		inc	si
		set_r	BUFWIN_R
		loop	SET_ADDRESS_1

		; reenable the receiver if it was on before
		call	rcv_on		; removes COMMAND register from stack

		clc			; OK
		ret

set_addr_BADADDRESS:
		mov	dh, BAD_ADDRESS	; improper address
		stc			; error
		ret


	public	set_multicast_list
set_multicast_list:
;enter with ds:si ->list of multicast addresses, ax = number of addresses,
;  cx = number of bytes.
		assume	ds:CODE
		jmp	SHORT set_multicast_err	; FOR NOW: no multicast support
		clc			; OK
		ret
set_multicast_err:
		mov	dh, NO_MULTICAST
		stc			; error
		ret


	public	TERMINATE
; Terminate the packet driver.  Nothing special to do.
TERMINATE:
		assume	ds:CODE
		ret

	public	XMIT
; Routine to process a queued transmission with the least possible latency.
; Called immediately within the receive ISR.  The attempt here is to effect
; back-to-back transmissions.  This routine may only use AX and DX freely
; and is running whatever stack exists at interrupt time (not the private
; one).  This routine isn't necessary on the 8005, because it can chain
; transmissions (if anyone really cared).
XMIT:
		assume	ds:nothing
		ret


	include	popf.asm
	include timeout.asm


; Everything above this line is resident upon successful load.

	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret

;any code after this will not be kept.  Buffers used by the program, if any,
;are allocated from the memory between end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
end_free_mem	label	byte

; Everything below this line is discarded upon installation.

	public	USAGE_MSG
USAGE_MSG	db	"usage: davidsys [options] <packet_int_no> <hardware_irq> <io_addr> <delay_mult>",CR,LF,'$'

	public	COPYRIGHT_MSG
COPYRIGHT_MSG	db	"Packet driver for the Ether-T PC/AT ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,".",'0'+s8005_version,CR,LF
		db	"Portions Copyright 1991 DAVID Systems, Inc and Marc S Dye",CR,LF,'$'

badint_msg	db	"Specified device interrupt not supported for"
		db	" your installation",CR,LF,'$'
int8_msg	db	" Try: 2, 3, 4, 5, 6, or 7",CR,LF,'$'
int16_msg	db	" Try: 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, or 15"
		db	  CR,LF,'$'
inttimedout_msg	db	"Timed out awaiting device test interrupt",CR,LF,'$'
nodev_msg	db	"No device found at specified i/o address",CR,LF,'$'
setaddr_msg	db	"Unable to set initial station address",CR,LF,'$'

delay_mult_name	db	"Delay multipler (x10) ",'$'
int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'

ifdef	DEBUG
count_del_name	db	"Incremental i/o delay spin (nsec x10) ",'$'
delay_del_name	db	"Basic i/o delay (nsec x100) ",'$'
io_delay_name	db	"I/O delay (spins) ",'$'
iowm_delay_name	db	"I/O write memory delay (spins) ",'$'
null_bias_name	db	"Null (overhead) cost (nsec x100) ",'$'
null_spin_name	db	"Null spin count ",'$'
ref_spin_name	db	"Reference spin count ",'$'
unit_spin_name	db	"Single spin count ",'$'
endif

;-> the assigned Ethernet address of the card.
	extrn	rom_address: byte

	private	int_map
; Interrupt number to Ether-T PC/AT configuration register code mapping table
		;	 0    1    2    3    4    5    6    7
int_map		db	00h, 00h, 02h, 01h, 03h, 04h, 05h, 06h
		;	 8    9   10   11   12   13   14   15
		db	00h, 02h, 07h, 08h, 09h, 00h, 0Ah, 0Bh

REF_DELAY	equ	64

	private	count_delay
count_delay	dw	?, 0		; # of 10 nsecs in each io_delay spin
	private	delay_delay
delay_delay	dw	?, 0		; # of 100 nsecs in the basic io_delay
	private	null_bias
null_bias	dw	?, 0		; # of 100 nsecs in a null spin
	private	null_spins
null_spins	dw	?, 0		; # of spins for without io_delay macro
	private	ref_spins
ref_spins	dw	?, 0		; # of spins for io_delay of 1+REF_DELAY
	private	test_delay
test_delay	dw	?		; holding tank for current sample count
	private	unit_spins
unit_spins	dw	?, 0		; # of spins for io_delay of 1


; macro to sample timer zero's counter register
timer0_sample	macro
		xor	al, al		; latch timer zero counter 
		out	43h, al
		in	al, 40h		; sample timer zero counter
		mov	ah, al
		in	al, 40h
		xchg	ah, al
		endm


	private	calibrate_one
calibrate_one:
		assume	ds:CODE
		mov	test_delay, ax
		; find the timer near zero
		mov	cx, 100h
calibrate_one_1:
		timer0_sample
		cmp	ax, cx
		ja	calibrate_one_1
		; now find the timer above that value (after wrapping to max)
calibrate_one_2:
		timer0_sample
		cmp	ax, cx
		jbe	calibrate_one_2
		; wait till it gets to the one quarter point
		mov	cx, 0C000h
calibrate_one_3:
		timer0_sample
		cmp	ax, cx
		ja	calibrate_one_3
		; calibration time - disable interrupts, watch for half a
		;  clock period to elapse
		pushf
		cli
		xor	bx, bx
		mov	cx, 4000h
		cmp	test_delay, 0		; see if measuring overhead?
		jne	calibrate_io
		; calibrating the overhead of this timing stuff only
calibrate_one_4:
		inc	bx
		jc	calibrate_exit		; overflow - exit w/ 0
		timer0_sample
		cmp	ax, cx
		ja	calibrate_one_4
		jmp	SHORT calibrate_exit
calibrate_io:	io_delay  test_delay
		inc	bx
		jc	calibrate_exit		; overflow - exit w/ 0
		timer0_sample
		cmp	ax, cx
		ja	calibrate_io
calibrate_exit:	popf
		mov	ax, bx
		ret


	private	calibrate_delay
calibrate_delay:
		assume	ds:CODE
		; if user wanted no delays, skip all this stuff
		cmp	delay_mult, 0
		jne	calibrate_delay_1
		xor	ax, ax			; normalize to zero
		jmp	calibrate_store
calibrate_delay_1:
		; calibrate the overhead of the time sampling loop
		xor	ax, ax
		call	calibrate_one
		or	ax, ax
		jz	calibrate_dj		; can't time -- default it all
		mov	null_spins, ax
ifdef	DEBUG
		mov	di, OFFSET null_spins
		mov	dx, OFFSET null_spin_name
		call	PRINT_NUMBER
endif
		; calibrate a unit (single spin) loop
		mov	ax, 1
		call	calibrate_one
		or	ax, ax
		jz	calibrate_dj		; can't time -- default it
		mov	unit_spins, ax
ifdef	DEBUG
		mov	di, OFFSET unit_spins
		mov	dx, OFFSET unit_spin_name
		call	PRINT_NUMBER
		mov	ax, unit_spins	; reload AX
endif
		cmp	null_spins, ax		; ensure null >= unit
		jb	calibrate_dj		; bogonic -- default it
		; now one with some teeth in it
		mov	ax, 1+REF_DELAY
		call	calibrate_one
		or	ax, ax
		jz	calibrate_dj		; can't time -- default it all
		mov	ref_spins, ax
ifdef	DEBUG
		mov	di, OFFSET ref_spins
		mov	dx, OFFSET ref_spin_name
		call	PRINT_NUMBER
		mov	ax, ref_spins		; reload AX
endif
		cmp	unit_spins, ax		; ensure unit > ref
		ja	calibrate_dj_1
calibrate_dj:	jmp	SHORT calibrate_def	; bogonic -- default it
calibrate_dj_1:

		; now do the math - compute the overhead of the timing code
		;  (in units of 100 nsec)
		mov	cx, null_spins
		call	compute_100nsecs
		jc	calibrate_def
		mov	null_bias, ax
ifdef	DEBUG
		mov	di, OFFSET null_bias
		mov	dx, OFFSET null_bias_name
		call	PRINT_NUMBER
endif
		; compute cost of the basic i/o delay macro (in units of
		;  100 nsec)
		mov	cx, unit_spins
		call	compute_100nsecs
		jc	calibrate_def
		sub	ax, null_bias
		mov	delay_delay, ax
ifdef	DEBUG
		mov	di, OFFSET delay_delay
		mov	dx, OFFSET delay_del_name
		call	PRINT_NUMBER
endif
		; compute cost of the reference spin in the i/o delay
		;  macro (this time, in units of 10 nsec)
		mov	cx, ref_spins
		call	compute_100nsecs
		jc	calibrate_def
		sub	ax, null_bias
		sub	ax, delay_delay		; now delay for REF_COUNT spins
		mov	cx, 10
		mul	cx
		jnc	calibrate_dj_2
		; this machine is *sooo* slow, a minimum delay is fine
		mov	ax, 1
		jmp	SHORT calibrate_store
calibrate_dj_2:
		mov	cx, REF_DELAY
		div	cx
		mov	count_delay, ax
ifdef	DEBUG
		mov	di, OFFSET count_delay
		mov	dx, OFFSET count_del_name
		call	PRINT_NUMBER
endif

		; now, see if basic i/o delay (w/o extra spins) is enough
		mov	bx, 1			; basic macro includes one spin
		mov	ax, delay_delay
		sub	ax, 22			; >= 2.2 usec ?
		jae	calibrate_dj_3
		neg	ax			; correct sign of residual
		mov	cx, 10			; scale to 10 nsec units
		mul	cx
		jc	calibrate_def
		div	count_delay
		inc	ax
		add	bx, ax			; back into spin count result
calibrate_dj_3:
		mov	ax, bx			; the calibrated basic result
		jmp	SHORT calibrate_store

calibrate_def:	; this processor is *sooo* fast that we can't calibrate it!?
		; just use a conservative default (should be good to about a
		;  400MHz 80486)
		mov	ax, 120

		; scale the delay by the user-request multiplier (if any)
calibrate_store:
		mul	delay_mult		; a tens multiple
		mov	cx, 10			; so reduce / 10
		div	cx			; allowed to be zero
		mov	io_delay_cnt, ax
		; compute the .9 usec 'iowm_delay_cnt'
		mov	cx, 9
		mul	cx
		mov	cx, 20
		div	cx
		mov	iowm_delay_cnt, ax
		ret


	private	compute_100nsecs
; Given a value in CX (representing spin counter during a 1/36.04 timing
;  run), compute the number of hundreds of nanoseconds per unit spin. Return
;  result in AX, or set CY and return if algorithm won't scale.
compute_100nsecs:
		assume	ds:CODE
		mov	ax, 9			; compute spins * 9 (36.04/4)
		mul	cx
		jc	compute_100n_err	; won't fit -- return error
		mov	cx, ax			; prepare for division
		mov	dx, 26h			; put 2,500,000 into DX,AX
		mov	ax, 25a0h
		div	cx			; compute 10M / (spins*36.04)
		clc
		ret
compute_100n_err:
		ret


	public	ETOPEN
; Perform initial open of the device.  Called only once: immediately prior to
; hooking the packet driver service interrupt and TSRing.  Device interrupts
; are to be hooked (if this routine deems reasonable to do so).  No registers
; are given on entry.  On return:
;	NC	if OK
;	DX	offset of the end of the resident portion of the driver
;	   or
;	CY	if error
ETOPEN:
		assume	ds:CODE
ifdef	DBGINT3
		int	03h		; Danger, Will Robinson!
endif
		; calibrate the i/o delays needed
		call	calibrate_delay
ifdef	DEBUG
		mov	di, OFFSET io_delay_cnt
		mov	dx, OFFSET io_delay_name
		call	PRINT_NUMBER
		mov	di, OFFSET iowm_delay_cnt
		mov	dx, OFFSET iowm_delay_name
		call	PRINT_NUMBER
endif

		; test for access to the device; check for 16-bit i/o
		call	try_io
		jnc	ETOPEN_1
		jmp	etopen_err
ETOPEN_1:
		; try out the interrupt channel & leave hooked if successful
		call	try_interrupt
		jnc	ETOPEN_2
		jmp	etopen_err
ETOPEN_2:
		; get the PROM Ethernet address
		call	RESET_INTERFACE	; reset the device (again!)
		loadport
		mov	ax, command_r	; everything still off
		or	ax, FIFO_WRITE
		setw_r	COMSTAT_R
		xor	ax, ax		; reset the DMA address to 0
		setw_r	DMA_ADDR_R
		mov	ax, config1_r_copy	; select the PROM
		or	ax, PROM_SEL
		setw_r	CONFIG1_R
		mov	ax, config2_r_copy	; blast the watchdog
		or	ax, KILL_WATCHDOG
		setw_r	CONFIG2_R
		push	ds
		pop	es
		mov	di,offset rom_address
		setport	BUFWIN_R	; fix access within the loop
		mov	cx, EADDR_LEN	; allocate some space for the address
ETOPEN_3:
		get_r	BUFWIN_R	; next byte of PROM Ethernet address
		stosb
		loop	ETOPEN_3

		; set the PROM address as the default STATION 0 address
		call	RESET_INTERFACE	; reset the device (yet again!)

		mov	cx, EADDR_LEN	; size of Ethernet address
		mov	si, offset rom_address
		call	SET_ADDRESS

		; load up Transmit End Area Pointer
		loadport
		mov	ax, config1_r_copy
		or	ax, TEA_SEL
		setw_r	CONFIG1_R
		mov	al, TEA_INIT
		set_r	BUFWIN_R

		; set up a few other default goodies once only here:
		;  config 1 :	STATION 0 address (Matchmode by 'rcv_mode_3')
		;  config 2 :	defaults are OK
		or	config1_r_copy, STATION_0_EN
		mov	ax, config1_r_copy
		setw_r	CONFIG1_R

		; we're go now -- wake up and smell the roses!
		and	command_r, NOT SET_RX_OFF
		; reload the CARD CONFIGURATION register
		mov	ax, config1_r_copy	; select CARD CONFIGURATION register
		or	ax, CARD_CONFIG_SEL
		setw_r	CONFIG1_R
		mov	al, cardconfig_r
		set_r	BUFWIN_R	; writes CARD CONFIGURATION register
		; turn on the receiver now, in (default) mode 3
		call	rcv_mode_3

		clc			; OK
		ret

etopen_err:
		stc			; error
		ret


	public	PARSE_ARGS
; Parse the device-specific portion of the invokation command line (after
; the packet driver vector number).  Entry with:
;	DS:SI	residual command line
; Can emit device-specific bitches as necessary (using DOS i/o) and exit
; without returning.  If it returns:
;	NC	if OK
;	   or
;	CY	if usage error
; Returning w/ carry set will cause a usage error, then exit without further
; processing.
PARSE_ARGS:
		assume	ds:CODE
		mov	di, OFFSET INT_NO
		call	GET_NUMBER
		mov	di, OFFSET IO_ADDR
		call	GET_NUMBER
		mov	di, OFFSET delay_mult
		call	GET_NUMBER
		clc			; OK
		ret


	public	PRINT_PARAMETERS
; Spew out all of the configuration parameters to the console device.
; Called within the main program, just prior to deciding to TSR.  Should
; dump out each device-specific parameter, parsed by PARSE_ARGS (just to
; make the user warm-and-fuzzy I suppose...)  Entry with:
;	no special register contents
; Returns:
;	nothing
PRINT_PARAMETERS:
		assume	ds:CODE
		mov	di, OFFSET INT_NO
		mov	dx, OFFSET int_no_name
		call	PRINT_NUMBER
		mov	di, OFFSET IO_ADDR
		mov	dx, OFFSET io_addr_name
		call	PRINT_NUMBER
		mov	di, OFFSET delay_mult
		mov	dx, OFFSET delay_mult_name
		call	PRINT_NUMBER
		ret


	private	try_interrupt
; try out the receiver interrupt (once at the outset); in the process,
; sets up the CARD CONFIGURATION register
try_interrupt:
		assume ds:CODE
		call	RESET_INTERFACE
		loadport
		mov	ax, config1_r_copy	; program CARD CONFIGURATION register
		or	ax, CARD_CONFIG_SEL
		setw_r	CONFIG1_R
		; map interrupt number to card config enumeration value
		mov	bx, WORD PTR INT_NO
		mov	al, [bx + OFFSET int_map]
		or	al, al
		jz	try_int_badint_err
		; check for 16-bit i/o usage; include in card config value
		cmp	io_16, 0
		je	try_interrupt_1
		or	al, SET_16BITMODE_M
try_interrupt_1:
		set_r	BUFWIN_R	; writes CARD CONFIGURATION register
		mov	cardconfig_r, al  ; save soft-copy of this
		; install the 'recv_isr' handler
		mov	int_test, 1	; flag that we're testing only
		call	SET_RECV_ISR
		; cause a receiver interrupt
		loadport
		mov	ax, command_r	; SET_RX_OFF in here now
		or	ax, RX_INT_EN+SET_RX_ON
		setw_r	COMSTAT_R	; Interrupt!
;# Compaq DOS leaves CPU ints disabled!
                sti
		mov	ax, 1		; wait one tick
		call	set_timeout
try_interrupt_2:
		call	do_timeout
		jz	try_int_timedout
		cmp	int_tested, 0	; did it happen?
		je	try_interrupt_2
		; the interrupt worked -- leave w/ the receiver off, the
		;   ISR hooked but masked
		mov	ax, command_r	; SET_RX_OFF in here now
		setw_r	COMSTAT_R	; shut up!
		mov	al, INT_NO
		call	MASKINT
		mov	int_test, 0	; from now on, it's the real thing
		clc			; OK
		ret

try_int_timedout:
		; timed-out (bummer dude!) -- turn receiver back off
		mov	ax, command_r	; SET_RX_OFF in here now
		or	ax, RX_INT_ACK 	; just in case ...
		setw_r	COMSTAT_R	; shut up!
		; deregister handler and boogie
		;   This should be a standard call -- I've asked Russ ...
		mov	al, INT_NO
		add	al, 8
		cmp	al, 8+8		; is it a slave 8259 interrupt?
		jb	try_int_timedout_1; no.
		add	al, 70h - (8+8)	; map it to the real interrupt
try_int_timedout_1:
		push	ds
		assume	ds:nothing
		lds	dx, THEIR_ISR
		mov	ah, 25h
		int	21h
		pop	ds
		assume	ds:CODE
		mov	dx, OFFSET inttimedout_msg	
		jmp	SHORT try_int_err
try_int_badint_err:
		mov	dx, OFFSET badint_msg
		mov	ah, 9		; blab to the user
		int	21h
		cmp	io_16, 0	; tell him/her/it what's legit
		jne	try_int_badint_err_1
		mov	dx, OFFSET int8_msg
		jmp	SHORT try_int_err
try_int_badint_err_1:
		mov	dx, OFFSET int16_msg
try_int_err:
		stc			; error
		ret


	private	try_io
; try out i/o to the device; in the process, determines if 16-bit i/o is OK
; NOTE: This code was transliterated from the C source for DAVID's NDIS driver.
;   In the absence of any written documentation on the CARD CONFIGURATION
;   register, the many magic numbers herein remain a mystery.
try_io:
		assume ds:CODE
		call	RESET_INTERFACE
		mov	command_r, SET_TX_OFF+SET_RX_OFF+SET_DMA_OFF
		loadport
		mov	ax, config1_r_copy	; select CARD CONFIGURATION register
		or	ax, CARD_CONFIG_SEL
		set_r	CONFIG1_R	; BYTE-size only here!
		; first taunting of the device ...
		mov	al, 05h		; C sez: "4 bit is LSBS value"
		set_r	BUFWIN_R	;        " ... and ... "
		get_r	BUFWIN_R	; C sez: "comes back in the 4 MSBs"
		and	al, 0F0h
		cmp	al, 50h		; this has to compare
		jne	try_io_err
		; second taunting of the device ...
		mov	al, 0Ah		; "Your mother was a hamster ..."
		set_r	BUFWIN_R
		get_r	BUFWIN_R	; "... and your father smelt of"
		and	al, 0F0h	;     "ELDERBERRIES!"
		cmp	al, 0A0h
		jne	try_io_err
		; now for something completely different -- ask the CARD
		;   CONFIGURATION register if it's plugged into an 8- or
		;   16-bit slot; mark it well
		get_r	BUFWIN_R
		and	al, 1		; bit on means 8-bit slot
		xor	al, 1		; complement sense for 'io_16'
		mov	io_16, al
		jz	try_io_1
		; set-up 16-bit versions of word i/o functions
		; N.B. From this point forward, we MUST to 16 bit i/o
		;   on 16 bit objects if the card told us to!
		mov	inw_fn, OFFSET inw_8005   ; input function
		mov	outw_fn, OFFSET outw_8005 ; output function
try_io_1:
		clc			; OK
		ret

try_io_err:
		mov	dx, OFFSET nodev_msg
		stc			; error
		ret	; "Now go away or I shall taunt you a second time-uh!"


CODE		ends

		end


; eof
