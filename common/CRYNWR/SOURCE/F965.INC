;
;   Copyright (C) 1993, RF Nets, Cupertino, CA 
;   All Rights Reserved
;   Author:kevinr@Solaris.com
;
;
;  f965.inc - definitions include for for Fujitsu 86965 EtherCoupler
;    
;  $Id$
;
;  $Log$
;
;
;  DLCR0 - Transmit Status - offset 0x00
;
TX_DONE	Equ	10000000b	;all packets in buffer transmitted <I>
NET_BSY	Equ	01000000b	;real time image of carrier detect line
TX_PKT_RCD Equ	00100000b	;no collison on last pkt xmitted
CR_LOST	Equ	00010000b	;carrier lost on last pkt xmitted (collison!)
JABBER	Equ	00001000b	;jabber timer expired <I>
COL	Equ	00000100b	;collision occurred <I>  
COL16	Equ	00000010b	;16 collisions occurred on one packet <I> 
;
;  DLCR1 - Receive Status - offset 0x01
;
RX_PKT	Equ	10000000b	;packet arrived in receive buffer <I>
BUS_RD_ERR Equ	01000000b	;bus read error - empty buffer <I>
DMA_EOP	Equ	00100000b	;host asserted DMA done. <I>
RMT_0900 Equ	00010000b	;pkt rcved with type field = 0900H <I>
RUNT_PKT Equ	00001000b	;packet less than 60 bytes rcved <I>
ALIGN_ERR Equ	00000100b	;last byte didn't have 8 bits <I>
CRC_ERR	Equ	00000010b	;last pkt rcved had incorrect CRC <I>
RX_BUF_OVFL Equ	00000001b	;rcv buffer overflow <I>
;
;  DLCR2 - Transmit Interrupt Enable - offset 0x02
;
TX_DONE_IE	Equ	10000000b	;generate interrupt on TX DONE
JABBER_IE	Equ	00001000b	;interrupt on JABBER
COL_IE		Equ	00000100b	;interrupt on 1 Collision
COL16_IE	Equ	00000010b	;interrupt on 16 Collisions
;
; DLCR3 - Receive interrupt enable - offset 0x03
;
;					 generate interrupt on:
RX_PKT_IE	Equ	10000000b	;rcv pkt
BUS_RD_ERR_IE	Equ	01000000b	;bus read error (buffer empty)
DMA_EOP_IE	Equ	00100000b	;host DMA assert done
RMT_0900_IE	Equ	00010000b	;remote link test pkt
RUNT_PKT_IE	Equ	00001000b	;runt pkacet received
ALIGN_ERR_IE	Equ	00000100b	;<8 bit byte received
CRC_ERR_IE	Equ	00000010b	;packet CRC incorrect
RX_BUF_OVFL_IE	Equ	00000001b	;rcv buffer overflow
;
;   DLCR4 - Transmit Mode - offset 0x04
;
COL_CTR		Equ	11110000b	;count of tx collisions (mask)
CNTRL		Equ	00000100b	;control output line
LBC		Equ	00000010b	;loopback (0)
EN_TX_DEFER	Equ	00000001b	;enable carrier sense before xmit
;
;   DLCR5 - Receive Mode - offset 0x05
RX_BUF_EMPTY	Equ	01000000b	;receive buffer empty
ACPT_BAD_PKT	Equ	00100000b	;accept pkts with CRC,alig,runt errors
RX_SHORT_ADDR	Equ	00010000b	;40 bit MAC address length
ACPT_RUNT_PKT	Equ	00001000b	;accept pkts <60 bytes in length
RMT_RST		Equ	00000100b	;enable remote reset of rcver
AF1		Equ	00000010b	;address filter mode bit 1
AF0		Equ	00000001b	;address filter mode bit 0
;
;   DLCR6 - Configuration 0 - offset 0x06
;
DLC_EN		Equ	10000000b	;DLC enable (0)
SRAM_CYCLE_CLK	Equ	01000000b	;SRAM cycle time 1=100ns;0=150ns
SYSTEM_BUSW	Equ	00100000b	;system bus width 1=8bit;0=16bit
BUFFER_BUSW	Equ	00010000b	;buffer bus width
TX_BUF_SIZE	Equ	00001100b	;Tx buffer size
BUF_SIZE	Equ	00000011b	;packet buffer size
;
TBS_1_2		Equ	00000000b	;Tx Buff count = 1, size = 2K
TBS_2_2		Equ	00000100b	;Tx Buff count = 2, size = 2K
TBS_2_4		Equ	00001000b	;Tx Buff count = 2, size = 4K
TBS_2_8		Equ	00001100b	;Tx Buff count = 2, size = 8K
BS_32		Equ	00000010b	;total buffer size = 32K
;
;   DLCR7 - Configuration 1 - offset 0x07
;
ECID		Equ	11000000b	;EtherCoupler Chip ID
PWRON		Equ	00100000b	;Powerdown Mode 1=on;0=down
RDYPNSEL	Equ	00010000b	;Ready Pin Polarity Select
RBS		Equ	00001100b	;register bank select
RBS_DLCRH	Equ	00000000b	;DLCR8-15
RBS_HT		Equ	00000100b	;Hash Table 8-15 (HT8-15)
RBS_BMPR	Equ	00001000b	;BMPR8-15
EOPPOL		Equ	00000010b	;DMA done polarity
BYTE_ORDER	Equ	00000001b	;Byte Ordering Control
;
;   TO acces any BMPR register, DLCR7.RBS must be set to RBS_BMPR
;
;   BMPR10 - Transmit Start - offset 0x0A 
;
TX_START	Equ	10000000b	;start transmitting a packet
TX_PKT_CNT	Equ	01111111b	;count of pkts to transmit
;
;   BMPR11 - 16 Collisions Control - offset 0x0B 
;
COL_16_CTL2	Equ	00000100b	;control 1 mask enable
COL_16_CTL1	Equ	00000010b	;control 0 mask enable
COL_16_CTL 	Equ	00000001b	;re-xmit or discard after 16 col
;
;   BMPR12 - DMA Enable - offset 0x0C 
;
RX_DMA_EN	Equ	00000010b	;enable receive side DMA (READ)
TX_DMA_EN	Equ	00000001b	;enable transmit side DMA (WRITE)
;
;  BMPR13 - DMA Burst and Transceiver Mode - offset 0x0D
;
IO_BASE_UNLOCK	Equ	10000000b	;increment I/O Base Decode
SQ_THLD		Equ	01000000b	;reduce squelch threshold
LINK_TEST_EN	Equ	00100000b	;link integrity test
AUI_TP_SEL	Equ	00010000b	;select between AUI and TP
AUTO_PORT_SEL	Equ	00001000b	;manual or auto port select
STP_UTP		Equ	00000100b	;100 (UTP) or 150 (STP) ohm termination
BURST_CTL	Equ	00000011b	;burst length control
BUSRT_LEN1	Equ	00000000b	;    len = 1
BUSRT_LEN4	Equ	00000001b	;    len = 4
BUSRT_LEN8	Equ	00000010b	;    len = 8
BUSRT_LEN12	Equ	00000011b	;    len = 12
;
;   BMPR14 - Filter Self Receive - offset 0x0E
;
RLD_IE		Equ	10000000b	;RLD interrupt enable
LLD_IE		Equ	01000000b	;LLD    ""       "" 
RJAB_IE		Equ	00100000b	;RJAB interrupt enable
SKIP_PKT	Equ	00000100b	;Skip received Packet
SQE_IE		Equ	00000010b	;SQE error interrupt enable
FILTER_SELF_RX	Equ	00000001b	;Rcv transmitted packets
;
;   BMPR15 - Transceiver Status Register
;
RLD		Equ	10000000b	;Remote Link Down
LLD		Equ	01000000b	;Local Link Down
RJAB		Equ	00100000b	;Remote port in Jabber condx
RMT_PORT	Equ	00010000b	;remote port compatible
RXI_POL_REV	Equ	00001000b	;reverse receive polarity
SQE		Equ	00000010b	;SQE error
;
;   BMPR16 thru 19 can be addressed regardless of the DLCR7.RBS setting
;
;
;   BMPR16 - EEPROM Control - offset 0x10
;
EEP_ESK		Equ	01000000b	;EEPROM Shift Data Clock
EEP_ECS		Equ	00100000b	;EEPROM chip select
;
;   BMPR17 - EEPROM Data - offset 0x11
;
EEP_EDIO	Equ	10000000b	;EEPROM Data I/O port
;
;   BMPR19 - Jumperless Configuration
;
INTSEL		Equ	11000000b	;Interrupt Line selected
INTSEL_0	Equ	00000000b	;IRQ0 (wired to ?)
INTSEL_1	Equ	01000000b	;IRQ1 (wired to ?)
INTSEL_2	Equ	10000000b	;IRQ2 (wired to ?)
INTSEL_3	Equ	11000000b	;IRQ3 (wired to ?)
MEMSEL		Equ	00111000b	;Memory decode selection
IOSEL		Equ	00000111b	;I/O base decode selection
IOSEL_0		Equ	00000000b	;260-27f
IOSEL_1		Equ	00000001b	;280-29f
IOSEL_2		Equ	00000010b	;2A0-2Bf
IOSEL_3		Equ	00000011b	;240-25f
IOSEL_4		Equ	00000100b	;340-35f
IOSEL_5		Equ	00000101b	;320-33f
IOSEL_6		Equ	00000110b	;380-39f
IOSEL_7		Equ	00000111b	;300-31f
;
;-------------------------------------------------------------------
;
;  Register offset equates
;
DLCR0	Equ	0
DLCR1	Equ	1
DLCR2	Equ	2
DLCR3	Equ	3
DLCR4	Equ	4
DLCR5	Equ	5
DLCR6	Equ	6
DLCR7	Equ	7
;
DLCR8	Equ	8
DLCR9	Equ	9
DLCR10	Equ	10
DLCR11	Equ	11
DLCR12	Equ	12
DLCR13	Equ	13
DLCR14	Equ	14
DLCR15	Equ	15
;
NID0	Equ	DLCR8
NID1	Equ	DLCR9
NID2	Equ	DLCR10
NID3	Equ	DLCR11
NID4	Equ	DLCR12
NID5	Equ	DLCR13
;
TDR0	Equ	DLCR14
TDR1	Equ	DLCR15
;
HT8	Equ	8
HT9	Equ	9
HT10	Equ	10
HT11	Equ	11
HT12	Equ	12
HT13	Equ	13
HT14	Equ	14
HT15	Equ	15
;
BMPR8	Equ	8
BMPR9	Equ	9
BMPR10	Equ	10
BMPR11	Equ	11
BMPR12	Equ	12
BMPR13	Equ	13
BMPR14	Equ	14
BMPR15	Equ	15
;
BMPR16	Equ	16
BMPR17	Equ	17
BMPR18	Equ	18
BMPR19	Equ	19
;
;---------------------------------------------------------------------
;  EEPROM command codes
;---------------------------------------------------------------------
EEP_CMD_READ	Equ	10000000b	;read 16 bit register
;
;---------------------------------------------------------------------
;  EEPROM register layout
;---------------------------------------------------------------------
EEP_CONFIG_R0	Equ	0
;
;   -- end --  f965.inc
;
