;***************************************************************************
;*
;*    Copyright (c) 1993, 1994
;*    by Digital Equipment Corporation, Maynard, Mass.
;*    All Rights Reserved.
;*
;*    This software is furnished under a license and may be used and  copied
;*    only  in  accordance  with  the  terms  of  such  license and with the
;*    inclusion of the above copyright notice.  This software or  any  other
;*    copies  thereof may not be provided or otherwise made available to any
;*    other person.  No title to and ownership of  the  software  is  hereby
;*    transferred.
;*
;*    The information in this software is subject to change  without  notice
;*    and  should  not  be  construed  as  a commitment by Digital Equipment
;*    Corporation.
;*
;*    Digital assumes no responsibility for the use or  reliability  of  its
;*    software on equipment which is not supplied by Digital.
;*
;***************************************************************************
;
; This module contains the symbolic constants and data structures defined
; by the NDIS 2.01 specification.
;
; Maintainers:
;	eg	Eric Goldstein
;   mf  Maurene Fritz
;   de  Dror Efraty
;
; Revision History:
;
; 10-May-1994	eg	Syntax changes for MASM 6.1.
; 28-jul-1994   mf  fix spelling of MAC_INTERRUPT_CONFLICT
; 25-Nov-1996   de  module name changed from ndis.ash to ndis.inc

		PAGE
;*****************************************************************************
;
;	Protocol Manager Information
;
;*****************************************************************************

PROTMAN_CAT	equ	81h		; protocol manager category code
PROTMAN_FUNC	equ	58h		; function code for protocol manager

;------  Protocol Manager request opcodes  ----------------------------

GET_PROTMAN_INFO	equ	1 		
REGISTER_MODULE		equ	2 		
BIND_AND_START		equ	3 		
GET_PROTMAN_LINKAGE	equ	4 		


;------ Protocol Manager request block ---------------------------------

ReqBlock	struc			
rb_opcode	dw	? 		; request opcode
rb_status	dw	? 		; status at completion of request
rb_pointer1	LONG_PTR	{?, ?}	; far pointer
rb_pointer2	LONG_PTR	{?, ?}	; far pointer
rb_word1	dw	? 		; word parameter
ReqBlock	ends			; ReqBlock

;-----------------------------------------------------------------------------

knownparams	struc
kp_len		dw	?		; number of bytes to move
kp_min		dw	?		; minimum value for kp_store
kp_max		dw	?		; max value for kp_store
kp_store	dw	?		; offset to parameter
kp_name		db	16 dup (0)	; the name
knownparams	ends

;******************************************************************************
;
;	ConfigMemoryImage structures
;
;******************************************************************************

ModuleConfig	struc
mc_next		dd	0		; Next module
mc_prev		dd	0		; Previous module
mc_name		db	16 dup (0)
ModuleConfig	ends

KeywordEntry	struc
kw_next		dd	0
kw_prev		dd	0
kw_name		db	16 dup (0)
kw_numparams	dw	0
KeywordEntry	ends

Params		struc
par_type	dw	0
par_len		dw	0
par_other	db	0
Params		ends

PAR_LONG	equ	0
PAR_STRING	equ	1

bindingslist	struc
numbind		dw	0		; number of modules to bind in
modname		db	16 dup(0)
bindingslist	ends

PROT_PHYS	equ	0
PROT_MAC	equ	1
PROT_DATALINK	equ	2
PROT_NET	equ	3
PROT_TRANSPORT	equ	4
PROT_SESSION	equ	5

;******************************************************************************
;
;	Common Characteristics table
;
;******************************************************************************

com_char	struc
cc_size		dw	0		; size of common char table
cc_ndis_majver	db	0		; major NDIS version (2 bcd digits)
cc_ndis_minver	db	0		; minor NDIS version (2 bcd digits)
cc_res		dw	0		; reserved must be NULL
cc_majver	db	1		; major version (2 bcd digits)
cc_minver	db	0		; minor version (2 bcd digits)
cc_modflags	dd	0		; module function flags (bit mask)
cc_module_name	db	16 dup (0)      ; module name (must be asciiz)
cc_plevel_up	db	0		; protocol level at upper boundary
cc_tint_up	db	0		; type of interface at upper boundary
cc_plevel_low	db	0		; protocol level at lower boundary
cc_tint_low	db	0		; type of interface at lower boundary
cc_modid	dw	0		; module ID filled in by protocol man
cc_dataseg	dw	0		; module data segment
cc_entry	dd	0		; system entry point
cc_servchar	dd	0		; service specific characteristics
cc_servstat	dd	0		; service specific status
cc_upperdisp	dd	0		; upper dispatch table
cc_lowerdisp	dd	0		; lower dispatch table
cc_res1		dd	0		; reserved must be NULL
cc_res2		dd	0		; reserved must be NULL
com_char	ends
CC_TABLE_SIZE equ       SIZE com_char

;******************************************************************************
;
;	Service Specific Characteristics table
;
;******************************************************************************

servspecchar	struc
ssc_len		dw  0          ; length of MAC service specific char table
ssc_name	db  16 dup (0) ; name of the MAC driver NET type
ssc_slen	dw  0          ; length of station address in bytes
ssc_permaddr	db  16 dup (0) ; permanent station Address
ssc_curraddr	db  16 dup (0) ; current Station Address
ssc_functional	dd  0          ; current functional address of adapter
ssc_multicast	dd  0          ; pointer to multicast address list
ssc_linkspeed	dd  0          ; link speed in bits/second
ssc_serviceflg	dd  0          ; service flags, (provided has hints only)
ssc_maxsize	dw  0          ; max frame size which may be send/received
ssc_tranbufcap	dd  0          ; total transmition buffer capacity in bytes
ssc_tranbufsize	dw  0          ; total transmition buffer allocation size bytes
ssc_recbufcap	dd  0          ; total receive buffer capacity in bytes
ssc_recbufsize	dw  0          ; total receive buffer allocation size in bytes
ssc_IEEEvendor	db  3 dup (0)  ; IEEE vendor code
ssc_AdapterCode	db  0          ; vendor adapter code
ssc_AdapterDesc	dd  0          ; pointer to vendor adapter description
ssc_interrupt	dw  0          ; IRQ interrupt level used by adapter
ssc_XmitQue	dw  0          ; transmit queue depth
ssc_MaxDB	dw  0          ; maximum number of data blocks in buffer descriptors supported
servspecchar	ends

SSC_TABLE_SIZE  equ     (SIZE servspecchar)+50

SSC_MULTI_LEN	equ	16	; length of multicast address field

ssc_multi	struc
ssc_maxnum	dw	0 	; max number of multicast addresses
ssc_current	dw	0	; current number of multicast addresses
ssc_multiaddr	db	0	; 16 byte sets of multicast addresses
ssc_multi	ends

;******************************************************************************
;
;	Service flags
;
;******************************************************************************

;;                   0FEDCBA9876543210

SF_BROADCAST	equ  00000000000000001b	; broadcast supported
SF_MULTICAST	equ  00000000000000010b	; multicast supported
SF_FUNCTIONAL	equ  00000000000000100b	; functional/group supported
SF_PROMISCUOUS	equ  00000000000001000b	; promiscuous mode supported
SF_SETSTATION	equ  00000000000010000b	; settable station addr
SF_STAT		equ  00000000000100000b	; statistics always current
SF_INITDIAGS	equ  00000000001000000b	; InitiateDiagnostics supported
SF_LOOPBACK	equ  00000000010000000b	; loopback supported
SF_RECEIVES	equ  00000000100000000b	; receive type 0 = lookahead, 1 = chain
SF_IBMROUTING	equ  00000001000000000b	; IBM source routing
SF_RESETSUP	equ  00000010000000000b	; reset mac supported
SF_OPENCLOSE	equ  00000100000000000b	; open / close adapter supported
SF_INTERRUPT	equ  00001000000000000b	; interrupt request supported
SF_SOURCEROUT	equ  00010000000000000b	; source route bridge supported
SF_GDT		equ  00100000000000000b	; GDT virtual addrs supported
SF_MULTITRANS	equ  01000000000000000b	; multi TransferDatas allowed
SF_FRAMESIZE	equ  10000000000000000b	; mac sets Size=0 in RecieveLookahead

mediaspecstat	struc
mss_length	dw	0		; length of table
mss_version	dw	0		; version of this structure
mss_alignment	dd      0               ; ** frames with alignment error
mss_obs1	dd      0               ; Obsoleted in NDIS 2.01
mss_overrun	dd      0               ; frames with overrun error
mss_obs2	dd      0               ; Obsoleted in NDIS 2.01
mss_deferred	dd      0               ; frames tx after deferring
mss_max_coll	dd      0               ; frames not txd after max collision
mss_obs3	dd      0               ; Obsoleted in NDIS 2.01
mss_late_coll	dd      0               ; total late collisions
mss_1_coll	dd      0               ; ** frames tx after exactly 1 collision
mss_N_coll	dd      0               ; ** frames tx after N collisions
mss_heartbeat	dd      0               ; frames tx, CD heart beat
mss_obs5	dd      0               ; Obsoleted in NDIS 2.01
mss_carrier	dd      0               ; carrier sense lost during transmit
mss_obs6	dd      0               ; Obsoleted in NDIS 2.01
mss_underruns	dd      0               ; number of underruns
mediaspecstat	ends


;******************************************************************************
;
;	FilterMask bit assignments
;
;******************************************************************************

FM_DIRECTED	equ	0001h		; directed/multicast/group/functional
FM_BROADCAST	equ	0002h		; Broadcast Packets
FM_PROMISCUOUS	equ	0004h		; All Lan Packets
FM_ROUTING	equ	0008h		; Any source routing packet

;******************************************************************************
;
;	Opcodes for MAC driver Status Indication
;
;	Called by MAC into Protocol stack
;	
;******************************************************************************

SI_RingStatus	equ	1	; Change in ring status (token ring)
SI_AdapterCheck	equ	2	; Return hardware status (fatal error)
SI_StartReset	equ	3	; Adapter started reset
SI_Interrupt	equ	4	; Interrupt has occured as a result of request

;******************************************************************************
;
;	MAC Error Codes
;
;******************************************************************************

MAC_SUCCESS			equ	0000h
MAC_WAIT_FOR_RELEASE		equ	0001h
MAC_REQUEST_QUEUED		equ	0002h
MAC_FRAME_NOT_RECOGNIZED	equ	0003h
MAC_FRAME_REJECTED		equ	0004h
MAC_FORWARD_FRAME		equ	0005h
MAC_OUT_OF_RESOURCE		equ	0006h
MAC_INVALID_PARAMETER		equ	0007h
MAC_INVALID_FUNCTION		equ	0008h
MAC_NOT_SUPPORTED		equ	0009h
MAC_HARDWARE_ERROR		equ	000Ah
MAC_TRANSMIT_ERROR		equ	000Bh
MAC_NO_SUCH_DESTINATION		equ	000Ch
MAC_BUFFER_TOO_SMALL		equ	000Dh
MAC_ALREADY_STARTED		equ	0020h
MAC_INCOMPLETE_BINDING		equ	0021h
MAC_DRIVER_NOT_INITIALIZED	equ	0022h
MAC_HARDWARE_NOT_FOUND		equ	0023h
MAC_HARDWARE_FAILURE		equ	0024h
MAC_CONFIGURATION_FAILURE	equ	0025h
MAC_INTERRUPT_CONFLICT		equ	0026h
MAC_INCOMPATIBLE_MAC		equ	0027h
MAC_INITIALIZATION_FAILED	equ	0028h
MAC_NO_BINDING			equ	0029h
MAC_NETWORK_MAY_NOT_BE_CONNECTED equ	002Ah
MAC_INCOMPATIBLE_OS_VERSION	equ	002Bh
MAC_ALREADY_REGISTERED		equ	002Ch
MAC_PATH_NOT_FOUND		equ	002Dh
MAC_INSUFFICIENT_MEMORY		equ	002Eh
MAC_INFO_NOT_FOUND		equ	002Fh
MAC_GENERAL_FAILURE		equ	00FFh

TRANSFER_DATA_BLOCK STRUC
   TDDataCount DW ?    ; Number of transfer data blocks.
   TDDataBlock DB ?
TRANSFER_DATA_BLOCK ENDS

TRANSFER_DATA_DESCR STRUC
   TDPtrType  DB ? ; Type of pointer (0=physical; 2=GDT)
   TDResByte  DB ? ; Reserved MBZ
   TDDataLen  DW ? ; Length, in bytes, of this data block
   TDDataPtr  DD ? ; Address of this data block
TRANSFER_DATA_DESCR ENDS

TX_BUF_DESCRIPTOR       STRUC
   XmtImmedLen           DW ?
   XmtImmedPtr           LONG_PTR	{?, ?}
   XmtDataCount          DW ?
TX_BUF_DESCRIPTOR       ENDS

TX_BLOCK_DESCRIPTOR     STRUC
   XmtPtrType            DB ?
   XmtResByte            DB ?
   XmtDataLen            DW ?
   XmtDataPtr            LONG_PTR	{?, ?}
TX_BLOCK_DESCRIPTOR     ENDS

REQ_PendingInfo         STRUC
   ReqProtID            DW ?
   ReqHandle            DW ?
   ReqFlags             DW 0
REQ_PendingInfo         ENDS

CLOSE_REQUESTED         EQU     1
OPEN_REQUESTED          EQU     2
MULTICAST_CHANGED       EQU     4
