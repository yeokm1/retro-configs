;*****************************************************************************
;* Name : ETOPEN.ASM
;*
;* All rights reserved by DAVICOM, 1996
;*
;* Description :
;*	. Allocate descriptors & buffers memory.
;*	. Setup interrupt vector.
;*	. Initializes transmit.
;*	. Initializes receive.
;*	. Initializes card.
;*
;* Functions :
;*
;* Author : Spenser Tsai
;*
;* Date : 05/17/96'
;*
;* Change Notes :
;* Date - Modifier
;*     Cause :
;*  Modified :
;*    Result :
;*
;*****************************************************************************
;
; These functions are hardware initialize.
;
extrn	AllocatePhysicalBlock : NEAR
EXTRN	set_recv_isr : NEAR

.386
; Called once to initialize the card

	public	etopen
etopen: 			; Initialize interface

	push	eax

	call	AllocatePhysicalBlock	    ;; allocate data buffer. (INITPCI.ASM)

	push   p_PhysBlockPhys	    ; Call XmtInit
	push   p_PhysBlockVirt
	call   XmtInit			;; (XMT.ASM)
	add    sp, 6

	;; Adjust pointer to Receive's buffer
	add    p_PhysBlockVirt, AX	; Adjust the virtual and physical block
	and    eax, 0FFFFh		; pointers based on the number of bytes
	add    p_PhysBlockPhys, EAX	; used

	push   p_PhysBlockPhys		; Call RcvInit
	push   p_PhysBlockVirt
	call   RcvInit			;; (RCV.ASM)
	add    sp, 6

	call	PortInit		 ; Init adapter port interface
	jc	etopen_exit

	call	set_recv_isr		;; Setup receive ISR
	mov	al, int_no		; Get board's interrupt vector
	add	al, 8
	cmp	al, 8+8 		; Is it a slave 8259 interrupt?
	jb	set_int_num		; No.
	add	al, 70h - 8 - 8 	; Map it to the real interrupt.
	set_int_num:
	xor	ah, ah			; Clear high byte
	mov	int_num, ax		; Set parameter_list int num.

	clc
etopen_exit:
	pop	eax

	ret
