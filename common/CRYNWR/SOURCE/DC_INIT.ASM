;*******************************************************************************
;
; DC_INIT.ASM
;
; ASM file for Dec Tulip and Fast Ethernet boards that handles the Chip init
; process. This modu;e is common to both the 16 bit ODI and NDIS2 drivers.
;
;Written by:   Moti Haimovsky
;	       Dror Efrati
;
; Date:        1-APR-1997
;
;
; Copyright (C) 1994 by Digital Equipment Corporation
; All rights reserved.
;
; Modification History:
;
;       By            Date     Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
;  Motti Daniel     12-Oct-97   2.61	calling ROM_Init to initiialize SROM size
;					change SetDcPCIParameters when writing CFLT
;					register to change only the CFLT part of
;					register with a mask
;*******************************************************************************
include  SEG_DEFS.INC
.386
include	 nic.inc
include	 SysSrvcs.inc
include	 DC_KWDS.inc
.8086
include	 DC_INIT.ASH
.386
include	 dc_regs.inc


START_DATA_SEGMENT_INIT

;----------------------------------------------------------
;Holds the actual threshold length.
;Use offset from above table (TxThresholdConvertTable)
;to get this parameter. Used by the software CRC
;algorithm to find out which packets are shorter than
;the threshold.
;----------------------------------------------------------
TX_THRESHOLD_SAFETY_LENGTH	equ	16	      ;must be < 72

TxThresholdLengthTable  db	  72      		;  72
			db	  96      		;  96
			db	  128      		; 128
			db	  160      		; 160



;--------------------
;BIOS override values
;--------------------
ConfigCFCSBiosVal	dw	ConfigCFCS_DEFAULT
				  ;Value of TulipConfigCFCS as read from BIOS
				  ;No parity check, master, I/O space
ConfigCFLTBiosVal	dw	configCFLT_DEFAULT ;Value of TulipConfigCFLT as read from
				  ;BIOS
CSR0ImageBiosVal	dw	CSR0_DEFAULT
				  ;Value of CSR0Image as read from BIOS
END_DATA_SEGMENT_INIT



START_CODE_SEGMENT_INIT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;       DcInit
;
;       This routine is called to intialize and bring the specified NIC
;       into operation.
;       Routine is called once only when the driver is invoked.
;       Routine verifies all special user values override to have 'good' values.
;
;       assumes:        ds=es=cs CGroup
;                       CLD has been executed
;                       Interrupts are enabled.
;
;       returns:        dx      -> error message if error during init.
;                       Carry   -> SET on Error
;  			
;			ECX, EAX Destroyed.
;                       All other registers and flags can be destroyed
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DcInit	proc	near

	;Verify CRC table is OK
	;----------------------
	call	CRC_VerifyTable
	jne	InitErrorExit			;Error msg ptr is in DX.

	;Check machine and bus type - see if we can work with such a system
	;------------------------------------------------------------------
	call	SYSSRVCS_Init
	jc      InitErrorExit   		;Error msg ptr is in DX.

	;Parse user KWDS
	;---------------
	call	ParseKWDS
	jc	SHORT InitErrorExit

	;Select Initial user parametes
        ;-----------------------------
	call	SelectInitialParameters
	jc      SHORT InitErrorExit

	;Search for our adapter
        ;----------------------
	call	FindDcBoardInSystem
	jc	InitErrorExit

	;Set Device dependent default parameters
	;---------------------------------------
	call	SetDeviceDefaultParameters

	;Read Check and set Device parameters (HDW and SW) according to BIOS selections
        ;------------------------------------------------------------------------------
	call    ReadAndCheckBiosParameters
	jc      InitErrorExit

	;Calculate Registers Addresses
        ;-----------------------------
	call	CalculateRegistersAddresses

	;Put  device in a known mode
	;---------------------------
	call	PutDeviceInSafeMode

	;Verify that we support this device
	;----------------------------------
	call 	VerifyDeviceSupport
	jc      InitErrorExit

	;Set SROM size
	;----------------------------------
	call	ROM_Init
	jc	SHORT InitErrorExit

	;Set Device parameters (HDW and SW) according to parameters read
	;From the On-Board ROM.
        ;---------------------------------------------------------------
	call	ROM_ReadAndParseRomParameters
	jc      SHORT InitErrorExit

	;Select working parameters between BIOS/Srom setup and user overrides
	;--------------------------------------------------------------------
	call	SelectWorkingParameters
	jc      SHORT InitErrorExit

	;Go and SET the system and chip PCI parmeters
	;--------------------------------------------
	call    SetPCIParameters
	jc      SHORT InitErrorExit	       ;error msg ptr is in DX.

	;Init the Phy support module
	;---------------------------
	call	Mac2PhyInit
	jc      SHORT InitErrorExit

	;Check ans adjust selected connection
        ;------------------------------------
	call	CheckAndAdjustSelectedConnection
	jc      SHORT InitErrorExit

InitExit:
	clc
        ret

InitErrorExit:
	stc
        ret

DcInit	endp

;****************************************************************************
;
;       SelectInitialParameters
;	Select Initialization/Initial parametes to be used when setting device
;	default parameters, device search etc. ;
;
; Inputs:
; 	UserKWDS
; Outputs:
;	Nic.PCType
;	Nic.NicBusType
;	Nic.SlotNumber
; Return values:
;
;****************************************************************************
SelectInitialParameters	proc	near

	push	ax

	;---------------------------
	; Select PC TYPE  parameter
	;---------------------------
	cmp	UserKWDS.PcType_UV.Selected, TRUE
	jne	SHORT SIP_DonePcType
	mov	al, UserKWDS.PcType_UV.BVal
	mov	Nic.PCType, al
SIP_DonePcType:

	;---------------------------
	; Select BUS Type parameter
	;---------------------------
	cmp	UserKWDS.Bus_UV.Selected, TRUE
	jne	SHORT SIP_DoneBus
	mov	al, UserKWDS.Bus_UV.BVal
	mov	Nic.BusType, al
SIP_DoneBus:

	;---------------------------
	; Select Slot Num parameter
	;---------------------------
	cmp	UserKWDS.SlotNumber_UV.Selected, TRUE
	jne	SHORT SIP_DoneSlot
	mov	al, UserKWDS.SlotNumber_UV.BVal
	mov	Nic.SlotNum, al
SIP_DoneSlot:

	pop	ax
	clc
	ret

SelectInitialParameters	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;       FindDCBoardInSystem
;
;       This routine is called for finding a tulip or Fasternet in the system.
;	The procedure checkes if the user has specified a slot#
;	and if so it searches the Device there.
;	if the user hasn't specified a slot# it searches the EISA bus and then
;	the PCI bus and uses the first Device found.
;	Notice:
;		Since PCI slots are virtual and EISA slots are 1..15,
;		we decided that slots 16-... will be considered as PCI slots.
;
;       assumes:        ds=es=cs CGroup
;                       CLD has been executed
;                       Interrupts are enabled.
;
;	Input:
;
;	   Nic.BusType   - if != Default
;			     specific bus where tulip should be searched.
;			  else
;			     Search in all supported busses.
;
;	   Nic.SlotNum	- if != UNDEF_SLOT
;			     specific slot where tulip should be found.
;			  else
;			     Search for tulip.
; 	   Nic.SystemFlags - Contains the type of busses in the system.
;
;       returns:
;	   If board was found:
;	       Carry reset
;	       Nic.BusType          	- The TYPE of the bus the board was found in.
;	       Nic.SlotNum		- The slot# where tulip was found.
;	       Nic.PCIAcessHandle 	- Valid if a TULIP PCI board was found.
;	   Else
;	       Carry SET
;	       dx      -> error message ptr.
;              All other registers and flags can be destroyed
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
FindDcBoardInSystem	proc

	;---------------------------------------------------------------------------
	;Check if user has specified BusId, if not - Scan all busses starting with
	;				    if so  - Find board on the specified bus
	;					     (if supported).
	;---------------------------------------------------------------------------
	cmp	Nic.BusType, BUS_TYPE_UNDEFINED
	je	SHORT AutoSearchForDC          ;Search all busses for a Board

	cmp	Nic.BusType, BUS_TYPE_PCI
	je	SHORT SearchInPCIBus
NoPCIBusSearch:

	;If reached this point UNSUPPORTED BUS
	;-------------------------------------
UnsupportedBus:
	DataAddress	dx, UnknownBusErr	 ;Prepare for worse.
	stc
	jmp	SHORT FDBIS_Exit


	;------------------------
	;Auto - search all busses
        ;------------------------
AutoSearchForDC:

	;Find PCI board
        ;--------------
SearchInPCIBus:
	call    FindBoardPCI
	;jnc     SHORT FDBIS_Exit

	;Handle Next BUS here

FDBIS_Exit:
	ret

FindDcBoardInSystem	endp

;****************************************************************************
;
;       FindBoardPCI
;
;	Finds a tulip or Fasternet PCI board (if any).
;
; Inputs:
;       Nic.SlotNum  - If value is UNDEF_SLOT
;			 scan all slots for board.
;                      else
;                        check only the user defined PCISlot for board.
;
; Outputs:
;
;	Nic.Dev	     			- The device found (Tulip or Fasternet)
;	Nic.Rev	     			- Device revision
;	Nic.PCIDeviceAccessHandle 	- For further accesses to the PCI regs of the
; 					  device.
;	Nic.BusType       		- The TYPE of the bus the board was found in.
;
; Return values:
;       If board found:
;          carry bit is cleared
;       else
;          carry bit is set
;          reg DX points to error message
;
;****************************************************************************
FindBoardPCI	proc    near

	push	ax
	push	bx
        push	ecx
	push	si
	push    di

	;---------------------------
	;Do we have PCI Bus at all ?
	;---------------------------
	DataAddress	dx, NoPciBIOSErr		;assume No PCI bus.
	test	Nic.SystemFlags, PCI_Present
	jz	FindBoardsPCIErrorExit            	;Correct assumption

	;----------------------------------------
	;Did the user ask for a specific "slot" ?
	;----------------------------------------
	cmp	Nic.SlotNum, UNDEF_SLOT
	jne	SHORT UserDefinedSlot

	mov     Nic.SlotNum, FRST_PCI_SLOT   		;Search for the first tulip

UserDefinedSlot:
	;Check definition to be in the correct range
	;(FRST_PCI_SLOT =< NICSlot)
	;--------------------------------------------
	DataAddress     dx, SlotValueErr	      	;Prepare for worse
	cmp     Nic.SlotNum, FRST_PCI_SLOT
	jb      FindBoardsPCIErrorExit

	; Calculate pci board index
	;---------------------------
	movzx	ax, Nic.SlotNum
	sub     ax, FRST_PCI_SLOT
	xor	si, si					;Start with first Ethernet device

FindEthernetDevice:
	; Search for the SI'th ethernet device
	;-------------------------------------
	mov	ecx, PCI_EHETHERNET_CLASS_CODE
	call    PCIFindClassCodeDevice
	jc      FailedToFindPCIEthernetDevice

	;If ethernet device was found go and see if its tulip or fasternet
        ;-----------------------------------------------------------------
	;Save Device handle for further BIOS accesses
	;--------------------------------------------
	mov	Nic.PCIDeviceAccessHandle, bx

	;Read Device's CFID and check if its tulipx, fasternet, Twinet or Phyer
        ;---------------------------------------------------------------------
	mov	di, PCI_CFID_OFFSET
	call	PCIReadCfgDWORD
	jc	FindBoardsPCIErrorExit

	cmp	ecx, TULIP_CFID_VAL
	jne     SHORT Not_Tulip
	dec	ax
	jnge	SHORT Found_PCI_Tulip
	jmp	SHORT KeepSearching
Not_Tulip:

	cmp	ecx, TULIP3_CFID_VAL
	jne     SHORT Not_Tulip3
	dec	ax
	jnge	SHORT Found_PCI_Tulip3
	jmp	SHORT KeepSearching
Not_Tulip3:

	cmp	ecx, FASTERNET_CFID_VAL
	jne     SHORT Not_FasterNet
	dec	ax
	jnge	SHORT Found_PCI_Fasternet
	jmp	SHORT KeepSearching
Not_FasterNet:

	cmp	ecx, TWINET_CFID_VAL
	jne     SHORT Not_TwiNet
	dec	ax
	jnge	SHORT Found_PCI_Twinet
	jmp	SHORT KeepSearching
Not_TwiNet:


KeepSearching:
	inc	si
	jmp	SHORT FindEthernetDevice

	;If reached this point no (Tulip or Twinet or Phyer or Fasternet) were found
	;---------------------------------------------------------------------------
	DataAddress	dx, BadDeviceCFIDVal
	jmp	SHORT FindBoardsPCIErrorExit


Found_PCI_Twinet:
	mov	Nic.Dev, TWINET
	jmp	SHORT FBP_SavePCIParameters

Found_PCI_Fasternet:
	mov	Nic.Dev, FASTERNET
	jmp	SHORT FBP_SavePCIParameters

Found_PCI_Tulip:
	mov	Nic.Dev, TULIP
	jmp	SHORT FBP_SavePCIParameters

Found_PCI_Tulip3:
	mov	Nic.Dev, TULIP3

FBP_SavePCIParameters:

	;Change BusType to reflect that We are going to
	;work with PCI bus.
	;---------------------------------------------
	mov	Nic.BusType, BUS_Type_PCI

	;Read and save The device rev. number
	;------------------------------------
	mov	bx, Nic.PCIDeviceAccessHandle
	mov     di, PCI_CFRV_OFFSET
	call	PCIReadCfgDWORD
	jc	SHORT FindBoardsPCIErrorExit
	mov	Nic.Rev, cl     	;Save the Version of the Device we
					;hope to work with

	pop	di
	pop	si
	pop	ecx
        pop	bx
	pop	ax
	clc
	ret

FailedToFindPCIEthernetDevice:
	DataAddress     dx, BoardNotFoundErr

FindBoardsPCIErrorExit:
	pop	di
	pop	si
	pop	ecx
        pop	bx
	pop	ax
	stc             ;Indicate error occured
	ret

FindBoardPCI  endp


;****************************************************************************
;
;       ReadAndCheckBiosParameters
;
;       Check all relevant BIOS registers.
;       Update configuration table according to the default setup in these
;       registers.
;       We also have to set some needed values into these registers for proper
;       board operation.
;
; Assumes:
;	ds=es=cs CGroup
;       Interrupts are enabled.
;
; Outputs:
;       IOAddress1
;       IORange1
;       IntLine1
;
; Return values:
;       If board found:
;          carry bit is cleared
;       else
;          carry bit is set
;          reg DX points to error message
;
;****************************************************************************
ReadAndCheckBiosParameters	  proc	near

	cmp	Nic.BusType, BUS_TYPE_PCI
	jne	SHORT  RCASDBP_NotPciBus

	call	ReadAndCheckPCIBoardParameters
	jmp	SHORT RCASDBP_Exit
RCASDBP_NotPciBus:
        stc

RCASDBP_Exit:
	ret

ReadAndCheckBiosParameters	  endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       ReadAndCheckPCIBoardParameters
;
;       Check all relevant PCI configuration registers.
;       Updates the configCxxx variables according to the default setup in
;	these registers.
;	Use PCI regs in TULIP or Fasternet to detirmine:
;	I/O base, interrupt number and other PCI config. registers values.
;
; Input values:
;       PCIDeviceAccessHandle
;
; Outputs:
;       IOAddress1
;       IORange1
;       IntLine1
;
; Return values:
;   If success in accessing PCI configuration registers, correct Tulip rev:
;       carry bit is reset
;       ConfigCFLTBiosVal
;       MLIDInterrupt            - board interrupt number
;       TulipRev
;	configCFCS
;
;       else
;          carry bit is set
;          reg DX points to error message
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ReadAndCheckPCIBoardParameters proc near

	push	edi
	push	ecx
        push	bx
	push	eax

	;-----------------------------------------------
	; Change IORange to reflect Tulip PCI IO range
        ;-----------------------------------------------
	mov	IORange1, size DC_PCIBoardStruc

	;Let bx hold Device Access Handle
	;--------------------------------
	mov	bx, Nic.PCIDeviceAccessHandle

	;---------------------------------------
	;Read CBIO to get tulip base io address
	;---------------------------------------
	mov	di, PCI_CBIO_OFFSET
	call	PCIReadCfgDWORD	       		
	jc	SHORT RACPBP_Exit

	push	ecx                             ;verify that BIOS wrote 0's in upper word
	shr     ecx, 16         	  	;of CBIO.
	or      cx, cx
        pop	ecx
	jnz     SHORT RACPBP_BadCBIOValue

	and	cx, 0FF80h		  	;mask out unused bits (FF80 for pass 2)
	jz	SHORT RACPBP_BadCBIOValue 	;check that not all bits cleared

	mov	IOAddress1 , cx   		;Save the 16 Low bits (386 and above family
						;have only 16bits of IO address space)

	;-----------------------------------------
	;Get the interrupt number from BIOS setup.
	;-----------------------------------------
	;Get BIOS interrupt setting from the CFIT register and update
	;configuration table.
ReadCFIT:
	mov     di, PCI_CFIT_OFFSET
	call    PCIReadCfgDWORD
	jc      SHORT RACPBP_Exit			;Error msg ptr is in DX
	mov     IntLine1, cl 				;Save interrupt number in config table
	cmp	cl, 0					;Did the BIOS allocate int 0 ?
	je	SHORT RACPBP_BadInterruptAllocation
	cmp	cl, MAX_INTERRUPT       		;Did the Bios allocate int > 15 ?
	ja	SHORT RACPBP_BadInterruptAllocation

	;-------------------------------
	;Get BIOS value of CFCS register
	;-------------------------------
	mov     di, PCI_CFCS_OFFSET
	call    PCIReadCfgDWORD
	jc      SHORT RACPBP_Exit	;Error msg ptr is in DX

	test    cx, ConfigCFCS_IOSpaceAccess	; check if IO access is enabled
	jz      RACPBP_IOErrorExit

	mov     ConfigCFCSBiosVal, cx

	;-------------------------------
	;Get BIOS value of CFLT register
	;-------------------------------
	mov     di, PCI_CFLT_OFFSET
	call    PCIReadCfgDWORD
	jc      SHORT RACPBP_Exit		;Error msg ptr is in DX
	cmp	cx, MIN_CFLT_WE_ACCEPT SHL 8	;Verify that BIOS gave us at
	jae	AcceptBIOS_CFLT			;least the minimum we need
	mov	cx, MIN_CFLT_WE_ACCEPT SHL 8	;If not given, take!
AcceptBIOS_CFLT:
	mov     ConfigCFLTBiosVal, cx
	clc

RACPBP_Exit:
	pop	eax
        pop	bx
	pop	ecx
	pop	edi
	ret



RACPBP_BadCBIOValue:
	DataAddress     dx, PCIBIOSBadCBIOErr
	stc
	jmp	SHORT RACPBP_Exit

RACPBP_BadInterruptAllocation:
	DataAddress	dx, BadInterruptAllocation
	stc
	jmp	SHORT RACPBP_Exit

RACPBP_IOErrorExit:				
	;------------------------------------
	; can't work if bios doesn't allow us 
	; to access device private registers.
	;------------------------------------
	DataAddress     dx, DeviceIsDisabled
	stc
        jmp     RACPBP_Exit

ReadAndCheckPCIBoardParameters       endp

;****************************************************************************
;
; ClaculateRegistersAddresses
;
; Routine Calculates Device registers I/O addresses. these addresses are saved
; in the registers variables assigned to this purpose.  all registers accesses
; (ie IN or OUT commands) will be done using these addresses.
;
; This routine is called from DriverInit in init time.
;
;
; Assumes:
;	ds=es=cs CGroup
;       Interrupts are enabled.
;
; Input values:
;       IOAddress1 -  according to the NICSlot found.
;
; Output values:
;       Nic.RGisters addresses
;
;	All registes preserved.
;
; Return values:
;        MONE
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
CalculateRegistersAddresses	proc	near

	cmp	Nic.BusType, BUS_TYPE_PCI
	jne	SHORT  CRA_NotPciBus
	call	ClaculateRegistersAddressesPCI
	jmp	SHORT CRA_Exit
CRA_NotPciBus:
	stc
        ret

CRA_Exit:
	clc
	ret

CalculateRegistersAddresses	endp

;****************************************************************************
;
; ClaculateRegistersAddressesPCI
;
; Routine uses IOAddress1 and tulip registers offsets within a PCI board to
; calculate tulip registers addresses. these addresses are saved in the
; registers variables assigned to this purpose.  all registers accesses
; (ie IN or OUT commands) will be done using these addresses.
;
; This routine is called from DriverInit in init time.
;
;
; Assumes:
;	ds=es=cs CGroup
;       Interrupts are enabled.
;
; Input values:
;       IOAddress1
;
; Return values:
;       If PCI BIOS assigned a fair CBIO value:
;          carry bit is cleared
;          Tulip registers addresses.
;       else
;          carry bit is set
;          reg DX points to error message
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ClaculateRegistersAddressesPCI         proc	near

        push	di
	push	bx
        push	ax


	; Calculate PCI Registers addresses
	;-----------------------------------
	mov  	bx, IOAddress1

	lea	ax, (DC_PCIBoardStruc PTR [bx]).PCI_CSR0
	mov	Nic.CSR0_address, ax

	lea	ax, (DC_PCIBoardStruc PTR [bx]).PCI_CSR1
	mov	Nic.CSR1_address, ax

	lea	ax, (DC_PCIBoardStruc PTR [bx]).PCI_CSR2
	mov	Nic.CSR2_address, ax

	lea	ax, (DC_PCIBoardStruc PTR [bx]).PCI_CSR3
	mov	Nic.CSR3_address, ax

	lea	ax, (DC_PCIBoardStruc PTR [bx]).PCI_CSR4
	mov	Nic.CSR4_address, ax

	lea	ax, (DC_PCIBoardStruc PTR [bx]).PCI_CSR5
	mov	Nic.CSR5_address, ax

	lea	ax, (DC_PCIBoardStruc PTR [bx]).PCI_CSR6
	mov	Nic.CSR6_address, ax

	lea	ax, (DC_PCIBoardStruc PTR [bx]).PCI_CSR7
	mov	Nic.CSR7_address, ax

	lea	ax, (DC_PCIBoardStruc PTR [bx]).PCI_CSR8
	mov	Nic.CSR8_address, ax

	lea	ax, (DC_PCIBoardStruc PTR [bx]).PCI_CSR9
	mov	Nic.CSR9_address, ax

	lea	ax, (DC_PCIBoardStruc PTR [bx]).PCI_CSR10
	mov	Nic.CSR10_address, ax

	lea	ax, (DC_PCIBoardStruc PTR [bx]).PCI_CSR11
	mov	Nic.CSR11_address, ax

	lea	ax, (DC_PCIBoardStruc PTR [bx]).PCI_CSR12
	mov	Nic.CSR12_address, ax

	lea	ax, (DC_PCIBoardStruc PTR [bx]).PCI_CSR13
	mov	Nic.CSR13_address, ax

	lea	ax, (DC_PCIBoardStruc PTR [bx]).PCI_CSR14
	mov	Nic.CSR14_address, ax

	lea	ax, (DC_PCIBoardStruc PTR [bx]).PCI_CSR15
	mov	Nic.CSR15_address, ax

        pop	ax
	pop	bx
	pop	di
        clc
	ret

ClaculateRegistersAddressesPCI		endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;       PutDeviceInSafeMode
;
;
;       assumes:        ds=es=cs CGroup
;                       CLD has been executed
;                       Interrupts are enabled.
;
;       returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PutDeviceInSafeMode	proc

	;--------------------------------
	;ResetDevice which will perform:
	; - EXit device from sleep mode
        ; - resetting the device
	;--------------------------------
	call	SoftwareResetDevice

	ret

PutDeviceInSafeMode	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;	VerifyDeviceSupport
;
;	This routine checks that the selected device is supported by our driver
;
;	assumes:  	Device Registers addresses had been calculated
;       returns:    When an unsupported device has been found:
;		 	dx      -> error message if error during init.
;			Carry      SET
;
;		    DX - Destroyed
;		    EAX- Destroyed
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
VerifyDeviceSupport	proc	near

	;-----------------
	;Prepare for worse
        ;-----------------
	DataAddress	dx, UnsupportedDeviceRevision
	push	dx

	;-----------------------------------------------
	;Tulip pass1 on PCI or CardBus- is not supported
	;-----------------------------------------------
	cmp	Nic.DevAndRev, TULIP_REV1
	jne	SHORT VDSup_NotTulipPass1
	cmp	Nic.BusType, BUS_TYPE_PCI
	je	SHORT VDSup_ErrorExit
	cmp	Nic.BusType, BUS_TYPE_CARDBUS
	je	SHORT VDSup_ErrorExit
	jmp	SHORT VDSup_Exit
VDSup_NotTulipPass1:

	;----------------------
	;Is it fastrnet pass1 ?
        ;----------------------
	cmp	Nic.DevAndRev, FASTERNET_REV1
	je	SHORT VDSup_ErrorExit

	;----------------------------
	;Is it TULIP3 in TULIP2 Mode?
        ;----------------------------
	cmp	Nic.Dev, TULIP3
	jne	SHORT	VDSup_NotTulip3               ;Not tulip3 - No problem
	mov	dx, Nic.CSR9_Address                  ;Read the mode bit
	in	eax, dx
	test	ax, 8000h                             ;Test the mode bit
	jnz	SHORT VDSup_ErrorExit
VDSup_NotTulip3InTulip2Mode:
VDSup_NotTulip3:

VDSup_Exit:
	pop	dx
	clc
	ret

VDSup_ErrorExit:
	pop	dx
	stc
	ret

VerifyDeviceSupport	endp

;****************************************************************************
;
;       SelectWorkingParameters
;
;       Select between BIOS selected parameters and user overrides the working
;	parameters, Checks if the selections done are legal according to the
;	device we work with.
;
; Inputs:
;
; Outputs:
;	Nic.ConfigCFCS
;	Nic.ConfigCFLT
;	Nic.CSR0_Value
;	Nic.CSR13_Value
;	Nic.CSR14_Value
;	Nic.CSR15_Value
;       Nic.CSR6_Value
; Return values:
;
;****************************************************************************
SelectWorkingParameters   proc near


	;------------------------------------------
	;Select the NumTxBuffers working parameter
	;------------------------------------------
	cmp	UserKWDS.TXBuffers_UV.Selected, TRUE
	jne	SHORT SWP_DoneTxBuf
	mov	ax, UserKWDS.TXBuffers_UV.Wval
	mov	XmtNumBuffers, ax
SWP_DoneTxBuf:

	;------------------------------------------
	;Select the NumRxBuffers working parameter
	;------------------------------------------
	cmp	UserKWDS.RXBuffers_UV.Selected, TRUE		
	jne	SHORT SWP_DoneRxBuf
	mov	ax, UserKWDS.RXBuffers_UV.Wval			
	mov	RcvNumBuffers, ax
SWP_DoneRxBuf:

	;Check and adjust # TX & RX buffers.
	;-----------------------------------
	call	InitSetBuffersNum

	;------------------------------------------
	;Select the PowerMode working parameter
	;------------------------------------------
	cmp	UserKWDS.SNOOZE_UV.Selected, TRUE	;Where do I use this KWD ?
	jne	SHORT SWP_DoneSNOOZE
	mov     Nic.PowerMode, CFDA_SNOOZE_MODE
SWP_DoneSNOOZE:

	;---------------------------------------------
	;Select the Ethernet Address working parameter
	;---------------------------------------------
	lea	si, IEEEAddressSROM                     ;Assume No user IEEE address override.
	cmp	(KwdEntryStruc PTR UserKWDS.NetAddress_UV).Selected, TRUE	;Is addumptiom corresct ?
	jne	SHORT SWP_DoneAddressOverride           ; YEAH !
	lea	si, (KwdEntryStruc PTR UserKWDS.NetAddress_UV).BVal		;Wrong assumptiom ! - Use user Override.
SWP_DoneAddressOverride:
	call	SetEthernetAddressVariable		;Set IEEE variable

	;---------------------------------------
	;Select the ConfigCFCS working parameter
	;---------------------------------------
	mov	ax, ConfigCFCSBiosVal
	or	ax, ConfigCFCS_BusMaster		;Enable bus master
	mov  	Nic.ConfigCFCS, ax

	;---------------------------------------
	;Select the ConfigCFLT working parameter
	;---------------------------------------
	mov	ax, UserKWDS.CFLT_UV.Wval
	cmp	UserKWDS.CFLT_UV.Selected, TRUE
	je	SHORT UseUser_CFLT
UseBios_CFLT:
	mov	ax, ConfigCFLTBiosVal	
UseUser_CFLT:
SetCFLT:
	mov	Nic.ConfigCFLT, ax

	;----------------------------------------
	;Select the CSR0_Value working parameters
	;----------------------------------------
	movzx	eax, CSR0ImageBiosVal
	mov	Nic.CSR0_Value, eax

	;Select the CSR0_Value working PBL and CAL parameters
	;----------------------------------------------------
	call	SelectPBLandCALWorkingParameters


	;Select the CSR0 DescriptorSkipLength Value
	;------------------------------------------
	and	WORD PTR Nic.CSR0_Value, NOT 7Ch 	;Clear CSR0<DSL> bits
	mov	ax, DESCRIPTOR_SKIP_LENGTH     	 	;ax to hold DescriptorSkipLength
        test	ax, NOT 7Ch				;is it a mul of 4 and a leagal size?
	jnz	SWP_ErrorExit             		;If not -> error
	or 	WORD PTR Nic.CSR0_Value, ax		;write the DescriptorSkipLength mod 4

	; Handle Extended PCI Commands
	;  These settings should be performed AFTER
	;  CAL and PBL KWDS had been handled
	;-------------------------------------------
	call	HandleExtendedPCIConnads

	;----------------------------------------
	;Select Shadow_CSR6 Working parameters
	;----------------------------------------

	;Select Shadow_CSR6 TxThreshold parameter
	;----------------------------------------
	call	SelectTXTHRWorkingParameter

	;Handle NoScrambler KWD
	;----------------------
	cmp	UserKWDS.ScramblerRequest_UV.Selected, TRUE
	jne	SHORT SWP_DoneWithScrambler
	call	DisableScrambler
SWP_DoneWithScrambler:

	;----------------------------------------
	;Select Shadow_CSR7 Working parameters
	;----------------------------------------
	;Supress Early Receive Interrupt option if
	; - Not supported by the device
	; - Not supported by NOS
        ; - User request
	;------------------------------------------
	call	DoesDeviceSupportERI
	jc	SHORT SWP_DisableERI
	call	DoesSystemSupportERI
	jc	SHORT SWP_DisableERI
	cmp	UserKWDS.NO_ERI_UV.Selected, TRUE
	jne	SHORT SWP_DoneWithERI
SWP_DisableERI:
	and	Nic.Shadow_CSR7, NOT CSR7_ERM
SWP_DoneWithERI:


	;-------------------
	;Update GEP  values
        ;-------------------

	;Update GeneralPurposeControl value
	;----------------------------------
	cmp	UserKWDS.GPR_Ctrl_UV.Selected, TRUE 	;Did user override value?
	jne	SHORT SWP_DoneWithGPC                     	;No -

	mov	ax, UserKWDS.GPR_Ctrl_UV.Wval
	call	ModifyGEP_Control
SWP_DoneWithGPC:

	;Update GeneralPurposeData value
	;-------------------------------
	cmp	UserKWDS.GPR_Data_UV.Selected, TRUE 	;Did user override value?
	jne	SHORT SWP_DoneWithGPD                     	;No -

	mov	ax, UserKWDS.GPR_Data_UV.Wval
	call	ModifyGEP_Data
SWP_DoneWithGPD:

	;----------------------
	;Handle Media Selection
        ;----------------------
	;Get user or Bios Connection selection
	;-------------------------------------
	call	SelectMediaFromUserOrBios
	jc	SHORT SWP_ErrorExit


SWP_Exit:
	clc
	ret

SWP_ErrorExit:
	stc
	ret

SelectWorkingParameters   endp

;****************************************************************************
;
;       SelectPBLandCALWorkingParameters
;
; Inputs:
;
;
; Outputs:
;	.
;
; Return values:
;
;	
;
;
;****************************************************************************
SelectPBLandCALWorkingParameters	proc	near

	push	ax

	;-------------------------------------------
	;Select the CSR0_Value working PBL parameter
	;-------------------------------------------
	mov	ax, UserKWDS.PBL_UV.Wval
	cmp	UserKWDS.PBL_UV.Selected, TRUE
	jne	SHORT DonePBLKWD
UseUser_PBL:
	and     WORD PTR Nic.CSR0_Value, (NOT PBL_BITS_MASK)	;remove the BIOS PBL value from CSR0_Vlaue
	shl     ax, PBL_BITS_LOCATION
	or      WORD PTR Nic.CSR0_Value, ax     		;set PBL bits in CSR0_Value
DonePBLKWD:

	;-------------------------------------------
	;Select the CSR0_Value working CAL parameter
	;-------------------------------------------
	mov	ax, UserKWDS.CAL_UV.Wval
	cmp	UserKWDS.CAL_UV.Selected, TRUE
	jne	SHORT DoneCALKWD
UseUser_CAL:
	and     WORD PTR Nic.CSR0_Value, (NOT CAL_BITS_MASK)	;remove the BIOS CAL value from CSR0_Vlaue
	shl     ax, CAL_BITS_LOCATION
	or      WORD PTR Nic.CSR0_Value, ax    	;set CAL bits in CSR0_Value
DoneCALKWD:

	;----------------------------------------------------------
	;Limit PBL and CAL according to Chipset limiting arameters
        ;----------------------------------------------------------
	call	LimitPBLAndCALAccordingToChipsetParameters

	;----------------------------------------------------------
	;Limit PBL and CAL according to DECchip limiting arameters
        ;----------------------------------------------------------
	call	LimitDC21x4PBLCALWorkingParameters

	pop	ax
	ret

SelectPBLandCALWorkingParameters	endp

;****************************************************************************
;
;       LimitPBLAndCALAccordingToChipsetParameters
;
;	Limits DC21x4 PBL and CAL to the PBL value limited by the PCI chipset
;	(unless CSR0<PBL> <= Chipset PBL) in order to overcome chipset bug.
;
; Inputs:
;	
;
; Outputs:
;       CSR0_Value (<PBL> and <CAL> portions of it)
;
; Return values:
;
;
;****************************************************************************
LimitPBLAndCALAccordingToChipsetParameters	proc	near

        push	ax
	push	dx

	;------------------------------------
	;Check if Chipset has PBL limitations
        ;------------------------------------
	test	PCIChipSet.CS_Capabilities, PBL_MaxLimited
	jz	SHORT LPCC_Exit

	; Check selected PBL <= Chipset PBL
	;----------------------------------
	mov	ax, WORD PTR Nic.CSR0_Value
	and     ax, PBL_BITS_MASK		;Get PBL value from CSR0_Vlaue
	shr	ax, PBL_BITS_LOCATION
	cmp	al, PCIChipSet.CS_MaxPBL
	jbe	SHORT LPCC_Exit         	;PBL is smaller than bug appearance threshold -
					 	;no change is required
	;----------------------------------
	;Modify PBL and CAL to 8 Longwords
	;----------------------------------
	DataAddress	dx, ModifyingPBLMsg
	call    DisplayMessage

	;remove the too big PBL and Cache alignment values from CSR0_Vlaue
        ;-----------------------------------------------------------------
	and     WORD PTR Nic.CSR0_Value, NOT (CAL_BITS_MASK or PBL_BITS_MASK)

	;set PBL and CAL bits in CSR0_Value to be 8 longwords
        ;----------------------------------------------------
	or      WORD PTR Nic.CSR0_Value, (PBL_8 SHL PBL_BITS_LOCATION) or (CAL_1 SHL CAL_BITS_LOCATION)

LPCC_Exit:
	pop	dx
        pop	ax
	clc
	ret

LimitPBLAndCALAccordingToChipsetParameters	endp

;****************************************************************************
;
;       LimitDC21x4PBLCALWorkingParameters
;
;	Device specific Limitations and work-around
;	which affect the general working parameters
; Inputs:
;	CSR0
;       Shadow_CSR6
; 	Nic
;
; Outputs:
;	CSR0
;       Shadow_CSR6
; Return values:
;
;****************************************************************************
LimitDC21x4PBLCALWorkingParameters	proc	near

	push	ax
	;-------------------------------------------------------------------
	;Limit PBL to 16 due to bug in tulip and Tulip3 when using PBL of 32
	;-------------------------------------------------------------------

	;Is it Tulipn chip at all ?
        ;--------------------------
	cmp	Nic.Dev, TULIP
	je	SHORT LDPCWP_LimitPBL
	cmp	Nic.Dev, TULIP3
	jne	SHORT LDPCWP_Exit

LDPCWP_LimitPBL:
	mov	ax, WORD PTR Nic.CSR0_Value
	and     ax, PBL_BITS_MASK					;Get PBL value from CSR0_Vlaue
	jz	SHORT LDPCWP_ChangeBurstLength   			;If PBL == 0 -> Change it to 16
	cmp	ax, (PBL_16 SHL PBL_BITS_LOCATION)
	jle	SHORT LDPCWP_DoneSettingPBL    				;If PBL > 16 -> Change it to 16

LDPCWP_ChangeBurstLength:
	and     WORD PTR Nic.CSR0_Value, NOT PBL_BITS_MASK		;remove the too big PBL value from CSR0_Vlaue
	or      WORD PTR Nic.CSR0_Value, (PBL_16 SHL PBL_BITS_LOCATION)	;set PBL bits in CSR0_Value to be 16 longwords

	;If using default CAL - Align CAL to PBL
        ;---------------------------------------
	cmp	UserKWDS.CAL_UV.Selected, TRUE
	jne	SHORT LDPCWP_DoneSettingCAL
	and     WORD PTR Nic.CSR0_Value, (NOT CAL_BITS_MASK)		;remove the BIOS CAL value from CSR0_Vlaue
	or	WORD PTR Nic.CSR0_Value, (CAL_2 SHL CAL_BITS_LOCATION)  ;set CAL bits in CSR0_Value to be 16 longwords
LDPCWP_DoneSettingCAL:
LDPCWP_DoneSettingPBL:
LDPCWP_Exit:
	pop	ax
	ret

LimitDC21x4PBLCALWorkingParameters	endp

;****************************************************************************
;
;       HandleExtendedPCIConnads	proc
;
;	Handles chips Extended PCI commands according to the following algorithm:
;	There are three extended PCI commands, MWI (Memory Write Invalidate),
;	MRM (Memory Read Multiple), and MRL (Memory Read Line); each
;	has a bit to enable it in CSR0 (bits 24, 23 and 21 respectively).
;
;	Only two override keywords are given; EXT_MR_OFF disables _both_
;	MRM and MRL; EXT_MW_OFF disables MWI.
;
;	The algorithm:
;		If (chip does not support ext. commands)
;			exit;
;
;		/* On powerup, all three commands are disabled */
;
;		/* MWI support: */
;		If (keyword EXT_MW_OFF was specified)
;			exit;
; 		If (config. space CFCS<4> == 1)		/* BIOS/chipset allow MWI */
;	   	and (cache line size is legal)
;	   	and (PCI chipset is not problematic for MWI)
;		then
;			set CSR0<15:14>) to value from CFLT<7:0>	/* Set CAL */
;		    	CSR0<13:8> = 0			/* Set PBL for unlimited burst */
;		    	CSR0<24> = 1;			/* Enable MWI */
;
;		If (keyword EXT_MR_OFF was specified)
;			exit;
;
;		/* MRM support: */
;		If (PCI chipset is not problematic for MRM)
;			set CSR0<21> = 1;		/* Enable MRM */
;		
; 		/* MRL support */
;		If (cache line size is legal)
;	   	and (PCI chipset is not problematic for MRL)	
;		then
;			set CSR0<15:14>) to value from CFLT<7:0>	/* Set CAL */
;		    	CSR0<13:8> = 0			/* Set PBL for unlimited burst */
;		    	CSR0<23> = 1			/* Enable MRL */
;
;		Exit;
;
;	Further details:
;	---------------
;	Cache line size is legal if CFLT<7:0> is 8, 16 or 32.
;
;	Problematic chipsets (note that this list may be expanded  or refined
;	in the future, so you may want to have placeholders in your code):
;	Problematic chipsets for MRM: None
;	Problematic chipsets for MRL: None
;	Problematic chipsets for MWI:
;		The Intel Orion chipset:
;               chip name: Intel 82450KX Orion P6 chipset
;		vendor ID: 0x8086
;               device ID: 0x84C4, all revisions
;		(note we may want to restrict this to certain revision
;		IDs in the future)
;
;	If PCI chipset is one that otherwise has a limited burst size
;	(according to existing driver workarounds), then
;	For MRL and MWI
;		if (CFLT<7:0> > max_allowable_PBL_according_to_workaround)
;			leave MRL and MWI disabled
;
;	The following chips support the ext. commands:
;		Fasternet3.5, Fasternet 3.6 (21140-AD,21140-AE): CFID=0009h, CFRV >= 21h
;		Twinet1, Twinet2 (21142, 21143): CFID=0019h, all revisions
;		Fasternet4 will also support them.
;
; Inputs:
;
; Assumes:
;	PCI Chipset Type is already Known
;	CSR0_Value PBL and CAL had already been configured.
;
; Modifies:
;	Nic.CSR0_Value
;
; Return values:
;
;****************************************************************************
HandleExtendedPCIConnads	proc	near

	push	eax
	push	bx
	push	cx
        push	di

	;--------------------------------
	;Start with CSR0 <MRM><MRL><MWI>
        ;--------------------------------
	mov	ax, MRL_capable or MWI_capable or MRM_capable

	;---------------------------------------------
	;Modify Settings according to USER selections
        ;---------------------------------------------
	cmp	UserKWDS.ExtPCIOFF_UV.Selected, TRUE
	jne	SHORT HEPC_DoneWithUserSelection
	not	UserKWDS.ExtPCIOFF_UV.WVal
	and	ax, UserKWDS.ExtPCIOFF_UV.WVal
	jz	SHORT HEPC_Exit                     ;If No Extended PCI support at all - Exit
HEPC_DoneWithUserSelection:

	;------------------------------------------------
	;Modify settings according to DC21X4 Chip in use
	;------------------------------------------------
        push	ax                                              ;Save current settings
	call	GetDC21X4ExtPCICommndsSupport   		;AX - Extended PCI capabilities Bits mask
	pop	cx                                              ;Restore settings.
        and	ax, cx                                          ;combine settings.
	jz	SHORT HEPC_Exit					;If No Extended PCI support at all - Exit

	;-----------------------------------------------
	;Modify settings according to PCI Chipset found
	;-----------------------------------------------
	and	ax, PCIChipSet.CS_Capabilities
	jz	SHORT HEPC_Exit                     		;If No Extended PCI support at all - Exit


	;------------------------------
	;SET CSR0 Extended PCI commands
	;------------------------------

	;IF MRL or MWI are to be set do the following:
	;   set CSR0<15:14> to value from CFLT<7:0>  /* Set CAL to PCI BIOS CAL settings*/
	;	CSR0<13:8> = 0			     /* Set PBL for unlimited burst */
	;-----------------------------------------------------------------------------------
	test	ax, (MRL_capable or MWI_capable)
	jz	SHORT HEPC_DoneMRLorMWI

        ;Read CFLT Bits <7:0>  (PCI BIOS CAL Settings are placed here
	;------------------------------------------------------------
	mov	bx, Nic.PCIDeviceAccessHandle
	mov	di, PCI_CFLT_OFFSET
	call	PCIReadCfgBYTE
	jc	SHORT HEPC_Exit

	;if (CFLT<7:0> > max_allowable_PBL_according_to_workaround) then
	;	leave MRL and MWI disabled
        ;---------------------------------------------------------------
	mov	bx, WORD PTR Nic.CSR0_Value           ;Isolate PBL from CSR0
	and	bx, PBL_BITS_MASK
	shr	bx, PBL_BITS_LOCATION
	cmp	cl, bl                                ;if (CFLT<7:0> > max_allowable_PBL_according_to_workaround) then
	jbe	SHORT HEPC_ContinueWithMRLandMWI
	and	ax, NOT (MRL_capable or MWI_capable)  ;		leave MRL and MWI disabled
	jmp	SHORT HEPC_DoneMRLorMWI

HEPC_ContinueWithMRLandMWI:

	;remove old PBL and CAL values from CSR0_Vlaue
        ;---------------------------------------------
	and     WORD PTR Nic.CSR0_Value, NOT (CAL_BITS_MASK or PBL_BITS_MASK)

	;set PBL and CAL bits in CSR0_Value
	;-----------------------------------
	;CAL == 8
        ;---------
	cmp	cl, 8
	ja	SHORT HEPC_NotCAL_8
	or      WORD PTR Nic.CSR0_Value, (PBL_0 SHL PBL_BITS_LOCATION) or (CAL_1 SHL CAL_BITS_LOCATION)
	jmp	SHORT HEPC_DonePBLandCALSettings
HEPC_NotCAL_8:

	;CAL== 16
        ;--------
	cmp	cl, 16
	ja	SHORT HEPC_NotCAL_16
	or      WORD PTR Nic.CSR0_Value, (PBL_0 SHL PBL_BITS_LOCATION) or (CAL_2 SHL CAL_BITS_LOCATION)
	jmp	SHORT HEPC_DonePBLandCALSettings
HEPC_NotCAL_16:

	;CAL == 32
        ;---------
	or      WORD PTR Nic.CSR0_Value, (PBL_0 SHL PBL_BITS_LOCATION) or (CAL_3 SHL CAL_BITS_LOCATION)
HEPC_DonePBLandCALSettings:

HEPC_DoneMRLorMWI:

	;-------------------------------------------
	;Handle DC21X4 Extended PCI BUG:
	; If Both MRM and MWI are SET -> Disable MWI
        ;-------------------------------------------
	test	ax, MWI_capable 		;If MWI is NOT SET - Done
	jz	SHORT HEPC_DoneDCWA
	test	ax, MRL_capable                 ;If MRL is NOT SET - Done
	jz	SHORT HEPC_DoneDCWA
	and	ax, NOT MWI_capable             ;Reset MWI
HEPC_DoneDCWA:

	;---------------------------------------
	;Add Extended PCI commands to CSR0_Value
	;---------------------------------------
	shl     eax, 16                 ;Align EXT PCI bits
	or 	Nic.CSR0_Value, eax
        clc

HEPC_Exit:
	pop	di
	pop	cx
        pop	bx
	pop	eax
	ret

HandleExtendedPCIConnads	endp

;****************************************************************************
;
;       GetDC21X4ExtPCICommndsSupport	proc
;
;	Returns DC21x4 chips Extended PCI command capabilitiess accordnig
;	to the followinf roules:
;
;	The following chips support the ext. commands:
;		Fasternet3.5, Fasternet 3.6 (21140-AD,21140-AE): CFID=0009h, CFRV >= 21h
;		Twinet1, Twinet2 (21142, 21143): CFID=0019h, all revisions
;		Fasternet4 (PHYER )will also support them.
;	MWI and MRL support is valid only if Cache line size is legal
;	  ( CFLT<7:0> is 8, 16 or 32.)
;
; Inputs:
;
; Assumes:
;	DC21x4 PCI Device Type is already Known.
;
; Modifies:
;
; Return values:
; 	Upon SUCCESS AX - Extended PCI bommands capabilities BIT MASK
;		     CF - Cleared
;	If Failure or no support: AX destroyed
;				  CF - Set
;		All other registers are preserved.
;
;****************************************************************************
GetDC21X4ExtPCICommndsSupport	proc	near

	push	bx
	push	cx
	push	di

	xor	ax, ax

	;-------------------------------------------------
	;Check if Device suppoerts Ext PCI commands at all
	;-------------------------------------------------

	;Tulipn Family Does NOT support Extended PCI
	;--------------------------------------------
	cmp	Nic.Dev, TULIP
	je	SHORT GEPCS_ErrorExit
	cmp	Nic.Dev, TULIP3
	je	SHORT  GEPCS_ErrorExit

	;Only Fasternet REV < 21h Does NOT support Extended PCI
	;------------------------------------------------------
	cmp	Nic.Dev, FASTERNET
	jne	SHORT GEPCS_GetCommandSupport
	cmp	Nic.Rev, CFRV_REV2_1
	jb	SHORT GEPCS_ErrorExit

	;----------------------------------
	;Get Extended PCI commands support
        ;----------------------------------
GEPCS_GetCommandSupport:

	;MRM is always supported
	;------------------------
	or	ax, MRM_capable

	;MWI is supported if:
	;   Cache line size (CFLT<7:0>) is 8, 16 or 32 and config. space CFCS<4> == 1.
	;MRL is supported if:
	;   Cache line size (CFLT<7:0>) is 8, 16 or 32.
	;-----------------------------------------------------------------------------

	;Check if CFLT Bits <7:0> value is 8, 16 or 32.
	;----------------------------------------------
	mov	bx, Nic.PCIDeviceAccessHandle
	mov	di, PCI_CFLT_OFFSET
	call	PCIReadCfgBYTE
	jc	SHORT GEPCS_ErrorExit

	cmp	cl, 8
	je	SHORT GEPCS_LegalCache
	cmp	cl, 16
	je	SHORT GEPCS_LegalCache
	cmp	cl, 32
	jne	SHORT GEPCS_ErrorExit
GEPCS_LegalCache:
	or	ax, MRL_capable 	;Legal Cache -> MRL is supported

	;Ceck that CFCS<4> == 1
	;-----------------------
	mov	bx, Nic.PCIDeviceAccessHandle
	mov	di, PCI_CFCS_OFFSET
	call	PCIReadCfgBYTE
	jc	SHORT GEPCS_ErrorExit

	test	cl, 10h
	jz	SHORT GEPCS_DoneMWI
	or	ax, MWI_capable
GEPCS_DoneMWI:
GEPCS_Exit:
	pop	di
	pop	cx
        pop	bx
	clc
	ret

GEPCS_ErrorExit:
	pop	di
	pop	cx
        pop	bx
	stc
	ret

GetDC21X4ExtPCICommndsSupport	endp

;****************************************************************************
;
;       SelectTXTHRWorkingParameter
;
; Inputs:
;
;
; Outputs:
;	Shadow_CSR6 Tx Thr bits.
;
; Return values:
;
;	
;
;
;****************************************************************************
SelectTXTHRWorkingParameter	proc	near

	push	ax
        push	dx

	;------------------------------------------------
	;Set TX THR according to user selection (if any)
	;------------------------------------------------
	cmp	UserKWDS.TxTHR_UV.Selected, TRUE
	jne	SHORT STT_DoneThrKWD
	mov	ax, UserKWDS.TxTHR_UV.Wval
	call	SetTxThreshold
STT_DoneThrKWD:

	;---------------------------------------------
	;Limit TX THR according to Chipset parameters
	;---------------------------------------------
	test	PCIChipSet.CS_Capabilities, THR_MinLimited
	jz	SHORT STT_NoChipsetThrLimit

	;TX THR = MAX(Chipset Limit, Chip setting)
        ;------------------------------------------
	call	GetTxThreshold
	cmp	ax, PCIChipSet.CS_MinTxThreshold
	jae	SHORT STT_NoChipsetThrLimit

	mov	ax, PCIChipSet.CS_MinTxThreshold	;Set TX THR according to CHIPSET limitations
	call	SetTxThreshold
	DataAddress	dx, WACB_ModifyingTxTHR         ;Issue an appropriate message.
	call	DisplayMessage
STT_NoChipsetThrLimit:

	;------------------------------------------
	;Limit TX THR according to Chip parameters
	;------------------------------------------
	call	SetDcTxTHRWorkingParameter	;Perform chip specific adjustments

	pop	dx
	pop	ax
        ret

SelectTXTHRWorkingParameter	endp

;****************************************************************************
;
;       SetTxThreshold
;
; Inputs:
;       AX - TX Thresholds (range 0..4 where 4 is FP in Fasternet or Twinet)
;
; Outputs:
;	Shadow_CSR6 Tx Thr bits.
;
; Return values:
;
;	AX - Destroyed
;
;
;****************************************************************************
SetTxThreshold	proc

	;If Value == TX_THRESHOLD_MAX+1 then
	;       CSR6<TR> = TX_THRESHOLD_MAX;
	;       CSR6<FP> = 1; (FasterNet Only)
	;else
	;       CSR6<TR> = Value;
	;       CSR6<FP> = 0; (FasterNet Only)
	;-------------------------------------
	and     WORD PTR Nic.Shadow_CSR6, 03FFFh    ;CSR6<TR> = 0
	and     Nic.Shadow_CSR6, not CSR6_FP        ;CSR6<FP> = 0

	cmp     ax, TX_THRESHOLD_MAX
	ja      SHORT TxThr_HandleFP
	jmp	SHORT TxThr_HandleTxTHR

TxThr_HandleFP:
	mov	ax, TX_THRESHOLD_MAX            ;Go to max THR if its not Twinet or Fasternet
	cmp	Nic.Dev, TWINET                 ;CSR6<FP> = 1 is valid only in
	je	SHORT Set_TxThr_FP              ;Twinet,
	cmp	Nic.Dev, FASTERNET              ;and
	jne	SHORT TxThr_HandleTxTHR	        ;FasterNet.
Set_TxThr_FP:
	or      Nic.Shadow_CSR6, CSR6_FP            ;CSR6<FP> = 1

TxThr_HandleTxTHR:
	shl     ax, 14
	or      WORD PTR Nic.Shadow_CSR6, ax        ;Update CSR6<TR>

TxThr_Exit:
	ret


SetTxThreshold	endp

;****************************************************************************
;
;       GetTxThreshold
;
; Inputs:
;	Shadow_CSR6.
;
; Outputs:
;       AX - TX Thresholds (range 0..4 where 4 is FP in Fasternet or Twinet)
;
; Return values:
;
;
;****************************************************************************
GetTxThreshold	proc

	mov	ax, TX_THRESHOLD_MAX + 1	;Assume FP setting
	test    Nic.Shadow_CSR6, CSR6_FP            ;CSR6<FP> = 1 ?
	jnz	SHORT GetThr_Exit               ;If so - Done.

	mov	ax, WORD PTR Nic.Shadow_CSR6        ;Get Tx-Thr value
	shr     ax, 14

GetThr_Exit:
	ret

GetTxThreshold	endp

;****************************************************************************
;
;       SetDcTxTHRWorkingParameter
;
;	Device specific Limitations and work-around
;	which affect the general working parameters
; Inputs:
;	CSR0
;       Shadow_CSR6
; 	Nic
;
; Outputs:
;	CSR0
;       Shadow_CSR6
; Return values:
;
;****************************************************************************
SetDcTxTHRWorkingParameter	proc	near

	push	ax
	push	bx

	;---------------------------------------------------------------------
	;If version > 2.2 no tx underflow workaround required:
	;  - leave Tx Threshold and TX_CRC_Threshold in its default value (-1)
	;---------------------------------------------------------------------
	cmp	Nic.Dev, TULIP
	jne     SHORT STTP_CRC_WorkaroundDecisionDone
	cmp     Nic.Rev, CFRV_REV2_2
	ja	SHORT STTP_CRC_WorkaroundDecisionDone

	;-----------------------------
	;Handle SW CRC check Selection
        ;-----------------------------
	cmp	UserKWDS.SwCRC_UV.Selected, TRUE    	;Handle SW CRC here since TX THR depends
	jne	SHORT STTP_CRC_WorkaroundDecisionDone	;On It

	cmp	UserKWDS.SwCRC_UV.Bval, NEVER_CALC_SOFTWARE_CRC
	je	SHORT STTP_CRC_WorkaroundDecisionDone

	;Change Tx Threshold to MAX (in order to save SW CRC calc  on small packets
	;--------------------------------------------------------------------------
	mov	ax, TX_THRESHOLD_MAX
	call	SetTxThreshold

	;Select CRC calc threshold
	;-------------------------
	call	GetTxThreshold
	lea     bx, TxThresholdLengthTable
	xlat					;select the apropriate threshold
	sub	ax, TX_THRESHOLD_SAFETY_LENGTH	;allow a few longwords space
						;between current threshold
						;and maximum packet length
						;that is said to not need
						;software CRC calculation.
						;(because it is considered
						;shorter than the tx threshold).
	mov 	XmtCRCThreshold, ax
STTP_CRC_WorkaroundDecisionDone:

        pop	bx
        pop	ax
	ret

SetDcTxTHRWorkingParameter	endp

;****************************************************************************
;
;       DoesDeviceSupportERI	proc
;
;		Checkes if DC chip we work with supports ERI or not.
;               As for today TULIP3, FASTERNET3 and above and TWINET support ERI.
;
;       assumes:
;               Nic.DevAndRev is already initialized.
;       returns:
;		Carry flag SET   - Device does NOT support ERI.
;		Carry flag RESET - Device supports ERI.
;
;****************************************************************************
DoesDeviceSupportERI	proc

	cmp	Nic.Dev, TULIP			;Tulip2 does NOT support Early int
	je	SHORT DDSE_NoSupport

	cmp	Nic.Dev, FASTERNET              ;Tulip3, Twinet, Phyer and Fnet>=2.0 support ERI
	jne	SHORT DDSE_Support
	cmp	Nic.Rev, CFRV_REV1_1
	jbe	SHORT DDSE_NoSupport
DDSE_Support:
	clc
	ret

DDSE_NoSupport:
	stc
	ret

DoesDeviceSupportERI	endp

;****************************************************************************
;
;       SelectMediaFromUserOrBios
;
;       Selects between Bios and User selections, updates UserKWDs
;	according to the selections
;
; Inputs:
;       UserKWDS
; Outputs:
;       UserKWDS
; Return values:
;
;****************************************************************************
SelectMediaFromUserOrBios	proc	near

	;-----------------------
	;Handle media selection
	;-----------------------
	;If user had selected a media then
	;	use it (togater with LineSpeed)
	;ElseIf SROM contains media selection then
	;	use it (as is)
	;Else
	;	Error
        ;------------------------------------------
	cmp	UserKWDS.SelectedConnectionType_UV.Selected, TRUE
	je	SHORT SMUB_DoneMediaSelection

	;Handle SROM media selection
        ;-------------------------
	cmp     Nic.SelectedConnectionType, NoSelectedConnection 	;Do we have SROM selection ?
	je	SMUB_ErrorExit                                         	; No - Error
	jmp	SMUB_Exit                                   		; YES - Use it
SMUB_DoneMediaSelection:

	;-----------------------------
	;Handle  LineSpeed Selection
	;-----------------------------
	;If user had selected LineSpeed then
	;	Use it
	;Else
	;	Fake a selection according to Dev Type.
        ;--------------------------------------------
	cmp	UserKWDS.LineSpeed_UV.Selected, TRUE
	je	SHORT SMUB_DoneLineSpeedSelection

	;Fake LineSpeed selection according to Dev type
        ;----------------------------------------------
	mov	UserKWDS.LineSpeed_UV.Selected, TRUE

	;TulipX & Twinet1 default line speed is 10
        ;-----------------------------------------
	mov     UserKWDS.LineSpeed_UV.WVal, 10
	cmp	Nic.Dev, TULIP
	je	SHORT  SMUB_DoneLineSpeedSelection
	cmp	Nic.Dev, TULIP3
	je	SHORT  SMUB_DoneLineSpeedSelection
	cmp	Nic.DevAndRev, TWINET_REV1
	je	SHORT  SMUB_DoneLineSpeedSelection
	cmp	Nic.DevAndRev, TWINET_REV1_1
	je	SHORT  SMUB_DoneLineSpeedSelection

	;Fasternet, Twinet2 and Phyer families default line speed is 100
        ;----------------------------------------------------------------
	mov     UserKWDS.LineSpeed_UV.WVal, 100
SMUB_DoneLineSpeedSelection:


	;--------------------------------------------------------------
	;Select Connection using User's LineSpeed and media selection
        ;--------------------------------------------------------------
SMUB_SelectConnection:
     ;-----------------------------------------------------------------------------------------
     ;Combine LineSpeed and ConnectionType selections to create the user SelectedConnectionType
     ;-----------------------------------------------------------------------------------------
     ;Requested Connection    Requested LineSpeed          Chip        SelectedConnection Selected LineSpeed
     ;---------------------+----------------------+------------------++------------------+-------------------
	;AUTODTECT        && 100 || 10			             -> AUTODTECT        (100|| 10)
	;AUI              && 100 || 10				     -> Aui,	  	   10
	;BNC              && 100 || 10				     -> Bnc,	  	   10
	;T4		  && 100                                     -> 100BaseT4         100
        ;T4               &&  10                                     -> TP                 10
	;TP	          &&  10                 	     	     -> Tp,           	   10
	;TP     	  && 100    			     	     -> SymScr(100BaseTX) 100
	;TP_FD            &&  10                             	     -> TpFD,         	   10
	;TP_FD  	  && 100    			     	     -> SymScr_FD,	  100
	;TP_NLT           &&  10                 	     	     -> Tp_NLT,       	   10
	;TP_NLT 	  && 100    			     	     -> SymScr,           100
	;-----------------+----------------------+-------------------++-----------------+-------------------

	;AutoDetect/AutoSense Handling
	;-----------------------------
	cmp	UserKWDS.SelectedConnectionType_UV.Wval, ConnectionAutoSense
	je	SHORT SMUB_DoneConnectionLineSpeedCombination

	;AUI handling
	;------------
	cmp	UserKWDS.SelectedConnectionType_UV.Wval, ConnectionAUI
	je	SHORT SMUB_DoneConnectionLineSpeedCombination

	;BNC Handling
	;------------
	cmp	UserKWDS.SelectedConnectionType_UV.Wval, ConnectionBNC
	je	SHORT SMUB_DoneConnectionLineSpeedCombination

	;T4 Handling
        ;-----------
	cmp	UserKWDS.SelectedConnectionType_UV.Wval, Connection100BaseT4
	jne	SHORT SMUB_NotT4
	cmp	UserKWDS.LineSpeed_UV.Wval, 100
	je	SHORT SMUB_DoneConnectionLineSpeedCombination
	mov	UserKWDS.SelectedConnectionType_UV.Wval, ConnectionTP
	jmp	SHORT SMUB_DoneConnectionLineSpeedCombination
SMUB_NotT4:

	;TP and TP-mutations handling
	;----------------------------
	cmp	UserKWDS.LineSpeed_UV.Wval, 100
	jne	SHORT SMUB_HandleTP10Media

	;TpFD, 100 == SymScrFD
        ;---------------------
	cmp	UserKWDS.SelectedConnectionType_UV.Wval, ConnectionTpFD
	jne	SHORT SMUB_NotTpFD
	mov     UserKWDS.SelectedConnectionType_UV.Wval, ConnectionSymScrFD
	jmp	SHORT SMUB_DoneConnectionLineSpeedCombination
SMUB_NotTpFD:

	;TP 100 or TP_NLT 100 == SymScr
        ;------------------------------
	mov     UserKWDS.SelectedConnectionType_UV.Wval, ConnectionSymScr
	jmp	SHORT SMUB_DoneConnectionLineSpeedCombination

SMUB_HandleTP10Media:
	;TP, 10 == TP  TP_NLT 10 == TP_NLT
	;---------------------------------

SMUB_DoneConnectionLineSpeedCombination:
	mov	ax, UserKWDS.SelectedConnectionType_UV.Wval
	mov	Nic.SelectedConnectionType, ax

SMUB_Exit:
	clc
	ret

SMUB_ErrorExit:
	DataAddress	dx, MediaNotSupportedErr 		;No media selection Error
	stc                         		
	ret

SelectMediaFromUserOrBios	endp

;****************************************************************************
;
;       SetPCIParameters
;
;       This routine sets the PCI registers of the system and DECchip.
;
; Inputs:
;	Nic
;	UserKwds
; Outputs:
;    On success:
;	carry - cleared
;    fail
;       carry - set
;       DX   - error message ptr
;
; All other registers are preserved.
;
; Return values:
;
;****************************************************************************
SetPCIParameters   	proc 	near

	push	ax

	;------------------------------
	;Set PCI chipset to TURBO mode
	;------------------------------
	cmp	UserKWDS.Turbo_UV.Selected, TRUE	
	jne	SHORT SPP_DoneTurbo

	xor	ax, ax			    	    ;Clear CPU-PCI posting enable bit.
	call	HandleTURBOOnPCIMachines
	jc      SHORT SPP_Exit   	       	    ;Error msg ptr is in DX.
SPP_DoneTurbo:

	;------------------------------------------
	;Go and write the "PCI parmeters" to Dcxxxx
	;------------------------------------------
	call	SetDcPCIParameters

SPP_Exit:
	pop	ax
	ret

SetPCIParameters	endp

;****************************************************************************
;
;       SetDcPCIParameters
;
;       This routine sets the PCI registers of tulip using the
;	ConfigCxxx values.
;
; Inputs:
;       IOAddress1
;	BusId
;	PCIDeviceAccessHandle
; Outputs:
;    On success:
;	carry - cleared
;       PCI configuration registers CFCS, CFLT, CBIO initialized.
;    fail
;       carry - set
;       DX   - error message ptr
;
; All other registers are preserved.
;
; Return values:
;
;****************************************************************************
SetDcPCIParameters   proc near

	cmp	Nic.BusType, BUS_TYPE_PCI
	jne	SHORT STPP_NotPci

	push	di
	push	ax
        push	bx
	push	ecx

	;Let bx hold Device Access Handle
	;--------------------------------
	mov	bx, Nic.PCIDeviceAccessHandle

	;--------------------
	;Handle CFCS register
	;--------------------
	movzx	ecx, Nic.ConfigCFCS    		;high word of ECX is 0
	mov     di, PCI_CFCS_OFFSET
	call	PCIWriteCfgDWORD
	jc	SHORT PCIBusSettingsExit

	;--------------------
	;Handle CFLT register
	;--------------------
	mov     di, PCI_CFLT_OFFSET
	call    PCIReadCfgDWORD
	and	ecx, PCI_CFLT_MASK
	or	cx, Nic.ConfigCFLT
	call	PCIWriteCfgDWORD
	jc	SHORT PCIBusSettingsExit

	clc

PCIBusSettingsExit:
	pop	ecx
	pop	bx
	pop	ax
	pop	di
	ret

STPP_NotPci:
	stc
	ret

SetDcPCIParameters   endp

;****************************************************************************
;
;       CheckAndAdjustSelectedConnection	proc
;
; Inputs:
;
;
; Outputs:
;	Shadow_CSR6 Tx Thr bits.
;
; Return values:
;
;	AX - Destroyed
;
;
;****************************************************************************
CheckAndAdjustSelectedConnection	proc

	push	ax
	push	si

	;------------------------------------------
	;Verify that a Connection had been selected
        ;------------------------------------------
	cmp     NIC.SelectedConnectionType, NoSelectedConnection
	je	MediaSelNotAvailable

	;Do we have a media selection at all?
        ;------------------------------------
	cmp	Nic.SelectedMedia, NoSelectedMedia
	je	SHORT MediaSelNotAvailable

	;Do we have a Mode selection ?
	;-----------------------------
	cmp	Nic.SelectedOperationMode, NoOperationMode
	jne	SHORT OprationModeSelected
	mov	Nic.SelectedOperationMode, NoSpecialOperationMode
OprationModeSelected:

	;CheckThat the selected connection is supported by the Nic
        ;---------------------------------------------------------
	call	Mac2PhyCheckAndAdjustSelectedConnection

CAASC_Exit:
	pop	si
	pop	ax
	ret

MediaSelNotAvailable:
	DataAddress	dx, MediaNotSupportedErr
        stc
	jmp	SHORT CAASC_Exit

CheckAndAdjustSelectedConnection	endp

;****************************************************************************
;
; Name:         CheckEthernetAdressOverride
;
; Description:  This routine Checks if the IEEE address had been overriden by
;		the user and returns an indication if it did.
;
; On Entry:
;		UserKWDs  - Initialized and parsed.
;
; On Return:
;               all registers are  Preserved
;
;               Flags:
;
;                  Zero flag SET   - IEEE Address had been overriden by user
;                  Zero flag RESET - IEEE Address had NOT been overriden by user
;
;****************************************************************************
DidUserOverrideIEEEAddress	proc

	cmp	(KwdEntryStruc PTR UserKWDS.NetAddress_UV).Selected, TRUE
	ret

DidUserOverrideIEEEAddress	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;       DisplaySelectedChip
;
;       This routine is called for displaying the selected chip
;
;       assumes:        ds=es=cs CGroup
;                       CLD has been executed
;                       Interrupts are enabled.
;
;	returns:	None
;
;			dx	Destroyed
;			eax	Destroyed
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DisplaySelectedChip	proc	near
	; ------------------------
	; Print the selected Device
	; ------------------------
	;Tulip
        ;-----
	DataAddress	dx, WorkingWith21040_Message
	cmp	Nic.Dev, TULIP
	je	SHORT DSC_PrintDeviceName

	;Tulip3
        ;------
	DataAddress	dx, WorkingWith21041_Message
	cmp	Nic.Dev, TULIP3
	je	SHORT DSC_PrintDeviceName
			
	;Fasternet & Fasternet3
        ;----------------------
	DataAddress	dx, WorkingWith21140and21140A_Message
	cmp	Nic.Dev, FASTERNET
	je      SHORT DSC_PrintDeviceName

	;Twinet
        ;------
	DataAddress	dx, WorkingWith21142and21143_Message
	cmp	Nic.Dev, TWINET
	je     	SHORT DSC_PrintDeviceName

	stc		; Unknown chip - return carry
	jmp	DSC_exit

DSC_PrintDeviceName:
	call	DisplayMessage
	clc
DSC_exit:
	ret
DisplaySelectedChip	endp


IF NOS EQ NDIS2
IF OS EQ DOS
END_CODE_SEGMENT_INIT


START_CODE_SEGMENT_BIND
ENDIF
ENDIF
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;       DisplaySelectedMedia
;
;       This routine is called for displaying the selected media
;
;       assumes:        ds=es=cs CGroup
;                       CLD has been executed
;                       Interrupts are enabled.
;
;	returns:	None
;
;			dx	Destroyed
;			eax	Destroyed
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DisplaySelectedMedia	proc	near

	push	bx
	
	; ------------------------
	; Print the selected media
	; ------------------------
	DataAddress	dx, WorkingWithMediaMessage
	call	DisplayMessage

	;If Autosense-Nway media and Nway configuring -> Media is unknown
        ; Print "Autosense"
	;---------------------------------------------------------------
	test	Nic.SelectedOperationMode, ModeNWAY or ModeAUTOSENSE
	jz	SHORT DSM_DoneAsNway

IF OS EQ DOS
	call	Mac2PhyGetConnectionStatus
	jc	SHORT DSM_AsNotCompleted
	cmp	ah, NWAY_CONFIGURING
	jne	SHORT DSM_DoneAsNway
ELSE
	; In OS/2, this routine is called before auto-detection is performed.
	; thus, when the selected operation mode is nway or autosense, the
	; media AutoSense is displayed.
ENDIF

DSM_AsNotCompleted:
	; If nic.SelectedMedia is BNC or AUI & the media is present then print it also
	;-----------------------------------------------------------------------------
	mov	bx, BNC				
	cmp	nic.SelectedMedia, MediaBNC
	je	DSM_CheckPresence
	mov	bx, AUI
	cmp	nic.SelectedMedia, MediaAUI
	jne	DSM_PrintAutosenseOnly
		
DSM_CheckPresence:
	cmp	nic.Media[bx].MediaPresence, Present
	je 	SHORT DSM_DoneAsNway
	
DSM_PrintAutosenseOnly:
	DataAddress	dx, WorkingWithAutosenseMessage   ;Nway did not complete - Print Autosense	
	call	DisplayMessage

	DataAddress	dx, NewLineLineFeedMessage
	call	DisplayMessage
	jmp	SHORT DSM_Exit
DSM_DoneAsNway:

	;Print the selected medium according to the following rules:
	; If selected medium is unknown then
	; 	Skip Printing
	; else
        ;	Print selected medium name
        ; endif
        ;-----------------------------------------------------------
	movzx   si, Nic.SelectedMedia   		;Get the selected media
	cmp	si, NoSelectedMedia
	je	SHORT DSM_DonePrintingSelectedMedia     ;If no selected media - Skip printing

	shl	si, 1					;convert to WORD address since every entry
	mov	dx, MediaTypeMessage[si]        	;Get selected media message address
	call	DisplayMessage              		;Print it.
DSM_DonePrintingSelectedMedia:

	;------------------------
	;Print the operation mode
	;------------------------
	cmp	Nic.SelectedOperationMode, NoOperationMode
	je	SHORT DSM_Exit				;If no Operation Mode - Skip printing

	;if Full Duplex -> Print FD message
        ;-----------------------------------
	test	Nic.SelectedOperationMode, ModeFULL_DUPLEX
	jz	SHORT DSM_DoneFDOM
	DataAddress	dx, WorkingWithFDMessage
	call	DisplayMessage              	
DSM_DoneFDOM:

	;if Ignore Link-Test -> Print ILT message
        ;----------------------------------------
	test	Nic.SelectedOperationMode, ModeLINK_DISABLE
	jz	SHORT DSM_DoneILTOM
	DataAddress	dx, WorkingWithILTMessage
	call	DisplayMessage              	
DSM_DoneILTOM:

	;If AS-Nway -> Print AS message
        ;------------------------------
	test	Nic.SelectedOperationMode, ModeNWAY or ModeAUTOSENSE
	jz	SHORT DSM_DoneAsNwayOM
	DataAddress	dx, WorkingWithAutosenseMessage
	call	DisplayMessage              	
DSM_DoneAsNwayOM:

	;------------------
	;Move to a new line
        ;------------------
	DataAddress	dx, NewLineLineFeedMessage
	call	DisplayMessage

DSM_Exit:
	clc
	
	pop	bx
	ret

DisplaySelectedMedia	endp

IF NOS EQ NDIS2
IF OS EQ DOS
END_CODE_SEGMENT_BIND		; DOS - NDIS2
ELSE
END_CODE_SEGMENT_INIT		; OS/2 - NDIS2
ENDIF
ELSE
END_CODE_SEGMENT_INIT		; ODI		
ENDIF



;-----------------;
; Sanity checking ;
;-----------------;

;OS type checking
;----------------
IF OS EQ DOS
	%OUT DC_INIT.ASM Compiling for DOS.
ELSEIF OS EQ OS2
	%OUT DC_INIT.ASM Compiling for OS2.
ELSE
	.ERR
	%OUT DC_INIT.ASM Illegal OS value.
ENDIF

;NOS type checking
;-----------------
IF NOS EQ ODI
	%OUT DC_INIT.ASM Compiling for ODI.
ELSEIF NOS EQ NDIS2
	%OUT DC_INIT.ASM Compiling for NDIS2.
ELSE
	.ERR
	%OUT DC_INIT.ASM Illegal NOS value.
ENDIF



END
