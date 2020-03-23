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
; the  MACRCV.ASM module, and the public definitions that it exports.
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
;	Variables exported by MACRCV
;----------------------------------------------------------------------------
        PUBLIC p_RcvBlockVirt, p_RcvBlockPhys, p_RcvRingVirt, p_RcvRingPhys
	PUBLIC RcvState
        PUBLIC RcvNumBuffers
        PUBLIC RcvIndicationSemaphore
        PUBLIC RcvIndicationsIssued
        PUBLIC RcvSemaphore
        PUBLIC RcvCurrentLookahead
        PUBLIC RcvCurrentDescriptor
	PUBLIC DefRcvBuffersNum

;----------------------------------------------------------------------------
;	Functions exported by MACRCV
;----------------------------------------------------------------------------
	PUBLIC RcvMain
        PUBLIC RcvNDISTransferData
        PUBLIC RcvNDISReceiveRelease
	PUBLIC RcvNDISIndicationOn
	PUBLIC RcvNDISIndicationOff
	PUBLIC RcvPostFreeDescriptor
        PUBLIC RcvEnable
        PUBLIC RcvDisable
	PUBLIC RcvReset
        PUBLIC RcvInit
	PUBLIC RcvUninit

;****************************************************************************

;----------------------------------------------------------------------------
;	Variables provided by MAC2PHY
;----------------------------------------------------------------------------
	EXTRN	Nic:NicType


;----------------------------------------------------------------------------
;	Functions provided by DC_REGS
;----------------------------------------------------------------------------
	EXTRN	GenerateTUInterrupt:NEAR


;----------------------------------------------------------------------------
;	Variables provided by MACDATA
;----------------------------------------------------------------------------
EXTRN NDISCommonChar:com_char
EXTRN NDISServiceStatus:servspecstat
;EXTRN ReceiveLookahead:DWORD
;EXTRN IndicationComplete:DWORD

;EXTRN ProtDS:WORD

IF OS EQ OS2
EXTRN devhlp:LONG_PTR
EXTRN RxGDTSelector:WORD
ENDIF


;----------------------------------------------------------------------------
;	Functions provided by SYSSRVCS
;----------------------------------------------------------------------------
IFDEF DBG
EXTRN   DisplayMessage:NEAR
ENDIF


;----------------------------------------------------------------------------
;	Variables provided by TXHANG
;----------------------------------------------------------------------------
EXTRN 	RxHangCounter:WORD

