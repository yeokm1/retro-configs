;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Definitions for 583 and 584 ISA bus interface chips
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MSR			equ	00h	; Memory Select Register
ICR			equ	01h	; Interface Configuration Register
IAR			equ	02h	; I/O Address Register
BIO			equ	03h	; BIOS ROM Address Register
IRR			equ	04h	; Interrupt Request Register
LAAR			equ	05h	; LA Address Register
;NOT_USED		equ	06h	; (not used)
GP2			equ	07h	; General Purpose Data Latch 2
LAR0			equ	08h	; LAN Address Register 0
LAR1			equ	09h	; LAN Address Register 1
LAR2			equ	0Ah	; LAN Address Register 2
LAR3			equ	0Bh	; LAN Address Register 3
LAR4			equ	0Ch	; LAN Address Register 4
LAR5			equ	0Dh	; LAN Address Register 5

;------------------------------------------------------------------------------

; Definitions for Memory Select Register MSR (offset 00h)

RST			equ	80h	; Reset bit
MENB			equ	40h	; Memory enable bit
RAM_ADDR_MASK		equ	3Fh	; Mask to isolate RAM address

;------------------------------------------------------------------------------

; Definitions for Interface Configuration Register ICR (offset 01h)

STO			equ	80h	; Non-Volatile EEROM Store
RIO			equ	40h	; Recall I/O Address from EEPROM
RX7			equ	20h	; Recall all but I/O Address
RLA			equ	10h	; Recall LAN Address
MSZ			equ	08h	; Shared Memory Size flag
IR2			equ	04h	; Used with IRR bits 6 & 5 for IRQ
OTHER			equ	02h	; BIOS/EEROM address reg. select 0==BIO
BIT16			equ	01h	; R/W in 8 bit slot, R=1 16 bit slot.

;------------------------------------------------------------------------------

; Definitions for BIO Address Register (offset 03h)	ICR-OTHER = 0
;                 EEROM Address Register		ICR-OTHER = 1

ROM_SIZE_MASK		equ	0C0h	; Isolates ROM size 
;SINT			equ	01h	; Software interrupt
ROM_BASE_MASK		equ	37h	; Isolates ROM address
EEROM_ADDR_MASK		equ	0F0h	; Isolates EEROM address
RAM_IN_ROM		equ	08h	; 32K RAM installed in ROM socket
EEROM_PAGE_MASK		equ	07h	; Isolates EEROM page

;------------------------------------------------------------------------------

; Definitions for Interrupt Request Register IRR (offset 04h)

IEN			equ	80h	; Interrupt Enable
IR1			equ	40h	; IRQ index 1
IR0			equ	20h	; IRQ index 0
IRQ_MASK		equ	60h	; Isolates IR0 and IR1
FLSH			equ	10h	; Flash Memory in ROM socket
OUT3			equ	08h	; 
OUT2			equ	04h	; 
LITD			equ	02h	; Link Integrity Test Disable (W cards)
ZEROWS8			equ	01h	; 8-bit Zero Wait State

;------------------------------------------------------------------------------

; Definitions for LA Address Register LAAR (offset 05h)

MEM16EN			equ	80h	; Enable 16-bit Host memory access
LAN16EN			equ	40h	; Enable 16-bit NIC memory access
ZEROWS16		equ	20h	; 16-bit Zero Wait-State 
LA_MASK			equ	1Fh	; Isolates LA23-19

;------------------------------------------------------------------------------

; Definitions for Init Jumper Register (offset 06h)

;NOT_USED		equ	80h	; 
IN2			equ	40h	; 
IN1			equ	20h	; 
;NOT_USED		equ	10h	; 
;NOT_USED		equ	08h	; 
INIT2			equ	04h	; "Hard" config IO=300h, IRQ=10
INIT1			equ	02h	; "Hard" config IO=280h, IRQ=3
INIT0			equ	01h	; "Hard" config ROM=D800

;------------------------------------------------------------------------------

; Definitions for General Purpose Register GP2 (offset 07h)

;NOT_USED		equ	80h	; 
;NOT_USED		equ	40h	; 
;NOT_USED		equ	20h	; 
;NOT_USED		equ	10h	; 
;NOT_USED		equ	08h	; 
;NOT_USED		equ	04h	; 
;NOT_USED		equ	02h	; 
;NOT_USED		equ	01h	; 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Definitions for 593 and 594 MCA bus interface chips
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MER			equ	00h	; Memory Select Register
IMCCR			equ	05h	; Interrupt mask and Control Reg. (593)
CNTREG			equ	05h	; Control Register (594)
REVREG			equ	07h	; Revision Register (594)
;GPR			equ	07h	; General Purpose Register (593)
;LAR0			equ	08h	; LAN Address Register 0
;LAR1			equ	09h	; LAN Address Register 1
;LAR2			equ	0Ah	; LAN Address Register 2
;LAR3			equ	0Bh	; LAN Address Register 3
;LAR4			equ	0Ch	; LAN Address Register 4
;LAR5			equ	0Dh	; LAN Address Register 5

;------------------------------------------------------------------------------

;; Definitions for Memory Select Register MSR (offset 00h)
;
;RST			equ	80h	; Reset bit
;MENB			equ	40h	; Memory enable bit

;------------------------------------------------------------------------------

; Definitions for Control Register	CNTREG (offset 05h) (594)
;					IMCCR  (offset 05h) (593)

RMS2			equ	40h	; BIOSROM Map select 2 (594)
RMS1			equ	20h	; BIOSROM Map select 1 (594)
RMS0			equ	10h	; BIOSROM Map select 0 (594)
SINT			equ	08h	; Software interrupt (594)
EIL			equ	04h	; IRQ Enable bit
CLAIM1			equ	02h	; Claim bit 1 (594)
CLAIM0			equ	01h	; Claim bit 0 (594)

;------------------------------------------------------------------------------

; Definitions for Revision Register REVREG (offset 07h) (594)

VER3			equ	80h	; Silicon Revision bit 3
VER2			equ	40h	; Silicon Revision bit 2
VER1			equ	20h	; Silicon Revision bit 1
VER0			equ	10h	; Silicon Revision bit 0
RW3			equ	08h	; General Purpose bit 3
RW2			equ	04h	; General Purpose bit 2
RW1			equ	02h	; General Purpose bit 1
RW0			equ	01h	; General Purpose bit 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Defs for National Semiconductor DP8390 and WD WD83C690
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;-------------------Page 0 registers

CR		equ	10h	; Command register		R/W
PSTART		equ	11h	; Page Start register 		W
PSTOP		equ	12h	; Page Stop register		W
BNRY		equ	13h	; Boundary register		R/W
TSR		equ	14h	; Transmit Status register	R
TPSR		equ	14h	; Trasmit Page Start register	W
TBCR0		equ	15h	; Transmit byte count reg. 0	W
NCR		equ	15h	; Number of collisions reg.	R
TBCR1		equ	16h	; Transmit byte count reg. 1	W
FIFO		equ	16h	; FIFO				R
ISR		equ	17h	; Interrupt Status register	R/W
RBCR0		equ	1ah	; Remote Byte Count reg. 0	W
RBCR1		equ	1bh	; Remote Byte Count reg. 1	W
RSR		equ	1ch	; Receive Status register	R
RCONR		equ	1ch	; Receive Configuration reg.	W
TCR		equ	1dh	; Transmit Configuration reg.	W
CNTR0		equ	1dh	; FAE counter			R
DCR		equ	1eh	; Data Configuration register	W
CNTR1		equ	1eh	; CRC counter			R
IMR		equ	1fh	; Interrupt Status register	W
CNTR2		equ	1fh	; Missed Packet Counter		R

;-------------------Page 1 registers

PAR0		equ	11h	; Physical Address register 0	R/W
PAR1		equ	12h	; Physical Address register 1	R/W
PAR2		equ	13h	; Physical Address register 2	R/W
PAR3		equ	14h	; Physical Address register 3	R/W
PAR4		equ	15h	; Physical Address register 4	R/W
PAR5		equ	16h	; Physical Address register 5	R/W
CURR		equ	17h	; Current Page register		R/W
MAR0		equ	18h	; Multicast Address register 0	R/W
MAR1		equ	19h	; Multicast Address register 1	R/W
MAR2		equ	1Ah	; Multicast Address register 2	R/W
MAR3		equ	1Bh	; Multicast Address register 3	R/W
MAR4		equ	1Ch	; Multicast Address register 4	R/W
MAR5		equ	1Dh	; Multicast Address register 5	R/W
MAR6		equ	1Eh	; Multicast Address register 6	R/W
MAR7		equ	1Fh	; Multicast Address register 7	R/W

;-------------------Page 2 registers

RNP		equ	13h	; Remote Next Packet ptr reg.	R/W
LNP		equ	15h	; Local Next Packet ptr. reg.	R/W

;------------------------------------------------------------------------------
; Definitions for CR (offset 00h)

STP		equ	01h	; Stop
STA		equ	02h	; Start
TXP		equ	04h	; Transmit Packet
RD0		equ	08h	; Remote DMA Command 0
RD1		equ	10h	; Remote DMA Command 1
ABR		equ	20h	; Remote DMA Command 2
PS0		equ	40h	; Page Select bit 0
PS1		equ	80h	; Page Select bit 1

;------------------------------------------------------------------------------
; Definitions for ISR (offset 07h)

PRX		equ	01h	; Packet Received
PTX		equ	02h	; Packet Transmitted
RXE		equ	04h	; Receive Error
TXE		equ	08h	; Transmit Error
OVW		equ	10h	; Overwrite Warning
CNT		equ	20h	; Counter Overflow
RDC		equ	40h	; Remote DMA Complete
;RST		equ	80h	; Reset Status

;------------------------------------------------------------------------------
; Definitions for IMR (offset 0Fh)

PRXE		equ	01h	; Packet Received Interrupt enable
PTXE		equ	02h	; Packet Transmitted Interrupt enable
RXEE		equ	04h	; Receive Error Interrupt enable
TXEE		equ	08h	; Transmit Error Interrupt enable
OVWE		equ	10h	; Overwrite Warning Interrupt enable
CNTE		equ	20h	; Counter Overflow Interrupt enable
RDCE		equ	40h	; DMA Complete Interrupt enable
;Reserved	equ	80h	; Reserved

;------------------------------------------------------------------------------
; Definitions for DCR (offset 0Eh)

WTS		equ	01h	; Word Transfer Select
BOS		equ	02h	; Byte Order Select
LAS		equ	04h	; Long Address Select
BMS		equ	08h	; Burst Mode Select
AINTR		equ	10h	; Autoinitialize Remote
FTB2		equ	00h	; Receive FIFO threshold select - 2 bytes
FTB4		equ	20h	; Receive FIFO threshold select - 4 bytes
FTB8		equ	40h	; Receive FIFO threshold select - 8 bytes
FTB12		equ	60h	; Receive FIFO threshold select - 12 bytes


;------------------------------------------------------------------------------
; Definitions for TCR (offset 0Dh)

MCRC		equ	01h	; Inhibit CRC
LB1		equ	02h	; Mode 1 Internal Loopback LPBK==0
LB2		equ	04h	; Mode 2 Internal Loopback LPBK==1
LB3		equ	06h	; Mode 3 Internal Loopback LPBK==0
ATD		equ	08h	; Auto Transmit Disable
OFST		equ	10h	; Collision Offset Enable
;Reserved	equ	20h	; 
;Reserved	equ	40h	; 
;Reserved	equ	80h	; 

;------------------------------------------------------------------------------
; Definitions for Transmit Status Register TSR (offset 04h)

XMT		equ	01h	; packet transmitted without error 
COL		equ	04h	; transmit collided 
ABT		equ	08h	; transmit aborted 
CRS		equ	10h	; carrier sense lost - xmit not aborted 
FU		equ	20h	; FIFO underrun 
CDH		equ	40h	; CD heartbeat 
OWC		equ	80h	; out of window collision - xmit not aborted 

;------------------------------------------------------------------------------
; Definitions for Receive Configuration Register RCR (offset 1Ch)

SEP		equ	01h	; save error packets 
AR		equ	02h	; accept runt packet 
AB		equ	04h	; accept broadcast 
AM		equ	08h	; accept multicast 
PRO		equ	10h	; promiscuous physical 
MON		equ	20h	; monitor mode 

;------------------------------------------------------------------------------
; Definitions for Receive Status Register RSR

RCV		equ	01h	; packet received intact 
CRC		equ	02h	; CRC error 
FAE		equ	04h	; frame alignment error 
FO		equ	08h	; FIFO overrun 
MPA		equ	10h	; missed packet 
PHY		equ	20h	; physical/multicast address 
DIS		equ	40h	; receiver disable 
DFR		equ	80h	; deferring 

;------------------------------------------------------------------------------
; Misc defs...

;XMIT_BUF_SIZE	equ	600h	; Size of transmit buffer in shared ram.
CRC_SIZE	equ	4
NIC_HEADER_SIZE	equ	4	; Size of NIC header
TX_BUF_ONE	equ	1
TX_BUF_TWO	equ	2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Equates for ETH_RTNS.ASM
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TIMERVECT	EQU	70h		; interrupt 1c offset
SYS0VECT	EQU	20h		; interrupt 08 offset
SGM		EQU	2
OFF		EQU	0
EOI		EQU	20h

;EXTRN	TimerChainOff:	WORD
;EXTRN	TimerChainSgm:	WORD
;EXTRN	calibrate_state:BYTE
;EXTRN	delay_low:	WORD
;EXTRN	delay_high:	WORD

;PUBLIC	CalibrateHandler
;PUBLIC	enable_ram
;PUBLIC	disable_ram
;PUBLIC	CalibrateTimer
;PUBLIC	ms_delay

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Defs for 8013 AT adapters
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
INIT_LAAR_VALUE		equ	01h	; Initial LAAR vaule for 8013 adapters
INIT_LAAR_MASK		equ	21h	; Mask for initializing LAAR
L16E			equ	40h	; Memory 16 bit enable for NIC
M16E			equ	80h	; Memory 16 bit enable for host.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	External UM_ definitions for ETH_RTNS.ASM
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	LARGE
extrn	UM_Status_Change:	FAR
extrn	UM_Send_Complete:	FAR
extrn	UM_Receive_Packet:	FAR
extrn	UM_Interrupt:		FAR
extrn	UM_Delay:		FAR

else
extrn	UM_Status_Change:	NEAR
extrn	UM_Send_Complete:	NEAR
extrn	UM_Receive_Packet:	NEAR
extrn	UM_Interrupt:		NEAR
extrn	UM_Delay:		NEAR

endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	 MACRO  $POPFF
;	Used for the Intel 286 to mask a design flaw.
;	Use $POPFF instead of POPF - simulate popping flags using IRET instead.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
$POPFF	MACRO
		LOCAL	$1, $2
		jmp	$1			; jump around iret
$2:		iret				; Pop CS, IP, flags
$1:		push	cs
		call	$2			; CALL within segment
						; program will continue here
		ENDM
