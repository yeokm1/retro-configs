;*******************************************************************************
;
; Phys.INC
;
; Include file for Dec Ethernet and Fast Ethernet boards that provids support
; common to all Phys.
;
; Written by:   Moti Haimovsky
; Date:         1-Jul-1996
;
;
; Copyright (C) 1994 by Digital Equipment Corporation
; All rights reserved.
;
; Modification History:
;
;  By              Date        Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; Moti Haimovsky  16-Sep-1996 2.42 -Modified PhysSetConnection routine to call Connection
;                                   dependencies routine (for ML6692 Phy support)
; Moti Haimovsky  08-Jan-1997 2.60 -Removed FD implications handling from
;				    SetInternalPhyToConnection routine. It will now be in
;				    MAC2Phy routines
; Moti Haimovsky  15-Jun-1997 	   -Modified HdwResetMii routine to wait 500mSec for RESET to complete.
;*******************************************************************************
;******************************************************************************
;*                              PHY ENTITY CONSTANTS                          *
;******************************************************************************
;Notice in the scheme that there could be more than one PHY connected to the MAC

;------------------
;PHY Operation Mode
;------------------
PHY_OM_NWAY             equ     MiiPhyNwayCapable
PHY_OM_AUTOSENSE       	equ     PHY_OM_NWAY
PHY_NO_SPECIAL_OM       equ     0

;----------------------------------------------------------------------------
;               PHY routines entries definition tables
;----------------------------------------------------------------------------
PhyExternalRoutinesSTRUC        struc
	PhyInit                 	dw      offset CGroup:NullRoutine
	PhyGetCapabilities      	dw      offset CGroup:NullRoutine
	PhySetCapabilities      	dw      offset CGroup:NullRoutine
	PhySetConnectionType    	dw      offset CGroup:NullRoutine
	PhyGetConnectionType    	dw      offset CGroup:NullRoutine
	PhyGetConnectionStatus  	dw      offset CGroup:NullRoutine
	PhyAdminControl         	dw      offset CGroup:NullRoutine
	PhyAdminStatus          	dw      offset CGroup:NullRoutine
	PrepareForAsNwayConnection	dw	offset CGroup:NullRoutine
PhyExternalRoutinesSTRUC        ends

;----------------
; PHY Definitions
;----------------
GenPhyAttribSTRUC struc
	PhyAbilities    PhyCapabilitiesType          <<0,0>>
	PhyRoutines	PhyExternalRoutinesSTRUC     < >
	PhyPresence     dw                           Absent
GenPhyAttribSTRUC ends


; Autosense support structure
;----------------------------
AutosenseNwaySTRUC	struc
	ASNwayState	 ConnectionStatusType 	< >
	ASNwayPhy     	 dw			PHY_TYPE_UNKNOWN
	NwayLCW		 dw			0
	PowerUpAutosense dw			offset CGroup:NullRoutine
	DynamicAutosense dw			offset CGroup:NullRoutine
	LinkISR		 dw			offset CGroup:NullRoutine
AutosenseNwaySTRUC	ends


;--------------------------------------
; Phys Entries and selection in Mac2Phy
;--------------------------------------
NUM_SUPPORTED_PHYS      equ     3       ;SIA, SYM, MII

PhysSTRUC     struc
	PhysAbilities   PhyCapabilitiesType     <<0,0>>
	SelectedPhy     dw                       PHY_TYPE_UNKNOWN
	NumPhysFound    dw                       0
	AsNway          AutosenseNwaySTRUC 	< >
	PhysEntry  	GenPhyAttribSTRUC  	NUM_SUPPORTED_PHYS dup (<>)
PhysSTRUC     ends

;---------
;PHY types
;---------
PHY_TYPE_MII     	equ     0
PHY_TYPE_SIA     	equ     1 * (SIZE GenPhyAttribSTRUC)
PHY_TYPE_SYM     	equ     2 * (SIZE GenPhyAttribSTRUC)
PHY_TYPE_UNKNOWN 	equ     0FFFFh

;******************************************************************************
;*                        PHYs  External Routines                             *
;******************************************************************************
;	PROC	PhysInit
;	PROC	PhysSetConnection
;	PROC	PhysGetConnectionStatus
;	PROC	GetConnectionPhyType
;	PROC	GetMediumPhyType
;******************************************************************************


START_CODE_SEGMENT_INIT

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       PhysInit     proc
;
;
;       assumes:
;       	
;
;       returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PhysInit	proc

	;Init Phys Variables
	;-------------------
	mov	Phys.PhysAbilities.PhyCapabilities, 0

	;Check and Init the SIA Phy
	;--------------------------
	;All our chips support Sia - check if one is present
	;---------------------------------------------------
	call    SIAInit
	jc      SHORT PI_DoneWithSIA
	inc     Phys.NumPhysFound
PI_DoneWithSIA:

	;Check and Init the Sym Phy
	;--------------------------
	call    SYMInit
	jc      SHORT PI_DoneWithSym
	inc     Phys.NumPhysFound
PI_DoneWithSym:

	 ;Check and Init the MII Phy
	;--------------------------
	call    MiiInit
	jc      SHORT PI_DoneWithMII
	inc     Phys.NumPhysFound
PI_DoneWithMII:

	;Check if we have a Phy to work with
	;-----------------------------------
	cmp     Phys.NumPhysFound, 0
	jne     SHORT PI_Exit

	stc

PI_Exit:
	ret

PhysInit	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;            PhysAdjustNonMiiMedium	proc
;
;        	This routine adjusts Nic.SelectedMedium variable (NOT the chip itself)
;		To be a populated one.
;
;       assumes:
;              	1. Routine is called only when Nic.SelectedOperationMode is Autosense,
;		   Nway or Power-up autosense.
;		2. At least one non-mii medium is present.
;       returns:
;               Nic.SelectedMedia - Modified
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PhysAdjustNonMiiMedium	proc

	push	ax

	;---------------------------------
	;Get full Non-Mii Phys capabilities
        ;---------------------------------
	mov	ax, Phys.PhysEntry[PHY_TYPE_SIA].PhyAbilities.ConnectionCapabilities
	or	ax, Phys.PhysEntry[PHY_TYPE_SYM].PhyAbilities.ConnectionCapabilities

	;Start from TP
	;-------------
        mov	Nic.SelectedMedia, MediaTP
	test	ax, Phy10BaseTCapable
	jnz	SHORT PANMM_Exit

	;BNC
	;---
	mov	Nic.SelectedMedia, MediaBNC
	test	ax, PhyBNCCapable
	jnz	SHORT PANMM_Exit

	;AUI
	;---
	mov	Nic.SelectedMedia, MediaAUI
	test	ax, PhyAUICapable
	jnz	SHORT PANMM_Exit

	;SymSCR
	;------
	mov	Nic.SelectedMedia, MediaSymScr
	test	ax, Phy100BaseTxCapable
	jnz	SHORT PANMM_Exit

	;100BaseFX
	;---------
	mov	Nic.SelectedMedia, Media100BaseFX
	test	ax, Phy100BaseFxCapable
	jnz	SHORT PANMM_Exit

	;TP - full duplex
	;----------------
	mov	Nic.SelectedMedia, MediaTpFD
	test	ax, Phy10BaseTFDCapable
	jnz	SHORT PANMM_Exit

	;SymScr FD  (Last option left)
        ;-----------------------------
	mov	Nic.SelectedMedia, MediaSymScrFD
	test	ax, Phy100BaseTxFDCapable
	jnz	SHORT PANMM_Exit

	;100BaseFxFD (Last option left)
        ;------------------------------
	mov	Nic.SelectedMedia, Media100BaseFX
	test	ax, Phy100BaseTxFDCapable
	jnz	SHORT PANMM_Exit

PANMM_Exit:
	pop	ax
	ret

PhysAdjustNonMiiMedium	endp


END_CODE_SEGMENT_INIT


START_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       PhysSetConnection     proc
;
;
;       assumes:
;              	AX - Phy type (if PHY_TYPE_UNKNOWN - search for the phy)
;		SI - Connection/Media type	
;               Interrupts at any state
;
;       returns:
;              	AX 	- Phy type (if PHY_TYPE_UNKNOWN - search for the phy)
;		SI 	- Connection/Media type
;		Carry   - SET upon error
;               Interrupt state is preserved
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PhysSetConnection	proc

        push	bx
	push	dx
	pushf

	mov	bx, ax        			;Assume Phy is known -> Init BX

	cmp	ax, PHY_TYPE_UNKNOWN
	jne	SHORT PsSC_PhyIsKnown

	call	GetMediumPhyType
	jc	SHORT PsSC_ErrorExit
PsSC_PhyIsKnown:

	;Call the Phy's set connection routine
	;-------------------------------------
	mov	dx, Phys.AsNway.NwayLCW
	lea	bx, Phys.PhysEntry[bx]
        cli
	call	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhySetConnectionType
	jc	SHORT PsSC_ErrorExit

PsSC_Exit:
	popf
	clc
PsSC_Fin:
	pop	dx
        pop	bx
	ret

PsSC_ErrorExit:
	popf
	stc
	jmp	SHORT PsSC_Fin

PhysSetConnection	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		PhysExecuteConnectionDependencies
; Description:
;	       Sets internal Mac2Phy registers to appropriate Phy & connection Type
;	       if such setting is requred due to special p[hy handling/setting.
;	       As for today only Micro-Linear ML6692 needs special handling.
;	      
;
; On Entry:	
; On Return:
;	   All other registers are Preserved
;	
;		Flags:
;		     Carry set - upon failing to set connection 
;                                AX- holding Error code
;Note:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PhysExecuteConnectionDependencies	proc

	push	ax
	push	bx
	push	si

	;------------------------
	;ML6692 Phy Type handling
	;------------------------
	;------------------------------------------------------------------------------
	;ML6692 MII phy requires additional work:
	; When Force SIA TP/TP-FD -> force the MII Phy to TP/TP-FD respectivly.
	; When Autosense          -> Force the SIA to TP (Fasternet) or AUI-AS (Twinet)
	;			     Done in MII GEN module
	;------------------------------------------------------------------------------
	cmp	Nic.MiiPhysList[0].MiiPhySromID, ML6692
	jne	SHORT PECD_Exit

	;In case of ForceMedium which is not an MII medium we must force the Mii
	;Phy to that medium too 
	;-----------------------------------------------------------------------
	test	Nic.SelectedOperationMode, ModeNWAY or ModeAUTOSENSE
	jnz	SHORT PECD_DoneForceML

	cmp	Phys.SelectedPhy, PHY_TYPE_MII
	je	SHORT PECD_Exit

	mov	ax, BRUT_FORCE_CONNECTION                                 ;We do not check for MII presence
	lea	bx, Phys.PhysEntry[PHY_TYPE_MII]                          ;since in worst case the Null routine will
	call	Phys.PhysEntry[PHY_TYPE_MII].PhyRoutines.PhyAdminControl  ;be called.
	jmp	SHORT PECD_Exit
PECD_DoneForceML:


PECD_Exit:
	pop	si
	pop	bx
        pop	ax
	ret

PhysExecuteConnectionDependencies	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		SetInternalPhyToConnection (Phy         IN PhyType
;				     	    Connection 	IN SelectedConnectionType
;                                           Nway        IN NwayAdvertisement type).
; Description:
;	       Sets internal Mac2Phy registers to appropriate Phy & connection Type
;	       and advertised
;	
;
; On Entry:	
;       SI - Connection
;	AX - Phy type
;	DX - NWAYAdvertisment  (if dx==0 -> use Phy's defaults)
;       Interrupts - Must be disabled
; On Return:
;	   All other registers are Preserved
;	
;		Flags:
;		     Carry set - upon failing to set connection
;                                AX- holding Error code
;Note:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SetInternalPhyToConnection	proc

	push	bx

	call	SelectMedium
	jc	SHORT SIPTC_Exit

	;save the Phy type we've selected
        ;--------------------------------
	mov	Phys.SelectedPhy, ax
	mov	bx, si
	mov	Nic.SelectedMedia, bl

SIPTC_Exit:
	pop	bx
	ret

SetInternalPhyToConnection	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       PhysGetConnectionStatus     proc
;
;
;       assumes:
;              	AX - Phy type (if PHY_TYPE_UNKNOWN - search for the phy)
;		SI - Connection/Media type	
;
;       returns:
;		AX - Connection status
;		SI - Connection/Media type
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PhysGetConnectionStatus		proc

	push	bx

	mov	bx, ax        			;Assume Phy is known -> Init BX

	cmp	ax, PHY_TYPE_UNKNOWN
	jne	SHORT PGCS_PhyIsKnown

	call	GetMediumPhyType
	jc	SHORT PGCS_Exit
PGCS_PhyIsKnown:

	;Call the Phy's set connection routine
        ;-------------------------------------
	lea	bx, Phys.PhysEntry[bx]
	call	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetConnectionStatus

PGCS_Exit:
	pop	bx
	ret

PhysGetConnectionStatus		endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       PhysGetConnectionType     proc
;
;
;       assumes:
;              	AX - Phy type (if PHY_TYPE_UNKNOWN - search for the phy)
;
;       returns:
;		AX - Connection TYPE
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PhysGetConnectionType	proc

	push	bx

	mov	bx, ax        			;Assume Phy is known -> Init BX

	cmp	ax, PHY_TYPE_UNKNOWN
	jne	SHORT PGCT_PhyIsKnown

	mov	ax, Phys.SelectedPhy           ;if Phy type Unknown -> use the selected Phy
	mov	bx, ax                         ;for retrieving this info.
	cmp	ax, PHY_TYPE_UNKNOWN
	jne	SHORT PGCT_PhyIsKnown
	stc
	jmp	SHORT PGCT_Exit
PGCT_PhyIsKnown:

	;Call the Phy's get connection routine
        ;-------------------------------------
	lea	bx, Phys.PhysEntry[bx]
	call	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetConnectionType

PGCT_Exit:
	pop	bx
	ret

PhysGetConnectionType	endp

END_CODE_SEGMENT_RUNTIME


START_CODE_SEGMENT_INIT

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         HdwResetMii
;
; Description:
;       Resets the Mii phys
;       We assume that Phy numbers are consucutive/successive
;
; On Entry:
;		Interrupts are at any state but will be ENABLED in the routine.
;
; On Return:
;               Flags:
;
;
;               Note:
;
; returns:
;        	Interrupts state PRESERVED.
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
HdwResetMii     proc

	push    bx
	push	cx
        pushf   				;Save flags.

	;Perform the RESET sequence
        ;--------------------------
	lea     bx, Nic.MiiPhysList[0].GepReset[0]
	call    SetGep

	;Wait 500mSec for RESET to complete (according to MII spec)
	;---------------------------------------------------------- 
	mov	cx, 10000
	push	WORD PTR 120            	;10000 * 50u = 500mSec
HRM_DelayLoop:
	cli
	call	Delay
	sti    					;Let the system breath
	loop	HRM_DelayLoop
	add	sp, 2                           ;Free delay param from stack 

        popf       				;Restor Flags.
	pop	cx
	pop     bx
	ret

HdwResetMii     endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiInit         proc
;
; Description:
;               Initializes the mii module.
; On Entry:
;               NIC already containes the SROM parsed data
;
; On Return:
;               Flags:
;
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiInit         proc

	push	eax
	push	bx


	;Init MII entry
	;--------------
	lea	bx, Phys.PhysEntry[PHY_TYPE_MII].PhyRoutines[0]
	call	NullPhyExternalRoutines

	;IS MII Phy present in SROM? - If not No miiPhy
	;----------------------------------------------
	cmp     Nic.NumMiiPhys, 0
	je      SHORT MI_ErrorExit

	; BX <- Generic PHY entry PTR
        ;----------------------------
	lea     bx, Phys.PhysEntry[PHY_TYPE_MII]

	;MiiPhy is reported in SROM - Init it
	;------------------------------------
	call    HdwResetMii                                    ;Reset the MiiPhy
	call    MiiGenInit                                     ;init the Phys connected to it
	jc      MI_ErrorExit

	;Mark that PHY is PRESENT
	;------------------------
	mov     (GenPhyAttribSTRUC PTR [bx]).PhyPresence, Present    ;Mark Phy is present
	mov     Nic.MiiPhysList[0].MiiPhyPresence, Present         	;Mark Phy is present
	mov     Nic.MiiPhysList[0].MacEntry.MediaPresence, Present	;Validate MacEntry in Mii phy entry

	;Init internal link status routine
	;---------------------------------
	mov     Nic.MiiPhysList[0].MacEntry.InternalLinkSense.InternalSensePresence, Present
	mov	ax, (GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetConnectionStatus
	mov     Nic.MiiPhysList[0].MacEntry.InternalLinkSense.InternalLinkSenseRoutine, ax

	;Set mii phy capabilities
	;------------------------
	call    SetMiiCapabilities

MI_Exit:
	clc
	pop	bx
        pop	eax
	ret

MI_ErrorExit:
	stc
	pop	bx
        pop	eax
	ret

MiiInit         endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         SetMiiCapabilities
;
; Description:
;       sets the Mii phys capabilities
;       We assume that Phy numbers are consucutive/successive
;
; On Entry:
;
;
; On Return:
;               Flags:
;
;
;               Note:
;                    EAX - Destroyed
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SetMiiCapabilities      proc

	;Set Phy capabilities (Both in SROM and in PHY)
	;----------------------------------------------
	;Modify  PHY capabilities
	;------------------------
	xor     eax, eax
	mov     ax, Nic.MiiPhysList[0].NwayAdvertisement_
	shl     eax, 16
	mov     ax, Nic.MiiPhysList[0].MediaCapabilities
	call    (GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhySetCapabilities

	;Get and Save Gen Phy capabilities
	;---------------------------------
	call    (GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetCapabilities
	mov     (GenPhyAttribSTRUC PTR [bx]).PhyAbilities.PhyCapabilities, eax

	ret

SetMiiCapabilities      endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         SymInit         proc
;
; Description:
;               Initializes the Sym PHY.
;               Since Sym does not require special handling this routine
;               will only check for ots presence and return an error if Not present.
; On Entry:
;               NIC already containes the SROM parsed data
;
; On Return:
;               Flags:
;                   Carry SET - No Sym Phy is present.
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SymInit         proc

	push	eax
	push	bx

	; BX <- Generic PHY entry PTR
        ;----------------------------
	lea     bx, Phys.PhysEntry[PHY_TYPE_SYM]

	call    SYMGenInit
	jc	SHORT SYMinit_Exit

	;Get and Save Gen Phy capabilities
	;---------------------------------
	call    (GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetCapabilities
	mov     (GenPhyAttribSTRUC PTR [bx]).PhyAbilities.PhyCapabilities, eax

SYMinit_Exit:
	pop	bx
        pop	eax
	ret

SymInit         endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         SIAInit         proc
;
; Description:
;               Initializes the SIA PHY.
;               Since SIA does not require special handling this routine
;               will only check for ots presence and return an error if Not present.
; On Entry:
;               NIC already containes the SROM parsed data
;
; On Return:
;               Flags:
;                   Carry SET - No SIA Phy is present.
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SIAInit         proc

        push	eax
	push	bx

	; BX <- Generic PHY entry PTR
        ;----------------------------
	lea     bx, Phys.PhysEntry[PHY_TYPE_SIA]
	
	call    SIAGenInit
	jc	SHORT SIAinit_Exit

	;Get and Save Gen Phy capabilities
	;---------------------------------
	call    (GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetCapabilities
	mov     (GenPhyAttribSTRUC PTR [bx]).PhyAbilities.PhyCapabilities, eax

SIAinit_Exit:
	pop	bx
        pop	eax
	ret

SIAInit         endp


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       NullPhyExternalRoutines     proc
;
;		Fills the External routines struc pointed by bx with the address
;		of the Null routine.
;
;       assumes:
;       	bx - Pointer to Phy Externalroutines entry
;
;       returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NullPhyExternalRoutines		proc

	mov     (PhyExternalRoutinesSTRUC PTR [bx]).PhyInit,                 	offset CGroup:NullRoutine
	mov     (PhyExternalRoutinesSTRUC PTR [bx]).PhyGetCapabilities,      	offset CGroup:NullRoutine
	mov     (PhyExternalRoutinesSTRUC PTR [bx]).PhySetCapabilities,      	offset CGroup:NullRoutine
	mov     (PhyExternalRoutinesSTRUC PTR [bx]).PhySetConnectionType,    	offset CGroup:NullRoutine
	mov     (PhyExternalRoutinesSTRUC PTR [bx]).PhyGetConnectionType,    	offset CGroup:NullRoutine
	mov     (PhyExternalRoutinesSTRUC PTR [bx]).PhyGetConnectionStatus,  	offset CGroup:NullRoutine
	mov     (PhyExternalRoutinesSTRUC PTR [bx]).PhyAdminControl,         	offset CGroup:NullRoutine
	mov     (PhyExternalRoutinesSTRUC PTR [bx]).PhyAdminStatus,          	offset CGroup:NullRoutine
	mov	(PhyExternalRoutinesSTRUC PTR [bx]).PrepareForAsNwayConnection, offset CGroup:NullRoutine
	ret

NullPhyExternalRoutines		endp

END_CODE_SEGMENT_INIT


START_CODE_SEGMENT_RUNTIME


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         GetConnectionPhyType (Medium: IN  MediaType,
;                                 Phy   : OUT PhyType )
;
; Description:
;           Returns the Phy type the medium belongs to.
;
; On Entry:
;          SI - Medium
;
; On Return:
;	  SI - Converted medium (according to Phy type).
;         AX - Phy
;         BX - Phy
;               Flags:
;                  Carry SET - Media unknown or can't be associated to one
;                              of the supportes Phys.
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
GetConnectionPhyType	proc

	;If (AS/Nway connection) - Return ASNway Phy
	;Else - Return (GetMeduimPhyType)
	;--------------------------------------------
	test	si, ((ModeNWAY or ModeAUTOSENSE) SHL MEDIA_TYPE_FIELD_SIZE)
	jz	SHORT GCPT_ForceMedium

	cmp	Phys.AsNway.ASNwayPhy, PHY_TYPE_UNKNOWN
	je	SHORT GCPT_ForceMedium
	clc     					;Remove comparisment residues

	mov	bx, Phys.AsNway.ASNwayPhy
	mov	ax, Phys.AsNway.ASNwayPhy
	jmp	SHORT GCPT_Exit

GCPT_ForceMedium:
	call 	GetMediumPhyType
GCPT_Exit:
	ret

GCPT_ErrorExit:
	stc
        ret

GetConnectionPhyType	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         GetMediumPhyType (Medium: IN  MediaType,
;                                 Phy   : OUT PhyType )
;
; Description:
;           Returns the Phy type the medium belongs to.
;
; On Entry:
;          SI - Medium
;
; On Return:
;	  SI - Converted medium (according to Phy type).
;         AX - Phy
;         BX - Phy
;               Flags:
;                  Carry SET - Media unknown or can't be associated to one
;                              of the supportes Phys.
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
GetMediumPhyType        proc


	;If illlegal connection - Return FAIL
	;------------------------------------
	mov     ax, si
	xor     ah, ah
	IsLegalConnection  al
	jc      SHORT GMPT_ErrorExit

	;Convert medium to Phy acpabilities
	;----------------------------------
	call    ConvertConnectionToMediaCapabilities

	;Try MII
	;-------
	mov     bx, PHY_TYPE_MII
	test    ax, Phys.PhysEntry[bx].PhyAbilities.ConnectionCapabilities
	jz      SHORT GMPT_NotMII
	call	ToMiiMedia
        jmp	SHORT GMPT_Exit
GMPT_NotMII:

	;Try SYM or SIA
	;--------------
	mov     bx, PHY_TYPE_SYM
	test    ax, Phys.PhysEntry[bx].PhyAbilities.ConnectionCapabilities
	jz      SHORT GMPT_NotSYM
	jmp	SHORT GMPT_ToSymSiaMedia
GMPT_NotSYM:
	mov     bx, PHY_TYPE_SIA
	test    ax, Phys.PhysEntry[bx].PhyAbilities.ConnectionCapabilities
	jz      SHORT GMPT_ErrorExit
GMPT_ToSymSiaMedia:
	call	ToSiaSymMedia

GMPT_Exit:
	clc

	;ax=bx==Phy type
	;---------------
        mov	ax, bx
	ret

GMPT_ErrorExit:
	stc
	ret

GetMediumPhyType        endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         PROC    CheckPhyConnectionSupport (Connection  : IN ConnectionType,
;                                               GetConnectionRoutinePTR : IN RoutinePTR
;                                               ErrorMessage:  OUT ErrorMessagePTR );
;                                                               RETURNS CompletionStatus
;
; Description:
;             Check if the desired connection is supported by the PHY
;
;
; On Entry:
;       AX - Connection
;       CX - PhyConnectionCapabilities
;
; On Return:
;          All registers are Preserved
;
;               Flags:
;                    Carry set - if connection is not supported
;Note:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
CheckPhyConnectionSupport       proc

	push    ax
	push    cx

	;If Connection is AS/NWAY -> Does the Phy support it ?
	;-----------------------------------------------------
	test    ah, ModeNWAY or ModeAUTOSENSE or ModeAUTODETECT
	jz      SHORT CPCS_DoneWithAsNway
	test    cx, PhyAsNwayCapable
	jz      SHORT CPCS_ErrorExit
	jmp     SHORT CPCS_Exit
CPCS_DoneWithAsNway:


	;Force Medium -> check its legality and presence
	;-----------------------------------------------
	call    ConvertConnectionToMediaCapabilities
	test    cx, ax
	jz      SHORT CPCS_ErrorExit

CPCS_Exit:
	pop     cx
	pop     ax
	clc
	ret

CPCS_ErrorExit:
	pop     cx
	pop     ax
	stc
	ret

CheckPhyConnectionSupport       endp


END_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ConvertConnectionToMediaCapabilitiesBitMask
;                                                (Medium    : IN  MediaType,
;                                                 MiiMedium : OUT MediaCapabilitiesType)
;
; Description:
;
;
; On Entry:
;          AX - Medium
;
; On Return:
;         AX - MiiMedium
;
;               Flags:
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
START_DATA_SEGMENT_RUNTIME

MediaToCapabilitiesConversionTable      dw     Phy10BaseTCapable     ;TP
					dw     PhyBNCCapable         ;BNC
					dw     PhyAUICapable         ;AUI
					dw     Phy100BaseTxCapable   ;100BaseTX \SymScr
					dw     Phy10BaseTFDCapable   ;TP-FD
					dw     Phy100BaseTxFDCapable ;100BaseTX-FD  \SymScr-FD
					dw     Phy100BaseT4Capable   ;100BaseT4
					dw     Phy100BaseFxCapable   ;100BaseFX
					dw     Phy100BaseFxFDCapable ;100BaseFxFD
					dw     Phy10BaseTCapable     ;MediaMiiTP
					dw     Phy10BaseTFDCapable   ;MediaMiiTpFD
					dw     PhyBNCCapable         ;MediaMiiBNC
					dw     PhyAUICapable         ;MediaMiiAUI
					dw     Phy100BaseTxCapable   ;MediaMii100BaseTX
					dw     Phy100BaseTxFDCapable ;MediaMii100BaseTxFD
					dw     Phy100BaseT4Capable   ;MediaMii100BaseT4
					dw     Phy100BaseFxCapable   ;MediaMii100BaseFX
					dw     Phy100BaseFxFDCapable ;MediaMii100BaseFxFD

END_DATA_SEGMENT_RUNTIME

START_CODE_SEGMENT_RUNTIME

ConvertConnectionToMediaCapabilities    proc

	push    si

	;Convert Media code to capability
	;--------------------------------
	movzx   si, al
	shl     si, 1                                       ;Convert media code to table entry.
	mov     ax, MediaToCapabilitiesConversionTable[si]  ;Get capability stored in table Entry.

	pop     si
	ret

ConvertConnectionToMediaCapabilities    endp

END_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         PROC    ToMiiMedia (PhyMedia  : IN MediaCapabilitiesType,
;				       Medium	 : OUT MediaType )
;						        RETURNS CompletionStatus
;
; Description:
; 	Converts PhyMedia to an Mii one
;
;
; On Entry:
;       SI - PhyMedia
;
; On Return:
; 	AX - PhyMedia (Mii Type)
;
;               Flags:
;                    Carry set - if connection is not supported
;Note:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
START_DATA_SEGMENT_RUNTIME

MediaConversionTable      db	MediaMiiTP	 	;TP
			  db    MediaMiiBNC	  	;BNC
			  db    MediaMiiAUI	 	;AUI
			  db    MediaMii100BaseTX    	;100BaseTX \SymScr
			  db    MediaMiiTpFD    	;TP-FD
			  db    MediaMii100BaseTxFD  	;100BaseTX-FD  \SymScr-FD
			  db    MediaMii100BaseT4    	;100BaseT4
			  db    MediaMii100BaseFX    	;100BaseFX
			  db    MediaMii100BaseFxFD  	;100BaseFxFD
			  db    MediaTP      		;MediaMiiTP
			  db    MediaTPFD    		;MediaMiiTpFD
			  db    MediaBNC	  	;MediaMiiBNC
			  db    MediaAUI	  	;MediaMiiAUI
			  db    MediaSymScr    		;MediaMii100BaseTX
			  db    MediaSymScrFD  		;MediaMii100BaseTxFD
			  db    Media100BaseT4    	;MediaMii100BaseT4
			  db    Media100BaseFx    	;MediaMii100BaseFX
			  db    Media100BaseFxFD	;MediaMii100BaseFxFD
END_DATA_SEGMENT_RUNTIME

START_CODE_SEGMENT_RUNTIME

ToMiiMedia	proc

	push	ax

        mov	ax, si
	and	si, 0FFh		;Get rid of OM Bits

	;If already Mii Media -> Done
	;----------------------------
	cmp	si, MAX_MEDIA_TABLE
	jge	SHORT TMM_Exit

	;Convert to Mii Media
	;--------------------
	mov	al, BYTE PTR MediaConversionTable[si]

TMM_Exit:
	mov	si, ax
	pop	ax	
	ret

ToMiiMedia	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         PROC    ToSiaSymMedia (PhyMedia  : IN MediaCapabilitiesType,
;				       Medium	 : OUT MediaType )
;						        RETURNS CompletionStatus
;
; Description:
; 	Converts PhyMedia to a SIA or Sym  one
;
;
; On Entry:
;       AX - PhyMedia
;       SI - Media
; On Return:
; 	AX - Converted Media )
;
;               Flags:
;                    Carry set - if connection is not supported
;Note:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ToSiaSymMedia	proc

	push	ax

        mov	ax, si
	and	si, 0FFh		;Get rid of OM Bits

	;If already SIA/SYM Media -> Done
	;--------------------------------
	cmp	si, MAX_MEDIA_TABLE
	jl	SHORT TSSM_Exit

	;Convert to SIA/SYM Media
	;------------------------
	movzx	ax, BYTE PTR MediaConversionTable[si]

TSSM_Exit:
	mov	si, ax
	pop	ax	
	ret

ToSiaSymMedia	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MACRO ConnectionCapabilitiesToNway
;
; Description:
;
;
;
; On Entry:
;
; On Return:
;Assumes:
;       Connection capabilities are passed in a register
;
;               Flags:
;Note:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ConnectionCapabilitiesToNway    macro   ConnCap

	and     ConnCap, NwayCapableMediaList   ;Keep only Nwayable media
	shr     ConnCap, 6                      ;Align it to Nway local advertisement bits location.
endm

END_CODE_SEGMENT_RUNTIME
