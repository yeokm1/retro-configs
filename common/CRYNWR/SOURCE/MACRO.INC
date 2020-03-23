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
; This module contains macros that are called from within the DC21040 NDIS 2.01
; driver.
;
; Maintainers:
;	eg	Eric Goldstein
;   	mf  	Maurene Fritz
;	ymf	Yishai Fraenkel
;       as      Adi    Shaliv
;       de      Dror Efraty
;
; Revision History:
;
; 10-May-1994	eg	ENTER/EXIT_ISR save/restore extended registers, since
;			they are used extensively in interrupt processing.
;
; 16-Jun-1994   mf  	new macro POP_REGISTERS, for DOS interrupt sharing
;
;  7-Jul-1994   mf  	Modify EXIT_ISR so that it does not clear carry under
;                   	OS/2 (macisr must decide...this is the signal whether
;                   	it's our interrupt or not)
;
; 11-Jun-1995	ymf	Add FNET_SET_REGS to set correct values in CSR6, GPR
;			control and data, AFTER PortConfigGPR was correctly set.
;
; 05-Sep-1995   as      Move GetMediaEntry from srom.asm
;                       this macro translate media number to addr pointer in
;                       the media blocks table.
;
; 19-Nov-1996   de      Change macros to fit the new AWK. Add PCI_BIOS_CALL macro
; 25-Nov-1996   de      Change the module name from macro.ash to macro.inc
;
; 09-Jan-1997   de      Remove historical methodic support for 286 processor.
;
; 13-Jan-1997   de      move segment definitions and macros to seg_defs.inc
;

;**********
;
; ENTER_ISR
;
; This macro expands into the operating system specific preamble for the
; device ISR. For OS/2, this is null. For MS-DOS, a local stack is created.
; This macro is used in conjunction with the EXIT_ISR macro.
;
;**********

ENTER_ISR macro

IF OS EQ OS2

	pushad				;; Save general regs on calling stack
	push es

ELSEIF OS EQ DOS
;;
;; If this is MSDOS, save all general registers, and the segment registers
;;
	pushad				;; Save general regs on calling stack
	push	ds                      ;; Save the DS on the CALLING stack
	push	es                      ;; Save the ES on the CALLING stack

	mov     ax, cs			;; DS = CS
	mov	ds, ax
ENDIF

	endm


;**************************
;* MOVE_TO_PROTECTED_MODE *
;**************************
; This macro moves from the current machine mode
; to protected mode. It is suspected that this
; is never needed, because when called the machine
; is always in protected mode.
; The current machine status word is pused on the
; stack, to enable returning to previous mode.
; If REAL_TO_PROT devhlp fails, the carry is set,
; otherwise the carry is clear

MOVE_TO_PROTECTED_MODE  macro
local @mtpm_exit
IF OS EQ OS2
;
; If this is OS/2, check to see what mode we are in
;
	smsw ax                      ; get the machine status word
	push ax                      ; save it on the stack
	test ax, 1                   ; test protected enabled bit
	jnz  SHORT @mtpm_exit        ; jump if we are already in protected mode
	pop  ax			     ; pop ax to ensure that pop and push are done
				     ; in the same machine mode
; else we are in real mode so fix it

	mov  dl, DEVHLP_REALTOPROT
	call ds:[devhlp]

	push WORD PTR 0              ; push 0 - for real mode - to ensure that pop
				     ; and push are done in the same machine mode

@mtpm_exit:
ENDIF
        endm

BACK_TO_INITIAL_MODE    macro
local   @btim_exit
IF OS EQ OS2
;
; If this is OS/2, pop the machine status word off of the stack, and restore
; the CPU to REAL mode on exit.
;
	pop  ax		; pop machine protection mode.
        ;cli            (MOTIH)
						
	test ax, 1
	jnz  SHORT @btim_exit	                ; isr entered in protected mode
	mov  dl, DEVHLP_PROTTOREAL
	call ds:[devhlp]
@btim_exit:
        ;sti            (MOTIH) - DO NOT ENABLE INRTERRUPS !
ENDIF
        endm


SAVE_DOS_STACK	macro

IF OS EQ DOS
	mov     cs:[save_int_ss], ss    	;; save the stack
	mov     cs:[save_int_sp], sp    	;; save the stack offset
	mov     ax, cs				;; SS = CS
	mov     ss, ax
	mov     sp, OFFSET InterruptStack	;; set the local stack
ENDIF
	endm


RESTORE_DOS_STACK  macro

IF OS EQ DOS
	mov  ss, cs:[save_int_ss]		;; Restore calling stack
	mov  sp, cs:[save_int_sp]
ENDIF
	endm


;**********
;
; EXIT_ISR
;
; This macro expands into the operating system specific exit code for the
; device ISR. For OS/2 this means restoring registers and issuing a
; normal return. For MS-DOS, the stack is restored, and a return from
; interrupt is issued.
;
; Note that for OS/2 the carry is used to signal OS/2 whether we used this
; interrupt (for interrupt sharing).  InterruptMain sets or clears the
; carry, based on what it did with the interrupt.
;**********

EXIT_ISR macro

IF OS EQ OS2
;;
;; For OS/2, pop registers and issue a RET
;;
	pop es
	popad			;; Restore general registers
	ret

ELSEIF OS EQ DOS
;;
;; For MS-DOS, restore the stack, and issue an IRET
;;

	pop  es			;; Restore ES from the CALLING Stack
	pop  ds			;; Restore DS from the CALLING Stack

	popad			;; Restore general registers
	iret
ENDIF

	endm


;**********
;
; POP_REGISTERS
;
; This macro expands into code to restore the stack.  It is used for DOS
; interrupt sharing.  Note that the stack in use should be the one used by
; the caller.
;
;**********

POP_REGISTERS macro

	pop  es			;; Restore ES from the CALLING Stack
	pop  ds			;; Restore DS from the CALLING Stack

	popad			;; Restore general registers

	endm


;
; The following three macros are used to enable/disable interrupts at the
; adapter interrupt mask register.
;
SET_ADAPTER_INTERRUPT MACRO
	push   eax
	push   dx
	mov    dx, Nic.CSR7_Address
	mov    eax, Nic.Shadow_CSR7
        and    eax, Nic.Shadow_CSR7_Mask
	out    dx, eax
	pop    dx
	pop    eax
	ENDM

ENABLE_ADAPTER_INTERRUPT MACRO
        mov    Nic.Shadow_CSR7_Mask, 0FFFFFFFFh
	SET_ADAPTER_INTERRUPT
ENDM

DISABLE_ADAPTER_INTERRUPT MACRO
        mov    Nic.Shadow_CSR7_Mask, 0
	SET_ADAPTER_INTERRUPT
	ENDM

ENTER_TIMER_HANDLER  MACRO
	pushf             ; Save flags
	cli               ; Block interrupts
IF OS EQ DOS
	push ds           ; Save current data segment
	push cs
	pop  ds           ; DS = CS
ENDIF
	ENDM


EXIT_TIMER_HANDLER  MACRO
IF OS EQ DOS
	pop  ds           ; Restore data segment
	popf              ; Restore flags
	jmp  CS:[their_timer]

ELSEIF OS EQ OS2
        popf
	retf
ENDIF
	ENDM


