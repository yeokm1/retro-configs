;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	PCMCIA.INC
;
;	(C) Copyright 1992 Standard Microsystems Corp. All rights reserved.
;
;	Equates for PCMCIA Lower Mac driver supplement. Derived from 
;	PCMCIA Card Services Specification - Draft dated July 17, 1992
;
;
;	Author: Michael J. Steiger
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Client Services Functions

GetCardServicesInfo		equ	00Bh
RegisterClient			equ	010h
DeRegisterClient		equ	002h
GetStatus			equ	00Ch
ResetCard			equ	011h
SetEventMask			equ	031h
GetEventMask			equ	02Eh

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Resource Management Functions

RequestIO			equ	01Fh
ReleaseIO			equ	01Bh
RequestIrq			equ	020h
ReleaseIrq			equ	01Ch
RequestWindow			equ	021h
ReleaseWindow			equ	01Dh
ModifyWindow			equ	017h
MapMemPage			equ	014h
RequestSocket			equ	022h
ReleaseSocket			equ	02Fh
RequestConfiguration		equ	030h
GetConfigurationInfo		equ	004h
ModifyConfiguration		equ	027h
ReleaseConfiguration		equ	01Eh

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Bulk Memory Services Functions

OpenMemory			equ	018h
ReadMemory			equ	019h
WriteMemory			equ	024h
CopyMemory			equ	001h
RegisterEraseQueue		equ	00Fh
CheckEraseQueue			equ	026h
DeregisterEraseQueue		equ	025h
CloseMemory			equ	000h

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Client Utilities Functions

GetFirstTuple			equ	007h
GetNextTuple			equ	00Ah
GetTupleData			equ	00Dh
GetFirstRegion			equ	006h
GetNextRegion			equ	009h
GetFirstPartition		equ	005h
GetNextPartition 		equ	008h

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Advanced Client Services Functions

ReturnSSEntry			equ	023h
MapLogSocket			equ	012h
MapPhySocket			equ	015h
MapLogWindow			equ	013h
MapPhyWindow			equ	016h
RegisterMTD			equ	01Ah
RegisterTimer			equ	028h
SetRegion			equ	029h
ValidateCIS			equ	02Bh
RequestExclusive		equ	02Ch
ReleaseExclusive		equ	02Dh
GetFirstClient			equ	00Eh
GetNextClient			equ	02Ah
GetClientInfo			equ	003h
AddSocketServices		equ	032h
ReplaceSocketServices		equ	033h
VendorSpecific			equ	034h
AdjustResourceInfo		equ	035h


GET_ADP_CNT			equ	080h
GET_SS_INFO			equ	083h
INQ_ADAPTER			equ	084h
GET_ADAPTER			equ	085h
SET_ADAPTER			equ	086h
INQ_WINDOW			equ	087h
GET_WINDOW			equ	088h
SET_WINDOW			equ	089h
GET_PAGE			equ	08Ah
SET_PAGE			equ	08Bh
INQ_SOCKET			equ	08Ch
GET_SOCKET			equ	08Dh
SET_SOCKET			equ	08Eh
GET_STATUS			equ	08Fh
RESET_CARD			equ	090h

INQ_EDC				equ	095h
GET_EDC				equ	096h
SET_EDC				equ	097h
START_EDC			equ	098h
PAUSE_EDC			equ	099h
RESUME_EDC			equ	09Ah
STOP_EDC			equ	09Bh
READ_EDC			equ	09Ch
GET_VEND_INFO			equ	09Dh
ACK_INTERRUPT			equ	09Eh
PRIOR_HANDLER			equ	09Fh
SS_ADDR				equ	0A0h
ACCESS_OFFSETS			equ	0A1h

VEND_SPECIFIC			equ	0AEh
CARD_SERVICES			equ	0AFh

SS_INT				equ	01Ah


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Event Codes

PM_RESUME			equ	00Bh
PM_SUSPEND			equ	00Ch
BATTERY_DEAD			equ	001h
BATTERY_LOW			equ	002h
CARD_INSERTION			equ	040h
CARD_LOCK			equ	003h
CARD_READY			equ	004h
CARD_REMOVAL			equ	005h
CARD_RESET			equ	011h
CARD_UNLOCK			equ	006h
EJECTION_COMPLETE		equ	007h
EJECTION_REQUEST		equ	008h
ERASE_COMPLETE			equ	081h
EXCLUSIVE_COMPLETE		equ	00Dh
EXCLUSIVE_REQUEST		equ	00Eh
INSERTION_COMPLETE		equ	009h
INSERTION_REQUEST		equ	00Ah
REGISTRATION_COMPLETE		equ	082h
RESET_COMPLETE			equ	080h
RESET_PHYSICAL			equ	00Fh
RESET_REQUEST			equ	010h
MTD_REQUEST			equ	012h
CLIENTINFOSIZE			equ	013h
CLIENTINFO			equ	014h
TIMER_EXPIRED			equ	015h
SS_UPDATED			equ	016h

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; Return Codes

; The following codes are common to Socket Services . . .

SUCCESS				equ	000h ; Already defined in SMC's LMSTRUCT.INC
BAD_ADAPTER			equ	001h
BAD_ATTRIBUTE			equ	002h
BAD_BASE			equ	003h
BAD_EDC				equ	004h
;Reserved			equ	005h
BAD_IRQ				equ	006h
BAD_OFFSET			equ	007h
BAD_PAGE			equ	008h
READ_FAILURE			equ	009h
BAD_SIZE			equ	00Ah
BAD_SOCKET			equ	00Bh
;Reserved			equ	00Ch
BAD_TYPE			equ	00Dh
BAD_VCC				equ	00Eh
BAD_VPP				equ	00Fh
;Reserved			equ	010h
BAD_WINDOW			equ	011h
WRITE_FAILURE			equ	012h
;Reserved			equ	013h
NO_CARD				equ	014h
UNSUPPORTED_FUNCTION		equ	015h
UNSUPPORTED_MODE		equ	016h
BAD_SPEED			equ	017h
BUSY				equ	018h
_GENERAL_FAILURE		equ	019h	; Underscore prefix to avoid conflicts w/NDIS spec.

; The following codes are unique to Card Services . . .

WRITE_PROTECTED			equ	01Ah
BAD_ARG_LENGTH			equ	01Bh
BAD_ARGS			equ	01Ch
CONFIGURATION_LOCKED		equ	01Dh
IN_USE				equ	01Eh
NO_MORE_ITEMS			equ	01Fh
OUT_OF_RESOURCE			equ	020h
BAD_HANDLE			equ	021h

CISTPL_NULL			equ	000h
CISTPL_DEVICE			equ	001h

CISTPL_CHECKSUM			equ	010h
CISTPL_LONGLINK_A		equ	011h
CISTPL_LONGLINK_C		equ	012h
CISTPL_LINKTARGET		equ	013h
CISTPL_NO_LINK			equ	014h
CISTPL_VERS_1			equ	015h
CISTPL_ALTSTR			equ	016h
CISTPL_DEVICE_A			equ	017h
CISTPL_JEDEC_C			equ	018h
CISTPL_JEDEC_A			equ	019h
CISTPL_CONF			equ	01Ah
CISTPL_CE			equ	01Bh
CISTPL_DEVICE_OC		equ	01Ch
CISTPL_DEVICE_OA		equ	01Dh

CISTPL_MANFID			equ	020h
CISTPL_FUNCID			equ	021h
CISTPL_FUNCE			equ	022h

CISTPL_VERS_2			equ	040h
CISTPL_FORMAT			equ	041h
CISTPL_GEOMETRY			equ	042h
CISTPL_BYTEORDER		equ	043h
CISTPL_DATE			equ	044h
CISTPL_BATTERY			equ	045h
CISTPL_ORG			equ	046h

CISTPL_END			equ	0FFh

TPLFE_NETWORK_INFO		equ	000h

LAN_TECH			equ	001h
LAN_ETHERNET			equ	002h	;LAN_TECH code
LAN_SPEED			equ	002h
LAN_MEDIA			equ	003h
LAN_UTP				equ	001h	;LAN_MEDIA code: UnshieldTwistedPair
LAN_NID				equ	004h
LAN_CONN			equ	005h
LAN_CLOSED_CONN			equ	001h	; LAN_CONN code: Closed Connector St

ARC_2_MBIT			equ	000h
ETH_10_MBIT			equ	001h
TR_4_MBIT			equ	002h
TR_16_MBIT			equ	003h
SPREAD_SPECTRUM			equ	004h

INHERENT			equ	001h
UNSH_TP				equ	002h
SH_TP				equ	004h
COAX				equ	008h
FIBER				equ	010h
ETH_AUI				equ	020h

CLOSED_CONN			equ	000h

; Definitions for bits 4-7 of device info tuple device ID field.
DTYPE_NULL			equ	000h
DTYPE_ROM			equ	010h
DTYPE_OTPROM			equ	020h
DTYPE_EPROM			equ	030h
DTYPE_EEPROM			equ	040h
DTYPE_FLASH			equ	050h
DTYPE_SRAM			equ	060h
DTYPE_DRAM			equ	070h
DTYPE_IO			equ	0D0h
DTYPE_EXTEND			equ	0E0h

VCC				equ	80h
VPP1				equ	40h
VPP2				equ	20h
AC_IND				equ	01h
AC_PWR				equ	02h
AC_DBW				equ	04h
AS_POWERDOWN			equ	01h
AS_MAINTAIN			equ	02h
WC_COMMON			equ	01h
WC_ATTRIBUTE			equ	02h
WC_IO				equ	04h
WC_WAIT				equ	80h
WC_BASE				equ	0001h
WC_SIZE				equ	0002h
WC_WENABLE			equ	0004h
WC_8BIT				equ	0008h
WC_16BIT			equ	0010h
WC_BALIGN			equ	0020h
WC_POW2				equ	0040h
WC_CALIGN			equ	0080h
WC_PAVAIL			equ	0100h
WC_PSHARED			equ	0200h
WC_PENABLE			equ	0400h
WC_WP				equ	0800h
WC_INPACK			equ	0080h
WC_EISA				equ	0100h
WC_CENABLE			equ	0200h
WS_IO				equ	01h
WS_ENABLED			equ	02h
WS_16BIT			equ	04h
WS_PAGED			equ	08h
WS_EISA				equ	08h
WS_CENABLE			equ	10h
PS_ATTRIBUTE			equ	01h
PS_ENABLED			equ	02h
PS_WP				equ	04h
IRQ_0				equ	0001h
IRQ_1				equ	0002h
IRQ_2				equ	0004h
IRQ_3				equ	0008h
IRQ_4				equ	0010h
IRQ_5				equ	0020h
IRQ_6				equ	0040h
IRQ_7				equ	0080h
IRQ_8				equ	0100h
IRQ_9				equ	0200h
IRQ_10				equ	0400h
IRQ_11				equ	0800h
IRQ_12				equ	1000h
IRQ_13				equ	2000h
IRQ_14				equ	4000h
IRQ_15				equ	8000h
IRQ_NMI				equ	01h
IRQ_IO				equ	02h
IRQ_BUSERR			equ	04h
IRQ_HIGH			equ	40h
IRQ_ENABLED			equ	80h
SBM_WP				equ	01h
SBM_LOCKED			equ	02h
SBM_EJECT			equ	04h
SBM_INSERT			equ	08h
SBM_BVD1			equ	10h
SBM_BVD2			equ	20h
SBM_RDYBSY			equ	40h
SBM_CD				equ	80h
SBM_LOCK			equ	10h
SBM_BATT			equ	20h
SBM_BUSY			equ	40h
SBM_XIP				equ	80h
IF_MEMORY			equ	01h
IF_IO				equ	02h
EC_UNI				equ	01h
EC_BI				equ	02h
EC_REGISTER			equ	04h
EC_MEMORY			equ	08h
EC_PAUSEABLE			equ	10h
EC_WRITE			equ	02h
ET_CHECK8			equ	01h
ET_SDLC16			equ	02h

TPLMID_MANF			equ	01h	; Offset of MFG ID in CISTPL_MANFID tuple 	
TPLMID_CARD			equ	02h	; Offset of Card data in CISTPL_MANFID tuple	
FUNCTION_FAILURE		equ	01h	; Abnormal end code for MAIN			
FIRST_TUPLE			equ	0FFh	; for TupleStruct.DesiredTuple

; CISTPL_FUNCID Tuple definitions
TPLFID_FUNCTION			equ	06h	; LAN Adapter Function
TPLFID_SYSINIT			equ	00h	; System Init flags, all 0.

;	Bit Definitions for RegisterClientStruct.Attributes

ATTR_MASK			equ	001Ch

;	Bit Definitions for RegisterClientStruct.EventMask

EVENT_MASK			equ	02CCh

;	Bit Definitions for RegisterClientStruct.CSVersion

CS_VERSION			equ	0201h	; Current supported version
MIN_CS_VERSION			equ	0200h	; Minimum supported version

;	Bit Definitions	for ReqIoStruct.Attributes1

SHARED				equ	001h
IO_FIRST_SHARED			equ	002h
FORCE_ALIAS			equ	004h
DATA_WIDTH			equ	008h

REQ_IO_DEFAULT			equ	000h


;	Bit Definitions	for ReqIrqStruct.Attributes	

IRQ_EXCLUSIVE			equ	00000h
TIME_MULT_SHARE			equ	00001h
DYNAMIC_SHARED			equ	00002h
FORCE_PULSE			equ	00004h
IRQ_FIRST_SHARED		equ	00008h
PULSE_ALLOC			equ	00100h

REQ_IRQ_DEFAULT			equ	FORCE_PULSE OR IRQ_EXCLUSIVE


;	Bit Definitions	for ReqMemStruct		

RAM_WIN_DEFAULT_SIZE		equ	040000h		;	"Window" is 256KB	


;	Bit Definitions	for ReqMemStruct.Attributes	

MEM_TYPE			equ	00002h
MEM_ENABLED			equ	00004h
MEM_16_WIDTH			equ	00008h
MEM_PAGED			equ	00010h
MEM_SHARED			equ	00020h
MEM_1ST_SHARED			equ	00040h
MEM_WIN_PG_SIZE			equ	00100h		; Card offsets are window sized.	

REQ_MEM_DEFAULT			equ	MEM_ENABLED OR MEM_16_WIDTH


;	Bit Definitions	for ReqMemStruct.AccessSpeed	

SPEED_250nS			equ	00001h
SPEED_200nS			equ	00002h
SPEED_150nS			equ	00003h
SPEED_100nS			equ	00004h

;	Definitions for AdjResInfoStruct

; .Action

REMOVE_RESOURCE			equ	0
ADD_RESOURCE			equ	1

; .Resource
MEM_RESOURCE			equ	0
IO_RESOURCE			equ	1
IRQ_RESOURCE			equ	2

