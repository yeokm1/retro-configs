;****************************************************************************
;
;       The information contained in this file is confidential and 
;       proprietary to Standard Microsystems Corporation.  No part
;       of this file may be reproduced or distributed, in any form
;       or by any means for any purpose, without the express written
;       permission of Standard Microsystems Corporation.
;
; File:         GETCNFG.INC
;
; Description:	Equates to support the GETCNFG.ASM file.
;
;********************
;* Revision History *
;********************
;
; $Log:   H:\sweng\src\lmcom\vcs\getcnfg.ivc  $
;
;   Rev 1.24   17 Feb 1995 16:59:26   ANDERSON
;
; Change: added CNFG_SIZE_256kb.
;
;   Rev 1.23   17 Oct 1994 11:26:54   WOOD_R
;
; Changes:	Added equate CHIP_REV_MASK for designating a Chip Revision
;		level.  This was done for the 825XE chip.  This may be used
;		in the future by other chips.
;
;		Added equate BID_EEPROM_CHIP_REV_MASK to support the recall
;		of EEPROM Chip Revision data in bank A, byte 6.
;
;   Rev 1.22   08 Aug 1994 17:28:00   WOOD_R
; Changes:	Added the equate RAM_SIZE_0K for the extra_info variable.
;		This is to support the 8432 which has no RAM.
;
;   Rev 1.21   07 Jul 1994 14:43:20   wood_r
;
; LM_8416_s2.1_v2.01
; Changes:	Added code to support the Auto Media Detect feature,
;		the 8416 naming conventions, amd "No AUI media".
;
;
;+!/? ***********************************************************************

;
; Adapter POS ID's
;
CNFG_ID_8003E		equ	6fc0h		; 
CNFG_ID_8003S		equ	6fc1h		; 
CNFG_ID_8003W		equ	6fc2h		; 
CNFG_ID_8115TRA		equ	6ec6h		; Token Ring MCA 
CNFG_ID_8013E		equ	61C8h		; 
CNFG_ID_8013W		equ	61C9h		; 
CNFG_ID_BISTRO03E	equ	0EFE5h		; 
CNFG_ID_BISTRO13E	equ	0EFD5h		; 
CNFG_ID_BISTRO13W	equ	0EFD4h		; 	
;
; 583 & 584 registers, needed for getinfo
;
ifdef	NEC
CNFG_MSR_583		equ	0*2
CNFG_ICR_583		equ	1*2
CNFG_IAR_583		equ	2*2
CNFG_BIO_583		equ	3*2
CNFG_EAR_583            equ     3*2
CNFG_IRR_583		equ	4*2
CNFG_LAAR_584		equ	5*2
CNFG_GP2		equ	7*2
else
CNFG_MSR_583		equ	0
CNFG_ICR_583		equ	1
CNFG_IAR_583		equ	2
CNFG_BIO_583		equ	3
CNFG_EAR_583            equ     3
CNFG_IRR_583		equ	4
CNFG_LAAR_584		equ	5
CNFG_GP2		equ	7
endif

CNFG_LAAR_MASK		equ	01Fh
CNFG_LAAR_ZWS		equ	020h
CNFG_LAAR_L16E		equ	040h
CNFG_ICR_IR2_584	equ	04h
CNFG_ICR_MASK           equ     08h
CNFG_ICR_MSZ            equ     08h
CNFG_ICR_RLA            equ     010h
CNFG_ICR_STO            equ     080h
CNFG_IRR_IRQS		equ	060h
CNFG_IRR_IEN		equ	080h
CNFG_IRR_ZWS		equ	01h
CNFG_GP2_BOOT_NIBBLE	equ	0Fh
CNFG_IRR_OUT2           equ     04h
CNFG_IRR_OUT1           equ     02h
;
CNFG_SIZE_8kb		equ	8
CNFG_SIZE_16kb		equ	16
CNFG_SIZE_32kb		equ	32
CNFG_SIZE_64kb		equ	64
CNFG_SIZE_128kb        equ     128
CNFG_SIZE_256kb        equ     256
;
ROM_DISABLE		equ	0
;
CNFG_SLOT_ENABLE_BIT	equ	08h
;
CNFG_POS_CONTROL_REG	equ	096h
CNFG_POS_REG0		equ	100h
CNFG_POS_REG1		equ	101h
CNFG_POS_REG2		equ	102h
CNFG_POS_REG3		equ	103h
CNFG_POS_REG4		equ	104h
CNFG_POS_REG5		equ	105h

CNFG_ADAPTER_TYPE_MASK	equ	00eh
;******************************************************************************
;	General register definitions for identifying board types
;******************************************************************************
ifdef	NEC
BID_REG_0	equ	00h*2	;registers in LAN adapter
BID_REG_1	equ	01h*2
BID_REG_2	equ	02h*2
BID_REG_3	equ	03h*2
BID_REG_4	equ	04h*2
BID_REG_5	equ	05h*2
BID_REG_6	equ	06h*2
BID_REG_7	equ	07h*2
BID_LAR_0	equ	08h*2	;LAN address ROM registers
BID_LAR_1	equ	09h*2
BID_LAR_2	equ	0Ah*2
BID_LAR_3	equ	0Bh*2
BID_LAR_4	equ	0Ch*2
BID_LAR_5	equ	0Dh*2
else
BID_REG_0	equ	00h	;registers in LAN adapter
BID_REG_1	equ	01h
BID_REG_2	equ	02h
BID_REG_3	equ	03h
BID_REG_4	equ	04h
BID_REG_5	equ	05h
BID_REG_6	equ	06h
BID_REG_7	equ	07h
BID_LAR_0	equ	08h	;LAN address ROM registers
BID_LAR_1	equ	09h
BID_LAR_2	equ	0Ah
BID_LAR_3	equ	0Bh
BID_LAR_4	equ	0Ch
BID_LAR_5	equ	0Dh
endif

ifdef	NEC
BID_BOARD_ID_BYTE	equ	0Eh*2
BID_CHCKSM_BYTE		equ	0Fh*2
BID_LAR_OFFSET		equ	08h*2	;offset for aliasing check

else
BID_BOARD_ID_BYTE	equ	0Eh
BID_CHCKSM_BYTE		equ	0Fh
BID_LAR_OFFSET		equ	08h	;offset for aliasing check

endif


;******************************************************************************
;	General definitions
;******************************************************************************
BID_MSZ_583_BIT		equ	08h
BID_SIXTEEN_BIT_BIT	equ	01h

;******************************************************************************
;	Mask for extracting the board revision number
;******************************************************************************
BID_BOARD_REV_MASK	equ	1Eh

;******************************************************************************
;	Definitions for board rev numbers greater that 1
;******************************************************************************
BID_MEDIA_TYPE_BIT	equ	01h
BID_SOFT_CONFIG_BIT	equ	20h
BID_RAM_SIZE_BIT	equ	40h
BID_BUS_TYPE_BIT	equ	80h

;******************************************************************************
;	Defs for identifying the 690
;******************************************************************************

ifdef	NEC
 BID_CR		equ	10h*2		; Command Register
else
 BID_CR		equ	10h		; Command Register
endif

BID_TXP		equ	04h		; Transmit Packet Command

ifdef	NEC
 BID_TCR_DIFF	equ	0Dh*2		; Transmit Configuration Register
else
 BID_TCR_DIFF	equ	0Dh		; Transmit Configuration Register
endif


BID_TCR_VAL	equ	18h		; Value to Test 8390 or 690
BID_PS0		equ	00h		; Register Page Select 0
BID_PS1		equ	40h		; Register Page Select 1
BID_PS2		equ	80h		; Register Page Select 2
BID_PS_MASK	equ	3Fh		; For Masking Off Page Select Bits

;******************************************************************************
;	Defs for manipulating the 584
;******************************************************************************

ifdef	NEC
BID_EEPROM_0			equ	08h*2
BID_EEPROM_1			equ	09h*2
BID_EEPROM_2			equ	0Ah*2
BID_EEPROM_3			equ	0Bh*2
BID_EEPROM_4			equ	0Ch*2
BID_EEPROM_5			equ	0Dh*2
BID_EEPROM_6			equ	0Eh*2
BID_EEPROM_7			equ	0Fh*2
else
BID_EEPROM_0			equ	08h
BID_EEPROM_1			equ	09h
BID_EEPROM_2			equ	0Ah
BID_EEPROM_3			equ	0Bh
BID_EEPROM_4			equ	0Ch
BID_EEPROM_5			equ	0Dh
BID_EEPROM_6			equ	0Eh
BID_EEPROM_7			equ	0Fh
endif

BID_OTHER_BIT			equ	02h
BID_ICR_MASK			equ	0Ch
BID_EAR_MASK			equ	0Fh
BID_ENGR_PAGE			equ	0A0h
BID_RLA				equ	10h
BID_EA6				equ	80h
BID_RECALL_DONE_MASK		equ	010h
BID_BID_EEPROM_OVERRIDE		equ	0FFB0h
BID_EXTRA_EEPROM_OVERRIDE	equ	0FFD0h
BID_EEPROM_MEDIA_MASK		equ	07h
BID_STARLAN_TYPE		equ	00h
BID_ETHERNET_TYPE		equ	01h
BID_TP_TYPE			equ	02h
BID_EW_TYPE			equ	03h
BID_UTP2_TYPE			equ	05h
BID_EEPROM_IRQ_MASK		equ	18h
BID_PRIMARY_IRQ			equ	00h
BID_ALTERNATE_IRQ_1		equ	08h
BID_ALTERNATE_IRQ_2		equ	10h
BID_ALTERNATE_IRQ_3		equ	18h
BID_EEPROM_RAM_SIZE_MASK	equ	0E0h
BID_EEPROM_RAM_SIZE_RES1	equ	00h
BID_EEPROM_RAM_SIZE_RES2	equ	20h
BID_EEPROM_RAM_SIZE_8K		equ	40h
BID_EEPROM_RAM_SIZE_16K		equ	60h
BID_EEPROM_RAM_SIZE_32K		equ	80h
BID_EEPROM_RAM_SIZE_64K		equ	0A0h
BID_EEPROM_RAM_SIZE_RES3	equ	0C0h
BID_EEPROM_RAM_SIZE_RES4	equ	0E0h
BID_EEPROM_BUS_TYPE_MASK	equ	07h
BID_EEPROM_BUS_TYPE_AT		equ	00h
BID_EEPROM_BUS_TYPE_MCA		equ	01h
BID_EEPROM_BUS_TYPE_EISA	equ	02h
BID_EEPROM_BUS_TYPE_NEC		equ	03h
BID_EEPROM_BUS_SIZE_MASK	equ	18h
BID_EEPROM_BUS_SIZE_8BIT	equ	00h
BID_EEPROM_BUS_SIZE_16BIT	equ	08h
BID_EEPROM_BUS_SIZE_32BIT	equ	10h
BID_EEPROM_BUS_SIZE_64BIT	equ	18h
BID_EEPROM_RAM_PAGING		equ	40h
BID_EEPROM_ROM_PAGING		equ	80h
BID_EEPROM_PAGING_MASK		equ	0C0h
BID_EEPROM_LOW_COST		equ	08h
BID_EEPROM_IO_MAPPED		equ	10h
BID_EEPROM_HMI			equ	01h
BID_EEPROM_AUTO_MEDIA_DETECT	equ	01h
BID_EEPROM_CHIP_REV_MASK	equ	0Ch

;ifdef	NEC
;OFFSET_585_ENGR_DATA		equ	00Ah*2
;OFFSET_585_LAN_ADDR		equ	006h*2
;else

OFFSET_585_ENGR_DATA		equ	00Ah
OFFSET_585_LAN_ADDR		equ	006h

;endif

;******************************************************************************
;	Defs for local variables
;******************************************************************************
BID_LOCAL_BID		equ	2
BID_LOCAL_EXTRA		equ	4
BID_LOCAL_CR		equ	2
BID_LOCAL_TCR		equ	4
BOARD_ID_EQU_INCLUDED	EQU	1
;
;first set of equates to be used with the value returned in AX, the Board ID
;
STARLAN_MEDIA		equ	0001h		; StarLAN
ETHERNET_MEDIA		equ	0002h		; Ethernet
TWISTED_PAIR_MEDIA	equ	0003h		; Twisted Pair
EW_MEDIA		equ	0004h		; Ethernet and Twisted Pair
TOKEN_MEDIA		equ	0005h		; Token Ring Media
UTP2_MEDIA		equ	0006h		; Adapter with 2 Ethernet UTP ports
MEDIA_MASK		equ	0007h		; Isolates Media Type
MICROCHANNEL		equ	0008h		; MicroChannel Adapter

INTERFACE_CHIP		equ	0010h		; Soft Config Adapter
ADVANCED_FEATURES	equ	0020h		; Adv. netw. interface features
BOARD_16BIT		equ	0040h		; 16 bit capability
PAGED_RAM		equ	0080h		; Adapter has paged RAM

PAGED_ROM		equ	0100h		; Adapter has paged ROM
PCM_ADAPTER		equ	0200h		; PCMCIA Adapter
LITE_VERSION		equ	0400h		; Reduced Feature Adapter, I.E Tiger.
NIC_SUPERSET		equ	0800h		; NIC is a superset of 790

NEC_BUS			equ	1000h		; Adapter is PC-98 NEC bus.
HMI_ADAPTER		equ	2000h		; Adapter has integral hub.

NO_AUI_MEDIA		equ	4000h		; Adapter is AUI-less:
						; Valid only for NIC_SUPERSET
SEE_BOARD_ID2		equ	8000h		; Use board_id2 info
;
;second set of equates to be used with the value returned in DX, the Extra Bits
;
RAM_SIZE_UNKNOWN	equ	0000h		; Unknown RAM size
RAM_SIZE_0K		equ	0001h		; 0K  RAM
RAM_SIZE_8K		equ	0002h		; 8k  RAM
RAM_SIZE_16K		equ	0003h		; 16k RAM
RAM_SIZE_32K		equ	0004h		; 32k RAM
RAM_SIZE_64K		equ	0005h		; 64k RAM
RAM_SIZE_RESERVED_6	equ	0006h		; Reserved RAM size
RAM_SIZE_RESERVED_7	equ	0007h		; Reserved RAM size
RAM_SIZE_MASK		equ	0007h		; Isolates RAM Size
SLOT_16BIT		equ	0008h		; 16 bit board - 16 bit slot

INTERFACE_5X3_CHIP	equ	0000h		; 0000 = 583 or 593 chips
NIC_690_BIT		equ	0010h		; NIC is 690
ALTERNATE_IRQ_BIT	equ	0020h		; Alternate IRQ is used
INTERFACE_584_CHIP	equ	0040h		; 0001 = 584 chip
INTERFACE_594_CHIP	equ	0080h		; 0010 = 594 chip
INTERFACE_585_CHIP	equ	0100h		; 0100 = 585/790 chip
INTERFACE_CHIP_MASK	equ	03C0h		; Isolates Intfc Chip Type

NIC_825_BIT		equ	0400h		; TRC 83C825 NIC
NIC_790_BIT		equ	0800h		; NIC is 83C790 Ethernet

CHIP_REV_MASK		equ	3000h		; Use two bottom bits of the
						; upper nibble for chip rev.

SEE_EXTRA_BITS2		equ	8000h		; Use extra_bits2 info

;******************************************************************************
;	Full board type definitions
;******************************************************************************

WD8003E		equ	ETHERNET_MEDIA
WD8003EBT	equ	WD8003E
WD8003S		equ	STARLAN_MEDIA
WD8003SH	equ	WD8003S
WD8003WT	equ	TWISTED_PAIR_MEDIA
WD8003W		equ	(TWISTED_PAIR_MEDIA OR INTERFACE_CHIP)
WD8003EB	equ	(ETHERNET_MEDIA OR INTERFACE_CHIP)
WD8003EP	equ	WD8003EB	; with INTERFACE_584_CHIP
WD8003EW	equ	(EW_MEDIA OR INTERFACE_CHIP)
WD8003ETA	equ	(ETHERNET_MEDIA OR MICROCHANNEL)
WD8003STA	equ	(STARLAN_MEDIA OR MICROCHANNEL)
WD8003EA	equ	(ETHERNET_MEDIA OR MICROCHANNEL OR INTERFACE_CHIP)
WD8013EPA	equ	WD8003EA	; with INTERFACE_594_CHIP
WD8003SHA	equ	(STARLAN_MEDIA OR MICROCHANNEL OR INTERFACE_CHIP)
WD8003WA	equ	(TWISTED_PAIR_MEDIA OR MICROCHANNEL OR INTERFACE_CHIP)
WD8013WPA	equ	WD8003WA	; with INTERFACE_594_CHIP
WD8013EBT	equ	(ETHERNET_MEDIA OR BOARD_16BIT)
WD8013EB	equ	(ETHERNET_MEDIA OR BOARD_16BIT OR INTERFACE_CHIP)
WD8013W		equ	(TWISTED_PAIR_MEDIA OR BOARD_16BIT OR INTERFACE_CHIP)
WD8013EW	equ	(EW_MEDIA OR BOARD_16BIT OR INTERFACE_CHIP)
WD8013EWC	equ	(WD8013EW OR ADVANCED_FEATURES)
WD8013WC	equ	(WD8013W OR ADVANCED_FEATURES)
WD8013EPC	equ	(WD8013EB OR ADVANCED_FEATURES)
WD8003WC	equ	(WD8003W OR ADVANCED_FEATURES)
WD8003EPC	equ	(WD8003EP OR ADVANCED_FEATURES)
WD8115TA	equ	(TOKEN_MEDIA OR MICROCHANNEL OR INTERFACE_CHIP OR PAGED_RAM)
WD8115T		equ	(TOKEN_MEDIA OR INTERFACE_CHIP OR BOARD_16BIT OR PAGED_RAM)
WD8208T		equ	(WD8003WC OR PAGED_ROM OR PAGED_RAM)
WD8208		equ	(WD8003EPC OR PAGED_ROM OR PAGED_RAM)
WD8208C		equ	(EW_MEDIA OR INTERFACE_CHIP OR ADVANCED_FEATURES OR PAGED_ROM OR PAGED_RAM)

WD8216T		equ	(WD8013WC OR PAGED_ROM OR PAGED_RAM)
WD8216 		equ	(WD8013EPC OR PAGED_ROM OR PAGED_RAM)
WD8216C		equ	(WD8013EWC OR PAGED_ROM OR PAGED_RAM)
PCM10BT		equ	(TWISTED_PAIR_MEDIA OR PCM_ADAPTER OR PAGED_RAM OR ADVANCED_FEATURES)
WD8216L		equ	(WD8216 OR LITE_VERSION)
WD8216LT	equ	(WD8216T OR LITE_VERSION)
WD8216LC	equ	(WD8216C OR LITE_VERSION)
WD8216N		equ	(WD8216 OR NEC_BUS)
WD8216TN	equ	(WD8216T OR NEC_BUS)
WD8216CN	equ	(WD8216C OR NEC_BUS)
WD8216TH	equ	(WD8216T OR HMI_ADAPTER)
WD8216LTH	equ	(WD8216LT OR HMI_ADAPTER)
WD8216T2	equ	((WD8216T AND NOT MEDIA_MASK) OR UTP2_MEDIA)

WD8416T		equ	(WD8216T OR NIC_SUPERSET OR NO_AUI_MEDIA) ; UTP
WD8416BT	equ	(WD8216C OR NIC_SUPERSET OR NO_AUI_MEDIA) ; BNC/UTP
WD8416B		equ	(WD8216  OR NIC_SUPERSET OR NO_AUI_MEDIA) ; BNC
WD8416BTA	equ	(WD8216C OR NIC_SUPERSET)		; BNC/UTP/AUI
WD8416TA	equ	(WD8216T OR NIC_SUPERSET)		; UTP/AUI
WD8416BA	equ	(WD8216  OR NIC_SUPERSET)		; BNC/AUI

WD8414T		equ	(WD8416T   OR LITE_VERSION)	; UTP
WD8414BT	equ	(WD8416BT  OR LITE_VERSION)	; BNC/UTP
WD8414B		equ	(WD8416B   OR LITE_VERSION)	; BNC
WD8414BTA	equ	(WD8416BTA OR LITE_VERSION)	; BNC/UTP/AUI
WD8414TA	equ	(WD8416TA  OR LITE_VERSION)	; UTP/AUI
WD8414BA	equ	(WD8416BA  OR LITE_VERSION)	; BNC/AUI


;
;	Defs for PCM adapters
;
REG_PCM_RESETDRV	equ	002h
REG_PCM_GEN_CTRL	equ	003h
GEN_CTRL_INTR		equ	010h
GEN_CTRL_IO_CARD	equ	020h
GEN_CTRL_RST		equ	040h


REG_PCM_IO_START_LO	equ	008h
REG_PCM_IO_START_HI	equ	009h
REG_PCM_IO_STOP_LO	equ	00Ah
REG_PCM_IO_STOP_HI	equ	00Bh

REG_PCM_MEM_START_LO	equ	010h
REG_PCM_MEM_START_HI	equ	011h
REG_PCM_MEM_STOP_LO	equ	012h
REG_PCM_MEM_STOP_HI	equ	013h

REG_PCM_MEM_OFST_LO	equ	014h
REG_PCM_MEM_OFST_HI	equ	015h
MEM_ADD17		equ	020h	; Memory Address bit 17 aligned at 12.

REG_PCM_WIN_ENABLE	equ	006h
PCM_MEMWIN_EN0		equ	001h
PCM_MEMWIN_EN1		equ	002h
PCM_MEMWIN_EN2		equ	004h
PCM_MEMWIN_EN3		equ	008h
PCM_MEMWIN_EN4		equ	010h

PCM_IOWIN_EN0		equ	040h
PCM_IOWIN_EN1		equ	080h

PCM_MEM_16BIT		equ	080h
PCM_MEM_WAIT_STATE	equ	040h
