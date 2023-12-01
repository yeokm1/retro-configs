;*******************************************************************************
;
; DC_INIT.ASH
;
;	Holds the imports and exports used by and provided by DC_INIT module.
;
;Written by:   Moti Haimovsky
; Date:        10-Apr-1997
;
;
; Copyright (C) 1994 by Digital Equipment Corporation
; All rights reserved.
;
; Modification History:
;
;       By            Date     Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; Moti Haimovsky  16-Jun-1997       - added WACB_ModifyingTxTHR def.
; Moti Daniel     19-Jan-1998 2.62  - Added DeviceIsDisabled error message
;*******************************************************************************
.8086			; This sets the Mode for All the Include Files.

;****************************************************************************
;	Functions and Variables available Only During INIT Time.
;****************************************************************************
START_CODE_SEGMENT_INIT
;----------------------------------------------------------------------------
;	Functions Provided by DC_init.
;----------------------------------------------------------------------------
	;Common Driver Init routine
	;----------------------------
	public	DcInit
	public	DidUserOverrideIEEEAddress
	public	DisplaySelectedChip
IF ((NOS EQ NDIS2) AND (OS EQ DOS))
END_CODE_SEGMENT_INIT
START_CODE_SEGMENT_BIND
ENDIF
	public	DisplaySelectedMedia
IF ((NOS EQ NDIS2) AND (OS EQ DOS))
END_CODE_SEGMENT_BIND
START_CODE_SEGMENT_INIT
ENDIF

;----------------------------------------------------------------------------
;	Functions Needed by DC_init.
;----------------------------------------------------------------------------
	extrn	CRC_VerifyTable			:Near
	extrn	SYSSRVCS_Init			:Near
	extrn	ParseKWDS			:Near
	extrn	SetDeviceDefaultParameters	:Near
	extrn 	ROM_Init			:Near
	extrn	ROM_ReadAndParseRomParameters	:Near
	extrn	Mac2PhyInit			:Near
	extrn	Mac2PhyGetConnectionStatus	:Near
	extrn	SYSSRVCS_InitErrorExit		:Near
	extrn	PCIFindClassCodeDevice		:Near
	extrn	DisableScrambler                :Near
	extrn	DoesSystemSupportERI            :Near
	extrn	ModifyGEP_Control               :Near
	extrn	ModifyGEP_Data                  :Near
	extrn	DisplayMessage                  :Near
	extrn	Mac2PhyCheckAndAdjustSelectedConnection	:Near
	extrn   InitSetBuffersNum		:Near
	extrn	SetEthernetAddressVariable	:near

END_CODE_SEGMENT_INIT

START_DATA_SEGMENT_INIT
;----------------------------------------------------------------------------
;	Variables used by DC_Init.
;----------------------------------------------------------------------------
	extrn   UserKWDS			:UserSelectionsSTRUC
	extrn	UnknownBusErr			:Byte
	extrn	NoPciBIOSErr			:Byte
	extrn	SlotValueErr			:Byte
	extrn	BadDeviceCFIDVal		:Byte
	extrn	BoardNotFoundErr		:Byte
	extrn	PCIBIOSBadCBIOErr		:Byte
	extrn	BadInterruptAllocation		:Byte
	extrn	UnsupportedDeviceRevision	:Byte
	extrn   DeviceIsDisabled                :Byte
	extrn   WACB_ModifyingTxTHR		:Byte
	extrn	ModifyingPBLMsg			:Byte
	extrn	MediaNotSupportedErr		:Byte
	extrn	IEEEAddressSROM			:Byte

	extrn	WorkingWith21040_Message		:Byte
	extrn	WorkingWith21041_Message		:Byte
	extrn	WorkingWith21140and21140A_Message	:Byte
	extrn	WorkingWith21142and21143_Message	:Byte
IF ((NOS EQ NDIS2) AND (OS EQ DOS))
END_DATA_SEGMENT_INIT
START_DATA_SEGMENT_BIND
ENDIF
	extrn	WorkingWithMediaMessage		:Byte
	extrn	MediaTypeMessage		:Word
	extrn	WorkingWithFDMessage		:Byte
	extrn	WorkingWithILTMessage		:Byte
	extrn	WorkingWithAutosenseMessage	:Byte
	extrn	MediaUnknownMessage		:Byte
	extrn	NewLineLineFeedMessage		:Byte
IF ((NOS EQ NDIS2) AND (OS EQ DOS))
END_DATA_SEGMENT_BIND
ELSE
END_DATA_SEGMENT_INIT
ENDIF

;****************************************************************************
;	Functions and Variables available during RunTime
;****************************************************************************
START_CODE_SEGMENT_RUNTIME
;----------------------------------------------------------------------------
;	Functions used by DC_Init
;----------------------------------------------------------------------------

	extrn	HandleTURBOOnPCIMachines     	:Near
	extrn	PCIReadCfgDWORD			:Near
	extrn	PCIReadCfgBYTE			:Near
	extrn	PCIWriteCfgDWORD		:Near
	extrn	SoftwareResetDevice		:Near

END_CODE_SEGMENT_RUNTIME

START_DATA_SEGMENT_RUNTIME
;----------------------------------------------------------------------------
;	Variables used by DC_Init
;----------------------------------------------------------------------------
	extrn	Nic				:NicType
	extrn	PCIChipSet			:PCIChipsetSTRUC
	extrn	DESCRIPTOR_SKIP_LENGTH		:abs
	extrn	XmtNumBuffers 			:Word
	extrn	RcvNumBuffers                   :Word
	extrn	XmtCRCThreshold			:Word
	extrn	IOAddress1 			:Word
       	extrn	IORange1			:Word
	extrn	IntLine1			:Byte

END_DATA_SEGMENT_RUNTIME
