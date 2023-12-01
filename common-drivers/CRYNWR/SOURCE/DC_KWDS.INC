;*******************************************************************************
;
; DC_KWDS.INC
;
; Include file for Dec Tulip and Fast Ethernet boards that provides KWDs definitions
; to be used by the driver.
;
; Written by:   Moti Haimovsky
; Date:         22-Dec-1996
;
;                                       
; Copyright (C) 1994 by Digital Equipment Corporation 
; All rights reserved.
;
; Modification History:
;
; By              Date        Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; Moti Haimovsky  17-Feb-1997  2.60  added PcType_UV for MULTIA support.
; Moti Haimovsky  13-Apr-1997        added Sw CRC constants definitions.
;*******************************************************************************

;---------------------
;KWD entry definition
;---------------------
KwdEntrySTRUC	struc
	Selected		db	False
	Union
	 BVal		db	?
	 Wval		dw	0
	Ends
KwdEntrySTRUC	ends


;---------------------------------
;User KWDs data struc definitions
;---------------------------------
UserSelectionsSTRUC     struc
	TXBuffers_UV			KwdEntryStruc	<False, >
	RXBuffers_UV			KwdEntryStruc	<False, >
	SelectedConnectionType_UV	KwdEntryStruc	<False, >
	LineSpeed_UV                	KwdEntryStruc 	<False, >
	ScramblerRequest_UV		KwdEntryStruc	<False, >
	CFLT_UV				KwdEntryStruc 	<False, >
	PBL_UV 				KwdEntryStruc 	<False, >
	CAL_UV				KwdEntryStruc	<False, >
	TxTHR_UV			KwdEntryStruc	<False, >
	ExtPCIOFF_UV			KwdEntryStruc	<False, >
	GPR_Ctrl_UV             	KwdEntryStruc	<False, >
	GPR_Data_UV			KwdEntryStruc	<False, >
	Turbo_UV			KwdEntryStruc	<False, >
	SwCRC_UV			KwdEntryStruc	<False, >
	SNOOZE_UV			KwdEntryStruc	<False, >
	NO_ERI_UV			KwdEntryStruc	<False, >
	SlotNumber_UV			KwdEntryStruc	<False, >
	Bus_UV				KwdEntryStruc	<False, >
	PcType_UV			KwdEntryStruc	<False, >
	NetAddress_UV			db   		False, 0,0,0,0,0,0
UserSelectionsSTRUC     ends


;------------------
;SW CRC constants
;------------------
NEVER_CALC_SOFTWARE_CRC	    equ 0
ALWAYS_CALC_SOFTWARE_CRC    equ 1
