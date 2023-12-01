;*******************************************************************************
;
; SYM_GEN.INC
;
; Include file for Dec Ethernet and Fast Ethernet boards that holds information
; and supporting routines for SIA phy.
;
; Written by:   Moti Haimovsky
; Date:         7-Dec-1995
;
;                                       
; Copyright (C) 1994 by Digital Equipment Corporation
; All rights reserved.
;
; Modification History:
;
; By              Date        Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; Moti Haimovsky   25-Feb-96   2.32  Fixed eax, dx swapped values problem
;				     in SYMGenGetConnectionStatus.
; Moti Haimovsky   17-Jun-96   2.40  Modified module to support indirect routine calls.
;*******************************************************************************
;******************************************************************************
;*                 SYM GENERIC EXTERNAL (EXPORTED) ROUTINES                   *
;******************************************************************************
;       PACKAGE   SymGen   IS
;
;               PROC    SymGenInit  (ErrorMessage  OUT ErrorMessagePTR  );
;                                    RETURNS CompletionStatus
;
;               PROC    SymGenGetCapabilities  (Capabilities : OUT PhyCapabilitiesType,
;                                               ErrorMessage : OUT ErrorMessagePTR );
;                                               RETURNS CompletionStatus
;
;               PROC    SymGenSetCapabilities  (Capabilities : IN PhyCapabilitiesType,
;                                               ErrorMessage : OUT ErrorMessagePTR );
;                                               RETURNS CompletionStatus
;
;               PROC    SymGenSetConnectionType (Connection  : IN  PhyConnectionType,
;                                                ErrorMessage: OUT ErrorMessagePTR );
;                                                RETURNS CompletionStatus
;
;               PROC    SymGenGetConnectionType (DriverMode  : IN  DriverModeType,
;                                                Connection  : OUT ConnectionType,
;                                                ErrorMessage: OUT ErrorMessagePTR );
;                                                RETURNS CompletionStatus
;
;               PROC    SymGenGetConnectionStatus (Connection  : IN ConnectionType,
;                                                  ErrorMessage:  OUT ErrorMessagePTR );
;                                                  RETURNS CompletionStatus
;
;               PROC    SymGenAdminControl (Control : IN ControlType,
;                                           ErrorMessage: OUT ErrorMessagePTR );
;                                           RETURNS CompletionStatus
;
;               PROC    SymGenAdminStatus (Status : Out AdminStatusType,
;                                          ErrorMessage: OUT ErrorMessagePTR );
;                                          RETURNS CompletionStatus
;
;               PROC    PrepareForAsNwayConnection ( );
;                                          
;       END   SymGen
;******************************************************************************
START_CODE_SEGMENT_INIT 

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:	        SYMGenInit	proc
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
SYMGenInit	proc

        push	ax
	push	bx
	push	si

	;Init SYM entry
	;--------------
        push	bx
	lea	bx, (GenPhyAttribSTRUC PTR [bx]).PhyRoutines[0]
	call	NullPhyExternalRoutines
	pop	bx

	;Get SYM Phy capabilities
	;------------------------
	mov	si, MediaSymScr  					;Start with first SYM medium
SymInit_HandleMedium:
	cmp	si, MediaTPFD                           		;Skip TPFD stuck in the middle
	je	SHORT SymInit_DoneWithThisMedium
	mov	ax, PHY_TYPE_SYM
	call	GetMediumCapabilities                   		;Get & save medium capbilities
	or	(GenPhyAttribSTRUC PTR [bx]).PhyAbilities.ConnectionCapabilities, ax
SymInit_DoneWithThisMedium:
	inc	si                                                      ;Advance to next medium
	cmp	si, Media100BaseFxFD                                    ;100BaseFX is the last SYM medium.
	jle	SHORT SymInit_HandleMedium

	;If we do not have SYM capabilities - No SYM Phy
        ;-----------------------------------------------
	cmp	(GenPhyAttribSTRUC PTR [bx]).PhyAbilities.ConnectionCapabilities, 0
	je	SHORT SymGI_ErrorExit

	;Fill routines entries with supported routines
        ;---------------------------------------------
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyPresence, Present		     ;Mark Phy is present
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyInit,                    offset CGroup:SYMGenInit
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetCapabilities,         offset CGroup:SYMGenGetCapabilities
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhySetCapabilities, 	     offset CGroup:NullRoutine
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhySetConnectionType,       offset CGroup:SYMGenSetConnection
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetConnectionType,       offset CGroup:NullRoutine
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyGetConnectionStatus,     offset CGroup:SYMGenGetConnectionStatus
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyAdminControl,            offset CGroup:NullRoutine
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PhyAdminStatus,             offset CGroup:NullRoutine
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PrepareForAsNwayConnection, offset CGroup:NullRoutine


	;Init PrepareForAsNwayConnection routine entry according to the dev type
        ;------------------------------------------------------------------------
	cmp	Nic.Dev, TWINET
	jne	SHORT SymGI_NotTwinet
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PrepareForAsNwayConnection, \
						offset CGroup:TwinetPrepareForAsNwayConnection
	jmp	SHORT SymGI_DoneAsPrep
SymGI_NotTwinet:

	cmp	Nic.Dev, FASTERNET
	jne	SHORT SymGI_NotFnet
	mov	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PrepareForAsNwayConnection, \
						offset CGroup:FnetPrepareForAsNwayConnection
	jmp	SHORT SymGI_DoneAsPrep
SymGI_NotFnet:


SymGI_DoneAsPrep:
SymGI_Exit:
	clc
	pop	si
	pop	bx
        pop 	ax
	ret

SymGI_ErrorExit:
	stc
	pop	si
	pop	bx
        pop 	ax
	ret

SYMGenInit	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:	        SYMGenGetCapabilities	proc
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
SYMGenGetCapabilities	proc

	mov	eax, Phys.PhysEntry[PHY_TYPE_SYM].PhyAbilities.PhyCapabilities
        ret

SYMGenGetCapabilities	endp

END_CODE_SEGMENT_INIT 

START_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:	        SYMGenSetConnection	proc
;
; Description:
;
; On Entry:
; 		SI - Connection              
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
SYMGenSetConnection	proc

	push	ax
	push	cx

	;----------------------------------------------
	;SYM Phy Does NOT support Nway connection so 
	;	No need to update local Nway variables
	;----------------------------------------------

	;---------------------------
	;Set internal Phy to medium
        ;---------------------------
	mov	ax, PHY_TYPE_SYM
	call	SetInternalPhyToConnection

	;----------------------------------------
	;No External SYM PHY to Set to connection
	;----------------------------------------

SymGSC_Exit:
	pop	cx
	pop	ax
	ret

SYMGenSetConnection	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:	        SYMGenGetConnectionStatus	proc
;
; Description:
;
; On Entry:
; 		SI - Connection
;
; On Return:
; 		SI - Connection
;               AX - Connection Status
;
;		Flags:
;		   
;
;		Note:   
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SYMGenGetConnectionStatus	proc

	mov	ax, PHY_TYPE_SYM
	call	GetMediumLinkStatus
	mov	ah, NWAY_NOT_SUPPORTED

	ret

SYMGenGetConnectionStatus	endp

END_CODE_SEGMENT_RUNTIME


