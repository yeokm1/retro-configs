;***************************************************************************
;*
;*    Copyright (c) 1996
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
; This module contains the definitions for the external symbols needed by
; the  MACPORT.ASM module, and the public definitions that it exports.
;
; Maintainers:
;	de	Dror Efraty
;
; Modification History:
;
; By              Date        Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; de		  25-Nov-1996 2.50  Initial Version
;*******************************************************************************
.8086		; This must apear in the beginning of each .ash file,
		; for the compiler to understand NEAR exteanals as 16 bits.
;----------------------------------------------------------------------------
;	Variables exported by MACPORT
;----------------------------------------------------------------------------
	PUBLIC  TulipIntPosted

	public	AES_INTERVAL      ;Const specifying Interval time (in msec)

;----------------------------------------------------------------------------
;	Functions exported by MACPORT
;----------------------------------------------------------------------------

	PUBLIC 	PortUpdateReceiveFilter
	PUBLIC  SendMediaTestPacket
	PUBLIC 	PortInit
	PUBLIC 	PortReset	;(MOTIH)

;****************************************************************************

;----------------------------------------------------------------------------
;	Variables provided by MAC2PHY
;----------------------------------------------------------------------------
	EXTRN	Nic:NicType

;----------------------------------------------------------------------------
;	Functions provided by MAC2PHY
;----------------------------------------------------------------------------
	EXTRN	Mac2PhySetConnection:NEAR
	EXTRN	Mac2PhyAutodetect:NEAR
	EXTRN	GetMediaLineSpeed:NEAR

;----------------------------------------------------------------------------
;	Variables provided by MACDATA
;----------------------------------------------------------------------------
EXTRN NDISServiceSpecificChar:servspecchar
EXTRN NDISMulticastTable:ssc_multi
EXTRN NDISServiceStatus:servspecstat


;----------------------------------------------------------------------------
;	Functions provided by MACRCV
;----------------------------------------------------------------------------
EXTRN RcvEnable:NEAR
EXTRN RcvReset:NEAR


;----------------------------------------------------------------------------
;	Functions provided by MACXMT
;----------------------------------------------------------------------------
EXTRN  XmtSendSetupFrame:NEAR
EXTRN  XmtGetSetupBuffer:NEAR
EXTRN  XmtReset:NEAR
EXTRN  XmtEnable:NEAR

;----------------------------------------------------------------------------
;	Variables provided by MACXMT
;----------------------------------------------------------------------------
EXTRN  XmtCurrentDescriptor:WORD

EXTRN  TxDescFilterValue:DWORD


;----------------------------------------------------------------------------
;	Variables provided by MACISR
;----------------------------------------------------------------------------
EXTRN  InterruptSemaphore:BYTE


;----------------------------------------------------------------------------
;	Functions provided by DC_REGS
;----------------------------------------------------------------------------
EXTRN  SoftwareResetDevice:NEAR


;----------------------------------------------------------------------------
;	Functions provided by DC_INIT
;----------------------------------------------------------------------------
IF OS EQ DOS
EXTRN  DisplaySelectedMedia:NEAR
ENDIF


;----------------------------------------------------------------------------
;	Functions provided by SYSSRVCS
;----------------------------------------------------------------------------
EXTRN  PostResetDelay:NEAR
EXTRN  DisplayMessage:NEAR

;----------------------------------------------------------------------------
;	Variables provided by TXHANG
;----------------------------------------------------------------------------
EXTRN	AutosenseCounter:WORD

;-------------------
; Autosense Equates
;-------------------
AUTOSENSE_DISABLE	EQU	0FFFFh  ; Value indicating autosense counter
                                       	; is irrelevant.
AUTOSENSE_ENABLE	EQU	0	; Value indicating counter is relevant


;------------------------

