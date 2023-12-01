PAGE    ,132
NAME    MACXMT
TITLE   MACXMT  --  Digital Internal Use Only

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
; This module contains all of the functions and data structures which
; implement the transmit path for the DC21040 NDIS 2.01 driver.
;
; Maintainers:
;       eg      Eric Goldstein
;       mf      Maurene Fritz
;       ymf     Yishai Fraenkel
;       rv      Rivki Vizen
;
; Revision History:
;
; 10-May-1994   eg      Bug fixes to setting of TDES1 bits for Setup frames and
;                       CRC generation:  Changes to XmtNDISTransmitChain,
;                       XmtSendSetupFrame, and XmtInit.
;
; 11-May-1994   eg      Syntax changes for MASM 6.1.
;
; 23-May-1994   eg      Get chip revision from Nic.Rev, which is set at init
;                       time, instead of reading CFRV register.
;
; 30-May-1994   eg      XmtSendSetupFrame returns to caller only after setup
;                       frame has been processed, so that nothing else is done
;                       too soon.
;
; 31-May-1994   eg      Remove spurious "out" from tc_<error>_exit.
;
;  6-Jun-1994   eg      1)  Never do software CRC calculation for short
;                           packets.  This is unnecessary if they are smaller
; D-Day -- 50th             than the FIFO size, and won't work at all if they
;  anniversary              are so short that they are padded on transmission.
;                       2)  Longword-align XmtCRCTable for faster generation.
;
; 21-Jun-1994   eg      Replace XmtGenerateCRC flag with global parameter
;                       XmtCRCThreshold.  This is set by XmtInit, unless
;                       already set elsewhere.
;
; 23-Jun-1994   mf  Modify busy wait in XmtSendSetupFrame so that it times
;                   out instead of hanging if the setup packet never completes
;                   and report an error by setting carry;
;                   Don't PUSHF and POPF
;
;  1-aug-1994   mf  Move transmit descriptor definitions (TDES..) from here
;                   to HW.ASH
;
;  18-Aug-1994  ymf Add code for identifying TxHang
;
;  12-Sep-1994  rv  Add support to DC21140
;
;  13-Dec-1994  ymf Add debug messages + switching mechanism
;
;  23-Jan-1995  ymf Add STI at end of XmtNDISTransmitChain
;
;  25-Nov-1996	de  Changes in include file names, and in AWK conventions.
;
;  13-Jan-1996	de  Fix a bug in checking Tx buffer overflows.
;
;
.xlist                                  ; disable listing the include file
include seg_defs.inc
include macxmt.inc
include dc_regs.inc
include nic.inc
include driver.inc
include ndis.inc
include sss.inc
include macxmt.ash
.list                                   ; enable listing
.386

DefXmtBuffersNum   EQU  8                ; Default number transmit buffers

START_DATA_SEGMENT_RUNTIME

XmtNumBuffers         DW DefXmtBuffersNum    ; Number of transmit buffers.

XmtCurrentDescriptor  DW 0    ; Pointer to current descriptor

XmtNumDataBlocks      DW 0    ; Number of blocks in current TransmitChain
                              ; request descriptor

XmtTmp                DW 0    ; A temporary variable for use by TransmitChain

p_XmtRingVirt         DW 0    ; A virtual NEAR pointer to the base of the
                              ; transmit descriptor ring

p_XmtRingPhys         DD 0    ; A 32 bit physical pointer to the base of the
                              ; transmit descriptor ring

TxDescFilterValue     DD TDES0_M_ALL_ERR  ; a filter thet masks NC and LO bits
					  ; in TDES0, when in Full-Duplex

END_DATA_SEGMENT_RUNTIME

START_DATA_SEGMENT_BIND

p_XmtBlockPhys        DD 0    ; A 32 bit physical pointer to the base of the
                              ; transmit buffers

p_XmtBlockVirt        DW 0    ; A virtual NEAR pointer to the base of the
                              ; transmit buffers

END_DATA_SEGMENT_BIND

START_DATA_SEGMENT_RUNTIME

XmtState              DW 0    ; Current state of the trasmit object. 1=Active
                              ; 0=Inactive

;
; NOTE: the variables XmtNoCarrierFlag and XmtCompletedCount are used by
;       the TP Autosensing algorithm detailed in the module AUTOSENS.ASM
;

XmtNoCarrierFlag      DB 0    ; A flag set by TransmitChain when a transmit
                              ; buffer is detected with failed due to no
                              ; carrier status.

XmtCompletedCount     DW 0    ; A count of transmit descriptors that have
                              ; completed successfully or unsuccessfully

XmtCRCThreshold       DW -1   ; Minimum frame size for which the driver should
                              ; compute the CRC.  If less than 64, the Tulip's
                              ; padding will prevent CRC_Calc from working
                              ; correctly. It is initiated as -1 to disable the
			      ; CRC calculation.
XmtTheirPtr	      dd ?    ; Save the pointer to their packet.

;=========== D E B U G ==============================================
END_DATA_SEGMENT_RUNTIME

START_CODE_SEGMENT_RUNTIME

        PAGE
        PAGE
;************************
;* XmtNDISTransmitChain *
;************************
;
; This function is called by the protocol stack in order to transmit frames.
;
;
; Stack Frame (relative to BP)
;
; BP+14 WORD  ProtID     ; Module ID of Protocol
; BP+12 WORD  ReqHandle  ; Unique handle for this request, or zero
; BP+08 LPBUF XmtBufDescr ; Pointer to frame buffer descriptor
; BP+06 WORD  MACDS      ; Our Data Segment
;
; Algorithm:
;
; BEGIN
;   if (transmit not enabled)
;      return(INVALID_FUNCTION)
;   if (we don't own XmtCurrentDescriptor)
;      return(OUT_OF_RESOURCE)
;   Get status from XmtCurrentDescriptor and update NDIS Xmt Error counters
;   copy Transmit Buffer to XmtCurrentDescriptor->p_XmtBuffer
;   Flip Ownership bit
;   Deal with TxHang (Update counter variable)
;   Update NDIS Xmt OK Stats
;   return(SUCCESS)
; END
;
        ALIGN  4
	public	send_pkt
send_pkt:
	push	ds
	push	cs			;get our ds.
	pop	ds
	pop	word ptr XmtTheirPtr[2]
	mov	word ptr XmtTheirPtr[0], si

	cmp	cx,1514
	jbe	tc_begin
        jmp   tc_inv_param

tc_begin:
        test  NDISServiceStatus.sss_macstat._loword, SSS_OPEN ; if (adapter is closed)
        jz    tc_invalid_exit             ;    return (INVALID_FUNCTION)

        mov   si, XmtCurrentDescriptor
        mov   eax, [si].XMT_DESCRIPTOR.TDES0
        test  eax, TDES0_M_OWN            ; if (We don't own current descriptor)
        jnz   tc_out_of_resource_exit     ;    return (OUT_OF_RESOURCE)

tc_buffer_available:

        mov  di, [si].XMT_DESCRIPTOR.p_XmtBuffer ; index into driver buffer
                                          ; for rest of routine

        test  eax, TDES0_M_ES             ; Check the transmit Error Summary
        jnz   tc_error_stats              ; If no errors...
        inc   XmtCompletedCount           ; bump CompletedCount for autosense
        jmp   tc_stats_done               ; and skip error counters

tc_error_stats:
	and   eax, TxDescFilterValue	  ; Filter no_carrier and loss_of_carrier
					  ;   when in Full-Duplex.
	test  eax, TDES0_M_NC             ; If NC error bit is set...
        jz    tc_check_ec
        mov   XmtNoCarrierFlag, 1         ; ...Set XmtNoCarrierFlag

tc_check_ec:
        test  eax, TDES0_M_EC             ; Excessive Collisions
        jz    tc_check_1_coll
        inc   NDISMediaSpecificStatus.mss_max_coll
        jmp   tc_check_deferred
tc_check_1_coll:
        test  eax, TDES0_M_CC             ; N Collisions
        jz    tc_check_deferred
        inc   NDISMediaSpecificStatus.mss_N_coll
tc_check_deferred:
        test  eax, TDES0_M_DE             ; Deferred
        jz    tc_check_late
        inc   NDISMediaSpecificStatus.mss_deferred
tc_check_late:
        test  eax, TDES0_M_LC             ; Late Collision
        jz    tc_check_lost_carrier
        inc   NDISMediaSpecificStatus.mss_late_coll
tc_check_lost_carrier:
        test  eax, TDES0_M_LO             ; Loss of carrier during transmission
        jz    tc_stats_done
        inc   NDISMediaSpecificStatus.mss_carrier

tc_stats_done:
	push	cs			; get our segment into es.
	pop	es

	push	ds
	lds	si,XmtTheirPtr
	push	cx			; preserve cx.
        mov   ax, cx                      ;    Copy the immediate data
        and   ax, 3
        shr   cx, 2
        rep   movsd
        mov   cx, ax
        rep   movsb
	pop	cx
	pop	ds

        mov   si, XmtCurrentDescriptor    ; get descriptor for this frame
        mov   eax, [si].XMT_DESCRIPTOR.TDES1 ; field for its previous frame
        and   eax, TDES1_M_TER            ; keep only the TER bit
        or    eax, (TDES1_M_FS OR TDES1_M_LS) ; first and last descr. for frame
        mov   ax, cx                      ; new frame's size in BUFFER_1_SIZE
        mov   [si].XMT_DESCRIPTOR.TDES1, eax ; TDES1 for this frame
;
; If the packet is long enough that the driver should generate the CRC, call
; CRC_Calc to do so and disable DC21040 CRC generation.
;
        cmp   cx, XmtCRCThreshold         ; long enough for SW CRC generation?
        jb    tc_update_stats             ; branch if not
        mov   si, [si].XMT_DESCRIPTOR.p_XmtBuffer ; DS:SI points to frame
	push	cx
        call  CRC_Calc
	pop	cx
	mov   [si], eax			  ; Plant the calculated CRC
        mov   si, XmtCurrentDescriptor    ; restore pointer to descriptor
        add   [si].XMT_DESCRIPTOR.TDES1, (TDES1_M_AC + 4)
                                          ; suppress hardware CRC generation,
                                          ; add CRC's length to frame size

tc_update_stats:
        inc  NDISServiceStatus.sss_frames_tx
        movzx  eax, cx
        add  NDISServiceStatus.sss_bytes_tx, eax

        mov   di, [si].XMT_DESCRIPTOR.p_XmtBuffer
        mov  ax, WORD PTR 0[di]            ;        if (frame is BCast)
        and  ax, WORD PTR 2[di]
        and  ax, WORD PTR 4[di]
        cmp  ax, 0FFFFh
        jne  tc_not_broadcast
        inc NDISServiceStatus.sss_broad_tx ;          Update Total BCast
	jmp  tc_not_mcast

tc_not_broadcast:
        test  BYTE PTR [di], 01h          ;        if (frame is MCast)
        jz    tc_not_mcast
        inc NDISServiceStatus.sss_multi_tx ;          Update Total MCast

tc_not_mcast:
        mov   TxHangCounter, 1      ; Set TxhangCounter to 1 indicating transmit

        mov   [si].XMT_DESCRIPTOR.TDES0, TDES0_M_OWN ; Set ownership to
                                                 ; DC21040/DC21140

        mov   dx, Nic.CSR1_Address
        mov   eax,1
        out   dx, eax                     ; Off it goes! Kick the tx poll demand

        mov   eax, CSR5_TU              ; Prepare EAX for clearing CSR5 TU
        mov   dx, Nic.CSR5_Address                  ; Prepare DX for clearing CSR5 TU
        out   dx, eax                     ; Clear CSR5 TU bit

        test  [si].XMT_DESCRIPTOR.TDES0, TDES0_M_OWN ;check if already sent
        jnz   no_op                       ; Not sent - Do No Op
        mov   TxHangCounter, 0

no_op:  mov   ax, [si].XMT_DESCRIPTOR.p_XmtNext
        mov   XmtCurrentDescriptor, ax    ; Update XmtCurrentDescriptor


tc_done:
        mov   ax, MAC_SUCCESS             ; return(SUCCESS)
	clc
        jmp   short tc_exit

tc_invalid_exit:
        mov   ax, MAC_INVALID_FUNCTION
	stc
	mov	dh,12	;CANT_SEND
        jmp   short tc_exit

tc_out_of_resource_exit:
        mov   ax, MAC_OUT_OF_RESOURCE
	stc
	mov	dh,12	;CANT_SEND
        jmp   short tc_exit

tc_bogus_physical_exit:

tc_inv_param:
        mov   ax, MAC_INVALID_PARAMETER
	stc
	mov	dh,12	;CANT_SEND

tc_exit:
        ret


        PAGE
;*********************
;* XmtSendSetupFrame *
;*********************
;
; This routine transmits the XmtCurrentDescriptor as a setup frame. This
; routine assumes that the setup frame has alread been built into the
; buffer associated with the XmtCurrentDescriptor.
;
; RETURNS: carry set if setup packet did not complete
;
; Algorithm:
; BEGIN
;    Initialize transmit descriptor to set setup frame with perfect filtering
;    Flip the own bit
;    Kick the tx poll demand register (CSR1)
;    Update XmtCurrentDescriptor
;    Wait until the setup frame has been processed
;    If (timeout)
;       return(carry set)
;    Else
;       return(carry clear)
; END
;
                   ALIGN  4
XmtSendSetupFrame  PROC  NEAR

        cli
        cld

        push  eax
        push  ebx
        push  dx
        push  si


        mov   si, XmtCurrentDescriptor   ; descriptor for this frame
        mov   eax, [si].XMT_DESCRIPTOR.TDES1 ; field for its previous frame
        and   eax, TDES1_M_TER           ; keep only the TER bit
        or    eax, TDES1_M_SET           ; Assert the Setup Packet bit
        mov   ax, XMT_SETUP_FRAME_SIZE  ; Set size to HW_K_SETUP_FRAME_SIZE
        mov   [si].XMT_DESCRIPTOR.TDES1, eax ; Write TDES1

        mov   [si].XMT_DESCRIPTOR.TDES0, TDES0_M_OWN ; Set ownership to
                                                 ; DC21040/DC21140

        mov   dx, Nic.CSR1_Address
        mov   eax,1
        out   dx, eax                    ; Send the frame

        mov   ax, [si].XMT_DESCRIPTOR.p_XmtNext
        mov   XmtCurrentDescriptor, ax   ; Update XmtCurrentDescriptor

        push  cx
        mov   cx, 33000             ; a long loop, but not forever
xssf_wait:                          ; if this fails, bind will fail on its own
        test  [si].XMT_DESCRIPTOR.TDES0, TDES0_M_OWN ; setup processing done?
        je    xssf_loop_done
	call  PostResetDelay		; Wait for ~160msec = 33000 * 5usec
        loop  xssf_wait                 ; loop if not yet
        stc                             ; set carry if if there's an error
xssf_loop_done:
        pop   cx

        pop   si
        pop   dx
        pop   ebx
        pop   eax

        ret
XmtSendSetupFrame  ENDP

        PAGE
;*********************
;* XmtGetSetupBuffer *
;*********************
;
; This function returns a virtual NEAR pointer to the transmit buffer pointed
; to by XmtCurrentDescriptor. The calling agent builds a DC21040/DC21140 setup
; frame in the buffer, and eventually calls XmtSendSetupFrame to transmit the
; setup frame to the DC21040/DC21140. Clearly, since this routine returns a
; pointer based on XmtCurrentDescriptor, the XmtCurrentDescriptor cannot be
; allowed to  change from the time the buffer is allocated to the time
; XmtSendSetupFrame is called. It is the calling agent's responsibility to
; ensure the system interrupts are disabled from just before XmtGetSetupBuffer
; is called, until the time XmtSendSetupFrame returns.
;
; Returns: AX - NEAR pointer to buffer. All other regs preserved.
;
                   ALIGN  4
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
;*************
;* XmtEnable *
;*************
;
; This function enables the transmission of frames on the adapter
;
; Returns: Nothing. All registers preserved.
;
; Algorithm:
; BEGIN
;    Write CSR4 with p_XmtRingPhys to set base of transmit ring
;    Write CSR6 to start transmitter
;    Initialize XmtCurrentDescrtiptor
; END
          ALIGN  4
XmtEnable PROC NEAR
        push eax
        push dx

        mov  XmtState, 1

        mov  eax, p_XmtRingPhys         ;    Write CSR4 with p_XmtRingPhys
        mov  dx, Nic.CSR4_Address
        out  dx, eax
        mov  dx, Nic.CSR6_Address                 ;    Start the transmit process
        or   Nic.Shadow_CSR6, CSR6_START_TX_COMMAND
        call Nic.WriteCSR6

        mov  ax, p_XmtRingVirt
        mov  XmtCurrentDescriptor, ax   ;    Initialize current descriptor

        pop  dx
        pop  eax
        ret
XmtEnable ENDP

        PAGE
;**************
;* XmtDisable *
;**************
;
; This function disables the transmission of frames on the adapter
;
           ALIGN  4
XmtDisable PROC NEAR
        push eax
        push dx

        mov  XmtState, 0

        mov  dx, Nic.CSR6_Address                 ;    Stop the transmit process
        and  Nic.Shadow_CSR6, NOT CSR6_START_TX_COMMAND
        call Nic.WriteCSR6

        pop  dx
        pop  eax
        ret
XmtDisable ENDP

        PAGE
;************
;* XmtReset *
;************
;
; This function initializes the data structures local to MACXMT.ASM.
; It must be called before any other calls are made to the receive module.
;
; Returns: Nothing. All registers preserved.
;
; Algorithm:
; BEGIN
;    return(AX)
; END
;
        ALIGN  4
XmtReset PROC NEAR
        push ax
        push cx
        push si

        call XmtDisable

        mov  si, p_XmtRingVirt          ; Get pointer to base of transmit ring
        mov  cx, XmtNumBuffers          ; Get XmtNumBuffers

xreset_loop:

        mov  [si].XMT_DESCRIPTOR.TDES0, 0 ; Set ownership to Host, clear status

        mov  si, [si].XMT_DESCRIPTOR.p_XmtNext ; SI points to next descriptor
        loop xreset_loop                ; Loop while CX != 0

        mov  ax, p_XmtRingVirt
        mov  XmtCurrentDescriptor, ax   ; Initialize current descriptor

        pop  si
        pop  cx
        pop  ax
        ret
XmtReset ENDP

END_CODE_SEGMENT_RUNTIME

START_CODE_SEGMENT_BIND

        PAGE
;***********
;* XmtInit *
;***********
;
; This function initializes the data structures local to MACXMT.ASM.
; It must be called before any other calls are made to the receive module.
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
        ALIGN  4
XmtInit PROC NEAR
        push bp
        mov  bp,sp
        push edx
        push cx
        push di
        push si
        push eax

        mov  XmtState, 0

        mov  ax, WORD PTR [BP+4]        ; Get Virtual address of Memory Block
        mov  p_XmtBlockVirt, ax
        mov  p_XmtRingVirt, ax
        mov  edx, DWORD PTR [BP+6]      ; Get Physical address of Memory Block
        cmp  edx, 0                     ; If address is zero, just return
        je   xinit_return_bytes_used    ; bytes used, don't init.
        mov  p_XmtBlockPhys, edx
        mov  p_XmtRingPhys, edx
        mov  ax, XmtNumBuffers
        mov  dx, XMT_BUFFER_SIZE
        mul  dx
        movzx edx, ax                   ; EDX = #buffers * size of buffer
        add  p_XmtRingVirt, dx          ; Add total size of receive buffer...
        add  p_XmtRingPhys, edx         ; ...space to get offset of desc ring
;
; At this point the p_XmtBlock and p_XmtRing pointers are initialized.
; Now, initialize the descriptors. Registers are used as follows:
;
; SI points to descriptor being initialized.
; DI points to the descriptor's associated transmit buffer
; EDX is the physical address of the associated transmit buffer
;
        mov  si, p_XmtRingVirt
        mov  di, p_XmtBlockVirt
        mov  edx, p_XmtBlockPhys
        mov  cx, XmtNumBuffers          ; Get XmtNumBuffers
        dec  cx                         ; Initialize NumXmtBuffs-1 descriptors

xinit_loop:

        mov  [si].XMT_DESCRIPTOR.TDES0, 0   ; Set owner to Host, clear status
        mov  [si].XMT_DESCRIPTOR.TDES1, 0   ; clear all TDES1 control bits
        mov  [si].XMT_DESCRIPTOR.TDES2, edx ; Point buffer 1 to edx
        mov  [si].XMT_DESCRIPTOR.TDES3, 0   ; Point buffer 2 to NULL
        mov  [si].XMT_DESCRIPTOR.p_XmtBuffer, di ; virtual address of buffer
        mov  ax, si
        add  ax, SIZE XMT_DESCRIPTOR    ; AX points to next descriptor
        mov  [si].XMT_DESCRIPTOR.p_XmtNext, ax   ; virt address of next descr
        mov  si, ax                     ; SI points to next descriptor
        add  edx, XMT_BUFFER_SIZE       ; EDX holds physical address of next buf
        add  di, XMT_BUFFER_SIZE        ; DI points to next buf
        loop xinit_loop                 ; Loop while CX != 0
;
; Now initialize the last descriptor
;
        mov  [si].XMT_DESCRIPTOR.TDES0, 0    ; Set owner to Host, clear status.
        mov  [si].XMT_DESCRIPTOR.TDES1, TDES1_M_TER ; end of ring
        mov  [si].XMT_DESCRIPTOR.TDES2, edx  ; Point buffer 1 to edx
        mov  [si].XMT_DESCRIPTOR.TDES3, 0    ; Point buffer 2 to NULL
        mov  [si].XMT_DESCRIPTOR.p_XmtBuffer, di ; virtual address of buffer
        mov  ax, p_XmtRingVirt
        mov  [si].XMT_DESCRIPTOR.p_XmtNext, ax   ; point back to start of ring
;
; At this point, the transmit ring of descriptors is initialized, and
; all ownership bits are set to the Host. All is set for transmit DMA
; traffic to be delivered to the adapter once the adapter is enabled.
;
        mov  ax, p_XmtRingVirt
        mov  XmtCurrentDescriptor, ax   ; Initialize current descriptor

xinit_return_bytes_used:
        mov  ax, XmtNumBuffers          ; Get number of Xmt Buffers
        mov  dx, XMT_BUFFER_SIZE
        add  dx, SIZE XMT_DESCRIPTOR
        mul  dx                         ; DX:AX = (BUFFER_SIZE + DESCR_SIZE) *
                                        ;              NUMBER_OF_BUFFERS
                                        ; Note: We discard DX.

        mov  si, ax                     ; Save AX return value, restore eax.
        pop  eax
        mov  ax, si
        pop  si
        pop  di
        pop  cx
        pop  edx
        pop  bp
        ret
XmtInit ENDP

        PAGE
;*************
;* XmtUninit *
;*************
;
; This function uninitializes any local data structures
;
          ALIGN  4
XmtUninit PROC NEAR
        mov XmtState, 0
        ret
XmtUninit ENDP



END_CODE_SEGMENT_BIND
END

