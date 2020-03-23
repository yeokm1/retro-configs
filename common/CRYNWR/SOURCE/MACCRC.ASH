;*******************************************************************************
;
; MACCRC.ASH
;
;	Holds the imports and exports used by and provided by MACCRC module.
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
;*******************************************************************************
.8086			; This sets the Mode for All the Include Files.

;****************************************************************************
;	Functions and Variables available Only During INIT Time.
;****************************************************************************
START_CODE_SEGMENT_INIT
;----------------------------------------------------------------------------
;	Functions Provided by MACCRC.
;----------------------------------------------------------------------------

	;Verify CRC table correctness
	;----------------------------
	public	CRC_VerifyTable

END_CODE_SEGMENT_INIT

START_DATA_SEGMENT_INIT
;----------------------------------------------------------------------------
;	Variables used by MACCRC.
;----------------------------------------------------------------------------
	extrn	CRCTableErr		:Byte

END_DATA_SEGMENT_INIT


;****************************************************************************
;	Functions and Variables available during RunTime
;****************************************************************************
START_CODE_SEGMENT_RUNTIME
;----------------------------------------------------------------------------
;	Functions provided by MACCRC
;----------------------------------------------------------------------------

	;Calculates CRC of a given block
        ;-------------------------------
	public	CRC_Calc

END_CODE_SEGMENT_RUNTIME
