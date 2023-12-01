;************************************************************************;
;*									*;
;*			EEP17.INC					*;
;*									*;
;*  EEPROM configuration routines for the ATI AT-1700 Adapters.		*;
;*									*;
;*  Copyright (c) 1992, 1993, Allied Telesis, Inc.  All Rights Reserved.*;
;*									*;
;************************************************************************;


DATASEG	SEGMENT


	ifdef	CODE386		; 386 "flat" model
CONFIG_PTR	equ	ESI
	else			; all other models
CONFIG_PTR	equ	SI
	endif

	ifndef	@Version
@Version equ	000
	endif


; EtherCoupler Register addresses (offsets from IOBASE):
DLCR7_OFFSET	equ	7		; Config (register select) register
DLCR8_OFFSET	equ	8		; Node ID register
EESKCS_OFFSET	equ	16		; EESKCS register - see below
EEDP_OFFSET	equ	17		; EEDP register - see below
IOBAI_OFFSET	equ	18		; IOBAI register
JLC_OFFSET	equ	19		; JumperLess Configuration register
IDROM_OFFSET	equ	24		; first byte of IDROM

; EtherCoupler's EESKCS EEPROM control register:
DATA_IN		equ	80h	; serial data in (write)
CLOCK		equ	40h	; serial clock (write)
DATA_OUT	equ	04h	; serial data out (read)
CHIP_SEL	equ	20h	; Chip Select

; EtherCoupler's EDDP EEPROM Data register:
SB		equ	80h	; "Start Bit"
READ		equ	80h	; Command Code:  Read
EWEN		equ	30h	; Command Code:  Write Enable
WRITE		equ	40h	; Command Code:  Write
WRALL		equ	10h	; Command Code:  Write All
EWDS		equ	00h	; Command Code:  Write Disable

; EEPROM byte (word) locations:
CONFIG_ADDR	equ	0/2	; Configuration Byte - see below
ETHERNET_ADDR	equ	8/2	; Ethernet (MAC) address of this adapter
BMPR13_ADDR	equ	24/2	; value to be used in BMPR13 - see below
BRD_TYPE_ADDR	equ	30/2	; Board type code - see below
BRD_REV_ADDR	equ	31/2	; Board rev level code

; JLC register and Configuration Byte (EEPROM location 0) format:
IO_BASE_MASK	equ	007h	; bits 0-2 = I/O Base code - see below
MEM_BASE_MASK	equ	038h	; bits 3-5 = Boot PROM Base code - see below
IRQ_MASK	equ	0C0h	; bits 6-7 = IRQ code - see below

; I/O Base code (JLC bits 0-2):
BASE_IO_260	equ	00h
BASE_IO_280	equ	01h
BASE_IO_2A0	equ	02h
BASE_IO_240	equ	03h
BASE_IO_340	equ	04h
BASE_IO_320	equ	05h
BASE_IO_380	equ	06h
BASE_IO_300	equ	07h

; Boot PROM Base code (JLC bits 3-5):
ROM_BASE_C400		equ	00h
ROM_BASE_C800		equ	08h
ROM_BASE_CC00		equ	10h
ROM_BASE_D000		equ	18h
ROM_BASE_D400		equ	20h
ROM_BASE_D800		equ	28h
ROM_BASE_DC00		equ	30h
ROM_BASE_DISABLED	equ	38h

; IRQ code (JLC bits 6-7):
IRQ_3		equ	000h
IRQ_4		equ	040h
IRQ_5		equ	080h
IRQ_9		equ	0C0h

; BMPR13 Register bits (EEPROM location 24):
MAU_SEL_MASK	equ	18h		; bits 3&4 = Port selection
UTP_PORT		equ	08h		; UTP port
OTHER_PORT		equ	18h		; "Other" (BNC/Fiber) port
AUTO_SELECT		equ	00h		; "Auto Select"
TPTYPE_MASK	equ	44h		; bits 2&6 = Twisted Pair Type selection
UTP_MEDIA_TYPE		equ	40h		; 100ohm UTP or STP cabling
STP_MEDIA_TYPE		equ	04h		; 150ohm STP cabling

; Board Type code (EEPROM location 30):
IS_A_1700T	equ	0		; AT-1700T Twisted-Pair only
IS_A_1700BT	equ	1		; AT-1700BT Twisted-Pair plus BNC
IS_A_1700FT	equ	2		; AT-1700FT Twisted-Pair plus FOIRL

DATASEG	ENDS


CODESEG	SEGMENT

DELAY_750 MACRO
	; One CPU clock cycle = 25ns at 40Mhz CPU clock frequency
	; jmp short = (min) 8 cycles on a 386 = 200ns per jump
	; times 4 = at least 800ns on a 40Mhz 386
	jmp short $+2
	jmp short $+2
	jmp short $+2
	jmp short $+2
	ENDM

DELAY_250 MACRO
	; times 2 = at least 400ns on a 40Mhz 386
	jmp short $+2
	jmp short $+2
	ENDM


;************************************************************************;
;*									*;
;*  VerifyBoard								*;
;*	Function: 1) reset the board					*;
;*		  2) read the IRQ and BMPR13 value from the EEPROM.	*;
;*	Input:	DI = base I/O address of the AT-1700 board		*;
;*	Output: AH = IRQ from JLC register if success			*;
;*		AL = BMPR13 value register if success			*;
;*		AX = FFFFh if failure (not an AT-1700 or config error)	*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

VerifyBoard proc	near

	push	cx
	push	dx

	xor	ax, ax
	mov	dx, di			;reset the NIC
	add	dx, IDROM_OFFSET
	out	dx, al

	call	is_there_AT1700		;read the register pattern
	jnc	get_irq
	mov	ax, 0ffffh		;it's not there
	pop	dx
	pop	cx
	ret

get_irq:
	mov	dx, DI
	add	dx, JLC_OFFSET		;read JLC register
	in	al, dx

	; AL now contains Base IO and IRQ
	and	al, IRQ_MASK
	mov	cl, 3
	cmp	al, IRQ_3
	 je	get_bmpr
	mov	cl, 4
	cmp	al, IRQ_4
	 je	get_bmpr
	mov	cl, 5
	cmp	al, IRQ_5
	 je	get_bmpr
	mov	cl, 9

get_bmpr:
	call	read_BMPR_val		;al = BMPR13 register value
	mov	ah, cl

	pop	dx
	pop	cx
	ret

VerifyBoard endp


;************************************************************************;
;*									*;
;*  GetIRQAndVerify							*;
;*	Function: Get the IRQ and read MAC addr from EEPROM to verify	*;
;*		the board						*;
;*	Input:	DI = base I/O address of the AT-1700 board		*;
;*		DS:(E)SI => caller's buffer where to put MAC address.	*;
;*	Output: the board's MAC address is placed in the caller's bfr.	*;
;*		AX = IRQ from JLC register if success			*;
;*		AX = FFFFh if failure (not an AT-1700 or config error)	*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

GetIRQAndVerify proc	near

	push	cx			; save caller's registers
	push	dx

	call	Verify_JLC		; read & verify JLC (returns ah = JLC)
	mov	al, ah			; al = JLC value

	xor	cx, cx			; determine configured IRQ value
	and	al, IRQ_MASK
	mov	cl, 3
	cmp	al, IRQ_3
	 je	VerifyMACAddr
	mov	cl, 4
	cmp	al, IRQ_4
	 je	VerifyMACAddr
	mov	cl, 5
	cmp	al, IRQ_5
	 je	VerifyMACAddr
	mov	cl, 9

VerifyMACAddr:
	call	read_mac_addr		; read the board's MAC address
	cmp	word ptr [CONFIG_PTR], 0	; (validate it)
	 jne	FailToVerify
	cmp	byte ptr [CONFIG_PTR+2], 0F4h
	 jne	FailToVerify

	mov	ax, cx			; return IRQ value in ax
	pop	dx			; restore caller's registers
	pop	cx
	ret				; return to caller

FailToVerify:
	mov	ax, 0ffffh
	pop	dx
	pop	cx
	ret

GetIRQAndVerify endp

;************************************************************************;
;*									*;
;*  Verify_JLC								*;
;*	Function: Get the JLC and do a sanity check on it.		*;
;*	Input:	DI = base I/O address of the AT-1700 board		*;
;*	Output:	AH = JLC register value					*;
;*		ZF = TRUE (jz) on success				*;
;*		ZF = FALSE (jnz) on failure				*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

Verify_JLC	PROC	NEAR

	mov	dx, DI
	add	dx, JLC_OFFSET
	in	al, dx			; read the JLC register
	mov	ah, al			; save it for caller in AH

	and	al, IO_BASE_MASK
	cmp	di, 0300h
	 jne	next_io_1
	cmp	al, BASE_IO_300
	 je	JLC_verified
	jmp	JLC_failure
next_io_1:
	cmp	di, 0320h
	 jne	next_io_2
	cmp	al, BASE_IO_320
	 je	JLC_verified
	jmp	JLC_failure
next_io_2:
	cmp	di, 0340h
	 jne	next_io_3
	cmp	al, BASE_IO_340
	 je	JLC_verified
	jmp	JLC_failure
next_io_3:
	cmp	di, 0380h
	 jne	next_io_4
	cmp	al, BASE_IO_380
	 je	JLC_verified
	jmp	JLC_failure
next_io_4:
	cmp	di, 0240h
	 jne	next_io_5
	cmp	al, BASE_IO_240
	 je	JLC_verified
	jmp	JLC_failure
next_io_5:
	cmp	di, 0260h
	 jne	next_io_6
	cmp	al, BASE_IO_260
	 je	JLC_verified
	jmp	JLC_failure
next_io_6:
	cmp	di, 0280h
	 jne	next_io_7
	cmp	al, BASE_IO_280
	 je	JLC_verified
	jmp	JLC_failure
next_io_7:
	cmp	di, 02A0h
	 jne	JLC_failure
	cmp	al, BASE_IO_2A0
	 jne	JLC_failure

JLC_verified:
JLC_failure:
	ret		; return to caller

Verify_JLC endp


;************************************************************************;
;*									*;
;*  is_there_AT1700							*;
;*	Function: determines if this is an AT-1700 at this location.	*;
;*	Input:	DI = base I/O of the presumed AT-1700 adapter card.	*;
;*	Output: clc (carry clear) if AT1700 is found, else		*;
;*		stc (carry set) if not.					*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

is_there_AT1700 PROC NEAR

	push	ax
	push	dx

	;  First do a pattern check - a just powered-up or reset AT-1700 board
	;  will have a known pattern to its I/O registers.
	mov	dx, DI
	in	al, dx			; check DLCR0
	and	al, NOT 40h		; remove NET BUSY bit
	 jz	try_2			;   all other bits should be zero
	jmp	not_the_reset_pattern
try_2:
	inc	dx
	in	al, dx			; check DLCR1
	or	al, al
	 jz	try_3
	jmp	not_the_reset_pattern
try_3:
	inc	dx
	in	al, dx			; check DLCR2
	or	al, al
	 jz	try_4
	jmp	not_the_reset_pattern
try_4:
	inc	dx
	in	al, dx			; check DLCR3
	or	al, al
	 jz	try_5
	jmp	not_the_reset_pattern
try_5:
	inc	dx
	in	al, dx			; check DLCR4
	and	al, 0Fh
	cmp	al, 06h
	 je	try_6
	jmp	not_the_reset_pattern
try_6:
	inc	dx
	in	al, dx			; check DLCR5
	cmp	al, 041h
	 je	try_7
	jmp	not_the_reset_pattern
try_7:
	inc	dx
	in	al, dx			; check DLCR6
	cmp	al, 0B6h
	 je	try_8
	jmp	not_the_reset_pattern
try_8:
	inc	dx
	in	al, dx			; check DLCR7
	cmp	al, 0E0h
	 jne	not_the_reset_pattern

	;  The pattern matches the AT-1700 reset pattern!
found_it:
	clc
	pop	dx
	pop	ax
	ret

not_the_reset_pattern:
	;  The board at this I/O address (if there indeed is a board here)
	;  does not match the AT-1700 reset pattern.  Perhaps a driver has
	;  already been invoked which has changed some of the registers.
	;  So, we'll have to now follow Fujitsu's algorithm, which just checks
	;  a few registers to make sure a few reserved bits are actually zero.
	;  Since we don't think this approach is by itself very robust, we also
	;  add a check of DLCR6 and DLCR7 to make sure they make sense for this
	;  particular implementation (an AT-1700 always has 32k, for example).
	mov	DX, DI
	inc	DX
	inc	DX
	in	AL, DX			; read DLCR2
	and	AL, 71h			; isolate reserved bits
	 jnz	not_there		;   not zeros as expected
	inc	DX
	inc	DX
	in	AL, DX			; read DLCR4
	and	AL, 08h			; isolate reserved bit
	 jnz	not_there		;   not zero as expected
	inc	DX
	in	AL, DX			; read DLCR5
	and	AL, 80h			; isolate reserved bit
	 jnz	not_there		;   not zero as expected
	inc	DX
	in	AL, DX			; read DLCR6
	and	AL, 0F0h		; isolate AT-1700 meaningful bits
	cmp	AL, 050h		; known pattern for an AT-1700
	 jne	not_there		;   not an (initialized) AT-1700
	inc	DX
	in	AL, DX			; read DLCR7
	and	AL, 020h		; isolate AT-1700 meaningful bit
	cmp	AL, 020h		; known pattern for an AT-1700
	 jne	not_there		;   not an (initialized) AT-1700

	;  So far, it looks like this *might* be an (initialized) AT-1700.
	;  But we'll do two more checks to be sure:
	;	(1) the JLC (JumperLess Configuration) register better
	;	    have an I/O base value corresponding to the I/O base
	;	    that we're currently probing, and
	;	(2) the Node ID registers (DLCR8-10) better contain our magic
	;	    cookie (0000F4).  This assumes that since the other regs
	;	    are not in a reset state then some driver must have done
	;	    something, and any reasonable driver would also load the
	;	    MAC address into the Node ID regs.  This test also does
	;	    something we do nowhere else while probing:  it must write
	;	    registers in order to read the Node ID.  Although we don't
	;	    like doing random writes, we assume that it must be fairly
	;	    safe to do so since at this point we have passed all of the
	;	    above tests.
	call	Verify_JLC		; do a sanity check on the JLC

	push	CX
	pushf
	cli				; disable interrupts in case driver up!
	mov	DX, DI
	add	DX, DLCR7_OFFSET-1
	in	AL, DX			; read DLCR6
	mov	CL, AL			; save DLCR6 value for later restore
	or	AL, 80h
	out	DX, AL			; enable the Node ID registers
	inc	DX
	in	AL, DX			; read DLCR7
	mov	CH, AL			; save DLCR7 value for later restore
	and	AL, 0F3h
	out	DX, AL			; switch to bank zero (DLCR0-DLCR15)

	inc	DX
	in	AL, DX			; read DLCR8 = Node ID [0]
	cmp	AL, 00h
	 jne	not_a_1700		;   not 0000F4!!
	inc	DX
	in	AL, DX			; read DLCR9 = Node ID [1]
	cmp	AL, 00h
	 jne	not_a_1700		;   not 0000F4!!
	inc	DX
	in	AL, DX			; read DLCR10 = Node ID [2]
	cmp	AL, 0F4h
	 jne	not_a_1700		;   not 0000F4!!

	mov	DX, DI
	add	DX, DLCR7_OFFSET-1
	mov	AL, CL			; get saved DLCR6 value
	out	DX, AL			; restore DLCR6 for the driver
	inc	DX
	mov	AL, CH			; get saved DLCR7 value
	out	DX, AL			; restore DLCR7 for the driver
	popf				; re-enable interrupts if appropriate
	pop	CX

	jmp	found_it		; this is apparently an AT-1700 !!!

not_a_1700:
	popf				; re-enable interrupts if appropriate
	pop	CX

not_there:
	stc
	pop	dx
	pop	ax
	ret

is_there_AT1700 ENDP


;************************************************************************;
;*									*;
;*  read_mac_addr							*;
;*	Function: to read the mac address of the board.			*;
;*	Input:	DS:(E)SI => caller's buffer where to place mac address.	*;
;*		DI = base I/O address of the AT-1700 board		*;
;*	Output: the board's MAC address is placed in the caller's bfr.	*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

read_mac_addr	proc	near

	push	ax			; save caller's registers
	push	bx

	mov	bx, ETHERNET_ADDR	; start from EEPROM location 8
	call	rd_oper			; read a word of the MAC address
	mov	word ptr [CONFIG_PTR], ax
	inc	bx
	call	rd_oper
	mov	word ptr [CONFIG_PTR+2], ax
	inc	bx
	call	rd_oper
	mov	word ptr [CONFIG_PTR+4], ax

	pop	bx			; restore caller's registers
	pop	ax
	ret				; return to caller
	
read_mac_addr	endp


;************************************************************************;
;*									*;
;*  read_BMPR_val							*;
;*	Function: read the BMPR13 value to be used from EEPROM.	 	*;
;*	Input:	DI = base I/O address of the AT-1700 board		*;
;*	Output: AX = BMPR13 value to be used by the driver.		*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

read_BMPR_val	proc	near

	push	bx
	mov	bx, BMPR13_ADDR		; read location 24 for BMPR13
	call	rd_oper
	pop	bx
	ret				; return to caller

read_BMPR_val	endp


;************************************************************************;
;*									*;
;*  rd_oper								*;
;*	Function: do a complete word READ operation.			*;
;*	Input:	BX = EEPROM address to be read.				*;
;*		DI = base I/O address of the AT-1700 board		*;
;*	Output: AX = EEPROM data from the specified location.		*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

rd_oper	proc	near

	push	bx		; save caller's registers
	push	dx

	or	bl, READ
	call	wr_command	; output the address to be read
	call	rd_byte		; read the first (low-order) byte
	mov	dl, al		; temporarily save low-order byte
	call	rd_byte		; read the second (high-order) byte
	mov	dh, al		; assemble the complete word
	mov	ax, dx		;   and return to caller in AX

	pop	dx		; restore caller's registers
	pop	bx
	ret			; return to caller

rd_oper	endp


;************************************************************************;
;*									*;
;*  rd_byte								*;
;*	Function: Read one byte from the EEPROM.			*;
;*	Input:	DI = base I/O address of the AT-1700 board		*;
;*	Output:	AL = byte read.						*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

rd_byte	proc	near

	push	cx			; save caller's registers
	push	dx

	mov	dx, DI
	add	dx, EESKCS_OFFSET	; DX = EtherCoupler EESKSC register
	mov	cx, 8
r_bit:
	mov	al, CHIP_SEL
	out	dx, al			; turn on CHIP SELECT with CLOCK low
	or	al, CLOCK
	out	dx, al			; make CLOCK go high
	inc	dx			; DX = EtherCoupler EEDP register
	in	al, dx			; read EEDP
	shl	ax, 1			; shift AH <<= 1;  AL b7 -> AH b0;
	dec	dx			; DX = EESKSC register again
	loop	r_bit			; loop to read all 8 bits

	mov	al, ah			; return read byte (now in AH) in AL
	pop	dx			; restore caller's registers
	pop	cx
	ret				; return to caller

rd_byte	endp


;************************************************************************;
;*									*;
;*  wr_command								*;
;*	Function: Output a command and memory address to the EEPROM.	*;
;*	Input:	BL = the command/address byte to be written.		*;
;*		DI = base I/O address of the AT-1700 board		*;
;*	Output: nothing							*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

wr_command	proc	near

	push	ax			; save caller's registers
	push	dx

	mov	dx, DI
	add	dx, EESKCS_OFFSET	; DX = EtherCoupler EESKSC register
	xor	al, al
	out	dx, al			; turn off CHIP SELECT and CLOCK
	inc	dx			; DX = EtherCoupler EEDP register
	out	dx, al			; clear the Serial Data In line

	dec	dx			; DX = EESKSC register again
	mov	al, CHIP_SEL
	out	dx, al			; turn on CHIP SELECT with CLOCK low
	inc	dx			; DX = EEDP register again
	mov	al, SB
	out	dx, al			; write a start bit
	dec	dx			; DX = EESKSC register again
	mov	al, CHIP_SEL or CLOCK
	out	dx, al			; make CLOCK go high

	call	wr_byte			; write the caller's data byte

	pop	dx			; restore caller's registers
	pop	ax
	ret				; return to caller

wr_command	endp

;************************************************************************;
;*									*;
;*  wr_byte								*;
;*	Function: Write a byte to the eeprom.				*;
;*	Input:	BL = data byte to be written				*;
;*		DI = base I/O address of the AT-1700 board		*;
;*	Output: nothing							*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

wr_byte	proc	near

	push	ax			; save caller's registers
	push	cx
	push	dx

	mov	ax, bx			; save caller's byte temporarily
	mov	dx, DI
	add	dx, EEDP_OFFSET		; DX = EtherCoupler EEDP register
	mov	cx, 8
s_bit:
	push	ax			; save caller's byte on the stack
	out	dx, al			; output low-order bit of caller's byte
	dec	dx			; DX = EtherCoupler EESKSC register
	mov	al, CHIP_SEL
	out	dx, al			; turn on CHIP SELECT with CLOCK low
	or	al, CLOCK
	out	dx, al			; make CLOCK go high
	inc	dx			; DX = EEDP register again
	pop	ax			; restore caller's saved byte from stack
	shl	ax, 1			; shift to next bit position
	loop	s_bit			; loop to output all 8 bits

	pop	dx			; restore caller's registers
	pop	cx
	pop	ax
	ret				; return to caller

wr_byte	endp


CODESEG	ENDS

