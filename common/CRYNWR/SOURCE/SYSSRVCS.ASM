;*******************************************************************************
;
; SysSrvcs.ASM
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
; Haimovsky Moti  13-Apr-1997 2.60  - Modified HandleTURBOOnPCIMachines not to issue a warning message
;				      if Can't handle DETURBO KWD.
; Haimovsky Moti  13-Apr-1997	    - Modified DisplayMessage routine Not to display a message
;				      if not at INIT time. (ODI).
; Haimovsky Moti  18-Jun-1997	    - Fixed bug in FindPciHostBridge returning error
;				      in-case of a generic Phy.
;*******************************************************************************
	.xlist

Include	SEG_DEFS.INC
.386
include	 dc_regs.inc
include	 nic.inc
Include	SYSSRVCS.inc
.8086
Include	SYSSRVCS.ASH
IF OS EQ OS2
include	Driver.inc			;NDIS2 inc file
; include	DevHlp.inc			;From OS2 DDK
ENDIF
	.list

.386
;******************************************************************************
;*                	S Y S T E M    S E R V I C E S                        *
;******************************************************************************

START_CODE_SEGMENT_INIT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	SYSSRVCS_Init
;
;	Called:		At init Time Before any other call to any other SYSSRVCS
;			routine is Done.
;
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;			PCI machines are 386 and  above!
;	Modifies:      	
;	Returns:	In case of an Error or BIOS not present:	
;				Carry	= SET
;				DX     	= Error message PTR
;
;	       		In case of SUCCESS:
;				Carry  	= RESET
;
;	       	All other registers are modified according to the PCI faunction
;		call.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SYSSRVCS_Init	proc	near

	; Check that CPU is 386 and above
        ;--------------------------------
	call	IsCPU386OrAbove
	jc	SHORT SYSSRVCSI_Exit		;We cannot work with 286 or less
	or	NIc.SystemFlags, I386_Present   ;Mark That CPU is 386 or above

	; Init Internal SYSSRVCS modules
        ;-------------------------------
	call	SYSBUS_Init
	jc	SHORT SYSSRVCSI_Exit

SYSSRVCSI_Exit:
	ret

SYSSRVCS_Init	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	SYSSRVCS_InitDone
;
;	Called:		At init Time as the last action done before Init section
;			Completes.
;
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;
;	Modifies:
;	Returns:	In case of an Error or BIOS not present:	
;				Carry	= SET
;				DX     	= Error message PTR
;
;	       		In case of SUCCESS:
;				Carry  	= RESET
;
;	       	All other registers are modified according to the PCI faunction
;		call.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SYSSRVCS_InitDone	proc	near

	call	SYSBUS_InitDone
	jc   	SHORT SYSID_Exit		; branch on error

SYSID_Exit:
	ret

SYSSRVCS_InitDone	Endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	SYSSRVCS_InitErrorExit
;
;	Called:		At init Time If init FAILa and driver must be unloaded
;			Completes.
;
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;
;	Modifies:
;	Returns:
;	       	All registers are preserved
;		
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SYSSRVCS_InitErrorExit	proc	near

	call	SYSBUS_InitErrorExit
	ret

SYSSRVCS_InitErrorExit	Endp

END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_RUNTIME
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	SYSSRVCS_Close
;
;	Called:		At Run-Time before shutting down the driver.
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;	Modifies:
;	Returns:	In case of an Error or BIOS not present:	
;				Carry	= SET
;
;	       		In case of SUCCESS:
;				Carry  	= RESET
;
;	       	All other registers are modified according to the PCI faunction
;		call.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SYSSRVCS_Close	PROC	NEAR

	call	SYSBUS_Close
	ret

SYSSRVCS_Close	ENDP

END_CODE_SEGMENT_RUNTIME

;******************************************************************************
;*                	    C P U    S E R V I C E S                          *
;******************************************************************************
START_CODE_SEGMENT_INIT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	Is386OrAbove
;		Check that CPU is 386 and above
;		Manipulating the IOPL bits in the FLAGS reg is blocked by the
;		286 in real mode (since it runs in Ring3 privilage) but not in
;		386 or above (since it runs in Ring0 privilages).
;
;	Called:		At init Time Before any other call to any other SYSSRVCS
;			routine is Done.
;
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;			
;	Modifies:      	
;	Returns:	In case of an Error or BIOS not present:	
;				Carry	= SET
;				DX     	= Error message PTR
;
;	       		In case of SUCCESS:
;				Carry  	= RESET
;
;	       	All other registers are modified according to the PCI faunction
;		call.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
IsCPU386OrAbove	proc	near

	push	ax
        push	bx
	pushf				; Save original flags
	cli				; Let no one distturb US

IF NOS EQ NDIS2
	;---------------------------------------------------------------------
	; CPU type can be detirmind Via it's bits 12-15 behavior
	; - On 8086 machines its always SET (since not implemented).
	; - On 286 DOS program can't change the bits (which are always clear).
	; - On 386 and above the bits will be changed.
        ;---------------------------------------------------------------------

	;------------
	;Is it 8086 ?
	;------------
	;Clear bits 12-15
        ;----------------
	pushf				;Save EFlags
	pop	bx                      ;Store Eflags in bx
	mov	ax, 0FFFh		;Clear bits 12-15
	and	ax, bx
        push	ax                      ;Set Eflags to new Val.
	popf

	;If ALL bits are SET -> 8086
	;---------------------------
        pushf
	pop	ax
	and	ax, 0FFFh
	cmp	ax, 0f000h
	je	SHORT I286OrLess

	;--------------------
	;Is it 386 or above ?
        ;--------------------
	pushf
	pop	ax

	or	ax, 6000h               ;Set IOPL<13> and NT bits
	push	ax                      ;load flags with modified value
	popf

	pushf
	pop	ax                      ;Let ax hold Flags value again.
	test	ax, 6000h               ;If the bits were modified then its 386 or above.
	jnz	SHORT I386OrAbove
ELSE
	test    MSMSystemFlags,I386Flag ;Use Novell's check result
	jnz	SHORT I386OrAbove

ENDIF

I286OrLess:
	popf
	pop	bx
        pop	ax
	DataAddress	dx, NotA386MachineErr
	stc
	ret

I386OrAbove:
       	popf
       	pop	bx
        pop	ax
       	clc
       	ret

IsCPU386OrAbove	endp

END_CODE_SEGMENT_INIT

;******************************************************************************
;*                S Y S T E M   B U S   S E R V I C E S                       *
;******************************************************************************

;------------------------------------------------------------------------------
;   			   PCI  VARIABLES   (INTERNAL)
;------------------------------------------------------------------------------
IF OS EQ OS2
;---------------------------------------------------------------------------
; In OS/2 PCI access is done Via the PCI bios routine entry
;---------------------------------------------------------------------------
; Since Init and Run time calls cannot be made via the same selector due to
; Preivilage levels and LDT/GDT limitations we need 2 such selectors
;---------------------------------------------------------------------------
START_DATA_SEGMENT_INIT

PCIBIOSServiceEntryGDT	LONG_PTR <0,0>

END_DATA_SEGMENT_INIT

START_DATA_SEGMENT_RUNTIME

PCIBIOSServiceEntry	LONG_PTR <0,0>

END_DATA_SEGMENT_RUNTIME

ENDIF

;-------------------------------------------------------------
; PCI Chipset vital data to be checked and used by our driver
;-------------------------------------------------------------
START_DATA_SEGMENT_RUNTIME

PCIChipSet		PCIChipsetSTRUC <>

END_DATA_SEGMENT_RUNTIME


START_CODE_SEGMENT_INIT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	SYSBUS_Init
;
;	Called:		At init Time Before any other call to any other SYSSRVCS
;			routine is Done.
;
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;			PCI machines are 386 and  above!
;	Modifies:      	
;	Returns:	In case of an Error or BIOS not present:	
;				Carry	= SET
;				AH     	= ErrorCode  	
;				DX     	= Error message PTR
;
;	       		In case of SUCCESS:
;				AH	= SUCCESS
;				Carry  	= RESET
;
;	       	All other registers are modified according to the PCI faunction
;		call.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SYSBUS_Init	proc	near

	;----------------------
	; Find supported busses
	;----------------------
	;Start From PCI
        ;--------------
	call	PCIBUS_Init
	jc	SHORT SBI_DonePCI
	or	Nic.SystemFlags, PCI_Present
SBI_DonePCI:

	;---------------------------------------------
	;Check If at least one supported bus was found
	;---------------------------------------------
	test	Nic.SystemFlags, SUPPORTED_BUSSES_MASK
	jz	SHORT SBI_ErrorExit

        clc
	ret

SBI_ErrorExit:
	DataAddress dx, UnknownBusErr
	stc
	ret

SYSBUS_Init	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	SYSBUS_InitDone
;
;	Called:		At init Time Before bnecoming a TSR
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;			PCI machines are 386 and  above!
;	Modifies:      	
;	Returns:	In case of an Error or BIOS not present:	
;				Carry	= SET
;				DX     	= Error message PTR
;
;	       		In case of SUCCESS:
;				Carry  	= RESET
;
;	       	All other registers are modified according to the PCI faunction
;		call.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SYSBUS_InitDone	proc	near

	;Start From PCI
        ;--------------
	call	PCIBUS_InitDone
	ret

SYSBUS_InitDone	Endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	SYSBUS_InitErrorExit
;
;
;	Called:		At init Time If init FAILa and driver must be unloaded
;			Completes.
;
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;
;	Modifies:
;	Returns:
;	       	All registers are preserved
;		
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SYSBUS_InitErrorExit	proc	near

	;Start From PCI
        ;--------------
	call	PCIBUS_InitErrorExit
	ret

SYSBUS_InitErrorExit	Endp

END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_RUNTIME
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	SYSBUS_Close
;
;	Called:		At Run-Time
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;			PCI machines are 386 and  above!
;	Modifies:      	
;	Returns:	In case of an Error or BIOS not present:	
;				Carry	= SET
;				AH     	= ErrorCode  	
;				DX     	= Error message PTR
;
;	       		In case of SUCCESS:
;				AH	= SUCCESS
;				Carry  	= RESET
;
;	       	All other registers are modified according to the PCI faunction
;		call.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SYSBUS_Close	PROC	NEAR

	;Start From PCI
        ;--------------
	call	PCIBUS_Close
        ret

SYSBUS_Close	ENDP

END_CODE_SEGMENT_RUNTIME


;***********************************************
;*      P C I   B U S   S E R V I C E S        *
;***********************************************

;PCI BIOS call constants definition
;----------------------------------
PCI_BIOS_INT             equ     1Ah
PCI_FUNCTION_ID          equ    0B1h
PCI_BIOS_PRESENT         equ     01h
FIND_PCI_DEVICE          equ     02h
FIND_PCI_CLASS_CODE      equ     03h
GENERATE_SPECIAL_CYCLE   equ     06h
READ_CONFIG_BYTE         equ     08h
READ_CONFIG_WORD         equ     09h
READ_CONFIG_DWORD        equ     0Ah
WRITE_CONFIG_BYTE        equ     0Bh
WRITE_CONFIG_WORD        equ     0Ch
WRITE_CONFIG_DWORD       equ     0Dh

;PCI BIOS returned values constants definition
;---------------------------------------------
PCI_SUCCESSFUL           equ     00h
PCI_FUNC_NOT_SUPPORTED   equ     81h
PCI_BAD_VENDOR_ID        equ     83h
PCI_DEVICE_NOT_FOUND     equ     86h
PCI_BAD_REGISTER_NUMBER  equ     87h

;PCI Class code
;--------------
PCI_HOST_BRIDGE_CLASS_CODE 	equ 	060000h

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;   			GENERIC PCI ROUTINES  (INTERNAL)
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
START_CODE_SEGMENT_INIT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	PCIBUS_Init
;
;	Called:		At init Time Before any other call to any other SYSSRVCS
;			routine is Done.
;
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;			PCI machines are 386 and  above!
;	Modifies:      	
;	Returns:	In case of an Error or BIOS not present:	
;				Carry	= SET
;				AH     	= ErrorCode  	
;				DX     	= Error message PTR
;
;	       		In case of SUCCESS:
;				AH	= SUCCESS
;				Carry  	= RESET
;
;	       	All other registers are modified according to the PCI faunction
;		call.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIBUS_Init	proc	near

	;-----------------------------------------------
	;Allocate system resources needed for PCI module
        ;-----------------------------------------------
	call	PCIAllocResources
	jc	SHORT PBI_ErrorExit

	;--------------------------------------------------
	;Find PCI BIOS and its components (such as Chipset)
        ;--------------------------------------------------
	call	PCIFindBios
	jc	SHORT PBI_FullErrorExit

	call	FindPciHostBridge
	jc	SHORT PBI_FullErrorExit

PBI_Exit:
        clc
        ret

PBI_FullErrorExit:
	call	PCIBUS_InitErrorExit
PBI_ErrorExit:
	stc
	ret

PCIBUS_Init	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	PCIBUS_InitDone
;
;	Called:		At init Time Before any other call to any other SYSSRVCS
;			routine is Done.
;
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;			PCI machines are 386 and  above!
;	Modifies:      	
;	Returns:	In case of an Error or BIOS not present:	
;				Carry	= SET
;				AH     	= ErrorCode  	
;				DX     	= Error message PTR
;
;	       		In case of SUCCESS:
;				AH	= SUCCESS
;				Carry  	= RESET
;
;	       	All other registers are modified according to the PCI faunction
;		call.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIBUS_InitDone	proc	near
IF OS EQ OS2
	push	eax
	push	bx
	push	cx
        push	dx

	;-------------------
	;Perform PCI changes
	;-------------------
	;Free LDT PCI BIOS Entry since can't be used at BIND or RUN time
	;---------------------------------------------------------------
	mov  	ax, PCIBIOSServiceEntry._seg	; ax has the Selector to be freed.
        xor 	bx, bx                      	; Clear BX
        xor  	cx, cx                      	; Free full 64KB
	mov  	dh, UVIRT_FREE			; request to Free the above selector
	mov  	dl, DEVHLP_PHYSTOUVIRT     	; function to get virtual address
        call 	ds:[devhlp]                	; Free it

	;Put our GDT Entry in PCIBIOSServiceEntry
        ;----------------------------------------
	mov     eax, DWORD PTR PCIBIOSServiceEntryGDT
	mov     DWORD PTR PCIBIOSServiceEntry, eax

PBID_Exit:
	pop	dx
	pop	cx
        pop	bx
	pop	eax
        clc
ELSE
	clc
ENDIF
	ret

PCIBUS_InitDone	endp


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	PCIAllocResources
;
;	Called:		At init Time for allocating system resources to be used by
;			PCI module.
;
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;			PCI machines are 386 and  above!
;	Modifies:      	
;	Returns:	In case of an Error or BIOS not present:	
;				Carry	= SET
;				DX     	= Error message PTR
;
;	       		In case of SUCCESS:
;				Carry  	= RESET
;
;	       	All other registers are modified according to the PCI faunction
;		call.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIAllocResources	proc	near

IF OS EQ OS2
	push	eax
	push	bx
	push	ecx
	push	di
	push	si
	push	es

	;----------------------------------------------------
	; In OS2 map ourselvs to PCI BIOS entry
	; - For the Init Phase, Allocate PCI BIOS entry to LDT
	; - For Run-time, Use GDT entry.
	;-----------------------------------------------------

	; - For the Init Phase, Allocate PCI BIOS entry to LDT
        ;-----------------------------------------------------
	mov  	ax, (PCI_BIOS_INT_ADDR SHR 16) 	; high-order part of physical addr.
        mov 	bx, 0                      	; start of that segment
        mov  	cx, 0                      	; map full 64KB
        mov  	dh, UVIRT_RE               	; make it executable-readable
        mov  	dl, DEVHLP_PHYSTOUVIRT     	; function to get virtual address
        call 	ds:[devhlp]                	; get it
	jc   	PAR_ErrorExit			; branch on error

        add  	bx, (PCI_BIOS_INT_ADDR AND 0FFFFh) ; low-order part of phys addr
        mov  	PCIBIOSServiceEntry._off, bx  	; save entry point offset
	mov  	PCIBIOSServiceEntry._seg, es  	; save entry point segment


	; - For Run-time, Use GDT entry.
	;-------------------------------

	;Allocate GDT selector
        ;---------------------
	mov     ax, ds                          ;Make ES equal to DS.
        mov     es, ax                          ;ES = high address. (32 bits)
	lea     di, PCIBIOSServiceEntryGDT._seg ;DI = low address.
        mov     cx, 1                           ;One selector.
	mov     dl, DevHlp_AllocGDTSelector     ;Function call.
        call    ds:[DevHlp]                     ;Place GDT selector into [ES:DI].
	jc	SHORT PAR_ErrorExit

	;Map PCI BIOS Physical Address to a GDT Selector
	; - First map it as a Data selector to overcome a IBM BUG in allocGDTsel,
	; - Then map it as a Ring 0 Exec priv since we are going to use it at Run Time.
	;-------------------------------------------------------------------------------
	mov	ax, (PCI_BIOS_INT_ADDR SHR 16)  ;segment of PCI BIOS bios entry
	mov 	bx, 0				; map 64KB from beginning of segment
	mov  	cx, 0                      	; map full 64KB
	mov	si, PCIBIOSServiceEntryGDT._seg	; SI - Selector allocated using DevHlp_AllocGDTSelector
	mov  	dl, DevHlp_PhysToGDTSelector    ; function to get virtual address
        call 	ds:[devhlp]                	; get it
	jc   	SHORT PAR_ErrorExit         	; branch on error

	mov	ax, (PCI_BIOS_INT_ADDR SHR 16)  ;segment of PCI BIOS bios entry
	shl	eax, 16                         ;Address of PCI BIOS bios entry
	mov  	ecx, 0                      	; map full 64KB
	mov	si, PCIBIOSServiceEntryGDT._seg	; SI - Selector allocated using DevHlp_AllocGDTSelector
        mov  	dh, Ring0_Exec_Read_16     	; make it 16 bit readable code with ring0 priv.
	mov  	dl, DevHlp_PhysToGDTSel     	; function to get virtual address
        call 	ds:[devhlp]                	; get it
	jc   	SHORT PAR_ErrorExit         	; branch on error
	mov     PCIBIOSServiceEntryGDT._off, (PCI_BIOS_INT_ADDR AND 0FFFFh) ;Fill the OFFSET of BIOS entry call
        clc
	jmp	SHORT PAR_Exit

PAR_ErrorExit:
	DataAddress dx, OS2PhysToGDTFailed
	stc

PAR_Exit:
	pop	es
	pop	si
	pop	di
	pop	ecx
        pop	bx
        pop	eax
ELSE
	clc
ENDIF
	ret

PCIAllocResources	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	PCIBUS_InitErrorExit
;
;	Called:		At init Time If init FAILa and driver must be unloaded
;			Completes.
;
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;
;	Modifies:
;	Returns:
;	       	All registers are preserved
;		
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIBUS_InitErrorExit	proc	near

	;Free PCI preallocated resources by using the following routines
        ;---------------------------------------------------------------
	call	PCIBUS_InitDone 	;To free Init time resources
	call	PCIBUS_Close            ;To free Run time resources
	ret

PCIBUS_InitErrorExit	Endp

END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_RUNTIME
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	PCIBUS_Close
;
;	Called:		At init Time Before any other call to any other SYSSRVCS
;			routine is Done.
;
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;			PCI machines are 386 and  above!
;	Modifies:      	
;	Returns:	In case of an Error or BIOS not present:	
;				Carry	= SET
;				AH     	= ErrorCode  	
;				DX     	= Error message PTR
;
;	       		In case of SUCCESS:
;				AH	= SUCCESS
;				Carry  	= RESET
;
;	       	All other registers are modified according to the PCI faunction
;		call.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIBUS_Close	proc	near
IF OS EQ OS2
	push	eax
	push	dx

	;---------------------------
	;Free PCI BIOS GDT Selector
	;---------------------------
	mov	ax, PCIBIOSServiceEntry._seg	; AX - Selector we wish to free
	mov  	dl, DevHlp_FreeGDTSelector
	call 	ds:[devhlp]                	; free it

	pop	dx
	pop	eax
ELSE
	clc
ENDIF
	ret

PCIBUS_Close	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	PCIErrorHandling
;
;	Called:		At init and Run-Time AFTER a PCI call has returned with
;			an error.
;				Carry	= SET
;				AH     	= ErrorCode
;  	
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;			
;	Modifies:      	
;	Returns:	In case of an Error or BIOS not present:	
;				DX     	= Error message PTR
;
;
;	       	All other registers are preserved.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIErrorHandling	proc	near

	; PCI_BAD_VENDOR_ID error handling
        ;---------------------------------
	DataAddress	dx, BadDeviceCFIDVal
	cmp	ah, PCI_BAD_VENDOR_ID
	je	SHORT PEH_ErrorExit

	; PCI_DEVICE_NOT_FOUND error handling
        ;------------------------------------
	DataAddress	dx, BoardNotFoundErr
	cmp	ah, PCI_DEVICE_NOT_FOUND
	je	SHORT PEH_ErrorExit

	; PCI_BAD_REGISTER_NUMBER error handling
	;---------------------------------
	DataAddress	dx, PCIBIOSBadRegErr
	cmp	ah, PCI_BAD_REGISTER_NUMBER
	je	SHORT PEH_ErrorExit

	;Else or PCI_FUNC_NOT_SUPPORTED error handling
	;---------------------------------------------
	DataAddress	dx, PCIBIOSBadStatusErr

PEH_ErrorExit:
	stc
	ret

PCIErrorHandling	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	PCIBiosCall
;
;	Called:		At init and Run-Time AFTER PCIFindBios call had been
;			Called.
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;			PCI machines are 386 and  above!
;	Modifies:      	
;	Returns:	In case of an Error or BIOS not present:	
;				Carry	= SET
;				AH     	= ErrorCode  	
;				DX     	= Error message PTR
;
;	       		In case of SUCCESS:
;				AH	= SUCCESS
;				Carry  	= RESET
;
;	       	All other registers are modified according to the PCI faunction
;		call.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIBiosCall	proc	near

	mov     ah, PCI_FUNCTION_ID

	;-----------------------
	; Perform PCI BIOS call
	;-----------------------
IF OS EQ OS2
	pushf
	call	ds:[PCIBIOSServiceEntry]
ELSE
	int	PCI_BIOS_INT
ENDIF
        ;--------------------------------------------------------
	;On return from BIOS call we expect the following values:
	;carry - cleared
	;AH    - PCI_SUCCESSFUL
	;      - PCI_DEVICE_NOT_FOUND
	;      - PCI_BAD_VENDOR_ID
	;BH    - Bus number (0..255)
	;BL    - Device Number in upper 5 bits
	;        Function number in lower 3 bits
	;--------------------------------------------------------
	jc	SHORT PBC_ErrorExit		;Error - Handle it
PBC_Exit:
	ret

PBC_ErrorExit:
	call	PCIErrorHandling
	ret

PCIBiosCall	endp

END_CODE_SEGMENT_RUNTIME


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;   			INIT PCI ROUTINES (EXTERNAL)
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

START_CODE_SEGMENT_INIT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	PCIFindBios
;	Routine is activated once ib order to detirmine if PCI BIOS is present
;	and ,in OS2, to init the entry call for it.
;
;	Called:		At init only before any other PCI function is called
;	Assumes:      	DS = Cgroup (in DOS or Dgroup in OS2)
;			PCI machines are 386 and  above!
;	Modifies:      	PCIBiosEntry (In OS2 only)
;	Returns:	In case of an Error or BIOS not present:	
;				Carry	=  SET
;				DX     	= Error message PTR
;
;	       		In case of SUCCESS:
;				Carry  	=  RESET
;	       	All other registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIFindBios proc   near

IF NOS EQ ODI

	;test for PCI bus here
	;---------------------
	test   	MSMSystemFlags, PCIFlag
	jz	SHORT NotPCIBus                           ;If 0 - No PCI bus.
	clc                     			  ;Else - PCI bus found.
	ret

NotPCIBus:
	;If Reached this point we have no PCI bus
        ;----------------------------------------
	DataAddress  dx, NoPciBIOSErr
	stc     					
	ret

ELSE			;NDIS2 Handling
	push    eax
	push    ebx
	push    ecx
	push    edx

	;Check PCI BIOS to be present
	;----------------------------
        ;---------------------------------------------------------------------
	; On successfull return from BIOS call we expect the following values:
	; carry - cleared
	; AH    - 0
	; EDX   - ' PCI'
	; AL    - hardware mechanism (not interesting our driver so far)
	; BH    - Interface Level Major Version
	; BL    - Interface Level Minor Version
	; CL    - Number of last PCI bus in system
	;---------------------------------------------------------------------

	mov     al, PCI_BIOS_PRESENT
	call	PCIBiosCall
	jc      SHORT VBTPCI_ErrorExit     	;Failure exit

	or      ah, ah                		;AH should be 0
	jnz     SHORT NoPCI_BIOS

	cmp     edx, ' ICP'     		;check for 'PCI ' string to be there
	jnz     SHORT NoPCI_BIOS

	clc                     ;Success code.
	pop     edx
	pop     ecx             ;Intel BIOS bug workaround - destroyes EDX
	pop     ebx             ;Intel BIOS bug workaround - destroyes ECX
	pop     eax
	ret

NoPCI_BIOS:
	DataAddress	dx, NoPciBIOSErr
VBTPCI_ErrorExit:
	mov	ax, dx		;Save Error message PTR
	pop	edx             ;Restor prev EDX value
	mov	dx, ax          ;Restor Error message PTR
	pop	ecx
	pop	ebx
	pop	eax
	ret
ENDIF
PCIFindBios  endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	PCIFindDevice
;	Returns the location of the PCI device which have the specified Device ID,
;	Vendor ID and Instance.
;
;	Called:		At init only with:
;				ECX 	= Dev & Vendor IDs
;				SI  	= Index (0 for first)
;	Assumes:      		DS 	= Cgroup (in DOS or Dgroup in OS2)
;	Modifies:      	
;	Returns:	In case of an Error or device not found:	       	
;				CF	 = Set
;				DX     	= Error message PTR
;
;	       		In case of SUCCESS:
;				CF = reset
;				BX = Device access handle
;
; 	       		All other registers are Preserved
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIFindDevice	PROC	Near

        push	ax
	push	ecx
	push    dx

	;----------------
	;Find the device
	;----------------
	mov     al, FIND_PCI_DEVICE
	mov     dx, cx                  ;DX - vendor ID
	shr     ecx, 16                 ;CX - device ID
	call	PCIBiosCall
	jc	SHORT PFD_ErrorExit

PFD_Exit:
	pop	dx
	pop	ecx
        pop	ax
        ret

PFD_ErrorExit:
	pop	cx 	;Clear DX entry from stack
	pop	ecx
        pop	ax
	stc
        ret

PCIFindDevice   endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       PCIFindClassCodeDevice
;
;
;	Returns the location of the PCI device which have the specified
;	Class Code and Instance.
;
;	Called:		At init only with:
;				ECX 	= Class Code (in lower three bytes)
;				SI  	= Index
;	Assumes:      		DS 	= Cgroup (in DOS or Dgroup in OS2)
;	Modifies:      	
;	Returns:       In case of an Error or device not found	       	
;				CF 	= Set
;				DX     	= Error message PTR
;
;	       		In case of SUCCESS:
;				CF	 = reset
;				BX 	= Device access handle
;
;	       		All other registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIFindClassCodeDevice  proc    near

	push    ax

	;Find the device
	;----------------
	mov     al, FIND_PCI_CLASS_CODE
	call	PCIBiosCall

	pop     ax
	ret

PCIFindClassCodeDevice  endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       PCIGetDeviceNumber
;
;       This routine accepts a PCI device handle and returns the device number
;	associated with it.
;
;	Called:		At init only with:
;				BX 	= Device access handle
;	Assumes:      	
;	Modifies:      	
;	Returns:		AL	= Device Number.
;
;	       		All other registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIGetDeviceNumber		proc	near

	mov	al, bl
	shr     al, 3		;Align Dev#
	and	al, 1Fh		;Keep Dev# only
	ret

PCIGetDeviceNumber		endp

END_CODE_SEGMENT_INIT

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;   			RUN TIME PCI ROUTINES
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

START_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	PCIReadCfgDWORD
;
;	Reads a DWORD its offset is given in DI from the Device config space.
;
;	Called:	At init and Run time with:
;			BX 	= Device access handle
;			DI  	= Register # (0,4,8...255)
;	Assumes:      	DS 	= Cgroup (in DOS or Dgroup in OS2)
;	Modifies:      	
;	Returns:        In case of an Error	       	
;			CF 	= Set
;			DX     	= Error message PTR
;
;	       	In case of SUCCESS:
;			CF	= reset
;			ECX	= Dword read
;	       	All other registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIReadCfgDWORD    proc    near

	push    ax

	mov     al, READ_CONFIG_DWORD
        call	PCIBiosCall

	pop     ax
	ret

PCIReadCfgDWORD    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	PCIReadCfgWORD
;
;	Reads a WORD its offset is given in DI from the Device config space.
;
;	Called:	At init and Run time with:
;			BX 	= Device access handle
;			DI  	= Register # (0,2,4..254)
;	Assumes:      	DS 	= Cgroup (in DOS or Dgroup in OS2)
;	Modifies:      	
;	Returns:        In case of an Error	       	
;			CF 	= Set
;			DX     	= Error message PTR
;
;	       	In case of SUCCESS:
;			CF	= reset
;			CX	= word read
;	       	All other registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIReadCfgWORD    proc    near

	push    ax

	mov     al, READ_CONFIG_WORD
        call	PCIBiosCall

	pop     ax
	ret

PCIReadCfgWORD    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	PCIReadCfgBYTE
;
;	Reads a BYTE its offset is given in DI from the Device config space.
;
;	Called:	At init and Run time with:
;			BX 	= Device access handle
;			DI  	= Register # (0..255)
;	Assumes:      	DS 	= Cgroup (in DOS or Dgroup in OS2)
;	Modifies:      	
;	Returns:        In case of an Error	       	
;			CF 	= Set
;			DX     	= Error message PTR
;
;	       	In case of SUCCESS:
;			CF	= reset
;			CL	= BYTE read
;	       	All other registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIReadCfgBYTE    proc    near

	push    ax

	mov     al, READ_CONFIG_BYTE
        call	PCIBiosCall

	pop     ax
	ret

PCIReadCfgBYTE    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	PCIWritedCfgDWORD
;
;	Writes a DWORD its value is given in ECX to the Device config space in
;	an offset given in DI.
;
;	Called:		At init and Run time with:
;				BX 	= Device access handle
;				DI  	= Register # (0,4,8...252)
;				ECX	= Dword value to be written
;	Assumes:      	DS 	= Cgroup (in DOS or Dgroup in OS2)
;	Modifies:      	
;	Returns:        In case of an Error	       	
;				CF 	= Set
;				DX     	= Error message PTR
;
;	       	In case of SUCCESS:
;			CF	= reset
;	       	All other registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIWriteCfgDWORD   proc    near

	push    ax

	mov     al, WRITE_CONFIG_DWORD
	call	PCIBiosCall

	pop     ax
	ret

PCIWriteCfgDWORD   endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	PCIWritedCfgWORD
;
;	Writes a WORD its value is given in CX to the Device config space in
;	an offset given in DI.
;
;	Called:		At init and Run time with:
;				BX 	= Device access handle
;				DI  	= Register # (0,2,4...254)
;				CX	= word value to be written
;	Assumes:      	DS 	= Cgroup (in DOS or Dgroup in OS2)
;	Modifies:      	
;	Returns:        In case of an Error
;				CF 	= Set
;				DX     	= Error message PTR
;
;	       		In case of SUCCESS:
;				CF	= reset
;	       	All other registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIWriteCfgWORD   proc    near

	push    ax

	mov     al, WRITE_CONFIG_WORD
	call	PCIBiosCall

	pop     ax
	ret

PCIWriteCfgWORD   endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	PCIWritedCfgBYTE
;
;	Writes a DWORD its value is given in CL to the Device config space in
;	an offset given in DI.
;
;	Called:		At init and Run time with:
;				BX 	= Device access handle
;				DI  	= Register # (0,4,8...252)
;				CL	= Byte value to be written
;	Assumes:      	DS 	= Cgroup (in DOS or Dgroup in OS2)
;	Modifies:      	
;	Returns:        In case of an Error	       	
;				CF 	= Set
;				DX     	= Error message PTR
;
;	       		In case of SUCCESS:
;				CF	= reset
;	       	All other registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PCIWriteCfgBYTE   proc    near

	push    ax

	mov     al, WRITE_CONFIG_BYTE
	call	PCIBiosCall

	pop     ax
	ret

PCIWriteCfgBYTE   endp

END_CODE_SEGMENT_RUNTIME


START_CODE_SEGMENT_INIT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       FindPciHostBridge
;
;		This routine finds the PCI host bridge type and revision
;
;
; Inputs:
;       AX  - PCIDeviceAccessHandle
;       DI  - register offset within device configuration space
;       CX - value to be written
;
; Outputs:
;    success
;               carry - cleared
;               AX   -  preserved (PCIDeviceAccessHandle)
;    fail
;               carry - set
;               AX   - error message code
;               DX   - error message ptr
;
; All other registers are preserved.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
FindPciHostBridge	proc

        push	eax
	push	ecx
        push	di
        push	si

	mov	PCIChipset.CS_Found, FALSE            	;Mark Could not Find HOST bridge

	;--------------------------------------------
	;Find the host bridge using Class-Code search
	;--------------------------------------------
	xor	ecx, ecx
	mov	ecx, PCI_HOST_BRIDGE_CLASS_CODE
	xor	si, si					;Look for First Host Bridge
	call	PCIFindClassCodeDevice
	jnc	SHORT FPHB_PCIScanFoundHostBridge

	;--------------------------------------------------------------------
	;If failed finding PCI-HOST bridge using Class code try a more direct
	;approach - Search for specific chipsets known to have bugs.
        ;--------------------------------------------------------------------
	xor	si, si				 ;Saturn number 0
	mov     ecx, SATURN_CDC_CFID_VAL	 ;ECX - device & Vendor IDs
	call	PCIFindDevice
	jnc	FPHB_PCIScanFoundHostBridge

FPHB_CheckForPCMC:
	xor	si, si			       	;Saturn number 0
	mov     ecx, SATURN_PCMC_CFID_VAL      	;ECX - device & Vendor IDs
	call	PCIFindDevice
	jnc     SHORT FPHB_PCIScanFoundHostBridge


FPHB_CheckForC832:
	xor	si, si			       	;OPTI C832 number 0
	mov     ecx, OPTI_C832_CFID_VAL        	;ECX - device & Vendor IDs
	call	PCIFindDevice
	jnc     SHORT FPHB_PCIScanFoundHostBridge

FPHB_CheckForOrion:
	xor	si, si			       	;82450KX Orion number 0
	mov     ecx, ORION_CFID_VAL        	;ECX - device & Vendor IDs
	call	PCIFindDevice
	jnc     SHORT FPHB_PCIScanFoundHostBridge

	;--------------------------------------------------------------------------
	;If reached this point then we Failed to find a buggy ChipSet.
	;--------------------------------------------------------------------------
	jmp	SHORT FPHB_HandleChipset        ;Generic chipset has a minimal set of capabilities.

	;------------------------------------------------
	;Chipset found - Get its vendor ID, DevId and rev
	;------------------------------------------------
FPHB_PCIScanFoundHostBridge:
	mov	PCIChipset.CS_Handle, bx        ;Save Handle

	mov	di, PCI_CFID_OFFSET             ;Get and Save vendor & Device IDs
	call	PCIReadCfgDword
	jc	SHORT FPHB_ErrorExit
	mov	PCIChipset.VendorDevice, ecx

	mov	di, PCI_CFRV_OFFSET             ;Get and Save Revision ID
	call	PCIReadCfgDword
	jc	SHORT FPHB_ErrorExit
	mov	PCIChipset.Revision, cl         ;Save Revision ID

	mov	PCIChipset.CS_Found, TRUE       ;Mark Found HOST bridge

	;------------------------------------------
	;Chipset found - Handle it and its entries
        ;to chipset type
	;------------------------------------------
FPHB_HandleChipset:
        call	HandlePCIChipset
	jc	SHORT FPHB_ErrorExit

FPHB_Exit:
	clc
FPHB_ErrorExit:
	pop	si
	pop	di
	pop	ecx
	pop	eax
	ret

FindPciHostBridge	endp

;****************************************************************************
;
; Name:         HandlePCIChipset
;
; Description:  This routine call is used as a temporary solution to the
;		Intel CDC and Intel PCMC bugs related to bus master devices
;		which write to host memory.
;		There are few bugs we found that require handling:
;		1. Data loss due to passing cach line boundary.
;		   The bug is that when there is a long transaction to/from host
;		   memory, and it passes the cache line boundary, the data lands
;		   in host memory is corrupted (actually not written at all).
;		   The bug appears in CDC chip (ID=483h) rev 2 and in CDC chip
;		   (ID=4A3h) rev 3.
;		   The temporary workaround is to limit the Tulip burst length to
;		   8 longwords. It seems to work fine, but it is NOT based on any
;		   Intel engineering recommendation! We will modify the workaround
;		   as soon as we know how to do it correctly.
;		   Routine will implement the workaround on all machines having
;		   these buggy chips.
;               2. Data corruption/"reordering" when the cach is in WB mode.
;		   in CDC chip (ID=4A3h) rev 1, if the cache is in WB mode may
;		   cause "data reordering" in memory (ie. data exchange their memory
;		   locations).
;		   The only Work-around for that is to work in WT mode
;
;		Algorithm:
;		1.
;		SATURN_CFRV_BYTE_OFFSET = 8;
;		If (((FindPCIDevice(4838086h, &handle)) &
;		     (ReadConfigByte(handle, SATURN_CFRV_BYTE_OFFSET) == 2)
;                   )
;		    ||
;		    ((FindPCIDevice(4A38086h, &handle)) &
;		     (ReadConfigByte(handle, SATURN_CFRV_BYTE_OFFSET) == 3)
;                   )
;		    {
;		     if (CSR0_value.PBL > PBL8Val)
;			{
;			 prinf("Warning: This machine Host to PCI bridge has a
;				known bug. Driver limits DC21X4 bursts as a
;				workaround!\n");
;			 CSR0_value.PBL = PBL8Val;
;			 CSR0_value.CAL = CAL8Val;
;			}
;		    }
;		2.
;		SATURN_CACHE_MODE_ENTRY		equ 52h
;		SATURN_CACHE_MODE_BIT_MASK	equ 02h
;		If (FindPCIDevice(4A38086h, &handle)) &
;		     (ReadConfigByte(handle, SATURN_CFRV_BYTE_OFFSET) == 1) &
;		     	((ReadConfigByte(handle, SATURN_CFRV_BYTE_OFFSET) &&
;					      SATURN_CACHE_MODE_BIT_MASK) != 0){
;		      Issue a warning message
;		}
;
;               3. Massive amount of underruns which prevents successfull transmission
;		   to the network.
;                  This is due to OPTI chipset that supports only bursts of 1.
;		   work-around will be to work with the highest TX-Threshold possible
;		   in tulip and tulip3 and with Full-Packet in Fasternet and Twinet.
;
;
; On Entry:     EAX     N/A
;               EBX     N/A
;               ECX     N/A
;               EDX     N/A
;               EBP     N/A
;               ESI     N/A
;               EDI     N/A
;
;               Note:   Interrupts are in any state.
;
; On Return:    EAX     Destroyed
;               EBX     Preserved
;               ECX     Destroyed
;               EDX     Destroyed
;               EBP     Preserved
;               ESI     Preserved
;               EDI     Preserved
;
;               Flags:
;
;               Note:   Interrupts preserved.
;
; Remarks:      This routine is called from DriverInit prior to resetting
;		Tulip. It must be called after calling SelectWorkingParameters.
;
;
;****************************************************************************

SATURN_CACHE_MODE_REG_OFFSET	 equ 52h
SATURN_SECONDARY_CACHE_ENABLE_WB equ 03h
SATURN_SECONDARY_CACHE_MASK 	 equ 03h


HandlePCIChipset proc near

	;------------------------------------------------------------------------
	;Generic chipset is one that has no bugs and is implemented according to
	;PCI SPEC so:
	; - Support extended PCI commands
	; - No Turbo option
	; - PBL - unlimited
	; - CAL - unlimited
        ;------------------------------------------------------------------------
	mov	PCIChipset.CS_Capabilities, (MRM_capable OR MRL_capable OR MWI_capable)
	mov	PCIChipset.CS_MaxPBL, MAX_PBL		      	 ;Unlimited
	mov	PCIChipset.CS_MinTxThreshold, TX_THRESHOLD_MIN	 ;No Threshold limitation

	;If couldn't find the CS - Do nothing else !
	;-------------------------------------------
	cmp	PCIChipSet.CS_Found, FALSE
	je	SHORT HPC_Exit

	;----------------------------------------------------------------
	;We found the chipset - Check if there is a known problem with it
	;----------------------------------------------------------------
	;Intel PCMC Handling
        ;-------------------
	cmp	PCIChipSet.VendorDevice, SATURN_PCMC_CFID_VAL   ;Saturn is Intel's product
	jne	SHORT HPC_NotIntelPCMC
	or	PCIChipset.CS_Capabilities, TURBO_capable	;We support TURBO with Saturn
	call    HandleIntelPCMCBugs
	jmp	SHORT HPC_Exit
HPC_NotIntelPCMC:

	;Intel CDC Handling
        ;------------------
	cmp	PCIChipSet.VendorDevice, SATURN_CDC_CFID_VAL
	jne	SHORT HPC_NotIntelCDC
	or	PCIChipset.CS_Capabilities, TURBO_capable     	;We support TURBO with Saturn
	call    HandleIntelCDCBugs
	jmp	SHORT HPC_Exit
HPC_NotIntelCDC:

	;OPTI C832 handling
        ;------------------
	cmp	PCIChipSet.VendorDevice, OPTI_C832_CFID_VAL
	jne	SHORT HPC_NotOptiC832
	call    HandleOptiC832Bugs
	jmp	SHORT HPC_Exit
HPC_NotOptiC832:

	;If reached this point - No known problem with this chipset
	;----------------------------------------------------------
	clc
HPC_Exit:
	ret


HandlePCIChipset endp

;****************************************************************************
;
;       HandleIntelPCMCBugs
;
; Inputs:
;
; Outputs:
;
;
; Return values:
;
;	AX - Destroyed
;
;
;****************************************************************************
HandleIntelPCMCBugs	proc

	push	bx
	push	di

	;-----------------------------------------------------
	;Check if this is a problematic version of the chipset
	;-----------------------------------------------------
	cmp	PCIChipSet.Revision, 1
	je	SHORT HIPB_HandleIRev1Bugs

	cmp	PCIChipSet.Revision, 3
	je	SHORT HIPB_HandleRev3Bugs

	;If reached this point - No known problem with this chipset version
	;------------------------------------------------------------------
	clc
	jmp	SHORT HIPB_Exit

	;-------------------------------
	; Workaround Intel PCMC rev1 BUG
	;-------------------------------
HIPB_HandleIRev1Bugs:
	mov	bx, PCIChipSet.CS_Handle  		;BX to hold the handle.
	mov     di, SATURN_CACHE_MODE_REG_OFFSET
	call	PCIReadCfgBYTE
	jc	HIPB_ErrorExit

	;Cache MUST NOT be in WB mode or else data corruption may occure
        ;---------------------------------------------------------------
	and	cl, SATURN_SECONDARY_CACHE_MASK
	xor	cl, SATURN_SECONDARY_CACHE_ENABLE_WB
	jnz	HIPB_Exit				;Chache is NOT in WB mode -
							;No problem with this mode.

	;Cache in WB mode - BIG problem here
        ;-----------------------------------
	DataAddress     dx, WACB_WarnCacheInWBMode
	stc						;Crash the driver
	jmp	SHORT HIPB_ErrorExit


	;-------------------------------
	; Workaround Intel PCMC rev3 BUG
	; - Limit max PBL to 8
	; - No extended PCI commands !
	;-------------------------------
HIPB_HandleRev3Bugs:
	or	PCIChipSet.CS_Capabilities, PBL_MaxLimited
	mov	PCIChipset.CS_MaxPBL, PBL_8		;Limit max PBL to 8
	and	PCIchipset.CS_Capabilities, NOT (MRM_capable OR MRL_capable OR MWI_capable)

HIPB_Exit:
	clc
HIPB_ErrorExit:
	pop	di
	pop	bx
	ret

HandleIntelPCMCBugs	endp

;****************************************************************************
;
;       HandleIntelCDCBugs
;
; Inputs:
;
; Outputs:
;
;
; Return values:
;
;	AX - Destroyed
;
;
;****************************************************************************
HandleIntelCDCBugs	proc

	;--------------------------
	; Workaround Intel CDC BUGS
	;--------------------------
	cmp	PCIChipSet.Revision, 2
	jne	SHORT HICB_NotIntelCDCRev2

	;-------------------------------
	; Workaround Intel CDC rev2 BUG
	; - Limit max PBL to 8
	; - No extended PCI commands !
	;-------------------------------
	or	PCIChipSet.CS_Capabilities, PBL_MaxLimited
	mov	PCIChipset.CS_MaxPBL, PBL_8		;Limit max PBL to 8
	and	PCIchipset.CS_Capabilities, NOT (MRM_capable OR MRL_capable OR MWI_capable)

HICB_NotIntelCDCRev2:
	clc
	ret

HandleIntelCDCBugs	endp

;****************************************************************************
;
;       HandleOptiC832Bugs
;
;	   This routine implements a Work-around to the OPTI C832 bug of working
;	   with burst size of 1 causing DMA chips using low thresholds to
;	   underrun their tx buffers.
;	   The work-around is to increase DC21x4's TX_THR to MAX (FP in TWINET
;	   and Fasternet) unless the user spcificlly stated it wants a different
;	   threshold by using the TX_THR KWD in net.cfg.
;	
;
; Inputs:
;
; Outputs:
;	
; Modifies
;	PCIChipset.CS_MinTxThreshold
;
; Return values:
;
;****************************************************************************
HandleOptiC832Bugs	proc

	or	PCIChipSet.CS_Capabilities, THR_MinLimited
	mov	PCIChipset.CS_MinTxThreshold, TX_THRESHOLD_MAX+1

	clc
	ret

HandleOptiC832Bugs	endp

END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_RUNTIME
;****************************************************************************
;
; Name:         HandleTURBOOnPCIMachines
;
; Description:  This routine call is used as a temporary solution to the
;		transmit underflows and receive overflows in PCI machines which
;		use the Saturn chipset. In the Saturn DCD chip (82424) or in
;		PCMC chip (82434) there is a CPU-PCI posting enable bit. When
;		set (default by most BIOS for ISA bus better benchmarks) it
;		affects PCI and cause long latencies which makes Tulip to drop
;		packets.
;		Routine save the original value of this bit and clears this bit
;		if AX = 0, and restores the old value if AX != 0.
;		If there is no PCI on this machine, the routine will return
;		without doing anything.
;
; On Entry:     AX     0 - clear the CPU-PCI posting enable bit.
;			1 - restore the old value of the bit.
;               BX     N/A
;               CX     N/A
;               DX     N/A
;               BP     N/A
;               SI     N/A
;               DI     N/A
;
;               Note:   Interrupts are in any state.
;
; On Return:    AX     Destroyed
;               BX     Preserved
;               CX     Destroyed
;               DX     Destroyed
;               BP     Preserved
;               SI     Preserved
;               DI     Preserved
;
;               Flags:
;
;               Note:   Interrupts preserved.
;
; Remarks:      This routine is called at from DriverInit prior to resetting
;		Tulip to clear the bit, and in DriverShutdown to restore the
;		bit.
;
;****************************************************************************

SATURN_CPU_PCI_ENTRY	equ 53h
SATURN_CPU_PCI_BIT_MASK equ 0FDh

HandleTURBOOnPCIMachines proc near

	push	ax
	push	bx
	push	cx
	push	di

	;----------------------------------------
	;We can Handle TURBO on PCMC and CDC only
        ;----------------------------------------
	test 	PCIChipset.CS_Capabilities, TURBO_capable
	jz	SHORT HTP_PCIWarn				;No - Can't handle request.

	;-----------------------------------------
	;Check if it is a TURBO or DETURBO request
        ;-----------------------------------------
HTP_HandleRequest:
	or	ax, ax
	jz	SHORT HTP_HandleTURBO

	;----------------
	;DETURBO chipset
	;----------------
HTP_HandleDETURBO:
	cmp	PCIChipset.CS_TurboMode, FALSE 		;If NOT in TURBO mode - Nothing to do.
	je	SHORT HTP_Exit

	;DETURBO chipset - Perform Read-Modify-Write
	;--------------------------------------------
	mov	bx, PCIChipset.CS_Handle
	mov     di, SATURN_CPU_PCI_ENTRY
	call	PCIReadCfgBYTE                          ;Get Turbo bit
	jc	SHORT HTP_Exit
	test	cl, not SATURN_CPU_PCI_BIT_MASK		;Check TURBO bit state
	jnz	SHORT HTP_DoneDETURBO			;If already DETURBOed - Done
        						
	or	cl, not SATURN_CPU_PCI_BIT_MASK		;DeTURBO chipset.
	call	PCIWriteCfgBYTE
	jc	SHORT HTP_PCISBadCompletionStatus
HTP_DoneDETURBO:
	mov	PCIChipset.CS_TurboMode, FALSE 		;Mark "NOT in TURBO mode".
        clc
	jmp	SHORT HTP_Exit

	;--------------
	;TURBO chipset
	;--------------
HTP_HandleTURBO:
	cmp	PCIChipset.CS_TurboMode, TRUE 		;If in TURBO mode - Nothing to do.
	je	SHORT HTP_Exit

	;TURBO chipset - Perform Read-Modify-Write
	;-----------------------------------------
	mov	bx, PCIChipset.CS_Handle
	mov     di, SATURN_CPU_PCI_ENTRY
	call	PCIReadCfgBYTE                          ;Get Turbo bit
	jc	SHORT HTP_Exit
	test	cl, not SATURN_CPU_PCI_BIT_MASK		;Check TURBO bit state
	jz	SHORT HTP_DoneTURBO			;If already TURBOed - Done
        						
	and	cl, SATURN_CPU_PCI_BIT_MASK		;TURBO chipset.
	call	PCIWriteCfgBYTE
	jc	SHORT HTP_PCISBadCompletionStatus
HTP_DoneTURBO:
	mov	PCIChipset.CS_TurboMode, TRUE 		;Mark "In TURBO mode".
	jmp	SHORT HTP_Exit

	;-----------------------
	;Warning/Error Messages
        ;-----------------------
HTP_PCISBadCompletionStatus:
	DataAddress	dx, HPE_PCIErr        		;If Failed to Handle request (writing)We may have
	jmp	SHORT HTP_ErrorExit                 	;"Damaged" the chipset - Crash for safety

HTP_PCIWarn:                              		;If Unknown chipset or Failed reading Don't crash just:
	or	ax, ax                                  ; 1. Ignore the TURBO (!) request.
	jnz	SHORT HTP_NoDeturboWarning

	cmp	Nic.DriverMode, POWER_UP                ; 2. Issue a Warning message (if in POWER-UP)
	jne	SHORT HTP_NoDeturboWarning
	DataAddress	dx, HPE_PCIWarn
	call    DisplayMessage                  	
HTP_NoDeturboWarning:

	;----
	;Exit
	;----
HTP_Exit:
	clc
HTP_ErrorExit:
	pop	di
	pop	cx
	pop	bx
        pop	ax
	ret

HandleTURBOOnPCIMachines endp


END_CODE_SEGMENT_RUNTIME

;******************************************************************************
;*                	M E M O R Y   S E R V I C E S                         *
;******************************************************************************
START_DATA_SEGMENT_INIT

TEMP_MEM_SIZE	equ	256 			;In bytes
TempMem		db 	TEMP_MEM_SIZE  dup (0)  ;Temp mem

END_DATA_SEGMENT_INIT

START_CODE_SEGMENT_INIT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	AllocateMemory	Proc
;
;       	Allocates memory over the Init portion of the driver
;		(in OS2 over the INIT DATA segment) - NO OVERFLOW CHECK !!!.
;
;
;	Called:		At init with the Following parameters:
;			DI	= Pointer to DMA_DESCRIPTOR holding memory Info
;	Assumes:      	DS 	= Cgroup in DOS or Dgroup in OS2
;       Returns:        Upon Success
;		        	Carry flag   = RESET
;			Upon failure
;		        	Carry flag   = SET
;				DX Error message PTR
;	Modifies:
;		DMA_DESCRIPTOR pointed by DS:DI
;	       	All registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
AllocateMemory	Proc	Near

	push	eax

	;--------------------------------
	;Temp Memory allocation handling
	;--------------------------------
	test	(DMA_DESCRIPTOR PTR ds:[di]).MemoryType, TEMP_MEM_ALLOC 	;Temp alloc ?
	jz	SHORT AM_NotTempAlloc

	cmp	(DMA_DESCRIPTOR PTR ds:[di]).RegionSize, TEMP_MEM_SIZE		;Size checking
	ja	SHORT AM_TempErrorExit

	xor 	eax, eax
	mov	ax, di
	call	TempMemoryAllocation                                            ;Temp Mem alloc
	jc	SHORT AM_TempErrorExit

	xchg	ax, di
	mov	(DMA_DESCRIPTOR PTR ds:[di]).RegionOffset, eax		        ;Update offset field
	mov	(DMA_DESCRIPTOR PTR ds:[di]).RegionSegment, ds		        ;Update segment field
	jmp	SHORT AM_Exit

AM_NotTempAlloc:
	;----------------------------
	;Memory allocation Over Init
	;----------------------------
	test	(DMA_DESCRIPTOR PTR ds:[di]).MemoryType, SYSTEM_MEM_ALLOC 	;System alloc ?
	jnz	SHORT AM_SystemAlloc                                            ;0== OverInit, 1== Sytem
	call	AllocateMemoryOverINIT
	jc	SHORT AM_ErrorExit
	jmp	SHORT AM_Exit

	;--------------------------
	;System Memory allocation
	;--------------------------
AM_SystemAlloc:
	call	AllocateSystemMemory
	jc	SHORT AM_ErrorExit
	jmp	SHORT AM_Exit

AM_Exit:
	or	(DMA_DESCRIPTOR PTR ds:[di]).MemoryType, MEM_ALLOCATED		;Mark that mem had been allocated
	pop	eax
	clc
	ret

AM_TempErrorExit:
	DataAddress dx, AllocateMemoryError
AM_ErrorExit:
	and	(DMA_DESCRIPTOR PTR ds:[di]).MemoryType, NOT MEM_ALLOCATED	;Mark that mem had NOT been allocated
	pop	eax
	stc
	ret

AllocateMemory	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	TempMemoryAllocation	Proc
;
;		Allocates memory from local Driver's memory pool.
;		Notice That the returned address does not remain valid if another
;		Call to this routine is issued.
;
;               Max size == 256Byte
;
;	Called:		At init only with the following parameters:
;
;	Assumes:      	DS 	= Cgroup in DOS or Dgroup in OS2
;       returns:
;		DI - MEM PTR
;	       	All other registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
TempMemoryAllocation	Proc	Near

	lea	di, TempMem
        clc
        ret

TempMemoryAllocation	Endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	AllocateMemoryOverINIT	Proc
;
;       	Allocates memory over the Init portion of the driver
;		(in OS2 over the INIT DATA segment) - NO OVERFLOW CHECK !!!.
;
;
;	Called:		At init with the Following parameters:
;			DI	= Pointer to DMA_DESCRIPTOR holding memory Info
;	Assumes:      	DS 	= Cgroup in DOS or Dgroup in OS2
;       returns:        Upon Success
;		        	Carry flag   = RESET
;			Upon failure
;		        	Carry flag   = SET
;				DX Error message PTR
;	Modifies:
;		DMA_DESCRIPTOR pointed by DS:DI
;	       	All registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
AllocateMemoryOverINIT	Proc	Near

	push	eax
	push	bx

	mov	(DMA_DESCRIPTOR PTR ds:[di]).RegionSegment, ds		;Update segment field
	mov	eax, (DMA_DESCRIPTOR PTR ds:[di]).RegionSize            ;only ax will be used

IF NOS EQ ODI
	call	MSMAlloc
ELSE
	; Get pointer to end, move to new end.
	;--------------------------------------
	mov	bx, ImageEnd
	add	ImageEnd, ax
	jnc	SHORT AMOI_Exit

AMOI_ErrorExit:
	mov    ImageEnd, bx			       			;Restore Previous value
	DataAddress dx, AllocateMemoryError
	pop	bx
        pop	eax
	ret
ENDIF

AMOI_Exit:
	mov	WORD PTR (DMA_DESCRIPTOR PTR ds:[di]).RegionOffset, bx		;Update offset field
	pop	bx
        pop	eax
	clc
	ret

AllocateMemoryOverINIT	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	AllocateSystemMemory	proc
;
;       	Allocates memory From system Pool (OS2 only) - NOT IMPLEMENTED YET !!!.
;
;	Called:		At init
;	Assumes:      	DS 	= Cgroup (in DOS or Dgroup in OS2)
;       returns:        Upon Success
;		        	Carry flag   = RESET
;				DS:DI	     = FAR PTR to allocated memory block
;			Upon failure
;		        	Carry flag   = SET
;				DX Error message PTR
;	       	All registers are Preserved
;
;		Zero flag SET   - Device does NOT support ERI.
;		Zero flag RESET - Device supports ERI.
;	       	All registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
AllocateSystemMemory	Proc	Near
	DataAddress dx, AllocateMemoryError
	stc
        ret
AllocateSystemMemory	endp


END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_RUNTIME
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	VirtualToPhysical
;
; 		Converts Virtual address to a Phys one
;               In DOS:
;			Locks a memory region and retrieves it's physical Address
;		In OS2:
;			Retrieves it's physical Address
;			(We assume that memory is already locked)
;
;	Called:		At init and Run time
;	Assumes:      	DS 	= Cgroup (in DOS or Dgroup in OS2)
;			DI	= Pointer to DMA_DESCRIPTOR holding memory Info
;
;       returns:
;		Upon Failure	- Carry flag SET
;				  DX - Errormessage PTR
;		Upon Success	- Carry flag RESET.
;
;      Modifies:
;		DMA_DESCRIPTOR pointed by DS:DI
;	       	All registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
VirtualToPhysical	Proc	Near

IF OS EQ DOS
	call	DOSLockMemoryAndGetPhysicalAddress
ELSE
	call	OS2VirtToPhys
ENDIF
	jnc	SHORT VTP_Exit
	DataAddress dx, VDSLockMemoryError
VTP_Exit:
	ret

VirtualToPhysical	Endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	PhysicalToVirtual
;
;       	Converts Physical address to a virtual one
;
;	Called:		At init
;	Assumes:      	DS 	= Cgroup (in DOS or Dgroup in OS2)
;			DI	= Pointer to DMA_DESCRIPTOR holding memory Info
;       returns:
;		Zero flag SET   - Device does NOT support ERI.	   ????????????????????
;		Zero flag RESET - Device supports ERI.????????????????????????
;	       	All registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PhysicalToVirtual	Proc	Near
	stc
	ret
PhysicalToVirtual	Endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	FreeMemory	Proc
;
;         IN DOS
;       	Calls VDS services in order to unlock priviosly locked memory
;       	proir freeing it or prior to program termination.
;
;	Called:		At init and Run-time with the following parameters
;                       IN DOS
;                          di  - Holds the effective address of  a DMA_Descriptor
;                                structure holding the detailes about the memory
;                                to be unlocked.
;       assumes:        ds      Holds CGroup in DOS or DGroup in OS2
;
;       returns: noting
;       	all registers are preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
FreeMemory	Proc	Near

	;--------------------------
	;Had Memory been allocated
	;--------------------------
	test	(DMA_DESCRIPTOR PTR ds:[di]).MemoryType, MEM_ALLOCATED
	jz	SHORT FM_Exit

	;-----------------
	;Free Temp Memory
	;-----------------
	test	(DMA_DESCRIPTOR PTR ds:[di]).MemoryType, TEMP_MEM_ALLOC 	;Temp alloc ?
	jnz	SHORT FM_Exit                                                   ;Yes -> Done.

	;--------------------------------
	;Free Memory allocated Over Init
	;--------------------------------
	test	(DMA_DESCRIPTOR PTR ds:[di]).MemoryType, SYSTEM_MEM_ALLOC 	;System alloc ?
	jnz	SHORT FM_SystemFree                                            ;0== OverInit, 1== Sytem
	call	FreeMemoryOverINIT
	jc	SHORT FM_ErrorExit
	jmp	SHORT FM_Exit

	;-------------------
	;Free System Memory
	;-------------------
FM_SystemFree:
	call	FreeSystemMemory
	jc	SHORT FM_ErrorExit
	jmp	SHORT FM_Exit

FM_Exit:
	and	(DMA_DESCRIPTOR PTR ds:[di]).MemoryType, NOT MEM_ALLOCATED	;Mark that mem had been Freed
	clc
FM_ErrorExit:
	ret

FreeMemory	Endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	FreeMemoryOverINIT	Proc
;
;       	Frees memory allocated over the Init portion of the driver
;		(in OS2 over the INIT DATA segment)
;
;
;	Called:		At run-time with the Following parameters:
;			DI	= Pointer to DMA_DESCRIPTOR holding memory Info
;	Assumes:      	DS 	= Cgroup in DOS or Dgroup in OS2
;       returns:        Upon Success
;		        	Carry flag   = RESET
;			Upon failure
;		        	Carry flag   = SET
;				DX Error message PTR
;	Modifies:
;		DMA_DESCRIPTOR pointed by DS:DI
;	       	All registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
FreeMemoryOverINIT	Proc	Near

IF OS EQ DOS
	;If memory had been locked by DOS - Unlock It
        ;--------------------------------------------
	test	(DMA_DESCRIPTOR PTR ds:[di]).MemoryType, MEM_LOCKED
	call	DOSUnlockMemory
	jc	SHORT FMOI_ErrorExit
ENDIF					;Nothing to do in OS2

FMOI_Exit:
	and	(DMA_DESCRIPTOR PTR ds:[di]).MemoryType, NOT MEM_LOCKED 	;Mark that mem had been Freed
	clc
FMOI_ErrorExit:
	ret

FreeMemoryOverINIT	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       FreeSystemMemory	proc
;
;       	Frees memory allocated From system Pool  NOT IMPLEMENTED YET !!!.
;
;	Called:		At init or Run-time
;	Assumes:      	DS 	= Cgroup (in DOS or Dgroup in OS2)
;       returns:        Upon Success
;		        	Carry flag   = RESET
;				DS:DI	     = FAR PTR to allocated memory block
;			Upon failure
;		        	Carry flag   = SET
;				DX Error message PTR
;	       	All registers are Preserved
;
;		Zero flag SET   - Device does NOT support ERI.
;		Zero flag RESET - Device supports ERI.
;	       	All registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
FreeSystemMemory	Proc	Near
	stc
        ret
FreeSystemMemory	endp

IF OS EQ DOS
;*****************************************************************************
;			DOS memory services
;VDS Service are used  Used for supporting HighMem
;*****************************************************************************
;VDS interrupt number
	VDS_INTERRUPT       EQU       4Bh

; DMA Services function code
	VDS_GET_VERSION     EQU     8102h
	VDS_LOCK_REGION     EQU     8103h
	VDS_UNLOCK_REGION   EQU     8104h
	VDS_SC_GA_LOCK      EQU     8105h   ; Scatter/Gather lock region
	VDS_SC_GA_UNLOCK    EQU     8106h   ; Scatter/Gather unlock region
	VDS_REQUEST_BUFFER  EQU     8107h   ; Request DMA Buffer
	VDS_RELEASE_BUFFER  EQU     8108h   ; Release DMA Buffer
	VDS_COPY_IN_BUFFER  EQU     8109h
	VDS_COPY_OUT_BUFFER EQU     810Ah
	VDS_DISABLE_TRANSL  EQU     810Bh
	VDS_ENABLE_TRANSL   EQU     810Ch

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;       DOSLockMemoryAndGetPhysicalAddress
;
;       Routine checks if VDS are enabled, if so it calls VDS to Lock the
;       memory region its pointed by the descriptor pointed by SI and gets its
;       physical address.
;       If VDS are disabled it calculates the physical address from seg:offset
;       using the conventional 8086 way.
;
;       assumes:        ds      is set to CGroup
;                       CLD has been executed
;
;
;                       di      Pointer to VDS_Structure containing the info on
;                               The memory region to be locked and it's physical
;                               address we wish to get.
;
;       returns:        Physical address of the memory (written in the same
;                       structure). If VDS are enabled Locking of the memory.
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DOSLockMemoryAndGetPhysicalAddress PROC near

	push    es
	push    edx
	push    eax

	call    AreVDSServicesAvailale
	jc      SHORT NoVDSServicesAvailable

	;--------------------------------------------------
	;if reached this point VDS Are available - use them
	;--------------------------------------------------
	push    ds
	pop     es                    ;es:di -> DMA descriptor
	mov     ax, VDS_LOCK_REGION
	xor     edx, edx
	int     VDS_INTERRUPT
	jc     	SHORT LMAGPA_Exit

	mov	ax,VDS_UNLOCK_REGION	;now unlock the memory.
	xor	dx,dx
	int	VDS_INTERRUPT

	;Mark that memory had been successfully locked
        ;----------------------------------------------
        clc
	jmp	SHORT LMAGPA_Exit

NoVDSServicesAvailable:
	;--------------------------------------------
	;Calculate Physical address in the Simple way
	;PhysicallAddress = (Segment << 4) + offset
	;--------------------------------------------
	xor     eax, eax
	mov     ax, (DMA_DESCRIPTOR PTR DS:[di]).RegionSegment
	shl     eax, 4
	add     eax, (DMA_DESCRIPTOR PTR DS:[di]).RegionOffset
	mov     (DMA_DESCRIPTOR PTR DS:[di]).PhysicalAddress, eax

	;Mark that operation had successfully completed wo locking mem
	;(No need to lock mem since VDS are not enabled)
        ;--------------------------------------------------------------
	clc

LMAGPA_Exit:
	pop     eax
	pop     edx
	pop     es
	ret

DOSLockMemoryAndGetPhysicalAddress  ENDP

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       DOSUnlockMemory
;
;       Calls VDS services in order to unlock priviosly locked memory
;       proir freeing it or prior to program termination.
;       assumes:        ds      Holds CGroup
;                       di      Holds the effective address of  a DMA_Descriptor
;                               structure holding the detailes about the memory
;                               to be unlocked.
;       returns: noting
;       all registers are preserved
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DOSUnlockMemory proc near

	call    AreVDSServicesAvailale
	jnc     SHORT VDSServicesAvailale
	clc
	ret                             ;No VDS -> NO need to unlock memory

VDSServicesAvailale:
	push    ax
	push    dx
	push    es

	push    ds
	pop     es                              ;es=ds
	mov     ax, VDS_UNLOCK_REGION
	xor     dx, dx
	int     VDS_INTERRUPT

	pop     es
	pop     dx
	pop     ax
	ret
DOSUnlockMemory         ENDP
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;AreVDSServicesAvailale
;
;Checks if VDS services are enabled.
;Examine bit five (5) of the byte at 0040:007Bh.
;If the bit is set then should use the DMA services. Otherwise,
;the device can assume that all memory is mapped linear=physical.
;(Can be a dangerous assumption )
;       returns:
;               Carry   SET    If Services are NOT enabled
;                       RESET  If Services are enabled
;       all registers are preserved
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
AreVDSServicesAvailale  PROC near
	push    ax
	push    es

	mov     ax, 40h                 ;test byte at 40:7b
	mov     es, ax                  ;to see if VDS is supported
	test    BYTE PTR es:7Bh, 20h
	jnz     SHORT VDSServicesAvailable

	stc     ;pws Z = No VDS
VDSServicesAvailable:
	pop     es
	pop     ax
	ret
AreVDSServicesAvailale  ENDP


ELSE
;*****************************************************************************
;			OS2 memory services
;*****************************************************************************
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       OS2VirtToPhys
;
; 		Converts Virtual address to a Phys one
;		In OS2:
;			Retrieves it's physical Address
;			(We assume that memory is already locked)
;
;	Called:		At init and Run time
;	Assumes:      	DS 	= Cgroup (in DOS or Dgroup in OS2)
;			DI	= Pointer to DMA_DESCRIPTOR holding memory Info
;
;       returns:
;		Upon Failure	- Carry flag SET
;		Upon Success	- Carry flag RESET.
;
;      Modifies:
;		DMA_DESCRIPTOR pointed by DS:DI
;	       	All other registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
OS2VirtToPhys	Proc	Near

	push	eax
	push 	bx
	push 	dx
	push	si
        push	ds
	push	es

	push	ds
        pop	es							;Let ES be as DS
							
	mov 	dl, DEVHLP_VIRTTOPHYS                   		;DL - function ID
	mov	eax, (DMA_DESCRIPTOR PTR es:[di]).RegionOffset  	;si - Offset
        mov	si, ax
	mov	ax, (DMA_DESCRIPTOR PTR es:[di]).RegionSegment  	;DS - Segment
	mov	ds, ax

	call 	DWORD PTR ES:[devhlp]
	jc	SHORT OS2VTP_Exit
	shl 	eax, 16
	mov 	ax, bx
	mov	(DMA_DESCRIPTOR PTR es:[di]).PhysicalAddress, eax
	clc

OS2VTP_Exit:
	pop	es
	pop	ds
	pop	si
	pop 	dx
	pop 	bx
        pop	eax
	ret

OS2VirtToPhys	Endp

ENDIF

END_CODE_SEGMENT_RUNTIME


;******************************************************************************
;*                 I N T E R R U P T   S E R V I C E S                        *
;******************************************************************************
IF NOS EQ NDIS2
IF OS EQ DOS
START_DATA_SEGMENT_RUNTIME

	PICIntMaskPort		dw	0    	;Holds port's Address
	PICIntMaskOff		db	0 	
	PICIntMaskOn 		db      0
	PICIntMaskOrigin 	db      0       ;Original Port's mask (befor our intrvention).
	SlavePICNeedsEOI	db      FALSE
	IntVectorSaveLocation	dw      0       ;ISR Entry in the interrupt table
	IntVectorSave		LONG_PTR <0,0>  ;PREV isr which was located in the above entry

END_DATA_SEGMENT_RUNTIME
ENDIF
ENDIF

START_CODE_SEGMENT_INIT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	DoesSystemSupportERI
;
;
;	Called:		At init
;	Assumes:      	DS 	= Cgroup (in DOS or Dgroup in OS2)
;       returns:
;		Carry flag SET   - Device does NOT support ERI.
;		Carry flag RESET - Device supports ERI.
;	       	All registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DoesSystemSupportERI	proc	near

IF OS EQ OS2              ;OS2 Does not support ERI
	stc
ELSEIF NOS EQ ODI         ;ODI DOS supports ERI
	clc
ELSE                      ;NDIS2 DOS does not support ERI
	stc
ENDIF
	ret

DoesSystemSupportERI	endp

END_CODE_SEGMENT_INIT


START_CODE_SEGMENT_BIND
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	BindInterrupts	proc
;
;	Routine calles the OS for connecting the driver's ISR/s to the
;       specified interrupt number.
;	In DOS -
;	  Since interrupt sharing is supported by the driver the routine will
;	  save the previous interrup handler found in that entry.
;
;	Called:		At BIND time  with the following pararmeters:
;				Interrupts = Disabled
;				BX	   = Interrupt number.
;
;	Assumes:      	DS 	= Cgroup in DOS or Dgroup in OS2
;			In NSDIS2  Valid IRQ numbers are: 0-0Fh w.o IRQ 2
;
;       returns:
;		Upon success:
;			Carry flag RESET.
;		Upon Failure:
;			Carry flag SET.
;			DX - Error message PTR
;
;	       	All registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
BindInterrupts	proc	near

IF NOS EQ ODI
	;------------------------------------------------------------------
	;ODI - Hook interrupt vector (INT# will be taken from Config table)
	;------------------------------------------------------------------
	call	MSMSetIRQ
ELSE
	call	NDISSetIRQ
ENDIF
	jc	SHORT BI_ErrorExit
        ret

BI_ErrorExit:
	DataAddress	dx, BadInterruptAllocation
        ret

BindInterrupts	endp

IF NOS EQ NDIS2
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	NDISSetIRQ	proc
;
;	Routine calles the OS for connecting the driver's ISR/s to the
;       specified interrupt number.
;	In DOS -
;	  Since interrupt sharing is supported by the driver the routine will
;	  save the previous interrup handler found in that entry.
;
;	Called:		At BIND time  with the following pararmeters:
;				Interrupts = Disabled
;				BX	   = Interrupt number.
;
;	Assumes:      	DS 	= Cgroup in DOS or Dgroup in OS2
;			Valid IRQ numbers are: 0-0Fh w.o IRQ 2
;
;       returns:
;		Upon success:
;			Carry flag RESET.
;		Upon Failure:
;			Carry flag SET.
;			DX - Error message PTR
;
;	       	All registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NDISSetIRQ	proc	near

IF OS EQ OS2
	call	NDISOS2SetIRQ
ELSE
	call	NDISDOSSetIRQ
ENDIF
	ret

NDISSetIRQ	endp

IF OS EQ OS2
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	NDISOS2SetIRQ	proc
;
;	Routine calles the OS for connecting the driver's ISR/s to the
;       specified interrupt number.
;
;	Called:		At BIND time  with the following pararmeters:
;				Interrupts = Disabled
;				BX	   = Interrupt number.
;
;	Assumes:      	DS 	= Cgroup in DOS or Dgroup in OS2
;			Valid IRQ numbers are: 0-0Fh w.o IRQ 2
;
;       returns:
;		Upon success:
;			Carry flag RESET.
;		Upon Failure:
;			Carry flag SET.
;
;	       	All registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NDISOS2SetIRQ	proc	near

	push	ax
	push	dx

	;--------------------------------------------------------
	;		      NDIS2-OS2
	; Use NOS services for hooking the interrupt.
	; BX holds IRQ Number, AX holds ISR's address
	;--------------------------------------------------------
	mov	ax, offset CGroup:InterruptMain ; AX holds ISR address.
	mov   	dh, SETIRQ_SHARED               ; DH = yes, a shared interrupt
	mov   	dl, DEVHLP_SETIRQ               ; DL = Function code SetIRQ
	push	ax
        push	bx
	call  	ds:[devhlp]                     ; Call OS/2 device helper
	pop	bx
        pop	ax
	jnc   	NOSI_Exit                       ; success means we're done

   	;If shared interrupt fails, try unshared
	;---------------------------------------
	mov   dh, SETIRQ_NOT_SHARED           ; DH = NOT a shared interrupt
	mov   dl, DEVHLP_SETIRQ               ; DL = Function code SetIRQ
	call  ds:[devhlp]                     ; Call OS/2 device helper

	;If SETIRQ failed, carry is set, and returned to caller, who will fail
	;the Bind.
        ;---------------------------------------------------------------------

NOSI_Exit:
	pop	dx
	pop	ax
        ret

NDISOS2SetIRQ	endp

ENDIF

IF OS EQ DOS
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	NDISDOSSetIRQ	proc
;
;	Routine calles the OS for connecting the driver's ISR/s to the
;       specified interrupt number.
;	  Since interrupt sharing is supported by the driver the routine will
;	  save the previous interrup handler found in that entry.
;
;	Called:		At BIND time  with the following pararmeters:
;				Interrupts = Disabled
;				BX	   = Interrupt number.
;
;	Assumes:      	DS 	= Cgroup in DOS or Dgroup in OS2
;			Valid IRQ numbers are: 0-0Fh w.o IRQ 2
;
;       returns:
;		Upon success:
;			Carry flag RESET.
;		Upon Failure:
;			Carry flag SET.
;			DX - Error message PTR
;
;	       	All registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NDISDOSSetIRQ	proc	near

	;--------------------------------------------------
	;		 NDIS2-DOS
	; Need to Hook interrupt vector ourselvs
	;--------------------------------------------------
	push	es
        push	di
	push	dx
	push	cx
	push	bx
	push	ax	

	;--------------------------------------------------------------------
	; Since OS2 (!) will Fail if trying to bind IRQ 2 (cascade int)
	; we will do the same in DOS
	;--------------------------------------------------------------------
	cmp	bx, 2
	je	SHORT NDSI_ErrorExit
				
	;-------------------------------
	; Enable the interrupt in PIC.
	;-------------------------------
	mov	cx, bx			; Put IRQ Number in CX (actually in CL).
	cmp	cl, 8			; Is IRQ on slave?
	jb	SHORT NDSI_MasterOnly

	;-------------------------------
	; Interrupt is on the Slave PIC
	;-------------------------------
	mov	SlavePICNeedsEOI, TRUE	; Mark that EOI is needed on Slave too.

	;Enable Int2 entry in MASTER PIC since slave is connected to it
        ;--------------------------------------------------------------
	in	al, 21h			; Get the current mask
	and	al, not 4		; IRQ 2 bit enabled
	out	21h, al                 ; Enable IRQ2

	;Set PIC params
        ;--------------
	sub	cl, 8                   ; Adjest IRQ#
	mov	dx, 0a1h		; PIC 2's mask port
	mov	di, 70h			; Base int of PIC 2's vectors
	jmp 	SHORT NDSI_GetIRQMasks

	;--------------------------------
	; Interrupt is on the Master PIC
	;--------------------------------
NDSI_MasterOnly:
	mov	SlavePICNeedsEOI, FALSE	; MasterOnly = 0
	mov	dx, 21h			; PIC 1's mask port
	mov	di, 08h			; Base int of PIC 1's vectors

	;----------------------------------------------
	; Get/Save the Interrupt Mask Bit and Maskport
	;----------------------------------------------
NDSI_GetIRQMasks:

	;Save PIC's mask port address
        ;----------------------------
	mov	PICIntMaskPort, dx

	mov	ah, 1			; AH = 1
	shl	ah, cl			; align "1" bit to Correct port bit mask location.

	;Save port Disable Interrupt Mask
        ;--------------------------------
	mov	PICIntMaskOff, ah

	;Save port Enable Interrupt Mask
        ;-------------------------------
	not	ah
	mov	PICIntMaskOn, ah

	;Get the current mask
        ;--------------------
	in	al, dx			

	;Save OLD (original) port's mask
        ;-------------------------------
	push 	ax
	and 	al, PICIntMaskOff
	mov     PICIntMaskOrigin, al
	pop	ax

	;Enable our port's interrupts
        ;----------------------------
	and	al, ah			
	out	dx, al			

	;-------------------------------------------------
	; Save the old Interrupt vector and install OURs.
	;-------------------------------------------------
	xor	ax, ax
	mov	es, ax				; ES = 0; Int Table Seg
	mov	al, cl				; AX = Int number
	add	di, ax				; Move over to correct Int number
	shl	di, 2				; Calc Vector Address (Dword offset)
	mov	IntVectorSaveLocation, di	; Save for easy undoing later
	mov	ax, offset CGroup:InterruptMain ;Get ISR address
	xchg	ax, (LONG_PTR ptr es:[di])._off	; Swap out old for ours
	mov	IntVectorSave._off, ax		; Save off the Offset
	mov	ax, cs				; CX = CGroup
	xchg	ax, (LONG_PTR ptr es:[di])._seg	; Swap out old for our Segment
	mov	IntVectorSave._seg, ax		; Save off the Segment

	clc
NDSI_Exit:
	pop	ax
	pop	bx
	pop	cx
	pop	dx
	pop	di
        pop	es
	ret

NDSI_ErrorExit:
	stc
	jmp	SHORT NDSI_Exit

NDISDOSSetIRQ	endp

ENDIF
ENDIF

END_CODE_SEGMENT_BIND


;******************************************************************************
;*                 	     T I M E   S E R V I C E S                        *
;******************************************************************************
START_CODE_SEGMENT_RUNTIME

	PAGE
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       Delay
;
;       Delay receives (on the stack) a delay count (1Count = 419 nsec).
;       And returns after this Time delay expires.
;
;       assumes:        Interrupts disabled (and remain disabled).
;
;
;	Input  :	Time delay in Counts (1Count=419nSec) passed on stack.
;
;       returns:	All registers preserved
;                       Interrupts disabled
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DelayCountOffset	equ	4

Delay  proc    near

	push	bp                    	;Save BP
	mov	bp, sp

	push    ax
	push	bx
	push	cx

	call    ReadTickCounter         ;Get initial value
	mov     bx, ax                  ;Save start value

Delay_WaitForCountToFinish:
	call    ReadTickCounter
	mov	cx, bx
	sub	cx, ax
	cmp     cx, [bp + DelayCountOffset]
	jb      SHORT Delay_WaitForCountToFinish

	pop	cx
	pop     bx
	pop	ax
	pop	bp
	ret

Delay  endp

    PAGE
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       PostResetDelay
;
;       Tulip spec calls for 50 PCI cycles of delay between Tulip reset
;       and further Tulip accesses. Slowest PCI clock is 16Mhz. At 10Mhz PCI
;       clock (with safety margin) we have to wait 50cycles/10Mhz = 5000nsec.
;       ReadTickCounter gives 419 nsec per count. We have to delay a delta
;       count of  5000ns/419ns = 11.93. We will rount it up to 12.
;
;       Bottom line is that this routine returns after 5usec.
;
;       assumes:        Interrupts disabled
;
;       returns:        ax      has the current count
;                       All other registers preserved
;                       Interrupts disabled
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PostResetDelay  proc    near

	push    WORD PTR 12     ;Push delay count
	call    Delay
        add	sp, 2		;Get rid of the parameter
	ret

PostResetDelay  endp

    PAGE
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       ReadTickCounter
;
;       Reads the Timer tick count register which decrements by 2 from 65536
;       to 0 every 1/36.414 of a second.  Each 2 decrements of the count
;       represents 838 nsec's.
;
;       assumes:        Interrupts disabled
;
;       returns:        ax      has the current count
;                       All other registers preserved
;                       Interrupts disabled
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ReadTickCounter proc    near

	mov     al, 06h
	out     43h, al                 ;Command 8254 to latch T0's count

	;Now read the count.

	in      al, 40h                 ;Read LSB first
	mov     ah, al
	in      al, 40h                 ;Read MSB
	xchg    al, ah                  ;Get in proper order
	ret

ReadTickCounter endp

END_CODE_SEGMENT_RUNTIME

;******************************************************************************
;*                 	    P R I N T   S E R V I C E S                       *
;******************************************************************************
IF NOS EQ NDIS2
START_DATA_SEGMENT_BIND

HexByteTable   DB "0123456789ABCDEF" 	; Translation table for InitPrintHexByte

IF OS EQ OS2
ddtmp   DW	?				; For OS2 only. Dummy variable to hold DOSWRITE return code.
ENDIF

END_DATA_SEGMENT_BIND
ENDIF

START_CODE_SEGMENT_BIND

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;	DisplayMessage	proc
;
;	Routine For displaying 0 terminated messege on the screen.
;
;	Called:		At Init and Bind times with the following pararmeters:
;				DX = Message PTR	
;	Assumes:      	DS 	= Cgroup (in DOS or Dgroup in OS2)
;       returns:
;	       	All registers are Preserved
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DisplayMessage	Proc	Near

IF NOS EQ ODI   	
	pushf
	cmp	Nic.DriverMode, POWER_UP
	jne	SHORT DMSG_Exit
	call	MSMPrintStringZero  	;ODI uses MSM Printing util with String ends with 0.
DMSG_Exit:
	popf
	ret
ELSE
	pushf
	push	si
	mov	si, dx
	call	PrintMessageZ
	pop	si
	popf
	ret
ENDIF

DisplayMessage	endp

IF NOS EQ NDIS2

	PAGE
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; PrintMessage
;
; This function prints a message pointed to by DS:SI, that is CX bytes long.
; This function uses the BIOS video service at INT 10 to provide an OS
; independent method for displaying messages to the console during driver
; init.
;
; All registers and flags are saved.
;
; Arguments:  DS:SI - Far pointer to message to print
;                CX - Message length in bytes
;
; Algorithm:
;
; BEGIN
;    save flags
;    clear direction flag
;    do {
;      get char at DS:(SI++)
;      call INT 10 to print to console
;      CX--
;    while (CX != 0)
;    restore flags
; END
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PrintMessage  PROC NEAR

IF OS EQ DOS
        push si
        push ax
        push bx
        push cx
        pushf           	;    save flags
        cld             	;    clear direction flag
        mov  bx,0Fh     	;    Set video attributes for INT 10 call
pm_loop:                	;    do {
        lodsb           	;      get char at DS:(SI++)
        mov  ah,0EH
        int  10H        	;      call BIOS INT 10 to print to console
        loop pm_loop    	;      CX--
                        	;    while (CX != 0)
	popf            	;    restore flags
        pop cx
        pop bx
        pop ax
        pop si
        ret

ELSE 					; OS EQ OS2
	pushf
	cmp	nic.DriverMode, POWER_UP
	jne	PM_exit			; in OS2 we can print only during init-time
					; This is because we can't use DOSCALLS.LIB
					; after init-time.
	push ax
        push 1            		; write to file handle 1 = stdout
        push ds           		; DS:SI points to message to print
        push si
        push cx           		; Message is CX bytes long
        push ds           		; DS:ddtmp holds return value from call
        push OFFSET DGroup:ddtmp
        call DOSWRITE
        pop  ax
PM_exit:
	popf
	ret
ENDIF
PrintMessage  ENDP

	PAGE
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; PrintMessageZ 	proc
;
; This function prints a message pointed to by DS:SI, that is terminated by a
; zero byte.
;
; All registers are saved.
;
; Arguments:  DS:SI - Far pointer to message to print
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PrintMessageZ	PROC    NEAR

        pusha                           ; save registers
        push  es                        ;

        mov   ax, ds                    ;
        mov   es, ax                    ;
        mov   di, si                    ; ES:DI = DS:SI
        xor   al, al                    ; zero byte
        mov   cx, -1                    ; init scan count
        cld                             ; set scan direction
        repne scasb                     ; scan for the zero byte

        neg   cx                        ;
        sub   cx, 2                     ; number of bytes before zero byte
        call  PrintMessage          	; print that much

        pop   es                        ; restore registers
        popa                            ;
        ret                             ; return to caller

PrintMessageZ	ENDP

        PAGE
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; PrintHexByte	proc
;
; This function simply prints the hex byte in AL at the console. All
; registers are preserved.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PrintHexByte  PROC  NEAR
IF OS EQ DOS
        push 	ax
        push 	bx
        push 	cx
        mov  	cx,ax                    	; Save AX in CX momentarily
        DataAddress  bx, HexByteTable   	; Place offset of translation table in BX
        and  	al,0F0H                  	; Get AL upper nibble
        shr  	al,4                     	; Shift it into place
        xlat                          		; Convert AL to ASCII equivalent
        mov  	ah,0EH                   	; Load 'Teletype' function code in AH
        mov  	bx,0FH                   	; Set video attribute for INT 10 call
        int  	10H                      	; Call BIOS video service
        mov  	ax,cx                    	; Restore AX
        DataAddress bx, HexByteTable   		; Place offset of translation table in BX
        and  	al,0FH                   	; Get AL lower nibble
        xlat                          		; Convert AL to ASCII equivalent
        mov  	ah,0EH                   	; Load 'Teletype' function code in AH
        mov  	bx,0FH                   	; Set video attribute for INT 10 call
        int  	10H                      	; Call BIOS video service
        pop  	cx
        pop  	bx
        pop  	ax
        ret
ELSE				       ; OS2
	cmp	nic.DriverMode, POWER_UP
	jne	PHB_exit

	push  	ax
        push  	bx
        push  	cx
        mov   	cx, ax                  	; Save AX in CX momentarily
        and   	al, 0F0h                	; Isolate upper nibble first
        shr   	al, 4
	movzx  	bx, al
	add   	bx, offset DGroup:HexByteTable 	; DS:BX now points to ASCII equivalent
        push  	1                       	; Write to file handle 1 = stdout
	push  	ds                      	; DS:BX points to message to print
        push  	bx
        push  	1                       	; Message is 1 character long
        push  	ds                      	; DS:ddtmp holds return code
	push  	OFFSET DGroup:ddtmp
	call  	DOSWRITE

        mov   	ax, cx                  	; Restore AX
        and   	al, 0Fh                 	; Isolate lower nibble first
	movzx  	bx, al
        add   	bx, offset DGroup:HexByteTable 	; DS:BX now points to ASCII equivalent
        push  	1                       	; Write to file handle 1 = stdout
        push  	ds                      	; DS:BX points to message to print
        push  	bx
        push  	1                       	; Message is 1 character long
	push  	ds				; DS:ddtmp holds return code
	push  	OFFSET DGroup:ddtmp
        call  	DOSWRITE
        pop   	cx
        pop   	bx
	pop   	ax
PHB_exit:
        ret
ENDIF
PrintHexByte  ENDP

ENDIF

END_CODE_SEGMENT_BIND


;-----------------;
; Sanity checking ;
;-----------------;

;OS type checking
;----------------
IF OS EQ DOS
	%OUT SYSSRVCS.ASM Compiling for DOS.
ELSEIF OS EQ OS2
	%OUT SYSSRVCS.ASM Compiling for OS2.
ELSE
	.ERR
	%OUT SYSSRVCS.ASM Illegal OS value.
ENDIF

;NOS type checking
;-----------------
IF NOS EQ ODI
	%OUT SYSSRVCS.ASM Compiling for ODI.
ELSEIF NOS EQ NDIS2
	%OUT SYSSRVCS.ASM Compiling for NDIS2.
ELSE
	.ERR
	%OUT SYSSRVCS.ASM Illegal NOS value.
ENDIF

END
