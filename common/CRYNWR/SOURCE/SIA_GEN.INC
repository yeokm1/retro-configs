;*******************************************************************************
;
; SIA_GEN.INC
;
; Include file for Dec Ethernet and Fast Ethernet boards that holds information
; and supporting routines for SIA phy.
;
; Written by:   Moti Haimovsky
; Date:         5-Dec-1995
;
;
; Copyright (C) 1994 by Digital Equipment Corporation
; All rights reserved.
;
; Modification History:
;
;    By              Date      Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; Moti Haimovsky   25-Feb-96   2.32  Fixed eax, dx swapped values problem
;				     in SIAGenGetConnectionStatus.
; Moti Haimovsky  08-Nov-1996  2.50 - Added Phyer preliminary support
; Moti Haimovsky  14-Nov-1996       - Added Tulip3 autosense init support.
;*******************************************************************************

;******************************************************************************
;*            	   	   SIA INTERNAL VARIABLES		      	      *
;******************************************************************************
START_DATA_SEGMENT_RUNTIME

SIANwayLCW	dw	0	 ;Local variable holding SIA adevertised LCW

SIANwayMedium	db	MediaTP  ;The medium to be selectred when wishing to perform Nway
	even

END_DATA_SEGMENT_RUNTIME

;******************************************************************************
;*            	   SIA GENERIC EXTERNAL (EXPORTED) ROUTINES		      *
;******************************************************************************
START_CODE_SEGMENT_INIT

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		SIAGenInit	proc
;
; Description:
;
; On Entry:	
;
;
; On Return:
;		BX - Destroyed
;		AX - Destroyed
;
;		Flags:
;		    Carry set - if no phy was found.
;
;		Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SIAGenInit	proc

	push	ax
	push	bx
	push	si

	;--------------
	;Init SIA entry
	;--------------
	push	bx
	lea	bx, (GenPhyAttribSTRUC PTR [bx]).PhyRoutines[0]
	call	NullPhyExternalRoutines
	pop	bx

	;------------------------
	;Get Sia Phy capabilities
	;------------------------
	mov	si, MediaTP  						;Start with First medium
SiaInit_HandleMedium:
	cmp	si, MediaSymScr                           		;Skip SymScr stuck in the middle
	je	SHORT SiaInit_DoneWithThisMedium
	mov	ax, PHY_TYPE_SIA
	call	GetMediumCapabilities                   		;Get & save medium capbilities
	or	(GenPhyAttribSTRUC PTR [bx]).PhyAbilities.ConnectionCapabilities, ax
SiaInit_DoneWithThisMedium:
	inc	si                                                      ;Advance to next medium
	cmp	si, MediaTpFD                                    	;Tp-FD is the last SYM medium.
	jle	SHORT SiaInit_HandleMedium


	;If we do not have SIA capabilities - No SIA Phy
        ;-----------------------------------------------
	cmp	(GenPhyAttribSTRUC PTR [bx]).PhyAbilities.ConnectionCapabilities, 0
	je	SHORT SiaGI_ErrorExit


	;---------------------------------------------
	;Fill routines entries with supported routines
        ;---------------------------------------------
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyPresence, Present		     ;Mark Phy is present
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyInit,                    offset CGroup:SIAGenInit
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetCapabilities,         offset CGroup:SIAGenGetCapabilities
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhySetCapabilities, 	     offset CGroup:NullRoutine
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhySetConnectionType,       offset CGroup:SIAGenSetConnection
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetConnectionType,       offset CGroup:NullRoutine
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetConnectionStatus,     offset CGroup:SIAGenGetConnectionStatus
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyAdminControl,            offset CGroup:NullRoutine
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyAdminStatus,             offset CGroup:NullRoutine
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PrepareForAsNwayConnection, offset CGroup:NullRoutine

	;-----------------------------------------------------------
	;Fill routines entries with Device specific support routines
	;-----------------------------------------------------------
	;Tulip
        ;-----
	cmp	Nic.Dev, TULIP
	jne	SHORT SiaGI_NotTulip
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PrepareForAsNwayConnection, offset CGroup:TulipPrepareForAsNwayConnection
	jmp	SHORT SiaGI_DoneDevSpecific
SiaGI_NotTulip:

	;Tulip3
        ;------
	cmp	Nic.Dev, TULIP3
	jne	SHORT SiaGI_NotTulip3
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PrepareForAsNwayConnection, offset CGroup:Tulip3PrepareForAsNwayConnection
	jmp	SHORT SiaGI_DoneDevSpecific
SiaGI_NotTulip3:

	;FASTERNET
        ;---------
	cmp	Nic.Dev, FASTERNET
	jne	SHORT SiaGI_NotFasternet
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PrepareForAsNwayConnection, offset CGroup:FnetPrepareForAsNwayConnection
	jmp	SHORT SiaGI_DoneDevSpecific
SiaGI_NotFasternet:

	;Twinet
        ;------
	cmp	Nic.Dev, TWINET
	jne	SHORT SiaGI_NotTwinet
        call	SIATwinetInit
	jmp	SHORT SiaGI_DoneDevSpecific
SiaGI_NotTwinet:


SiaGI_DoneDevSpecific:
SiaGI_Exit:
	pop	si
	pop	bx
	pop	ax
	ret

SiaGI_ErrorExit:
	stc
	jmp	SHORT SiaGI_Exit

SIAGenInit	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:	        SIAGenGetCapabilities	proc
;
; Description:
;
; On Entry:	
;
;
; On Return:
;		Flags:
;		    Carry set - if no phy was found.
;
;		Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SIAGenGetCapabilities	proc

	mov	eax, Phys.PhysEntry[PHY_TYPE_SIA].PhyAbilities.PhyCapabilities
        ret
	
SIAGenGetCapabilities	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:	        SIATwinetInit	proc
;
; Description:
;
; On Entry:	
;
;
; On Return:
;		Flags:
;		
;
;		Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SIATwinetInit	proc

	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PrepareForAsNwayConnection, offset CGroup:TwinetPrepareForAsNwayConnection

	;------------------------
	;Twinet2 has Nway support
        ;------------------------
	cmp	Nic.rev, CFRV_REV2
	jl	SHORT SiaTwI_NotTwinet2

	;If TP media is not present -> No NWAY
	;-------------------------------------
	test	(GenPhyAttribSTRUC PTR [bx]).PhyAbilities.ConnectionCapabilities, Phy10BaseTCapable
	jz	SHORT SiaTwI_NoTwinet2Nway

	mov	Phys.PhysEntry[PHY_TYPE_SIA].PhyAbilities.NwayCapabilities, \
								Nway100BaseT4Capable	or \
								Nway100BaseTxFDCapable  or \
								Nway100BaseTxCapable    or \
								Nway10BaseTFDCapable    or \
								Nway10BaseTCapable

	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetConnectionType,       offset CGroup:SIATwinet2GetConnectionType
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetConnectionStatus,     offset CGroup:SIATwinet2GetConnectionStatus
SiaTwI_NoTwinet2Nway:
SiaTwI_NotTwinet2:
	clc
	ret

SIATwinetInit	endp


END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:	        SIAGenSetConnection	proc
;
; Description:
;
; On Entry:	
;
;
; On Return:
;		Flags:
;		    Carry set - if no phy was found.
;
;		Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SIAGenSetConnection	proc

	push	ax
	push	cx

	;---------------------------------------------------------------------------
	;SIA Phy may support Nway connection so:
	;If AS-Nway connection and ASNwayPhy == SIA_PHY and then Physupports it then
	;	update local Nway variables
	;---------------------------------------------------------------------------
	test	si, (ModeNWAY SHL MEDIA_TYPE_FIELD_SIZE)
	jz	SHORT SiaGSC_DoneNwayConnection
	cmp 	Phys.AsNway.ASNwayPhy, PHY_TYPE_SIA
	jne	SHORT SiaGSC_DoneNwayConnection

	;update Nway variables
        ;---------------------
	mov     Phys.AsNway.ASNwayState.OMStatus, NWAY_CONFIGURING                ;Nway status is config.
	and	dx, Phys.PhysEntry[PHY_TYPE_SIA].PhyAbilities.NwayCapabilities    ;Calac Nway LCW
	mov	SIANwayLCW, dx
	xchg	si, ax                                                            ;Get the medium to perform
	mov	al, SIANwayMedium                                                 ;Nway throgh and update the Nic
	mov	Nic.SelectedMedia, al                                            ;variables.
	xchg	si, ax
SiaGSC_DoneNwayConnection:

	;---------------------------
	;Set internal Phy to medium
        ;---------------------------
	call	SetInternalPhyToConnection
	jc	SHORT SiaGSC_Exit

	;----------------------------------------
	;No External SIA PHY to Set to connection
	;----------------------------------------

SiaGSC_Exit:
	pop	cx
	pop	ax
	ret

SIAGenSetConnection	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:	        SIAGenGetConnectionStatus	proc
;
; Description:
;
; On Entry:	
;
;
; On Return:
;		Flags:
;		    Carry set - if no phy was found.
;
;		Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SIAGenGetConnectionStatus	proc

	mov	ax, PHY_TYPE_SIA
	call	GetMediumLinkStatus
	mov	ah, NWAY_NOT_SUPPORTED
	ret

SIAGenGetConnectionStatus	endp

;******************************************************************************
;*                        TWINET2  SUPPORT  ROUTINES                  	      *
;******************************************************************************
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:	        SIATwinet2GetConnectionType	proc
;
; Description:
;
;	Returns the connection status of Twinet2 according to the following
;	algorithm:
;		Get Connection Status
;		If (ConnectionStatus != Nway_Complete) then
;			return (FAIL)
;		EndIf
;		Read SIA Staus register (CSR12)
;		If (LinkPartnere is Nway able) then
;			Resolve Nway connection
;			return (Resolved connection)
;		Else
;			If (LS100 == LP) then
;				return (100BaseTX)
;			EndIf
;			If (LS10 == LP) then
;				return (10BaseT)
;			EndIf
;			Return (FAIL)
;		EndIf
;
; On Entry:
;
;
; On Return:
;		AX - Connection Type
;
;		Flags:
;		    Carry set - Error
;
;		Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SIATwinet2GetConnectionType	proc

	push	dx
	push	eax

	;---------------------
	;Get Connection Status
        ;---------------------
	call	SIATwinet2GetConnectionStatus

	;-------------------------------------------
	;If (ConnectionStatus != Nway_Complete) then
	;	return (FAIL)
	;-------------------------------------------
	cmp	ah, NWAY_COMPLETE
	jne	SHORT ST2GCT_ErrorExit

	;-------------------------------
	;Read SIA Staus register (CSR12)
        ;-------------------------------
	mov	dx, Nic.CSR12_Address
	in	eax, dx

	;----------------------------------------
	;If (LinkPartnere is Nway able) then
	;	return (Resolve Nway connection)
	;----------------------------------------
	test	eax, CSR12_LPN
	jz	SHORT ST2GCT_LinkPartnerNotNwayAble

	call	SIATWinet2ResolveNwayConnection
	jmp	ST2GCT_Exit

ST2GCT_LinkPartnerNotNwayAble:
	
	;--------------------------------------------------------------------------
	;Else  ;(Partner is not Nway able -> Parallel detection had been performed)
	;	If (LS100 == LP) then
	;		return (100BaseTX)
	;	EndIf
	;	If (LS10 == LP) then
	;		return (10BaseT)
	;	EndIf
        ;	Return (FAIL)
	;EndIf
	;--------------------------------------------------------------------------
	mov	dx, MediaSymScr          ;Assume Media Sym/Scr
	test	eax, CSR12_LF100T
	jz	SHORT ST2GCT_Exit

	mov	dx, MediaTP              ;Assume Media TP
	test	eax, CSR12_LKF
	jz	SHORT ST2GCT_Exit

	jmp	SHORT ST2GCT_ErrorExit   ;No medium found

ST2GCT_Exit:
	pop	eax
	mov	ax, dx
	or      ah, ModeNWAY or ModeAUTOSENSE    ;set operation mode to be NWAY or AutoSense
	pop	dx
	ret

ST2GCT_ErrorExit:
	pop	eax
	pop	dx
	mov	ax, NoSelectedMedia
	stc
        ret

SIATwinet2GetConnectionType	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:	        SIATwinet2GetConnectionStatus	proc
;
; Description:
;	Returns the connection status of Twinet2 according to the following
;	algorithm:
;		Get Nway Status
;		Case (NwayStatus) is
;			When DISABLED 	 ->
;				Return (NwyaDiasabled , GetMediumLinkStatus (si))
;			When CONFIGURING ->
;				Return (NwayConfiguring, MediaStatusUnknown)
;			When COMPLETE	 ->
;				Return (NwayComplete, (GetMediumLinkStatus(100BaseTX) OR GetMediumLinkStatus(10BaseT))
;			Default
;				Return (NwayStatusUnknown, MediaStatusUnknown)
;		EndCase
;
; On Entry:	
;
;
; On Return:
;		Flags:
;		    Carry set - if no phy was found.
;
;		Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SIATwinet2GetConnectionStatus	proc

	push	si

	;---------------
	;Get Nway Status
	;---------------
	call	SIATwinet2GetNwayStatus    ;AH - Holds Nway status

	;-------------------
	;Case Nway status is
	;-------------------

	;-----------------------------------------------------------------
	;	When DISABLED 	 ->
	;		Return (NwyaDiasabled , GetMediumLinkStatus (si))
	;-----------------------------------------------------------------
	cmp	ah, NWAY_DISABLED
	jne	SHORT ST2GCS_NwayNotDisabled
	mov	ax, PHY_TYPE_SIA
	call    GetMediumLinkStatus
	mov	ah, NWAY_DISABLED
	jmp	SHORT ST2GCS_Exit
ST2GCS_NwayNotDisabled:

	;-----------------------------------------------------------
	;	When CONFIGURING ->
	;		Return (NwayConfiguring, MediaStatusUnknown)
	;-----------------------------------------------------------
	cmp	ah, NWAY_CONFIGURING
	jne	SHORT ST2GCS_NwayNotConfiguring
	mov	al, MEDIA_STATE_UNKNOWN
        stc
	jmp	SHORT ST2GCS_Exit
ST2GCS_NwayNotConfiguring:

	;------------------------------------------------------------------------------------------------------
	;	When COMPLETE	 ->
	;		Return (NwayComplete, (GetMediumLinkStatus(100BaseTX) OR GetMediumLinkStatus(10BaseT))
	;------------------------------------------------------------------------------------------------------
	cmp	ah, NWAY_COMPLETE
	jne	SHORT ST2GCS_NwayNotCompleted

        mov	si, MediaTP
	mov	ax, PHY_TYPE_SIA
	call    GetMediumLinkStatus
	cmp	al, MEDIA_LINK_PASS
	je      SHORT ST2GCS_DoneLinkTest

	mov	si, MediaSymScr
	mov	ax, PHY_TYPE_SYM
	call    GetMediumLinkStatus
ST2GCS_DoneLinkTest:

	mov	ah, NWAY_COMPLETE
	jmp	SHORT ST2GCS_Exit
ST2GCS_NwayNotCompleted:

	;-------------------------------------------------------------
	;	Default
	;		Return (NwayStatusUnknown, MediaStatusUnknown)
        ;-------------------------------------------------------------
	mov	ah, NWAY_UNKNOWN
	mov	al, MEDIA_STATE_UNKNOWN

ST2GCS_Exit:
	pop	si
	ret

SIATwinet2GetConnectionStatus	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:	          SIATWinet2ResolveNwayConnection	proc
;
; Description:
;	Returns the resolved connection of Twinet2 according highest common
;	mode found between LCW and Link-Partner Code word (If None -> return Error)
;
; On Entry:	
;	EAX - CSR12 value
;
; On Return:
;	DX - Resolved Connection
;	All other registers  - Preserved
;
;		Flags:
;		    Carry set - Connection Not resolved.
;
;		Note:
;
; Assumes:
;	Link-Partner is Nway able
;	
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SIATWinet2ResolveNwayConnection		proc

	push	eax

	mov	dx, NoSelectedMedia     ;Assume worst case
	shr	eax, 16			;Align Link-partner code WORD

	;-----------------------------------------------------------
	;Check if Nway selector is 802.3 (If not - Can't handle it)
        ;-----------------------------------------------------------
	push	ax                               ;Save original value
	and	ax, NwaySelectorMask             ;Keep only selector bits
	cmp	al, NWAY_802_3_Selector          ;Is it 802.3 selector
	pop	ax                               ;Restor original value
	jne	STw2RNC_ErrorExit

	;-------------
	;Resolve media
        ;-------------
	and	ax, SIANwayLCW			;Create common media word
	jz	SHORT STw2RNC_ErrorExit 	;No common Medium -> Error

	;Is it 100BaseTx FD ?
	mov     dx, Connection100BaseTxFD
	test    ax, Nway100BaseTxFD
	jnz     SHORT STw2RNC_Exit

	;Is it 100BaseT4 ?
	mov     dx, Connection100BaseT4
	test    ax, Nway100BaseT4
	jnz     SHORT STw2RNC_Exit

	;Is it 100BaseTx ?
	mov     dx, Connection100BaseTx
	test    ax, Nway100BaseTx
	jnz     SHORT STw2RNC_Exit

	;Is it 10BaseT FD ?
	mov     dx, ConnectionTPFD
	test    ax, Nway10BaseTFD
	jnz     SHORT STw2RNC_Exit

	;Is it 10BaseT ?
	mov     dx, ConnectionTP
	test    ax, Nway10BaseT
	jnz     SHORT STw2RNC_Exit

STw2RNC_ErrorExit:
	pop	eax
	stc
	ret

STw2RNC_Exit:
	pop	eax
	ret

SIATWinet2ResolveNwayConnection		endp

END_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		SIATwinet2GetNwayStatus  PROC
;
; Description:
;
; On Entry:	
;
; On Return:
;	AH - Holds Nway status
;
;		Flags:
;		    Carry set - Connection Not resolved.
;
;		Note:
;
; Assumes:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
START_DATA_SEGMENT_RUNTIME

SIANwayMachineState	db	NWAY_DISABLED      ;000 -> Nway Disabled
			db      NWAY_CONFIGURING   ;001 -> Transmit Disabled
			db      NWAY_CONFIGURING   ;010 -> Ability detect
			db	NWAY_CONFIGURING   ;011 -> Acknowledge detect
			db	NWAY_CONFIGURING   ;100 -> complete acknowledge
			db	NWAY_COMPLETE      ;101 -> FLP Link good - Nway complete
			db	NWAY_CONFIGURING   ;110 -> Link check
			db	NWAY_UNKNOWN   	   ;111 -> Illegal combination

END_DATA_SEGMENT_RUNTIME

START_CODE_SEGMENT_RUNTIME

	even
SIATwinet2GetNwayStatus		proc

	push    dx
	push	bx
	push    eax

	;Read SIA status register (CSR12)
        ;--------------------------------
	mov	dx, Nic.CSR12_Address
	in	eax, dx

	;Handle Nway status
	;------------------
	shr	ax, 12				;right justify Nway Machine status bits
	and	al, 7           		;Get rid of irrelevant bits
	lea	bx, SIANwayMachineState
        xlat                            	;Convert machine state to Nway status.
	mov     dl, al                  	;move result to ch

	pop	eax
	mov	ah, dl
	pop	bx
	pop	dx
	ret

SIATwinet2GetNwayStatus		endp

END_CODE_SEGMENT_RUNTIME
