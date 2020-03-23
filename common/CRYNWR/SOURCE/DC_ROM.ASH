;*******************************************************************************
;
; DC_ROM.ASH
;
;	Holds the imports and exports used by and provided by DC_ROM module.
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
; Moti Haimovsky  13-Apr-1997  2.60 - Added IEEEAddressSROM variable to hold IEEE address 
;				      as read from SROM.
;				    - Added DidUserOverrideIEEEAddress routine definition.
;				    - Using CRC_Calc for calculating CRC
;*******************************************************************************
.8086			; This sets the Mode for All the Include Files.

;****************************************************************************
;	Functions and Variables available Only During INIT Time.
;****************************************************************************
START_CODE_SEGMENT_INIT
;----------------------------------------------------------------------------
;	Functions Provided by DC_ROM.
;----------------------------------------------------------------------------

	;ROM init and parsing routine
	;----------------------------
	public	ROM_Init
	public	ROM_ReadAndParseRomParameters

;----------------------------------------------------------------------------
;	Functions Provided by DC21X4.
;----------------------------------------------------------------------------
	extrn	PCIGetDeviceNumber		:near
	extrn	TempMemoryAllocation		:near
	extrn	DidUserOverrideIEEEAddress	:near

END_CODE_SEGMENT_INIT

START_DATA_SEGMENT_INIT
;----------------------------------------------------------------------------
;	Variables provided by DC_ROM.
;----------------------------------------------------------------------------
	public	IEEEAddressSROM

;----------------------------------------------------------------------------
;	Variables Provided by MAC2PHY
;----------------------------------------------------------------------------

	;SROM Parsing messages
        ;---------------------
	extrn	UnableToLocateROM               :Byte
	extrn	SROM_ReadFailed                 :Byte
	extrn	UnsupportedSROMVersion          :Byte
	extrn	UnsupportedDC21X4SROMVersion    :Byte

END_DATA_SEGMENT_INIT

;****************************************************************************
;	Functions and Variables available during RunTime
;****************************************************************************
START_CODE_SEGMENT_RUNTIME
;----------------------------------------------------------------------------
;	Functions provided by MAC2PHY
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
;	Functions provided by DC21X4
;----------------------------------------------------------------------------
	extrn 	PostResetDelay			:near
	extrn 	Delay				:near
	extrn 	PutDeviceInRunMode		:near
	extrn 	PutDeviceInMode			:near

;----------------------------------------------------------------------------
;       Functions provided by MacCRC
;----------------------------------------------------------------------------
	extrn	CRC_Calc			:near

;----------------------------------------------------------------------------
;	Functions provided by the MSM
;----------------------------------------------------------------------------

END_CODE_SEGMENT_RUNTIME


START_DATA_SEGMENT_RUNTIME
;----------------------------------------------------------------------------
;	Variables provided by Nic
;----------------------------------------------------------------------------
	extrn	Nic				:NicType
	extrn	Entry1				:word
;----------------------------------------------------------------------------
;	Variables provided by DC21X4
;----------------------------------------------------------------------------

END_DATA_SEGMENT_RUNTIME
