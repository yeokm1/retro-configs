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
; the  MACINIT.ASM module, and the public definitions that it exports.
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
;	Functions exported by MACINIT
;----------------------------------------------------------------------------
	PUBLIC InitDriverInit
	PUBLIC InitSetBuffersNum
	PUBLIC SetEthernetAddressVariable
;----------------------------------------------------------------------------
;	Variables exported by MACINIT
;----------------------------------------------------------------------------
	PUBLIC	IOAddress1
	PUBLIC	IORange1
	PUBLIC	IntLine1
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
EXTRN NDISServiceStatus:servspecstat

IF OS EQ OS2
EXTRN devhlp:LONG_PTR
EXTRN RxGDTSelector:WORD
ENDIF

EXTRN p_PhysBlockVirt:WORD
EXTRN p_PhysBlockPhys:DWORD
EXTRN PhysBlockSize:WORD

EXTRN NewLineLineFeedMessage:WORD


;----------------------------------------------------------------------------
;	Variables provided by MACRCV
;----------------------------------------------------------------------------
EXTRN RcvNumBuffers:WORD
EXTRN DefRcvBuffersNum:abs

;----------------------------------------------------------------------------
;	Functions provided by MACRCV
;----------------------------------------------------------------------------
EXTRN RcvInit:NEAR


;----------------------------------------------------------------------------
;	Functions provided by DC_INIT
;----------------------------------------------------------------------------
EXTRN DcInit:NEAR
EXTRN DisplaySelectedChip:NEAR
IF OS EQ OS2
EXTRN DisplaySelectedMedia:NEAR
ENDIF

;----------------------------------------------------------------------------
;	Functions provided by MACXMT
;----------------------------------------------------------------------------
EXTRN  XmtInit:NEAR

;----------------------------------------------------------------------------
;	Variables provided by MACXMT
;----------------------------------------------------------------------------
EXTRN  XmtNumBuffers:WORD
EXTRN  DefXmtBuffersNum:abs

;----------------------------------------------------------------------------
;	Variables provided by NDS2SHLL
;----------------------------------------------------------------------------
IF OS EQ OS2
EXTRN	CodeImageEnd:NEAR
ENDIF

EXTRN	ImageEnd:WORD

	extrn	rom_address: byte		;from head.asm

;----------------------------------------------------------------------------
;	Functions provided by SYSSRVCS
;----------------------------------------------------------------------------
EXTRN DisplayMessage:NEAR
EXTRN PrintHexByte:NEAR
EXTRN SYSSRVCS_InitDone:NEAR
EXTRN VirtualToPhysical:NEAR

IF OS EQ OS2
EXTRN  DOSOPEN:FAR
EXTRN  DOSCLOSE:FAR
EXTRN  DOSDEVIOCTL:FAR
EXTRN  DOSWRITE:FAR
ENDIF

