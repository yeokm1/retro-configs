ifdef TASM
%PAGESIZE 66,130
else
PAGE 66, 130
endif
;*****************************************************************************
;   SEG_DEFS.INC
;
;	Includ file that must be includded first in each separate compilation unit
;       (resulting *.obj file) wich holds segment and grouping definitions.
;
; Written by:   Moti Haimovsky
; Date:         23-Oct-1996
;
;
; Copyright (C) 1993 by Digital Equipment Corporation
; All rights reserved.
;
; Modification History:
;    By              Date      Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; Moti Haimovsky   22-Dec-96  2.60   Added segment ordering section.
;
;*****************************************************************************
.8086			; This sets the Mode for All the Include Files.
;----------------------------------------------------------;
;Usefull constants for ODI/NDIS2 and DOS/OS2 compatibility ;
;----------------------------------------------------------;
NDIS2	equ	1
ODI     equ	2
DOS     equ	3
OS2     equ	4

;-----------------;
; Sanity checking ;
;-----------------;

;OS type checking
;----------------
IF OS EQ OS2
	%OUT Compiling for OS2.
ELSEIF OS EQ DOS
	%OUT Compiling for DOS.
ELSE
	.ERR
	%OUT Illegal OS value, Use 3 for DOS or 4 for OS2.
ENDIF

;NOS type checking
;-----------------
IF NOS EQ NDIS2
	%OUT Compiling for NDIS2.
ELSEIF NOS EQ ODI
	%OUT Compiling for ODI.
ELSE
	.ERR
	%OUT Illegal NOS value, Use 1 for NDIS2 or 2 for ODI.
ENDIF

;*******************************************************************************
;		SEGMENTS   DEFINITIONS   AND   ORDERING
; 	DO NOT add any segment definition before this definition !!!
;*******************************************************************************
IF OS EQ OS2
;-----------------------------------------------------
;          OS2 Segments definitions and ordering
;-----------------------------------------------------
IF NOS EQ NDIS2
;-----------------------------------------------------
;        NDIS2-OS2 Segments definitions and ordering
;
;        In NDIS2-OS2, the segments should be mentioned
;        in the proper order in the file os2.def
;-----------------------------------------------------
Header		segment	common para use16 'DATA'	;Device driver header
Header		ends

Data		segment public PARA use16 'DATA'	;Bind+Resident data
Data		ends

InitData	segment public PARA use16 'DATA'	;init data
InitData	ends

Filler  	segment public PARA use16 'DATA'	;Filler, to put Rx/Tx buffer in
Filler  	ends

Code		segment	public PARA use16 'CODE'	;Bind+Resident  code
Code		ends

Init		segment public PARA use16 'CODE'	;init code
Init		ends

DGroup	group	Header, Data, InitData, Filler
CGroup	group	Code, Init
	ASSUME cs:CGroup, ds:DGroup, es:NOTHING, ss:NOTHING
ENDIF
IF NOS EQ ODI
;-----------------------------------------------------
;        ODI-OS2 Segments definitions and ordering
;-----------------------------------------------------
	.ERR
	%OUT OS2 ODI driver is not supported !!!
ENDIF
ENDIF

IF OS EQ DOS
;-----------------------------------------------------
;          DOS Segments definitions and ordering
;-----------------------------------------------------
IF NOS EQ NDIS2
;-----------------------------------------------------
;        NDIS2-DOS Segments definitions and ordering
;-----------------------------------------------------
Header		segment	common para 'CODE'	;Device driver header
Header		ends

Code    	segment para public 'CODE'      ;Bind+Resident Code and Data
Code    	ends

Init    	segment para public 'CODE'      ;Init Code and Data
Init		ends

FillerStack	segment para public 'CODE'      ;Init Stack and buffer space
FillerStack   	ends

CGroup	group	Header, Code, Init, FillerStack
	assume	cs:CGroup, ds:CGroup, es:nothing, ss:nothing
ENDIF

IF NOS EQ ODI
;-----------------------------------------------------
;      DOS-ODI Segments definitions and ordering
;-----------------------------------------------------
Code    	segment para public 'CODE'      ;Bind+Resident Code and Data
Code    	ends

Init    	segment para public 'CODE'      ;Init Code and Data
Init		ends

CGroup	group	Code,Init
	assume	cs:CGroup, ds:CGroup, es:nothing, ss:nothing
ENDIF
ENDIF

;-----------------------------------------------------;
; Usefull Macros for ODI and NSDIS2/OS2 compatibility ;
;-----------------------------------------------------;

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         START_DATA_SEGMENT_RUNTIME
;
; Description:
;       assumes:
;       Note:
;       Returns:
; Remarks:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
START_DATA_SEGMENT_RUNTIME macro

IF OS EQ OS2
Data	segment para use16 public 'DATA'
ELSE
Code    segment para public 'CODE'
ENDIF
	endm

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         END_DATA_SEGMENT_RUNTIME
;
; Description:
;       assumes:
;       Note:
;       Returns:
; Remarks:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
END_DATA_SEGMENT_RUNTIME macro

IF OS EQ OS2
Data	ends
ELSE
Code    ends
ENDIF
	endm


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         START_DATA_SEGMENT_INIT
;
; Description:
;       assumes:
;       Note:
;       Returns:
; Remarks:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
START_DATA_SEGMENT_INIT macro

IF OS EQ OS2
InitData	segment para use16 public 'DATA'
ELSE
Init    	segment para public 'CODE'
ENDIF
	endm

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         END_DATA_SEGMENT_INIT
;
; Description:
;       assumes:
;       Note:
;       Returns:
; Remarks:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
END_DATA_SEGMENT_INIT macro

IF OS EQ OS2
InitData    ends
ELSE
Init        ends
ENDIF
	endm



;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         START_CODE_SEGMENT_RUNTIME
;
; Description:
;       assumes:
;       Note:
;       Returns:
; Remarks:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
START_CODE_SEGMENT_RUNTIME macro
IF OS EQ OS2
Code    segment para use16 public 'CODE'
ELSE
Code    segment para public 'CODE'
ENDIF
	endm

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         END_CODE_SEGMENT_RUNTIME
;
; Description:
;       assumes:
;       Note:
;       Returns:
; Remarks:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
END_CODE_SEGMENT_RUNTIME macro
Code    ends
	endm



;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         START_CODE_SEGMENT_INIT
;
; Description:
;       assumes:
;       Note:
;       Returns:
; Remarks:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
START_CODE_SEGMENT_INIT macro

IF OS EQ OS2
Init            segment para use16 public 'CODE'
ELSE
Init    	segment para public 'CODE'
ENDIF
	endm

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         END_CODE_SEGMENT_INIT
;
; Description:
;       assumes:
;       Note:
;       Returns:
; Remarks:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
END_CODE_SEGMENT_INIT macro

Init		ends
	endm



;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         START_CODE_SEGMENT_BIND
;
; Description:
;       assumes:
;       Note:
;       Returns:
; Remarks:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
START_CODE_SEGMENT_BIND macro

IF NOS EQ NDIS2
IF OS EQ OS2
Code    segment para use16 public 'CODE'
ELSE
Code    segment para use16 public 'CODE'
ENDIF
ELSEIF NOS EQ ODI
Init    segment para public 'CODE'
ENDIF
	endm

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         END_CODE_SEGMENT_BIND
;
; Description:
;       assumes:
;       Note:
;       Returns:
; Remarks:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
END_CODE_SEGMENT_BIND macro

IF NOS EQ NDIS2
Code	ends
ELSE
Init	ends
ENDIF
	endm


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         START_DATA_SEGMENT_RUNTIME
;
; Description:
;       assumes:
;       Note:
;       Returns:
; Remarks:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
START_DATA_SEGMENT_BIND macro

IF NOS EQ NDIS2
IF OS EQ OS2
Data    segment para use16 public 'DATA'
ELSE
Code    segment para public 'CODE'
ENDIF
ELSE
Init    segment para public 'CODE'
ENDIF
	endm

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         END_DATA_SEGMENT_BIND
;
; Description:
;       assumes:
;       Note:
;       Returns:
; Remarks:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
END_DATA_SEGMENT_BIND macro

IF NOS EQ NDIS2
IF OS EQ OS2
Data    ends
ELSE
Code    ends
ENDIF
ELSE
Init	ends
ENDIF
	endm



;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         DataAddress
;
; Description:
;       assumes:
;       Note:
;       Returns:
; Remarks:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DataAddress 	macro  To, DataVariable

IF OS EQ OS2
	mov	To, offset DGroup:DataVariable
ELSE
	mov	To, offset CGroup:DataVariable

ENDIF
	endm

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         TableAddress
;
; Description:
;       assumes:
;       Note:
;       Returns:
; Remarks:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
TableAddress 	macro  DataVariable

IF OS EQ OS2
	dw	offset DGroup:DataVariable
ELSE
	dw	offset CGroup:DataVariable

ENDIF
	endm


