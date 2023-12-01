;***************************************************************************
;*
;*    Copyright (c) 1996
;*    by Digital Equipment Corporation, Maynard, Mass.
;*    All Rights Reserved.
;*
;*    This software is furnished under a license and may be used and  copied
;*    only  in  accordance  with  the  terms  of  such  license and with the
;*    inclusion of the above copyright notice.  This software or  any  other
;*    copies  thereof may not be provided or otherwise made available to any
;*    other person.  No title to and ownership of  the  software  is  hereby
;*    transferred.
;*
;*    The information in this software is subject to change  without  notice
;*    and  should  not  be  construed  as  a commitment by Digital Equipment
;*    Corporation.
;*
;*    Digital assumes no responsibility for the use or  reliability  of  its
;*    software on equipment which is not supplied by Digital.
;*
;***************************************************************************
;
; This module contains the definitions for the external symbols needed by
; the  MACDATA.ASM module, and the public definitions that it exports.
;
; Maintainers:
;	de	Dror Efraty
;
; Modification History:
;
; By              Date        Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; de		  25-Nov-1996 2.50  Initial Version
;*******************************************************************************
.8086		; This must apear in the beginning of each .ash file,
		; for the compiler to understand NEAR exteanals as 16 bits.
;----------------------------------------------------------------------------
;	Variables exported by MACDATA
;----------------------------------------------------------------------------
        ;SROM Parsing messages
        ;---------------------
       PUBLIC UnableToLocateROM
       PUBLIC SROM_ReadFailed
       PUBLIC UnsupportedSROMVersion
       PUBLIC UnsupportedDC21X4SROMVersion

	; Print messages for Working with DC21X4 Device
	;----------------------------------------------
	PUBLIC	WorkingWith21040_Message
	PUBLIC	WorkingWith21041_Message
	PUBLIC	WorkingWith21140and21140A_Message
	PUBLIC	WorkingWith21142and21143_Message
IFDEF PHYER
	PUBLIC	WorkingWith21144_Message
ENDIF

        ;Print messages for AutoDetection and media selection
        ;----------------------------------------------------
        PUBLIC  AutoDetectionMessage
        PUBLIC  SwitchingToMessage
        PUBLIC  SwitchingToUTPMessage
        PUBLIC  SwitchingToBNCMessage
        PUBLIC  SwitchingToAUIMessage
        PUBLIC  SwitchingToSymScrMessage
        PUBLIC  SwitchingToT4Message
        PUBLIC  SwitchingToFxMessage
        PUBLIC  SwitchingBetweenTpSymScr
        PUBLIC  PerformingMiiPhyAutodetect
        PUBLIC  StartingNwayMessage
	PUBLIC	NoMediumFound

	;Selected Media messages
	;-----------------------
	PUBLIC	WorkingWithMediaMessage
	PUBLIC	MediaTypeMessage
	PUBLIC	WorkingWithFDMessage
	PUBLIC	WorkingWithILTMessage
	PUBLIC	WorkingWithAutosenseMessage
	PUBLIC	MediaUnknownMessage
	PUBLIC	NewLineLineFeedMessage

	;Media selection Error messages
        ;------------------------------
        PUBLIC  MediaNotSupportedErr
        PUBLIC  MediaNotFoundErr
        PUBLIC  MediaUnknownMessage

 ;syssrvcs messages
 ;-----------------


public  AllocateMemoryError
public  VDSLockMemoryError
public  NotA386MachineErr
public  SlotValueErr
public  BoardNotFoundErr
public  UnknownBusErr
public  BadDeviceCFIDVal
public  UnsupportedDeviceRevision
public  DeviceIsDisabled
public  NoPciBIOSErr
public  PCIBIOSBadStatusErr
public  PCIBIOSBadRegErr
public  PCIBIOSBadCBIOErr
public  BadInterruptAllocation
public  HPE_PCIWarn
public  HPE_PCIErr
public  CRCTableErr
public  OS2PhysToGDTFailed
public  WACB_PCIErr
public  ModifyingPBLMsg
public  WACB_WarnCacheInWBMode
public  WACB_ModifyingTxTHR


	;Compile Error Messages
	;----------------------
	PUBLIC ErrorRoutineMessage

;
; The PIC variables control access to the PIC chip. The PIC chip handles the
; delivery of hardware interrupts to the CUP in an Intel based PC AT/XT. The
; IRQ of the adapter is determined at init time, in the InitGetAdapterConfig
; function in the module MACINIT.ASM
;	PUBLIC PICIntOff, PICIntOn, PICIntMask, PICAckSlave

                public  NDISCommonChar

                public  NDISServiceSpecificChar

                public  NDISServiceStatus

                public  NDISMediaSpecificStatus

  if 0
                public  NDISMACUpperDispatch

                public  NDISProtLowerDispatch
                public  RequestConfirm, TransmitConfirm, ReceiveLookahead
                public  IndicationComplete, ReceiveChain, StatusIndication

                public ProtDS
  endif

IF OS EQ OS2
                public devhlp
                public RxGDTSelector, XmtGDTSelector
ENDIF

		PUBLIC p_PhysBlockVirt, p_PhysBlockPhys, PhysBlockSize

;***************************************************************************

;----------------------------------------------------------------------------
;	Functions provided by MACRCV
;----------------------------------------------------------------------------
EXTRN RcvNDISTransferData:FAR
EXTRN RcvNDISReceiveRelease:FAR
EXTRN RcvNDISIndicationOn:FAR
EXTRN RcvNDISIndicationOff:FAR


;----------------------------------------------------------------------------
;	Functions provided by MACREQ
;----------------------------------------------------------------------------
;EXTRN SysReqDispatch:FAR
;EXTRN GenReqDispatch:FAR


;----------------------------------------------------------------------------
;	Functions provided by MACXMT
;----------------------------------------------------------------------------

