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
; the  MACREQ.ASM module, and the public definitions that it exports.
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
;	Functions exported by MACREQ
;----------------------------------------------------------------------------
;	PUBLIC SysReqDispatch
;	PUBLIC GenReqDispatch
	PUBLIC Bind
	PUBLIC SetStationAddress
	PUBLIC OpenAdapter
	PUBLIC CloseAdapter
	PUBLIC SetPacketFilter
	PUBLIC AddMulticastAddress
	PUBLIC DeleteMulticastAddress
	PUBLIC UpdateStatistics
	PUBLIC ClearStatistics
	PUBLIC SetLookahead
	PUBLIC SysReqInvalidFunction
	PUBLIC NDISMulticastTableInit
	PUBLIC NDISMulticastTableSearch

;----------------------------------------------------------------------------
;	Variables exported by MACREQ
;----------------------------------------------------------------------------
	PUBLIC PendingRequests

;****************************************************************************

;----------------------------------------------------------------------------
;	Variables provided by MAC2PHY
;----------------------------------------------------------------------------
	EXTRN	Nic:NicType


;----------------------------------------------------------------------------
;	Variables provided by MACDATA
;----------------------------------------------------------------------------
EXTRN NDISCommonChar:com_char
EXTRN NDISServiceSpecificChar:servspecchar
EXTRN NDISMulticastTable:ssc_multi
EXTRN NDISServiceStatus:servspecstat
EXTRN NDISMediaSpecificStatus:mediaspecstat
;EXTRN NDISProtLowerDispatch:BYTE
;EXTRN RequestConfirm:DWORD

;EXTRN PICIntOn:BYTE
;EXTRN PICIntMask:WORD
;----------------------------------------------------------------------------

;EXTRN ProtDS:WORD

EXTRN p_PhysBlockVirt:WORD
EXTRN p_PhysBlockPhys:DWORD


;----------------------------------------------------------------------------
;	Functions provided by MACPORT
;----------------------------------------------------------------------------
EXTRN PortUpdateReceiveFilter:NEAR
EXTRN PortInit:NEAR
EXTRN PortReset:NEAR		
EXTRN TulipIntPosted:WORD

;----------------------------------------------------------------------------
;	Functions provided by SYSSRVCS
;----------------------------------------------------------------------------
IFDEF DBG
EXTRN DisplayMessage:NEAR
ENDIF
EXTRN BindInterrupts:NEAR


;----------------------------------------------------------------------------
;	Functions provided by MACRCV
;----------------------------------------------------------------------------
EXTRN RcvInit:NEAR

;----------------------------------------------------------------------------
;	Variables provided by MACRCV
;----------------------------------------------------------------------------
EXTRN RcvCurrentLookahead:WORD


;----------------------------------------------------------------------------
;	Functions provided by MACXMT
;----------------------------------------------------------------------------
EXTRN  XmtInit:NEAR


;----------------------------------------------------------------------------
;	Variables provided by MACISR
;----------------------------------------------------------------------------
EXTRN	InterruptSemaphore:BYTE


;----------------------------------------------------------------------------
;	Functions provided by DC_REGS
;----------------------------------------------------------------------------
EXTRN	SoftwareResetDevice:NEAR
