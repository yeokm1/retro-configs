;*****************************************************************************
;* Name : RCV.ASM
;*
;* All rights reserved by DAVICOM, 1996
;*
;* Description : Initialize, reset, enable & free descriptor for the
;*		receiption frame.
;*
;* Functions :
;*	. RcvInit
;*	. RcvReset
;*	. RcvDisable
;*	. RcvMain
;*	. RcvPostFreeDescriptor
;*	. RcvEnable
;*
;* Author : Spenser Tsai
;*
;* Date : 05/17/96
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
; Date	     Modfier.	Modification Descriptions
; ---------- ---------- ------------------------------------------
; 2000.2.16	htho	dynamicaly keep a image of CR6 in [PortConfigCR6]
;
;*
;*****************************************************************************
.386
include dm9100.inc
;;include hw.inc
include hardware.asd

EXTRN	errors_in : DWORD

	PUBLIC	RcvNumBuffers
;;RcvNumBuffers   DW	  12	  ; Number of Receive's buffer
RcvNumBuffers	DW	8      ; Number of Receive's buffer

	PUBLIC p_RcvBlockVirt, p_RcvBlockPhys, p_RcvRingVirt, p_RcvRingPhys
p_RcvBlockVirt	DW 0			; NEAR Pointer to base of Receive Block
p_RcvBlockPhys	DD 0			; Physical address of Receive Block
p_RcvRingVirt	DW 0			; NEAR Pointer to base of Receive Ring
p_RcvRingPhys	DD 0			; Physical address of Receive Ring

	       PUBLIC RcvState
RcvState       DW 0

	PUBLIC RcvSemaphore
RcvSemaphore  DB  0			; Controls re-entry of RcvMain


	PUBLIC RcvCurrentDescriptor
RcvCurrentDescriptor	 DW 0

;--------------------------------------------------------------------+
; Name : RcvInit
;
; Description:
; This routine initializes the receive module. It must be called before
; any other calls are made to the receive module.
;
; Stack Frame relative to BP (Remember, gang, this is a NEAR call, so the
;			      first argument appears at BP+4. It's NOT a typo)
;
; Enter :
;	BP+6  DWORD  PhysAddr	 ; Physical Address of Memory Block
;	BP+4  WORD   VirtAddr	 ; NEAR pointer to Memory Block. DS:VirtAddr
;
; Return :  Bytes used in AX.
;
; Destroied registers :
;
;---------------------------------------------------------------------+
	PUBLIC RcvInit
RcvInit PROC NEAR
	push bp
	mov  bp,sp
	push edx
;;++, 980415, Hu-Tiong
	push	ebx
;;++
	push cx
	push di
	push si

	mov  RcvState, 0

	mov  ax, WORD PTR [BP+4]	; Get Virtual address of Memory Block
	mov  p_RcvBlockVirt, ax
	mov  p_RcvRingVirt, ax
	mov  edx, DWORD PTR [BP+6]	; Get Physical address of Memory Block
	cmp  edx, 0			; If address is zero, just return
	je   rinit_return_bytes_used	; bytes used, don't init.
	mov  p_RcvBlockPhys, edx
	mov  p_RcvRingPhys, edx
	mov  ax, RcvNumBuffers		; Get number of Rcv Buffers
	mov  dx, RCV_BUFFER_SIZE
	mul  dx
	movzx edx, ax			; EDX = #buffers * size of buffer
	;; Pointer to 1st Descriptor address
	add  p_RcvRingVirt, dx		; Add total size of receive buffer...
	add  p_RcvRingPhys, edx 	; ...space to get offset of desc ring
;
; At this point the p_RcvBlock and p_RcvRing pointers are initialized.
; Now, initialize the descriptors. Registers are used as follows:
;
; SI points to descriptor being initialized.
; DI points to the descriptor's associated receive buffer
; EDX is the physical address of the associated receive buffer
;
	mov  si, p_RcvRingVirt
	mov  di, p_RcvBlockVirt
	mov  edx, p_RcvBlockPhys
;;++, 980415, Hu-Tiong
	mov	ebx, p_RcvRingPhys
;;++
	mov  cx, RcvNumBuffers		; Get RcvNumBuffers
	dec  cx 			; Initialize NumRcvBuffs-1 descriptors

rinit_loop:
	mov  [si].RCV_DESCRIPTOR.RDES0, RDES0_M_OWN ; Set ownership to 90100
						    ;;(80000000h)
;;	  mov  [si].RCV_DESCRIPTOR.RDES1, 0000005F0h  ; Set buffer 1&2 to length 1520
;;;-+, 980414, Hu-Tiong
;;	mov  [si].RCV_DESCRIPTOR.RDES1, RCV_BUFFER_SIZE  ; Set buffer 1&2 to length 1520
;;;;;;	mov  [si].RCV_DESCRIPTOR.RDES1, 600h		 ; Set buffer 1&2 to length 1520
	mov  [si].RCV_DESCRIPTOR.RDES1, RDES1_M_CE OR 600h	; Set buffer 1&2 to length 1520
;;;-+
	mov  [si].RCV_DESCRIPTOR.RDES2, edx	    ; Point buffer 1 to edx
;;;-+, 980415, Hu-Tiong
;;	mov  [si].RCV_DESCRIPTOR.RDES3, 0	    ; Point buffer 2 to edx
	add  ebx, SIZE RCV_DESCRIPTOR	; Next Descriptor's physical address
	mov  [si].RCV_DESCRIPTOR.RDES3, ebx	    ; Point next descriptor
;;;-+
	mov  [si].RCV_DESCRIPTOR.p_RcvBuffer, di	  ; Init buf virtual address
	mov  ax, si
	add  ax, SIZE RCV_DESCRIPTOR	; AX points to next descriptor
	mov  [si].RCV_DESCRIPTOR.p_RcvNext, ax ; Init virtual address of next desc
	mov  si, ax			; SI points to next descriptor
	add  edx, RCV_BUFFER_SIZE	; EDX holds physical address of next buf
	add  di, RCV_BUFFER_SIZE	; DI points to next buf
	loop rinit_loop 		; Loop while CX != 0
;
; Now initialize the last descriptor
;
	mov  [si].RCV_DESCRIPTOR.RDES0, RDES0_M_OWN ; Set ownership to 90100
;;;-+, 980414, Hu-Tiong
;;	mov  [si].RCV_DESCRIPTOR.RDES1, RCV_BUFFER_SIZE OR RDES1_M_EOR ; end of ring
;;;;;;	mov  [si].RCV_DESCRIPTOR.RDES1, 600h OR RDES1_M_EOR ; end of ring
	mov  [si].RCV_DESCRIPTOR.RDES1, RDES1_M_CE OR 600h  ; end of ring
;;;-+
	mov  [si].RCV_DESCRIPTOR.RDES2, edx	    ; Point buffer 1 to edx
;;-+, 980415, Hu-Tiong
;;;;;;	mov  [si].RCV_DESCRIPTOR.RDES3, 0	    ; Point buffer 2 to edx
	mov  ebx, p_RcvRingPhys
	mov  [si].RCV_DESCRIPTOR.RDES3, ebx	    ; Point buffer 2 to edx
;;-+
	mov  [si].RCV_DESCRIPTOR.p_RcvBuffer, di	  ; Init buf virtual address
	mov  ax, p_RcvRingVirt
	mov  [si].RCV_DESCRIPTOR.p_RcvNext, ax	       ; point to start of ring
;
; At this point, the receive ring of descriptors is initialized, and
; all ownership bits are set to the DM9100. All is set for receive DMA
; traffic to be delivered to the buffers once the adapter is enabled.
;
	mov  ax, p_RcvRingVirt
	mov  RcvCurrentDescriptor, ax	; Initialize current descriptor

rinit_return_bytes_used:
	mov  ax, RcvNumBuffers		; Get number of Rcv Buffers
	mov  dx, RCV_BUFFER_SIZE	;; 1520
	add  dx, SIZE RCV_DESCRIPTOR
	mul  dx 			; DX:AX = (BUFFER_SIZE + DESCR_SIZE) *
					;	       NUMBER_OF_BUFFERS


	pop  si
	pop  di
	pop  cx
;;++, 980415, Hu-Tiong
	pop	ebx
;;++
	pop  edx
	pop  bp
	ret
RcvInit ENDP

	PAGE
;--------------------------------------------------------------------+
; Name : RcvReset
;
; Description:
; This routine re-initializes the receive module. It has the following
; effect:
;
; 1) RcvDisable is called with the following actions:
;    - RcvState is reset to 0
;    - Receiver is stopped
;    - RIM interrupt is masked
; 2) The receive descriptor ring is reinitialized with all own bits
;    set to DM9100
; 3) The RcvCurrentDescriptor is reinitialized to point to the base of the
;    ring
;
; Enter :
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+
	 PUBLIC RcvReset
RcvReset PROC NEAR
	push cx
	push si

	call RcvDisable 		; Disable receiver

	mov  si, p_RcvRingVirt		; Get pointer to base of receive ring
	mov  cx, RcvNumBuffers		; Get RcvNumBuffers

rreset_loop:
	mov  [si].RCV_DESCRIPTOR.RDES0, RDES0_M_OWN ; Set ownership to 90100
	mov  si, [si].RCV_DESCRIPTOR.p_RcvNext	   ; SI points to next descriptor
	loop rreset_loop		; Loop while CX != 0

	mov  cx, p_RcvRingVirt
	mov  RcvCurrentDescriptor, cx	; Initialize current descriptor


	pop  si
	pop  cx
	ret
RcvReset ENDP

	PAGE
;--------------------------------------------------------------------+
; Name : RcvDisable
;
; Description:
;	  This function disables the receipt of frames from the adapter.
;
; Enter :
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+
	PUBLIC RcvDisable
RcvDisable  PROC  NEAR
	push eax
	push dx

	mov  RcvState, 0

;;-+, 2000.2.16, hu-tiong
;	mov  dx, p_CR6		       ;    Write CR6 to stop receiver
;	in   eax, dx
;	and  eax, NOT CR6_M_RXSC
	mov	eax, PortConfigCR6
	and	eax, NOT CR6_M_RXSC
	mov	PortConfigCR6, eax
;;-+
	call PortCR6Write
	mov  dx, p_CR7		       ;    Write CR7 to mask RXCIE interrupt
	in   eax, dx
	and  eax, NOT CR7_M_RXCIE
	out  dx, eax
	pop  dx
	pop  eax
	ret
RcvDisable  ENDP

	PAGE
;--------------------------------------------------------------------+
; Name : RcvMain
;
; Description:
; This routine is responsible for processing frames received from the adapter.
; This involves verifying the receive status, and rejecting the frame if there
; are errors. Additionally, this function determines the type of frame that
; has been received, and translates the frame appropriately.
;
; Enter :
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+
;;EXTRN   RxHangCounter : DWORD
;;++, 980306, Hu-Tiong
ps	macro	ch
	push	ax
	mov	al, ch
	int	0bbh
	pop	ax
	endm
;;++

	 PUBLIC  RcvMain
RcvMain  PROC  NEAR
	push	es

	cli
	mov  al, 1
	xchg RcvSemaphore, al
	cmp  al, 0
	jne  rm_reentered

	sub  esi, esi
	sub  edi, edi

rm_loop:			      ;    while (
	mov  si, RcvCurrentDescriptor ;      current descriptor owned by host)
	mov  eax, [si].RCV_DESCRIPTOR.RDES0
	test eax, RDES0_M_OWN
	jne  rm_exit		;; Jump, if OWN = DM9100
   ;; Ownership = Host
;;++, 980414, Hu-Tiong
mov	ebx, eax
and	ebx, (RDES0_M_BD OR RDES0_M_ED)
cmp	ebx, (RDES0_M_BD OR RDES0_M_ED) ; if packet spread over one descriptor
je	good_pkt_1			; jump if not (it's a leagle packet)

call	RcvPostFreeDescriptor
jmp	rm_loop

good_pkt_1:
;;++
    mov  ebx, eax		  ; Check if rdes0.frame_length=0x7FFF
    and  ebx, RDES0_M_LENGTH
    cmp  ebx, RDES0_M_LENGTH
    jne   rm_chk_err		  ; Didn't find RX hang - go to check frame's
				  ; status

    call PortUpdateReceiveFilter  ; Reset chip to handle RX hang
    jmp  rm_exit

rm_chk_err:
	mov  RxHangCounter, 1

	test eax, RDES0_M_ES	      ;       if (error summary set) {
	jz   SHORT rm_fmc_stat_ok

	inc	errors_in		;; For statistics
	test eax, RDES0_M_CE	      ; 	 if (CRC_ERR)
	jz   SHORT rm_not_crc_err

rm_not_crc_err:
	call RcvPostFreeDescriptor    ; 	 RcvPostFreeDescriptor
	jmp  rm_loop

rm_fmc_stat_ok: 		      ;       } else {
	mov  di, [si].RCV_DESCRIPTOR.p_RcvBuffer   ; DS:DI points to buffer

rm_not_mcast:
	mov  ecx, [si].RCV_DESCRIPTOR.RDES0
	and  ecx, RDES0_M_LENGTH      ; 	 Mask off, and shift rcv
	shr  ecx, RDES0_V_LENGTH      ; 	 length to EAX<14:0>
	sub  cx, 4		      ; 	 Sub 4 CRC bytes
;;--, 980611, Hu-Tiong, for DM9102 cut4
COMMENT %
;;++, 980303, Hu-Tiong
;
; Data error occasually occurrs wile the MAC move the data of received frame
; from FIFO to host memory.
;
	cmp	ChipType, DM9102_CHIP
	jne	NoDataError

	push	di			; resevee packet buffer pointer
	push	si			; reserve current descriptor pointer
	push	cx			; reserve packet length

	mov	bx, di
	add	bx, cx
	mov	edx, [bx]		; EDX = original CRC value
	push	edx			; reserve original CRC

	mov	si, di			; DS:SI -> data buffer
	call	CalcCRC 		; result CRC will replace original one

	pop	edx			; restore original CRC

	pop	cx			; restore packet length
	pop	si			; restore current descriptor pointer
	pop	di

	cmp	eax, edx		; if new CRC = original CRC
	jne	rm_not_crc_err		; jump if not (data error occurrs)
NoDataError:
;;++
%
;;--------------------------------------------------------------------------
	mov ax, cs			; Set ds = code
	mov ds, ax
	mov es,ax

	add	di, 12			;; Point to Frame type field
	mov	dl, BLUEBOOK		;assume bluebook Ethernet.
	mov	eax, [si].RCV_DESCRIPTOR.RDES0
	test	eax, RDES0_M_FT
	jnz	BlueBookPacket		;; Frame length > 1500
	inc	di			;set di to 802.2 header
	inc	di
	mov	dl, IEEE8023

BlueBookPacket:
	push	si
	push	cx
	call	recv_find
	pop	cx
	pop	si

	jc	rcv_no_copy

	cld			; Copies below are forward, please
	mov ax, es		; Did recv_find give us a null pointer?
	or ax,	di		; ..
	je	rcv_no_copy	; If null, don't copy the data

	push	cx		; We will want the count and pointer
	push	es		;  to hand to client after copying,
	push	di		;  so save them at this point
	mov  ax, [si].RCV_DESCRIPTOR.p_RcvBuffer   ; AX points to DES's buffer

	call	block_input

rcv_copy_ok:
	pop	si		; Recover pointer to destination
	pop	ds		; Tell client it's his source
	pop	cx		; And it's this long
	assume	ds:nothing
	call	recv_copy	; Give it to him

rcv_no_copy:
	movseg	ds,cs
	assume	ds:code

rcv_copy_deferred:

	cli

	call RcvPostFreeDescriptor    ; 	 call RcvPostFreeDescriptor
	jmp	rm_loop

rm_exit:
	mov RcvSemaphore, 0
rm_reentered:
	pop	es
	ret

RcvMain  ENDP

	PAGE
;--------------------------------------------------------------------+
; Name : RcvPostFreeDescriptor
;
; Description:
; This function simply flips the ownership bit of the RcvCurrentDescriptor
; to the DM9100, and updates the RcvCurrentDescriptor pointer.
;
; Enter :
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+
	 PUBLIC RcvPostFreeDescriptor
RcvPostFreeDescriptor  PROC  NEAR
	pushf
	cli
	mov  si, RcvCurrentDescriptor	; Get pointer current descriptor
	mov  [si].RCV_DESCRIPTOR.RDES0, RDES0_M_OWN ; Set ownership to 90100
	mov  ax, [si].RCV_DESCRIPTOR.p_RcvNext
	mov  RcvCurrentDescriptor, ax	; Updatte RcvCurrentDescriptor

	popf

	ret
RcvPostFreeDescriptor  ENDP

EXTRN	rcv_mode_num : WORD
	PAGE
;--------------------------------------------------------------------+
; Name : RcvEnable
;
; Description: This function enables the receipt of frames from the adapter.
;
; Enter :
;
; Return : Nothing
;
; Destroied registers :
;
;---------------------------------------------------------------------+
	PUBLIC RcvEnable
RcvEnable  PROC  NEAR
	push eax
	push ebx
	push dx

	mov  RcvState, 1

	mov  eax, p_RcvRingPhys 	;    Write CR3 with p_RcvRingPhys
	mov  dx, p_CR3
	out  dx, eax
	mov  dx, p_CR7		       ;    Clear NISE and RXCIE in CR7
	in   eax, dx
;;;	   or	eax, 0FFFFFFFFh
	or   eax, (CR7_M_NISE OR CR7_M_RXCIE OR CR7_M_TXCIE)
	out  dx, eax
	mov  dx, p_CR8		       ;    Read to clear CR8
	in   eax, dx
;;-+, 2000.2.16, hu-tiong
;	mov  dx, p_CR6		       ;    Write CR6 to...
;	in   eax, dx
	mov	eax, PortConfigCR6
;;-+
	or   eax, CR6_M_RXSC		 ;    start the receiver...
	and  eax, NOT CR6_M_PAM 	;    Clear PASS_ALL_MULTICAST
	cmp	rcv_mode_num, 6 	;; Promiscuous mode ?
	jne	re_nopr
	or	eax, CR6_M_PM
	jmp	pr_write_CR6

re_nopr:
	and  eax, NOT CR6_M_PM	       ;    Clear promiscuous

pr_write_CR6:
;;++, 2000.2.16, hu-tiong
	mov	PortConfigCR6, eax
;;++
	call PortCR6Write
	pop  dx
	pop  ebx
	pop  eax
	ret
RcvEnable  ENDP
