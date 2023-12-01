PAGE    ,132
NAME    MACRCV
TITLE   MACRCV  --  Digital Internal Use Only

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
; This file contains all of the routines which implement the receive path
; for the NDIS 2.01 DC21040/DC21140 driver.
;
; General descripton of the receive process goes here.
;
; Maintainers:
;   eg      Eric Goldstein
;   mf      Maurene Fritz
;   ymf     Yishai Fraenkel
;   rv      Rivki Vizen
;   de      Dror Efraty
;
; Revision History:
;
; 11-May-1994   eg      Syntax changes for MASM 6.1.
;
; 25-May-1994   eg      Make RcvCurrentLookahead a word, and use it when
;                       calling ReceiveLookahead as specified by NDIS spec.
;
; 30-May-1994   eg      RcvEnable does not set CSR0<DSL>; that may be done only
;                       at port init/reset.
;
;  1-aug-1994   mf      Move receive descriptor definitions (RDES..) from here
;                       to HW.ASH
;
; 08-Sep-1994   ymf     Add code to deal with RxHang problem
;
; 12-Sep-1994   rv      Add support to DC21140
;
; 13-Dec-1994   ymf     Add debug messages + switching mechanism
;
; 15-Feb-1995   ymf     Add support for promiscuous mode in RcvEnable
;
; 23-Aug-1995   ymf     Fix an indications problem: Check in RcvMain - if
;                       indications are off, do not execute the rcv code.
;
; 09-Aug-1995   as      Add checking if was Rcv Overflows (CSR8 != 0)
;                       if yes: 1) stop  RX machine. (polling untile Stop)
;                               2) clean RX interrupt.
;                               3) clean the Rcv Ring.
;                               4) start RX machine.
;
; 25-Nov-1996	de	Changes in include file names, and in AWK conventions.
;

; This module contains the following functions:
;
; RcvMain                - Main receive processing loop.
;
; RcvNDISTransferData    - Copy received frame to protocol stack.
;
; RcvNDISReceiveRelease  - Return a ReceiveChain buffer (unimplemented)
;
; RcvNDISIndicationOn    - Enable Receive Indications.
;
; RcvNDISIndicationOff   - Disable Receive Indications.
;
; RcvPostFreeDescriptor  - Transfer ownership of current descriptor to
;                          DC21040/DC21140 and update current descriptor
;                          pointer.
;
; RcvEnable              - Enable adapter receive logic, the delivery of
;                          receive interrupts to host, and the delivery of
;                          received frames to protocol stack.
;
; RcvDisable             - Disable adapter receive logic, the delivery of
;                          interrupts to host, and elivery of frames to
;                          protocol stack.
;
; RcvInit                - Initialize data structures local to MACRCV module
;
; RcvUninit              - Uninitialize local data structures.
;

.xlist                                  ; disable listing the include file
include seg_defs.inc
include driver.inc
include macrcv.inc
include macro.inc
include dc_regs.inc
include nic.inc
include ndis.inc
include sss.inc
include macrcv.ash
.list                                   ; enable listing

EXTRN InterruptSemaphore:BYTE

DefRcvBuffersNum   EQU  8                ; Default number receive buffers

.386
START_DATA_SEGMENT_RUNTIME

p_RcvBlockVirt  DW 0                    ; NEAR Pointer to base of Receive Block
p_RcvBlockPhys  DD 0                    ; Physical address of Receive Block
p_RcvRingVirt   DW 0                    ; NEAR Pointer to base of Receive Ring
p_RcvRingPhys   DD 0                    ; Physical address of Receive Ring

RcvState       DW 0

RcvNumBuffers  DW DefRcvBuffersNum


RcvIndicationSemaphore  DB 0            ; State of NDIS indications  0=ON
                                        ; else=OFF

RcvIndicationFlag  DB  0FFh             ; Indication flag for calls to
                                        ; ReceiveLokahead
RcvIndicationsIssued  DB  0             ; This flag is used by the
                                        ; IndicateToProtocol function to
                                        ; schedule a call to Protocol Manager's
                                        ; IndicationComplete function at the
                                        ; END of ISR processing. See the
                                        ; InterruptMain function in MACISR.ASM
                                        ; for details.

RcvSemaphore  DB  0                     ; Controls re-entry of RcvMain

RcvCurrentLookahead     DW 64           ; Current receive lookahead value

RcvCurrentDescriptor     DW 0

RcvTemp        DW 0

RcvTDBytesCopied         DW 0
RcvTDBytesToBeCopied     DW 0
RcvTDCurrentBlock        DW 0
RcvTDBufferCount         DW 0

;========= D E B U G ================================================
;====================================================================

END_DATA_SEGMENT_RUNTIME

START_CODE_SEGMENT_RUNTIME

        PAGE
;***********
;* RcvMain *
;***********
;
; This routine is responsible for processing frames received from the adapter.
; This involves verifying the receive status, and rejecting the frame if there
; are errors. Additionally, this function determines the type of frame that
; has been received, and translates the frame appropriately.
;
; This function is called ONLY by the Interrupt Service Routine 'dev_interrupt'
; in module macisr.asm
;
; Returns: Nothing. Note: Many registers are blown away. This function is
;                   called ONLY from the ISR, which saves all registers.
;
; Algorithm:
;
; BEGIN
;    clear indications issued flag
;    while (RcvCurrentdescriptor owned by host) {
;       Get Descriptor from RcvCurrentDescriptor
;       if (Overflow counter != 0)  {
;          Reset Rx machin
;          Reset Rx Discriptors ring
;          Exit from Receive main loop
;       }
;       if (Error Summary Set) {
;          if (frame_status AND CRC_ERR)
;             Update CRC error counter
;          RcvPostFreeDescriptor
;       } else {
;          Update Total Frames Received OK
;          Turn indications off (increment RcvIndicationSemaphore)
;          RcvIndicationFlag = 0FFh
;          set indications issued flag
;          Call ReceiveLookahead
;          call RcvPostFreeDescriptor
;          if (RcvIndicationFlag != 0)
;             Turn indications back on (decrement RcvIndicationSemaphore)
;       }
;    }
; END
;
RcvMain  PROC  NEAR

        cli
;        cmp  RcvSemaphore, 0
;        jne  rm_reentered

;        mov  RcvSemaphore, 1

        sub  esi, esi
        sub  edi, edi

;        mov  RcvIndicationsIssued, 0  ;    clear indications issued flag
rm_loop:                              ;    while (
        ; If indications semaphor is on - perform nothing and exit
;        cmp  RcvIndicationSemaphore, 0
;        jne  rm_exit

	test NDISServiceStatus.sss_macstat._loword, SSS_OPEN
        jz   rm_exit		      ;    if adapter is closed - exit

	mov  si, RcvCurrentDescriptor ;      current descriptor owned by host)
        mov  eax, [si].RCV_DESCRIPTOR.RDES0
        test eax, RDES0_M_OWN
        jne  rm_exit

;*******************************************
;*    check in CSR8 if overflow occur ?
;*******************************************
	cmp	Nic.RxFifoHangPresence, TRUE		; does chip have RxHang bug
	jne	rm_no_overflow

; Now, check if Overflow Counter bits in CSR8 are set
        push    eax
        mov     dx, Nic.CSR8_Address
        in      eax, dx
        and     eax, Nic.CSR8_MaskOFF
	and	eax, NOT CSR8_MASK_MISSED_FRAMES
        pop     eax
        jz	SHORT rm_no_overflow

rm_overflow:
	call	RcvHandleRxHang
        jmp     rm_exit
;***************************************************************
rm_no_overflow:
        mov  RxHangCounter, 1                    ; RxHangCounter = 1

        test eax, RDES0_M_ES		; any errors at all?
        jz   SHORT rm_fmc_stat_ok	; nope.

        inc  NDISServiceStatus.sss_hard_err	; yup, count them.

	test eax, RDES0_M_CE		; crc errors?
        jz   SHORT rm_not_crc_err	; nope, count count it as one.
        inc  NDISServiceStatus.sss_crc_err
rm_not_crc_err:
        call RcvPostFreeDescriptor	; discard the frame and look again.
        jmp  rm_loop
rm_fmc_stat_ok:
	and  eax, RDES0_M_LENGTH      ;          eax is RDES0. Mask off, and
        shr  eax, RDES0_V_LENGTH      ;          shift rcv length to EAX<14:0>
        sub  ax, 4                    ;          Sub 4 CRC bytes
	mov	cx,ax

	push	cs
	pop	es
        mov  di, [si].RCV_DESCRIPTOR.p_buf
	add	di, 6 + 6		; point es:di -> packet type.

	mov	dl, 1	;BLUEBOOK		;assume bluebook Ethernet.
	mov	ax, es:[di]
	xchg	ah, al
	cmp 	ax, 1500
	ja	BlueBookPacket
	inc	di			;set di to 802.2 header
	inc	di
	mov	dl, 11; IEEE8023
BlueBookPacket:

;XXX	mov	dh,save_err
	push	cx			; Save frame size
	extrn	recv_find: near
	call	recv_find		; See if type and size are wanted
	pop	cx
	cld			; Copies below are forward, please
	mov ax,	es		; Did recv_find give us a null pointer?
	or ax,	di		; ..
	je	rcv_no_copy	; If null, don't copy the data

	push	cx		; We will want the count and pointer
	push	es		;  to hand to client after copying,
	push	di		;  so save them at this point

        mov  si, RcvCurrentDescriptor   ;    DS:SI -> Current Descriptor
        mov  si, [si].RCV_DESCRIPTOR.p_buf

        mov   ax, cx                      ;    Copy the immediate data
        and   ax, 3
        shr   cx, 2
        rep   movsd
        mov   cx, ax
        rep   movsb

	pop	si		; Recover pointer to destination
	pop	ds		; Tell client it's his source
	pop	cx		; And it's this long
	extrn	recv_copy: near
	call	recv_copy	; Give it to him
	push	cs		; recover our data segment.
	pop	ds
rcv_no_copy:
        call RcvPostFreeDescriptor    ;          RcvPostFreeDescriptor

;        cmp  RcvIndicationFlag, 0     ;          if (RcvIndicationFlag != 0)
;        jne  rm_loop
	jmp	rm_loop

;  Here, protocol leaved indications disabled.
;        inc  RcvIndicationSemaphore   ;          Turn indications off

;	and  Nic.Shadow_CSR7, NOT CSR7_RIM
rm_exit:

;        mov RcvSemaphore, 0
rm_reentered:
        ret

RcvMain  ENDP

        PAGE
;***********************
;* RcvNDISTransferData *
;***********************
;
; This function is called by a protocol stack wishing to copy the receive
; frame presented in the NDISReceiveLookahead call. The protocol passes in
; the offset at which the copy should begin, a pointer to the transfer data
; buffer descriptor, and a pointer to a WORD in which the number of bytes
; transferred is to be stored.
;
; Stack Frame relative to BP
;
; BP+14 LPWORD BytesCopied ; Pointer to word to store number of bytes copied
; BP+12 WORD   FrameOffset ; Starting Offset in frame for transfer
; BP+8  LPBUF  TDBufDescr  ; Virtual Address of transfer data descriptor
; BP+6  WORD   MACDS       ; DS of called MAC module
;
; The transfer data buffer descriptor points to a structure which describes
; the buffers the protocol stack has set up to receive the incoming frame.
; The format of the desriptor is:
;
; WORD TDDataCount ; Number of transfer data blocks.
;
; Followed by TDDataCount instances of:
;
; BYTE  TDPtrType ; Type of pointer (0=physical; 2=GDT)
; BYTE  TDResByte ; Reserved MBZ
; WORD  TDDataLen ; Length, in bytes, of this data block
; LPBUF TDDataPtr ; Address of this data block
;
; In DOS, the pointer type doesn't matter, since all pointers are in SEG:OFFSET
; format. In OS/2, we advertize in the MAC Service-Specific Characteristics
; table that we support GDTs (bit 14 = 1), but we may also get a Physical
; address, so the OS/2 portion is written to handle both Physical and GDTs.
; GDTs in OS/2 are handled just like SEG:OFFSET in DOS.
;
; Algorithm:
;
; BEGIN
;    DS:SI = &frame[TransferOffset]
;    RcvTDBytesCopied = 0
;    RcvTDBufferCount = TDDataCount
;    while (RcvTDBufferCount > 0) {
;       ES:DI = PhyToVir(TDDataPtr)
;       CX = TDDataLen
;       Copy Data Block
;       RcvTDBytesCopied += CX
;       point to next descriptor
;       RcvTDBufferCount -= 1
;    }
;    return(RcvTDBytesCopied)
; END
;
RcvNDISTransferData    PROC    FAR
        push bp
        mov  bp, sp
        push edi
        push esi
        push es
        push ds
        pushf

        cld
        cli                             ;    BLOCK Interrupts

        sub  esi, esi
        sub  edi, edi

        mov  ds, [bp+6]                 ;    Establish OUR Data Segment

        mov  si, RcvCurrentDescriptor   ;    DS:SI -> Current Descriptor
        mov  eax, [si].RCV_DESCRIPTOR.RDES0
        and  eax, RDES0_M_LENGTH
        shr  eax, RDES0_V_LENGTH
        sub  ax, 4                      ;    Get length in AX, adjust for CRC
                                        ;    RcvTDBytesToBeCopied = length -
        sub  ax, WORD PTR [bp+12]       ;            frame copy offset
        mov  RcvTDBytesToBeCopied, ax

        mov  ax, [si].RCV_DESCRIPTOR.p_buf ;    AX is pointer to buffer
        add  ax, WORD PTR [bp+12]       ;    add frame copy offset
        mov  si, ax                     ;    DS:SI -> Start of rec'd frame

        mov  RcvTDBytesCopied, 0        ;    RcvTDBytesCopied = 0
        mov  RcvTDCurrentBlock, 2
        les  di, [bp+8]                 ;  ES:DI -> transfer data buffer
        mov  ax, es:[di].TRANSFER_DATA_BLOCK.TDDataCount  ;  RcvTDBufferCount

        cmp  ax, 0                      ;  if zero buffers, return error.
        je   td_error_exit

        mov  RcvTDBufferCount, ax
td_loop:
        cmp  RcvTDBufferCount, 0        ;    while (RcvTDBufferCount > 0)
        je   td_done
        cmp  RcvTDBytesToBeCopied, 0    ;      AND (RcvTDBytesToBeCopied > 0) {
        je   td_done

        les  di, [bp+8]                 ;       ES:DI -> xfer data descriptor
        add  di, RcvTDCurrentBlock      ;       ES:DI -> current block in descr
        mov  cx, es:[di].TRANSFER_DATA_DESCR.TDDataLen ; CX = length of
                                        ;       current transfer buffer

        cmp  cx, 0
        je   SHORT td_next_buffer       ;       if buffer length = 0 skip

        cmp  cx, RcvTDBytesToBeCopied   ;       Check buffer length against
        jbe  SHORT td_copy              ;       number of bytes left to copy.

        mov  cx, RcvTDBytesToBeCopied   ;       Buffer is larger than number
                                        ;       of bytes left to copy, so
                                        ;       only copy number of bytes left.


td_copy:
        add  RcvTDBytesCopied, cx       ;       RcvTDBytesCopied += CX
        sub  RcvTDBytesToBeCopied, cx   ;       RcvTDBytesToBeCopied -= CX

;
;       ES:DI = PhyToVir(TDDataPtr)
;

IF OS EQ OS2
        cmp es:[di].TRANSFER_DATA_DESCR.TDPtrType, 0 ; Is the address Physical?
        je  td_os2_phys_to_gdt          ;       if so, convert it to a GDT

        les di, es:[di].TRANSFER_DATA_DESCR.TDDataPtr ; Otherwise, treat it
                                        ;       like a DOS FAR pointer.
        jmp td_os2_copy_data_block

td_os2_phys_to_gdt:
        push eax                        ; Preserve the 32 bit registers used.
        push ebx

        mov eax, es:[di].TRANSFER_DATA_DESCR.TDDataPtr
        mov RcvTemp, si
        mov ebx, eax                    ; move physical address to AX:BX
        shr eax, 16
        mov si, RxGDTSelector           ; SI points to the selector
        mov dl, DEVHLP_PHYSTOGDTSELECTOR
        call DWORD PTR DS:[devhlp]
        pop ebx
        pop eax
        jc  td_error_exit               ; If we get a bogus physical
                                        ; address, bag out completely.
        mov es, si                      ; SI is now virtual selector
        sub di, di                      ; ES:0 now maps to physical addr
        mov si, RcvTemp

td_os2_copy_data_block:

ENDIF

IF OS EQ DOS
        les di, es:[di].TRANSFER_DATA_DESCR.TDDataPtr
                                        ; DOS address is already SEG:OFF
ENDIF

;
; At this point ES:DI holds the virtual address of the transfer data block
; and DS:SI points to the received frame.
;

        mov ax, cx                      ;       Copy Data Block
        and ax, 3
        shr cx, 2
        rep movsd
        mov cx, ax
        rep movsb

td_next_buffer:
        add RcvTDCurrentBlock, 8        ;       point to next descriptor
        dec RcvTDBufferCount            ;       RcvTDBufferCount -= 1
        jmp td_loop                     ;    }
td_done:
        les di, [bp+14]
        mov ax, RcvTDBytesCopied
        mov WORD PTR es:[di], ax        ;    return(RcvTDBytesCopied)

        mov ax, MAC_SUCCESS
        jmp SHORT td_exit

td_error_exit:
        mov ax, MAC_INVALID_PARAMETER
        les di, [bp+14]
        mov WORD PTR es:[di], 0

td_exit:
        popf
        pop ds
        pop es
        pop esi
        pop edi
        pop bp
        ret 12
RcvNDISTransferData    ENDP


        PAGE
;*************************
;* RcvNDISReceiveRelease *
;*************************
;
; This function is called by the protocol stack to return a ReceiveChain
; buffer to the driver. This driver never issues a ReceiveChain indication
; to the protocol stack, but we must be prepared to handle a call to this
; entry point just in case.
;
; Stack Frame relative to BP
;
; BP+8  WORD  ReqHandle   ; Unique handle assigned during ReceiveChain call
; BP+6  WORD  MACDS       ; DS of called MAC module
;
; Algorithm:
; BEGIN
;    return FAILURE
; END
RcvNDISReceiveRelease  PROC    FAR
        mov  ax, MAC_GENERAL_FAILURE  ;    return FAILURE
        ret  4
RcvNDISReceiveRelease  ENDP

        PAGE
;***********************
;* RcvNDISIndicationOn *
;***********************
;
; This function is called by the protocol stack to enable receive indications
; from the driver. The NDIS spec REQUIRES that "This function always returns
; with interrupts disabled".
;
; The indication semaphore is implemented as a counting semaphore, which
; allows nesting RcvNDISIndicationOn and RcvNDISIndicationOff calls.
; Indications are considered enabled when the semaphore is equal to 0. A
; call to RcvNDISIndicationOff INCREMENTS the semaphore, and a call to
; RcvNDISIndicationOn DECREMENTS the semaphore.
;
; The indication semaphore may be thought of as tracking the 'off depth'.
;
; When the indication semaphore is returned to 0 the adapter interrupt is
; normally re-enabled. The only exception is if the ISR Semaphore is set.
; If the ISR Sempahore is set, RcvNDISIndicationOn is being called due to the
; protocol stack seizing control during a receive indication, or during
; indication complete processing at the end of the ISR. In both circumstances,
; the adapter interrupt should NOT be re-enabled, as this could cause a
; re-entry to the ISR dev_interrupt. dev_interrupt is NOT designed to be
; re-entrant. This is especially true on the DOS platform, where an
; interrupt stack is allocated.
;
; NOTE: According to the NDIS 2.01 specification, this function must work
;       when the adapter is closed.
;
; NOTE: The RcvNDISIndicationOn and RcvNDISIndicationOff functions employ a
;       dirty trick to save beaucoup cycles in two routines that get called
;       A LOT. The way that these routines usually are coded is with an ENTER
;       statement, or a with a push bp - mov bp,sp deal at the begining, and
;       DS is pulled from the calling stack frame at [bp+6]. These routines
;       never modify the DS register. Instead, the Data Segment is established
;       in the ES register, using the SEG operator on the
;       RcvIndicationSemaphore. Since, by Microsoft calling standard, ES does
;       not need to be saved, several pushes and pops are saved. These are
;       fairly costly instructions even in the 486.
;
; Algorithm:
;
; BEGIN
;   disable system interrupts (required by NDIS 2.01 spec)
;   decrement IndicationSemaphore
;   if (RcvIndicationSemaphore == 0)
;      if (a packet is pending due to indications disabeling
;            during ReceiveLookAhead) AND (TO bit in CSR5 is reset)
;         Create a false interrupt (only CSR5 at the moment).
;      if (InterruptSemaphore == 0)
;         re-enable Adapter Interrupts (CSR7)
; END
;

RcvNDISIndicationOn    PROC    FAR
        cli                             ; Disable system interrupts
                                        ; CLI required by 2.01 spec

	push ds
	push si
        mov  ax, cs			; SEG RcvIndicationSemaphore
        mov  ds, ax

        cmp  RcvIndicationSemaphore, 0 ; Don't let it go negative
        je   indon_exit
        dec  RcvIndicationSemaphore  ; Decrement indication semaphore
        jnz  indon_exit                 ; if (RcvIndicationSemaphore == 0)

        or   Nic.Shadow_CSR7, (CSR7_NIM OR CSR7_RIM)

	mov  si, RcvCurrentDescriptor      ;         If Curr receive descriptor
	test DWORD PTR [si].RCV_DESCRIPTOR.RDES0, RDES0_M_OWN;  not host owned -
	jnz  indon_dont_create_interrupt
	push dx
	push eax
        mov  dx,  Nic.CSR5_Address
	in   eax, dx
	test eax, CSR5_RI
	pop  eax
	pop  dx

	jnz  indon_dont_create_interrupt

	call GenerateTUInterrupt

indon_dont_create_interrupt:
	cmp  InterruptSemaphore, 0
	jnz  indon_exit		; don't enable interrupts when inside the ISR

	SET_ADAPTER_INTERRUPT
indon_exit:
        mov  ax,MAC_SUCCESS             ; Return success to procotol stack

	pop  si
	pop  ds
        ret  2

RcvNDISIndicationOn    ENDP

        PAGE
;************************
;* RcvNDISIndicationOff *
;************************
;
; This function is called by the protocol stack to disable receive indications
; from the driver. The NDIS spec REQUIRES that "This function always returns
; with interrupts disabled".
;
; A complete description of the IndicationSemaphore policy can be found in the
; function header for RcvNDISIndicationOn.
;
; NOTE: According to the NDIS 2.01 specification, this function must work
;       when the adapter is closed.
;
; Algorithm:
;
; BEGIN
;   disable system interrupts (required by NDIS 2.01 spec)
;   increment RcvIndicationSemaphore
;   block Adapter Interrupts
; END
;
RcvNDISIndicationOff   PROC    FAR
        cli                                ; Disable system interrupts
                                           ; CLI required by NDIS 2.01 spec
	push ds

        mov  ax, cs			; SEG RcvIndicationSemaphore
        mov  ds, ax

        inc  RcvIndicationSemaphore     ; Increment RcvIndicationSemaphore

	and    Nic.Shadow_CSR7, NOT CSR7_RIM

	cmp  InterruptSemaphore, 0
	jnz  indoff_exit	; don't enable interrupts when inside the ISR

	SET_ADAPTER_INTERRUPT

indoff_exit:
	mov  ax,MAC_SUCCESS                ; Return success to procotol stack

	pop  ds
        ret  2

RcvNDISIndicationOff   ENDP

        PAGE
;*************************
;* RcvPostFreeDescriptor *
;*************************
;
; This function simply flips the ownership bit of the RcvCurrentDescriptor
; to the DC21040/DC21140, and updates the RcvCurrentDescriptor pointer.
;
; The atomicity of this function is vital, and it is called ONLY when
; adapter interrupts are disabled. It is called from RcvMain and
;
;
;
; Returns: Nothing. Note: AX, and SI get blown away. This routine is
;                   called ONLY from inside MACRCV.ASM, and the routines
;                   which call it expect this behavior.
;
; Algorithm:
; BEGIN
;    Flip ownership of current descriptor, and zero length and flags
;    Update RcvCurrentDescriptor
; END
;
RcvPostFreeDescriptor  PROC  NEAR
        pushf
        cli
        mov  si, RcvCurrentDescriptor   ; Get pointer current descriptor
        mov  [si].RCV_DESCRIPTOR.RDES0, RDES0_M_OWN ; Set ownership to
                                                ; DC21040/DC21140
        mov  ax, [si].RCV_DESCRIPTOR.p_next
        mov  RcvCurrentDescriptor, ax   ; Updatte RcvCurrentDescriptor

        popf

        ret
RcvPostFreeDescriptor  ENDP


	PAGE
;*******************
;* RcvHandleRxHang *
;*******************
; This routine treats the possible Rx Hang II
; Algorithm:
;   call  RcvDisable
;   Poll on CSR5 for RX_STATE = STOPPED
;   clean CSR5 RI bit
;   call  RcvReset
;   call  RcvEnable
;
; The routine destroys eax and dx registers.

RcvHandleRxHang  PROC

        ; Write RX stop to CSR6 +  Disable RIM mask in CSR7
        ;---------------------------------------------------
        call    RcvDisable
        mov     dx, Nic.CSR5_Address
rm_poll_rx_state:
        ; Poll on CSR5 for RX_STATE = STOPPED
        ;--------------------------------------
	in      eax, dx		; eax is destroyed
        and     eax, CSR5_RS
        jnz     SHORT rm_poll_rx_state

        ; Clean CSR5 RI bit
        ;-----------------------------------
        or      eax, CSR5_RI
        out     dx,  eax

        ; Clear Receive Discriptors Ring
        ;-----------------------------------
        call    RcvReset
        ; Write Start RX to CSR6 + Enable RIM mask in CSR7
        ;--------------------------------------------------
        call    RcvEnable
	ret
RcvHandleRxHang  ENDP


	PAGE
;*************
;* RcvEnable *
;*************
;
; This function enables the receipt of frames from the adapter.
;
; Returns: Nothing. All registers preserved.
;
; Algorithm:
; BEGIN
;    Write CSR3 with p_RcvRingPhys to set base of receive ring
;    Set NIM and RIM in CSR7 to enable delivery of rcv interrupts
;    Read to clear CSR8
;    Write CSR6 to start receiver, clear pass all MCast. If packet filter
;    indicates so, set promiscuous bit.
; END
;
RcvEnable  PROC  NEAR
        push eax
        push bx
        push dx

        mov  RcvState, 1

        mov  eax, p_RcvRingPhys         ;    Write CSR3 with p_RcvRingPhys
        mov  dx, Nic.CSR3_Address
        out  dx, eax
        mov  dx, Nic.CSR8_Address                 ;    Read to clear CSR8
        in   eax, dx

        or   Nic.Shadow_CSR6, CSR6_START_RX_COMMAND ;    start the receiver...
	call Nic.WriteCSR6
; Check if indications are off. If so don't enable RI
	cmp  RcvIndicationSemaphore, 0
	jnz  re_after_set_ri
	or   Nic.Shadow_CSR7, (CSR7_NIM OR CSR7_RIM)
re_after_set_ri:
        pop  dx
        pop  bx
        pop  eax
        ret
RcvEnable  ENDP

        PAGE
;**************
;* RcvDisable *
;**************
;
; This function disables the receipt of frames from the adapter.
;
; Returns: Nothing. All registers preserved.
;
; Algorithm:
; BEGIN
;    Reset RcvState to 0
;    Write CSR13 to
;    Write CSR6 to stop receiver
;    Write CSR7 to mask RIM interrupt
; END
;
RcvDisable  PROC  NEAR

        mov  RcvState, 0

        and  Nic.Shadow_CSR6, NOT CSR6_START_RX_COMMAND
        call Nic.WriteCSR6

;    Write CSR7 to mask RIM interrupt
	and  Nic.Shadow_CSR7, NOT CSR7_RIM

	ret
RcvDisable  ENDP


        PAGE
;************
;* RcvReset *
;************
;
; This routine re-initializes the receive module. It has the following
; effect:
;
; 1) RcvDisable is called with the following actions:
;    - RcvState is reset to 0
;    - SIA is disabled
;    - Receiver is stopped
;    - RIM interrupt is masked
; 2) The receive descriptor ring is reinitialized with all own bits
;    set to DC21040/DC21140
; 3) The RcvCurrentDescriptor is reinitialized to point to the base of the
;    ring
;
; Stack Frame relative to BP (Remember, gang, this is a NEAR call, so the
;                             first argument appears at BP+4. It's NOT a typo)
;
; BP+6  DWORD  PhysAddr    ; Physical Address of Memory Block
; BP+4  WORD   VirtAddr    ; NEAR pointer to Memory Block. DS:VirtAddr
;
; Algorithm:
; BEGIN
;    return(AX)
; END
;
RcvReset PROC NEAR
        push cx
        push si

        call RcvDisable                 ; Disable receiver

        mov  si, p_RcvRingVirt          ; Get pointer to base of receive ring
        mov  cx, RcvNumBuffers          ; Get RcvNumBuffers

rreset_loop:
        mov  [si].RCV_DESCRIPTOR.RDES0, RDES0_M_OWN ; Set ownership to
                                                ; DC21040/DC21140
        mov  si, [si].RCV_DESCRIPTOR.p_next     ; SI points to next descriptor
        loop rreset_loop                ; Loop while CX != 0

        mov  cx, p_RcvRingVirt
        mov  RcvCurrentDescriptor, cx   ; Initialize current descriptor


        pop  si
        pop  cx
        ret
RcvReset ENDP

END_CODE_SEGMENT_RUNTIME

START_CODE_SEGMENT_BIND

        PAGE
;***********
;* RcvInit *
;***********
;
; This routine initializes the receive module. It must be called before
; any other calls are made to the receive module.
;
; Returns: Bytes used in AX. All other registers preserved.
;
; Stack Frame relative to BP (Remember, gang, this is a NEAR call, so the
;                             first argument appears at BP+4. It's NOT a typo)
;
; BP+6  DWORD  PhysAddr    ; Physical Address of Memory Block
; BP+4  WORD   VirtAddr    ; NEAR pointer to Memory Block. DS:VirtAddr
;
; Algorithm:
; BEGIN
;    return(AX)
; END
;
RcvInit PROC NEAR
        push bp
        mov  bp,sp
        push edx
        push cx
        push di
        push si

        mov  RcvState, 0

        mov  ax, WORD PTR [BP+4]        ; Get Virtual address of Memory Block
        mov  p_RcvBlockVirt, ax
        mov  p_RcvRingVirt, ax
        mov  edx, DWORD PTR [BP+6]      ; Get Physical address of Memory Block
        cmp  edx, 0                     ; If address is zero, just return
        je   rinit_return_bytes_used    ; bytes used, don't init.
        mov  p_RcvBlockPhys, edx
        mov  p_RcvRingPhys, edx
        mov  ax, RcvNumBuffers          ; Get number of Rcv Buffers
        mov  dx, RCV_BUFFER_SIZE
        mul  dx
        movzx edx, ax                   ; EDX = #buffers * size of buffer
        add  p_RcvRingVirt, dx          ; Add total size of receive buffer...
        add  p_RcvRingPhys, edx         ; ...space to get offset of desc ring
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
        mov  cx, RcvNumBuffers          ; Get RcvNumBuffers
        dec  cx                         ; Initialize NumRcvBuffs-1 descriptors

rinit_loop:
        mov  [si].RCV_DESCRIPTOR.RDES0, RDES0_M_OWN ; Set ownership to
                                                ; DC21040/DC21140
        mov  [si].RCV_DESCRIPTOR.RDES1, 0002F85F0h  ; Set buffer 1&2 to length 1520
        mov  [si].RCV_DESCRIPTOR.RDES2, edx         ; Point buffer 1 to edx
        mov  [si].RCV_DESCRIPTOR.RDES3, edx         ; Point buffer 2 to edx
        mov  [si].RCV_DESCRIPTOR.p_buf, di          ; Init buf virtual address
        mov  ax, si
        add  ax, SIZE RCV_DESCRIPTOR    ; AX points to next descriptor
        mov  [si].RCV_DESCRIPTOR.p_next, ax ; Init virtual address of next desc
        mov  si, ax                     ; SI points to next descriptor
        add  edx, RCV_BUFFER_SIZE       ; EDX holds physical address of next buf
        add  di, RCV_BUFFER_SIZE        ; DI points to next buf
        loop rinit_loop                 ; Loop while CX != 0
;
; Now initialize the last descriptor
;
        mov  [si].RCV_DESCRIPTOR.RDES0, RDES0_M_OWN ; Set ownership to
                                                ; DC21040/DC21140
        mov  [si].RCV_DESCRIPTOR.RDES1, 0002F85F0h OR RDES1_M_RER ; end of ring
        mov  [si].RCV_DESCRIPTOR.RDES2, edx         ; Point buffer 1 to edx
        mov  [si].RCV_DESCRIPTOR.RDES3, edx         ; Point buffer 2 to edx
        mov  [si].RCV_DESCRIPTOR.p_buf, di          ; Init buf virtual address
        mov  ax, p_RcvRingVirt
        mov  [si].RCV_DESCRIPTOR.p_next, ax         ; point to start of ring
;
; At this point, the receive ring of descriptors is initialized, and
; all ownership bits are set to the DC21040/DC21140. All is set for receive DMA
; traffic to be delivered to the buffers once the adapter is enabled.
;
        mov  ax, p_RcvRingVirt
        mov  RcvCurrentDescriptor, ax   ; Initialize current descriptor

rinit_return_bytes_used:
        mov  ax, RcvNumBuffers          ; Get number of Rcv Buffers
        mov  dx, RCV_BUFFER_SIZE
        add  dx, SIZE RCV_DESCRIPTOR
        mul  dx                         ; DX:AX = (BUFFER_SIZE + DESCR_SIZE) *
                                        ;              NUMBER_OF_BUFFERS


        pop  si
        pop  di
        pop  cx
        pop  edx
        pop  bp
        ret
RcvInit ENDP

        PAGE
;*************
;* RcvUninit *
;*************
;
; This routine uninitializes the receive module.
;
; Algorithm:
; BEGIN
; END
;
RcvUninit PROC NEAR
        mov  RcvState, 0
        ret
RcvUninit ENDP

END_CODE_SEGMENT_BIND
END

