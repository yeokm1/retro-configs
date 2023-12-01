;*******************************************************************************
;
; Nic.ASH
;	Holds the imports and exports used and provided by Nic module.
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
;	Functions Provided by Nic.
;----------------------------------------------------------------------------

END_CODE_SEGMENT_INIT

START_DATA_SEGMENT_INIT
;----------------------------------------------------------------------------
;	Variables provided by Nic.
;----------------------------------------------------------------------------

END_DATA_SEGMENT_INIT

;****************************************************************************
;	Functions and Variables available during RunTime
;****************************************************************************
START_CODE_SEGMENT_RUNTIME
;----------------------------------------------------------------------------
;	Functions provided by Nic
;----------------------------------------------------------------------------

END_CODE_SEGMENT_RUNTIME


START_DATA_SEGMENT_RUNTIME
;----------------------------------------------------------------------------
;	Variables provided by Nic
;----------------------------------------------------------------------------
	public	Nic
	public  Entry1

END_DATA_SEGMENT_RUNTIME
