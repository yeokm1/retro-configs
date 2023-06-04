;************************************************************************;
;*									*;
;*			EEP15.INC					*;
;*									*;
;*  EEPROM configuration routines for the ATI AT-1500 Adapters.		*;
;*									*;
;*  Copyright (c) 1992, 1993, Allied Telesis, Inc.  All Rights Reserved.*;
;*									*;
;************************************************************************;


DATASEG SEGMENT


	ifdef	CODE386		; 386 "flat" model (Novell 386 server driver)
POINTER_REGISTER  equ	ESI
	else			; all other models
POINTER_REGISTER  equ	SI
	endif

	ifndef	@Version
@Version equ	000
	endif


; Bit definitions for the PCNetISA "Vendor Specific Word", which on the
; AT-1500 controls the on-board serial EEPROM (National Semiconductor NMC95C12).
DATA_IN		equ	001h	; EEPROM serial data in (DI) - write/only
CLOCK		equ	002h	; EEPROM serial clock (SK) - write/only
DATA_OUT	equ	004h	; EEPROM serial data out - read/only
CHIP_SEL	equ	008h	; EEPROM Chip Select - write/only
JUMPER_STATE	equ	008h	; Alternate Address Jumper state - read/only

; EEPROM command codes.
READ		equ	80h	; Read EEPROM memory at specified address
WEN		equ	30h	; Write Enable
WRITE		equ	40h	; Write EEPROM memory at specified address
WRALL		equ	10h	; Write to all EEPROM locations
WDS		equ	00h	; Write Disable

SB		equ	01h	; "Start Bit" (command follows)
ADDR_MASK	equ	3Fh	; EEPROM memory address mask

; EEPROM locations used for AT-1500 configuration data (all are word addresses):
BOARD_TYPE_LOC		equ	0	; ASCII product name:  12 bytes
BOARD_REV_LOC		equ	6	; board rev. level:  low-order byte
BOARD_SUBTYPE_LOC	equ	6	; board subtype code:  high-order byte
FLAG_WORD_LOC		equ	32	; Flag bits - see below
SCR_SAVE_ADDR		equ	61	; SCR (below) power-up value save loc.
SCR_ADDR		equ	62	; "Switch Configuration Register"
SRR_ADDR		equ	63	; "Switch Readback Register"

; Configuration values for the SCR and the SCR_SAVE (word locations 61 & 62):
IRQ_MASK	equ	0003h		; bits  0-3  (switch 1): IRQ: see below
DMA_MASK	equ	0030h		; bits  4-7  (switch 2): DMA: see below
IO_BASE_MASK	equ	0300h		; bits  8-11 (switch 3): IO: see below
BOOT_EN_MASK	equ	1000h		; bits 12-15 (switch 4): BOOT: see below
MAU_SEL_MASK	equ	2000h		; bits 12-15 (switch 4): PORT: see below

; SCR Bits 0-3:  IRQ configuration:
IRQ_CHOICE_A	equ	0000h
IRQ_CHOICE_B	equ	0001h
IRQ_CHOICE_C	equ	0002h
IRQ_CHOICE_D	equ	0003h
IRQ_3		equ	IRQ_CHOICE_A
IRQ_4		equ	IRQ_CHOICE_B
IRQ_5		equ	IRQ_CHOICE_C
IRQ_9		equ	IRQ_CHOICE_D
IRQ_10		equ	IRQ_CHOICE_A		; AT-1500xx-20 only
IRQ_11		equ	IRQ_CHOICE_B		; AT-1500xx-00/20 only
IRQ_14		equ	IRQ_CHOICE_C		; AT-1500xx-20 only
IRQ_15		equ	IRQ_CHOICE_D		; AT-1500xx-00/20 only

; SCR Bits 4-7:  DMA configuration:
DMA_3		equ	0000h
DMA_5		equ	0010h
DMA_6		equ	0020h
DMA_7		equ	0030h

; SCR Bits 8-11:  IO BASE configuration:
BASE_IO_300	equ	0000h
BASE_IO_320	equ	0100h
BASE_IO_340	equ	0200h
BASE_IO_360	equ	0300h

; SCR Bits 12-15:  BOOT PROM and PORT SELECTION configuration:
BOOT_ENA	equ	1000h		; bit 12 = 1:  Enable boot PROM
BOOT_DIS	equ	0000h		; bit 12 = 0:  Disable boot PROM
UTP_PORT	equ	2000h		; bit 13 = 1:  Select UTP Port
OTHER_PORT	equ	0000h		; bit 13 = 0:  Select "Other" Port

; Flag Word (location 32):
AUTO_SENSE_BIT	equ	0001h

; Board "Subtypes" (location 6):
SUBTYPE_00	equ	1
SUBTYPE_10	equ	2
SUBTYPE_20	equ	3

; PCNetISA I/O Ports:
ADDR_PROM_OFFSET	equ	0	; MAC (datalink) Address PROM
RDP_OFFSET		equ	16	; Register Data Port
RAP_OFFSET		equ	18	; Register Address Port
ISACR_OFFSET		equ	22	; ISA-Bus Control Register
VSW_OFFSET		equ	24	; Vendor Specific Word

ISACR2		equ	2		; ISACR2 (out RAP register == ISACR2)
MC_UTP_OTHER	equ	001h		; value to select UTP or "Other" port
MC_AUTO_SEL	equ	002h		; value to select "Auto Select" function

; Possible AT-1500 IRQ choices (varies depending on board "subtype"):
IRQ_RANGE	MACRO	range_name, irq_a, irq_b, irq_c, irq_d
range_name	equ	(irq_a SHL 12) + (irq_b SHL 8) + (irq_c SHL 4) + irq_d
		ENDM
	IRQ_RANGE  LOW_IRQ_RANGE,    3,  4,  5,  9
	IRQ_RANGE  HIGH_IRQ_RANGE,  10, 11, 14, 15
	IRQ_RANGE  MIXED_IRQ_RANGE,  3, 11,  5, 15


DATASEG ENDS


CODESEG SEGMENT

	if	@Version GE 600
	ASSUME  CS:CODESEG
	endif
	ifdef	DATAGROUP
	ASSUME  DS:DATAGROUP
	endif
	ifdef	STACKSEG
	ASSUME  SS:STACKSEG
	endif
	ASSUME  ES:NOTHING

DELAY_750 MACRO
	; One CPU clock cycle = 25ns at 40Mhz CPU clock frequency
	; jmp short = (min) 8 cycles on a 386 = 200ns per jump
	; times 4 = at least 800ns on a 40Mhz 386
	; times 8 = at least 800ns on an 80Mhz 386 (!!)
	jmp short $+2
	jmp short $+2
	jmp short $+2
	jmp short $+2
	jmp short $+2
	jmp short $+2
	jmp short $+2
	jmp short $+2
	ENDM

DELAY_250 MACRO
	; times 2 = at least 400ns on a 40Mhz 386
	; times 4 = at least 400ns on an 80Mhz 386 (!!)
	jmp short $+2
	jmp short $+2
	jmp short $+2
	jmp short $+2
	ENDM

DEBUG_DISPLAY MACRO	display_char
	push	AX
	push	DX
	mov	AH, 02h
	mov	DL, '<'
	int	21h
	mov	DL, display_char
	int	21h
	mov	DL, '>'
	int	21h
	pop	DX
	pop	AX
	ENDM


;************************************************************************;
;*									*;
;*  VerifyBoard								*;
;*	Function: Read the configuration of the AT-1500 board.		*;
;*	Input:  DI = base I/O address of the AT-1500 board.		*;
;*	Output: stc (carry set) if not an AT-1500 or config error;	*;
;*		clc (carry clear) if successful, and:			*;
;*			BH = configured DMA channel.			*;
;*			BL = configured IRQ.				*;
;*			CX = value to be output to the ISACR2 register.	*;
;*		Other registers used are preserved.			*;
;*									*;
;************************************************************************;

VerifyBoard proc	near

	push	AX			; save caller's registers
	push	DX

	; Verify that this really is an AT-1500 board.
	mov	DX, DI			; DX = address prom I/O address
	in	AX, DX			; read the first 2 bytes of MAC address
	cmp	AX, 0			; it better be 0000
	je	VB_go_on
	 jmp	scr_error
VB_go_on:
	add	DX, 2
	in	AX, DX			; read the next 2 bytes of MAC address
	cmp	AL, 0F4h		; the third byte better be F4
	je	VB_its_ours
	 jmp	scr_error
VB_its_ours:
	;  Read the SCR to get the state of the configuration "switches".
	mov	BX, SCR_ADDR
	call	rd_oper			; read the Switch Configuration Register
	mov	DX, AX			; save SCR value for later

	;  Read this board's rev level and "subtype" codes.
	mov	BX, BOARD_REV_LOC	; read "board rev code" at EEPROM loc 6
	call	rd_oper			; AL=rev level code, AH=Subtype code

	;  Determine the configured IRQ and return this value in BL.
	mov	BX, HIGH_IRQ_RANGE	; (assume this is a Subtype 20 board)
	cmp	AH, SUBTYPE_20		; is this a Subtype 20 board ?
	 je	got_irq_range		;   yes, uses High range of IRQ choices
	mov	BX, MIXED_IRQ_RANGE
	cmp	AH, SUBTYPE_00		; is this a Subtype 00 board ?
	 je	got_irq_range		;   yes, uses Mixed range of IRQ choices
	mov	BX, LOW_IRQ_RANGE	; must be Subtype 10: uses Low IRQ range
  got_irq_range:
	mov	AX, DX			; get the SCR value again
	and	AX, IRQ_MASK		; isolate IRQ configuration bits
	mov	CL, 12
	cmp	AX, IRQ_CHOICE_A	; switch based upon on of 4 IRQ choices
	 je	got_irq
	mov	CL, 8
	cmp	AX, IRQ_CHOICE_B
	 je	got_irq
	mov	CL, 4
	cmp	AX, IRQ_CHOICE_C
	 je	got_irq
	xor	CL, CL
	cmp	AX, IRQ_CHOICE_D
	 je	got_irq
	jmp	scr_error
got_irq:
	shr	BX, CL			; compute actual IRQ value
	and	BL, 0Fh			;   and return in register BL

	;  Determine the configured DMA channel and return this value in BH.
	mov	AX, DX			; get the SCR value again
	and	AX, DMA_MASK		; isolate DMA channel configuration bits
	mov	BH, 3
	cmp	AX, DMA_3		; is it DMA channel 3 ?
	 je	got_dma			;    yes
	mov	BH, 5
	cmp	AX, DMA_5		; is it DMA channel 5 ?
	 je	got_dma			;    yes
	mov	BH, 6
	cmp	AX, DMA_6		; is it DMA channel 6 ?
	 je	got_dma			;    yes
	mov	BH, 7
	cmp	AX, DMA_7		; is it DMA channel 7 ?
	 je	got_dma			;    yes
	jmp	scr_error
got_dma:

	;  Determine the proper value to be used for ISACR2 and return it in CX.
	mov	CX, 0001h		; assume ISACR2 = XMAUSEL (ext. hdw)
	test	DX, UTP_PORT		; check SCR value: is "UTP" selected ?
	 jz	got_mau			;   no, "Other" port (BNC/FOIRL/AUI)
	push	bx
	mov	BX, FLAG_WORD_LOC	; not the "other" port, but ...
	call	rd_oper			; read the flag word from the EEPROM
	pop	bx
	test	DX, AUTO_SENSE_BIT	; is "Auto Select" configured ?
	 jz	got_mau			;   no, must be the UTP port
	mov	CX, 0002h		; yes, ISACR2 = ASEL (Auto Select)
got_mau:

	clc				; set CF=0 == "success"
	pop	dx			; restore caller's registers
	pop	ax
	ret				; return to caller
	
scr_error:
	stc				; set CF=1 == "error"
	pop	dx			; restore caller's registers
	pop	ax
	ret				; return to caller
		
VerifyBoard endp


;************************************************************************;
;*									*;
;*  read_adr_prom							*;
;*	Function: read the MAC (datalink) address of the board.		*;
;*	Input:	DS:(E)SI = pointer to caller's mac address buffer.	*;
;*		DI = base I/O address of the AT-1500 board		*;
;*	Output: the board's MAC address is placed in the caller's bfr.	*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

read_adr_prom	proc	near

	if	@Version GE 600
	ASSUME	POINTER_REGISTER : PTR BYTE
	endif

	push	ax			; save caller's registers
	push	dx
	mov	DX, DI			; DX = address prom I/O address
	in	ax, dx
	mov	word ptr [POINTER_REGISTER], ax
	add	dx, 2
	in	ax, dx
	mov	word ptr [POINTER_REGISTER+2], ax
	add	dx, 2
	in	ax, dx
	mov	word ptr [POINTER_REGISTER+4], ax
	pop	dx			; restore caller's registers
	pop	ax
	ret				; return to caller
	
read_adr_prom	endp


;************************************************************************;
;*									*;
;*  rd_oper								*;
;*	Function: do a complete word READ operation.			*;
;*	Input:	BX = EEPROM address to be read.				*;
;*		DI = base I/O address of the AT-1500 board		*;
;*	Output: AX = data read from EEPROM.				*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

rd_oper proc	near

	push	bx		; save caller's registers
	push	cx
	push	dx
	mov	cx, bx

	call	pulse_cs
	call	prep_load	; prepare the EEPROM for a new command
	mov	dx, SB
	call	wr_bit		; write a Start Bit
	mov	dl, READ
	and	cl, ADDR_MASK
	or	dl, cl
	call	wr_byte		; write a READ command code with the address

	xor	bx, bx		; bx = data read
	mov	cx, 16		; reading 16 bits
rd_next_bit1:
	shl	bx, 1
	call	rd_bit		; read a bit
	or	bx, ax		; merge it with accumulated bits so far
	loop	rd_next_bit1

	call	pulse_cs	; pulse CHIP SELECT to terminate the command
	mov	ax, bx		; return EEPROM value in AX
	pop	dx		; restore caller's registers
	pop	cx
	pop	bx
	ret			; return to caller

rd_oper endp

;************************************************************************;
;*									*;
;*  rd_bit								*;
;*	Function: Read 1 bit from the eeprom DO pin.			*;
;*	Input:	AX = the least significant bit (bit 0) is the data bit	*;
;*			read.						*;
;*		DI = base I/O address of the AT-1500 board		*;
;*	Output: nothing							*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

rd_bit	proc	near

	push	dx
	xor	ax, ax
	mov	al, CHIP_SEL
	or	al, CLOCK
	mov	dx, DI
	add	dx, VSW_OFFSET
	out	dx, al		; make CLOCK go high

	in	al, dx		; read D0
	and	al, DATA_OUT
	DELAY_750		; chip requires about 750ns hold time here

	push	ax
	mov	al, CHIP_SEL
	out	dx, al		; make CLOCK go low again
	pop	ax

	shr	ax, 1
	shr	ax, 1		; return DO in LSB (bit 0) of AX
	pop	dx
	ret

rd_bit	endp


;************************************************************************;
;*									*;
;*  wr_byte								*;
;*	Function: Write a byte to the eeprom.				*;
;*	Input:	DL = data byte to be written.				*;
;*		DI = base I/O address of the AT-1500 board.		*;
;*	Output:	nothing							*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

wr_byte proc	near

	push	ax			; save caller's registers
	push	cx

	mov	al, dl
	mov	cx, 8
next_bit:
	rol	al, 1
	mov	dl, al
	and	dl, 01h			; DL bit 0 = bit to write
	call	wr_bit			; write one bit of the byte
	loop	next_bit		; loop to write all bits

	pop	cx			; restore caller's registers
	pop	ax
	ret				; return to caller

wr_byte endp

;************************************************************************;
;*									*;
;*  wr_bit								*;
;*	Function: Write a bit to the EEPROM Data In pin.		*;
;*	Input:	DL = the least significant bit (bit 0) is the data bit	*;
;*			to be written.					*;
;*		DI = base I/O address of the AT-1500 board.		*;
;*	Output: nothing							*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

wr_bit	proc	near

	push	ax		; save caller's registers
	push	bx
	push	dx
	mov	bl, dl
	mov	al, CHIP_SEL
	and	bl, 01h
	or	al, bl
	mov	dx, DI
	add	dx, VSW_OFFSET
	out	dx, al		; write CS and DI out
	or	al, CLOCK
	out	dx, al		; present data bit with CLOCK high
	DELAY_750		; chip requires about 750ns hold time here
	mov	al, CHIP_SEL
	out	dx, al		; make the CLOCK go low again

	pop	dx		; restore registers
	pop	bx
	pop	ax
	ret			; return to caller

wr_bit	endp


;************************************************************************;
;*									*;
;*  prep_load								*;
;*	Function: Generate one clock cycle as required before sending	*;
;*			a new command code to the EEPROM.		*;
;*	Input:	DI = base I/O address of the AT-1500 board		*;
;*	Output:	nothing							*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

prep_load	proc	near

	push	ax
	push	dx
	mov	dx, DI
	add	dx, VSW_OFFSET
	mov	al, CHIP_SEL + CLOCK
	out	dx, al			; turn on CHIP SELECT and CLOCK
	DELAY_250		; chip requires about 250ns hold time here

	and	al, NOT CLOCK		; wait for 1 clock cycle
	out	dx, al			; turn off CLOCK

	pop	dx
	pop	ax
	ret				; return to caller

prep_load	endp

;************************************************************************;
;*									*;
;*  pulse_cs								*;
;*	function: to make CS pin in the eeprom go low for a short time,	*;
;*		  then go high again (required between commands).	*;
;*	input:	DI = base I/O address of the AT-1500 board		*;
;*	output: nothing							*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

pulse_cs	proc	near

	pushf			; save interrupt state
	cli			; disable interrupts
	call	cs_low		; drop CHIP_SEL for about 250ns
	call	cs_high		; raise CHIP_SEL again
	popf			; re-enable interrupts (if they were enabled)
	ret			; return to caller

pulse_cs	endp

;************************************************************************;
;*									*;
;*  cs_low								*;
;*	Function: to make the Chip Select pin in the EEPROM go low.	*;
;*	Input:	DI = base I/O address of the AT-1500 board		*;
;*	Output: nothing							*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

cs_low	proc	near

	push	ax		; save caller's registers
	push	dx
	mov	dx, DI
	add	dx, VSW_OFFSET
	xor	ax, ax
	out	dx, al		; turn off CHIP SELECT
	DELAY_250		; chip requires about 250ns between instructions
	pop	dx		; restore caller's registers
	pop	ax
	ret			; return to caller

cs_low	endp

;************************************************************************;
;*									*;
;*  cs_high								*;
;*	Function: to make the Chip Select pin in the EEPROM go high.	*;
;*	Input:	DI = base I/O address of the AT-1500 board		*;
;*	Output: nothing							*;
;*		registers used are preserved				*;
;*									*;
;************************************************************************;

cs_high	proc	near

	push	ax		; save caller's registers
	push	dx
	mov	dx, DI
	add	dx, VSW_OFFSET
	mov	al, CHIP_SEL
	out	dx, al		; turn on CHIP SELECT
	pop	dx		; restore caller's registers
	pop	ax
	ret			; return to caller

cs_high	endp


CODESEG ENDS
