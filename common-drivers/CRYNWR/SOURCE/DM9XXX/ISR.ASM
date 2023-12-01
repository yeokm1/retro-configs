;*****************************************************************************
;* Name : ISR.ASM
;*
;* All rights reserved by DAVICOM, 1996
;*
;* Description :
;*
;* Functions :
;*	. InterruptMain
;*
;* Author :
;*
;* Date :
;*
;* Change Notes :
;* Date - Modifier
;*     Cause :
;*  Modified :
;*    Result :
;
; Maintainers:
;
; John H.T. Ho		htho
;
;
; Revision History:
;
; Date	     Modfier.	Modification Descriptions
; ---------- ---------- ------------------------------------------
; 2000.4.6	htho	port rese while rx hang
;
;*
;*****************************************************************************

.386

EXTRN	their_isr : DWORD
EXTRN	our_stack : BYTE

		PUBLIC InterruptSemaphore
InterruptSemaphore  DB 0

CR5_image	   DD ?

		PUBLIC save_int_ss, save_int_sp
save_int_ss	DW ?
save_int_sp	DW ?

		PAGE

;--------------------------------------------------------------------+
; Name : InterruptMain
;
; Description: This is the device ISR.
;	       This ISR handles receive interrupts from the adapter.
;
; Enter :
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+
		PUBLIC	InterruptMain
InterruptMain	PROC	FAR

	ENTER_ISR			; Do OS specific entry stuff

	cli				; Momentarily block system interrupts
	cld				; Set the direction flag forward

	mov  al, 1			; Set the semaphore
	xchg InterruptSemaphore, al
	cmp  al, 0			; Check previous value of sempahore
	je   im_clear			; if it was already set, chain

;------------------- Support interrupt sharing

im_chain:

	POP_REGISTERS			   ; clean up caller's stack
	jmp	DWORD PTR cs:their_isr

im_clear:
	DISABLE_ADAPTER_INTERRUPT	; Block adapter ints (use caller's stack)


;     Is this interrupt for us?

	;Get the interrupt status bits (CR5)
	;------------------------------------
	mov	dx,  p_CR5
	in	eax, dx
	mov	CR5_image, eax

	;Test if this interrupt is from Tulip
	;------------------------------------
	test	eax, CR7_K_DEFAULT_ON	       ;; NI | AI | RI
	jnz	im_our_int			  ; it's our interrupt

	;Not our interrupt; restore adapter interrupt, semaphore, and chain
	;------------------------------------------------------------------
	cmp	TulipIntPosted, 1 ;Was an interrupt posted from prev. reset?
	je	im_posted_int
	ENABLE_ADAPTER_INTERRUPT
	mov	InterruptSemaphore, 0
	jmp	im_chain

im_posted_int:
;;-- Reset post interrupt before initialized.
	;Previous possible interrupt posted before Chip reset
	;----------------------------------------------------
	and	eax, 0FFFFFFFBh
	out	dx, eax 	     ;; If set, reset EB, TS, RS, NIS

	mov	TulipIntPosted, 0

	SAVE_DOS_STACK
	ACK_PIC_INTERRUPT	;; Issue EOI, Could accept next interrupt
	RESTORE_DOS_STACK
	jmp	im_exit_after

	;Clear active interrupts
	;---------------------------------
im_our_int:
	and	eax, 0FFFFFFFBh 	; don't write TU bit (TxHang Stuff)
	out	dx, eax 		;; Clear CR5

	SAVE_DOS_STACK			; Use our own stack

	ACK_PIC_INTERRUPT		; Issue EOI to the 8259 PIC Chips

	sti				; Re-enable system wide interrupts

;
; ISR Processing Goes Here
;
tx_int:
	cli

	test   CR5_image, CR7_M_TXCIE
	jz     rx_int

;-- check if currently transmiting packet complete
	mov	di, NextTxPollPtr

	test	[di].XMT_DESCRIPTOR.TDES0, TDES0_M_OWN
	jnz	rx_int		       ; exit if transmit not complete

;-- transmit complete, kick transmit poll for next waiting if any

	;-- reset TxHangCounter to prevent timer handler from reseting the chip
	mov	TxHangCounter, 0

	;-- decrement transmit pending count
	dec	TxPendingCnt

	;-- advance NextTxPollPtr to next waiting
	mov	ax, [di].XMT_DESCRIPTOR.p_XmtNext
	mov	NextTxPollPtr, ax	; advance to next waiting

;;-- check if any other patcket pending
	 cmp	 TxPendingCnt, 0
	 je	 rx_int

;;++, 990830, htho
	sti
;;++
	call	XmtMain

rx_int:
;;++, 990830, htho
	cli
;;++
	test   CR5_image, CR7_M_RXCIE
	jz     im_exit
;;;;++, 2000.4.6, htho
	inc	interval_rx_cnt
;;;;++

;;++, 990830, htho
	sti
;;++
	call RcvMain

im_exit:

	RESTORE_DOS_STACK

im_exit_after:
;
; Momentarily disable system interrupts, and re-enable hardware interrupts
; at the ESIC chip. Interrupts will be re-enabled on return from the ISR, since
; the processor flags are restored on return from interrupt
;

	cli

	mov InterruptSemaphore, 0

	ENABLE_ADAPTER_INTERRUPT

im_isrdone:
	EXIT_ISR

InterruptMain	ENDP
