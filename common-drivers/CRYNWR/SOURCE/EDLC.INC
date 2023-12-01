        SUBTTL  Data - Equates for the 8005 Chip
	PAGE +
;****************************************************************************
;
;	Data Name:	Equates
;
;	Procedure Type: Data
;
;	Assumes:
;               Nothing.
;
;	Returns:
;		Provides values for 8005 register usage.
;
;	Description:	
;		Equates defining 8005 register usage. See SEEQ data book
;               for a complete discussion of the 8005 EDLC.  This file has
;               been modified to contain literals used by the PEA.  The file
;               RAVEN.MAC contains macros that allow the usage of the PEA with
;               minimal changes to the underlying source code.
;
;	Author:
;               Aguillon
;
;	Date Written:	
;               09/01/90
;
;	Revision History:
;               09/01/90 - First Written
;***************************************************************************/

;
;       8005 COMMAND register definitions
;
DMA_INT_EN		EQU	0001h
RX_INT_EN		EQU	0002h
TX_INT_EN		EQU	0004h
WINDOW_INT_EN		EQU	0008h
DMA_INT_ACK		EQU	0010h
RX_INT_ACK		EQU	0020h
TX_INT_ACK		EQU	0040h
WINDOW_INT_ACK		EQU	0080h
SET_DMA_ON		EQU	0100h
SET_RX_ON		EQU	0200h
SET_TX_ON		EQU	0400h
SET_DMA_OFF		EQU	0800h
SET_RX_OFF		EQU	1000h
SET_TX_OFF		EQU	2000h
FIFO_READ		EQU	4000h
FIFO_WRITE		EQU	8000h

	;
	;	8005 STATUS register definintions
	;
DMA_INT			EQU	0010h
RX_INT			EQU	0020h
TX_INT			EQU	0040h
WINDOW_INT		EQU	0080h
DMA_ON			EQU	0100h
RX_ON			EQU	0200h
TX_ON			EQU	0400h
COLLISIONS_16           EQU     1000h           ; 16-collisions if == 0
FIFO_FULL		EQU	2000h
FIFO_EMPTY		EQU	4000h
FIFO_DIR		EQU	8000h

	;
	;	8005 CONFIGURATION 1 register definitions
	;
MATCH_BITS		EQU	0c000h
MATCH_ONLY		EQU	0000h
MATCH_BROAD		EQU	4000h
MATCH_MULTI		EQU	8000h
MATCH_ALL		EQU	0c000h
ALL_STATIONS		EQU	3f00h
STATION_0_EN		EQU	0100h
STATION_1_EN		EQU	0200h
STATION_2_EN		EQU	0400h
STATION_3_EN		EQU	0800h
STATION_4_EN		EQU	1000h
STATION_5_EN		EQU	2000h
DMA_LENGTH		EQU	00c0h
NBYTES_1		EQU	0000h
NBYTES_2		EQU	0040h
NBYTES_4		EQU	0080h
NBYTES_8		EQU	00c0h
DMA_INTERVAL		EQU	0030h
CONTINUOUS		EQU	0000h
DELAY_800		EQU	0010h
DELAY_1600		EQU	0020h
DELAY_3200		EQU	0030h
BUFFER_CODE_BITS 	EQU	000fh
STATION_0_SEL		EQU	0000h
STATION_1_SEL		EQU	0001h
STATION_2_SEL		EQU	0002h
STATION_3_SEL		EQU	0003h
STATION_4_SEL		EQU	0004h
STATION_5_SEL		EQU	0005h
PROM_SEL		EQU	0006h
TEA_SEL			EQU	0007h
BUFFER_MEM_SEL		EQU	0008h
INT_VECTOR_SEL		EQU	0009h
CONFIG3_REG_SEL         EQU     000Ch
PRODUCT_ID_SEL          EQU     000Dh
MULTICAST_TABLE_SEL     EQU     000Fh

PRODUCT_ID_MASK         EQU     00F0h

CMOS_PART               EQU     0A0h

	;
	;	8005 CONFIGURATION 2 register definitions
	;
BYTE_SWAP		EQU	0001h
AUTO_UPDATE_REA		EQU	0002h
DISABLE_SELF_RCV        EQU     0004h
CRC_ERR_EN		EQU	0008h
DRIBBLE_EN		EQU	0010h
SHORT_FRAME_EN		EQU	0020h
SLOT_TIME_SELECT 	EQU	0040h
XMIT_NO_PREAMBLE 	EQU	0080h
ADDR_LENGTH		EQU	0100h
RECEIVE_CRC		EQU	0200h
XMIT_NO_CRC		EQU	0400h
LOOPBACK_EN		EQU	0800h
KILL_WATCHDOG		EQU	1000h
RESET			EQU	8000h


;--------Configuration 3 register---------------;
AUTO_PAD_TXPKTS         EQU     01h
SWAP_NEXT_PKT_PTR       EQU     80h



COAX_TYPE              EQU     1000h
UTP_TYPE               EQU     0000h


	;
	;	8005 TRANSMIT HEADER COMMAND BYTE definitions
	;
PACKET_PRESENT		EQU	80h
CHAIN_CONTINUE		EQU	40h
DATA_FOLLOWS		EQU	20h
CMD_B4			EQU	10h		;NOTE: This bit is undefined
XMIT_OK_INT_EN		EQU	08h
COLL_16_INT_EN		EQU	04h
COLL_INT_EN		EQU	02h
BABBLE_INT_EN		EQU	01h

	;
	;	8005 TRANSMIT PACKET STATUS BYTE definitions
	;
DONE			EQU	80h
COLL_16_ERROR		EQU	04h
COLLISION		EQU	02h
BABBLE_ERROR		EQU	01h

	;
	;	8005 RECEIVE PACKET STATUS BYTE definitions
	;
SHORT_FRAME		EQU	08h
DRIBBLE_ERROR		EQU	04h
CRC_ERROR		EQU	02h
OVERSIZE		EQU	01h

;
;       Mask to test for end of packet chain
;
END_OF_PACKET_CHAIN	EQU	00FFh

;
;       FIFO DEPTH
;
FIFO_Depth	EQU	18			;Byte Mode, length is 18

;
;       First Three Bytes of Node Address in PROM (Fixed)
;
PROMAddressByte1	EQU	00h
PROMAddressByte2	EQU	80h
PROMAddressByte3	EQU	1bh
