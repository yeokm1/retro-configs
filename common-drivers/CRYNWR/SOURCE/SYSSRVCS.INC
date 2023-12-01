;*******************************************************************************
;
; SysSrvcs.INC
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
;  By              Date        Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; Haimovsky Moti   13-Apr-1997 2.60 - Added MAX_INTERRUPT constant.
;*******************************************************************************

;******************************************************************************
;*                	S Y S T E M    S E R V I C E S                        *
;******************************************************************************
;
; The following structures are used all over the place when splitting up
; DWORD accesses into two WORD accesses. They are functionally identical,
; however, the two sets of names make more sense in context when dealing
; with FAR pointers and DWORD variables.
;
LONG_PTR  STRUC
_off      DW ?  ; offset of FAR pointer
_seg      DW ?  ; segment of FAR pointer
LONG_PTR  ENDS

DWORD_PTR  STRUC
_loword   DW ?  ; low order word of a DWORD type
_hiword   DW ?  ; high order word of a DWORD type
DWORD_PTR  ENDS

;******************************************************************************
;*                S Y S T E M   B U S   S E R V I C E S                       *
;******************************************************************************

;-----------------------------------------------
;*                   P C I                     *
;-----------------------------------------------
	;------------------------
	;	PCI Codes
	;------------------------
PCI_EHETHERNET_CLASS_CODE       equ   	020000h   ;To be used when calling FindPciClassCode..

;---------------------------------
;PCI Config Space registers Layout
;---------------------------------
PCICSRstruc 	struc
	PCI_CFID             dd      ?          ;Configuration ID reg.
	PCI_CFCS             dd      ?          ;Configuration command/status
	PCI_CFRV             dd      ?          ;Configuration revision
	PCI_CFLT             dd      ?          ;Configuration latency timer
	PCI_CBIO             dd      ?          ;Configuration base IO address
	PCI_CBMA             dd      ?          ;Configuration base memory address (Not used)
	PCI_NotUsed0         dd      6 dup (?)  ;Unimplemented config. regs.
	PCI_CBER             dd      ?          ;Expansion ROM base address (TULIP3 only).
	PCI_NotUsed1         dd      2 dup (?)  ;Unimplemented config. regs.
	PCI_CFIT             dd      ?          ;Configuration interrupt reg.
	PCI_CFDA             dd      ?          ;Configuration driver area reg.
PCICSRstruc	ends

PCI_CFID_OFFSET		EQU	00h
PCI_CFCS_OFFSET	       	EQU 	04h
PCI_CFRV_OFFSET	       	EQU 	08h
PCI_CFLT_OFFSET	       	EQU 	0Ch
PCI_CBIO_OFFSET	       	EQU 	10h
PCI_CFIT_OFFSET	       	EQU 	3Ch
PCI_CFDA_OFFSET	       	EQU 	40h

;----------------------
;PCI chipset parameters
;----------------------

;PCI Host bridges
;----------------
SATURN_CDC_CFID_VAL		equ     04838086h ;0483h is DCD chip ID,  8086h is Intel
SATURN_PCMC_CFID_VAL		equ     04A38086h ;04A3h is PCMC chip ID, 8086h is Intel
OPTI_C832_CFID_VAL		equ    0C8321045h ;C832h is C832 chip ID, 1045h is Opti
ORION_CFID_VAL			equ     84C48086h ;84C4h is ORION chip ID,8086h is Intel

;These bit masks are used to describe CS_Capabilities / Limitations
;------------------------------------------------------------------
TURBO_capable	equ       1B
PBL_MaxLimited	equ    	 10B    	;Chip has a MAX PBL limitation
THR_MinLimited 	equ   	100B    	;Chip forces a Min TX THR limitation on DC21x4 chip
MRM_capable	equ  	CSR0_MRM SHR 16 ;Memory Read Multiple 		(ext PCI command)
MRL_capable     equ    	CSR0_MRL SHR 16 ;Memory Read Line     		(ext PCI command)
MWI_capable     equ   	CSR0_MWI SHR 16 ;Memory Write Invalidate	(ext PCI command)

PCIChipsetSTRUC	struc
 	union
   	  struc
     	    Vendor    	dw  ?
     	    CS_Device 	dw  ?
     	    Revision  	db  ?
   	  ends
	  VendorDevice 	dd  ?
	ends
	CS_Handle 		dw	0
	CS_Capabilities		dw	MRM_capable OR MRL_capable OR MWI_capable
	CS_MaxPBL               db	0          	;MAX PBL allowed
	CS_MinTxThreshold	dw	0		;MIN TX threshold recommended
	CS_TurboMode		dw	FALSE		;Will be set if in TURBO mode
	CS_Found		db	FALSE
PCIChipsetSTRUC	ends

;-------------------
;PCI slot numbering:
;-------------------
FRST_PCI_SLOT   equ      1


;******************************************************************************
;*                	M E M O R Y   S E R V I C E S                         *
;******************************************************************************

;Bit masks used in the caller's MemoryType field
;------------------------------------------------
SYSTEM_MEM_ALLOC	equ	     1B	;1 == Allocate From system mem,
					;0 == allocate over Driver's INIT section
TEMP_MEM_ALLOC		equ    	    10B	;1 == Allocate Memory from driver's local heap

USED_AT_INIT		equ   	   100B	;1 == Used at Init time,
					;0 == Used at Run-time
MAP_TO_GIVEN_PHYS	equ  	  1000B	;1 == Only map to the address given in PhysicalAddress,
					;0 == Alloc an lock Phys mem
MEM_ALLOCATED		equ 	 10000B	;1 == Memory had been successfully allocated,

MEM_LOCKED		equ 	100000B	;1 == Memory had been successfully locked,

;----------------------------------------------------------------
; Structure required for passing parameters to Memory services.
; DO NOT ALTER FIELD POSITION since VDS needs them in that order
;----------------------------------------------------------------
DMA_DESCRIPTOR  STRUC
	RegionSize      	DD      0	;Size of memory needed
	RegionOffset    	DD      0
	RegionSegment   	DW      0
	BufferID        	DW      0       ;For VDS use ONLY
	PhysicalAddress 	DD      0
	MemoryType		DW	0	;Caller memory requirenments
DMA_DESCRIPTOR  ENDS

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       Align32        macro
;
;       Returns the #of bytes needed to be added to the address given to this
;	macro that will align it to 32byte
;
;       assumes:
;
;       returns:        al      Destroyed
;                       All other registers preserved
;                       Interrupts disabled
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Align32        macro	HowMuchToAdd, AddressToAlign

	;Align HowMuchToAdd to 32Bytes boundary
        ;--------------------------------------
	mov	HowMuchToAdd, AddressToAlign
	add     HowMuchToAdd, 31
	and	HowMuchToAdd, NOT 1Fh		;Clear 5LSBits

	;Get the Delta we have to add for getting the desired alignment
        ;--------------------------------------------------------------
	sub	HowMuchToAdd, AddressToAlign
endm


;******************************************************************************
;*                 I N T E R R U P T   S E R V I C E S                        *
;******************************************************************************
MAX_INTERRUPT		 equ 0Fh

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       AckPIC	macro
;
;       ACK PIC interrupt Clears The PIC/s (Issues an EOI to the PIC/s)
;	Since PCs have 2 concatenated PICs itrs essential to know if EOI is needed
;	In tha MAster PIC only or both MAster amd Slave PICs.
;
;       assumes:        Interrupts disabled
;       called :	At run-time with the following:
;				Interrupts 	- Disabled and must not be enabled.
;				EOIonSlaveToo 	- If Slave PIC needs to be
;						  acknowledged too.
;       returns:        Interrupts disabled
;                       All registers preserved
;
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
AckPIC	macro	
	LOCAL   @ClearMasterPIC
	
	push	ax
        push	dx

IF OS EQ OS2
	mov  ax, NDISServiceSpecificChar.ssc_interrupt
	mov  dl, DEVHLP_EOI
	call ds:[devhlp]
ENDIF
IF OS EQ DOS
	mov     al, 20h                         ;Issue EOI to PIC(s)
IF NOS EQ NDIS2
	cmp     SlavePICNeedsEOI, FALSE         ;EOI needed on slave PIC?  (NDIS2)
ELSE
	cmp     MSMEOIFlag, FALSE         	;EOI needed on slave PIC?  (ODI)
ENDIF
	je      SHORT @ClearMasterPIC

	out     0a0h, al                        ;Issue EOI to Slave PIC

	push	ax
	in	al, 61h                         ;time sensitive ports need some delay.
	in	al, 61h
	in	al, 61h
	pop	ax

@ClearMasterPIC:
	out     20h, al                         ;Issue EOI to the 1st PIC
ENDIF
	pop	dx
	pop     ax

		endm

;******************************************************************************
;*                 	     T I M E   S E R V I C E S                        *
;******************************************************************************
;******************************************************************************
;*                 	    P R I N T   S E R V I C E S                       *
;******************************************************************************

