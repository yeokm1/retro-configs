;*****************************************************************************
;* Name : XMT.ASM
;*
;* All rights reserved by DAVICOM, 1996
;*
;* Description : Transmission initialize, reset, enable, disable, execute,
;*		multicast and setup frame.
;*
;* Functions :
;*	. XmtInit
;*	. XmtReset
;*	. XmtDisable
;*	. XmtEnable
;*	. XmtGetSetupBuffer
;*	. XmtSendSetupFrame
;*	. XmtSendDummyFrame
;*	. send_pkt
;*	. XmtMain
;*	. AddMulticastAddress
;*	. MulticastTableSearch
;*
;* Author : Spenser Tsai
;*
;* Date : 05/17/96
;*
;
; Maintainers:
;
; John H.T. Ho		htho
;
;
; Date	     Modfier.	Modification Descriptions
; ---------- ---------- ------------------------------------------
; 2000.2.16	htho	dynamicaly keep a image of CR6 in [PortConfigCR6]
;
;*
;*****************************************************************************
.386
	PUBLIC	NextTxPollPtr, TxPendingCnt
NextTxPollPtr		DW	0	; Polling command pointer at descriptor
TxPendingCnt		DW	0


	PUBLIC XmtNumBuffers, XmtState
XmtNumBuffers	DW	8	; Number of transmit's buffer
XmtState	      DW 0    ; Current state of the trasmit object. 1=Active
			      ; 0=Inactive

	PUBLIC	XmtFrameSize
XmtFrameSize	      DW 0    ; Cumulative size of current current TransmitChain
			      ; frame

	PUBLIC XmtCRCThreshold
XmtCRCThreshold       DW 0    ; Minimum frame size for which the driver should
			      ; compute the CRC.  If less than 64, the Tulip's
			      ; padding will prevent CalcCRC from working
			      ; correctly.
	PUBLIC p_XmtBlockVirt, p_XmtRingVirt, p_XmtBlockPhys, p_XmtRingPhys
p_XmtBlockVirt	      DW 0    ; A virtual NEAR pointer to the base of the
			      ; transmit buffers

p_XmtRingVirt	      DW 0    ; A virtual NEAR pointer to the base of the
			      ; transmit descriptor ring

p_XmtBlockPhys	      DD 0    ; A 32 bit physical pointer to the base of the
			      ; transmit buffers

p_XmtRingPhys	      DD 0    ; A 32 bit physical pointer to the base of the
			      ; transmit descriptor ring

	PUBLIC XmtCurrentDescriptor
	PUBLIC TxPollPtr, PreTxPollPtr, Poll1st
XmtCurrentDescriptor  DW 0    ; Pointer to current descriptor
TxPollPtr	      DW 0    ;; Polling command pointer at descriptor
PreTxPollPtr	      DW 0    ;; Polling command pointer at descriptor
Poll1st 	      DB 1    ;; 1 = never poll

;--------------------------------------------------------------------+
; Name : XmtInit
;
; Description: Initializes the data structures for transmitting.
;		It must be called before any other calls are made to
;		XMT.
;
; Stack Frame relative to BP (Remember, gang, this is a NEAR call, so the
;			      first argument appears at BP+4. It's NOT a typo)
;
; Enter :
;	BP+6  DWORD  PhysAddr	 ; Physical Address of Memory Block
;	BP+4  WORD   VirtAddr	 ; NEAR pointer to Memory Block. DS:VirtAddr
;
; Return : Bytes used in AX.
;
; Destroied registers :
;
;---------------------------------------------------------------------+
	ALIGN  4
	PUBLIC XmtInit
XmtInit PROC NEAR
	push bp
	mov  bp,sp
	push edx
;;++, 980415, Hu-Tiong
	push	ebx
;;++
	push cx
	push di
	push si

	mov  XmtState, 0

	cmp  XmtCRCThreshold, 0 	; Has threshold been set already?
	jne  xi_continue		; If yes, don't do so here.

xi_dont_gen_crc:
	mov  XmtCRCThreshold, FRAME_MTU+1 ; Above Rev 2.2, set threshold ...
					; ... greater than maximum size
					;; FRAME_MTU = 1514.
xi_continue:
	mov  ax, WORD PTR [BP+4]	; Get Virtual address of Memory Block
	mov  p_XmtBlockVirt, ax
	mov  p_XmtRingVirt, ax
	mov  edx, DWORD PTR [BP+6]	; Get Physical address of Memory Block
	cmp  edx, 0			; If address is zero, just return
	je   xinit_return_bytes_used	; bytes used, don't init.
	mov  p_XmtBlockPhys, edx
	mov  p_XmtRingPhys, edx
	mov  ax, XmtNumBuffers
	mov  dx, XMT_BUFFER_SIZE
	mul  dx
	movzx edx, ax			; EDX = #buffers * size of buffer
	add  p_XmtRingVirt, dx		; Add total size of receive buffer...
	add  p_XmtRingPhys, edx 	; ...space to get offset of desc ring
;; p_XmtRingVirt/p_XmtRIngPhys are end of entity block.
;
; At this point the p_XmtBlock and p_XmtRing pointers are initialized.
; Now, initialize the descriptors. Registers are used as follows:
;
; SI points to descriptor being initialized.
; DI points to the descriptor's associated transmit buffer
; EDX is the physical address of the associated transmit buffer
;
	mov  si, p_XmtRingVirt		;; ? p_XmtBlockVirt ?
	mov  di, p_XmtBlockVirt
	mov  edx, p_XmtBlockPhys
;;++, 980415, Hu-Tiong
	mov	ebx, p_XmtRingPhys
;;++
	mov  cx, XmtNumBuffers		; Get XmtNumBuffers
	dec  cx 			; Initialize NumXmtBuffs-1 descriptors

xinit_loop:

	mov  [si].XMT_DESCRIPTOR.TDES0, 0   ; Set owner to Host, clear status
;;-+, 980415, Hu-Tiong
;;	mov  [si].XMT_DESCRIPTOR.TDES1, 0   ; clear all TDES1 control bits
	mov  [si].XMT_DESCRIPTOR.TDES1, TDES1_M_CE   ; clear all TDES1 control bits
;;-+
	mov  [si].XMT_DESCRIPTOR.TDES2, edx ; Point buffer 1 to edx
;;-+, 980415, Hu-Tiong
;;	mov  [si].XMT_DESCRIPTOR.TDES3, 0   ; Point buffer 2 to NULL
	add  ebx, SIZE XMT_DESCRIPTOR
	mov  [si].XMT_DESCRIPTOR.TDES3, ebx ; Point buffer 2 to NULL
;;-+
	mov  [si].XMT_DESCRIPTOR.p_XmtBuffer, di ; virtual address of buffer
	mov  ax, si
	add  ax, SIZE XMT_DESCRIPTOR	; AX points to next descriptor
	mov  [si].XMT_DESCRIPTOR.p_XmtNext, ax	 ; virt address of next descr
	mov  si, ax			; SI points to next descriptor
	add  edx, XMT_BUFFER_SIZE	; EDX holds physical address of next buf
	add  di, XMT_BUFFER_SIZE	; DI points to next buf
	loop xinit_loop 		; Loop while CX != 0
;
; Now initialize the last descriptor
;
	mov  [si].XMT_DESCRIPTOR.TDES0, 0    ; Set owner to Host, clear status.
;;-+, 980415, Hu-Tiong
;;	mov  [si].XMT_DESCRIPTOR.TDES1, TDES1_M_EOR ; end of ring ;; (02000000h)
	mov  [si].XMT_DESCRIPTOR.TDES1, TDES1_M_CE  ; end of ring ;; (02000000h)
;;-+
	mov  [si].XMT_DESCRIPTOR.TDES2, edx  ; Point buffer 1 to edx
;;-+, 980415, Hu-Tiong
;;	mov  [si].XMT_DESCRIPTOR.TDES3, 0    ; Point buffer 2 to NULL
	mov  ebx, p_XmtRingPhys
	mov  [si].XMT_DESCRIPTOR.TDES3, ebx ; Point buffer 2 to NULL
;;-+
	mov  [si].XMT_DESCRIPTOR.p_XmtBuffer, di ; virtual address of buffer
	mov  ax, p_XmtRingVirt
	mov  [si].XMT_DESCRIPTOR.p_XmtNext, ax	 ; point back to start of ring
;
; At this point, the transmit ring of descriptors is initialized, and
; all ownership bits are set to the Host. All is set for transmit DMA
; traffic to be delivered to the adapter once the adapter is enabled.
;
	mov  ax, p_XmtRingVirt
	mov  XmtCurrentDescriptor, ax	; Initialize current descriptor

xinit_return_bytes_used:
	mov  ax, XmtNumBuffers		; Get number of Xmt Buffers
	mov  dx, XMT_BUFFER_SIZE	;; 1520
	add  dx, SIZE XMT_DESCRIPTOR
	mul  dx 			; DX:AX = (BUFFER_SIZE + DESCR_SIZE) *
					;	       NUMBER_OF_BUFFERS
					; Note: We discard DX.
					; AX return value.
	pop  si
	pop  di
	pop  cx
;;++, 980415, Hu-Tiong
	pop	ebx
;;++
	pop  edx
	pop  bp
	ret
XmtInit ENDP

	PAGE
;--------------------------------------------------------------------+
; Name : XmtReset
;
; Description: Stop transmit & Clear descriptor's OWN bit.
;
; Enter : None
;
; Return : None
;
; Destroied registers :
;
;---------------------------------------------------------------------+
	ALIGN  4
	PUBLIC XmtReset
XmtReset PROC NEAR
	push ax
	push cx
	push si

	call XmtDisable

	mov  si, p_XmtRingVirt		; Get pointer to base of transmit ring
	mov  ax, XmtNumBuffers
	mov  TxPendingCnt, 0
	mov  XmtCurrentDescriptor, si
	mov  NextTxPollPtr, si
	mov  cx, XmtNumBuffers		; Get `mtNumBuffers

xreset_loop:
	mov  [si].XMT_DESCRIPTOR.TDES0, 0 ; Set ownership to Host, clear status

	mov  si, [si].XMT_DESCRIPTOR.p_XmtNext ; SI points to next descriptor
	loop xreset_loop		; Loop while CX != 0

	pop  si
	pop  cx
	pop  ax
	ret
XmtReset ENDP

	PAGE
;--------------------------------------------------------------------+
; Name : XmtDisable
;
; Description:
;	   This function disables the transmission of frames on the adapter
;			 (Stop)
;
; Enter : None
;
; Return : None
;
; Destroied registers :
;
;---------------------------------------------------------------------+
	   ALIGN  4
	   PUBLIC XmtDisable
XmtDisable PROC NEAR
	push eax
	push dx

	mov  XmtState, 0

;;-+, 2000.2.16, hu-tiong
;	mov  dx, p_CR6		       ;    Stop the transmit process
;	in   eax, dx
;	and  eax, NOT CR6_M_TXSC
	mov	eax, PortConfigCR6
	and	eax, NOT CR6_M_TXSC
	mov	PortConfigCR6, eax
;;-+
	call PortCR6Write

	pop  dx
	pop  eax
	ret
XmtDisable ENDP

	PAGE
;--------------------------------------------------------------------+
; Name : XmtEnable
;
; Description:
;		This function enable the transmission of frames on the adapter.
;		And set base of transmit ring to CR4.
;
; Enter : None
;
; Return : None
;
; Destroied registers :
;
;---------------------------------------------------------------------+
	  ALIGN  4
	  PUBLIC XmtEnable
XmtEnable PROC NEAR
	push eax
	push dx

	mov  XmtState, 1

	mov  eax, p_XmtRingPhys 	;    Write CR4 with p_XmtRingPhys
	mov  dx, p_CR4
	out  dx, eax

;;	  mov  dx, p_CR6		 ;    Start the transmit process
;;	  in   eax, dx
;;	  or   eax, CR6_M_ST	 ;;(00002000h)
;;	  call PortCR6Write
;;++, 2000.2.16
;;	mov	eax, PortConfigCR6
;;	or	eax, CR6_M_TXSC
;;	mov	eax, PortConfigCR6
;;	call	PortCR6Write
;;++

	mov  ax, p_XmtRingVirt
	mov  XmtCurrentDescriptor, ax	;    Initialize current descriptor

	pop  dx
	pop  eax
	ret
XmtEnable ENDP

	PAGE
;--------------------------------------------------------------------+
; Name : XmtGetSetupBuffer
;
; Description:
; This function returns a virtual NEAR pointer to the transmit buffer pointed
; to by XmtCurrentDescriptor. The calling agent builds a DM9100 setup
; frame in the buffer, and eventually calls XmtSendSetupFrame to transmit the
; setup frame to the DM9100. Clearly, since this routine returns a
; pointer based on XmtCurrentDescriptor, the XmtCurrentDescriptor cannot be
; allowed to  change from the time the buffer is allocated to the time
; XmtSendSetupFrame is called. It is the calling agent's responsibility to
; ensure the system interrupts are disabled from just before XmtGetSetupBuffer
; is called, until the time XmtSendSetupFrame returns.
;
; Enter : None
;
; Return : AX -> Point to setup frame buffer.
;
; Destroied registers :
;
;---------------------------------------------------------------------+
		   ALIGN  4
		   PUBLIC XmtGetSetupBuffer
XmtGetSetupBuffer  PROC  NEAR
	pushf
	cli
	push si
	mov  si, XmtCurrentDescriptor
	mov  ax, [si].XMT_DESCRIPTOR.p_XmtBuffer
	pop  si
	popf
	ret
XmtGetSetupBuffer  ENDP

	PAGE
;--------------------------------------------------------------------+
; Name : XmtSendSetupFrame
;
; Description:
; This routine transmits the XmtCurrentDescriptor as a setup frame. This
; routine assumes that the setup frame has alread been built into the
; buffer associated with the XmtCurrentDescriptor.
;
; Enter : None
;
; Return : carry set if setup packet did not complete
;
; Destroied registers :
;
;---------------------------------------------------------------------+
		   ALIGN  4
		   PUBLIC  XmtSendSetupFrame
XmtSendSetupFrame  PROC  NEAR

	cli
	cld

	push  eax
	push  ebx
	push  dx
	push  si

;-- setup transmit descriptor for setup frame
	mov	si, XmtCurrentDescriptor	; descriptor for this frame
	mov	NextTxPollPtr, si
	mov	eax, [si].XMT_DESCRIPTOR.TDES1	; field for its previous frame
	and	eax, TDES1_M_CE 		; keep only the TER bit
	or	eax, TDES1_M_SETF		; Assert the Setup Packet bit
	mov	ax, HW_K_SETUP_FRAME_SIZE	; Set size to HW_K_SETUP_FRAME_SIZE
	mov	[si].XMT_DESCRIPTOR.TDES1, eax	; Write TDES1
	mov	[si].XMT_DESCRIPTOR.TDES0, TDES0_M_OWN ; Set ownership to 9102/9100

;-- start the transmit process
;;-+, 2000.2.16, hu-tiong
;	mov	dx, p_CR6
;	in	eax, dx
;	or	eax, CR6_M_TXSC     ;;(00002000h)
	mov	eax, PortConfigCR6
	or	eax, CR6_M_TXSC
	mov	PortConfigCR6, eax
;;-+
	call	PortCR6Write

;-- kick the transmit poll demand
	mov   dx, p_CR1 		; Transmit pooling
	mov   eax,1
	out   dx, eax			; Send the frame

	mov   ax, [si].XMT_DESCRIPTOR.p_XmtNext
	mov   XmtCurrentDescriptor, ax	 ; Update XmtCurrentDescriptor

	mov	NextTxPollPtr, ax

	push  cx
	mov   cx, 0FFFFh		; a long loop, but not forever
xssf_wait:				; if this fails, bind will fail on its own
	test  [si].XMT_DESCRIPTOR.TDES0, TDES0_M_OWN ; setup processing done?
	je    xssf_loop_done
	loop  xssf_wait 		; loop if not yet
	stc				; set carry if if there's an error
xssf_loop_done:
	pop   cx

	pop   si
	pop   dx
	pop   ebx
	pop   eax

	ret
XmtSendSetupFrame  ENDP

;--------------------------------------------------------------------+
; Name : XmtSendDummyFrame
;
; Description: Send a dummy frmae for the next setup frame.
;
; Enter : None.
;
; Return :
;		error: carry flag set.
;	    non-error: carry flag claer.
;
; Destroied registers :
;
;---------------------------------------------------------------------+
	PAGE
;		    ALIGN  4
		ALIGN
		   PUBLIC  XmtSendDummyFrame
XmtSendDummyFrame  PROC  NEAR

	cli
	cld

	push  eax
	push  ebx
	push  dx
	push  si


	mov   si, XmtCurrentDescriptor	 ; descriptor for this frame
	mov   eax, [si].XMT_DESCRIPTOR.TDES1 ; field for its previous frame
	and	eax, TDES1_M_DUMMY

	mov	[si].XMT_DESCRIPTOR.TDES1, eax		;; Set Dummy frame info.
	mov   [si].XMT_DESCRIPTOR.TDES0, TDES0_M_OWN ; Set ownership to 90100

	mov   dx, p_CR1        ;; Transmit pooling
	mov   eax,1
	out   dx, eax			 ; Send the frame

	mov   ax, [si].XMT_DESCRIPTOR.p_XmtNext
	mov   XmtCurrentDescriptor, ax	 ; Update XmtCurrentDescriptor

	push  cx
	mov   cx, 0FFh		      ; a long loop, but not forever
xsdf_wait:			    ; if this fails, bind will fail on its own
	test  [si].XMT_DESCRIPTOR.TDES0, TDES0_M_OWN ; setup processing done?
	jz    xssf_loop_done
	loop  xsdf_wait 		; loop if not yet
	stc				; set carry if if there's an error

xsdf_loop_done:
	pop   cx

	pop   si
	pop   dx
	pop   ebx
	pop   eax

	ret
XmtSendDummyFrame  ENDP

	PAGE
;--------------------------------------------------------------------+
; Name : send_pkt
;
; Description:
; This function is called by the protocol stack in order to transmit frames.
;
; Enter :
;	     DS:SI -> Caller's Buffer.
;		CX -> Bytes length.
;
; Return :
;
; Destroied registers :
;
;
;---------------------------------------------------------------------+

EXTRN	bytes_out : DWORD
EXTRN	packets_out : DWORD
EXTRN	errors_out : DWORD
;;EXTRN   TxHangCounter : DWORD

	ALIGN  4
	PUBLIC send_pkt
send_pkt   PROC NEAR
	cld				; Clear direction flag

	push	bx
	push	ds

tc_begin:
	mov	ax, cs			; DS = CS, Change DS to local segment.
	mov	ds, ax

;-- Check if transmit enabled?
;------------------------------------------------------------------------
	cmp	XmtState, 1		; If (transmit not enabled)
	jne	xmt_fail		;    return (CANT_SEND)

	mov	bx, XmtCurrentDescriptor; BX -> current tx descriptor

;-- Check if any buffer available?
;------------------------------------------------------------------------
tc_owner_check:
	mov	eax, [bx].XMT_DESCRIPTOR.TDES0
	test	eax, TDES0_M_OWN	; if (We don't own current descriptor)
	jnz	out_of_resource_exit	;    return (OUT_OF_RESOURCE)

tc_buffer_available:
;-- Check if any error occurred during previous transmition?
;------------------------------------------------------------------------
	test	eax, TDES0_M_ES 	; Check the transmit Error Summary
	jz	xmt_no_err

	inc	errors_out		; For statistics

xmt_no_err:
	mov	di, [bx].XMT_DESCRIPTOR.p_XmtBuffer ; index into driver buffer
					; for rest of routine

COMMENT %
	cmp	cx, GIANT		; Is this packet too large
	ja	send_pkt_toobig
%
	cmp	cx, RUNT
	jnb	tc_copy
	mov	cx, RUNT

tc_copy:
	add	bytes_out, ecx		; For statistics
	inc	packets_out

	mov	XmtFrameSize, cx

;-- Copy data to transmit buffer
;------------------------------------------------------------------------
	mov	ax, ds
	mov	es, ax			; Get our segment into ES
	pop	ds			; Change DS to Procotol's segment
	push	ds

	mov	ax, cx			;      Copy Data
	and	ax, 3
	shr	cx, 2
	rep	movsd
	mov	cx, ax
	rep	movsb

tc_post_frame:
;-- Setup Tx Descriptor
;------------------------------------------------------------------------
	mov	ax, cs
	mov	ds, ax			; Cahnge DS to Local segment.

	mov	si, XmtCurrentDescriptor	; descriptor for this frame
	mov	eax, [si].XMT_DESCRIPTOR.TDES1	; field for its previous frame
;;-+, 980415, Hu-Tiong
;;	and	eax, TDES1_M_EOR		; keep only the TER bit
	and	eax, TDES1_M_CE 		; keep only the CE bit
;;-+
	or	eax, (TDES1_M_BD OR TDES1_M_ED) ; first and last descr. for frame
	mov	ax, XmtFrameSize		; new frame's size in BUFFER_1_SIZE
	or	eax, TDES1_M_CI 		; Interrupt on complete
	mov	[si].XMT_DESCRIPTOR.TDES1, eax	; TDES1 for this frame

;
; If the packet is long enough that the driver should generate the CRC, call
; CalcCRC to do so and disable DM9100 CRC generation.
;
	cmp   ax, XmtCRCThreshold	; long enough for SW CRC generation?(1515)
	jb    xmt_post			; branch if not

	mov   cx, ax			; CX = Length in bytes - CRC
	mov   si, [si].XMT_DESCRIPTOR.p_XmtBuffer ; DS:SI points to frame
	call  CalcCRC
	mov   si, XmtCurrentDescriptor	; restore pointer to descriptor
	add   [si].XMT_DESCRIPTOR.TDES1, (TDES1_M_CAD + 4)
					; suppress hardware CRC generation,
					; add CRC's length to frame size
;-- Transmit the packet
;------------------------------------------------------------------------
xmt_post:
	mov	ax, [si].XMT_DESCRIPTOR.p_XmtNext
	mov	XmtCurrentDescriptor, ax  ; Update XmtCurrentDescriptor

;-- decrement free transmit descriptor count
	inc	TxPendingCnt

;-- check if oney one patcket pending
	cmp	TxPendingCnt, 1
	jne	xmt_done

	call	XmtMain

xmt_done:
	pop	ds
	pop	bx
	clc
	sti
	ret

	PUBLIC xmt_fail
xmt_fail:
	stc
	mov	dh, CANT_SEND	   ;; Return status
	pop	ds
	pop	bx
	sti
	ret


send_pkt_toobig:
out_of_resource_exit:
	pop	ds
	pop	bx
	mov	dh, NO_SPACE
	stc
	sti
	ret

send_pkt   ENDP


;--------------------------------------------------------------------+
; Name : XmtMain
;
; Description:
;		This function process transmit complete interrupt for one
;	packet transmit.
;		Currently, used by CUT6.
;
; Enter :
;
; Return :
;
; Destroied registers :
;
;---------------------------------------------------------------------+

	ALIGN	4
	PUBLIC	XmtMain
XmtMain PROC	NEAR
	push	eax
	push	dx
	push	si
	push	di

;-- disable system interrupt
	cli

check_tx_pending:
;;-- check if oney one patcket pending
;	 cmp	 TxPendingCnt, 1
;	 jne	 xm_exit

;-- Clear CR5's TXDU bit
	mov	dx, p_CR5		; Prepare DX for clearing CR5 TU
	mov	eax, CR5_M_TXDU 	; Prepare EAX for clearing CR5 TU
	out	dx, eax 		; Clear CR5 TU bit

	mov	si, NextTxPollPtr

	;-- set ownership to 9102/9100
	mov	[si].XMT_DESCRIPTOR.TDES0, TDES0_M_OWN

	;-- kick the transmit poll demand
	mov	dx, p_CR1
	mov	eax,1
	out	dx, eax 		; Off it goes! Kick the tx poll demand

;	 test	 [si].XMT_DESCRIPTOR.TDES0, TDES0_M_OWN ;check if already sent
;	 jnz	 txok			   ; Not sent
;
;	 mov   TxHangCounter, 0
;txok:


xm_exit:
	sti
	pop	di
	pop	si
	pop	dx
	pop	eax
	ret

XmtMain ENDP

;--------------------------------------------------------------------+
; Name : AddMulticastAddress
;
; Description:
; This function attempts to add a multicast address to the Adapter CAM. The
; adapter automatically performs destination address filtering based on the
; contents of the CAM, so it is not necessary for the driver to do any such
; filtering. The driver does maintain a table of multicast addresses, in
; order to check for duplicate addresses, and to clean up the adapter CAM
; in the CloseAdapter function.
;
; Enter :
;	     ES:SI -> New address list.
;		BX = Number of address to added.
;
; Return :
;
; Destroied registers :
;
;---------------------------------------------------------------------+
		    PUBLIC AddMulticastAddress
AddMulticastAddress PROC  NEAR
	push si
	push di
	pushf

	mov  di, OFFSET MulticastTable
	mov  ax, MulticastTable.table_current ; Convert current # of entries
	shl  ax, 4			; in the table to an offset to the next
	add  ax, 4			; free slot.
	add  di, ax

	push ds 			; Save our DS

	mov	cx, bx
ama_vacancy:
	push	di
	call MulticastTableSearch	   ; Search for address pointed to by ES:SI
	cmp  ax, -1			; If if ain't in there, continue
	je     ama_not_found
	add	si, 6
	loop	ama_vacancy
ama_not_found:
;
; At this point DS:SI points to the address to add, and ES:DI points to the
; free slot in the table.
;
	push	ds
	mov  ax, ds
	movseg	   ds, es
	mov  es, ax			; ES = DS & DS = ES
	cld

	movsw				; Stuff the address into the table
	movsw
	movsw

	pop	ds
	inc  MulticastTable.table_current ; Update current number of entries
	pop	di
	add	di, 16
	dec	bx
	jnz	 ama_vacancy

	pop  ds 			; Restore our data segment
;
; If the adapter is open, give it the new info
;
	call PortUpdateReceiveFilter	     ; clue the adapter in on all this
	jnc  ama_success		     ; did it succeed?
	stc

ama_success:
	clc
ama_exit:
	popf
	pop  di
	pop  si
	ret
AddMulticastAddress ENDP

	PAGE
;--------------------------------------------------------------------+
; Name : MulticastTableSearch
;
; Description:
; This function searches the MCast Table for the given address. If
; the address is found, the entry number is is returned, else -1 is returned.
; Since the MCast Table is usually small (16 entries max), and address
; table operations are not time critical, a linear search is used. Bogus, I
; know, but hey, it's small on code size, and speed just don't matter
; at this point in the driver code.
;
; Enter :
;	     ES:SI -> New address list.
;
; Return :
;    Status in AX (Entry Number or -1=Failure)
;    The entry number that AX returns starts counting at Entry Number 0.
;
; Destroied registers :
;
; Algorithm:
; BEGIN
;    CX = number of entries in NDIS MCast Table
;    if (CX == 0)
;	return(-1) Not Found
;    Point DI to the first entry in the NDIS MCast Table
;    do
;    {
;	if (WORD at ES:[SI].0 == DWORD at DS:[DI].0)
;	  if (WORD at ES:[SI].2 == DWORD at DS:[DI].2)
;	    if (WORD at ES:[SI].4 == WORD at DS:[DI].4)
;	       return(0); Found it
;	DI += 16
;    }
;    while (--CX != 0)
;    return(-1) NotFound
; END
;
;---------------------------------------------------------------------+
		   PUBLIC MulticastTableSearch
MulticastTableSearch  PROC  NEAR
	push di
	push cx
	push bx

	mov  cx, MulticastTable.table_current
	cmp  cx, 0
	je   SHORT snm_not_found_exit
	mov  di, OFFSET MulticastTable + 4
	mov  ax, 0
;
; ES:SI points to the address you're searching for
; DS:DI points to the entries in the MulticastTable
;
snm_loop:
	mov  bx, WORD PTR ES:0[SI]
	cmp  bx, WORD PTR DS:0[DI]
	jne  SHORT snm_check_next
	mov  bx, WORD PTR ES:2[SI]
	cmp  bx, WORD PTR DS:2[DI]
	jne  SHORT snm_check_next
	mov  bx, WORD PTR ES:4[SI]
	cmp  bx, WORD PTR DS:4[DI]
	jne  SHORT snm_check_next
	jmp  SHORT snm_exit
snm_check_next:
	add  di, 16
	add  ax, 1
	loop snm_loop
snm_not_found_exit:
	mov  ax, -1
snm_exit:
	pop bx
	pop cx
	pop  di
	ret
MulticastTableSearch  ENDP
