
; Receive frame status
BIT1			EQU 02h
WRAP_BIT		EQU 80h
RCV_DONE		EQU 0008h
RX_ERROR		EQU 0D81h	; Various error conditions
SHORT_FRAME_BIT	EQU	0080h
OVER_RUN_BIT	EQU	0100h
ALIGN_BIT		EQU	0400h
CRC_BIT			EQU	0800h
RX_OK			EQU 2000h
RCV_OUR_OWN		EQU	0002h


CMD_DONE_BIT	EQU	80h		; Commands will have this bit set when done
CMD_OK_BIT		EQU 2000h	; Set if command completed with no errors

TX_DONE_BIT		EQU	80h		; TX status byte will have this bit when done
TX_HDR_SIZE		EQU	08h		; TX header overhead
CHAIN_BIT		EQU	80h		; Used in the TX bute count to chain packets

BANK0 EQU 00h
BANK0_SELECT EQU 00h
BANK1 EQU 01h
BANK1_SELECT EQU 40h
BANK2 EQU 02h
BANK2_SELECT EQU 80h

; Bank 0 registers
COMMAND_REG	EQU	00h		; Available for all banks
	XMT_CMD			EQU	04h
	JOIN_RING_CMD	EQU	04h
	TEST_RING_CMD	EQU	05h
	RCV_ENABLE		EQU	08h
	RESET_CMD		EQU 0Eh
	CONFIG_CMD		EQU	10h
	ENABLE_80186	EQU 1Ah
	DISABLE_80186	EQU 1Bh
	RESUME_XMT_CMD	EQU	1Ch
	SEL_RESET		EQU	1Eh
STATUS_REG	EQU	01h
	RX_INT	EQU	02h
	EXEC_STATUS	EQU	030h
ID_REG			EQU	02h
INT_MASK_REG	EQU	03h
	RX_STOP_MASK	EQU 01h
	RX_MASK			EQU 02h
	TX_MASK			EQU 04h
	EXEC_MASK		EQU 08h
	ALL_MASK		EQU 0fh
BAR_LOW			EQU	04h
BAR_HIGH		EQU	05h
RCV_STOP_LOW	EQU	06h
BLOCK_SEL_REG	EQU	09h
XMT_ADDR_REG	EQU	0Ah
HOST_ADDRESS	EQU	0Ch
LOCAL_MEM_PORT	EQU	0Eh

; Bank 1 registers
REG1	EQU		01h
	WORD_WIDTH	EQU	02h
	INT_ENABLE	EQU	80h
INT_NO_REG	EQU	02h
RCV_LOW_LIMIT_REG	EQU	08h
RCV_UPPER_LIMIT_REG	EQU	09h
XMT_LOW_LIMIT_REG	EQU	0Ah
XMT_UPPER_LIMIT_REG	EQU	0Bh

; Bank 2 registers
RCV_MODES_REG	EQU	02h
	NO_RX_CRC		EQU	04h
	NO_ADD_INS		EQU	10h
	MATCH_ID		EQU	NO_ADD_INS OR NO_RX_CRC OR 02h
	MATCH_ALL		EQU	NO_ADD_INS OR NO_RX_CRC OR 01h OR 20h
	MATCH_BRDCAST	EQU	NO_ADD_INS OR NO_RX_CRC
	MATCH_MULTICAST	EQU	NO_ADD_INS OR NO_RX_CRC OR 20h
REG3	EQU		03h
	TPE_BIT	EQU	04h
	TEST_MODE_MASK	EQU 3fh
I_ADD_REG0	EQU 04h
I_ADD_REG1	EQU 05h
I_ADD_REG2	EQU 06h
I_ADD_REG3	EQU 07h
I_ADD_REG4	EQU 08h
I_ADD_REG5	EQU 09h
EEPROM_REG	EQU 0AH
; Bit positions in the EEPROM_REG
	EEDO	EQU	08h
	EEDI	EQU	04h
	EECS	EQU	02h
	EESK	EQU	01h

;bit masks within EEPROM word 1:
EEPROM_RING_SPEED_16        EQU 0008H
EEPROM_EARLY_TR             EQU 0010H
EEPROM_AUTODETECT           EQU 0020H


LOAD_PORT	MACRO port_param
	mov		dx, base_addr
	add		dx, port_param
	port_no	= port_param
	ENDM

LOAD_BANK_PORT	MACRO new_bank_no, new_port_no
	push	ax
	if new_bank_no EQ BANK0
		mov		al, BANK0_SELECT
	else
		if new_bank_no EQ BANK1
			mov		al, BANK1_SELECT
		else
			mov		al, BANK2_SELECT
		endif
	endif
	mov		dx, base_addr
	out		dx, al
	if new_port_no NE 0
		if new_port_no EQ 1 
			inc	dx
		else
			add	dx, new_port_no
		endif
	endif
	pop		ax
	bank_no	= new_bank_no
	port_no	= new_port_no
	ENDM

SET_PORT	MACRO port_param
	if port_param - port_no EQ 1
		inc	dx
	else
		if port_param - port_no EQ -1
			dec	dx
		else
			if port_param - port_no NE 0
				add	dx,port_param - port_no
			endif
		endif
	endif
	port_no	= port_param
	ENDM


SET_BANK_PORT	MACRO new_bank_no,new_port_no
	if new_bank_no NE bank_no
		push	ax
		SET_PORT	COMMAND_REG
		if new_bank_no EQ BANK0
			mov		al, BANK0_SELECT
		else
			if new_bank_no EQ BANK1
				mov		al, BANK1_SELECT
			else
				mov		al, BANK2_SELECT
			endif
		endif
		out		dx, al
		pop		ax
	endif
	SET_PORT	new_port_no
	bank_no	= new_bank_no
	port_no	= new_port_no
	ENDM

write_eeprom_bit	MACRO
		out		dx, al
		or		al, EESK				; Set the eeprom strobe
		out		dx,	al					; Write rising edge of strobe to eeprom
		and		al, NOT EESK			; Clear the eeprom strobe
		out		dx,	al					; Write falling edge of strobe to eeprom
		ENDM

read_eeprom_bit	MACRO
		mov		al, EECS OR EESK
		out		dx,	al					; Write rising edge of strobe to eeprom
		in		al, dx					; Get the data bit
		mov		bl,	al					; Place the result in bl
		mov		al, EECS				; Clear the eeprom strobe
		out		dx,	al					; Write falling edge of strobe to eeprom
		ENDM


; Equates for the code to search the I/O space
FIRST_IO		EQU	100h	; First I/O port to check
LAST_IO			EQU	400h	; Last I/O port to check (+10h)
ID_MASK			EQU	02Ch	; Bits invloved in the mask register
ID_BITS1		EQU 002h SHL 2 	; Mozart Signature bits 1'st and 2'nd location
ID_BITS2		EQU 009h SHL 2 	; Mozart Signature bits 3'rd and 4'th location
ID_SIG1			EQU (00 SHL 6) + ID_BITS1 ; Mozart 1'st Signature
ID_SIG2			EQU (01 SHL 6) + ID_BITS1 ; Mozart 2'nd Signature
ID_SIG3			EQU (02 SHL 6) + ID_BITS2 ; Mozart 3'rd Signature
ID_SIG4			EQU (03 SHL 6) + ID_BITS2 ; Mozart 4'th Signature
R_ROBIN_BITS	EQU	0C0h	; Bits containing the round robin counter

TOKEN_RUNT		EQU 18h
TOKEN_GIANT		EQU	4096h

RAM_SIZE		EQU	10000h	; RAM on the card - has 64k bytes for the host
SHARED_SIZE		EQU	400h	; 1k of RAM reserved for shared memory
TX_BUF_CNT		EQU	2			; Number of simultaeous TX packets
TX_HEADER		EQU	8			; Header overhead for each TX packet
; For token ring need to include addition header + rif
TX_FRAME_SIZE	EQU	TOKEN_GIANT+TX_HEADER	+ 30 + 8; Max size of each frame
TX_AREA_SIZE	EQU	(((TX_FRAME_SIZE*TX_BUF_CNT)/100h)+1)*100h
RX_AREA_SIZE	EQU RAM_SIZE - SHARED_SIZE - TX_AREA_SIZE
RX_AREA_BEG		EQU	SHARED_SIZE
RX_AREA_END		EQU	RX_AREA_BEG + RX_AREA_SIZE - 1
TX_AREA_BEG		EQU	RX_AREA_END + 1
TX_AREA_END		EQU	RAM_SIZE - 1

IRQ_MAP_LEN 	EQU	2	; No of butes in the IRQ map

; Ring configuration options
PBMF		EQU	0001h		; Pass Beacon MAC frames
PAMF		EQU	0002h		; Pass Attemtion MAC frames
PUMF		EQU	0004h		; Pass Unsupported MAC frames
FMRO		EQU	0008h		; Media rate option : 1 = 16 Mbits
FETO		EQU 0010h		; Early token release
FCCO		EQU	0020h		; Claim conteder
FRRO		EQU	0040h		; Reject remove frame
ASMR		EQU	0080h		; Auto sense media rate
ALLMAC		EQU	0100h		; Receive all MAC frame in promiscuous mode
ALL_NON_MAC	EQU	0200h		; Pass Non-MAC frames in promiscuous mode
ATRM		EQU 0400h		; Active Token Ring Management
ATRST		EQU 0800h		; Active Token Ring Status Change
TRSSER		EQU 1000h		; Token Ring Status Soft Error Report
TRSHER		EQU 2000h		; Token Ring Status Hard Error Report

; Join ring options
CANONICAL	EQU 0001h
WRAPPED_L	EQU 0002h
RPL			EQU	0004h
WRAPPED_B	EQU 0008h
W_DOG_EN	EQU	0010h
CONG_AVODI	EQU	8000h

; Join ring status
JOINED_AT_16		EQU	0100h
JOIN_STATUS_MASK	EQU	000Fh
FIRST_ON_RING		EQU	0006h
NO_SPEED_DETECT		EQU	0007h

; LOCATIONS RESERVED IN THE SHARED MEMORY REGION OF BLOCK 1
JOIN_RING_LOC	EQU	0104h
STOP_REG_LOC	EQU	0100h
WATCH_DOG		EQU 0102h

; DOWNLOADER EQUATES
REFRSH_CODE_SIZE	EQU	400h
SECOND_PART			EQU	0C00h
RESTART_LOC			EQU 0FFF0h
RESTART_JMP_SIZE 	EQU	6h
HANDSHAKE_LOC		EQU 004Ch
DOWNLOAD_FLAG_LOC	EQU	004Eh
HANDSHAKE_VALUE		EQU	9090h

CONFIG_CMD			EQU	0010H
CONFIG_CMD_LEN		EQU	0008H

; Receive Header
; Description of header of each packet in receive area of memory
RBUF_CMD		EQU	0	; Receive done command or NOP if no more frames
RBUF_DUMMY		EQU	1	; Empty byte in the header
RBUF_STAT_LOW	EQU	2	; Received frame status
RBUF_STAT_HI	EQU	3	; Received frame status
RBUF_NEXT_LOW	EQU	4	; Low 8 bit address of start of next frame
RBUF_NEXT_HI	EQU	5	; High 8 bit address of start of next frame
RBUF_SIZE_LOW	EQU	6	; Length of this frame
RBUF_SIZE_HI	EQU	7	; Length of this frame
RBUF_HEAD_LEN	EQU	8	; Length of this header
RBUF_AC_FIELD	EQU	8	; Access control field
RBUF_FC_FIELD	EQU	9	; Frame control field
RX_CTRL_FIELDS	EQU	2	; Number of receive control fields

CRC_SIZE		EQU	4	; Length of CRC field

RII_BIT				EQU	80H	; If set indicates routing bytes follow

LLC_AC		EQU	00h		; access control LLC
LLC_FC		EQU	40h		; frame control  LLC

LLC_FIELDS	EQU	(LLC_FC SHL 8) + LLC_AC

LLC_SSAP_DSAP	EQU	0AAAAh	
LLC_CON			EQU	03h
CTRL_FIELD_SIZE	EQU	02h
LLC_SIZE		EQU	03h
SNAP_SIZE		EQU	05h - 2 ; Last two bytes hold the 'regular' type byte
;TOKEN_HDR_SIZE	EQU 8	; XMT & FC FIELDS, 3 LLC fields, 3 SNAP bytes
TOKEN_HDR_SIZE	EQU  CTRL_FIELD_SIZE + LLC_SIZE + SNAP_SIZE

DEST_ADDR		EQU	RBUF_HEAD_LEN+RX_CTRL_FIELDS
SOURCE_ADDR		EQU	DEST_ADDR+EADDR_LEN
RX_ROUTING		EQU SOURCE_ADDR+EADDR_LEN
RX_LLC			EQU RX_ROUTING			; ROUTING length is 0 - 30
RX_SNAP			EQU RX_LLC + LLC_SIZE
RX_TYPE			EQU RX_SNAP + SNAP_SIZE
RX_FIRST_WORD	EQU RX_TYPE + 2

; Transmit header
; Positions within the tx_hdr_buff
TX_DEST_ADDR	EQU	4					; Count word + CTRL word
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

my_name	EQU	"Token Express Pro"

ROUTING			EQU 1	; 1 if SOURCE routing is to be performed
ARP_CONVERSION	EQU 1	; 1 if ARP packet conversion is to be performed
