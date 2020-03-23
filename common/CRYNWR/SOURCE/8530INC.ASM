FLAG	equ	07eh

; Register selects
R0	equ	0000h		; Register selects
R1	equ	0100h
R2	equ	0200h
R3	equ	0300h
R4	equ	0400h
R5	equ	0500h
R6	equ	0600h
R7	equ	0700h
R8	equ	0800h
R9	equ	0900h
R10	equ	0a00h
R11	equ	0b00h
R12	equ	0c00h
R13	equ	0d00h
R14	equ	0e00h
R15	equ	0f00h

NULLCODE	equ	0	; Null Code
POINT_HIGH	equ	8h	; Select upper half of registers
RES_EXT_INT	equ	10h	; Reset Ext. Status Interrupts
SEND_ABORT	equ	18h	; HDLC Abort
RES_RxINT_FC	equ	20h	; Reset RxINT on First Character
RES_Tx_P	equ	28h	; Reset TxINT Pending
ERR_RES		equ	30h	; Error Reset
RES_H_IUS	equ	38h	; Reset highest IUS

RES_Rx_CRC	equ	40h	; Reset Rx CRC Checker
RES_Tx_CRC	equ	80h	; Reset Tx CRC Checker
RES_EOM_L	equ	0C0h	; Reset EOM latch

; Write Register 1

EXT_INT_ENAB	equ	1h	; Ext Int Enabled
TxINT_ENAB	equ	2h	; Tx Int Enable
PAR_SPEC	equ	4h	; Parity is special condition

RxINT_DISAB	equ	0	; Rx Int Disable
RxINT_FCERR	equ	8h	; Rx Int on First Character Only or Error
INT_ALL_Rx	equ	10h	; Int on all Rx Characters or error
INT_ERR_Rx	equ	18h	; Int on error only

WT_RDY_RT	equ	20h	; Wait/Ready on R/T
WT_FN_RDYFN	equ	40h	; Wait/FN/Ready FN
WT_RDY_ENAB	equ	80h	; Wait/Ready Enable

; Write Register #2 (Interrupt Vector)

; Write Register 3

RxENABLE	equ	1h	; Rx Enable
SYNC_L_INH	equ	2h	; Sync Character Load Inhibit
ADD_SM		equ	4h	; Address Search Mode (SDLC)
RxCRC_ENAB	equ	8h	; Rx CRC Enable
ENT_HM		equ	10h	; Enter Hunt Mode
AUTO_ENAB	equ	20h	; Auto Enables
Rx5		equ	0h	; Rx 5 Bits/Character
Rx7		equ	40h	; Rx 7 Bits/Character
Rx6		equ	80h	; Rx 6 Bits/Character
Rx8		equ	0C0h	; Rx 8 Bits/Character

; Write Register 4

PAR_ENA		equ	1h	; Parity Enable
PAR_EVEN	equ	2h	; Parity Even/Odd

SYNC_ENAB	equ	0h	; Sync Modes Enable
SB1		equ	4h	; 1 stop bit/char
SB15		equ	8h	; 1.5 stop bits/char
SB2		equ	0ch	; 2 stop bits/char
MONSYNC		equ	0h	; 8 Bit Sync character
BISYNC		equ	10h	; 16 bit sync character
SDLC		equ	20h	; SDLC Mode (01111110 Sync Flag)
EXTSYNC		equ	30h	; External Sync Mode
X1CLK		equ	0h	; x1 clock mode
X16CLK		equ	40h	; x16 clock mode
X32CLK		equ	80h	; x32 clock mode
X64CLK		equ	0C0h	; x64 clock mode

; Write Register 5

TxCRC_ENAB	equ	1h	; Tx CRC Enable
RTS		equ	2h	; RTS
SDLC_CRC	equ	4h	; SDLC/CRC-16
TxENAB		equ	8h	; Tx Enable
SND_BRK		equ	10h	; Send Break
Tx5		equ	0h	; Tx 5 bits (or less)/character
Tx7		equ	20h	; Tx 7 bits/character
Tx6		equ	40h	; Tx 6 bits/character
Tx8		equ	60h	; Tx 8 bits/character
DTR		equ	80h	; DTR

; Write Register 6 (Sync bits 0-7/SDLC Address Field)

; Write Register 7 (Sync bits 8-15/SDLC 01111110)

; Write Register 8 (transmit buffer)

; Write Register 9 (Master interrupt control)
VIS	equ	1h	; Vector Includes Status
NV	equ	2h	; No Vector
DLC	equ	4h	; Disable Lower Chain
MIE	equ	8h	; Master Interrupt Enable
STATHI	equ	10h	; Status high
NORESET	equ	0h	; No reset on write to R9
CHRB	equ	40h	; Reset channel B
CHRA	equ	80h	; Reset channel A
FHWRES	equ	0c0h	; Force hardware reset

; Write Register 10 (misc control bits)
BIT6	equ	1h	; 6 bit/8bit sync
LOOPMODE equ	2h	; SDLC Loop mode
ABUNDER	equ	4h	; Abort/flag on SDLC xmit underrun
MARKIDLE equ	8h	; Mark/flag on idle
GAOP	equ	10h	; Go active on poll
NRZ	equ	0h	; NRZ mode
NRZI	equ	20h	; NRZI mode
FM1	equ	40h	; FM1 (transition = 1)
FM0	equ	60h	; FM0 (transition = 0)
CRCPS	equ	80h	; CRC Preset I/O

;  Write Register 11 (Clock Mode control)
TRxCXT	equ	0h	; TRxC = Xtal output
TRxCTC	equ	1h	; TRxC = Transmit clock
TRxCBR	equ	2h	; TRxC = BR Generator Output
TRxCDP	equ	3h	; TRxC = DPLL output
TRxCOI	equ	4h	; TRxC O/I
TCRTxCP	equ	0h	; Transmit clock = RTxC pin
TCTRxCP	equ	8h	; Transmit clock = TRxC pin
TCBR	equ	10h	; Transmit clock = BR Generator output
TCDPLL	equ	18h	; Transmit clock = DPLL output
RCRTxCP	equ	0h	; Receive clock = RTxC pin
RCTRxCP	equ	20h	; Receive clock = TRxC pin
RCBR	equ	40h	; Receive clock = BR Generator output
RCDPLL	equ	60h	; Receive clock = DPLL output
RTxCX	equ	80h	; RTxC Xtal/No Xtal

; Write Register 12 (lower byte of baud rate generator time constant)

; Write Register 13 (upper byte of baud rate generator time constant)

; Write Register 14 (Misc control bits)
BRENABL	equ	1h	; Baud rate generator enable
BRSRC	equ	2h	; Baud rate generator source
DTRREQ	equ	4h	; DTR/Request function
AUTOECHO equ	8h	; Auto Echo
LOOPBAK	equ	10h	; Local loopback
SEARCH	equ	20h	; Enter search mode
RMC	equ	40h	; Reset missing clock
DISDPLL	equ	60h	; Disable DPLL
SSBR	equ	80h	; Set DPLL source = BR generator
SSRTxC	equ	0a0h	; Set DPLL source = RTxC
SFMM	equ	0c0h	; Set FM mode
SNRZI	equ	0e0h	; Set NRZI mode

; Write Register 15 (external/status interrupt control)
ZCIE	equ	2h	; Zero count IE
DCDIE	equ	8h	; DCD IE
SYNCIE	equ	10h	; Sync/hunt IE
CTSIE	equ	20h	; CTS IE
TxUIE	equ	40h	; Tx Underrun/EOM IE
BRKIE	equ	80h	; Break/Abort IE


; Read Register 0
Rx_CH_AV	equ	1h	; Rx Character Available
ZCOUNT		equ	2h	; Zero count
Tx_BUF_EMP	equ	4h	; Tx Buffer empty
DCD		equ	8h	; DCD
SYNC_HUNT	equ	10h	; Sync/hunt
CTS		equ	20h	; CTS
TxEOM		equ	40h	; Tx underrun
BRK_ABRT	equ	80h	; Break/Abort

; Read Register 1
ALL_SNT		equ	1h	; All sent
; Residue Data for 8 Rx bits/char programmed
RES3		equ	8h	; 0/3
RES4		equ	4h	; 0/4
RES5		equ	0ch	; 0/5
RES6		equ	2h	; 0/6
RES7		equ	0ah	; 0/7
RES8		equ	6h	; 0/8
RES18		equ	0eh	; 1/8
RES28		equ	0h	; 2/8
; Special Rx Condition Interrupts
PAR_ERR		equ	10h	; Parity error
Rx_OVR		equ	20h	; Rx Overrun Error
CRC_ERR		equ	40h	; CRC/Framing Error
END_FR		equ	80h	; End of Frame (SDLC)

; Read Register 2 (channel b only) - Interrupt vector

; Read Register 3 (interrupt pending register) ch a only
CHBEXT	equ	1h		; Channel B Ext/Stat IP
CHBTxIP	equ	2h		; Channel B Tx IP
CHBRxIP	equ	4h		; Channel B Rx IP
CHAEXT	equ	8h		; Channel A Ext/Stat IP
CHATxIP	equ	10h		; Channel A Tx IP
CHARxIP	equ	20h		; Channel A Rx IP

; Read Register 8 (receive data register)

;  Read Register 10  (misc status bits)
ONLOOP		equ	2h		; On loop
LOOPSEND	equ	10h		; Loop sending
CLK2MIS		equ	40h		; Two clocks missing
CLK1MIS		equ	80h		; One clock missing

; Read Register 12 (lower byte of baud rate generator constant)

; Read Register 13 (upper byte of baud rate generator constant)

; Read Register 15 (value of WR 15)

