; Equates for the code to serach the I/O space
FIRST_IO		EQU	22h		; First I/O port to check
LAST_IO			EQU	402h	; Last I/O port to check (+10h)
ID_REG_MASK		EQU	02Ch	; Bits invloved in the mask register
ID_REG_SIG		EQU 024h 	; Expected 82595 Signature
R_ROBIN_BITS	EQU	0C0h	; Bits containing the round robin counter

IRQ_MAP_LEN 	EQU	2	; No of butes in the IRQ map
RAM_SIZE	EQU	8000h	; RAM on the card only has 32k bytes

GIANT		equ	1514		; largest legal size packet, no fcs
TX_BUF_CNT	EQU	2			; Number of simultaeous TX packets
TX_HEADER	EQU	8			; Header overhead for each TX packet
TX_FRAME_SIZE	EQU	GIANT+TX_HEADER	; Max size of each frame
TX_AREA_SIZE	EQU	(((TX_FRAME_SIZE*TX_BUF_CNT)/256)+1)*256
RX_AREA_SIZE	EQU     RAM_SIZE - TX_AREA_SIZE
RX_AREA_BEG		EQU	0
RX_AREA_END		EQU	RX_AREA_BEG + RX_AREA_SIZE - 1
TX_AREA_BEG		EQU	RX_AREA_END + 1
TX_AREA_END		EQU	RAM_SIZE - 1

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

; Receive frame status
RCV_DONE	EQU     0008h
RX_OK		EQU     2000h
RX_ERROR	EQU     0D81h	; Various error conditions
RCV_OUR_OWN	EQU		0002h

TX_DONE_BIT	EQU		80h		; TX status byte will have this bit when done
TX_HDR_SIZE	EQU		08h		; TX header overhead
CHAIN_BIT	EQU		80h		; Used in the TX bute count to chain packets

BANK0 EQU 00h
BANK0_SELECT EQU 00h
BANK1 EQU 01h
BANK1_SELECT EQU 40h
BANK2 EQU 02h
BANK2_SELECT EQU 80h

; Bank 0 registers
COMMAND_REG	EQU	00h		; Available for all banks
	XMT_CMD		EQU	04h
	RCV_ENABLE	EQU	08h
	RESET_CMD	EQU 0Eh
	RESUME_XMT_CMD	EQU	1Ch
	SEL_RESET	EQU	1Eh
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
RCV_STOP_HIGH	EQU	07h
XMT_ADDR_REG	EQU	0Ah
HOST_ADDRESS	EQU	0Ch
LOCAL_MEM_PORT	EQU	0Eh

; Bank 1 registers
REG1	EQU		01h
	WORD_WIDTH	EQU	02h
	INT_ENABLE	EQU	80h
INT_NO_REG	EQU	02h
REC_LOW_LIMIT_REG	EQU	08h
REC_UPPER_LIMIT_REG	EQU	09h
XMT_LOW_LIMIT_REG	EQU	0Ah
XMT_UPPER_LIMIT_REG	EQU	0Bh

; Bank 2 registers
RECV_MODES_REG	EQU	02h
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
