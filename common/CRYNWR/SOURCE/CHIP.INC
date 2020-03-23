
REGS_R_32_BIT	EQU	1				; 32 bit registers need to be saved/restored

AUTO_CONNECTOR  equ     0
TPE_CONNECTOR   equ     1
BNC_CONNECTOR   equ     2
AUI_CONNECTOR   equ     3

TPE				EQU		10h
BNC				EQU		20h
AUI				EQU		30h

SPEED_SLOW		EQU		11h
SPEED_FAST		EQU		12h
DUPLEX_HALF		EQU		13h
DUPLEX_FULL		EQU		14h

SLOW_10			EQU	10
FAST_100		EQU	100
HALF_DUPLEX		EQU	1
FULL_DUPLEX		EQU	2

MATCH_IA				EQU	02h
MATCH_BRDCAST			EQU	03h
MATCH_SOME_MULTICAST	EQU	04h
MATCH_ALL_MULTICAST		EQU	05h
MATCH_EVERYTHING		EQU	06h

; Action command bits
EL_BIT		EQU	8000h
S_BIT		EQU	4000h
INT_BIT		EQU	2000h
IA_SETUP	EQU	0001h
CONFIG_CMD	EQU	0002h
MULTI_ADD	EQU	0003h
TRANSMIT	EQU	0004h
TDR_CMD		EQU	0005h
	LNK_OK		EQU	8000h
	TDR_TIME	equ	07ffh
;according to jrd@cc.usu.edu, the following will turn off early transmit.
;In theory we don't need to turn this off because packets are always
;ready, but apparently practice dictates otherwise.
	TX_THRESHOLD	EQU	200
	TX_EOF_BIT		EQU	8000h
DUMP		EQU	0006h
DIAGNOSE	EQU	0007h

; Receive frame status in the RFD
SHORT_FRAME_BIT	EQU	0080h
OVER_RUN_BIT	EQU	0100h
RESOURCES_BIT	EQU 0200h
ALIGN_BIT		EQU	0400h
CRC_BIT			EQU	0800h
LENGTH_BIT		EQU 1000h
RX_OK			EQU 2000h
RFD_PREFETCH	EQU 4000h
RFD_DONE_BIT	EQU 8000h

RBD_PREFETCH	EQU 4000h

COUNT_VALID		EQU	4000h
EOF_BIT			EQU 8000h		; End of frame marker for RBD

C_DONE_BIT		EQU	8000h
FLEXIBLE_MODE	EQU	0008h


RBD_COUNT		EQU		10h
RFD_COUNT		EQU		12h		; More than RBD so that we don't run out
SIZE_ONE_DATA_BUFF	EQU	100h

LOAD_PORT	MACRO port_param
	mov		dx, base_addr
	if port_param NE 0
		add		dx, port_param
	endif
	port_no	= port_param
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

stall	macro
	push	ax
	in		al, 61h
	in		al, 61h
	in		al, 61h
	pop		ax
	endm


