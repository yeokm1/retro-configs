;***********************************************************************
;
;              ---------------------------------------------
;------------- Clock I/O for DS-1216E SmartWatch Clock Chip ------------
;              ----------------------------------------------
;
;	Copyright (C), 1986, by Zenith Data Systems Corporation
;
;***********************************************************************

;***********************************************************************
;	This file contains the 'I/O' drivers for the SmartWatch.
; This code is linked with CLOCK to produce an executable file (see
; CLOCK.C for more details).
;
; EXTREMELY IMPORTANT NOTE!!! - - -
;
;	The SmartWatch works by strobing its host EPROM on and off.
; Since this code accesses the SmartWatch, it is necessary to keep
; ALL interrupts disabled while communicating with the SmartWatch.
; As a tricky side effect, it is virtually impossible to DEBUG this
; code, since stopping the processor prior to completing the SmartWatch
; initialization will leave the SmartWatch disabled (the state machine
; will reject the extra ROM reads required to run DEBUG, etc).
; Alternately, stopping the program between InitClock and completion
; of ReadClock or WriteClock will cause the debugger to attempt to
; access a now non-existant ROM.  Consequently, be VERY careful when
; modifying this file!!!  On the other hand, CLOCK runs with the clock
; I/O turned off, so it may be debugged normally.
;***********************************************************************

@CODE 	SEGMENT BYTE PUBLIC 'CODE'
	ASSUME	CS:@CODE

;***********************************************************************
;		     G E N E R A L   E Q U A T E S
;***********************************************************************
ROMSEG		EQU	0F000H		;Location of ROM segment
DOS		EQU	21H		;DOS Function-Call Interrupt
DOSSDATE	EQU	2BH		;DOS Set-Date function
DOSSTIME	EQU	2DH		;DOS Set-Time function


;***********************************************************************
;	  D S - 1 2 1 6 E   C L O C K   I / O   E Q U A T E S
;***********************************************************************
WRITE_0		EQU	0F002H		;Set Read/Write=Write, D0=00H
WRITE_1		EQU	0F003H		;Set Read/Write=Write, D0=01H
READ		EQU	0F004H		;Set Read/Write=Read,  D0=XX
FSECONDS	EQU	0		;Fractional seconds register
SECONDS		EQU	1		;Seconds register
MINUTES		EQU	2		;Minutes register
HOURS		EQU	3		;Hours register
DAY		EQU	4		;Current day of week
DATE		EQU	5		;Current date in month
MONTH		EQU	6		;Current month number
YEAR		EQU	7		;Current year number


;***********************************************************************
;			  D O S   E Q U A T E S
;***********************************************************************
DOS		EQU	21H		;DOS Function-Call Interrupt
DOSSDATE	EQU	2BH		;DOS Set-Date function
DOSSTIME	EQU	2DH		;DOS Set-Time function


;***********************************************************************
;     D S - 1 2 1 6 E   I N I T I A L I Z A T I O N   P A T T E R N
;***********************************************************************
CLKPAT		DB	0C5H,03AH,0A3H,05CH,0C5H,03AH,0A3H,05CH ;Pattern to wake clock up
BCDTBL		DB	0,10,20,30,40,50,60,70,80,90 ;Values for BCD digits


;***********************************************************************
; InitClock:
;
;	InitClock is called to turn on the clock driver.  This routine
; effectively removes the system ROM from the system, so it is vital
; that the caller leave interrupts disabled.  The routine works by
; sending the complex 64-state data pattern to the SmartWatch socket
; which turns the device on.
;***********************************************************************
INITCLOCK PROC NEAR
	CLI				;Keep interrupts out during clock I/O
	CLD				;Use forward string moves
	PUSH	SI			;Save register SI
	PUSH	ES			;Save register ES
	MOV	AX,ROMSEG		;Point to the monitor ROM segment
	MOV	ES,AX			;Point ES to segment for reads
	MOV	AH,ES:[READ]		;Reset the clock's state machine
	MOV	CX,8			;Get number of bytes in data pattern
	MOV	SI,OFFSET CS:CLKPAT	;Point to the clock state pattern
IC1:	PUSH	CX			;Save the current byte count
	MOV	CX,8			;Set the bit/byte count
	LODS	CS: BYTE PTR [SI]	;Get a byte of the pattern
IC2:	SHR	AL,1			;Get a bit into the carry flag
	JC	IC3			;Bit set - write a 1 bit to clock
	MOV	AH,ES:[WRITE_0]		;Write a 0 bit to the clock (fake write)
	JMP	IC4			;Continue with the next bit
IC3:	MOV	AH,ES:[WRITE_1]		;Write a 1 bit to the clock (fake write)
IC4:	LOOP	IC2			;Continue with this byte
	POP	CX			;Restore the byte counter
	LOOP	IC1			;Loop until clock is enabled
	POP	ES			;Restore register ES
	POP	SI			;Restore register SI
	RET				;Return to the caller with clock on
INITCLOCK ENDP


;***********************************************************************
; ReadClk:
;
;	ReadClk is called to read all 64 data bits of the clock.
; The format of the data stream is as documented in the DS-1216E
; SmartWatch data sheet.
;
; Input:
;	Stack Parm 1: Pointer to 8-byte buffer to contain chip data
;***********************************************************************
READCLK PROC NEAR
	PUBLIC	READCLK
	PUSH	BP			;Save the current frame pointer
	MOV	BP,SP			;Point into the current stack
	CALL	INITCLOCK		;Initialize and enable the clock
	PUSH	ES			;Save register ES
	MOV	AX,ROMSEG		;Point to the monitor ROM segment
	MOV	ES,AX			;Point ES to segment for reads
	MOV	SI,[BP+4]		;Point to the data pattern to write
	MOV	CX,8			;Get number of bytes in data pattern
RC1:	PUSH	CX			;Save the current byte count
	MOV	CX,8			;Set the bit/byte count
	XOR	AL,AL			;Clear the output 'bit array'
RC2:	MOV	AH,ES:[READ]		;Read a bit of the clock
	SHR	AH,1			;Place the bit into the carry flag
	RCR	AL,1			;ROL the bit into the output byte
	LOOP	RC2			;Continue with this byte
	MOV	BYTE PTR [SI],AL	;Store a byte into the output array
	INC	SI			;Point to the next buffer location
	POP	CX			;Restore the byte counter
	LOOP	RC1			;Loop until entire clock is read
	POP	ES			;Restore register ES
	POP	BP			;Restore the old frame pointer
	STI				;Enable interrupts - CLOCK now off
	RET				;Return to the caller with clock on
READCLK ENDP


;***********************************************************************
; WriteClk:
;
;	WriteClk is called to write all 64 data bits to the clock.
; The format of the data stream is as documented in the DS-1216E
; SmartWatch data sheet.
;
; Input:
;	Stack Parm 1: Pointer to 8-byte buffer to be written to chip
;***********************************************************************
WRITECLK PROC NEAR
	PUBLIC	WRITECLK
	PUSH	BP			;Save the current frame pointer
	MOV	BP,SP			;Point into the current stack
	CALL	INITCLOCK		;Initialize and enable the clock
	PUSH	ES			;Save register ES
	MOV	AX,ROMSEG		;Point to the monitor ROM segment
	MOV	ES,AX			;Point ES to segment for reads
	MOV	CX,8			;Get number of bytes in data pattern
	MOV	SI,[BP+4]		;Point to the data pattern to write
WC1:	PUSH	CX			;Save the current byte count
	MOV	CX,8			;Set the bit/byte count
	LODSB				;Get a byte from the clock
WC2:	SHR	AL,1			;Get a bit into the carry flag
	JC	WC3			;Bit set - write a 1 bit to clock
	MOV	AH,ES:[WRITE_0]		;Write a 0 bit to the clock (fake write)
	JMP	WC4			;Continue with the next bit
WC3:	MOV	AH,ES:[WRITE_1]		;Write a 1 bit to the clock (fake write)
WC4:	LOOP	WC2			;Continue with this byte
	POP	CX			;Restore the byte counter
	LOOP	WC1			;Loop until clock is written
	POP	ES			;Restore register ES
	POP	BP			;Restore the frame pointer
	STI				;Enable interrupts - CLOCK now off
	RET				;Return to the caller with clock written
WRITECLK ENDP


;***********************************************************************
; SDOSTim: (CLOCKBF)
;
;	SDOSTim is called to translate the current time-of-day
; into the data format used by MS-DOS.  The routine then sets the
; time-of-day via the standard DOS function requests.
;
; Input:
;	Stack Parm 1: Pointer to string containing the time
;***********************************************************************
SDOSTIM PROC NEAR
	PUBLIC	SDOSTIM
	PUSH	BP			;Save the current frame pointer
	MOV	BP,SP			;Get the new frame pointer in BP
	MOV	SI,[BP+4]		;Point to the clock buffer
	MOV	AL,[SI+DATE]		;Get the current date
	CALL	BCDTOBIN		;Convert it to binary
	MOV	DL,AL			;Place the date in DL
	MOV	AL,[SI+MONTH]		;Get the current month
	CALL	BCDTOBIN		;Convert it to binary
	MOV	DH,AL			;Place the month in DH
	MOV	AL,[SI+YEAR]		;Get the current year number
	CALL	BCDTOBIN		;Convert it to binary
	MOV	CL,AL			;Place the year in CL
	XOR	CH,CH			;Extend the year to a word
	ADD	CX,1900			;Make the year start with at least 1900
	CMP	CX,1980			;Is this at least 1985?
	JAE	SDT1			;Yes - this is a 19XX year!
	ADD	CX,100			;No, must be a 20XX year
SDT1:	MOV	AH,DOSSDATE		;Get command to set the current date
	INT	DOS			;Set the date to the present date
	MOV	AL,[SI+FSECONDS]	;Get the current fractional seconds
	CALL	BCDTOBIN		;Convert it to binary
	MOV	DL,AL			;Place the fractional seconds in DL
	MOV	AL,[SI+SECONDS]		;Get the current seconds
	CALL	BCDTOBIN		;Convert it to binary
	MOV	DH,AL			;Place the seconds in DH
	MOV	AL,[SI+MINUTES]		;Get the current minutes value
	CALL	BCDTOBIN		;Convert it to binary
	MOV	CL,AL			;Place the minutes in CL
	MOV	AL,[SI+HOURS]		;Get the current hours value
	AND	AL,3FH			;Mask out the control flags
	CALL	BCDTOBIN		;Convert it to binary
	MOV	CH,AL			;Place the hours count in CH
	MOV	AH,DOSSTIME		;Get command to set the current date
	INT	DOS			;Set the date to the present date
	POP	BP			;Restore the old frame pointer
	RET				;Exit to the operating system
SDOSTIM ENDP


;***********************************************************************
; BCDTOBIN: (BCD)
;
;	BCDToBin is called to translate a single packed-BCD byte into
; a binary number.
;
; Input:
;	AL: BCD-encoded digit pair
;
; Output:
;	AH: Binary-encoded value of BCD digits
;***********************************************************************
BCDTOBIN PROC NEAR
	PUBLIC	BCDTOBIN
	PUSH	BX			;Save register BX
	PUSH	CX			;Save register CX
	MOV	BL,AL			;Save the byte in BL
	MOV	CL,4			;Set shift count to nibble size
	SHR	BL,CL			;Get the M.S. digit in L.S. nibble
	XOR	BH,BH			;Extend it to a word
	MOV	BL,CS:BCDTBL[BX]	;Convert M.S. digit to binary value
	AND	AL,0FH			;Mask out the L.S. digit in AL
	ADD	AL,BL			;Add in the L.S. digit to get total
	POP	CX			;Restore register CX
	POP	BX			;Restore register BX
	RET
BCDTOBIN ENDP


@CODE ENDS


	END

