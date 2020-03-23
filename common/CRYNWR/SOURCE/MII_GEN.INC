;*******************************************************************************
;
; MII_GEN.INC
;
; Include file for Dec Fast Ethernet board that holds information
; and supporting routines for MII phy chips (if any).
;
; Assumptions:
;      1. Supporting Nics with 1 Mii Phy.
;           As for today we support only 1 Mii phy this is done in-order
;	    to shorten development time and since that the probability for
;	    multiple phys in the same nic is low.
;
; Written by:   Moti Haimovsky
; Date:         8-Oct-1995
;
;
; Copyright (C) 1994 by Digital Equipment Corporation
; All rights reserved.
;
; Modification History:
;
; By              Date        Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; Moti Haimovsky  24-Oct-1995 2.20 - Added MiiGenSetCapabilities routine
; Moti Haimovsky   9-Nov-1995      - Modified MiiGenSetCapabilities to update
;				     MiiGen capabilities variable.
; Moti Haimovsky   4-Feb-1996 2.31 - Minor modifications
; Moti Haimovsky  16-Jun-1996 2.40 - Modified MiiPhySetConnection
;				     Changed Phys variable name to MiiPhys
; Moti Haimovsky  16-Sep-1996 2.42 - Modified MiiGenSetInternalPhyToConnection in order to support
;				     ML Phy in AS mode
;*******************************************************************************
;******************************************************************************
;*                 SYM GENERIC EXTERNAL (EXPORTED) ROUTINES                   *
;******************************************************************************
;       PACKAGE   SymGen   IS
;
;               PROC    MiiGenInit  (ErrorMessage  OUT ErrorMessagePTR  );
;                                    RETURNS CompletionStatus
;
;               PROC    MiiGenGetCapabilities  (Capabilities : OUT PhyCapabilitiesType,
;                                               ErrorMessage : OUT ErrorMessagePTR );
;                                               RETURNS CompletionStatus
;
;               PROC    MiiGenSetCapabilities  (Capabilities : IN PhyCapabilitiesType,
;                                               ErrorMessage : OUT ErrorMessagePTR );
;                                               RETURNS CompletionStatus
;
;               PROC    MiiGenSetConnectionType (Connection  : IN  PhyConnectionType,
;                                                ErrorMessage: OUT ErrorMessagePTR );
;                                                RETURNS CompletionStatus
;
;               PROC    MiiGenGetConnectionType (DriverMode  : IN  DriverModeType,
;                                                Connection  : OUT ConnectionType,
;                                                ErrorMessage: OUT ErrorMessagePTR );
;                                                RETURNS CompletionStatus
;
;               PROC    MiiGenGetConnectionStatus (Connection  : IN ConnectionType,
;                                                  ErrorMessage:  OUT ErrorMessagePTR );
;                                                  RETURNS CompletionStatus
;
;               PROC    MiiGenAdminControl (Control : IN ControlType,
;                                           ErrorMessage: OUT ErrorMessagePTR );
;                                           RETURNS CompletionStatus
;
;               PROC    MiiGenAdminStatus (Status : Out AdminStatusType,
;                                          ErrorMessage: OUT ErrorMessagePTR );
;                                          RETURNS CompletionStatus
;
;               PROC    MiiPrepareForAsNwayConnection ( );
;
;       END   SymGen
;******************************************************************************
include  Mii_Phy.inc

;******************************************************************************
;*            		     	GENERAL CONSTANTS			      *
;******************************************************************************
;Phy Numbers and numbering (- PhyNumberType)
;-------------------------------------------
MAX_NUM_OF_SUPPORTED_PHYS       equ	1    ;Manually change # of phys in
					     ;MiiPhysSTRUC due to bug in TLINK
NO_SELECTED_PHY			equ	0FFh
FIRST_PHY			equ	0

;******************************************************************************
;*     MII PHYS Module interface (Exported data structues and routines)       *
;******************************************************************************
	;----------------------------------------------------------
	;This Line was commented out due to a bug in Borland linker
	;(TLINK) Which hanged at link time when this line appeared
	;------------------------------------------------------------
	;Phys	MiiPhySTRUC	MAX_NUM_OF_SUPPORTED_PHYS	dup (<>)
	;and the following line replaced it:
	;Phys	MiiPhySTRUC<>
	;------------------------------------------------------------

MiiGenSTRUC	struc
	NumMiiPhysFound		dw	0
	CombinedCapabilities	PhyCapabilitiesType <<0,0>>
	SelectedMiiPhy          dw 	NO_SELECTED_PHY		; 0 meaning also that all phys are isolated
	MiiPhys			MiiPhySTRUC<>
MiiGenSTRUC	ends

START_DATA_SEGMENT_RUNTIME

;Data structure which holds Phys' data
;-------------------------------------
MiiGen	MiiGenSTRUC <>

;Variable to hold the SIA medium to put Decchip to when prerforming MII autosense
;When Phy tupe il MicroLinear 6692
;---------------------------------------------------------------------------------
MiiAsML6692SiaMedium	dw	MediaTP

END_DATA_SEGMENT_RUNTIME

;******************************************************************************
;*            	   MII GENERIC EXTERNAL (EXPORTED) ROUTINES		      *
;******************************************************************************
START_CODE_SEGMENT_INIT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		MiiGenInit	proc
;
; Description:
; 		This Routine Is called when we wish to initialize the module
;		before starting to work with it.
;		- Initializes its internal structures.
;		- Calls FindMiiPhysProc for finding the first Phy in the Nic
;		- If A phy ws found then
;		     - Calls phy's init routine.
;		     - Gets Phy's capabilities and saves them as the Generic
;		       phy capabilities.
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
MiiGenInit	proc

	push	eax

	;Find the first Phy connected
	;----------------------------
	mov	MiiGen.NumMiiPhysFound, 0   ;Init Num of Phys found
	call	FindAndInitMiiPhys
	cmp	MiiGen.NumMiiPhysFound, 0   ;No Phy was found !
	je	SHORT MGI_ErrorExit

	;Get Generic PHY capabilities
	;----------------------------
	push	bx                                                              ;Save GenPhyEntry PTR
	lea     bx, MiiGen.MiiPhys[0]                                  		;Let bx point at first Phy entry.
	call    (MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyGetCapabilities   	;Get Phy's capabilities
	pop	bx                                                              ;Restor GenPhyEntry PTR
	or      MiiGen.CombinedCapabilities.PhyCapabilities, eax 	   	;Update General Phys' capabilities
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyAbilities.PhyCapabilities, eax

	;write Selected phy# (to be the Phy found which is always 0)
	;----------------------------------------------------------
        mov	MiiGen.SelectedMiiPhy, FIRST_PHY


	;Fill routines entries with supported routines
	;---------------------------------------------
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyPresence, Present			;Mark Phy is present
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyInit,                 	offset CGroup:MiiGenInit
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetCapabilities,      	offset CGroup:MiiGenGetCapabilities
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhySetCapabilities, 		offset CGroup:MiiGenSetCapabilities
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhySetConnectionType,    	offset CGroup:MiiGenSetConnection
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetConnectionType,       	offset CGroup:MiiGenGetConnection
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetConnectionStatus,  	offset CGroup:MiiGenGetConnectionStatus
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyAdminControl,            	offset CGroup:MiiGenAdminControl
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyAdminStatus,          	offset CGroup:MiiGenAdminStatus
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PrepareForAsNwayConnection,	offset CGroup:MiiPrepareForAsNwayConnection


MGI_Exit:
	pop	eax
	clc		;Clear Error indication
	ret

MGI_ErrorExit:
	pop	eax
	stc
	ret

MiiGenInit	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		MiiGenGetCapabilities (PhyCapabilities OUT PhysCapabilitiesType)
;					
;
; Description:
;	 	Returns the Generic Phy capabilities
;
; On Entry:	
;
; On Return:
;        AX   - Phys capabilities (in status reg format).
;
;		Flags:
;		
;
;		Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiGenGetCapabilities	proc

	mov	eax, MiiGen.CombinedCapabilities.PhyCapabilities
	ret

MiiGenGetCapabilities	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		MiiGenSetCapabilities (PhyCapabilities IN PhysCapabilitiesType)
;					
;
; Description:
;	 	Sets the Generic Phy MEDIA(!) capabilities
;
; On Entry:	
;
; On Return:
;        AX   - Phys capabilities (in status reg format).
;
;		Flags:
;		
;
;		Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiGenSetCapabilities	proc

	push	eax
	push	bx

	;Bx to point at Phys structure
	lea	bx, MiiGen.MiiPhys[0]

	;Set Phy's capabilities
	;----------------------
	call	(MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhySetCapabilities   	;Set Phy's capabilities

	;Modify MiiGen capabilities according to New MiiPhy capabilities
	;---------------------------------------------------------------
	call	(MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyGetCapabilities       ;Get Phy's capabilities
	mov	MiiGen.CombinedCapabilities.PhyCapabilities, eax    		;Update General Phys' capabilities

	pop	bx
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyAbilities.PhyCapabilities, eax
	pop	eax
	ret

MiiGenSetCapabilities	endp

END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_RUNTIME
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		MiiGenSetConnection (Connection 	IN SelectedConnectionType
;				     NwayAdvertisement  IN word)
;
; Description:
;	       Sets Phy's connection to the desired connection and advertised
;	
;	      (Phy will remain Isolated and selecting one of them will
;	       be done via the Admin control procedure).
;		endif
;
;
; On Entry:	
;       SI - Connection
;	DX - NWAYAdvertisment  (if dx==0 -> use Phy's defaults)
;
; On Return:
;	   All other registers are Preserved
;	
;		Flags:
;		     Carry set - upon failing to set connection
;                                AX- holding Error code
;Note:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiGenSetConnection	proc

        push	ax
	push	bx
        push	cx
	push	si

	;------------------------
	;Check connection support
        ;------------------------
	mov	cx, Phys.PhysEntry[PHY_TYPE_MII].PhyAbilities.ConnectionCapabilities
        mov	ax, si
	call	CheckPhyConnectionSupport
	jc	SHORT MGSC_Exit


	;------------------------------
	;Set internal Phy to connection
        ;------------------------------
	call	MiiGenSetInternalPhyToConnection

	;----------------------------------
	;Set the External PHY to connection
	;----------------------------------
	mov	dx, Phys.AsNway.NwayLCW						;DX to hold NwayLCW
	lea	bx, MiiGen.MiiPhys[0]                                           ;Bx to point at Phys structure
	mov     ax, si                                     			;AX - Connection
	call	(MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhySetConnectionType   	;Set Phy's connection
	jc      SHORT MGSC_Exit
                                                
	;Put Phy in operational mode
        ;---------------------------
	mov     ax, OPERATIONAL                			     		;It is an MiiPhy media -> cx holds Phy#,
	call    (MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyAdminControl		;Select the desired Phy

MGSC_Exit:
	pop	si
	pop	cx
	pop	bx
        pop	ax
	ret

MiiGenSetConnection	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		MiiGenSetInternalPhyToConnection (Connection 	IN SelectedConnectionType
;				     		  NwayAdvertisement  IN word)
;
; Description:
;	       Sets Phy's connection to the desired connection and advertised
;	      
;	      (Phy will remain Isolated and selecting one of them will
;	       be done via the Admin control procedure).
;		endif
;
;
; On Entry:	
;       SI - Connection
;	DX - NWAYAdvertisment  (if dx==0 -> use Phy's defaults)
;
; On Return:
;	   All other registers are Preserved
;	
;		Flags:
;		     Carry set - upon failing to set connection 
;                                AX- holding Error code
;Note:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiGenSetInternalPhyToConnection	proc

	push	ax
	push	si

	;---------------------------------------------------
	;If AS-Nway connection and ASNwayPhy == MII_PHY then
	;	update local Nway variables
	;--------------------------------------------------- 
	test	si, ((ModeNWAY or ModeAUTOSENSE) SHL MEDIA_TYPE_FIELD_SIZE)
	jz	SHORT MGSIC_DoneNwayConnection
	cmp 	Phys.AsNway.ASNwayPhy, PHY_TYPE_MII
	jne	SHORT MGSIC_DoneNwayConnection
	mov     Phys.AsNway.ASNwayState.OMStatus, NWAY_CONFIGURING

	;------------------------------------------------------------------------------
	;ML6692 MII phy requires additional work:
	; When Autosense          -> Force the SIA to TP (Fasternet) or AUI-AS (Twinet)
	;------------------------------------------------------------------------------
	cmp	Nic.MiiPhysList[0].MiiPhySromID, ML6692
	jne	SHORT MGSIC_SetMiiInternal

	mov     si, MiiAsML6692SiaMedium			  	 ;Get SIA medium to set Decchip to
	mov     ax, PHY_TYPE_SIA                                         ;Phy type is SIA (ofcourse)
	call    SetInternalPhyToConnection				 ;Set Decchip to desired medium
	jc	SHORT MGSIC_SetMiiInternal                                ;If failed setting Chip - set it to Mii
	jmp	SHORT MGSIC_Exit
MGSIC_DoneNwayConnection:

MGSIC_SetMiiInternal:
	mov	ax, PHY_TYPE_MII
	call	SetInternalPhyToConnection

MGSIC_Exit:
	pop	si
	pop	ax
	ret

MiiGenSetInternalPhyToConnection	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		MiiGenGetConnectionStatus (ConnectionStatus OUT ConnectionStatusType)
;
; Description:
;		Returns the connection status of the Phy
;
; On Entry:	
;
; On Return:
;       AX - ConnectionStatus
;		Flags:
;		    Carry set Upon Status "error" (Nway configuring or Link-Fail)
;
;		Note:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiGenGetConnectionStatus	proc

	push	bx
	lea	bx, MiiGen.MiiPhys[0]  				;BX - Pointr to Phys data
	call	(MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyGetConnectionStatus
	pop	bx
	ret

MiiGenGetConnectionStatus	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		MiiGenGetConnection (Connection    OUT  SelectedConnectionType)
;
; Description:
;		Returns the connection type of the Phy if possible (Phy Nway
;		is either disabled or completed).
;
; On Entry:	
;
; On Return:
;       AX - Connection
;		Flags:
;		    Carry set Upon error  (AX = MAC_CONN_UNKNOWN)
;
;		Note:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiGenGetConnection	proc

	push	bx

	lea	bx, MiiGen.MiiPhys[0]  				;BX - Pointr to Phys data

	;Is the PHY in a "stable" state ?
        ;--------------------------------
	call	(MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyGetConnectionStatus
	jc	SHORT MGGC_ErrorExit				;NWAY Not in stable state or Link_Fail.

	;Phy is in a stable state - get Connection
        ;-----------------------------------------
	call	(MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyGetConnectionType

MGGC_Exit:
	pop	bx
	ret

MGGC_ErrorExit:
	mov	ax, MAC_CONN_UNKNOWN
	stc
	jmp	SHORT MGGC_Exit

MiiGenGetConnection	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		MiiGenAdminStatus (AdminStatus OUT AdminStatusType)
;
; Description:
;	Returnes the Admin status of the PHY.
;
; On Entry:	
;
; On Return:
;       AX - AdminStatus
;		Flags:
;		
;
; Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiGenAdminStatus	proc

	push	bx

	;Get Phy Status
        ;--------------
	lea	bx, MiiGen.MiiPhys[0]
	call	(MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyAdminStatus       ;read Phy's status

MGAS_Exit:
	pop	bx
	ret

MiiGenAdminStatus	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		MiiGenAdminControl  (AdminControl OUT	Word)
;
; Description:
;		Performs the requested Admin control on the Phy.
;
; On Entry:	
;       AX - AdminControl
;
; On Return:
;
;		Flags:
;			Carry SET upon Failure.
;
;		Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiGenAdminControl	proc

	push	ax
	push	bx

	lea	bx, MiiGen.MiiPhys[0]		;Bx - pointer to first Phy data

	;Perform the operation on the Phy
	;--------------------------------
MGAC_PerformCommand:
	call	(MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyAdminControl        ;Perform command

	;Perform Generic phy operations related to the specified command
	;---------------------------------------------------------------
	cmp	ax, RESET                  	   ;Is it Reset mode handling
	je	SHORT MGAC_CommandReset
	cmp	ax, OPERATIONAL                    ;Is it operational mode handling
	je	SHORT MGAC_CommandOperational
	cmp	ax, STANDBY                    	   ;Is it Standby mode handling
	je	SHORT MGAC_CommandStadby
	cmp	ax, POWERDOWN                      ;Is it Shutdown mode handling
	je	SHORT MGAC_CommandShutdown
	cmp	ax, BRUT_FORCE_CONNECTION	   ;Is it brut force medium handling ?
	je	SHORT MGAC_Exit                    ;If so - Done

	;If reached this point Unknown command
	;-------------------------------------
	stc
	jmp	SHORT MGAC_ErrorExit

MGAC_CommandReset:
	;Move Phy to operational mode after reset
	;----------------------------------------
	mov	ax, OPERATIONAL
	jmp	SHORT MGAC_PerformCommand

MGAC_CommandOperational:
	;Update selectedPhy parameter
	;----------------------------
	mov	MiiGen.SelectedMiiPhy, FIRST_PHY      		;Update selected phy#
	jmp	SHORT MGAC_Exit
MGAC_CommandStadby:
MGAC_CommandShutdown:
	;Update selectedPhy parameter
	;----------------------------
	mov	MiiGen.SelectedMiiPhy, NO_SELECTED_PHY     	;Update selected phy#

MGAC_Exit:
	clc
MGAC_ErrorExit:
	pop	bx
	pop	ax
	ret

MiiGenAdminControl	endp

END_CODE_SEGMENT_RUNTIME

;******************************************************************************
;*            	   	MII GENERIC INTERNAL ROUTINES		      	      *
;******************************************************************************
START_CODE_SEGMENT_INIT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:		FindAndInitMiiPhysProc 	proc
;
; Description:
; 		This Routine Scans the entire Nic's Phys address space and
;		for a PHY and Initializes each phy found .
;
; On Entry:	
;
;
; On Return:
;		Flags:
;		
;
;		Note:
;		     Today we only support 1 Phy meaning that this routine exit
;		     after the first Phy found.
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
FindAndInitMiiPhys	proc

	push	bx
	push	dx

	lea	bx, MiiGen.MiiPhys[0]		;bx points at the begining of the phys struc.
	xor	dx, dx                   	;Start from address 0

FAIMP_SearchForAPhy:
	;Is there a Phy in this address?
        ;-------------------------------
	mov	(MiiPhySTRUC PTR [bx]).MiiPhyAddress, dl
	call	MiiPhyInit
	jc	SHORT FAIMP_DoneWithThisPhy

	;Found a Phy - Handle it
        ;-----------------------
	inc	MiiGen.NumMiiPhysFound	       ;inc # of phys found
	jmp	SHORT FAIMP_SearchCompleted
FAIMP_DoneWithThisPhy:

	;Try to find a Phy in the next address
        ;-------------------------------------
	inc	dx                              ;Look at next PHY address.
	cmp	dx, MAX_PHYADD                  ;did we pass the legal address range ?
	jl	SHORT FAIMP_SearchForAPhy

FAIMP_SearchCompleted:
	pop	dx
        pop	bx
	ret

FindAndInitMiiPhys	endp

END_CODE_SEGMENT_INIT

