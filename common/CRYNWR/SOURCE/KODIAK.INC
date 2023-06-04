;
; SEEQ 8005
;

; Registers

CMD	equ	00h			;command (write only)
STAT	equ	00h			;status (read only)
CONFIG1	equ	02h			;configure 1
CONFIG2	equ	04h			;configure 2
RXAREA	equ	06h			;receive end area
;K2WR	equ	07h			;ksetup 2 write
;KSTAT	equ	07h			;kombo status
BWIND	equ	08h			;buffer window
RXPTR	equ	0ah			;receive pointer
TXPTR	equ	0ch			;transmit pointer
DMAADR	equ	0eh			;dma address

; Command Register (CMD, write only)
;
ENABLE_RX_INT	equ     0002h
ENABLE_TX_INT	equ     0004h
ENABLE_BUF_INT	equ     0008h
ACK_RX_INT	equ     0020h
ACK_TX_INT	equ     0040h
ACK_BUF_INT	equ     0080h
ACK_INT		equ     00ffh
RX_ON		equ     0200h
TX_ON		equ     0400h
RX_OFF		equ     1000h
TX_OFF		equ     2000h
FIFO_READ	equ     4000h
FIFO_WRITE	equ     8000h

; Status Register (STAT, read only)
;
RX_INT		equ     0020h
TX_INT		equ     0040h
BUF_INT		equ     0080h
ALL_INT		equ     RX_INT
FIFO_FULL	equ     2000h
FIFO_EMPTY	equ     4000h
FIFO_DIR	equ     8000h

; Configuration Register 1 (CONFIG1)
;
BUFFER_BITS 	EQU	000fh
ID_REG_0	equ     0000h
ID_REG_1	equ     0001h
ID_REG_2	equ     0002h
ID_REG_3	equ     0003h
ID_REG_4	equ     0004h
ID_REG_5	equ     0005h
ADDR_PROM	equ     0006h
TEA_REG		equ     0007h
BUFFER_MEMORY	equ     0008h
INT_VECTOR	equ	0009h
;
ID_0_ENABLE	equ     0100h
ID_1_ENABLE	equ     0200h
ID_2_ENABLE	equ     0400h
ID_3_ENABLE	equ     0800h
ID_4_ENABLE	equ     1000h
ID_5_ENABLE	equ     2000h
MATCH_ID	equ     0000h+0000h
MATCH_BRDCAST	equ     0000h+4000h
MATCH_MULTICAST	equ     8000h+0000h
MATCH_ALL	equ     8000h+4000h


; Configuration Register 2 (CONFIG2)
;
REA_UPDATE_ON		equ     0002h
LOOP_BACK		equ     0800h
WATCH_TIME_DIS		equ	1000h
RESET_BIT		equ     8000h
SHORT_FRAME_ENABLE	equ     0020h
DRIBBLE_ERROR_ENABLE	equ     0010h
CRC_ERROR_ENABLE	equ     0008h
DISABLE_LOOP_BACK_RX	equ     1000h

;
; Transmit Header
;
TX_DONE		equ     80h
COLL16		equ     04h

TX_COMMAND	equ     0ach
;Transmit (80h), Data follows (20h), Xmit succ enable (08h), 16 coll (04h).

;
; Receive Header
;
; Description of header of each packet in receive area of memory

RBUF_SIZE_HI	equ	0	; Length of this frame
RBUF_SIZE_LO	equ	1	; Length of this frame
RBUF_HDR	equ	2	; Header information
RBUF_STAT	equ	3	; Received frame status
RBUF_NXT_PG	equ	1	; Page after this frame
RBUF_NHDR	equ	4	; Length of above header area

RX_CHAIN	equ	40h
RX_DONE		equ     80h
RX_ERROR	equ     0bh

; Misc.
;
TX_BUF_CNT	equ     4
BUF_SIZE	equ     0600h

TX_AREA_BEG	equ     00000h
TX_AREA_END	equ     (TX_BUF_CNT * BUF_SIZE) - 1
RX_AREA_BEG	equ     TX_AREA_END + 1
RX_AREA_END	equ     0FFFFh
RX_AREA_SIZE	equ     RX_AREA_END - TX_AREA_END

FIFO_Count	equ	6000

