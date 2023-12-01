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
; the  MACXMT.ASM module, and the public definitions that it exports.
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
;	Variables exported by MACXMT
;----------------------------------------------------------------------------
	PUBLIC XmtNumBuffers, XmtCurrentDescriptor
	PUBLIC XmtTmp, p_XmtBlockVirt, p_XmtRingVirt
	PUBLIC p_XmtBlockPhys, p_XmtRingPhys, XmtState
	PUBLIC XmtNoCarrierFlag, XmtCompletedCount
	PUBLIC XmtCRCThreshold
	PUBLIC TxDescFilterValue
	PUBLIC DefXmtBuffersNum

	PUBLIC DESCRIPTOR_SKIP_LENGTH  ; public constant for both Xmt and Rcv descriptors
;----------------------------------------------------------------------------
;	Functions exported by MACXMT
;----------------------------------------------------------------------------
	PUBLIC  XmtSendSetupFrame
	PUBLIC XmtGetSetupBuffer
	PUBLIC XmtEnable
	PUBLIC XmtDisable
	PUBLIC XmtReset
	PUBLIC XmtInit
	PUBLIC XmtUninit

;****************************************************************************

;----------------------------------------------------------------------------
;	Variables provided by MAC2PHY
;----------------------------------------------------------------------------
	EXTRN	Nic:NicType


;----------------------------------------------------------------------------
;	Variables provided by MACDATA
;----------------------------------------------------------------------------
EXTRN NDISMediaSpecificStatus:mediaspecstat
EXTRN NDISServiceStatus:servspecstat

IF OS EQ OS2
EXTRN devhlp:LONG_PTR
EXTRN XmtGDTSelector:WORD
ENDIF


;----------------------------------------------------------------------------
;	Functions provided by SYSSRVCS
;----------------------------------------------------------------------------
IFDEF DBG
EXTRN DisplayMessage:NEAR
ENDIF
EXTRN PostResetDelay:NEAR


;----------------------------------------------------------------------------
;	Variables provided by TXHANG
;----------------------------------------------------------------------------
EXTRN 	TxHangCounter:WORD


;----------------------------------------------------------------------------
;	Functions provided by MACCRC
;----------------------------------------------------------------------------
EXTRN	CRC_Calc:NEAR
