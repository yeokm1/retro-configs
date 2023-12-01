;*******************************************************************************
;
; SysSrvcs.ASH
;
; Include file for Dec Tulip and Fast Ethernet boards that provides different
; system services routines to be used by the driver.
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
;
;*******************************************************************************

;******************************************************************************
;*                	Messgaes required By SYSSRVCS module                  *
;******************************************************************************
START_DATA_SEGMENT_INIT

	extrn	NotA386MachineErr	:Byte
	extrn	BadDeviceCFIDVal	:Byte
	extrn	BoardNotFoundErr	:Byte
	extrn	NoPciBIOSErr          	:Byte
	extrn	PCIBIOSBadRegErr	:Byte
	extrn	PCIBIOSBadStatusErr	:Byte
	extrn	UnknownBusErr		:Byte
	extrn	WACB_WarnCacheInWBMode	:Byte
	extrn	AllocateMemoryError	:Byte
	extrn	VDSLockMemoryError	:Byte
	extrn	HPE_PCIWarn		:Byte
	extrn	HPE_PCIErr		:Byte
	extrn	BadInterruptAllocation  :Byte

END_DATA_SEGMENT_INIT

;******************************************************************************
;*                	S Y S T E M    S E R V I C E S                        *
;******************************************************************************
START_DATA_SEGMENT_RUNTIME

	extrn	Nic			:NicType
	extrn	ImageEnd		:Word
	
IF OS EQ OS2
	extrn	devhlp			:LONG_PTR
	extrn	OS2PhysToGDTFailed	:Byte

ENDIF
IF NOS EQ ODI  				;In ODI MSM defines these Flags and vars
	extrn	I386Flag		:abs            ;In ODI MSM defines this Flag
	extrn	PCIFlag			:abs		;In ODI MSM defines this Flag
	extrn	CSFlag			:abs	        ;In ODI MSM defines this Flag
	extrn	MSMSystemFlags		:word           ;In ODI MSM defines this field
ENDIF

END_DATA_SEGMENT_RUNTIME

;******************************************************************************
;*              MODULE  INITIALIZATION  AND  CLOSE  ROUTINES                  *
;******************************************************************************
START_CODE_SEGMENT_INIT

	public	SYSSRVCS_Init		;Must be the first routine activated
					;in this module
	public	SYSSRVCS_InitDone       ;Must be called when Init phase of the
					;driver is completed
	public	SYSSRVCS_InitErrorExit  ;Must be called when Init failed and driver
					;must be unloaded.
END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_RUNTIME

	public	SYSSRVCS_Close		;To bu used when unloading the driver

END_CODE_SEGMENT_RUNTIME


;******************************************************************************
;*                S Y S T E M   B U S   S E R V I C E S                       *
;******************************************************************************

;***********************************************
;*                   P C I                     *
;***********************************************

;-------------------------------------------
;     	  Basic PCI Functions.
;-------------------------------------------
START_CODE_SEGMENT_INIT

	public	PCIFindDevice
	public	PCIFindClassCodeDevice
	public	PCIGetDeviceNumber

END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_RUNTIME

	public	PCIReadCfgDWORD
	public	PCIReadCfgWORD
	public	PCIReadCfgBYTE
	public	PCIWriteCfgDWORD
	public	PCIWriteCfgWORD
	public	PCIWriteCfgBYTE

END_CODE_SEGMENT_RUNTIME

;-------------------------------------------
;	PCI Chipset Handling functions
;-------------------------------------------
START_CODE_SEGMENT_RUNTIME

	public	HandleTURBOOnPCIMachines   	;Handles TURBO request

END_CODE_SEGMENT_RUNTIME

;-------------------------------------------
;	      PCI Variables
;-------------------------------------------
START_DATA_SEGMENT_RUNTIME

	public	PCIChipSet			;PCIChipsetSTRUC, Holds PCI chipset parameters.

END_DATA_SEGMENT_RUNTIME


;******************************************************************************
;*                	M E M O R Y   S E R V I C E S                         *
;******************************************************************************
START_CODE_SEGMENT_INIT

	public	AllocateMemory		;Allocates memory from Local pool, over Init section or from system
	public	TempMemoryAllocation    ;Allocates memory from local pool
IF NOS EQ ODI
	extrn	MSMAlloc		:Near
ENDIF

END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_RUNTIME

	public	VirtualToPhysical       ;Converts Virtual address to a Phys one
	public	PhysicalToVirtual       ;Converts Physical address to a virtual one
	public	FreeMemory		

END_CODE_SEGMENT_RUNTIME


;******************************************************************************
;*                 I N T E R R U P T   S E R V I C E S                        *
;******************************************************************************
;----------------------------------------------------------------------------
;	Init Time Functions provided by Interrupt services
;----------------------------------------------------------------------------
START_CODE_SEGMENT_INIT

	public	DoesSystemSupportERI

END_CODE_SEGMENT_INIT

;----------------------------------------------------------------------------
;	Bind Time Functions provided by Interrupt services
;----------------------------------------------------------------------------
START_CODE_SEGMENT_BIND

	public	BindInterrupts

END_CODE_SEGMENT_BIND

START_CODE_SEGMENT_RUNTIME
;----------------------------------------------------------------------------
;	Run Time Functions needed by Interrupt services
;----------------------------------------------------------------------------
IF NOS EQ ODI
	extrn	MSMSetIRQ		:near
ENDIF
IF NOS EQ NDIS2
	extrn	InterruptMain		:far
ENDIF

END_CODE_SEGMENT_RUNTIME

;----------------------------------------------------------------------------
;	Run Time data provided by Interrupt services
;----------------------------------------------------------------------------
IF NOS EQ NDIS2
IF OS EQ DOS
START_DATA_SEGMENT_RUNTIME

	public	IntVectorSave		;For interrupt sharing purpose
IF OS EQ DOS
	public	SlavePICNeedsEOI
ENDIF

END_DATA_SEGMENT_RUNTIME
ENDIF
ENDIF

;******************************************************************************
;*                 	     T I M E   S E R V I C E S                        *
;******************************************************************************
START_CODE_SEGMENT_RUNTIME

	public	Delay
	public	PostResetDelay

END_CODE_SEGMENT_RUNTIME

;******************************************************************************
;*                 	    P R I N T   S E R V I C E S                       *
;******************************************************************************
;----------------------------------------------------------------------------
;	Functions needed by Print services
;----------------------------------------------------------------------------
START_CODE_SEGMENT_BIND

IF NOS EQ ODI
	extrn	MSMPrintStringZero	:Near
ENDIF
IF OS EQ OS2
	EXTRN  	DOSWRITE		:FAR
ENDIF

END_CODE_SEGMENT_BIND

;----------------------------------------------------------------------------
;	Functions Provided by Print services
;----------------------------------------------------------------------------
START_CODE_SEGMENT_BIND

	public	DisplayMessage

IF NOS EQ NDIS2
	PUBLIC 	PrintMessage
	PUBLIc	PrintMessageZ
	PUBLIC 	PrintHexByte
ENDIF

END_CODE_SEGMENT_BIND
