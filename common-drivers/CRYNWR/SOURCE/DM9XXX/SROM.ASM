PAGE	,132
NAME	SROM
TITLE	SROM  --  UMC Internal Use Only

;***************************************************************************
;*
;***************************************************************************
;
; This file contains all of the routines which manage the 9346 SROM.
;
; Originator: Spenser Tsai
;
; Functions:
;	. SROMDelay
;	. MakeSureSROMIdle
;	. ReadSROMWord
;	. ReadSROM
;
; Maintainers:
;
; Revision History:
;
.xlist			; Disable listing the include files
include maccrc.asm
.list			; Enable listing

;;SET_CPU_TYPE
.386p


SROM_Word_Address	DW 0	; Word address for word read from SROM
SROM_Data_Read		DD 0	; Holds in low part a word read from SROM

;CR9 Register Bit Definition:
;----------------------------
CR9_CRCS	EQU	0001h		;Chip_Select to EEPROM
CR9_CRCLK	EQU	0002h		;Clock to EEPROM
CR9_CRDIN	EQU	0004h		;Data_In to EEPROM
CR9_CRDOUT	EQU	0008h		;Data_Out to EEPROM
CR9_ERS 	EQU	 800h		;EEPROM Selected
CR9_BRS 	EQU	1000h		;Boot ROM Selected
CR9_MWC 	EQU	2000h		;Memory Write Control
CR9_MRC 	EQU	4000h		;Memory Read Control
CR9_MDCLKH	EQU    10000h		;MII Management Clock
CR9_MDOUTH	EQU    20000h		;MII Management Data_Out
CR9_MREAD	EQU    40000h		;MII Management Read/Write Mode Selection
CR9_MDIN	EQU    80000h		;MII Management Data_In

CR9_MDCLKL	EQU    00000h		;MII Management Clock Low
CR9_MDOUTL	EQU    00000h		;MII Management Data_Out Low
CR9_MWRITE	EQU    00000h		;MII Management Read/Write Mode Selection

SROM_MAX_DELAY		EQU	25
SROM_ADDRESS_BIT_NUM	EQU	6

	PAGE
;*************
;* SROMDelay *
;*************
;
;	SROM_93LC46B spec calls for ~840 nSEC of delay between various
;	activities.
;	PortReadTickCounter gives 419 nsec per count. We therefore have to
;	delay ~ 2 - 3 count ticks. For extra caution we wait 4 ticks.
;
	PUBLIC	SROMDelay
SROMDelay  proc    near
	cli
	push	ax
	push	bx
	call	PortReadTickCounter	;Get initial value, Return counter value = AX
	mov	bx, ax			;Save start value

Srom_loop:				 ; Loop till 4 ticks have gone by
	call	PortReadTickCounter
	neg	ax
	add	ax, bx			;Get difference
	cmp	ax, 4
	jb	SHORT Srom_loop
	pop	bx
	pop	ax
	sti
	ret
SROMDelay  endp


;+****************************************************************************+
; ReadSROMWord
;
;  Read the SROM WORD content from MII Management Interface.
;
;  Entrys:	SI = Offset Address of the SROM content
;
;  Returns:	DI = Read SROM Data (Word)
;
;  Preserved :	None
;
;  Called by:	ReadSROM
;
;-****************************************************************************-
ReadSROMWord	  proc	  near
	push	si
	push	di
	push	bx
	push	cx
	push	dx
	mov	si, ax

	;SromRWInit - SROM Read Write Init
	;---------------------------------
	mov	dx, p_CR9
	mov	eax, CR9_MWC or CR9_ERS 	;Select SRom access
	out	dx, eax

	;SromIdle - SROM Make Sure Idle
	;------------------------------
	or	al, CR9_CRCS			;Select SRom
	mov	ecx, SROM_MAX_DELAY
GenerateRWSequenceSignals:
	or	al, CR9_CRCLK			;Clock UP
	out	dx, eax
	call	Delay10us

	and	al, not CR9_CRCLK		;Clock DOWN
	out	dx, eax
	call	Delay10us
	loop	GenerateRWSequenceSignals

	and	al, not CR9_CRCS		;DeSelect SRom
	out	dx, eax
	call	Delay10us

	;SromRdOp - SROM Read Operation (Out CR9, 1-1-0 Sequence)
	;Initiate Read data sequence and signals
	;---------------------------------------------------------
	or	al, CR9_CRCS			;Select SRom

	;1. Write 1
	;Output READ command to the SROM (sequence of 110)
	;-------------------------------------------------
	or	ax, CR9_CRDIN			;Write 1
	out	dx, eax

	or	ax, CR9_CRCLK			;clock UP
	out	dx, eax
	call	Delay10us

	and	ax, NOT CR9_CRCLK		;Clock DOWN
	out	dx, eax
	call	Delay10us

	;2. Write 1
	;----------
	out	dx, eax 			;Write 1

	or	ax, CR9_CRCLK			;Clock UP
	out	dx, eax
	call	Delay10us
						;Clock DOWN
	and	ax, NOT CR9_CRCLK
	out	dx, eax
	call	Delay10us

	;3. Write 0
	;----------
	and	ax, NOT CR9_CRDIN
	out	dx, eax 			;Write 0

	or	ax, CR9_CRCLK			;Clock UP
	out	dx, eax
	call	Delay10us
						;Clock DOWN
	and	ax, NOT CR9_CRCLK
	out	dx, eax
	call	Delay10us

	;SromAddressSetup - SROM Address Setup
	;Output the WORD Address of the SROM (Bit by Bit from MSB to LSB)
	;----------------------------------------------------------------
	mov	ecx, SROM_ADDRESS_BIT_NUM	;Here we assume size<=8Bit
						;Cx holds the number of address bits
	push	si				;SROM index

RSW_WriteAddressBitx:
	pop	si
	push	si				;for correct shifting
	dec	cl
	shr	si, cl				;shift the appropriate address bit
	inc	cl				;restore cl
	and	si, 1				;mask all irrelevant address bits
	shl	si, 2				;Align to Data bit loacation (in CR9)
	and	ax, not CR9_CRDIN		;Clear prev. address bit
	or	ax, si				;Move the address bit to ax
	out	dx, eax 			;Write it to CR9

	or	ax, CR9_CRCLK
	out	dx, eax 			;Clock UP
	call	Delay10us

	and	ax, not CR9_CRCLK
	out	dx, eax 			;Clock DOWN
	call	Delay10us

	loop	RSW_WriteAddressBitx

	pop	si				;Restor SI

	;Verify that the SROM output data became now 0.
	;----------------------------------------------
	in	eax, dx
	test	eax, CR9_CRDOUT
	jnz	SHORT RSW_ReadFailedx

	;SromDataIn - SROM Data In
	;Input the WORD of data from the SROM
	;------------------------------------
	xor	di, di
	mov	ecx, 16

RSW_ReadBitx:
	;Clock UP (with appropriate signals)
	;-----------------------------------
	mov	eax, CR9_MWC or CR9_ERS or CR9_CRCS or CR9_CRCLK
	out	dx, eax
	call	Delay10us

	;Read the "CX" bit in the word
	;-----------------------------
	in	eax, dx
	shr	ax, 3			;Mov the databit to Bit0
	and	ax, 1			;Clear all othe bits
	dec	cx
	shl	ax, cl			;Mov the data bit to its relative
	inc	cx			;location in WORD

	;Store the bit in the temporary data storage
	;-------------------------------------------
	or	di, ax

	;SromLeave - SROM Leave
	;Clock DOWN (with appropriate signals)
	;-------------------------------------
	mov	eax, CR9_MWC or CR9_ERS or CR9_CRCS
	out	dx, eax
	call	Delay10us

	loop	RSW_ReadBitx

	mov	di,di
	mov	di,di
	mov	di,di
	mov	di,di

	;Negate the CS (chip select) to end the SROM command
	;---------------------------------------------------
	mov	eax, CR9_MWC or CR9_ERS
	out	dx, eax
	call	Delay10us

RSW_ReadFailedx:
	mov	ax, di

	pop	dx
	pop	cx
	pop	bx
	pop	di
	pop	si

	ret
ReadSROMWord	  endp

;+****************************************************************************+
; Delay419ns
;
;  Delay 419 nsec. (1 tick)
;
;  Entrys:	DelayTickCount
;		Interrupts disabled
;
;  Returns:	None
;		Interrupts disabled
;
;  Preserved :	None
;
;  Called by:	Delay10us
;
;-****************************************************************************-

DelayTickCount	dw	0

Delay419ns	proc	near

	push	eax
	push	ebx
	push	ecx

	;Read the Timer Tick Counter
	;(The Timer Tick Counter decreases from 65536 to 0 by 2)
	;-------------------------------------------------------
	call	PortReadTickCounter
	mov	bx, ax				;BX = Start Tick Count (decrease)
WaitDelay419nsLoop:
	call	PortReadTickCounter
	mov	cx, bx
	sub	cx, ax				;AX = Last Tick Count (decrease)

	cmp	cx, DelayTickCount
	jb	WaitDelay419nsLoop

	pop	ecx
	pop	ebx
	pop	eax
	ret

Delay419ns	endp


;+****************************************************************************+
; Delay1us
;
;  Delay 1 usec. (about 2 ticks)
;
;  Entrys:	Time delay in Counts (1 Count=419nsec) passed on stack.
;		Interrupts disabled
;
;  Returns:	None
;		Interrupts disabled
;
;  Preserved :	None
;
;  Called by:	ResetMIIPHY, Delay500us
;
;-****************************************************************************-

Delay1us  proc	  near

	mov	DelayTickCount, 2		;2 ticks = 1 usec
	call	Delay419ns
	ret

Delay1us  endp

;+****************************************************************************+
; Delay10us
;
;  Delay 10 usec for waiting DM9100 NIC Reset stability.
;
;  Entrys:	None
;		Interrupts disabled
;
;  Returns:	None
;
;  Preserved :	None
;
;  Called by:	ResetDM910X, ResetMIIPHY
;
;-****************************************************************************-

Delay10us	proc	near

	push	ecx

	mov	ecx, 10 		;Delay 10 usec
WaitDelay10usLoop:
	call	Delay1us
	loop	WaitDelay10usLoop

	pop	ecx
	ret

Delay10us	endp

;=================================================================
    PAGE

;************
;* ReadSROM *
;************
; Reads the entire SROM into an internal driver buffer (which is later reused
; for receive buffer.
; It's legacy if CRC check error.
;
; CX - Holds num of words to read.
; SI - (Near) pointer into where to read.
;
; Return: Carry set if read failed
;
	ALIGN 4
	PUBLIC ReadSROM
ReadSROM	PROC	NEAR
	push	ax
	push	bx
	push	si

	mov	bx, 0  ; Offset in SROM
	mov	ax, bx	;; AX=BX=0

read_loop:
	call	ReadSROMWord	;; Return Word = AX
;;;;	jc	rs_exit

	mov	[si], al
	inc	si
	mov	[si], ah
	inc	si
	inc	bx		;; Num of word counter
	mov	ax, bx		;; SROM address
	loop	read_loop

; Check validity of CRC
;-----------------------
	sub	si, 2
	mov	bx, WORD PTR [si]   ; BX stores two low bytes of CRC
	mov	cx, 126
	sub	si, cx

	push	eax		    ; save registers as CRC calc destoyes
	push	ebx
	push	di
	push	si
	pushf

	call	CalcCRC

	popf
	pop	si
	pop	di
	pop	ebx
	pop	eax

	add	si, 126 	   ; Compare calculated CRC
	mov	cx, WORD PTR [si]
	cmp	cx, bx
	je	rs_exit

	stc			  ; Error: Incorrect CRC

	rs_exit:
	pop	si
	pop	bx
	pop	ax
	ret
ReadSROM ENDP


