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
; the  TXHANG.ASM module, and the public definitions that it exports.
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
;	Variables exported by TXHANG
;----------------------------------------------------------------------------
	PUBLIC TxHangCounter, TxNumOfHangs
	PUBLIC RxHangCounter, RxNumOfHangs
	PUBLIC AutosenseCounter

;----------------------------------------------------------------------------
;	Variables exported by TXHANG
;----------------------------------------------------------------------------
;****************************************************************************

;----------------------------------------------------------------------------
;	Variables provided by MAC2PHY
;----------------------------------------------------------------------------
	EXTRN	Nic:NicType

;----------------------------------------------------------------------------
;	Functions provided by MAC2PHY
;----------------------------------------------------------------------------
	EXTRN	Mac2PhyAutosense:NEAR

;----------------------------------------------------------------------------
;	Variables provided by MACISR
;----------------------------------------------------------------------------
	EXTRN	InterruptSemaphore:BYTE


;----------------------------------------------------------------------------
;	Variables provided by MACRCV
;----------------------------------------------------------------------------
	EXTRN	RcvIndicationSemaphore:BYTE


;----------------------------------------------------------------------------
;	Variables provided by MACDATA
;----------------------------------------------------------------------------
	EXTRN	NDISServiceStatus:servspecstat
IF OS EQ OS2
EXTRN devhlp:LONG_PTR
ENDIF


;----------------------------------------------------------------------------
;	Functions provided by MACRCV
;----------------------------------------------------------------------------
EXTRN RcvCurrentDescriptor:WORD
EXTRN PortUpdateReceiveFilter:NEAR


;----------------------------------------------------------------------------
;	Functions provided by DC_REGS
;----------------------------------------------------------------------------
EXTRN GenerateTUInterrupt:NEAR

EXTRN their_timer: dword
