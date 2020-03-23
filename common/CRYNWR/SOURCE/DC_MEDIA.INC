;*******************************************************************************
;
; DC_Media.INC
;
; Include file for Dec Fast Ethernet board that holds information
; and supporting routines for its Non MII media .
;
; Limitations:
;
; Written by:   Moti Haimovsky
; Date:         09-May-1996
;
;
; Copyright (C) 1994 by Digital Equipment Corporation
; All rights reserved.
;
; Modification History:
;
;  By              Date        Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; Moti Haimovsky   16/Jun/96   2.40 - Modified SetCSR6ToPointedMedium to modify CSR6 value
;				      in 3 steps.
; Moti Haimovsky   17/Jun/96        - Added GetMediumCapabilities routine
;				    - Modified WriteInternalPhyRegs not to write CSR13 value
;				      if its 0.
; Adi Shaliv       20-Aug-1996      - Add Chacking if we use MULTIA board and loading the
;                                     proper values for this board BNC CSR13,14,15 to
;                                     NICstruct.      (In DcMediaInitTulip procedure )
; Moti Haimovsky   20/Aug/96  2.41  - Moved the SetGepToPointedMedium routine to be the first
;                                     routine to be called in SetMedia.
; Moti Haimovsky  08-Nov-1996  2.50 - Added Phyer preliminary support
; Moti Haimovsky  19-Nov-1996	    - Modified Tulip3 csr6 writing routine from WriteCSR6Tulip
;				      to WriteCSR6Reg.
; Moti Haimovsky  05-Jan-1997  2.51 - Modified Fnet3 and Twinet Default parameters (Drivers' unification).
; Moti Haimovsky  17-Feb-1997  2.60 - MULTIA indication is now in NIC and ODI uses it too.
; Motti Daniel    12-Oct-1997  2.61 - Change in MSelectPointedMediumTwinetMiiSym
;				      to keep eax register value while reading CSR6. 
;*******************************************************************************
;******************************************************************************
;	      		 DC_MEDIA   EXTERNAL   ROUTINES
;******************************************************************************

START_CODE_SEGMENT_INIT

;****************************************************************************
;
; SetDeviceDefaultParameters
;
; Sets the device dependent default parameters
; especially the initial value of the SIA registers and the presence or absence
; of media in the Nic.
; This routine assumes the WORSE case of rom presence, meaning:
;		IEEE address rom for Tulip
;		SROM with Legacy format for Tulip3 & FasterNet
;
; This routine is called from DriverInit in init time.
;
; Assumes:
;	ds=es=cs CGroup
;       Interrupts are enabled.
;       Nic structure has been initialized according to the device found
;
; Input values:
;       NICSlot   - The EISA slot# in which Tulip was found.
;
; Output values:
;       IOAddress1 -  according to the NICSlot found.
;       IORange1
;
;	Tulip registers addresses.
;	All registes preserved.
;
; Return values:
;        NONE
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SetDeviceDefaultParameters	proc

	push	bx
        push	cx

	;-----------------------
	;Reset all media entries
	;-----------------------
	mov	cx, MAX_MEDIA_TABLE - 1
SDDP_InitEntry:
	mov	bx, cx
	GetMediaEntry	bx, bx
	mov	Nic.media[bx].MediaPresence, Absent       			;Media - Absent
	mov	Nic.media[bx].CSR6_OM, 0           				;OM Reg
	mov	Nic.media[bx].Gep.SequenceCount, 0 				;GEP sequence
	mov	Nic.media[bx].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID   ;External link sense
	mov	Nic.media[bx].InternalLinkSense.InternalSensePresence, Absent   ;Internal Link sense
	mov	Nic.media[bx].MediumInternalRegs.RegsPresence, Absent           ;Internal Phy regs

	;Medium routines init
        ;--------------------
	mov	Nic.Media[bx].MediumRoutines.MInit,		offset CGroup:ErrorRoutine
	mov	Nic.Media[bx].MediumRoutines.MParse,		offset CGroup:ErrorRoutine
	mov	Nic.Media[bx].MediumRoutines.MGetCapabilities,	offset CGroup:ErrorRoutine
	mov	Nic.Media[bx].MediumRoutines.MSelectMedium,	offset CGroup:ErrorRoutine
	mov	Nic.Media[bx].MediumRoutines.MGetLinkStatus,	offset CGroup:ErrorRoutine

	dec	cx
	jge	SDDP_InitEntry

	;--------------------------------------
	;Go to set default parameters according
	;to the device found on Nic
        ;--------------------------------------
	cmp	Nic.Dev, TULIP
	je	SHORT SDDP_Tulip
	cmp	Nic.Dev, TULIP3
	je	SDDP_Tulip3
	cmp	Nic.Dev, FASTERNET
	je	SDDP_FasterNet
	cmp	Nic.Dev, TWINET
	je	SDDP_TwiNet

	pop	cx
        pop	bx
	stc                             ;If reached this point - Unknown device
	ret

SDDP_Tulip:
	call	SetTulipDefaultParameters
	jmp	SHORT SDDP_Exit

SDDP_Tulip3:
	call	SetTulip3DefaultParameters
	jmp	SHORT SDDP_Exit

SDDP_FasterNet:
	call	SetFasternetDefaultParameters
	jmp	SHORT SDDP_Exit

SDDP_TwiNet:
	call	SetTwinetDefaultParameters
	jmp	SHORT SDDP_Exit


SDDP_Exit:
	clc
	pop	cx
        pop	bx
	ret

SetDeviceDefaultParameters	endp

;****************************************************************************
;
; SetTulipDefaultParameters
;
; Sets Tulip dependent default parameters
; especially the initial value of the SIA registers and the presence or absence
; of media in the Nic.
;
; This routine is called from DriverInit in init time.
;
; Assumes:
;	ds=es=cs CGroup
;       Interrupts are enabled.
;       Nic structure has been initialized according to the device found
;
;
; Return values:
;        NONE
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SetTulipDefaultParameters	proc

	;Set Tulip default parameters
        ;----------------------------

	;---------------------------------
	;Set Default connection parameters
        ;---------------------------------
	mov	Nic.SelectedConnectionType, ConnectionAutoDetect
	mov	Nic.AutoSenseCapable, NOT AUTOSENSE_CAPABLE

	;---------------------------
	;Set chip dependent routines
        ;---------------------------
	mov	Nic.WriteGepRegister, offset CGroup:NullRoutine
	mov	Nic.ReadGepRegister,  offset CGroup:NullRoutine
	mov	Nic.WriteCSR6, 	      offset CGroup:WriteCSR6Tulip

	;-------------------------------
	;Set Chip OM register parameters
        ;-------------------------------
	mov	Nic.Shadow_CSR6, TULIP_CSR6_DEFAULT
	mov	Nic.CSR6_OM_MaskOFF, NOT (DWORD PTR CSR6_FD)
	mov	Nic.CSR8_MaskOFF, DWORD PTR CSR8_MASK_MISSED_FRAMES

	;-------------------------
	;Set chip media parameters
	;-------------------------
	call	DcMediaInit


	ret

SetTulipDefaultParameters	endp

;****************************************************************************
;
; SetTulip3DefaultParameters
;
; Sets Tulip3 dependent default parameters
; especially the initial value of the SIA registers and the presence or absence
; of media in the Nic.
;
; This routine is called from DriverInit in init time.
;
; Assumes:
;	ds=es=cs CGroup
;       Interrupts are enabled.
;       Nic structure has been initialized according to the device found
;
;
; Return values:
;        NONE
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SetTulip3DefaultParameters	proc

	;Set Tulip3 default parameters
        ;-----------------------------

	;---------------------------------
	;Set Default connection parameters
        ;---------------------------------
	mov	Nic.SelectedConnectionType, ConnectionAutoSense
	mov	Nic.AutoSenseCapable, AUTOSENSE_CAPABLE

	;---------------------------
	;Set chip dependent routines
        ;---------------------------
	mov	Nic.WriteGepRegister, offset CGroup:NullRoutine
	mov	Nic.ReadGepRegister,  offset CGroup:NullRoutine
	mov	Nic.WriteCSR6, 	      offset CGroup:WriteCSR6Reg

	;-------------------------------
	;Set Chip OM register parameters
        ;-------------------------------
	mov	Nic.Shadow_CSR6, TULIP3_CSR6_DEFAULT
	mov	Nic.CSR6_OM_MaskOFF, NOT (DWORD PTR CSR6_FD)
	mov	Nic.CSR8_MaskOFF, DWORD PTR CSR8_MASK_MISSED_FRAMES

	;-------------------------
	;Set chip media parameters
	;-------------------------
	Call	DcMediaInit

	ret

SetTulip3DefaultParameters	endp

;****************************************************************************
;
; SetFasternetDefaultParameters
;
; Sets Tulip dependent default parameters
; especially the initial value of the SIA registers and the presence or absence
; of media in the Nic.
;
; This routine is called from DriverInit in init time.
;
; Assumes:
;	ds=es=cs CGroup
;       Interrupts are enabled.
;       Nic structure has been initialized according to the device found
;
;
; Return values:
;        NONE
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SetFasternetDefaultParameters	proc

	;Set FasterNet default parameters
	;--------------------------------

	;---------------------------------
	;Set Default connection parameters
        ;---------------------------------
	mov	Nic.SelectedConnectionType, NoSelectedConnection
	mov	Nic.AutoSenseCapable, NOT AUTOSENSE_CAPABLE
	mov	Nic.DefaultMedia, NoSelectedMedia
	mov	Nic.MediaPrecedence.NumMedia, 0  		;No autosensable Medis

	;---------------------------
	;Set chip dependent routines
        ;---------------------------
	mov	Nic.WriteGepRegister, offset CGroup:WriteGepRegisterFnet
	mov	Nic.ReadGepRegister,  offset CGroup:ReadGepRegisterFnet
	mov	Nic.WriteCSR6, 	      offset CGroup:WriteCSR6Reg

	;-------------------------------
	;Set Chip OM register parameters
        ;-------------------------------
	mov	Nic.Shadow_CSR6, FasterNet_CSR6_DEFAULT
	mov	Nic.CSR6_OM_MaskOFF, NOT DWORD PTR ((CSR6_PORT_SPEED_SELECTION_MASK or CSR6_FD ))

	mov	Nic.CSR8_MaskOFF, DWORD PTR CSR8_MASK_MISSED_FRAMES
	cmp	Nic.Rev, CFRV_REV2
	jl	SHORT SFDP_DoneUpdatingCSR8
	or	Nic.CSR8_MaskOFF, DWORD PTR CSR8_MASK_RX_OVERFLOW 	;Fasternet3 has RxFifo Oveflow counter in CSR8
SFDP_DoneUpdatingCSR8:

	;--------------------------------
	;Set chip Work-around Indications
	;--------------------------------
	;---------------------------------------------------------
	;Fasternet chips that have the RX fifo hang are F3 Family:
	;---------------------------------------------------------
	cmp	Nic.rev, CFRV_REV2
	jl	SHORT SFDP_DoneWithHangIndication

	;HangMayHappen
        ;-------------
	mov	Nic.RxFifoHangPresence, Present
SFDP_DoneWithHangIndication:

	;-------------------------
	;Set chip media parameters
	;-------------------------
	call	DcMediaInit

	ret

SetFasternetDefaultParameters	endp

;****************************************************************************
;
; SetTwinetDefaultParameters
;
; Sets Tulip dependent default parameters
; especially the initial value of the SIA registers and the presence or absence
; of media in the Nic.
;
; This routine is called from DriverInit in init time.
;
; Assumes:
;	ds=es=cs CGroup
;       Interrupts are enabled.
;       Nic structure has been initialized according to the device found
;
;
; Return values:
;        NONE
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SetTwinetDefaultParameters	proc

	;Set TwiNet default parameters
	;-----------------------------

	;---------------------------------
	;Set Default connection parameters
        ;---------------------------------
	mov	Nic.SelectedConnectionType, ConnectionAutoSense
	mov	Nic.AutoSenseCapable, AUTOSENSE_CAPABLE

	;---------------------------
	;Set chip dependent routines
        ;---------------------------
	mov	Nic.WriteGepRegister, offset CGroup:WriteGepRegisterTwinet
	mov	Nic.ReadGepRegister,  offset CGroup:ReadGepRegisterTwinet
	mov	Nic.WriteCSR6, 	      offset CGroup:WriteCSR6Reg

	;-------------------------------
	;Set Chip OM register parameters
        ;-------------------------------
	mov	Nic.Shadow_CSR6, TWINET_CSR6_DEFAULT
	mov	Nic.CSR6_OM_MaskOFF, (NOT DWORD PTR (CSR6_PORT_SPEED_SELECTION_MASK or CSR6_FD ) )

	mov	Nic.CSR8_MaskOFF, DWORD PTR (CSR8_MASK_MISSED_FRAMES or CSR8_MASK_RX_OVERFLOW)

	;--------------------------------
	;Set chip Work-around Indications
	;--------------------------------
	;-----------------------------------------------
	;Twinet Family of chips may have RX fifo hang
	;-----------------------------------------------
	;Hang May Happen
	;---------------
	mov	Nic.RxFifoHangPresence, Present
STwDP_DoneWithHangIndication:

	;-------------------------
	;Set chip media parameters
	;-------------------------
	call	DcMediaInit

	ret

SetTwinetDefaultParameters	endp


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          DcMediaInit	Proc
;
;
;
; Description:
; On Entry:
;              Nic.Dev&Rev is initialized
;
; On Return:
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DcMediaInit	proc

	;-----------------------------------------
	;Init DC media according to Dec chip found
        ;-----------------------------------------
	;Tulip
        ;-----
	cmp	Nic.Dev, TULIP
	jne	SHORT DMI_NotTulip
	call	DcMediaInitTulip
	jmp	SHORT DMI_Exit
DMI_NotTulip:

	;Tulip3
        ;------
	cmp	Nic.Dev, TULIP3
	jne	SHORT DMI_NotTulip3
	call	DcMediaInitTulip3
	jmp	SHORT DMI_Exit
DMI_NotTulip3:

	;Fasternet
        ;---------
	cmp	Nic.Dev, FASTERNET
	jne	SHORT DMI_NotFasterNet
	call	DcMediaInitFasterNet
	jmp	SHORT DMI_Exit
DMI_NotFasterNet:

	;Twinet
        ;------
	cmp	Nic.Dev, TWINET
	jne	SHORT DMI_NotTwiNet
	call	DcMediaInitTwinet
	jmp	SHORT DMI_Exit
DMI_NotTwiNet:


	stc

DMI_Exit:
	ret

DcMediaInit	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          DcMediaInitTulip	Proc
;
;
;
; Description:
; On Entry:
;              Nic.Dev&Rev is initialized
;
; On Return:
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DcMediaInitTulip	proc

	;-------------------------
	;Set chip media parameters
	;-------------------------
	;----------
	; Medium TP
        ;----------
	mov	Nic.media[TP].MediaPresence, Present

	;OM Reg
        ;------
	mov	Nic.media[TP].CSR6_OM, 0

	;GEP sequence
        ;------------
	mov	Nic.media[TP].Gep.SequenceCount, 0

	;External link sense
        ;-------------------
	mov	Nic.media[TP].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[TP].InternalLinkSense.InternalSensePresence, Present
	mov	Nic.media[TP].InternalLinkSense.InternalLinkSenseRoutine,\
					      offset CGroup:Tulip_GetLinkStatusTP

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[TP].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[TP].MediumInternalRegs.CSR13, CSR13_TP
	mov	Nic.media[TP].MediumInternalRegs.CSR14, CSR14_TP
	mov	Nic.media[TP].MediumInternalRegs.CSR15, CSR15_TP


	;Medium routines init
        ;--------------------
	mov	Nic.Media[TP].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[TP].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[TP].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[TP].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[TP].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus

	;-----------
	; Medium BNC
        ;-----------
	mov	Nic.media[BNC].MediaPresence, Present

	;OM Reg
        ;------
	mov	Nic.media[BNC].CSR6_OM, 0

	;GEP sequence
        ;------------
	mov	Nic.media[BNC].Gep.SequenceCount, 0

	;External link sense
        ;-------------------
	mov	Nic.media[BNC].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[BNC].InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[BNC].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[BNC].MediumInternalRegs.CSR13, CSR13_BNC
	mov	Nic.media[BNC].MediumInternalRegs.CSR14, CSR14_BNC
	mov	Nic.media[BNC].MediumInternalRegs.CSR15, CSR15_BNC

	; Check if it is MULTIA board. and load the proper values
	; to CSR13,14,15
	;---------------------------------------------------------
	cmp     Nic.PCType, MULTIA_PC
	je      DMIT_NotMultia

	mov	Nic.media[BNC].MediumInternalRegs.CSR13, MULTIA_CSR13_BNC
	mov	Nic.media[BNC].MediumInternalRegs.CSR14, MULTIA_CSR14_BNC
	mov	Nic.media[BNC].MediumInternalRegs.CSR15, MULTIA_CSR15_BNC
DMIT_NotMultia:

	;Medium routines init
        ;--------------------
	mov	Nic.Media[BNC].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[BNC].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[BNC].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[BNC].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[BNC].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus

	;-----------
	; Medium AUI
        ;-----------
	mov	Nic.media[AUI].MediaPresence, Present

	;OM Reg
        ;------
	mov	Nic.media[AUI].CSR6_OM, 0

	;GEP sequence
        ;------------
	mov	Nic.media[AUI].Gep.SequenceCount, 0

	;External link sense
        ;-------------------
	mov	Nic.media[AUI].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[AUI].InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[AUI].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[AUI].MediumInternalRegs.CSR13, CSR13_AUI
	mov	Nic.media[AUI].MediumInternalRegs.CSR14, CSR14_AUI
	mov	Nic.media[AUI].MediumInternalRegs.CSR15, CSR15_AUI

	;Medium routines init
        ;--------------------
	mov	Nic.Media[AUI].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[AUI].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[AUI].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[AUI].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[AUI].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus

	;---------------------
	; Medium TP FullDuplex
        ;---------------------
	mov	Nic.media[TPFD].MediaPresence, Present

	;OM Reg
        ;------
	mov	Nic.media[TPFD].CSR6_OM, CSR6_FD

	;GEP sequence
        ;------------
	mov	Nic.media[TPFD].Gep.SequenceCount, 0

	;External link sense
        ;-------------------
	mov	Nic.media[TPFD].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[TpFD].InternalLinkSense.InternalSensePresence, Present
	mov	Nic.media[TpFD].InternalLinkSense.InternalLinkSenseRoutine,\
					      offset CGroup:Tulip_GetLinkStatusTP

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[TPFD].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[TpFD].MediumInternalRegs.CSR13, CSR13_TP_FD
	mov	Nic.media[TpFD].MediumInternalRegs.CSR14, CSR14_TP_FD
	mov	Nic.media[TpFD].MediumInternalRegs.CSR15, CSR15_TP_FD

	;Medium routines init
        ;--------------------
	mov	Nic.Media[TpFD].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[TpFD].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[TpFD].MediumRoutines.MGetCapabilities,offset CGroup:NullRoutine
	mov	Nic.Media[TpFD].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[TpFD].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus

	ret

DcMediaInitTulip	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          DcMediaInitTulip3	Proc
;
;
;
; Description:
; On Entry:
;              Nic.Dev&Rev is initialized
;
; On Return:
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DcMediaInitTulip3	proc

	;-------------------------
	;Set chip media parameters
	;-------------------------
	;----------
	; Medium TP
	;----------
	mov	Nic.media[TP].MediaPresence, Absent

	;OM Reg
	;------
	mov	Nic.media[TP].CSR6_OM, 0

	;GEP sequence
	;------------
	mov	Nic.media[TP].Gep.SequenceCount, 0

	;External link sense
	;-------------------
	mov	Nic.media[TP].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
	;-------------------
	mov	Nic.media[TP].InternalLinkSense.InternalSensePresence, Present
	mov	Nic.media[TP].InternalLinkSense.InternalLinkSenseRoutine,\
					      offset CGroup:Tulip_GetLinkStatusTP
	;Internal Phy regs
	;-----------------
	mov	Nic.media[TP].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[TP].MediumInternalRegs.CSR13, TULIP3_CSR13_TP_DEFAULT
	mov	Nic.media[TP].MediumInternalRegs.CSR14, TULIP3_CSR14_TP_DEFAULT
	mov	Nic.media[TP].MediumInternalRegs.CSR15, TULIP3_CSR15_TP_DEFAULT

	;Medium routines init
        ;--------------------
	mov	Nic.Media[TP].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[TP].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[TP].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[TP].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[TP].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	;-----------
	; Medium BNC
        ;-----------
	mov	Nic.media[BNC].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[BNC].CSR6_OM, 0

	;GEP sequence
        ;------------
	mov	Nic.media[BNC].Gep.SequenceCount, 0

	;External link sense
        ;-------------------
	mov	Nic.media[BNC].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[BNC].InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[BNC].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[BNC].MediumInternalRegs.CSR13, TULIP3_CSR13_BNC_DEFAULT
	mov	Nic.media[BNC].MediumInternalRegs.CSR14, TULIP3_CSR14_BNC_DEFAULT
	mov	Nic.media[BNC].MediumInternalRegs.CSR15, TULIP3_CSR15_BNC_DEFAULT

	;Medium routines init
        ;--------------------
	mov	Nic.Media[BNC].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[BNC].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[BNC].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[BNC].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[BNC].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	;-----------
	; Medium AUI
        ;-----------
	mov	Nic.media[AUI].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[AUI].CSR6_OM, 0

	;GEP sequence
        ;------------
	mov	Nic.media[AUI].Gep.SequenceCount, 0

	;External link sense
        ;-------------------
	mov	Nic.media[AUI].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[AUI].InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[AUI].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[AUI].MediumInternalRegs.CSR13, TULIP3_CSR13_AUI_DEFAULT
	mov	Nic.media[AUI].MediumInternalRegs.CSR14, TULIP3_CSR14_AUI_DEFAULT
	mov	Nic.media[AUI].MediumInternalRegs.CSR15, TULIP3_CSR15_AUI_DEFAULT

	;Medium routines init
        ;--------------------
	mov	Nic.Media[AUI].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[AUI].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[AUI].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[AUI].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[AUI].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus

	;---------------------
	; Medium TP FullDuplex
        ;---------------------
	mov	Nic.media[TPFD].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[TPFD].CSR6_OM, CSR6_FD

	;GEP sequence
        ;------------
	mov	Nic.media[TPFD].Gep.SequenceCount, 0

	;External link sense
        ;-------------------
	mov	Nic.media[TPFD].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[TpFD].InternalLinkSense.InternalSensePresence, Present
	mov	Nic.media[TpFD].InternalLinkSense.InternalLinkSenseRoutine,\
					      offset CGroup:Tulip_GetLinkStatusTP

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[TPFD].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[TpFD].MediumInternalRegs.CSR13, TULIP3_CSR13_TPFD_DEFAULT
	mov	Nic.media[TpFD].MediumInternalRegs.CSR14, TULIP3_CSR14_TPFD_DEFAULT
	mov	Nic.media[TpFD].MediumInternalRegs.CSR15, TULIP3_CSR15_TPFD_DEFAULT

	;Medium routines init
        ;--------------------
	mov	Nic.Media[TpFD].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[TpFD].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[TpFD].MediumRoutines.MGetCapabilities,offset CGroup:NullRoutine
	mov	Nic.Media[TpFD].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[TpFD].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus

	ret

DcMediaInitTulip3	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          DcMediaInitFasternet	Proc
;
;
;
; Description:
; On Entry:
;              Nic.Dev&Rev is initialized
;
; On Return:
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DcMediaInitFasternet	proc


	;-------------------------
	;Set chip media parameters
	;-------------------------

	;----------
	; Medium TP
        ;----------
	mov	Nic.media[TP].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[TP].CSR6_OM, CSR6_SIA_10M

	;GEP sequence
        ;------------
	mov	Nic.media[TP].Gep.SequenceCount, 2
	mov	Nic.Media[TP].Gep.SequenceData[Gep_Control], GPR_InitValue
	mov	Nic.Media[TP].Gep.SequenceData[Gep_Data],    EXTERNAL_POINT_TO_POINT

	;External link sense
        ;-------------------
	mov	Nic.media[TP].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[TP].InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
	;-----------------
	mov	Nic.media[TP].MediumInternalRegs.RegsPresence, Absent

	;Medium routines init
        ;--------------------
	mov	Nic.Media[TP].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[TP].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[TP].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[TP].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[TP].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	;-----------
	; Medium BNC
        ;-----------
	mov	Nic.media[BNC].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[BNC].CSR6_OM, CSR6_SIA_10M

	;GEP sequence
        ;------------
	mov	Nic.media[BNC].Gep.SequenceCount, 2
	mov	Nic.Media[BNC].Gep.SequenceData[Gep_Control], GPR_InitValue
	mov	Nic.Media[BNC].Gep.SequenceData[Gep_Data],    EXTERNAL_POINT_TO_POINT

	;External link sense
        ;-------------------
	mov	Nic.media[BNC].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[BNC].InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[BNC].MediumInternalRegs.RegsPresence, Absent

	;Medium routines init
        ;--------------------
	mov	Nic.Media[BNC].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[BNC].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[BNC].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[BNC].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[BNC].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus

	;-----------
	; Medium AUI
        ;-----------
	mov	Nic.media[AUI].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[AUI].CSR6_OM, CSR6_SIA_10M

	;GEP sequence
        ;------------
	mov	Nic.media[AUI].Gep.SequenceCount, 2
	mov	Nic.Media[AUI].Gep.SequenceData[Gep_Control], GPR_InitValue
	mov	Nic.Media[AUI].Gep.SequenceData[Gep_Data],    EXTERNAL_POINT_TO_POINT

	;External link sense
        ;-------------------
	mov	Nic.media[AUI].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[AUI].InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[AUI].MediumInternalRegs.RegsPresence, Absent

	;Medium routines init
        ;--------------------
	mov	Nic.Media[AUI].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[AUI].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[AUI].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[AUI].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[AUI].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	;---------------------
	; Medium TP FullDuplex
        ;---------------------
	mov	Nic.media[TPFD].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[TPFD].CSR6_OM, CSR6_SIA_10M or CSR6_FD

	;GEP sequence
        ;------------
	mov	Nic.media[TPFD].Gep.SequenceCount, 2
	mov	Nic.Media[TPFD].Gep.SequenceData[Gep_Control], GPR_InitValue
	mov	Nic.Media[TPFD].Gep.SequenceData[Gep_Data],    EXTERNAL_POINT_TO_POINT_TpFD

	;External link sense
        ;-------------------
	mov	Nic.media[TPFD].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[TpFD].InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[TPFD].MediumInternalRegs.RegsPresence, Absent

	;Medium routines init
        ;--------------------
	mov	Nic.Media[TpFD].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[TpFD].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[TpFD].MediumRoutines.MGetCapabilities,offset CGroup:NullRoutine
	mov	Nic.Media[TpFD].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[TpFD].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	;--------------
	; Medium SymScr
        ;--------------
	mov	Nic.media[SymScr].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[SymScr].CSR6_OM, CSR6_SYM_SCR_100M

	;GEP sequence
        ;------------
	mov	Nic.media[SymScr].Gep.SequenceCount, 2
	mov	Nic.Media[SymScr].Gep.SequenceData[Gep_Control], GPR_InitValue
	mov	Nic.Media[SymScr].Gep.SequenceData[Gep_Data],    EXTERNAL_POINT_TO_POINT_SymScr

	;External link sense
        ;-------------------
	mov	Nic.media[SymScr].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[SymScr].MediumInternalRegs.RegsPresence, Absent

	;Medium routines init
        ;--------------------
	mov	Nic.Media[SymScr].MediumRoutines.MInit,			offset CGroup:NullRoutine
	mov	Nic.Media[SymScr].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[SymScr].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[SymScr].MediumRoutines.MSelectMedium,		offset CGroup:MSelectPointedMedium
	mov	Nic.Media[SymScr].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	;--------------------------
	; Medium SymScr FullDuplex
        ;-------------------------
	mov	Nic.media[SymScrFD].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[SymScrFD].CSR6_OM, CSR6_SYM_SCR_100M or CSR6_FD

	;GEP sequence
        ;------------
	mov	Nic.media[SymScrFD].Gep.SequenceCount, 2
	mov	Nic.Media[SymScrFD].Gep.SequenceData[Gep_Control], GPR_InitValue
	mov	Nic.Media[SymScrFD].Gep.SequenceData[Gep_Data],    EXTERNAL_POINT_TO_POINT_SymScrFD

	;External link sense
        ;-------------------
	mov	Nic.media[SymScrFD].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[SymScrFD].InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[SymScrFD].MediumInternalRegs.RegsPresence, Absent

	;Medium routines init
        ;--------------------
	mov	Nic.Media[SymScrFD].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[SymScrFD].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[SymScrFD].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[SymScrFD].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[SymScrFD].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	;------------------
	; Medium 100BaseT4
        ;------------------
	mov	Nic.media[BaseT4].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[BaseT4].CSR6_OM, CSR6_SYM_100M

	;GEP sequence
        ;------------
	mov	Nic.media[BaseT4].Gep.SequenceCount, 2
	mov	Nic.Media[BaseT4].Gep.SequenceData[Gep_Control], GPR_InitValue
	mov	Nic.Media[BaseT4].Gep.SequenceData[Gep_Data],    EXTERNAL_POINT_TO_POINT_SymScr

	;External link sense
        ;-------------------
	mov	Nic.media[BaseT4].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[BaseT4].MediumInternalRegs.RegsPresence, Absent

	;Medium routines init
        ;--------------------
	mov	Nic.Media[BaseT4].MediumRoutines.MInit,			offset CGroup:NullRoutine
	mov	Nic.Media[BaseT4].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[BaseT4].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[BaseT4].MediumRoutines.MSelectMedium,		offset CGroup:MSelectPointedMedium
	mov	Nic.Media[BaseT4].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus



	;------------------
	; Medium 100BaseFX
        ;------------------
	mov	Nic.media[BaseFx].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[BaseFx].CSR6_OM, CSR6_SYM_100M

	;GEP sequence
        ;------------
	mov	Nic.media[BaseFx].Gep.SequenceCount, 2
	mov	Nic.Media[BaseFx].Gep.SequenceData[Gep_Control], GPR_InitValue
	mov	Nic.Media[BaseFx].Gep.SequenceData[Gep_Data],    EXTERNAL_POINT_TO_POINT_SymScr

	;External link sense
        ;-------------------
	mov	Nic.media[BaseFx].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[BaseFx].InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[BaseFx].MediumInternalRegs.RegsPresence, Absent

	;Medium routines init
        ;--------------------
	mov	Nic.Media[BaseFx].MediumRoutines.MInit,			offset CGroup:NullRoutine
	mov	Nic.Media[BaseFx].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[BaseFx].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[BaseFx].MediumRoutines.MSelectMedium,		offset CGroup:MSelectPointedMedium
	mov	Nic.Media[BaseFx].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	;----------------------------
	; Medium 100BaseFX FullDuplex
        ;----------------------------
	mov	Nic.media[BaseFxFD].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[BaseFxFD].CSR6_OM, CSR6_SYM_100M or CSR6_FD

	;GEP sequence
	;------------
	mov	Nic.media[BaseFxFD].Gep.SequenceCount, 2
	mov	Nic.Media[BaseFxFD].Gep.SequenceData[Gep_Control], GPR_InitValue
	mov	Nic.Media[BaseFxFD].Gep.SequenceData[Gep_Data],    EXTERNAL_POINT_TO_POINT_SymScrFD

	;External link sense
	;-------------------
	mov	Nic.media[BaseFxFD].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[BaseFxFD].InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
	;-----------------
	mov	Nic.media[BaseFxFD].MediumInternalRegs.RegsPresence, Absent

	;Medium routines init
        ;--------------------
	mov	Nic.Media[BaseFxFD].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[BaseFxFD].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[BaseFxFD].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[BaseFxFD].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[BaseFxFD].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	;--------
	; Mii PHY
	;--------

	;OM Reg
        ;------
	mov	Nic.MiiPhysList[0].MacEntry.CSR6_OM, CSR6_MII

	;External link sense
        ;-------------------
	mov	Nic.MiiPhysList[0].MacEntry.ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.MiiPhysList[0].MacEntry.InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
	;-----------------
	mov	Nic.MiiPhysList[0].MacEntry.MediumInternalRegs.RegsPresence, Absent

	;Medium routines init
        ;--------------------
	mov	Nic.MiiPhysList[0].MacEntry.MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.MiiPhysList[0].MacEntry.MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.MiiPhysList[0].MacEntry.MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.MiiPhysList[0].MacEntry.MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.MiiPhysList[0].MacEntry.MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	ret

DcMediaInitFasternet	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          DcMediaInitTwinet	Proc
;
;
;
; Description:
; On Entry:
;              Nic.Dev&Rev is initialized
;
; On Return:
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DcMediaInitTwinet	proc

	;----------
	; Medium TP
        ;----------
	mov	Nic.media[TP].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[TP].CSR6_OM, CSR6_SIA_10M

	;GEP sequence
        ;------------
	mov	Nic.media[TP].Gep.SequenceCount, 2
	mov	Nic.Media[TP].Gep.SequenceData[Gep_Control], TWINET_GPR_InitValue
	mov	Nic.Media[TP].Gep.SequenceData[Gep_Data],    TWINET_GPR_DataValue

	;External link sense
        ;-------------------
	mov	Nic.media[TP].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
	;-------------------
	mov	Nic.media[TP].InternalLinkSense.InternalSensePresence, Present

	;Twinet1 has internal link sense of TP links as in tulip
        ;-------------------------------------------------------
	mov	Nic.media[TP].InternalLinkSense.InternalLinkSenseRoutine,\
		    			      offset CGroup:Tulip_GetLinkStatusTP

	;Twinet2 and above have a different internal link sense of TP
        ;------------------------------------------------------------
	cmp	Nic.rev, CFRV_REV2
	jl	SHORT STwDP_DoneTwinet2LinkSenseTP
	mov	Nic.media[TP].InternalLinkSense.InternalLinkSenseRoutine,\
					      offset CGroup:Twinet2_GetLinkStatusTP
STwDP_DoneTwinet2LinkSenseTP:

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[TP].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[TP].MediumInternalRegs.CSR13, TWINET_CSR13_TP_DEFAULT
	mov	Nic.media[TP].MediumInternalRegs.CSR14, TWINET_CSR14_TP_DEFAULT
	mov	Nic.media[TP].MediumInternalRegs.CSR15, TWINET_CSR15_TP_DEFAULT

	;Twinet2 and above have different SIA values
	;-------------------------------------------
	cmp     Nic.rev, CFRV_REV2
	jl      SHORT STwDP_DoneTwinet2SIATP

	mov     Nic.media[TP].MediumInternalRegs.RegsPresence, Present
	mov     Nic.media[TP].MediumInternalRegs.CSR13, TWINET2_CSR13_TP_DEFAULT
	mov     Nic.media[TP].MediumInternalRegs.CSR14, TWINET2_CSR14_TP_DEFAULT
	mov     Nic.media[TP].MediumInternalRegs.CSR15, TWINET2_CSR15_TP_DEFAULT

STwDP_DoneTwinet2SIATP:
	;Medium routines init
        ;--------------------
	mov	Nic.Media[TP].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[TP].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[TP].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[TP].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[TP].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	;-----------
	; Medium BNC
        ;-----------
	mov	Nic.media[BNC].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[BNC].CSR6_OM, CSR6_SIA_10M

	;GEP sequence
        ;------------
	mov	Nic.media[BNC].Gep.SequenceCount, 2
	mov	Nic.Media[BNC].Gep.SequenceData[Gep_Control], TWINET_GPR_InitValue
	mov	Nic.Media[BNC].Gep.SequenceData[Gep_Data],    TWINET_GPR_DataValue

	;External link sense
        ;-------------------
	mov	Nic.media[BNC].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[BNC].InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[BNC].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[BNC].MediumInternalRegs.CSR13, TWINET_CSR13_BNC_DEFAULT
	mov	Nic.media[BNC].MediumInternalRegs.CSR14, TWINET_CSR14_BNC_DEFAULT
	mov	Nic.media[BNC].MediumInternalRegs.CSR15, TWINET_CSR15_BNC_DEFAULT

	;Twinet2 and above have different SIA values
	;-------------------------------------------
	cmp     Nic.rev, CFRV_REV2
	jl      SHORT STwDP_DoneTwinet2SIABNC

	mov     Nic.media[BNC].MediumInternalRegs.RegsPresence, Present
	mov     Nic.media[BNC].MediumInternalRegs.CSR13, TWINET2_CSR13_BNC_DEFAULT
	mov     Nic.media[BNC].MediumInternalRegs.CSR14, TWINET2_CSR14_BNC_DEFAULT
	mov     Nic.media[BNC].MediumInternalRegs.CSR15, TWINET2_CSR15_BNC_DEFAULT

STwDP_DoneTwinet2SIABNC:
	;Medium routines init
        ;--------------------
	mov	Nic.Media[BNC].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[BNC].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[BNC].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[BNC].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[BNC].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	;-----------
	; Medium AUI
        ;-----------
	mov	Nic.media[AUI].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[AUI].CSR6_OM, CSR6_SIA_10M

	;GEP sequence
        ;------------
	mov	Nic.media[AUI].Gep.SequenceCount, 2
	mov	Nic.Media[AUI].Gep.SequenceData[Gep_Control], TWINET_GPR_InitValue
	mov	Nic.Media[AUI].Gep.SequenceData[Gep_Data],    TWINET_GPR_DataValue

	;External link sense
        ;-------------------
	mov	Nic.media[AUI].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[AUI].InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[AUI].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[AUI].MediumInternalRegs.CSR13, TWINET_CSR13_AUI_DEFAULT
	mov	Nic.media[AUI].MediumInternalRegs.CSR14, TWINET_CSR14_AUI_DEFAULT
	mov	Nic.media[AUI].MediumInternalRegs.CSR15, TWINET_CSR15_AUI_DEFAULT

	;Twinet2 and above have different SIA values
	;-------------------------------------------
	cmp     Nic.rev, CFRV_REV2
	jl      SHORT STwDP_DoneTwinet2SIAAUI

	mov     Nic.media[AUI].MediumInternalRegs.RegsPresence, Present
	mov     Nic.media[AUI].MediumInternalRegs.CSR13, TWINET2_CSR13_AUI_DEFAULT
	mov     Nic.media[AUI].MediumInternalRegs.CSR14, TWINET2_CSR14_AUI_DEFAULT
	mov     Nic.media[AUI].MediumInternalRegs.CSR15, TWINET2_CSR15_AUI_DEFAULT

STwDP_DoneTwinet2SIAAUI:
	;Medium routines init
        ;--------------------
	mov	Nic.Media[AUI].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[AUI].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[AUI].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[AUI].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[AUI].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	;---------------------
	; Medium TP FullDuplex
        ;---------------------
	mov	Nic.media[TPFD].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[TPFD].CSR6_OM, CSR6_SIA_10M or CSR6_FD

	;GEP sequence
        ;------------
	mov	Nic.media[TPFD].Gep.SequenceCount, 2
	mov	Nic.Media[TPFD].Gep.SequenceData[Gep_Control], TWINET_GPR_InitValue
	mov	Nic.Media[TPFD].Gep.SequenceData[Gep_Data],    TWINET_GPR_DataValue

	;External link sense
        ;-------------------
	mov	Nic.media[TPFD].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
	;-------------------
	mov	Nic.media[TPFD].InternalLinkSense.InternalSensePresence, Present

	;Twinet1 has internal link sense of TP links as in tulip
        ;-------------------------------------------------------
	mov	Nic.media[TPFD].InternalLinkSense.InternalLinkSenseRoutine,\
		    			      offset CGroup:Tulip_GetLinkStatusTP

	;Twinet2 and above have a different internal link sense of TP
        ;------------------------------------------------------------
	cmp	Nic.rev, CFRV_REV2
	jl	SHORT STwDP_DoneTwinet2LinkSenseTPFD
	mov	Nic.media[TPFD].InternalLinkSense.InternalLinkSenseRoutine,\
					      offset CGroup:Twinet2_GetLinkStatusTP
STwDP_DoneTwinet2LinkSenseTPFD:

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[TPFD].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[TPFD].MediumInternalRegs.CSR13, TWINET_CSR13_TPFD_DEFAULT
	mov	Nic.media[TPFD].MediumInternalRegs.CSR14, TWINET_CSR14_TPFD_DEFAULT
	mov	Nic.media[TPFD].MediumInternalRegs.CSR15, TWINET_CSR15_TPFD_DEFAULT

	;Twinet2 and above have different SIA values
	;-------------------------------------------
	cmp     Nic.rev, CFRV_REV2
	jl      SHORT STwDP_DoneTwinet2SIATPFD

	mov     Nic.media[TPFD].MediumInternalRegs.RegsPresence, Present
	mov     Nic.media[TPFD].MediumInternalRegs.CSR13, TWINET2_CSR13_TPFD_DEFAULT
	mov     Nic.media[TPFD].MediumInternalRegs.CSR14, TWINET2_CSR14_TPFD_DEFAULT
	mov     Nic.media[TPFD].MediumInternalRegs.CSR15, TWINET2_CSR15_TPFD_DEFAULT

STwDP_DoneTwinet2SIATPFD:
	;Medium routines init
        ;--------------------
	mov	Nic.Media[TpFD].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[TpFD].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[TpFD].MediumRoutines.MGetCapabilities,offset CGroup:NullRoutine
	mov	Nic.Media[TpFD].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMedium
	mov	Nic.Media[TpFD].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	;------------------------------------------------
	;Only Twinet2 and above have Internal 100MBps PHY
        ;------------------------------------------------
	cmp	Nic.rev, CFRV_REV2
	jl	STwDP_DoneWithTwinet2Internal100MBps


	;--------------
	; Medium SymScr
        ;--------------
	mov	Nic.media[SymScr].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[SymScr].CSR6_OM, CSR6_SYM_SCR_100M

	;GEP sequence
        ;------------
	mov	Nic.media[SymScr].Gep.SequenceCount, 2
	mov	Nic.Media[SymScr].Gep.SequenceData[Gep_Control], TWINET_GPR_InitValue
	mov	Nic.Media[SymScr].Gep.SequenceData[Gep_Data],    TWINET_GPR_DataValue

	;External link sense
        ;-------------------
	mov	Nic.media[SymScr].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[SymScr].InternalLinkSense.InternalSensePresence, Present
	mov	Nic.media[SymScr].InternalLinkSense.InternalLinkSenseRoutine,\
					      offset CGroup:Twinet2_GetLinkStatusSymScr

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[SymScr].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[SymScr].MediumInternalRegs.CSR13, TWINET_CSR13_SYM
	mov	Nic.media[SymScr].MediumInternalRegs.CSR14, TWINET_CSR14_SYM
	mov	Nic.media[SymScr].MediumInternalRegs.CSR15, TWINET_CSR15_SYM

	;Medium routines init
        ;--------------------
	mov	Nic.Media[SymScr].MediumRoutines.MInit,			offset CGroup:NullRoutine
	mov	Nic.Media[SymScr].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[SymScr].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[SymScr].MediumRoutines.MSelectMedium,		offset CGroup:MSelectPointedMediumTwinetMiiSym
	mov	Nic.Media[SymScr].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	;--------------------------
	; Medium SymScr FullDuplex
        ;-------------------------
	mov	Nic.media[SymScrFD].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[SymScrFD].CSR6_OM, CSR6_SYM_SCR_100M or CSR6_FD

	;GEP sequence
        ;------------
	mov	Nic.media[SymScrFD].Gep.SequenceCount, 2
	mov	Nic.Media[SymScrFD].Gep.SequenceData[Gep_Control], TWINET_GPR_InitValue
	mov	Nic.Media[SymScrFD].Gep.SequenceData[Gep_Data],    TWINET_GPR_DataValue

	;External link sense
        ;-------------------
	mov	Nic.media[SymScrFD].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[SymScrFD].InternalLinkSense.InternalSensePresence, Present
	mov	Nic.media[SymScrFD].InternalLinkSense.InternalLinkSenseRoutine,\
					      offset CGroup:Twinet2_GetLinkStatusSymScr


	;Internal Phy regs
        ;-----------------
	mov	Nic.media[SymScrFD].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[SymScrFD].MediumInternalRegs.CSR13, TWINET_CSR13_SYM
	mov	Nic.media[SymScrFD].MediumInternalRegs.CSR14, TWINET_CSR14_SYM
	mov	Nic.media[SymScrFD].MediumInternalRegs.CSR15, TWINET_CSR15_SYM

	;Medium routines init
        ;--------------------
	mov	Nic.Media[SymScrFD].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[SymScrFD].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[SymScrFD].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[SymScrFD].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMediumTwinetMiiSym
	mov	Nic.Media[SymScrFD].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	;------------------
	; Medium 100BaseT4
        ;------------------
	mov	Nic.media[BaseT4].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[BaseT4].CSR6_OM, CSR6_SYM_100M

	;GEP sequence
        ;------------
	mov	Nic.media[BaseT4].Gep.SequenceCount, 2
	mov	Nic.Media[BaseT4].Gep.SequenceData[Gep_Control], TWINET_GPR_InitValue
	mov	Nic.Media[BaseT4].Gep.SequenceData[Gep_Data],    TWINET_GPR_DataValue

	;External link sense
        ;-------------------
	mov	Nic.media[BaseT4].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[BaseT4].MediumInternalRegs.RegsPresence, Absent

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[BaseT4].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[BaseT4].MediumInternalRegs.CSR13, TWINET_CSR13_SYM
	mov	Nic.media[BaseT4].MediumInternalRegs.CSR14, TWINET_CSR14_SYM
	mov	Nic.media[BaseT4].MediumInternalRegs.CSR15, TWINET_CSR15_SYM

	;Medium routines init
        ;--------------------
	mov	Nic.Media[BaseT4].MediumRoutines.MInit,			offset CGroup:NullRoutine
	mov	Nic.Media[BaseT4].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[BaseT4].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[BaseT4].MediumRoutines.MSelectMedium,		offset CGroup:MSelectPointedMediumTwinetMiiSym
	mov	Nic.Media[BaseT4].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus



	;------------------
	; Medium 100BaseFX
        ;------------------
	mov	Nic.media[BaseFx].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[BaseFx].CSR6_OM, CSR6_SYM_100M

	;GEP sequence
        ;------------
	mov	Nic.media[BaseFx].Gep.SequenceCount, 2
	mov	Nic.Media[BaseFx].Gep.SequenceData[Gep_Control], TWINET_GPR_InitValue
	mov	Nic.Media[BaseFx].Gep.SequenceData[Gep_Data],    TWINET_GPR_DataValue

	;External link sense
        ;-------------------
	mov	Nic.media[BaseFx].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[BaseFx].InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[BaseFx].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[BaseFx].MediumInternalRegs.CSR13, TWINET_CSR13_SYM
	mov	Nic.media[BaseFx].MediumInternalRegs.CSR14, TWINET_CSR14_SYM
	mov	Nic.media[BaseFx].MediumInternalRegs.CSR15, TWINET_CSR15_SYM

	;Medium routines init
        ;--------------------
	mov	Nic.Media[BaseFx].MediumRoutines.MInit,			offset CGroup:NullRoutine
	mov	Nic.Media[BaseFx].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[BaseFx].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[BaseFx].MediumRoutines.MSelectMedium,		offset CGroup:MSelectPointedMediumTwinetMiiSym
	mov	Nic.Media[BaseFX].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus


	;----------------------------
	; Medium 100BaseFX FullDuplex
        ;----------------------------
	mov	Nic.media[BaseFxFD].MediaPresence, Absent

	;OM Reg
        ;------
	mov	Nic.media[BaseFxFD].CSR6_OM, CSR6_SYM_100M or CSR6_FD

	;GEP sequence
        ;------------
	mov	Nic.media[BaseFxFD].Gep.SequenceCount, 2
	mov	Nic.Media[BaseFxFD].Gep.SequenceData[Gep_Control], TWINET_GPR_InitValue
	mov	Nic.Media[BaseFxFD].Gep.SequenceData[Gep_Data],    TWINET_GPR_DataValue

	;External link sense
        ;-------------------
	mov	Nic.media[BaseFxFD].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.media[BaseFxFD].InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
        ;-----------------
	mov	Nic.media[BaseFxFD].MediumInternalRegs.RegsPresence, Present
	mov	Nic.media[BaseFxFD].MediumInternalRegs.CSR13, TWINET_CSR13_SYM
	mov	Nic.media[BaseFxFD].MediumInternalRegs.CSR14, TWINET_CSR14_SYM
	mov	Nic.media[BaseFxFD].MediumInternalRegs.CSR15, TWINET_CSR15_SYM

	;Medium routines init
        ;--------------------
	mov	Nic.Media[BaseFxFD].MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.Media[BaseFxFD].MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.Media[BaseFxFD].MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.Media[BaseFxFD].MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMediumTwinetMiiSym
	mov	Nic.Media[BaseFXFD].MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus

STwDP_DoneWithTwinet2Internal100MBps:

	;--------
	; Mii PHY
	;--------

	;OM Reg
        ;------
	mov	Nic.MiiPhysList[0].MacEntry.CSR6_OM, CSR6_MII

	;External link sense
        ;-------------------
	mov	Nic.MiiPhysList[0].MacEntry.ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID

	;Internal Link sense
        ;-------------------
	mov	Nic.MiiPhysList[0].MacEntry.InternalLinkSense.InternalSensePresence, Absent

	;Internal Phy regs
	;-----------------
	mov	Nic.MiiPhysList[0].MacEntry.MediumInternalRegs.RegsPresence, Present
	mov	Nic.MiiPhysList[0].MacEntry.MediumInternalRegs.CSR13, TWINET_CSR13_MII
	mov	Nic.MiiPhysList[0].MacEntry.MediumInternalRegs.CSR14, TWINET_CSR14_MII
	mov	Nic.MiiPhysList[0].MacEntry.MediumInternalRegs.CSR15, TWINET_CSR15_MII

	;Medium routines init
        ;--------------------
	mov	Nic.MiiPhysList[0].MacEntry.MediumRoutines.MInit,		offset CGroup:NullRoutine
	mov	Nic.MiiPhysList[0].MacEntry.MediumRoutines.MParse,		offset CGroup:NullRoutine
	mov	Nic.MiiPhysList[0].MacEntry.MediumRoutines.MGetCapabilities,	offset CGroup:NullRoutine
	mov	Nic.MiiPhysList[0].MacEntry.MediumRoutines.MSelectMedium,	offset CGroup:MSelectPointedMediumTwinetMiiSym
	mov	Nic.MiiPhysList[0].MacEntry.MediumRoutines.MGetLinkStatus,	offset CGroup:GetPointedMediumLinkStatus

	ret

DcMediaInitTwinet	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          GetMediumCapabilities     (Phy	   IN  PhyType
;					    Medium IN  MediaType)
;
;
; Description:
; On Entry:
;               Ax	   Medium's Phy
;               SI         Medium
;
; On Return:
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
GetMediumCapabilities	proc

	push	di

	;Point to medium Entry in Nic
        ;----------------------------
	call	PointToMedium
	jc	SHORT  GMC_ErrorExit

	;Check for medium presence
        ;-------------------------
        xor	ax, ax
	cmp     (MEDIA_ENTRY PTR [di]).MediaPresence, Present
	jne     SHORT GMC_Exit

	;Convert Medium from MediaType to Phy capability bit mask
        ;--------------------------------------------------------
	mov	ax, si
	xor	ah, ah
	call	ConvertConnectionToMediaCapabilities

	;Chek for Medium AS ability
        ;--------------------------
	cmp     (MEDIA_ENTRY PTR [di]).ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID
	je	SHORT GMC_DoneWithExternalLink
	or	ax, PhyAsNwayCapable
GMC_DoneWithExternalLink:

	cmp     (MEDIA_ENTRY PTR [di]).InternalLinkSense.InternalSensePresence, Present
	jne	SHORT GMC_DoneWithInternalLink
	or	ax, PhyAsNwayCapable
GMC_DoneWithInternalLink:

GMC_Exit:
	pop	di
	ret

GMC_ErrorExit:
	xor	ax, ax
	pop	di
	stc
	ret

GetMediumCapabilities	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          TP_To_TPILT	Proc
;
;
;
; Description:
; On Entry:
;               SI         Selected Medium
;               Ax	   Medium's Phy
;		DX	   Nway advertisement
;
; On Return:
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
TP_To_TPILT	proc

	;Go to set default parameters according
	;to the device found on Nic
        ;--------------------------------------
	cmp	Nic.Dev, TULIP
	je	SHORT TTTI_Tulip
	cmp	Nic.Dev, TULIP3
	je	TTTI_Tulip3
	cmp	Nic.Dev, FASTERNET
	je	TTTI_FasterNet
	cmp	Nic.Dev, TWINET
	je	TTTI_TwiNet
	stc                             ;If reached this point - Unknown device
	ret

TTTI_Tulip:
	mov	Nic.Media[TP].MediumInternalRegs.CSR14, CSR14_TP_ILT ;Change values for TP-ILT
	jmp	SHORT TTTI_Exit

TTTI_Tulip3:
	mov	Nic.Media[TP].MediumInternalRegs.CSR13, TULIP3_CSR13_TP_NLT_DEFAULT ;Change values for TP-ILT
	mov	Nic.Media[TP].MediumInternalRegs.CSR14, TULIP3_CSR14_TP_NLT_DEFAULT ;Change values for TP-ILT
	mov	Nic.Media[TP].MediumInternalRegs.CSR15, TULIP3_CSR15_TP_NLT_DEFAULT ;Change values for TP-ILT
	jmp	SHORT TTTI_Exit

TTTI_FasterNet:
	jmp	SHORT TTTI_Exit

TTTI_TwiNet:
	mov	Nic.Media[TP].MediumInternalRegs.CSR13, TWINET_CSR13_TP_NLT_DEFAULT ;Change values for TP-ILT
	mov	Nic.Media[TP].MediumInternalRegs.CSR14, TWINET_CSR14_TP_NLT_DEFAULT ;Change values for TP-ILT
	mov	Nic.Media[TP].MediumInternalRegs.CSR15, TWINET_CSR15_TP_NLT_DEFAULT ;Change values for TP-ILT
	jmp	SHORT TTTI_Exit


TTTI_Exit:
	clc
	ret

TP_To_TPILT	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          DisableScrambler	Proc
;
;
;
; Description:
; On Entry:
;
; On Return:
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
;			All registers are PRESERVED
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DisableScrambler	proc

	;Modify CSR6_OM ins SymScr media entries and Shadow_CSR6
	;-------------------------------------------------------
	and	Nic.Shadow_CSR6, not CSR6_SCR
	and	Nic.Media[SymScr].CSR6_OM, not CSR6_SCR   ;Update SymScr media specific bit
	and	Nic.Media[SymScrFD].CSR6_OM, not CSR6_SCR ;Update SymScr media specific bit
	ret

DisableScrambler	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ModifyGEP_Control	Proc
;
;
;
; Description:
; On Entry:
;         	AX - New GEP value
;
; On Return:
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
;			All registers are PRESERVED
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ModifyGEP_Control	proc

	push	cx
        push	si

	;SIA and SYM GPR Control Update
	;------------------------------
	mov	cx, MAX_MEDIA_TABLE

MGC_UpdateGPRControl:
	indexToOffset MEDIA_ENTRY, cx, 1, si
	mov	Nic.Media[si].Gep.SequenceData[Gep_Control], ax
	loop	MGC_UpdateGPRControl

	;MII PHY GPR Control Handling
	;----------------------------
	mov	Nic.MiiPhysList[0].MacEntry.Gep.SequenceData[Gep_Control], ax   ;We assume the first word is to be modified.
	mov	Nic.MiiPhysList[0].GepReset.SequenceData[Gep_Control], ax       ;We assume the first word is to be modified

	;External reset Control handling
	;-------------------------------
	mov	Nic.ExternalReset.SequenceData[Gep_Control], ax   		;We assume the first word is to be modified.

MGC_exit:
	pop	si
        pop	cx
	ret

ModifyGEP_Control	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ModifyGEP_Data	Proc
;
;
;
; Description:
; On Entry:
;         	AX - New GEP value
;
; On Return:
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
;			All registers are PRESERVED
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ModifyGEP_Data	proc

	push	cx
        push	si

	;SIA and SYM GPR Data Update
	;---------------------------
	mov	cx, MAX_MEDIA_TABLE

MGD_UpdateGPRData:
	indexToOffset MEDIA_ENTRY, cx, 1, si
	mov	Nic.Media[si].Gep.SequenceData[Gep_Data], ax
	loop	MGD_UpdateGPRData

	;MII PHY GPR Data Handling
	;-------------------------
	mov	Nic.MiiPhysList[0].MacEntry.Gep.SequenceData[Gep_Data], ax  ;We assume the second word is to be modified.
	mov	Nic.MiiPhysList[0].GepReset.SequenceData[Gep_Data+2], ax    ;We assume the third word is to be modified
									    ;(First-control, Second-reset, Third-data)
	;External reset Data handling
	;-------------------------------
	mov	Nic.ExternalReset.SequenceData[Gep_Data+2], ax   	     ;We assume the third word is to be modified.
									     ;(First-control, Second-reset, Third-data)
MGD_exit:
	pop	si
        pop	cx
	ret

ModifyGEP_Data	endp

END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          SelectMedium	Proc
;
;
;
; Description:
; On Entry:
;               SI         Selected Medium
;               Ax	   Medium's Phy
;		DX	   Nway advertisement
;
; On Return:
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SelectMedium	proc


	push	eax
	push	ebx
	push	di

	call	PointToMedium
	jc	SHORT SM_ErrorExit


	;---------------------------
	;Stop the TX and RX machines
	;---------------------------

	;Save original Shadow CSR6 TX & RX machines
	;------------------------------------------
	mov	ebx,  Nic.Shadow_CSR6
	and     ebx,  CSR6_START_TX_COMMAND or CSR6_START_RX_COMMAND
	push	ebx

	;Stop the TX & RX machines
        ;-------------------------
	call    StopTheTxAndRxMachines

	;---------------------------------------
	;Call the Media specific setting routine
	;---------------------------------------
	call    (MEDIA_ENTRY PTR [di]).MediumRoutines.MSelectMedium

	;------------------------------------------------
	;Let things Stabilize befor starting the machines
        ;------------------------------------------------
	call	WaitForMagneticsStabilization

	;------------------------------------
	;Restart TX & RX machines (If needed)
        ;------------------------------------
	pop	eax				;Restore original Shadow CSR6 TX & RX
	or	eax, eax                        ;If eax== 0 -> no need to write CSR6 again
	jz	SHORT SM_Exit
	or	NIc.Shadow_CSR6, eax
	call    Nic.WriteCSR6

SM_Exit:
	clc
SM_Fin:
	pop	di
	pop	ebx
	pop	eax
	ret

SM_ErrorExit:
	stc
	jmp	SHORT SM_Fin

SelectMedium	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          GetMediumLinkStatus	Proc
;
;
;
; Description:
; On Entry:
;               SI         Selected Medium
;               Ax	   Medium's Phy
;
; On Return:
; 		AL	Medium Link Status
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
GetMediumLinkStatus	proc

	push	di

	call	PointToMedium
	jc	SHORT GMLS_ErrorExit

	call    (MEDIA_ENTRY PTR [di]).MediumRoutines.MGetLinkStatus

	clc
        pop	di
	ret

GMLS_ErrorExit:
	stc
	mov	al, MEDIA_STATE_UNKNOWN
	pop	di
	ret

GetMediumLinkStatus	endp

END_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Name:		GetMediaLineSpeed	proc
;
; Description:
;
; On Entry:	Interrupts disabled
;               SI 	   Medium its line soeed we are looking for.
;
; On Return:
;               AX  -      The media's LineSpeed
;		Flags:
;
;
;		Note:   Interrupts are disabled.
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
START_DATA_SEGMENT_RUNTIME

MediaToLineSpeedConversionTable	     	db	10  ;MediaTP 	     (0)
					db	10  ;MediaBNC	     (1)
					db	10  ;MediaAUI        (2)
					db	100 ;MediaSymScr     (3)==100Tx
					db	10  ;MediaTPFD       (4)
					db	100 ;MediaSymScrFD   (5)
					db	100 ;Media100BaseT4  (6)
					db	100 ;Media100BaseFx  (7)
					db	100 ;Media100BaseFxFD(8)
					db	10  ;MediaMiiTP
					db	10  ;MediaMiiTpFD
					db	10  ;MediaMiiBNC
					db	10  ;MediaMiiAUI
					db      100 ;MediaMii100BaseTX
					db	100 ;MediaMii100BaseTxFD
					db	100 ;MediaMii100BaseT4
					db	100 ;MediaMii100BaseFX
					db	100 ;MediaMii100BaseFxFD

END_DATA_SEGMENT_RUNTIME

START_CODE_SEGMENT_RUNTIME

GetMediaLineSpeed	proc

	push	bx

	mov	ax, si			;ax to hold media
	xor	ah, ah			;Clear irrelvant bits

	;If media type is unknown - Line speed == 10
	;-------------------------------------------
	cmp	al, NoSelectedMedia
	jne	SHORT GMLS_GetSpeed
	mov	al, MediaTP			;No media -> Assume TP

	;Media is indicated -> retrieve its line-speed
        ;----------------------------------------------
GMLS_GetSpeed:
	lea	bx, MediaToLineSpeedConversionTable
	xlat

GMLS_Exit:
	pop	bx
	ret

GetMediaLineSpeed	endp

END_CODE_SEGMENT_RUNTIME


;******************************************************************************
;	      		 DC_MEDIA   INTERNAL   ROUTINES
;******************************************************************************

START_CODE_SEGMENT_RUNTIME
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          MSelectPointedMedium	Proc
;
;
;
; Description:
; On Entry:
;               SI         Selected Medium
;               Ax	   Medium's Phy
;		DX	   Nway advertisement
;		DI	   Meduim entry
;
; On Return:
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MSelectPointedMedium		proc

	;----------------
	;Media Selecting
	;----------------
	call	SetGEPToPointedMedium
	call	SetCSR6ToPointedMedium
	call	SetInternalPhyRegsToPointedMedium
	ret

MSelectPointedMedium		endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          MSelectPointedMediumTwinetMiiSym	Proc
;
;
;
; Description:
; On Entry:
;               SI         Selected Medium
;               Ax	   Medium's Phy
;		DX	   Nway advertisement
;		DI	   Meduim entry
;
; On Return:
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MSelectPointedMediumTwinetMiiSym	proc

	push	dx

	;Set GEP
        ;-------
	call	SetGEPToPointedMedium

        ;-------------------------------
	;MII or SYM Phys' media Handling
	;-------------------------------
	;If (Currently selected Port is SIA ) then
	;	Write SIA registers
	;Else
	;	Switch to SIA port
	;	Write SIA registers
	;EndIf
	;--------------------------------------------
	push	eax
	mov	dx, Nic.CSR6_Address
	in	eax, dx
	test	eax, CSR6_PS
	jz	SHORT MSPMTMS_PsSIA
	and	eax, NOT (CSR6_PS or CSR6_SCR)		;Select SIA, Disable SCR
	out	dx, eax
MSPMTMS_PsSIA:                                        	;current PS is SIA -> Do SIA writing
	pop		eax
	call	SetInternalPhyRegsToPointedMedium

	;Set CSR6
        ;--------
	call	SetCSR6ToPointedMedium


        pop	dx
	ret

MSelectPointedMediumTwinetMiiSym	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          MSelectPointedMediumTwinet2SIANway	Proc
;
; Description:
;	This routine sets the chip to the desired SIA medium (TP, TpFD, BNC, AUI)
;	with the inclusion of NWAY dvertizment.
;	Since Nway adv. bits are spread in CSR14 and CSR6 regs the following
;	steps have to be taken:
;	1. Update Shadow_CSR6 to the desired medium value
;	2. Update Shadow SIA regs (13,14,15) to the desired medium values
;	3. Add the appropriate Nway adv. bits
;	4. Write CSR6
;	5. Write SIA Regs
;	6. Write Gep
;
; On Entry:
;               SI         Selected Medium
;               Ax	   Medium's Phy
;		DX	   Nway advertisement
;		DI	   Meduim entry
;
; On Return:
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MSelectPointedMediumTwinet2SIANway		proc

	;Set GEP to medium
        ;-----------------
	call	SetGEPToPointedMedium

        ;Update shadow csr6 to pointed medium
	;------------------------------------
	call    UpdateShadowCSR6ToPointedMedium

	;Modify SIA & CSR6 Shadow registers
	;----------------------------------
	call    SetInternalPhyShadowRegsToPointedMedium
	call	AddNwayAdvBitsTwinet2

	;Write shadow regs in this order
        ;------------------------------
	call    Nic.WriteCSR6

	;Write SIA regs
        ;--------------
	call    WriteInternalPhyRegs         	;Write SIA regs

	ret

MSelectPointedMediumTwinet2SIANway		endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         AddNwayAdvBitsTwinet2	proc
;
;
; Description:
;	Adds the appropriate Nway adv. bits to shadow SIA and CSR6 regs
;
; On Entry:
;		SI - Connection Type
;          	DX - Nway adv. bits
;
; On Return:
;               All registers are preserved
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
AddNwayAdvBitsTwinet2	proc

	push	ax
	push	si


	;------------------------------
	;Add Enable Autosense-Nway Bits
	;------------------------------
	or      Nic.CSR14_Value, TWINET2_CSR14_ANE or TWINET2_CSR14_TAS

	;---------------------------
	;Add Nway Advertisement bits
	;---------------------------

	;10BaseT bit handling
	;--------------------
	test	dx, Nway10BaseT
	jz	SHORT ANABT2_Done10BaseT
	or	Nic.CSR14_Value, TWINET2_CSR14_NWAY_TP
ANABT2_Done10BaseT:

	;10BaseT-FD bit handling
	;-----------------------
	and	Nic.Shadow_CSR6, NOT (DWORD PTR CSR6_FD)	;Assume no TpFD Adv. is needed
	test	dx, Nway10BaseTFD
	jz	SHORT ANABT2_Done10BaseTFD
	or	Nic.Shadow_CSR6, CSR6_FD
ANABT2_Done10BaseTFD:

	;100BaseTX bit handling
        ;----------------------
	test	dx, Nway100BaseTx
	jz	SHORT ANABT2_Done100BaseTX
	or	Nic.CSR14_Value, TWINET2_CSR14_NWAY_TX
ANABT2_Done100BaseTX:

	;100BaseTX-FD bit handling
        ;-------------------------
	test	dx, Nway100BaseTxFD
	jz	SHORT ANABT2_Done100BaseTXFD
	or	Nic.CSR14_Value, TWINET2_CSR14_NWAY_TXFD
ANABT2_Done100BaseTXFD:

	;100BaseT4 bit handling
        ;----------------------
	test	dx, Nway100BaseT4
	jz	SHORT ANABT2_Done100BaseT4
	or	Nic.CSR14_Value, TWINET2_CSR14_NWAY_T4
ANABT2_Done100BaseT4:

	pop	si
	pop	ax
	ret

AddNwayAdvBitsTwinet2	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         SetInternalPhyRegsToPointedMedium
;
;
; Description:
; On Entry:
;               SI         Media Type
;               DI         Pointer to Selected Medium Entry in Nic.
;               AX         Phy Type
; On Return:
;
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SetInternalPhyRegsToPointedMedium       proc

	call    SetInternalPhyShadowRegsToPointedMedium
	jc      SHORT SIPR_Exit
	call    WriteInternalPhyRegs
SIPR_Exit:
	clc
	ret

SetInternalPhyRegsToPointedMedium       endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         SetInternalPhyShadowRegsToPointedMedium
;
;
; Description:
; On Entry:
;               DI         Pointer to Selected Medium Entry in Nic.
;
; On Return:
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SetInternalPhyShadowRegsToPointedMedium proc

	push    eax

	;If No internal regs value - Done
	;--------------------------------
	cmp     (MEDIA_ENTRY PTR [di]).MediumInternalRegs.RegsPresence, Present
	jne     SHORT SIPSR_ErrorExit

	xor	eax, eax

	mov     ax, (MEDIA_ENTRY PTR [di]).MediumInternalRegs.CSR13
	mov     Nic.CSR13_Value, eax
	mov     ax, (MEDIA_ENTRY PTR [di]).MediumInternalRegs.CSR14
	mov     Nic.CSR14_Value, eax
	mov     ax, (MEDIA_ENTRY PTR [di]).MediumInternalRegs.CSR15
	mov     Nic.CSR15_.SIA_, ax

	clc

SIPSR_Exit:
	pop     eax
	ret

SIPSR_ErrorExit:
	stc
	jmp	SHORT SIPSR_Exit

SetInternalPhyShadowRegsToPointedMedium endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Name:       SetGEPToPointedMedium     proc
;
; Description:
;
; On Entry:
;               SI         Media Type
;               DI         Pointer MEDIA_STRUC entry.
;               AX         Phy Type
;
; On Return:
;               Flags:
;
;
;               Note:   Interrupts are disabled.
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SetGEPToPointedMedium   proc

	push    bx
	lea     bx, (MEDIA_ENTRY PTR [di]).Gep[0]
	call    SetGep
	pop     bx
	ret

SetGEPToPointedMedium   endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Name:       SetCSR6ToPointedMedium            proc
;
; Description:
;	sets and writes CSR6 with appropriate medium values.
;	Notice the 3 step writing sequence:
;	  1. Stop the TX & RX machines
;	  2. Write the new/modified csr6 value with TX & RX machines stopped.
;	  3. Restart the TX & RX machines (if needed).
;
;	
; On Entry:
;               SI         Media Type
;               DI         Pointer to Selected Medium Entry in Nic.
;               AX         Phy Type
;
; On Return:
;               Flags:
;
;
;               Note:   Interrupts are disabled.
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SetCSR6ToPointedMedium  proc

	;Update shadow csr6 to pointed medium
        ;------------------------------------
	call    UpdateShadowCSR6ToPointedMedium
	call    Nic.WriteCSR6

	ret

SetCSR6ToPointedMedium   endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         GetPointedMediumLinkStatus (Connection IN  ConnectionType)
;
;
; Description:
; On Entry:
;               SI      Selected Medium  (SIA or SYM medium only)
;               AI	Phy type
;		DI	Medium entry ptr
; On Return:
;               Al      External linkStatus (in al)
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
GetPointedMediumLinkStatus     proc


	;If External Link is valid - use it
	;----------------------------------
	cmp     (MEDIA_ENTRY PTR [di]).ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID
	je      SHORT GPMLS_DoneWithExternalLink
	call    GetExternalLinkStatus
	jmp     SHORT GPMLS_Exit
GPMLS_DoneWithExternalLink:

	;ElseIf Internal Link status routine is present - use it
	;--------------------------------------------------------
	cmp     (MEDIA_ENTRY PTR [di]).InternalLinkSense.InternalSensePresence, Present
	jne     SHORT GPMLS_DoneWithInternalLink
	call    (MEDIA_ENTRY PTR [di]).InternalLinkSense.InternalLinkSenseRoutine
	jmp     SHORT GPMLS_Exit
GPMLS_DoneWithInternalLink:

	;Else Link status is Unknown
	;---------------------------
GPMLS_ErrorExit:
	mov     al, MEDIA_STATE_UNKNOWN
	stc

GPMLS_Exit:
	ret

GetPointedMediumLinkStatus     endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         GetExternalLinkStatus
;
;
; Description:
; On Entry:
;               SI         Media Type
;               DI         Pointer to Selected Medium Entry in Nic.
;               AX         Phy Type
;
; On Return:
;               AX      External linkStatus (in al)
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
GetExternalLinkStatus   proc

	;Is Medium Link sensable
	;-----------------------
	cmp     (MEDIA_ENTRY PTR [di]).ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID
	je      SHORT GELS_ErrorExit                            ;Medium is Not link sensable

	push    ax
	call    Nic.ReadGEPRegister
	xor     al, (MEDIA_ENTRY PTR [di]).ExternalLinkSense.Polarity         ;Set link mask according to polarity
	and     al, (MEDIA_ENTRY PTR [di]).ExternalLinkSense.LinkSenseMask    ;Keep link bit only
	xor     al, (MEDIA_ENTRY PTR [di]).ExternalLinkSense.LinkSenseMask    ;Set Zero flag if Link==1
	pop     ax
	mov     al, MEDIA_LINK_PASS                           ;Assume LinkPass
	jz      SHORT GELS_Exit
	mov     al, MEDIA_LINK_FAIL                           ;Link failed
	stc                                                   ;Link failed
GELS_Exit:
	ret

GELS_ErrorExit:
	mov     al, MEDIA_STATE_UNKNOWN                       ;Link Unknown
	stc
	ret

GetExternalLinkStatus   endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         WriteInternalPhyRegs
;
;
; Description:
; On Entry:
;
;
; On Return:
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
WriteInternalPhyRegs    proc

	push    eax
	push    cx
	push    dx

	;First Reset SIA
	;---------------
	xor     eax, eax
	mov     dx, Nic.CSR13_Address
	out     dx, eax

	;Write regs values
	;-----------------
	mov     eax, Nic.CSR15_.Value
	mov     dx,  Nic.CSR15_Address
	out     dx, eax

	mov     eax, Nic.CSR14_Value
	mov     dx,  Nic.CSR14_Address
	out     dx, eax

	mov     eax, Nic.CSR13_Value             ;If csr13 value is 0 we already write it
	or	eax, eax                         ;when resetted SIA
	jz	SHORT WIPR_DoneWithCSR13
	mov     dx, Nic.CSR13_Address
	out     dx, eax
WIPR_DoneWithCSR13:

	;Chip specific stabilization
	;---------------------------
	;In Tulip pass1 if in TP the driver should check to see if the Link Test
	;is in progress.  This is so if CSR12<LKF> is set and CSR12<NCR> is
	;clear. At the end of link test, there are two link test status
	;possibilities:
	;       CSR12<LKF> CSR12<NCR>
	;          1            0       - During link test
	;          0            x       - End of link test, status = success
	;                                                        (up to 240msec)
	;          1            1       - End of link test, status = failed
	;                                                        (after 2.4 sec)
	;
	;The test should be as follows:
	; DO
	;   temp = CSR12;
	; UNTIL ((temp<LKF> = 0) OR (temp<NCR> = 1);
	;The test duration is 240mSec - so we should TimeOut on that.
	;------------------------------------------------------------
	cmp     Nic.DevAndRev, TULIP_REV1
	jne     SHORT WIPR_NotPass1

	cmp     WORD PTR Nic.CSR13_Value, CSR13_TP
	jne     SHORT WIPR_NoDelayNeeded

	cmp     WORD PTR Nic.CSR14_Value, CSR14_TP_ILT  ;If in ignore link test, skip
	je      SHORT WIPR_NoDelayNeeded          	;this delay!


	mov     si, MediaTP
	mov     cx, 48000               ;Max time = 5u * 48K = 240mSec
WIPR_WaitForLinkTestToEnd:
	call    GetMediumLinkStatus
	cmp     al, MEDIA_LINK_CONFIGURING
	jne     SHORT WIPR_LinkTestEnded
	call    PostResetDelay          ;Delay for 5uSec
	loop    WIPR_WaitForLinkTestToEnd
WIPR_LinkTestEnded:

WIPR_NoDelayNeeded:
WIPR_NotPass1:

	pop     dx
	pop     cx
	pop     eax
	ret

WriteInternalPhyRegs    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Name:       SetGEP            proc
;
; Description:
;
; On Entry:
;               SI         Media Type
;               BX         Pointer GPR_STRUC entry.
;               AX         Phy Type
;
; On Return:
;               Flags:
;
;
;               Note:   Interrupts are disabled.
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SetGEP  proc

	;Save Registers
	;--------------
	push    ax
	push    cx
	push    si


	xor     si, si                          ;SI - First GPR word
	mov     cx, (GPR_STRUC PTR [bx]).SequenceCount
	shl     cx, 1                           ;Cx - Num of BYTES in GEP sequence

SG_WriteGEPSequence:

	;Delay before writing gep
	;------------------------
	push    WORD PTR 240                            ;Delay for 100u berore second gep writing
	call    Delay                                   ;Wait a little
	add	sp, 2                                   ;remove delay param from stack.

	;Do we have another GPR write to handle?
	;---------------------------------------
	cmp     si, cx
	je      SHORT SG_Exit

	;Write the GEP sequence word
	;---------------------------
	mov     ax, (GPR_STRUC PTR [bx]).SequenceData[si]
	call    Nic.WriteGEPRegister

	;Move to next seq. word
	;----------------------
	add     si, 2
	jmp     SHORT SG_WriteGEPSequence

SG_Exit:
	pop     si
	pop     cx
	pop     ax
	ret

SetGEP  endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Name:       UpdateShadowCSR6ToPointedMedium	  proc
;
; Description:
;
; On Entry:     Interrupts disabled
;               SI         Media Type
;               DI         Pointer to Selected Medium Entry in Nic.
;               AX         Phy Type
;
; On Return:
;               AX  -      The media's LineSpeed
;               Flags:
;
;
;               Note:   Interrupts are disabled.
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
UpdateShadowCSR6ToPointedMedium        proc

	push    ax
	push    edx

	;Clear previous OM bits
	;----------------------
	mov     edx, Nic.CSR6_OM_MaskOFF
	and     Nic.Shadow_CSR6, edx

	;Write New OM value
	;------------------
	mov     edx, (MEDIA_ENTRY PTR [di]).CSR6_OM                ;Get media specific CSR6
	or      Nic.Shadow_CSR6, edx                               ;Update saved bits

	;-----------------------
	;MII Phy needs more work
	;-----------------------
	cmp     ax, PHY_TYPE_MII
	jne     SHORT US6_Exit

	;create Mii media control bit
	;----------------------------
	mov     ax, si                                   ;ax <- MediaType
	call    ConvertConnectionToMediaCapabilities     ;Get Medium bit location in Nic's Phy entry

	;Handle Full-Duplex selection
	;----------------------------
	test    Nic.MiiPhysList[0].FullDuplexBits, ax
	jz      SHORT US6_DoneWithMiiFD
	or      Nic.Shadow_CSR6, CSR6_FD
US6_DoneWithMiiFD:

	;Handle TTM selection
	;--------------------
	test    Nic.MiiPhysList[0].TxThresholdModeBits, ax
	jz      SHORT US6_DoneWithTTM
	or      Nic.Shadow_CSR6, CSR6_TTM
US6_DoneWithTTM:

US6_Exit:
	pop     edx
	pop     ax
	ret

UpdateShadowCSR6ToPointedMedium	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;       StopTheTAndRxMachines
;
;
;       Called by: o
;
; On Entry:
;
;               Flags:
;
;       Modifies: 	Shadow_CSR6
;	Note:
;                       All registers are preserved
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
StopTheTxAndRxMachines  proc

	and     Nic.Shadow_CSR6, not (DWORD PTR (CSR6_START_TX_COMMAND or CSR6_START_RX_COMMAND)) ;Stop TX and RX
	call    Nic.WriteCSR6                                                                     ;Stop TX and RX
	call    WaitForTxAndRxMachinesToStop                                                      ;Restor New CSR6 value

	ret

StopTheTxAndRxMachines  endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;       WaitForTxAndRxMachinesToStop
;
;       Routine to wait untill Tx and Rx machines stop.
;       The routines waits with NO Time-Out for the machines to stop, this is not
;	a problem since a working chip will always stop it's machines.
;
;       Called by: o
;
; On Entry:
;
;               Flags:
;
;               Note:   Interrupts at any state.
;                       All registers are preserved
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
WaitForTxAndRxMachinesToStop    proc

	push    eax
        push	cx
	push    dx

	mov     cx, 48000               	;Wait time >= 5u * 48K = 240mSec
WFTARMTS_WaitForTxAndRxToStop:
	mov     dx, Nic.CSR5_Address
	in      eax, dx
	test    eax, CSR5_TS or CSR5_RS
	jz	SHORT WFTARMTS_Exit
	call	PostResetDelay			;Wait for 5usec befor trying again
	loop    WFTARMTS_WaitForTxAndRxToStop

WFTARMTS_Exit:
	pop     dx
        pop	cx
	pop     eax
	ret

WaitForTxAndRxMachinesToStop    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         PointToMedium	proc
;
;
; Description:
; On Entry:
;
;               SI         ConnectionType.
;               AX         PhyType.
;
; On Return:
;               SI         ConnectionType.
;               AX         PhyType.
;               DI         Pointer to the appropriate Medium entry in the Nic.
;
;               Flags:
;                       Carry  set - Fail
;
;               Note:
;			All register (except DI) - preserved
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PointToMedium   proc

	push	si

	cmp     ax, PHY_TYPE_MII
	jne     SHORT PTM_HandleNonMiiPhy

	;-----------------
	; MII PHY handling
        ;-----------------
	;As for Today we support one MII Phy
	;-----------------------------------
	cmp     Nic.MiiPhysList[0].MiiPhyPresence, Present      ;Do we have an MII phy entry at all ?
	jne     SHORT PTM_ErrorExit

	lea     di, Nic.MiiPhysList[0].MacEntry[0]              ;Let DI point at MiiPhy.MacEntry
	jmp     SHORT PTM_Exit

	;---------------------------
	; SIA and SYM PHYs handling
	;--------------------------
PTM_HandleNonMiiPhy:
	GetMediaEntry   di, si
	cmp     Nic.Media[di].MediaPresence, Absent            ;Does media exist at all ?
	je 	SHORT PTM_ErrorExit

	lea     di, Nic.Media[di]                               ;Let dI point at media Entry

PTM_Exit:
	pop	si
	ret

PTM_ErrorExit:
	stc
	pop	si
	ret

PointToMedium   endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         WaitForMagneticsStabilization
;
;
;
; Description:
;	It is recommended to have a delay of at least 1.5Msec between media
;	selection and network activity we will wait for 5msec
; On Entry:
;               ax        GEP word to be written
;
; On Return:
;
;               Flags:
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
WaitForMagneticsStabilization	proc

	push	cx

	mov     cx, 1000                ;1000 times.
Magnetics_Delay:
	call    PostResetDelay          ;wait 5usec
	loop    Magnetics_Delay

	pop	cx
	ret

WaitForMagneticsStabilization	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		Tulip_GetLinkStatusTP
;
; Description:
;
;
; On Entry:	
; On Return:
;       AX - ConnectionStatus
;		Flags:
;		    Carry set Upon Status "error" (Nway configuring or Link-Fail)
;
;		Note:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Tulip_GetLinkStatusTP	proc

	push	dx
	push    eax


	;Read SIA status Reg.
	;--------------------
	mov	dx, Nic.CSR12_Address
	in	eax, dx

	;Handle Nway status
	;------------------
	mov	dh, NWAY_NOT_SUPPORTED

	;Handle Link status
        ;------------------
	test    al, CSR12_LKF		   	;Use LKF and NCR bits for testing TP
	jnz	SHORT TGLSTp_TpNotLP            ;Link status

	mov	dl, MEDIA_LINK_PASS             ;    if !(Status & LF) -> LP
	jmp	SHORT TGLSTp_Exit
TGLSTp_TpNotLP:
	test	al, CSR12_NCR		   	
	jnz	SHORT TGLSTp_TpLF               ;    if (Status & NCR) -> LF
TGLSTp_TpConfiguring:
	mov	dl, MEDIA_LINK_CONFIGURING      ;Link test had not been completed Yet.
	stc
	jmp	SHORT TGLSTp_Exit

TGLSTp_TpLF:
	mov	dl, MEDIA_LINK_FAIL
	stc

TGLSTp_Exit:
	pop	eax
	mov	ax, dx       ;Restor status
	pop	dx
	ret

Tulip_GetLinkStatusTP	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		Twinet2_GetLinkStatusTP
;
; Description:
;
;
; On Entry:
;	ah - Nway status	
; On Return:
;       AX - ConnectionStatus
;		Flags:
;		    Carry set Upon Status "error" (Nway configuring or Link-Fail)
;
;		Note:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Twinet2_GetLinkStatusTP	proc

	push	dx
	push    eax

	;Read SIA status Reg.
	;--------------------
	mov	dx, Nic.CSR12_Address
	in	eax, dx

	;Handle Nway status
	;------------------
	mov	dh, ah

	;Handle Link status
        ;------------------
	mov	dl, MEDIA_LINK_PASS             ; Assume Link pass
	test    al, CSR12_LKF		   	; Use LKF bit for testing Link status
	jz	SHORT TwGLSTp_Exit            	;

	mov	dl, MEDIA_LINK_FAIL             ;Bad assumption -> status is Link Fail
	stc

TwGLSTp_Exit:
	pop	eax
	mov	ax, dx       ;AX to hold Link-status
	pop	dx
	ret

Twinet2_GetLinkStatusTP	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		Twinet2_GetLinkStatusSymScr
;
; Description:
;
;
; On Entry:	
;	ah - Nway status
; On Return:
;       AX - ConnectionStatus
;		Flags:
;		    Carry set Upon Status "error" (Nway configuring or Link-Fail)
;
;		Note:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Twinet2_GetLinkStatusSymScr	proc

	push	dx
	push    eax


	;Read SIA status Reg.
	;--------------------
	mov	dx, Nic.CSR12_Address
	in	eax, dx

	;Handle Nway status
	;------------------
	mov	dh, ah

	;Handle Link status
        ;------------------
	mov	dl, MEDIA_LINK_PASS             ; Assume Link pass
	test    al, CSR12_LF100T		; Use LKF bit for testing Link status
	jz	SHORT TwGLSSS_Exit

	mov	dl, MEDIA_LINK_FAIL             ;Bad assumption -> status is Link Fail
	stc

TwGLSSS_Exit:
	pop	eax
	mov	ax, dx       ;Restor status
	pop	dx
	ret

Twinet2_GetLinkStatusSymScr	endp

END_CODE_SEGMENT_RUNTIME

