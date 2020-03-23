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
; the  MACISR.ASM module, and the public definitions that it exports.
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
;	Variables exported by MACISR
;----------------------------------------------------------------------------
IF OS EQ DOS
		PUBLIC InterruptStack, IntStackOverflow
;		PUBLIC IntVectorSave, IntVectorSaveLocation
		PUBLIC save_int_ss, save_int_sp
ENDIF
		PUBLIC InterruptSemaphore


;----------------------------------------------------------------------------
;	Functions exported by MACISR
;----------------------------------------------------------------------------
		PUBLIC  InterruptMain

;****************************************************************************

;----------------------------------------------------------------------------
;	Variables provided by MAC2PHY
;----------------------------------------------------------------------------
	EXTRN	Nic:NicType

;----------------------------------------------------------------------------
;	Functions provided by MAC2PHY
;----------------------------------------------------------------------------

	EXTRN	Mac2PhyLinkHandler:NEAR

;----------------------------------------------------------------------------
;	Variables provided by MACDATA
;----------------------------------------------------------------------------
EXTRN NDISCommonChar:com_char
;EXTRN IndicationComplete:DWORD

IF OS EQ OS2
EXTRN NDISServiceSpecificChar:servspecchar
ENDIF

;EXTRN ProtDS:WORD

IF OS EQ OS2
EXTRN devhlp:LONG_PTR
ENDIF


;----------------------------------------------------------------------------
;	Variables provided by MACPORT
;----------------------------------------------------------------------------
EXTRN TulipIntPosted:WORD


;----------------------------------------------------------------------------
;	Functions provided by MACRCV
;----------------------------------------------------------------------------
EXTRN ReqHandlePendingRequests:NEAR


;----------------------------------------------------------------------------
;	Functions provided by MACRCV
;----------------------------------------------------------------------------
EXTRN RcvMain:NEAR

;----------------------------------------------------------------------------
;	Variables provided by MACRCV
;----------------------------------------------------------------------------
EXTRN RcvIndicationsIssued:BYTE


;----------------------------------------------------------------------------
;	Variables provided by SYSSRVCS
;----------------------------------------------------------------------------
IF OS EQ DOS
EXTRN	SlavePICNeedsEOI:BYTE
EXTRN	IntVectorSave:DWORD
ENDIF

