;*******************************************************************************
;
; DC_REGS.ASH
;
;	Holds the imports and exports used by and provided by DC_REGS module.
;
;Written by:   Moti Haimovsky
; Date:        14-Apr-1997
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

START_DATA_SEGMENT_RUNTIME
;----------------------------------------------------------------------------
;	Variables used by DC_REGS
;----------------------------------------------------------------------------

	extrn	Nic			:NicType

IF NOS EQ ODI
	extrn	DriverStatRxOverflow	:dword
	extrn	RxFifoOverflow          :dword
ENDIF

END_DATA_SEGMENT_RUNTIME

START_CODE_SEGMENT_RUNTIME
;----------------------------------------------------------------------------
;	Functions provided by DC_REGS
;----------------------------------------------------------------------------

	public	WriteCSR6Reg
	public  WriteCSR6Tulip
	public	WriteGEPRegisterFnet
	public  WriteGEPRegisterTwinet
	public  ReadGEPRegisterFnet
	public	ReadGEPRegisterTwinet
	public  PutDeviceInMode
	public  PutDeviceInSleepMode
	public  PutDeviceInRunMode
	public 	ExitFromSleepMode
	public	SoftwareResetDevice
IF NOS EQ ODI
	public	UpdateMissedFrameCounter
ENDIF
	public  GenerateTUInterrupt
;----------------------------------------------------------------------------
;	Functions used by DC_REGS
;----------------------------------------------------------------------------
	extrn	Delay				:near
	extrn	PostResetDelay			:near
	extrn	PCIWriteCfgWORD                 :near
	extrn	WriteInternalPhyRegs            :near

END_CODE_SEGMENT_RUNTIME
