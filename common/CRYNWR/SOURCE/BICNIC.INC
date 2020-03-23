;****************************************************************************
;
;       The information contained in this file is confidential and 
;       proprietary to Standard Microsystems Corporation.  No part
;       of this file may be reproduced or distributed, in any form
;       or by any means for any purpose, without the express written
;       permission of Standard Microsystems Corporation.
;
; File:         lmstruct.inc
;
; Description:	Include file for Bus Interface Chips 83C583, 584, 585, 593,
;		594, 790, 571/572.  Network Interface Controllers 83C690
;		(8390), 825, 790.  No defs for the 593 in 8023 Mode.
;
;********************
;* Revision History *
;********************
;
;  $Log:   G:/SWENG/SRC/LMCOM/VCS/BICNIC.IVC  $
;
;   Rev 1.28   15 Sep 1994 13:55:34   MARCUS_C
;Deleted EISA_ROM_PAGE_MASK equate reference.
;
;   Rev 1.27   09 Sep 1994 14:47:52   unknown
;
;   Rev 1.26   07 Jul 1994 14:40:08   wood_r
;
;   Rev 1.25   07 Jul 1994 14:39:10   wood_r
;   
;     Rev 1.24   07 Jul 1994 14:36:10   wood_r
;
; LM_8416_s2.1_v2.01
; Change:	Added equates for the Manchester Encoder/decoder register
;		on the 795.  The register value is 1Fh and the equate
;		is REG_MANCH with its bit values as MANCH_???.
;   
;
;+!/? ***********************************************************************


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Defs for Bus Interface Chips . . .
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 0: MSR - Memory Select Register
;
IFDEF NEC
 REG_MSR	equ	000h*2	; Register Offset
ELSE
 REG_MSR	equ	000h	; Register Offset
ENDIF
MSR_RST		equ	080h	; LAN Controller Reset
MSR_MENB	equ	040h	; Shared Memory Enable
MSR_RA18	equ	020h	; Ram Address bit 18	(583, 584)
MSR_0WS		equ	020h	; Zero Wait State	(585/790)
MSR_RA17	equ	010h	; Ram Address bit 17	(583, 584, 585/790)
MSR_RA16	equ	008h	; Ram Address bit 16	(583, 584, 585/790)
MSR_RA15	equ	004h	; Ram Address bit 15	(583, 584, 585/790)
MSR_RA14	equ	002h	; Ram Address bit 14	(583, 584, 585/790)
MSR_RA13	equ	001h	; Ram Address bit 13	(583, 584, 585/790)
MSR_MASK	equ	03Fh	; Mask for Address bits RA18-RA13 (583, 584)
MSR_585_MASK	equ	01Fh	; Mask for Address bits RA17-RA13 (585/790)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1: ICR - Interface Configuration Register (583, 584)
;
IFDEF NEC
 REG_ICR	equ	001h*2	; Register Offset
ELSE
 REG_ICR	equ	001h	; Register Offset
ENDIF
ICR_STO		equ	080h	; EEROM Store		
ICR_RIO		equ	040h	; Recall I/O Address
ICR_RX7		equ	020h	; Recall All but I/O and LAN Addr
ICR_RLA		equ	010h	; Recall LAN Address
ICR_MSZ		equ	008h	; Memory Size
ICR_IR2		equ	004h	; IRQ index MSB (584)
ICR_OTH		equ	002h	; "Other"(EEROM) register access (584)
ICR_16B		equ	001h	; Bus size bit (584)

; Unique defs for 583 . . .
;
ICR_DMA		equ	004h	; DMA Enable (583)
ICR_IO		equ	002h	; I/O Port Enable (583)
ICR_WTS		equ	001h	; Word Transfer Select (583)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1: EER - EEROM Register (585/790)
;
IFDEF NEC
 REG_EER	equ	001h*2	; Register Offset
ELSE
 REG_EER	equ	001h	; Register Offset
ENDIF
EER_STO		equ	080h	; Store EEROM Data
EER_RC		equ	040h	; Recall Index 1
EER_EA7		equ	020h	; EEROM Address bit 7 (write, 795)
EER_UNLCK	equ	010h	; Unlock bit
EER_EA6		equ	008h	; EEROM Address bit 6 (write)
EER_EA5		equ	004h	; EEROM Address bit 5 (write)
EER_EA4		equ	002h	; EEROM Address bit 4 (write)
EER_EA3		equ	001h	; EEROM Address bit 3 (write)

EER_INIT3	equ	008h	; Init Jumper Input pin 3 (read)
EER_INIT2	equ	004h	; Init Jumper Input pin 2 (read)
EER_INIT1	equ	002h	; Init Jumper Input pin 1 (read)
EER_INIT0	equ	001h	; Init Jumper Input pin 0 (read)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 02: SSR - Status Register (PCMCIA)
;
REG_SSR		equ	002h

SSR_BNC		equ	80h	; Turns on external BNC transciever.
SSR_VX		equ	40h	; Indicates external power is applied to card.
SSR_NLNK	equ	20h	; Link Integrity present.
SSR_NPOL	equ	10h	; UTP polarity.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 02: IOPDL - I/O Pipe Data Lo (795)
;
REG_IOPDL	equ	002h		; Register Offset
REG_IOPD	equ	REG_IOPDL	; Register Offset for 16 bit access

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 03: IOPDH - I/O Pipe Data Hi (795)
;
REG_IOPDH	equ	003h	; Register Offset

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 02: IAR - I/O Address Register (583, 584) For 585/790,
;		   use IAR5 (offset 0A).
;
;	Example:
;	  0	  2	  8	  0
;	XXXX	XXXX	XXXX	XXXX
;	***0	00**	***0	0000
;
IFDEF NEC
 REG_IAR	equ	002h*2	; Register Offset
ELSE
 REG_IAR	equ	002h	; Register Offset
ENDIF
IAR_IA15	equ	080h	; I/O Address bit 15
IAR_IA14	equ	040h	; I/O Address bit 14
IAR_IA13	equ	020h	; I/O Address bit 13
IAR_IA9		equ	010h	; I/O Address bit 9
IAR_IA8		equ	008h	; I/O Address bit 8
IAR_IA7		equ	004h	; I/O Address bit 7
IAR_IA6		equ	002h	; I/O Address bit 6
IAR_IA5		equ	001h	; I/O Address bit 5

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 03: BIO - BIOS ROM Address register (583, 584)
;
IFDEF NEC
 REG_BIO	equ	003h*2	; Register offset
ELSE
 REG_BIO	equ	003h	; Register offset
ENDIF
BIO_RS1		equ	080h	; ROM Size Index 1
BIO_RS0		equ	040h	; ROM Size Index 0
BIO_BA18	equ	020h	; Address bit 18
BIO_BA17	equ	010h	; Address bit 17
BIO_BA16	equ	008h	; Address bit 16
BIO_BA15	equ	004h	; Address bit 15
BIO_BA14	equ	002h	; Address bit 14
BIO_INT		equ	001h	; Hardware Interrupt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 03: EAR - EEROM Address Register (584) This register is accessed
;		   when ICR_OTH is set.
;
IFDEF NEC
 REG_EAR	equ	003h*2	; Register Offset
ELSE
 REG_EAR	equ	003h	; Register Offset
ENDIF
EAR_EA6		equ	080h	; EEROM Address Bit 6
EAR_EA5		equ	040h	; EEROM Address Bit 5
EAR_EA4		equ	020h	; EEROM Address Bit 4
EAR_EA3		equ	010h	; EEROM Address Bit 3
EAR_RAM		equ	008h	; RAM Installed in ROM Socket
EAR_RPE		equ	004h	; ROM Page Enable
EAR_RP1		equ	002h	; ROM Page bit 1
EAR_RP0		equ	001h	; ROM Page bit 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 04: IRR Interrupt Request Register (583, 584)
;
IFDEF NEC
 REG_IRR	equ	004h*2	; Register Offset
ELSE
 REG_IRR	equ	004h	; Register Offset
ENDIF
IRR_IEN		equ	080h	; Interrupt (IRQ) Enable
IRR_IR1		equ	040h	; IRQ index bit 1 (For 584, Bit 2 is ICR_IR2)
IRR_IR0		equ	020h	; IRQ index bit 0
IRR_FLSH	equ	010h	; Flash ROM in ROM Socket (584)
IRR_OUT3	equ	008h	; Output3 Pin Assert (584)
IRR_OUT2	equ	004h	; Output2 Pin Assert (584)
IRR_OUT1	equ	002h	; Output1 Pin Assert (584)
IRR_0WS8	equ	001h	; 8-bit Zero Wait State Enable

; Unique defs for 583 . . .
;
IRR_AMD		equ	010h	; Alternate Mode
IRR_AINT	equ	008h	; Alternate (Hardware) Interrupt
IRR_BW1		equ	004h	; BIOS ROM Wait State Bit 1
IRR_BW0		equ	002h	; BIOS ROM Wait State Bit 0

; Adapter Specific Defs:
;
; Ethernet:
IRR_BNC		equ	004h	; Enables -9V DC/DC Converter for Thin-net.
IRR_LITE	equ	002h	; Link Integ. Test Enable (for 8003WC series)
BNC_584_OFF	equ	000h	; Bit setting to disable BNC power
BNC_584_ON	equ	004h	; Bit setting to enable BNC power

				;  Disable (for other Elite Adapters)
; Token Ring:
IRR_UTP		equ	004h	; Unshielded TP Cable Select (0=Shielded TP)
IRR_16MBPS	equ	002h	; 16 MBPS Select (0=4MBPS)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 04: HWR - Hardware Support Register (585/790)
;
IFDEF NEC
 REG_HWR	equ	004h*2	; Register Offset
ELSE
 REG_HWR	equ	004h	; Register Offset
ENDIF
HWR_SWH		equ	080h	; Switch Register Set
HWR_LPRM	equ	040h	; LAN Address ROM Select
HWR_ETHER	equ	020h	; NIC Type. 1=83C690, 0=83C825. (Read)
HWR_HOST16	equ	010h	; Set When Host has 16 bit bus. (Read)
HWR_STAT2	equ	008h	; Interrupt Status (Read)
HWR_STAT1	equ	004h	; Interrupt Status (Read)
HWR_GIN2	equ	002h	; General Purpose Input 2 (Read)
HWR_PNPE	equ	002h	; Plug'n'Play enabled bit (795, read)
HWR_GIN1	equ	001h	; General Purpose Input 1 (Read)

HWR_MASK	equ	020h	; Interrupt Mask Bit (Write)
HWR_NUKE	equ	008h	; Hardware Reset (Write)
HWR_CLR1	equ	004h	; Clear Interrupt (Write, 585 only)
HWR_HWCS	equ	002h	; WCS Control (Write, 585 only)
HWR_CA		equ	001h	; Control Attention (Write, 585 only)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 05: GP1 - General Purpose Register 1 (583)
;
IFDEF NEC
 REG_GP1	equ	005h*2	; Register Offset
ELSE
 REG_GP1	equ	005h	; Register Offset
ENDIF
GP1_BIT7	equ	080h	; Undefined
GP1_BIT6	equ	040h	; Undefined
GP1_BIT5	equ	020h	; Undefined
GP1_BIT4	equ	010h	; Undefined
GP1_BIT3	equ	008h	; Undefined
GP1_BIT2	equ	004h	; Undefined
GP1_BIT1	equ	002h	; Undefined
GP1_BIT0	equ	001h	; Undefined

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 05: LAAR - LA Address Register (584)
;
IFDEF NEC
 REG_LAAR	equ	005h*2	; Register Offset
ELSE
 REG_LAAR	equ	005h	; Register Offset
ENDIF
LAAR_M16E	equ	080h	; 16 Bit Host Access Enable
LAAR_L16E	equ	040h	; 16 Bit NIC Access Enable
LAAR_0WS16	equ	020h	; 16 Bit Zero Wait State Enable
LAAR_LA23	equ	010h	; RAM Address bit 23
LAAR_LA22	equ	008h	; RAM Address bit 22
LAAR_LA21	equ	004h	; RAM Address bit 21
LAAR_LA20	equ	002h	; RAM Address bit 20
LAAR_LA19	equ	001h	; RAM Address bit 19
LAAR_MASK	equ	01Fh	; Masks off LA Address bits & LAAR_M16E

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 05: BPR - BIOS Page Register (585/790)
;
IFDEF NEC
 REG_BPR	equ	005h*2	; Register Offset
ELSE
 REG_BPR	equ	005h	; Register Offset
ENDIF
BPR_M16EN	equ	080h	; 16 Bit Host Access Enable
BPR_BP15	equ	040h	; BIOS ROM Offset Bit 15
BPR_BP14	equ	020h	; BIOS ROM Offset Bit 14
BPR_BP13	equ	010h	; BIOS ROM Offset Bit 13
BPR_SINT	equ	008h	; Software Induced Interrupt
BPR_EIL		equ	004h	; Interrupt Enable (585)
BPR_BMSTR	equ	004h	; Bus Master Enable (Ethernet EISA)
BPR_SOFT2	equ	002h	; General Purpose For Software (Claim Bit)
BPR_SOFT1	equ	001h	; General Purpose For Software (Claim Bit)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 05: CR - Control Register (593, 594)
;
IFDEF NEC
 REG_CR		equ	005h*2	; Register Offset
ELSE
 REG_CR		equ	005h	; Register Offset
ENDIF
CR_BIT7		equ	080h	; Reserved
CR_RMS2		equ	040h	; BIOS ROM Map Select 2 (594)
CR_RMS1		equ	020h	; BIOS ROM Map Select 1 (594)
CR_RMS0		equ	010h	; BIOS ROM Map Select 0 (594)
CR_SINT		equ	008h	; Software Induced Interrupt (594)
CR_EIL		equ	004h	; Interrupt Enable
CR_CLAIM1	equ	002h	; Claim Bit 1 (594)
CR_CLAIM0	equ	001h	; Claim Bit 0 (594)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 06: IJR - Initialize Jumper Register (584)
;
IFDEF NEC
 REG_IJR	equ	006h*2	; Register Offset
ELSE
 REG_IJR	equ	006h	; Register Offset
ENDIF
IJR_BIT7	equ	080h	; Not Defined
IJR_LPOL	equ	040h	; Link Polarity Input (Ethernet TP)
IJR_LINT	equ	020h	; Link Integrity Input (Ethernet TP)
IJR_BIT4	equ	010h	; Not Defined
IJR_BIT3	equ	008h	; Not Defined
IJR_INIT2	equ	004h	; Jumper Input Bit 2
IJR_INIT1	equ	002h	; Jumper Input Bit 1
IJR_INIT0	equ	001h	; Jumper Input Bit 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 06: INTCR - Interrupt Control Register (790)
;
IFDEF NEC
 REG_INTCR	equ	006h*2
ELSE
 REG_INTCR	equ	006h
ENDIF

INTCR_MCT	equ	080h	; Memory cache test bit (795)
INTCR_STAG	equ	040h	; Staggered address enable (795)
INTCR_IOPAV	equ	020h	; I/O pipe address visible (795)
INTCR_IOPE	equ	010h	; I/O pipe enable (795)
INTCR_SINT	equ	008h	; Software irq
INTCR_MSK2	equ	004h	; Irq mask 2 (masks NIC irqs)
INTCR_MSK1	equ	002h	; Irq mask 1 (not used)
INTCR_EIL	equ	001h	; Enable irq line

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 07: GP2 - General Purpose Register 2 (583, 584)
;
IFDEF NEC
 REG_GP2	equ	007h*2	; Register Offset
ELSE
 REG_GP2	equ	007h	; Register Offset
ENDIF
GP2_BIT7	equ	080h	; General purpose bit 7
GP2_BIT6	equ	040h	; General purpose bit 6
GP2_BIT5	equ	020h	; General purpose bit 5
GP2_BIT4	equ	010h	; General purpose bit 4
GP2_BIT3	equ	008h	; General purpose bit 3
GP2_PME		equ	004h	; Priority Mode Enable (584, Token Ring)
GP2_ETRD	equ	002h	; Early Token Release Disable (584, Token Ring)
GP2_RPLD	equ	001h	; RPL Disable (584, Bistro Ethernet)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 07: REV - Revision Register (585/790, 795)
;		 - I/O Pipe Address (write, 795)

IFDEF NEC
 REG_REV	equ	007h*2	; Register Offset
 REG_IOPA	equ	007h*2	; Register Offset I/O pipe address (795)
ELSE
 REG_REV	equ	007h	; Register Offset
 REG_IOPA	equ	007h	; Register Offset I/O pipe address (795)
ENDIF

REV_CHIP3	equ	080h	; Chip type bit 3
REV_CHIP2	equ	040h	; Chip type bit 2
REV_CHIP1	equ	020h	; Chip type bit 1
REV_CHIP0	equ	010h	; Chip type bit 0
REV_REV3	equ	008h	; Chip revision bit 3
REV_REV2	equ	004h	; Chip revision bit 2
REV_REV1	equ	002h	; Chip revision bit 1
REV_REV0	equ	001h	; Chip revision bit 0

; 790 Chip type is 0010. (CHIP3:0)
CHIP_790_DEF	equ	REV_CHIP1

; 585 Chip type is 0011 (CHIP3:0)
CHIP_585_DEF	equ	REV_CHIP1 OR REV_CHIP0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offsets 08-0F: LAR - LAN Address Registers (All BIC's)
; Individual bits are not specifically defined.

IFDEF NEC
 REG_LAR0	equ	008h*2	; LAN Address byte 0 (MSB) Global
 REG_LAR1	equ	009h*2	; LAN Address byte 1 Global
 REG_LAR2	equ	00Ah*2	; LAN Address byte 2 Global
 REG_LAR3	equ	00Bh*2	; LAN Address byte 3
 REG_LAR4	equ	00Ch*2	; LAN Address byte 4
 REG_LAR5	equ	00Dh*2	; LAN Address byte 5 (LSB)
 REG_BDID	equ	00Eh*2	; Adapter ID byte
 REG_CKSM	equ	00Fh*2	; LAN Address/ID byte checksum
ELSE
 REG_LAR0	equ	008h	; LAN Address byte 0 (MSB) Global
 REG_LAR1	equ	009h	; LAN Address byte 1 Global
 REG_LAR2	equ	00Ah	; LAN Address byte 2 Global
 REG_LAR3	equ	00Bh	; LAN Address byte 3
 REG_LAR4	equ	00Ch	; LAN Address byte 4
 REG_LAR5	equ	00Dh	; LAN Address byte 5 (LSB)
 REG_BDID	equ	00Eh	; Adapter ID byte
 REG_CKSM	equ	00Fh	; LAN Address/ID byte checksum
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 09: DCFG - Driver Config Register (585/790)
;
IFDEF NEC
 REG_DCFG	equ	009h*2	; Register Offset
ELSE
 REG_DCFG	equ	009h	; Register Offset
ENDIF
DCFG_BIT7	equ	080h
DCFG_BIT6	equ	040h
DCFG_BIT5	equ	020h
DCFG_BIT4	equ	010h
DCFG_BIT3	equ	008h
DCFG_BIT2	equ	004h
DCFG_ETRD	equ	002h
DCFG_BIT0	equ	001h	; Early Token Release Disable

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 0A: IAR7 - I/O Address Register (585/790)
; Register is referred to as IAR7 instead of IAR to avoid conflicts with 
; the 584 IAR register.
;
;	Example:
;	  0	  2	  8	  0
;	XXXX	XXXX	XXXX	XXXX
;	***0	001*	***0	0000
;
IFDEF NEC
 REG_IAR7	equ	00Ah*2	; Register Offset
ELSE
 REG_IAR7	equ	00Ah	; Register Offset
ENDIF
IAR7_IA15	equ	080h	; I/O Address bit 15
IAR7_IA14	equ	040h	; I/O Address bit 14
IAR7_IA13	equ	020h	; I/O Address bit 13
IAR7_IA8	equ	010h	; I/O Address bit 8
IAR7_IA7	equ	008h	; I/O Address bit 7
IAR7_IA6	equ	004h	; I/O Address bit 6
IAR7_IA5	equ	002h	; I/O Address bit 5
IAR7_PNPB	equ	001h	; Plug'n'Play boot bit (795)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 0B: RAR - RAM Address Register (585/790)
;
IFDEF NEC
 REG_RAR	equ	00Bh*2	; Register Offset
ELSE
 REG_RAR	equ	00Bh	; Register Offset
ENDIF
RAR_HRAM	equ	080h	; High ram address
RAR_RA17	equ	040h	; RAM base address bit 17
RAR_RWS1	equ	020h	; RAM window size bit 1
RAR_RWS0	equ	010h	; RAM window size bit 0
RAR_RA16	equ	008h	; RAM base address bit 16
RAR_RA15	equ	004h	; RAM base address bit 15
RAR_RA14	equ	002h	; RAM base address bit 14
RAR_RA13	equ	001h	; RAM base address bit 13

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 0C: BIO - BIOS ROM Control Register (585/790)
; Register is referred to as BAR instead of BIO to avoid conflicts with the
; 584 BIO register.
;
IFDEF NEC
 REG_BAR	equ	00Ch*2	; Register Offset
ELSE
 REG_BAR	equ	00Ch	; Register Offset
ENDIF
BAR_FINE	equ	080h	; MEMCS16 Assertion for RAM (Not ROM)
BAR_BA17	equ	040h	; ROM base address bit 17
BAR_BWS1	equ	020h	; ROM window size bit 1
BAR_BWS0	equ	010h	; ROM window size bit 0
BAR_BA16	equ	008h	; ROM base address bit 16
BAR_BA15	equ	004h	; ROM base address bit 15
BAR_BA14	equ	002h	; ROM base address bit 14
BAR_BA13	equ	001h	; ROM base address bit 13

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 0D: GCR - General Control Register (585/790)
;
IFDEF NEC
 REG_GCR	equ	00Dh*2	; Register Offset
ELSE
 REG_GCR	equ	00Dh	; Register Offset
ENDIF
GCR_EUTP	equ	080h	; Extended Length UTP (795)
GCR_IR2		equ	040h	; IRQ index Bit 2 MSB
GCR_0WS		equ	020h	; Zero Wait State
GCR_RIPL	equ	010h	; RPL Disable (MCA)
GCR_IR1		equ	008h	; IRQ index Bit 1
GCR_IR0		equ	004h	; IRQ index Bit 0 LSB
GCR_GPOUT	equ	002h	; General purpose output.
GCR_LITE	equ	001h	; Link integrity test enable

BNC_585_OFF	equ	00h	; Bit setting to disable BNC power
BNC_585_ON	equ	02h	; Bit setting to enable BNC power

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 0E: ERFAL - Early Rx Fail Address Lo (795)
;
IFDEF NEC
 REG_ERFAL	equ	00Eh*2	; Register Offset
 REG_ERFA	equ	00Eh*2	; Register Offset (16 bit access)
ELSE
 REG_ERFAL	equ	00Eh	; Register Offset
 REG_ERFA	equ	00Eh	; Register Offset (16 bit access)
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 0F: ERFAH - Early Rx Fail Address Hi (795)
;
IFDEF NEC
 REG_ERFAH	equ	00Fh*2	; Register Offset
ELSE
 REG_ERFAH	equ	00Fh	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Defs for Network Interface Controllers . . .
; 8390/690, 790, 825
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 8390/690 defs
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Offset 10h (NIC offset 00h): CMD - Command Register
; Read	page (all)
; Write	page (all)
IFDEF NEC
 REG_CMD	equ	010h*2	; Register Offset
ELSE
 REG_CMD	equ	010h	; Register Offset
ENDIF
CMD_STP		equ	001h	; Stop NIC
CMD_STA		equ	002h	; Start NIC
CMD_TXP		equ	004h	; Transmit Packet
CMD_RD0		equ	008h	; Remote DMA Command bit 0
CMD_RD1		equ	010h	; Remote DMA Command bit 1
CMD_RD2		equ	020h	; Remote DMA Command bit 2
CMD_PS0		equ	040h	; Page Select Bit 0
CMD_PS1		equ	080h	; Page Select Bit 1

; or in these bits for selecting a specific page . . .
CMD_PAGE0	equ	000h
CMD_PAGE1	equ	CMD_PS0
CMD_PAGE2	equ	CMD_PS1
CMD_PAGE3	equ	CMD_PS0+CMD_PS1

; 790 specific defs . . .
CMD_DISETCH	equ	008h
CMD_ENETCH	equ	010h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 11h (NIC offset 01h): PSTART - Page Start Register
; Read	page 0
; Write	page 2
IFDEF NEC
 REG_PSTART	equ	011h*2	; Register Offset
ELSE
 REG_PSTART	equ	011h	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 12h (NIC offset 02h): PSTOP - Page Stop Register
; Read	page 0
; Write	page 2
IFDEF NEC
 REG_PSTOP	equ	012h*2	; Register Offset
ELSE
 REG_PSTOP	equ	012h	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 11h (NIC offset 01h):
;	RBEGIN - Receive Descriptor Table Start Register
; Read	page 2
; Write	page 0
IFDEF NEC
 REG_RBEGIN	equ	011h*2	; Register Offset
ELSE
 REG_RBEGIN	equ	011h	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 12h (NIC offset 02h): 
;	REND - Receive Descriptor Table End Register
; Read	page 2
; Write	page 0
IFDEF NEC
 REG_REND	equ	012h*2	; Register Offset
ELSE
 REG_REND	equ	012h	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 13h (NIC offset 03h): BNRY - Boundary Pointer Register
; Read	page 0
; Write	page 0
IFDEF NEC
 REG_BNRY	equ	013h*2	; Register Offset
ELSE
 REG_BNRY	equ	013h	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 13h (NIC offset 03h):
; Offset 15h (NIC offset 05h):
;	TBEGIN - Transmit Descriptor Table Begin Register
;
; Read	page 2, Offset 13h
; Write	page 0, Offset 15h
;
IFDEF NEC
 REG_TBEGINW	equ	015h*2	; Write this offset
 REG_TBEGINR	equ	013h*2	; Read this offset
ELSE
 REG_TBEGINW	equ	015h	; Write this offset
 REG_TBEGINR	equ	013h	; Read this offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 14h (NIC offset 04h):
;	TEND - Transmit Descriptor Table End Register
; Read	page 2
; Write	page 0
IFDEF NEC
 REG_TEND	equ	014h*2
ELSE
 REG_TEND	equ	014h
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 14h (NIC offset 04h): TSR - Transmit Status Register
; Read only, page 0
IFDEF NEC
 REG_TSR	equ	014h*2	; Register Offset
ELSE
 REG_TSR	equ	014h	; Register Offset
ENDIF
TSR_PTX		equ	001h	; Packet Transmitted
TSR_NDT		equ	002h	; Non-Deferred Transmit
TSR_COL		equ	004h	; Transmit Collided
TSR_ABT		equ	008h	; Xmit Aborted due to excessive collisions
TSR_CRS		equ	010h	; Carrier Sense lost
TSR_FU		equ	020h	; FIFO Underrun
TSR_CDH		equ	040h	; Carrier Detect Heartbeat
TSR_OWC		equ	080h	; Out of Window Collision

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 14h (NIC offset 04h): TPSR - Transmit Page Start Address Register
; Read	page 2
; Write	page 0
IFDEF NEC
 REG_TPSR	equ	014h*2	; Register Offset
ELSE
 REG_TPSR	equ	014h	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 15h (NIC offset 05h): NCR - Number of Collisions Register
; Read only, page 0
IFDEF NEC
 REG_NCR	equ	015h*2	; Register Offset
ELSE
 REG_NCR	equ	015h	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 15h (NIC offset 05h): TBCR0 - Transmit Byte Count Register 0
; Write	only, page 0
IFDEF NEC
 REG_TBCR0	equ	015h*2	; Register Offset
ELSE
 REG_TBCR0	equ	015h	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 16h (NIC offset 06h): TBCR1 - Transmit Byte Count Register 1
; Write	only, page 0
IFDEF NEC
 REG_TBCR1	equ	016h*2	; Register Offset
ELSE
 REG_TBCR1	equ	016h	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 16h (NIC offset 06h): FIFO - FIFO Register
; Read only, page 0
IFDEF NEC
 REG_FIFO	equ	016h*2	; Register Offset
ELSE
 REG_FIFO	equ	016h	; Register Offset
ENDIF
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 17h (NIC offset 07h): ISR - Interrrupt Status Register
; Read	page 0
; Write	page 0
IFDEF NEC
 REG_ISR	equ	017h*2	; Register Offset
ELSE
 REG_ISR	equ	017h	; Register Offset
ENDIF

ISR_PRX		equ	001h	; Packet Received
ISR_PTX		equ	002h	; Packet Transmitted
ISR_RXE		equ	004h	; Receive Error
ISR_TXE		equ	008h	; Transmit Error
ISR_OVW		equ	010h	; Ring Overwrite Warning
ISR_CNT		equ	020h	; Counter Overflow Warning
ISR_RDC		equ	040h	; Remote DMA Complete
ISR_ERW		equ	040h	; Early Rec Interrupt
ISR_RST		equ	080h	; Reset Status

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 17h (NIC offset 07h): CURR - Current Page Register
; Read	page 1
; Write	page 1
IFDEF NEC
 REG_CURR	equ	017h*2	; Register Offset
ELSE
 REG_CURR	equ	017h	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 17h (NIC offset 07h): ENH - Enhancement Register (790)
; Read	page 2
; Write	page 2
IFDEF NEC
 REG_ENH	equ	017h*2	; Register Offset
ELSE
 REG_ENH	equ	017h	; Register Offset
ENDIF
ENH_SBACK	equ	001h	; Backoff mode
;ENH_		equ	002h
ENH_EOTINT	equ	004h	; End of transmit interrupt mode bit
ENH_SLOT0	equ	008h	; Slot time bit 0
ENH_SLOT1	equ	010h	; Slot time bit 1
ENH_ALTEGO	equ	020h	; 690/790 mode select
ENH_WAIT0	equ	040h	; DMA wait states bit 0
ENH_WAIT1	equ	080h	; DMA wait states bit 1

ifdef	LNKLST
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 16h (NIC offset 06h): ERWCNT - Early Receive Warning Count
; Read Page 0
; Write Page 0
IFDEF NEC
 REG_ERWCNT	equ	016h*2
ELSE
 REG_ERWCNT	equ	016h
ENDIF

else
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 18h (NIC offset 08h): ERWCNT - Early Receive Warning Count
; Read Page 0
; Write Page 0
;
IFDEF NEC
 REG_ERWCNT	equ	018h*2
ELSE
 REG_ERWCNT	equ	018h
ENDIF

endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 18h (NIC offset 08h): RTABL - Receive Descriptor Table Ptr Lo Byte
;
IFDEf NEC
 REG_RTABL	equ	018h*2
ELSE
 REG_RTABL	equ	018h
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 19h (NIC offset 09h): RTABH - Receive Descriptor Table Ptr Hi Byte
;
IFDEF NEC
 REG_RTABH	equ	019h*2
ELSE
 REG_RTABH	equ	019h
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 19h (NIC offset 09h): TPSRL - Transmit Page Start Address Register
; Read	page 2
; Write	page 0
IFDEF NEC
 REG_TPSRL	equ	019h*2	; Register Offset
ELSE
 REG_TPSRL	equ	019h	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 19h (NIC offset 09h): UBRCV - Ultra Bitchen Receive Register (795)
; Read/Write	page 0
IFDEF NEC
 REG_UBRCV	equ	019h*2	; Register Offset
ELSE
 REG_UBRCV	equ	019h	; Register Offset
ENDIF

UBRCV_RE	equ	004h	; Indicates Rx ring is empty (read only)
UBRCV_URUN	equ	002h	; Indicates ERX underrun
UBRCV_WREN	equ	001h	; Ring Wrap enable

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1Ah (NIC offset 0Ah): TTABL - Transmit Descriptor Table Ptr Lo Byte
;
IFDEF NEC
 REG_TTABL	equ	01Ah*2
ELSE
 REG_TTABL	equ	01Ah
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1Bh (NIC offset 0Bh): TTABH - Receive Descriptor Table Ptr Hi Byte
;
IFDEF NEC
 REG_TTABH	equ	01Bh*2
ELSE
 REG_TTABH	equ	01Bh
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1Ah (NIC offset 0Ah): RBCR0 - Remote Byte Count Register 0
; Write	only, page 0
IFDEF NEC
 REG_RBCR0	equ	01Ah*2	; Register Offset
ELSE
 REG_RBCR0	equ	01Ah	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1Bh (NIC offset 0Bh): RBCR1 - Remote Byte Count Register 1
; Write	only, page 0
IFDEF NEC
 REG_RBCR1	equ	01Bh*2	; Register Offset
ELSE
 REG_RBCR1	equ	01Bh	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1Ah (NIC offset 0Ah): RCNTL - Receive Byte Count Register Lo (790)
; Read	only, page 0

IFDEF	NEC
 REG_RCNTL	equ	01Ah*2	; Register Offset
ELSE
 REG_RCNTL	equ	01Ah	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1Bh (NIC offset 0Bh): RCNTH - Receive Byte Count Register Hi (790)
; Read	only, page 0

IFDEF	NEC
 REG_RCNTh	equ	01Bh*2	; Register Offset
ELSE
 REG_RCNTH	equ	01Bh	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1Ch (NIC offset 0Ch): RSR - Receive Status Register
; Read only, page 0
IFDEF NEC
 REG_RSR	equ	01Ch*2	; Register Offset
ELSE
 REG_RSR	equ	01Ch	; Register Offset
ENDIF
RSR_PRX		equ	001h	; Packet Received
RSR_CRC		equ	002h	; CRC Error
RSR_FAE		equ	004h	; Frame Alignment Error
RSR_FO		equ	008h	; FIFO Overrun
RSR_MPA		equ	010h	; Missed Packet
RSR_PHY		equ	020h	; Physical Address
RSR_DIS		equ	040h	; Receiver Disabled
RSR_DFR		equ	080h	; Deferring

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1Ch (NIC offset 0Ch): RCR - Receive Configuration Register
; Read	page 2
; Write	page 0
IFDEF NEC
 REG_RCR	equ	01Ch*2	; Register Offset
ELSE
 REG_RCR	equ	01Ch	; Register Offset
ENDIF
RCR_SEP		equ	001h	; Save Errored Packets
RCR_AR		equ	002h	; Accept Runt Packets
RCR_AB		equ	004h	; Accept Broadcast Packets
RCR_AM		equ	008h	; Accept Multicast Packets
RCR_PRO		equ	010h	; Promiscuous Mode
RCR_MON		equ	020h	; Monitor Mode
;RCR_RES	equ	040h	; Reserved
;RCR_RES	equ	080h	; Reserved

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1Dh (NIC offset 0Dh): TCR - Transmit Configuration Register
; Read	page 2
; Write	page 0
IFDEF NEC
 REG_TCR	equ	01Dh*2	; Register Offset
ELSE
 REG_TCR	equ	01Dh	; Register Offset
ENDIF
TCR_CRC		equ	001h	; Inhibit CRC
TCR_LB0		equ	002h	; Encoded Loopback Control bit 0
TCR_LB1		equ	004h	; Encoded Loopback Control bit 1
TCR_ATD		equ	008h	; Auto Transmit Disable
TCR_OFST	equ	010h	; Collision Offset Enable
;TCR_RES	equ	020h	; Reserved
;TCR_RES	equ	040h	; Reserved
;TCR_RES	equ	080h	; Reserved
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1Dh (NIC offset 0Dh): CNTR0 - Tally Counter Register 0 (FAE)
; Read only, page 0
IFDEF NEC
 REG_CNTR0	equ	01Dh*2	; Register Offset
ELSE
 REG_CNTR0	equ	01Dh	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1Eh (NIC offset 0Eh): DCR - Data Configuration Register
; Read	page 2
; Write page 0
IFDEF NEC
 REG_DCR	equ	01Eh*2	; Register Offset
ELSE
 REG_DCR	equ	01Eh	; Register Offset
ENDIF
DCR_WTS		equ	001h	; Word Transfer Select
DCR_BOS		equ	002h	; Byte Order Select
DCR_LAS		equ	004h	; Long Address Select (8390)
DCR_LS		equ	008h	; Loopback Select
DCR_AR		equ	010h	; Autoinitialize Remote
DCR_FT0		equ	020h	; FIFO Threshhold Select Bit 0
DCR_FT1		equ	040h	; FIFO Threshhold Select Bit 1
;DCR_RES	equ	080h	; Reserved

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1Eh (NIC offset 0Eh): CNTR1 - Tally Counter Register 1 (CRC)
; Read only, page 0
IFDEF NEC
 REG_CNTR1	equ	01Eh*2	; Register Offset
ELSE
 REG_CNTR1	equ	01Eh	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1Fh (NIC offset 0Fh): IMR - Interrupt Mask Register
; Read	page 2
; Write page 0
IFDEF NEC
 REG_IMR	equ	01Fh*2	; Register Offset
ELSE
 REG_IMR	equ	01Fh	; Register Offset
ENDIf
IMR_PRXE	equ	001h	; Packet Received Interrupt Enable
IMR_PTXE	equ	002h	; Packet Transmitted Interrupt Enable
IMR_RXEE	equ	004h	; Receive Error Interrupt Enable
IMR_TXEE	equ	008h	; Transmit Error Interrupt Enable
IMR_OVWE	equ	010h	; Ring Overwrite Warning Interrupt Enable
IMR_CNTE	equ	020h	; Counter Overflow Interrupt Enable
IMR_RDCE	equ	040h	; DMA Complete Interrupt Enable
IMR_ERWE	equ	040h	; Early Receive Warning Interrupt Enable
;IMR_RES	equ	080h	; Reserved

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1Fh (NIC offset 0Fh): CNTR2 - Tally Counter Register 2 (MPA)
; Read only, page 0
IFDEF NEC
 REG_CNTR2	equ	01Fh*2	; Register Offset
ELSE
 REG_CNTR2	equ	01Fh	; Register Offset
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 1Fh (NIC offset 0Fh): MANCH - Status read-back of 10BaseT LED
;				       drivers
; Read  page 3
; Write page 3
;
IFDEF NEC
 REG_MANCH	equ	01Fh*2	; Register Offset
ELSE
 REG_MANCH	equ	01Fh	; Register Offset
ENDIF

MANCH_TLED	equ	001h	; Transmit LED
MANCH_RLED	equ	002h	; Receive LED
MANCH_LLED	equ	004h	; Link Status LED
MANCH_PLED	equ	008h	; TPRX Polarity readback
MANCH_ENAPOL	equ	010h	; Automatic polarity correct
;;;MANCH_xxx	equ	020h	; Not Used
MANCH_SEL	equ	040h	; Select AUI idle state
MANCH_MANDIS	equ	080h	; Disable Manchester encoder/decoder

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
; Other Page 1 Register Offset Assignments
;
IFDEF NEC
 REG_PAR0	equ	11h*2	; Offset, Physical Address Register 0
 REG_PAR1	equ	12h*2	; Offset, Physical Address Register 1
 REG_PAR2	equ	13h*2	; Offset, Physical Address Register 2
 REG_PAR3	equ	14h*2	; Offset, Physical Address Register 3
 REG_PAR4	equ	15h*2	; Offset, Physical Address Register 4
 REG_PAR5	equ	16h*2	; Offset, Physical Address Register 5

 REG_MAR0	equ	18h*2	; Offset, Multicast Address Register 0
 REG_MAR1	equ	19h*2	; Offset, Multicast Address Register 1
 REG_MAR2	equ	1Ah*2	; Offset, Multicast Address Register 2
 REG_MAR3	equ	1Bh*2	; Offset, Multicast Address Register 3
 REG_MAR4	equ	1Ch*2	; Offset, Multicast Address Register 4
 REG_MAR5	equ	1Dh*2	; Offset, Multicast Address Register 5
 REG_MAR6	equ	1Eh*2	; Offset, Multicast Address Register 6
 REG_MAR7	equ	1Fh*2	; Offset, Multicast Address Register 7
ELSE
 REG_PAR0	equ	11h	; Offset, Physical Address Register 0
 REG_PAR1	equ	12h	; Offset, Physical Address Register 1
 REG_PAR2	equ	13h	; Offset, Physical Address Register 2
 REG_PAR3	equ	14h	; Offset, Physical Address Register 3
 REG_PAR4	equ	15h	; Offset, Physical Address Register 4
 REG_PAR5	equ	16h	; Offset, Physical Address Register 5

 REG_MAR0	equ	18h	; Offset, Multicast Address Register 0
 REG_MAR1	equ	19h	; Offset, Multicast Address Register 1
 REG_MAR2	equ	1Ah	; Offset, Multicast Address Register 2
 REG_MAR3	equ	1Bh	; Offset, Multicast Address Register 3
 REG_MAR4	equ	1Ch	; Offset, Multicast Address Register 4
 REG_MAR5	equ	1Dh	; Offset, Multicast Address Register 5
 REG_MAR6	equ	1Eh	; Offset, Multicast Address Register 6
 REG_MAR7	equ	1Fh	; Offset, Multicast Address Register 7
ENDIF




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Defs for Bus Interface Chip 571/572(Eisa Bus Master) . . .
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

EISA_MANUF_ID          EQU     04da3h  ; 'SMC' compressed
EISA_BRD_83M32         EQU     09010h  ; version #
EISA_TKN_CFG           EQU     0CA4H

EISA_RAM_MASK          EQU     0fch
EISA_RAM_PAGE_MASK     EQU     003h

EISA_ROM_MASK          EQU     0f0h
;;IFNDEF EISA_ROM_PAGE_MASK
;;EISA_ROM_PAGE_MASK     EQU     007h
;;ENDIF
; register name                offset from IO base 
; ---------------------------------------------------
B571_ID1               EQU     000H    ; EISA ID1
B571_ID2               EQU     001H    ; EISA ID2
B571_ID3               EQU     002H    ; EISA ID3 - adapter product number
B571_ID4               EQU     003H    ; EISA ID4 - adapter revision number
B571_EBC               EQU     004H    ; expansion board control register
B571_RIML              EQU     006H    ; RAM base address register (I/O map)
B571_RIMH              EQU     007H    ; ..
B571_RAM               EQU     008H    ; RAM base address register (mem map)
B571_ROM               EQU     009H    ; ROM base address register
B571_INT               EQU     00aH    ; interrupt register
B571_STAT              EQU     00bH    ; status register

B571_AA                EQU     010H    ; EISA DMA registers
B571_AS                EQU     014H

B571_TR0		EQU	020H	; 571 TRC control Registers
B571_TR2               EQU     022H    ; ..
B571_TR4               EQU     024H    ; ..


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 4h : B571_EBC - Expansion board control register
;
B571_EBC_ENB		EQU	001H    ; board enable



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 0ah : B571_INT - Interrupt register
;
B571_INT_CLRD          EQU     80h     ; DMA interrupt clear
B571_INT_MENB		EQU	40H     ; memory enable
B571_INT_ROMEN         EQU     20h     ; ROM enable
B571_INT_G4            EQU     10h     ; if set, RAM in upper memory space
B571_INT_POL           EQU     08h     ; interrupt polarity(1=edge, 0=level)
B571_INT_IRQ_MASK      EQU     07h     ; IRQ settings




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 0bh : B571_STAT - status register
;
B571_STAT_EIL		EQU	80H     ; 1 = enable interrupts, 0 = disable interrupts
B571_STAT_DIEN         EQU     40h     ; DMA interrupt enable
B571_STAT_STATI        EQU     20h     ; NIC interrupt status
B571_STAT_STATD        EQU     10h     ; DMA interrupt status
B571_STAT_RNIC		EQU	08H     ; reset NIC only works for 790, move to TR4
B571_STAT_SDMA         EQU     02h     ; DMA start/stop (read only)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 14h : B571_AS - EISA DMA BURST 
; must be accessed as 32 bits register 
; 
B571_AS_SDMA           EQU     08000h  ; DMA start/stop bit
B571_AS_TO_HOST        EQU     04000h  ; DMA direction, 1 = to host, 0 = from host


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 20h : B571_TR0 - TRC control register
;
B571_TR0_HWCS		EQU	002H    ; WCS control
B571_TR0_BME           EQU     004H    ; bus master mode enable
B571_TR0_CLRI		EQU	008H    ; interrupt clear(write only)
B571_TR0_CA            EQU     001H    ; control attention(write only)
B571_TR0_CBUSY         EQU     001H    ; cbusy status (read only)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 22h : B571_TR2 - TRC control register
; 
B571_TR2_ESK_RISE      EQU     001H    ; EEPROM clock rise
B571_TR2_ESK_FALL      EQU     000H    ; EEPROM clock fall


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Offset 24h : B571_TR4 - TRC control register
; 

B571_TR4_ECS           EQU     004H    ; EEPROM select
B571_TR4_RNIC          EQU     008H    ; reset NIC



