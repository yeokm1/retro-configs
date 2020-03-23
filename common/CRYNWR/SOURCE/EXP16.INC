;	82586 Structure definitions

SysConfigPtr	struc
SCP_SystemBus		dw	?
			dw	2 dup (?)
SCP_ISCP_Ptr_low	dw	?
SCP_ISCP_Ptr_high	dw	?
SysConfigPtr	ends


;----------------------------------------------------------------
; Note: The @ addresses are the I/O address offsets from [bp].
;----------------------------------------------------------------

; The SCP is at location XXX6H.  Since the
; SMB pointers must have the low order 5 bits
; zero, we assume that the SMP pointer will
; be set to XXE0H
@SysConfigPtr	struc
	db	8000h dup (?)
	dw	?
	dw	?
	dw	?
@SCP_SystemBus	dw	?
	dw	2 dup (?)
@SCP_ISCP_Ptr_low	dw	?
@SCP_ISCP_Ptr_high	dw	?
@SysConfigPtr	ends


ISysConfigPtr	struc
ISCP_Busy	dw	?
ISCP_SCB_Offset	dw	?
ISCP_Ptr_low	dw	?
ISCP_Ptr_high	dw	?
ISysConfigPtr	ends


; NOTE: Access to the SCB through the shadow
; registers is done by setting the SMB_PTR to
; the ISCP base address and then using this
; structure.  This is because the SCB address
; does not start on a 32 byte boundary as
; as required for the SMB_PTR.

@ISysConfigPtr	struc
	db	4000h dup (?)
@ISCP_Busy	dw	?
@ISCP_SCB_Offset	dw	?
@ISCP_SCB_Ptr_low	dw	?
@ISCP_SCB_Ptr_high	dw	?
@SCB_Status	dw	?
@SCB_Command	dw	?
@SCB_CommandList	dw	?
@SCB_RecBlockList	dw	?
	db	4000h - 16 dup (?)
@SCB_CRC_Errors	dw	?
@SCB_ALN_Errors	dw	?
@SCB_RSC_Errors	dw	?
@SCB_OVR_Errors	dw	?
@ISysConfigPtr	ends


SystemControlBlock	struc
SCB_Status	dw	?
SCB_Command	dw	?
SCB_CommandList	dw	?
SCB_RecBlockList	dw	?
SCB_CRC_Errors	dw	?
SCB_ALN_Errors	dw	?
SCB_RSC_Errors	dw	?
SCB_OVR_Errors	dw	?
SystemControlBlock	ends

; NOTE: The SCB shadow register structure is
; part of the ISysConfigPtr shadow register
; structure.

ReceiveBlock	struc
FD_Status	dw	?
FD_Command	dw	?
FD_Link		dw	?
FD_RBD_Offset	dw	?
RBD_ByteCount	dw	?
RBD_Link	dw	?
RBD_RB_Address_low	dw	?
RBD_RB_Address_high	dw	?
RBD_Size	dw	?
RB_Data		db	RxBufferSize dup (?)
ReceiveBlock	ends

ReceiveBlock_data	struc
IPX_FD_Status	dw	?
IPX_FD_Command	dw	?
IPX_FD_Link	dw	?
IPX_FD_RBD_Offset	dw	?
IPX_RBD_ByteCount	dw	?
IPX_RBD_Link	dw	?
IPX_RBD_RB_Address_low	dw	?
IPX_RBD_RB_Address_high	dw	?
IPX_RBD_Size	dw	?
IPX_DestAddr_HIGH	dw	?
IPX_DestAddr_MID	dw	?
IPX_DestAddr_LOW	dw	?
IPX_SourceAddr_HIGH	dw	?
IPX_SourceAddr_MID	dw	?
IPX_SourceAddr_LOW	dw	?
IPX_LengthTypeField	dw	?
ReceiveBlock_data	ends


@ReceiveBlock	struc
	db	4000h dup (?)
@FD_Status	dw	?
@FD_Command	dw	?
@FD_Link	dw	?
@FD_RBD_Offset	dw	?
@RBD_ByteCount	dw	?
@RBD_Link	dw	?
@RBD_RB_Address_low	dw	?
@RBD_RB_Address_high	dw	?
	db	4000h - 16 dup (?)
@RBD_Size	dw	?
; Ethernet Packet Data
@DestAddr_HIGH	dw	?
@DestAddr_MID	dw	?
@DestAddr_LOW	dw	?
@SourceAddr_HIGH	dw	?
@SourceAddr_MID	dw	?
@SourceAddr_LOW	dw	?
@LengthTypeField	dw	?
@ReceiveBlock	ends

SendBlock	struc
TxCB_Status	dw	?
TxCB_Command	dw	?
TxCB_Link	dw	?
TxCB_TBD_Offset	dw	?
TBD_ByteCount	dw	?
TBD_Link	dw	?
TBD_TB_Address_low	dw	?
TBD_TB_Address_high	dw	?
TB_Data		db	TxBufferSize dup (?)
SendBlock	ends


@SendBlock	struc
	db	4000h dup (?)
@TxCB_Status	dw	?
@TxCB_Command	dw	?
@TxCB_Link	dw	?
@TxCB_TBD_Offset	dw	?
@TBD_ByteCount	dw	?
@TBD_Link	dw	?
@TBD_TB_Address_low	dw	?
@TBD_TB_Address_high	dw	?
	db	4000h - 16 dup (?)
@TB_Data	db	TxBufferSize dup (?)
@SendBlock	ends


CommandBlock	struc			 		;Set command block
CB_Status	dw	?			; Size for largest
CB_Command	dw	?			; command.  The Dump
CB_Link		dw	?				; command needs a 170
CB_Param0	dw	?			; byte area.  The 14
	db	170+14 dup (?)	 	; extra bytes are
CommandBlock	ends					; padding to make the
							; size of this struc
							; boundary.
@CommandBlock	struc
	db	4000h dup (?)		;Set command block
@CB_Status	dw	?			; Size for largest
@CB_Command	dw	?			; command.  The Dump
@CB_Link	dw	?			; command needs a 170
@CB_Parm0	dw	?			; byte area.  The 14
	db	170+14 dup (?)  	; extra bytes are
@CommandBlock	ends					; padding to make the
							; size of this struc
							; align on a 16 byte
SCPS		equ	SysConfigPtr
ISCPS		equ	ISysConfigPtr
SCBS		equ	SystemControlBlock

; System ControlBlock.

Bit_CX		equ	8000h
Bit_FR		equ	4000h
Bit_CNA		equ	2000h
Bit_RNR		equ	1000h

;  System Control Block's control unit statuses

CUS_Idle	equ	0000h
CUS_Suspended	equ	0100h
CUS_Active	equ	0200h
CUS_Mask	equ	0300h

;  System Control Block's receive unit statuses.
RUS_Idle	equ	0000h
RUS_Suspend	equ	0010h
RUS_No_Resource	equ	0020h
RUS_Ready	equ	0040h

;  System Control Block's control unit commands
CUC_NOP		equ	0000h
CUC_Start	equ	0100h
CUC_Resume	equ	0200h
CUC_Suspend	equ	0300h
CUC_Abort	equ	0400h

;  System Control Block's receive unit commands
RUC_NOP		equ	0000h
RUC_Start	equ	0010h
RUC_Resume	equ	0020h
RUC_Suspend	equ	0030h
RUC_Abort	equ	0040h


; General Action Command Block.

GA_NOP		equ	0000h
GA_IA_Setup	equ	0001h
GA_Configure	equ	0002h
GA_MC_Setup	equ	0003h
GA_Transmit	equ	0004h
GA_TDR		equ	0005h
GA_Dump		equ	0006h
GA_Diagnose	equ	0007h

	lock_bit_address	EQU	01H
	lock_bit_mask	EQU	0000000000000001B
	iochrdy_mask	EQU	00010000B
	iochrdy_test_mask	EQU	00100000B
	iochrdy_test_result	EQU	01000000B
	iochrdy_early	EQU	00000000B
	iochrdy_late	EQU	00010000B


; Common Bits.

Bit_C		equ	8000h	; Command complete.
Bit_B		equ	4000h	; Busy executing command.
Bit_OK		equ	2000h	; Error free completion.
Bit_A		equ	1000h	; Command aborted.

Bit_EL		equ	8000h	; End of list.
Bit_EOF		equ	8000h	; End of frame.
byte_Bit_EOF	equ	80h	; End of frame.
Bit_S		equ	4000h	; Suspend after completion.
Bit_I		equ	2000h	; Interrupt after completion.

Bit_S11		equ	0800h
Bit_S10		equ	0400h
Bit_S9		equ	0200h
Bit_S8		equ	0100h
Bit_S7		equ	0080h
Bit_S6		equ	0040h
Bit_S5		equ	0020h

ACK_INT_Mask	equ	0f000h
MaxCollisions	equ	0020h
Ready		equ	0040h

LNK_OK		equ	8000h
XCVR_PRB	equ	4000h
ET_OPN		equ	2000h
ET_SRT		equ	1000h
TDR_TIME	equ	07ffh

;
; equates and definitions:
;
EOI		equ	020h	;End-of-interrupt command.
Master_PIC	equ	020h	;1st Interrupt-Control port.
Slave_PIC	equ	0A0h	;2nd Interrupt-Control port.

Number_of_Tx_Buffers	equ	1

_586_Reset	equ	0080H
ASIC_Reset	equ	0040H

bus_width	equ	0	;16 bit, use for initialize
initialize_586	equ	1

;
; Timer equates
;
	one_mil	EQU	02387
	ten_mils	EQU	23866


;
;  EEPROM equATES
;
EE_SK		equ	00000001B	;EEPROM shift clock (1 = high, 0 = low)
EE_CS		equ	00000010B	;EEPROM chip select (1 = high, 0 = low)
EE_DI		equ	00000100B	;EEPROM data in (set to 1 for writing data to EEPROM)
EE_DO		equ	00001000B	;EEPROM data out
EE_tick		equ	10

EEPROM_read_opcode	equ	110B
EEPROM_write_opcode	equ	101B
EEPROM_erase_opcode	equ	111B
EEPROM_EWEN_opcode	equ	10011B		;Erase/write enable
EEPROM_EWDS_opcode	equ	10000B		;Erase/write disable

TIME_OUT_VALUE	equ	0FFFFh

loopback_enable	equ	00000010B

