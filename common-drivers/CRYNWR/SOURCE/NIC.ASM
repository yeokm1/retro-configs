;*******************************************************************************
;
; Nic.ASM
; 	Module holding the General\Global Nic data structure used for holding
;	driver/Board/Chip specific data. and used by all the driver's modules.
;
;Written by:   Moti Haimovsky
; Date:        27-Oct-1996
;
;
; Copyright (C) 1994 by Digital Equipment Corporation
; All rights reserved.
;
; Modification History:
;
;       By            Date     Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
;
;*******************************************************************************
include  SEG_DEFS.INC
include	 Nic.ASH
.386
include	 DC_regs.inc
include	 Nic.inc

START_DATA_SEGMENT_RUNTIME

	even
Nic     NicType <>


Entry1                  dw      TP
			dw      BNC
			dw      AUI
			dw      SymScr
			dw      TpFD
			dw      SymScrFD
			dw      BaseT4
			dw      BaseFx
			dw      BaseFxFD


END_DATA_SEGMENT_RUNTIME

;-----------------;
; Sanity checking ;
;-----------------;

;OS type checking
;----------------
IF OS EQ DOS
	%OUT NIC.ASM Compiling for DOS.
ELSEIF OS EQ OS2
	%OUT NIC.ASM Compiling for OS2.
ELSE
	.ERR
	%OUT NIC.ASM Illegal OS value.
ENDIF

;NOS type checking
;-----------------
IF NOS EQ ODI
	%OUT NIC.ASM Compiling for ODI.
ELSEIF NOS EQ NDIS2
	%OUT NIC.ASM Compiling for NDIS2.
ELSE
	.ERR
	%OUT NIC.ASM Illegal NOS value.
ENDIF

END
