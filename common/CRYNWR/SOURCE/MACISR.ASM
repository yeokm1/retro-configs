PAGE    ,132
NAME    MACISR
TITLE   MACISR  --  Digital Internal Use Only

;***************************************************************************
;*
;*    Copyright (c) 1993, 1994
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
; This module contains the interrupt service routine, and related functions,
; for the DC21040 NDIS 2.01 driver.
;
; Maintainers:
;       eg      Eric Goldstein
;       mf      Maurene Fritz
;       ymf     Yishai Fraenkel
;       as	Adi Shaliv
;	de	Dror Efraty
;
; Revision History:
;
; 11-May-1994   eg      Syntax changes for MASM 6.1.
;
;  9-Jun-1994   mf      Add interrupt sharing support
;                              1) InterruptInit:
;                                    in DOS, save int vector for chaining
;                                            while hooking our vector
;                                    in OS2, tell dev_hlp that we share
;                                            interrupts
;                              2) InterruptMain: if re-entered, or if
;                                    no interrupt for us,
;                                    (DOS)chain to saved interrupt
;                                    (OS2)exit from isr
;
;                                    move SAVE_DOS_STACK until after decision
;                                    to chain
; 20-jun-1994   mf     Temporarily do not set interrupt sharing in OS/2
;                      (dev_hlp SETIRQ uses SETIRQ_NOT_SHARED; change to SHARED
;                      when we figure out why this does not work)
;
;  7-jul-1994   mf     Make interrupt sharing work for OS/2:
;                      1) check whether SETIRQ succeeds in InterruptInit
;                         if it fails, return carry set
;                      2) In InterruptMain, for OS/2 set or clear the carry
;                         depending on whether we are ignoring the interrupt
;                         (set) or handling it (clear) just before return.
;
; 28-jul-1994   mf     If shared interrupt fails, try to use unshared intrpt
;
; 21-Aug-1994   ymf    When resetting CSR5 - Do not touch the TU bit
;                      in order not to harm the TxHang algorithm.
;
; 21-Nov-1994   ymf    When deciding if interrupt has originated from TULIP,
;                      check if a previous interrupt was pending before reset
;                      was preformed. In this case , although CSR5 doesn't
;                      indicate the TULIP caused the interrupt, we don't jump
;                      to the chained ISR. This thing prevents a crash in case
;                      the standard int handler masks the PIC entry of the
;                      TULIP.
;
; 20-Apr-1995   ymf     Add TULIP3 autosense support in InterruptMain
;
; 05-May-1996   as     1. Change CSR5_Image to Nic.CSR5_Image.
;                      2. Change the routine call for PortResetSIA to
;			  call for Mac2PhySetConnection.
; 21-Apr-1996  as 	Change the IRQ support off the Adapter in
;			InterruptInit now support IRQ 3-15.
;
; 14-Nov-1996	de	Move TULIP3 autosense suppurt to MAC2PHY module
;
; 25-Nov-1996	de	Changes in include file names, and in AWK conventions.
;
.xlist                 ; disable listing the include file
include seg_defs.inc
include macro.inc
include dc_regs.inc
include nic.inc
include driver.inc
include ndis.inc
include syssrvcs.inc
include macisr.ash
.list                                   ; enable listing
.386

START_DATA_SEGMENT_RUNTIME

IF OS EQ DOS
		ALIGN 2

IntStackOverflow DW ?            ; For DEBUG can set break on write
		 DB 512 DUP (?)  ; For DOS only, define a 512 byte interrupt stack
InterruptStack   DW ?

save_int_ss     DW ?
save_int_sp     DW ?

ENDIF

InterruptSemaphore  DB 0


END_DATA_SEGMENT_RUNTIME


START_CODE_SEGMENT_RUNTIME

	
		PAGE

; *****************
; * InterruptMain *
; *****************
;
; This is the device ISR. This ISR handles all interrupts from the adapter.
;
; Algorithm:
;
; BEGIN
;
;   Check if this interrupt is for us; if not (either semaphore set or
;   no interrupt set in CSR5), chain
;
;   Mask adapter interrupts
;
;   acknowledge (re-arm) adapter interrupt at the PIC chip
;
;   re-enable system interrupts
;
;   (OS/2 only) switch to protected mode if necessary
;
;   Platform Specific Processing Goes Here
;
;   (OS/2 Only) Restore CPU mode
;
;   Re-Enable adapter interrupts
;
;   On exit, under OS/2 carry is clear if we handled this interrupt;
;                       carry is set if we did not handle this interrupt.
; END

InterruptMain   PROC    FAR

	ENTER_ISR                       ; Do OS specific entry stuff

	cli                             ; Momentarily block system interrupts
	cld                             ; Set the direction flag forward

IF OS EQ OS2
	MOVE_TO_PROTECTED_MODE

	jnc  im_protected_ok	       ; call is successful jump to further processing

; else prepare to exit

	pop  ax
	;sti			(MOTIH) - DO NOT ENABLE INRTERRUPS ! ; set interrupts to exit properly from the isr
	stc			; set carry to tell OS/2 we didn't handle the interrupt
	jmp  im_isrdone		; exit

im_protected_ok:
ENDIF

	cmp  InterruptSemaphore, 0
	je   im_clear                   ; if it was already set, chain

;------------------- Support interrupt sharing

im_chain:

IF OS EQ OS2
	jmp  im_exit_not_our_isr     ; normal return, OS2 handles chain
ENDIF

IF OS EQ DOS
	POP_REGISTERS                      ; clean up caller's stack
	jmp  DWORD PTR cs:IntVectorSave    ; Jump to next interrupt
ENDIF


im_clear:
; Block adapter ints (use caller's stack)

	mov     dx,  Nic.CSR7_Address
	xor	eax, eax
	out	dx, eax

;     Is this interrupt for us?

	;Get the interrupt status bits (CSR5)
	;------------------------------------
	mov     dx,  Nic.CSR5_Address
	in      eax, dx

	;Test if this interrupt is from Tulip
	;------------------------------------
	and	eax, Nic.Shadow_CSR7_Mask
	and	eax, Nic.Shadow_CSR7
	jnz     im_our_int                        ; it's our interrupt

	cmp     TulipIntPosted, 1 ;Was an unterrupt posted from prev. reset?
	je      im_posted_int
	;Not our interrupt; restore adapter interrupts and chain
	;-------------------------------------------------------
	SET_ADAPTER_INTERRUPT
	jmp     im_chain

im_posted_int:
	;Previous possible interrupt posted before Chip reset
	;----------------------------------------------------
	mov     TulipIntPosted, 0
	AckPIC		           ; Issue EOI to the 8259 PIC Chips

	jmp     im_exit

	;Clear the Tulip active interrupts
	;---------------------------------
im_our_int:
	mov     TulipIntPosted, 0
	mov	InterruptSemaphore, 1

;	since only bits that are not masked by CSR7 are written to CSR5,
;	we don't need to clear TU bit in eax, since it is never set in CSR7
;       unless this is a false interrupt for handling RxHang or handling
; 	the Rx ring after an IndicationOff request.
;	and     eax, NOT CSR5_TU         ; dont write TU bit (TxHang Stuff)
	out     dx, eax

	mov     Nic.CSR5_image, eax         ;save for later use

	and	Nic.Shadow_CSR7, NOT CSR7_TUM	; disable TU bit in CSR7

	SAVE_DOS_STACK                  ; Use our own stack

	AckPIC  		        ; Issue EOI to the 8259 PIC Chips

	sti                             ; Re-enable system wide interrupts

	;Check if Link sense/Nway interrupt
	;----------------------------------
	test	Nic.CSR5_image, CSR5_LC or CSR5_LNF or CSR5_ANC or CSR5_LNP
	jz	SHORT im_DoneLinkInt
	call	Mac2PhyLinkHandler
im_DoneLinkInt:

;---------------------------
; ISR Processing Goes Here
;---------------------------
;   add some error checking on CSR5  such as:
;	Transmit underflow (CSR5_UNF)
;	Abnormal interrupt (CSR5_TJT or CSR5_SE)
;
; Handle Receive interrupt
; ------------------------
	call RcvMain

	RESTORE_DOS_STACK

;
; At this point, the indications_issued flag is checked. If this interrupt
; event resulted in frames being passed up the protocol stack by the
; IndicateToProtocol function in MACRCV.ASM, then the indications_issued
; flag has been set, signifying that we should call IndicationComplete at
; this time. The call to IndicationComplete is delayed to this point to meet
; the criteria detailed in the NDIS 2.01 spec for calling the function.
;
; 1) The system interrupts are enabled, but the interrupt at the adapter
;    has been dismissed
;
; 2) The time critical functions have been carried out, and now the protocol
;    stack gets time to do its post-indication processing.
;
; 3) If this is MS-DOS, the stack on which the interrupt occurred has been
;    restored.
;
	cmp  RcvIndicationsIssued, 0    ;    if (RcvIndicationsIssued flag set)
	jz   im_ind_complete

;	push NDISCommonChar.cc_modid    ;       PUSH WORD MACID
;	push ProtDS                     ;       PUSH WORD ProtDS
;        sti				;	Routine must be called with interrupts ENABLED !
;	cld
;	call [IndicationComplete]       ;       Call IndicationComplete

im_ind_complete:

im_exit:


	
;
; Momentarily disable system interrupts, and re-enable hardware interrupts
; at the ESIC chip. Interrupts will be re-enabled on return from the ISR, since
; the processor flags are restored on return from interrupt
;

	cli
	
	mov InterruptSemaphore, 0

	call ReqHandlePendingRequests

	SET_ADAPTER_INTERRUPT

IF OS EQ OS2
	BACK_TO_INITIAL_MODE
	clc		; clear carry to tell OS2 we handled the interrupt
ENDIF
im_isrdone:
	EXIT_ISR

im_exit_not_our_isr:
IF OS EQ OS2
	BACK_TO_INITIAL_MODE
	stc		; set carry to tell OS2 we didn't handle the interrupt
ENDIF
	EXIT_ISR

InterruptMain   ENDP

END_CODE_SEGMENT_RUNTIME

END

