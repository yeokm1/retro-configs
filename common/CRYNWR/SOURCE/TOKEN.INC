; Receive Header
RBUF_AC_FIELD	EQU	0	; Access control field
RBUF_FC_FIELD	EQU	1	; Frame control field
RX_CTRL_FIELDS	EQU	2	; Number of receive control fields

TOKEN_RUNT		EQU 18h
TOKEN_GIANT		EQU	4096h

CRC_SIZE		EQU	4	; Length of CRC field

RII_BIT			EQU	80H	; If set indicates routing bytes follow

LLC_AC			EQU	00h	; access control LLC
LLC_FC			EQU	40h	; frame control  LLC

LLC_FIELDS		EQU	(LLC_FC SHL 8) + LLC_AC

LLC_SSAP_DSAP	EQU	0AAAAh	
LLC_CON			EQU	03h
CTRL_FIELD_SIZE	EQU	02h
LLC_SIZE		EQU	03h
SNAP_SIZE		EQU	05h - 2 ; Last two bytes hold the 'regular' type byte
;TOKEN_HDR_SIZE	EQU 8	; XMT & FC FIELDS, 3 LLC fields, 3 SNAP bytes
TOKEN_HDR_SIZE	EQU  CTRL_FIELD_SIZE + LLC_SIZE + SNAP_SIZE

DEST_ADDR		EQU	RX_CTRL_FIELDS
SOURCE_ADDR		EQU	DEST_ADDR+EADDR_LEN
RX_ROUTING		EQU SOURCE_ADDR+EADDR_LEN
RX_LLC			EQU RX_ROUTING			; ROUTING length is 0 - 30
RX_SNAP			EQU RX_LLC + LLC_SIZE
RX_TYPE			EQU RX_SNAP + SNAP_SIZE
RX_FIRST_WORD	EQU RX_TYPE + 2

; Transmit header
; Positions within the tx_hdr_buff
TX_DEST_ADDR	EQU	CTRL_FIELD_SIZE	
TX_ROUTE		EQU	TX_DEST_ADDR + 2*EADDR_LEN

FAKE_RIF_SIZE	EQU	2h
;FAKE_ROUTE		EQU	2082h
FAKE_ROUTE		EQU	0A082h	; Bit 15 will be inverted

TYPE_BYTES_IN_HEADER	EQU	2
DATA_BYTES_IN_HEADER	EQU	2
DATA_IN_HEADER	EQU 2*EADDR_LEN + TYPE_BYTES_IN_HEADER + DATA_BYTES_IN_HEADER
; Number of bytes from the data which are part of the token ring header
; Includes the source and destination address, 2 Ethernet type bytes and the
; the first two bytes of the data

ARP_TX_FIX		EQU	0600h
ARP_RX_FIX		EQU	0100h
ARP_TYPE		EQU	0608h
ARP_DATA_LENGTH	EQU	1Ch

; Bytes left in ARP packet not included in the header
ARP_LEFT_SIZE	EQU	ARP_DATA_LENGTH - DATA_BYTES_IN_HEADER
ARP_PACKET_SIZE	EQU	TOKEN_HDR_SIZE + DATA_IN_HEADER + ARP_LEFT_SIZE

ROUTING			EQU 1	; 1 if SOURCE routing is to be performed
ARP_CONVERSION	EQU 1	; 1 if ARP packet conversion is to be performed
