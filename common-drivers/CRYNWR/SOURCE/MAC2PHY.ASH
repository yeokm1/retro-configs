ifdef TASM
%PAGESIZE 66,130
else
PAGE 66, 130
endif
;*****************************************************************************
;   MAC2PHY.ASH
;
;	Included by MAC2PHY to setup it's exports and IMPORTS for othe HSM
;	compilation units (such as DC21X4)
;
; Written by:   Moti Haimovsky
; Date:         09-Apr-1996
;
;
; Copyright (C) 1993 by Digital Equipment Corporation 
; All rights reserved.
;
; Modification History:
; By              Date        Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; Moti Haimovsky  17-Nov-1996 2.50  - Added ErrorRoutineMessage
; Moti Haimovsky  08-Jan-1997 2.60  - Added BIND segment defininitions.
; Moti Haimovsky  17-Jan-1997       - Removed MULTIA extrn defininition since its in NIC now.
;*****************************************************************************

;****************************************************************************
;	Functions and Variables available Only During INIT Time.
;****************************************************************************
START_CODE_SEGMENT_INIT
;----------------------------------------------------------------------------
;	Functions Provided by MAC2PHY.
;----------------------------------------------------------------------------

	;MAC init and support routines
        ;-----------------------------
	public	Mac2PhyInit
	public	Mac2PhyCheckAndAdjustSelectedConnection
	public	Mac2PhyAutoDetect

	;Device init and support routines
	;--------------------------------
	public	SetDeviceDefaultParameters
	public	DisableScrambler
	public  ModifyGEP_Control                       
	public  ModifyGEP_Data


END_CODE_SEGMENT_INIT

START_DATA_SEGMENT_INIT
;----------------------------------------------------------------------------
;	Variables Provided by DC21X4
;----------------------------------------------------------------------------

	;Media selection Error messages
	;------------------------------    
	extrn	MediaNotSupportedErr            :Byte
	extrn	MediaNotFoundErr                :Byte
	extrn	MediaUnknownMessage		:Byte
	extrn	ErrorRoutineMessage		:Byte

END_DATA_SEGMENT_INIT


;****************************************************************************
;	Functions and Variables available During BIND Time.
;****************************************************************************
START_CODE_SEGMENT_BIND
;----------------------------------------------------------------------------
;	Functions Provided by DC21X4.
;----------------------------------------------------------------------------
	extrn	SendMediaTestPacket		:near

END_CODE_SEGMENT_BIND

START_DATA_SEGMENT_BIND

	;Print messages for AutoDetection and media selection
	;----------------------------------------------------
	extrn	AutoDetectionMessage		:Byte
	extrn	SwitchingToMessage              :Byte
	extrn	SwitchingToUTPMessage           :Byte
	extrn	SwitchingToBNCMessage           :Byte
	extrn	SwitchingToAUIMessage           :Byte
	extrn	SwitchingToSymScrMessage        :Byte
	extrn	SwitchingToT4Message            :Byte
	extrn	SwitchingToFxMessage            :Byte
	extrn	SwitchingBetweenTpSymScr        :Byte
	extrn	PerformingMiiPhyAutodetect      :Byte
	extrn	StartingNwayMessage             :Byte
	extrn	NoMediumFound                   :Byte

END_DATA_SEGMENT_BIND


;****************************************************************************
;	Functions and Variables available during RunTime
;****************************************************************************
START_CODE_SEGMENT_RUNTIME
;----------------------------------------------------------------------------
;	Functions provided by MAC2PHY
;----------------------------------------------------------------------------

	;MAC support routines
	;--------------------
	;Connection handling routines
	;----------------------------
	public	Mac2PhyAutosense
	public	Mac2PhyLinkHandler
	public	Mac2PhySetConnection
	public	Mac2PhyGetConnectionStatus

	;Media support routine
        ;---------------------
	public	GetMediaLineSpeed
	public	WriteInternalPhyRegs

	;Null routine
	;------------
	public	NullRoutine

;----------------------------------------------------------------------------
;	Functions required by MAC2PHY
;----------------------------------------------------------------------------
	extrn 	PostResetDelay			:near
	extrn 	Delay				:near
	extrn 	PutDeviceInRunMode		:near
	extrn 	PutDeviceInMode			:near
	extrn	DisplayMessage			:near
	extrn	Post_SetConnection		:near
	extrn	WriteCSR6Reg			:near
	extrn	WriteCSR6Tulip			:near
	extrn	WriteGEPRegisterFnet            :near
	extrn	WriteGEPRegisterTwinet          :near
	extrn	ReadGEPRegisterFnet             :near
	extrn	ReadGEPRegisterTwinet           :near

END_CODE_SEGMENT_RUNTIME

START_DATA_SEGMENT_RUNTIME

;----------------------------------------------------------------------------
;	Variables provided by Nic
;----------------------------------------------------------------------------
	extrn	Nic				:NicType
	extrn	Entry1				:word

;----------------------------------------------------------------------------
;	Variables provided by MAC2PHY
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
;	Variables provided by DC21X4
;----------------------------------------------------------------------------
	extrn	AES_INTERVAL			:abs

END_DATA_SEGMENT_RUNTIME
