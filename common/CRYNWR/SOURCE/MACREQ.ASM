PAGE    ,132
NAME    MACREQ
TITLE   MACREQ  --  Digital Internal Use Only

;***************************************************************************
;*
;*    Copyright (c) 1993, 1994,1995,1996
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
; This module contains the functions which dispatch NDIS System and General
; requests, as well as the code which implements those requests. In the
; descriptions, PROTMAN refers to the Protocol Manager PROTMAN.EXE. The main
; difference between the System Requests and the General Requests is the
; caller. The Protocol Manager is usually the caller of the System Requests,
; whereas the protocol stacks managed by PROTMAN call the General Requests.
;
; Maintainers:
;   eg          Eric Goldstein
;   mf          Maurene Fritz
;   ymf         Yishai Fraenkel
;   rv          Rivki Vizen
;   de		Dror Efraty
;
; Revision History:
;
; 10-May-1994   eg      Syntax changes for MASM 6.1.
;
; 25-May-1994   eg      Change SetLookahead to do what the procedure header
;                       says that it does.
;
; 30-May-1994   eg      OpenAdapter does not call Rcv/XmtEnable; that is done
;                       at the appropriate time by PortUpdateReceiveFilter.
;
; 12-Jun-1994   eg      Reset changes, in conjunction with others in MACPORT:
;                       1)  Bind calls PortInit after Xmt/RcvInit (as
;                           described in pseudocode).
;                       2)  Remove PortUpdateReceiveFilter call from
;                           SetStationAddress, since the condition for it could
;                           never occur.
;                       3)  Open/CloseAdapter don't
;                           ENABLE/DISABLE_ADAPTER_INTERRUPT; that is done by
;                           the appropriate hardware control routines.
;                       4)  SetPacketFilter calls PortUpdateReceiveFilter,
;                           instead of deciding on its own what to do with the
;                           receive hardware.
;
; 23-Jun-1994   mf
;               1) Report errors if PortUpdateReceiveFilter fails
;               2) AddMulticastAddress checks if adapter is open before
;                  calling PortUpdateReceiveFilter, and reports error if
;                  PortUpdateReceiveFilter fails
;               3) Correct documentation of SetStationAddress (does not
;                  call PortUpdateReceiveFilter)
;
; 11-Jul-1994   mf  Add error condition if InterruptInit fails during
;                   Bind
;
; 18-Aug-1994   ymf  Add Transmit hang code (Initialize timer routine at bind)
;
; 25-Sep-1994   rv   Add ethernet address checksum
;
; 13-Dec-1994   ymf  Add debug messages + switching mechanism
;
; 23-Jan-1995   ymf  Add push and pop flags in entry and exit of dispatch
;                    routines.
;
; 15-Feb-1995   ymf  Enable protocol to set promiscuous mode in SetPacketFilter
;                    call.
;
; 25-Nov-1996	de  Changes in include file names, and in AWK conventions.
;
; This module contains the following functions:
;
; SysReqDispatch - This function dispatches NDIS 'System' requests. The two
;                  supported system requests are Bind and UnBind. All others
;                  are implemented by PROTOCOL drivers, and return failure.
;
; GenReqDispatch - This function dispatches NDIS 'General' requests. This
;                  driver supports a number of these functions. The details
;                  are in the function header.
;
; Bind           - Exchange table information with PROTMAN. Init port interface.
;
; SetStationAddress - Set the network address of the station.
;
; OpenAdapter    - Activate network connection.
;
; CloseAdapter   - Deactivate network connection.
;
; SetPacketFilter - Set packet reception policy.
;
; AddMulticastAddress - Add an m-cast address to the NDIS Multicast Table.
;
; DeleteMulticastAddress - Remove an m-cast address from the Multicast Table.
;
; UpdateStatistics - Cause MAC stats to be updated.
;
; ClearStatistics - Cause MAC stats to be cleared.
;
; SetLookahead - Set length of lookahead information for ReceiveLookahead.
;
; SysReqInvalidFunction - Return INVALID_FUNCTION status to caller
;
; GenReqNotSupported - Return NOT_SUPPORTED status to caller
;

.xlist                                  ; disable listing the include file
include seg_defs.inc
include macro.inc
include dc_regs.inc
include nic.inc
include driver.inc
include ndis.inc
include sss.inc
include macreq.ash
.list                                   ; enable listing

.386

START_DATA_SEGMENT_RUNTIME

SysReqDispatchTable     label WORD
        DW OFFSET SysReqInvalidFunction  ; 0 undefined
        DW OFFSET SysReqInvalidFunction  ; 1 InitiateBind
        DW OFFSET Bind                   ; 2 Bind
        DW OFFSET SysReqInvalidFunction  ; 3 InitiatePrebind
        DW OFFSET SysReqInvalidFunction  ; 4 InitiateUnbind
        DW OFFSET SysReqInvalidFunction  ; 5 Unbind

MAX_SYS_OPCODE equ 5

GenReqDispatchTable  LABEL  WORD
        DW OFFSET GenReqNotSupported     ; 0 undefined
        DW OFFSET GenReqNotSupported     ; 1 InitiateDiagnostics
        DW OFFSET GenReqNotSupported     ; 2 ReadErrorLog
        DW OFFSET SetStationAddress      ; 3 SetStationAddress
        DW OFFSET OpenAdapter            ; 4 OpenAdapter
        DW OFFSET CloseAdapter           ; 5 CloseAdapter
        DW OFFSET GenReqNotSupported     ; 6 ResetMAC
        DW OFFSET SetPacketFilter        ; 7 SetPacketFilter
        DW OFFSET AddMulticastAddress    ; 8 AddMulticastAddress
        DW OFFSET DeleteMulticastAddress ; 9 DeleteMulticastAddress
        DW OFFSET UpdateStatistics       ; 10 UpdateStatistics
        DW OFFSET ClearStatistics        ; 11 ClearStatistics
        DW OFFSET GenReqNotSupported     ; 12 InterruptRequest
        DW OFFSET GenReqNotSupported     ; 13 SetFunctionalAddress
        DW OFFSET SetLookahead           ; 14 SetLookahead

MAX_GEN_OPCODE equ 14

      	even
PendingRequests	REQ_PendingInfo	<>

;====== D E B U G ===================================================
;====================================================================

SetLookCalledFlag       DB FALSE    ; Set to TRUE if SetLookahead has been called

END_DATA_SEGMENT_RUNTIME

START_CODE_SEGMENT_RUNTIME

  if 0
;******************
;* SysReqDispatch *
;******************
;
; This function dispatches NDIS 'System' requests. System requests are issued
; by the Protocol Manager using the FAR entry pointer, to this function, in
; the MAC Common Characteristics Table. This function extracts the OpCode from
; the call stack, and uses it as an index into the SysReqDispatchTable. The
; handler for the request is called, and the return status is passed back to
; the caller.
;
; Calling Stack:
;
;       PUSH DWORD Param1       ; Function specific parameters
;       PUSH DWORD Param2
;       PUSH WORD  Param3
;       PUSH WORD  Opcode       ; Function Op Code
;       PUSH WORD  TargetDS     ; MAC Driver Data Segment
;       CALL System
;
; Algorithm:
; BEGIN
;    Establish stack frame in BP
;    Save current DS, and set DS = TargetDS
;    if (Opcode > MAX_SYS_OPCODE)
;       return (INVALID_FUNCTION)
;    p_routine = SysReqDispatchTable[Opcode]
;    call indirect p_routine
;    restore DS and BP
;    clean up stack frame
;    return AX status from p_routine
; END
;
SysReqDispatch  PROC  FAR
        push bp
        mov  bp, sp
        push ds
        push si
	push di
        push dx
        pushf

        mov  ds, WORD PTR [bp+06]
        mov  ax, WORD PTR [bp+08]

;======= D E B U G ===============================
;====================================================================

        cmp  ax, MAX_SYS_OPCODE
        ja   SysReqBogusOpCode
        shl  ax, 1
        mov  si, ax
        call SysReqDispatchTable[si]
        jmp  SysReqExit
SysReqBogusOpCode:
        mov  ax, MAC_INVALID_FUNCTION
SysReqExit:
        cld
        popf
        pop  dx
	pop  di
        pop  si
        pop  ds
        pop  bp
        ret  14
SysReqDispatch  ENDP
  endif

  if 0
; ******************
; * GenReqDispatch *
; ******************
;
; This function dispatches NDIS 'General' requests. General requests are
; issued to the driver via the FAR entry pointer, to this function, in the
; MAC Upper Dispatch Table. This function extracts the opcode from the
; calling stack, and uses it as an index into the GenReqDispatchTable. The
; selected function handler is called, and the returned status is passed
; up to the caller.
;
; In this driver implementation, the supported General Requests do not
; function in a meanungful way unless the MAC is already bound. This function
; checks to see if the MAC is bound before dispatching the handler. If the
; MAC is not already bound, a GENERAL_FAILURE is retuned.
;
; Calling Stack:
;
;       PUSH WORD  ProtID       ; Module ID of calling protocol, or 0
;       PUSH WORD  ReqHandle    ; Unique handle for this request, or 0
;       PUSH WORD  Param1       ; Function specific parameters
;       PUSH DWORD Param2
;       PUSH WORD  Opcode       ; Function Op Code
;       PUSH WORD  MACDS        ; MAC Driver Data Segment
;       CALL Request
;
; Algorithm:
; BEGIN
;    Establish stack frame in BP
;    Save current DS, and set DS = MACDS
;    if (MAC is not bound)
;       return (GENERAL_FAILURE)
;    if (Opcode > MAX_GEN_OPCODE)
;       return (INVALID_FUNCTION)
;    p_routine = GenReqDispatchTable[Opcode]
;    call indirect p_routine
;    restore DS and BP
;    clean up stack frame
;    return AX status from p_routine
; END
;
GenReqDispatch  PROC  FAR
        push bp
        mov  bp, sp                        ;    Establish stack frame in BP
        push ds                            ;    Save current DS...
        push si
	push di
        push dx
        pushf

        mov  ds, WORD PTR [bp+06]          ;    ...and set DS = MACDS
        test NDISServiceStatus.sss_macstat._loword, SSS_BOUND
        jnz  GenReqCheckOpCode             ;    if (MAC is not bound)
        mov  ax, MAC_GENERAL_FAILURE       ;       return (GENERAL_FAILURE)
        jmp  GenReqExit
GenReqCheckOpCode:
        mov  ax, WORD PTR [bp+08]

;======== D E B U G =================================================
;====================================================================

        cmp  ax, MAX_GEN_OPCODE            ;    if (Opcode > MAX_GEN_OPCODE)
        ja   GenReqBogusOpCode             ;       return (INVALID_FUNCTION)
        shl  ax, 1                         ;    Get pointer to routine
        mov  si, ax
        call GenReqDispatchTable[si]       ;    call routine indirect
        jmp  GenReqExit
GenReqBogusOpCode:
        mov  ax, MAC_INVALID_FUNCTION
GenReqExit:
        cld
        popf                              ; NDIS says return dir flag clear
        pop  dx
	pop  di
        pop  si
        pop  ds
        pop  bp
        ret  14
GenReqDispatch  ENDP
  endif

END_CODE_SEGMENT_RUNTIME

START_CODE_SEGMENT_BIND

; ********
; * Bind *
; ********
;
; This function services the System Request 'Bind'. The protocol manager passes
; Bind a FAR pointer to its common characteristics table, and pointer to a
; location where this function places a FAR pointer to our common
; characteristics table. The adapter hardware is initialized in this function.
; According to the NDIS 2.01 spec, the driver may NOT manipulate the adapter
; hardware at INIT time in order to maintain compatibility with remote
; initial program load.
;
; ....
;
; Finally, at this point, the driver copies the protocol's lower dispatch
; table, and returns to the protocol, a pointer to our common characteristics
; table.
;
; Stack Frame (relative to BP)
;
; BP+16 LPBUF CharTab  ; Pointer to caller's table
; BP+12 LPBUF TabAddr  ; Pointer to DWORD to hold FAR pointer to our Table
; BP+10 WORD  0        ; Unused
; BP+08 WORD  2        ; OpCode for Bind Request
; BP+06 WORD  TargetDS ; Our Data Segment
;
; Algorithm:
; BEGIN
;    if (MAC not OPERATIONAL in service specific status table)
;       return(DRIVER_NOT_INITIALIZED)
;    if (MAC BOUND in service specific status table)
;       return(INVALID_FUNCTION)
;    Get IPL from MAC Service Specific Characteristics Table
;    Call InterruptInit
;    if (InterruptInit failed)    ** can occur only under OS/2 **
;       return(MAC_INTERRUPT_CONFLICT)
;    Call TxHangInit
;    if (TxHangInit failed)    ** can occur only under OS/2 **
;       return(MAC_INITIALIZATION_FAILED)
;    Call XmtInit
;    Call RcvInit
;    if (PortInit failed)
;       return(MAC_INITIALIZATION_FAILED)
;    Call NDISMulticastTableInit
;    Set MAC Bound and HW operational bits in MAC Status field in MAC -
;    Service Specific State Table
;    Exchange Tables
;    return(SUCCESS)
; END
;
;
      ALIGN 4
Bind  PROC  NEAR
	push bx
        push di
        push si
        pushf

        cli

        test NDISServiceStatus.sss_macstat._loword, SSS_OPERATIONAL
        jnz bind_operational                  ; Check MAC Status
        mov ax, MAC_DRIVER_NOT_INITIALIZED    ; If HW not operational EXIT
        jmp bind_exit                         ; this means dev_init failed

bind_operational:
        test NDISServiceStatus.sss_macstat._loword, SSS_BOUND
        jz  bind_not_yet_bound                ; Check MAC status again
        mov ax, MAC_INVALID_FUNCTION          ; If we're already bound, don't
        jmp bind_exit                         ; allow another call

bind_not_yet_bound:
	mov Nic.DriverMode, BIND_TIME	      ; move to bind-time

	DISABLE_ADAPTER_INTERRUPT
        mov bx, NDISServiceSpecificChar.ssc_interrupt
        call BindInterrupts                    ; Hook the adapter hw interrupt

IF OS EQ OS2
        jnc  bind_int_ok                      ; jump if everything is OK
        mov  ax, MAC_INTERRUPT_CONFLICT        ; report error to caller
        jmp  bind_exit                         ; (can happen only in OS/2)
;
ENDIF
;
bind_int_ok:
IF OS EQ OS2
        cmp     ax, 1
        jne     bind_txhang_ok
        mov     ax, MAC_INITIALIZATION_FAILED     ; report error to caller
        jmp     bind_exit                         ; (can happen only in OS/2)
ENDIF

bind_txhang_ok:
        push   p_PhysBlockPhys      ; Call XmtInit
        push   p_PhysBlockVirt
        call   XmtInit
        add    sp, 6
        add    p_PhysBlockVirt, AX  ; Adjust the virtual and physical block
        and    eax, 0FFFFh          ; pointers based on the number of bytes
        add    p_PhysBlockPhys, EAX ; used

        push   p_PhysBlockPhys      ; Call RcvInit
        push   p_PhysBlockVirt
        call   RcvInit
        add    sp, 6

        call PortInit                         ; Init adapter port interface
	jnc  bind_PortInit_ok
        mov     ax, MAC_INITIALIZATION_FAILED     ; report error to caller
        jmp     bind_exit                         ;

bind_PortInit_ok:
        call NDISMulticastTableInit           ; clean out the NDISMulticastTable

        or  NDISServiceStatus.sss_macstat._loword, SSS_BOUND ;    Set MAC Bound
;
; At this point, all of the things that must happen, for Bind to succeed,
; have completed successfully. Now, return a pointer to our common
; characteristics table to the protocol, and copy the protocol's dispatch
; table.
;
  if 0
        les di, [bp+12]                       ; Point ES:DI to the buf where
        mov es:[di].LONG_PTR._seg, ds         ; we return our pointer
        mov es:[di].LONG_PTR._off, OFFSET NDISCommonChar

        mov  ax, ds ; Set ES = DS
        mov  es, ax

        push ds                               ; Save OUR data segment

        lds si, [bp+16]     ; Point DS:SI to the Protocol's common char's table
        mov bx, ds:[si].com_char.cc_dataseg   ; Grab Protcol's data segment
        lds si, ds:[si].com_char.cc_lowerdisp ; Point DS:SI to the Prot's lower disp tbl

        mov di, OFFSET NDISProtLowerDispatch  ; Point ES:DI to OUR copy of
                                              ; prtocol lower dispatch table

        mov cx, 16                            ; Copy 16 words DS:SI->ES:DI
        rep movsw

        pop ds                                ; Restore OUR data segment

        mov ProtDS, bx                        ; Save the Protocol's DS
                                              ; for future reference
  endif
        mov ax, MAC_SUCCESS                   ; return(SUCCESS)

	mov Nic.DriverMode, RUN_TIME	; move from bind-time to run-time
bind_exit:
        popf
        pop si
        pop di
	pop bx
        ret

Bind            ENDP

END_CODE_SEGMENT_BIND

START_CODE_SEGMENT_RUNTIME

; *********************
; * SetStationAddress *
; *********************
;
; Set the network address of the station. This function allows a protocol
; to set the functional address of the MAC. According to the NDIS 2.01 spec,
; BARF!  We are not NDIS!
;
;    update Current Address in MAC Service Specific Characteristics Table
;    Update
;    return(SUCCESS)
; END
;
SetStationAddress PROC  NEAR
        mov  ax, ds                         ; ES = DS
        mov  es, ax
        mov  di, OFFSET NDISServiceSpecificChar.ssc_curraddr
        movsw                               ; Copy MLA at DS:SI to current
        movsw                               ; address at ES:DI
        movsw

        call PortUpdateReceiveFilter
        jc   ssa_error
        mov ax, MAC_SUCCESS
        jmp ssa_exit
ssa_error:
        mov ax, MAC_GENERAL_FAILURE
ssa_exit:
        ret
SetStationAddress ENDP

; ***************
; * OpenAdapter *
; ***************
;
; This function activates the adapter hardware, allowing it to begin
; transmitting and receiving frames.
;
; Upon successfully resetting and enabling the transmit and receive paths,
; this function updates the MAC Open bit in the MAC Service Specific Status
; table.
;
; In order for OpenAdapter to work properly, the MAC must be BOUND, and not
; already OPEN. The MAC bound bit is checked in GenReqDispatch before this
; function is called.
;
; Any failure, i.e. failed AIM call or invalid MAC state on entry, returns
; a GENERAL_FAILURE.
;
; Stack Frame (relative to BP)
;
; BP+18 WORD  ProtID     ; Module ID of calling protocol
; BP+16 WORD  ReqHandle  ; Unique request handle or 0
; BP+14 WORD  ?          ; Defined by spec, but unused by this driver
; BP+10 LPBUF ?          ; Defined by spec, but unused by this driver
; BP+08 WORD  4          ; OpenAdapter OpCode
; BP+06 WORD  MACDS      ; Our Data Segment
;
; Algorithm:
; BEGIN
;    if (inside the isr)
;       if (a close request wasn't queued)
;          return(INAVLID_FUNCTION)
;       else {
;          if (the request handle wasn't 0)
;             issue a Request Confirmation for the queued CloseAdapter
;          save request handle, and protocol ID
;          mark that open needs to be done, and unmark close.
;          return (REQUEST_QUEUED)
;       }
;    if (MAC is open)
;       return(GENERAL_FAILURE)
;    Set MAC Open bit in MAC Service Specific Status Table
;    Enable interrupts at the PIC
;    return(SUCCESS)
; END
;
OpenAdapter  PROC  NEAR
	pushf
	cli		; disable interrupts

	test 	NDISServiceStatus.sss_macstat._loword, SSS_OPEN
	jz  open_ok
        mov  ax, MAC_INVALID_FUNCTION         ; If MAC opened, flag error
        jmp  open_exit
open_ok:

        or  	NDISServiceStatus.sss_macstat._loword, SSS_OPEN ; Set MAC Open bit
        mov    	Nic.Shadow_CSR7_Mask, 0FFFFFFFFh

	cmp  InterruptSemaphore, 0
	je   open_not_in_isr

	or   PendingRequests.ReqFlags, OPEN_REQUESTED
	and  PendingRequests.ReqFlags, NOT CLOSE_REQUESTED
	mov  ax, MAC_SUCCESS
	jmp  open_exit

open_not_in_isr:
        call PortUpdateReceiveFilter
        jc   open_error                       ; setup of receive filter failed

        SET_ADAPTER_INTERRUPT

        mov ax, MAC_SUCCESS
        jmp open_exit
open_error:
        mov ax, MAC_GENERAL_FAILURE
open_exit:
	popf
        ret

OpenAdapter  ENDP

; ****************
; * CloseAdapter *
; ****************
;
; This function has the effect of disabling the transmit and receive paths.
; The specific effects of this function are:
;
; 1) The MAC is set to CLOSED state in the NDISServiceStatus table
; 2) Adapter interrupts are disabled
; 3) The Port object is reset
; 4) The Receive object is reset
; 5) The Transmit object is reset
; 6) The NDISMusticastTable is reset, but any alternate station address set
;    is preserved.
;
; Stack Frame (relative to BP)
;
; BP+18 WORD  ProtID     ; Module ID of calling protocol
; BP+16 WORD  ReqHandle  ; Unique request handle or 0
; BP+14 WORD  0          ; Unused MBZ
; BP+10 LPBUF 0          ; Unused MBZ
; BP+08 WORD  5          ; CloseAdapter OpCode
; BP+06 WORD  MACDS      ; Our Data Segment
; BP-02 WORD  ProtDS     ; Protocol Data Segment
;
; Algorithm:
; BEGIN
;    if (inside the isr)
;       if (a close request is already queued)
;          return(INAVLID_FUNCTION)
;       else {
;          Init NDIS MulticastTable
;          if ((an open request is queued) and (its request handle wasn't 0))
;             issue a Request Confirmation for the queued OpenAdapter
;          save request handle, protocol ID
;          mark that close needs to be done, and unmark open.
;          return (REQUEST_QUEUED)
;       }
;    if (MAC is closed)
;       return(INAVLID_FUNCTION)
;    call SoftwareResetDevice
;    clear NDISMulticastTable
;    update NDISServiceSpecificChar table
;    return(SUCCESS)
; END
;
CloseAdapter  PROC  NEAR

	pushf
	cli	  ; disable interrupts

	test NDISServiceStatus.sss_macstat._loword, SSS_OPEN
        jnz  close_ok
        mov  ax, MAC_INVALID_FUNCTION         ; If MAC closed, flag error
        jmp  close_exit
close_ok:
        and  NDISServiceStatus.sss_macstat._loword, NOT SSS_OPEN
                                              ; Set Closed in MAC status table
	mov  Nic.Shadow_CSR7_Mask, 0
        call NDISMulticastTableInit           ; Clean out MCastTable

	cmp  InterruptSemaphore, 0
	je   close_not_in_isr

	or   PendingRequests.ReqFlags, CLOSE_REQUESTED
	and  PendingRequests.ReqFlags, NOT OPEN_REQUESTED

	jmp  close_success

close_not_in_isr:
	call	PortReset		;(MOTIH)
        call 	SoftwareResetDevice	;(MOTIH)
	mov     TulipIntPosted, 1	;(MOTIH) - Possible pending int.

close_success:
        mov  ax, MAC_SUCCESS
close_exit:
	popf
        ret

CloseAdapter  ENDP

; *******************
; * SetPacketFilter *
; *******************
;
; This function accepts a bitmask which indicates the type of frames the
; protocol stack wishes to receive.  This driver doesn't care what the
; protocol stack does and does not want to receive.  The protocol stack is
; gonna get what's good for it.  That is: All directed frames, All Broadcast
; frames, and All Multicast frames which match a CAM entry.
;
; NOTE: According to the NDIS 2.01 specification, this function must work
;       when the adapter is closed.
;
; Algorithm:
; BEGIN
;    Get FileterMask from stack frame
;    if (filter mask is not within bounds)
;       return MAC_INVALID_PARAMETER
;    Update Current Packet Filter in MAC Service Specific Status Table
;    if (MAC is OPEN)
;       call PortUpdateReceiveFilter to set receive process accordingly
;    return(SUCCESS)
; END

SetPacketFilter  PROC  NEAR
        test ax, NOT 7                        ;   Ensure bits 4-15 of filter
        jz   spf_filter_arg_ok                ;   are 0 as required by spec,
                                              ;   and that bit 3 is not set,
                                              ;   since we don't support
                                              ;   source routing.

        mov ax, MAC_INVALID_PARAMETER
        jmp SHORT spf_exit

spf_filter_arg_ok:
        cmp  ax, NDISServiceStatus.sss_filter  ;   If filter wasn't changed
	je   spf_success			      ;   Return success

        mov  NDISServiceStatus.sss_filter, ax  ;   Update Filter
        test NDISServiceStatus.sss_macstat._loword, SSS_OPEN
        jz   spf_success                      ; If MAC is closed bag out

	cmp  InterruptSemaphore, 0
	je   spf_update_filter

	or   PendingRequests.ReqFlags, MULTICAST_CHANGED
	jmp  spf_success

spf_update_filter:
	call PortUpdateReceiveFilter          ; Otherwise, update HW filter
	jnc  spf_success                      ; did it succeed?
        mov  ax, MAC_GENERAL_FAILURE           ; no, report failure
        jmp  spf_exit

spf_success:
        mov ax, MAC_SUCCESS                   ;    return(SUCCESS)
spf_exit:
        ret
SetPacketFilter  ENDP

; ***********************
; * AddMulticastAddress *
; ***********************
;
; This function attempts to add a multicast address to the Adapter CAM. The
; adapter automatically performs destination address filtering based on the
; contents of the CAM, so it is not necessary for the driver to do any such
; filtering. The driver does maintain a table of multicast addresses, in
; order to check for duplicate addresses, and to clean up the adapter CAM
; in the CloseAdapter function.
;
; The caller supplies a pointer to the multicast address to be added. The
; address is assumed to be in canonnical format. There are a number of reasons
; that an address may be rejected. They are:
;
; 1) Address is not multicast. For an address to be considered multicast,
;    the least significant bit of the most significant address byte must be
;    one. i.e. the first byte of the address must be an odd number. If the
;    address is not multicast, an INVALID_PARAMETER error is returned.
;
; 2) No more room in multicast table. The driver allows for up to 16 mcast
;    addresses in its table. If the table is already full, an OUT_OF_RESOURCE
;    error is returned.
;
; 3) NDIS 2.01 does NOT allow for multiple instances of the same address in
;    the multicast table. If the address to be added already exists in the
;    multicast table, an INVALID_PARAMETER error is returned.
;
; If the address is found to be a valid candidate, it is added to the NDIS
; MCastTable, and the current number of entries is updated. Next,
; PortUpdateReceiveFilter is called to inform the adapter of the new entry.
;
; Note: The return code INVALID_FUNCTION, for when the table is full, makes no
;       sense. OUT_OF_RESOURCE makes a lot more sense, but the NDIS conformance
;       tests look for INVALID_FUNCTION explicitly, and flunk you if you
;       return otherwise when they deliberately overflow the table.
;
; Stack Frame (relative to BP)
;
; BP+18 WORD  ProtID     ; Module ID of calling protocol
; BP+16 WORD  ReqHandle  ; Unique request handle or 0
; BP+14 WORD  0          ; Unused MBZ
; BP+10 LPBUF MultiAddr  ; FAR pointer to buffer containing address to be added
; BP+08 WORD  8          ; AddMulticastAddress OpCode
; BP+06 WORD  MACDS      ; Our Data Segment
;
; Algorithm:
; BEGIN
;    Get pointer to address from stack frame
;    if (address in not mcast)
;       return (INVALID_PARAMETER)
;    Get pointer to MCast Table
;    Get current number of entries
;    if (driver mcast table is full)
;       return (INVALID_FUNCTION)
;    if (address is already in driver mcast table)
;       return (INVALID_PARAMETER)
;    Convert current number of entries into pointer to next free entry
;    Stuff address into the MCast table
;    Update current number of entries
;    If (adapter is open)
;       Call PortUpdateReceiveFilter
;    return (SUCCESS)
; END
;
AddMulticastAddress PROC  NEAR
        push si
        push di
        pushf
	cli			; to avoid interrupt during address addition

        les  si, [bp+10]                ; Get pointer to address in ES:SI
        mov  al, BYTE PTR es:[si]       ; Get first byte of address
        and  al, 01h                    ; Check least significant bit
        jne  ama_ok_mcast               ; If it's set, the address is mcast
        mov  ax, MAC_INVALID_PARAMETER  ; else it's unicast, and bogus
        jmp  ama_exit
ama_ok_mcast:
        mov  di, OFFSET NDISMulticastTable
        mov  ax, NDISMulticastTable.ssc_maxnum  ; Compare max entries with...
        cmp  ax, NDISMulticastTable.ssc_current ; ...current number of entries
        jg   ama_vacancy                ; If there's room, carry on
        mov  ax, MAC_INVALID_FUNCTION   ; else indicate no room at the inn
        jmp  ama_exit
ama_vacancy:
        call NDISMulticastTableSearch          ; Search for address pointed to by ES:SI
        cmp  ax, -1                     ; If if ain't in there, continue
        je   ama_not_found
        mov  ax, MAC_INVALID_PARAMETER  ; else bag out, no dup addresses allowed
        jmp  ama_exit
ama_not_found:
        mov  ax, NDISMulticastTable.ssc_current ; Convert current # of entries
        shl  ax, 4                      ; in the table to an offset to the next
        add  ax, 4                      ; free slot.
        add  di, ax

        mov  ax, ds
        mov  es, ax                     ; ES = DS

        push ds                         ; Save our DS

        lds  si, [bp+10]                ; Get address to add in DS:SI

;
; At this point DS:SI points to the address to add, and ES:DI points to the
; free slot in the table.
;
        cld
        movsw                           ; Stuff the address into the table
        movsw
        movsw

        pop  ds                         ; Restore our data segment

        inc  NDISMulticastTable.ssc_current ; Update current number of entries
;
; If the adapter is open, give it the new info
;
        test NDISServiceStatus.sss_macstat._loword, SSS_OPEN
        jz   ama_success                      ; If MAC is closed bag out

	cmp  InterruptSemaphore, 0
	je   ama_update_filter

	or   PendingRequests.ReqFlags, MULTICAST_CHANGED
	jmp  ama_success

ama_update_filter:

        call PortUpdateReceivefilter         ; clue the adapter in on all this
        jnc  ama_success                     ; did it succeed?
        mov  ax, MAC_GENERAL_FAILURE         ; no, report it
        jmp  ama_exit

ama_success:
        mov  ax, MAC_SUCCESS
ama_exit:
        popf
        pop  di
        pop  si
        ret
AddMulticastAddress ENDP

; **************************
; * DeleteMulticastAddress *
; **************************
;
; This function attemps to remove an address from the adapter CAM. The caller
; supplies a pointer to the address to be removed. If the address is not found
; in the driver multicast address table, an INVALID_PARAMETER error is
; returned. If the address is found, the address is removed from the NDIS
; MCastTable, PortUpdateReceiveFilter is called, and SUCCESS is returned.
;
; Since NDIS does not require that the table be kept ordered, the delete works
; as follows: The address to delete is located in the table. The last valid
; address in the table is copied into the slot occupied by the address to be
; deleted, and the last address in the table is then zeroed out. The current
; count is then decremented.
;
; Stack Frame (relative to BP)
;
; BP+18 WORD  ProtID     ; Module ID of calling protocol
; BP+16 WORD  ReqHandle  ; Unique request handle or 0
; BP+14 WORD  0          ; Unused MBZ
; BP+10 LPBUF MultiAddr  ; FAR pointer to buffer containing address to be added
; BP+08 WORD  8          ; AddMulticastAddress OpCode
; BP+06 WORD  MACDS      ; Our Data Segment
;
; Algorithm:
; BEGIN
;    Get pointer to address from stack frame
;    if (address is not in driver mcast table)
;       return (INVALID_PARAMETER)
;    Remove address from driver mcast table
;    if (adapter is open)
;        call PortUpdateReceiveFilter
;        if (failure) return(GENERAL_FAILURE)
;    return (SUCCESS)
; END
;
DeleteMulticastAddress PROC  NEAR
        push si
        push di
        pushf
	cli			; to avoid interrupts during address table change

        les si,[bp+10]
        call NDISMulticastTableSearch
        cmp ax, -1
        jne SHORT dmcast_found_it
        mov ax, MAC_INVALID_PARAMETER
        jmp dmcast_exit
dmcast_found_it:        	; Here AX is the addresses' entry number.
        shl ax, 4		; Convert it into an offset into the MCastTable
				; by multiplying by 16.
        mov di, OFFSET NDISMulticastTable.ssc_multiaddr
        add di, ax             ; DI points to the address to delete
        mov si, OFFSET NDISMulticastTable
        mov ax, [si].ssc_multi.ssc_current
        sub ax, 1              ; AX is now the number of the last entry
        shl ax, 4              ; Convert it into an offset into the MCastTable
        add ax, 4
        add si, ax             ; SI points to the last address in the table

        mov  ax, ds
        mov  es, ax            ; Make ES=DS
        cld                    ; And clear that pesky direction flag

;
; At this point DS:SI points to the LAST entry in the table, and ES:DI
; points to the entry to delete. Copy the last address on top of the address
; to delete.
;
        mov cx, 8
        rep movsw
        sub si, 16             ; Adjust SI to point to last entry again
        mov di, si             ; Make DI point there also.
;
; At this point, DS:DI points to the last entry in the MCast table. Zero it.
;
dmcast_clear_last:
        mov ax, 0
        mov cx, 8
        rep stosw
;
; Decrement Current Count
;
        dec NDISMulticastTable.ssc_current
;
; if adapter is open call PortUpdateReceiveFilter
;
        test NDISServiceStatus.sss_macstat._loword, SSS_OPEN
        jz   dmcast_success                      ; If MAC is closed bag out

	cmp  InterruptSemaphore, 0
	je   dmcast_update_filter

	or   PendingRequests.ReqFlags, MULTICAST_CHANGED
	jmp  dmcast_success

dmcast_update_filter:

        call PortUpdateReceivefilter
        jnc  dmcast_success                     ; if success, we're done
        mov  ax, MAC_GENERAL_FAILURE            ; otherwise, report failure
        jmp  dmcast_exit

dmcast_success:
        mov ax, MAC_SUCCESS
dmcast_exit:
        popf
        pop  di
        pop  si
        ret
DeleteMulticastAddress ENDP

; ********************
; * UpdateStatistics *
; ********************
;
; Cause MAC stats to be updated. The MAC statistics are always current in
; this driver, so NDIS 2.01 requires this function to return SUCCESS.
;
; Algorithm:
; BEGIN
;    return (SUCCESS)
; END
;
UpdateStatistics PROC  NEAR
        mov ax,MAC_SUCCESS
        ret
UpdateStatistics ENDP

; *******************
; * ClearStatistics *
; *******************
;
; Cause MAC stats to be cleared. This function causes the SUPPORTED statistics
; in the MAC Service Specific Status table to be zeroed. The supported
; statistics are the three statistics which are required by NDIS 2.10 to be
; supported. 1) Total Frames Received OK, 2) Total Frames with CRC error, 3)
; Total Frames Transmitted OK. This function zeroes these values. NDIS 2.10
; requires that this be an atomic operation, so system interrupts are briefly
; disabled to preserve atomicity. This function always returns SUCCESS.
;
; Algorithm:
; BEGIN
;    Save current state of CPU interrupt flag
;    Disable system interrupts
;    zero supported statistics
;    Restore state of CPU interrupt flag
;    return (SUCCESS)
; END
;

ClearStatistics  PROC  NEAR
        pushf
        cli
        mov NDISServiceStatus.sss_frames_rx,  0
        mov NDISServiceStatus.sss_crc_err,    0
        mov NDISServiceStatus.sss_bytes_rx,   0
        mov NDISServiceStatus.sss_multi_rx,   0
        mov NDISServiceStatus.sss_broad_rx,   0
        mov NDISServiceStatus.sss_hard_err,   0
        mov NDISServiceStatus.sss_frames_tx,  0
        mov NDISServiceStatus.sss_bytes_tx,   0
        mov NDISServiceStatus.sss_multi_tx,   0
        mov NDISServiceStatus.sss_broad_tx,   0
        mov NDISServiceStatus.sss_no_trans,   0
        mov NDISServiceStatus.sss_hard_tx,    0
	mov NDISMediaSpecificStatus.mss_deferred,  0
	mov NDISMediaSpecificStatus.mss_max_coll,  0
	mov NDISMediaSpecificStatus.mss_late_coll, 0
	mov NDISMediaSpecificStatus.mss_N_coll,    0
	mov NDISMediaSpecificStatus.mss_carrier,   0
        mov ax,MAC_SUCCESS
        popf
        ret

ClearStatistics ENDP

; ****************
; * SetLookahead *
; ****************
;
; This function allows the calling protocol to change the number of bytes
; of lookahead information. The NDIS 2.01 spec gets a little wierd in
; defining how this function should operate, so here's my best guess at
; interpreting the spec, as it pertains to this MAC driver. Reading the
; spec yourself would definately aid in the understanding of this operation.
;
; The receive lookahead value determines the MINUMUM length, in bytes, of
; lookahead information to be returned in a ReceiveLookahead indication. MAC
; drivers initialize to a default value of 64.
;
; The FIRST time SetLookahead is called (and ONLY the FIRST time) the lookahead
; value MAY be lowered. In all SUBSEQUENT calls, the lookahead value is changed
; ONLY if a LARGER value is specified.
;
; The MAXIMUM lookahead value is 256.
;
; Okay, so far, so good. This function implements the prohibitions on
; decreasing the lookahead value ONLY on the first call. This function returns
; SUCCESS for all calls, if the lookahead value requested is less than the
; specified maximum of 256. The ONLY error that is ever returned from this
; function is due to requesting a lookahead length greater than 256.
;
; Note that a return code of SUCCESS does NOT mean that the function call
; changed the lookahead value. According to the NDIS 2.01 spec this is cool.
;
; This MAC driver ALWAYS returns the ENTIRE packet in the lookahead data. So,
; the length of the frames always euqals the lookahead bytes available.
;
; NOTE: According to the NDIS 2.01 specification, this function must work
;       when the adapter is closed.
;
; Stack Frame (relative to BP)
;
; BP+18 WORD  ProtID     ; Module ID of calling protocol
; BP+16 WORD  ReqHandle  ; Unique request handle or 0
; BP+14 WORD  Length     ; Minimum length of lookahead information
; BP+10 LPBUF 0          ; Unused MBZ
; BP+08 WORD  14         ; SetLookahead OpCode
; BP+06 WORD  MACDS      ; Our Data Segment
;
; Algorithm:
; BEGIN
;    Get Length from call frame
;    if (Length > 256)
;       return (INVALID_PARAMETER)
;    else
;       {
;       if (SetLookaheadCalled flag is clear)
;             OR (Length > current lookahead length)
;          current lookahead length = Length
;       set SetLookaheadCalled flag
;       return (SUCCESS)
;       }
; END
;
SetLookahead  PROC  NEAR
        mov  ax, [BP+14]
        cmp  ax, 256
        jbe  SHORT SetLookLengthOk
        mov  ax, MAC_INVALID_PARAMETER
        jmp  SHORT SetLookExit
SetLookLengthOk:
        cmp  SetLookCalledFlag, TRUE
        jne  SetLookFlagSet
        cmp  ax, RcvCurrentLookahead
        jbe  SetLookSuccess			;(MOTIH - jle to jbe)
SetLookFlagSet:
        mov  RcvCurrentLookahead, ax
        mov  SetLookCalledFlag, TRUE
SetLookSuccess:
        mov  ax, MAC_SUCCESS
SetLookExit:
        ret


SetLookahead    ENDP

; *************************
; * SysReqInvalidFunction *
; *************************
;
; Return INVALID_FUNCTION status to caller. This function is called when an
; unsupported System Request is made. It simply returns INVALID_FUNCTION
; status to the caller.
;
; Algorithm:
; BEGIN
;    return (INVALID_FUNCTION)
; END
;
SysReqInvalidFunction PROC  NEAR
        mov ax, MAC_INVALID_FUNCTION
        ret
SysReqInvalidFunction ENDP

; **********************
; * GenReqNotSupported *
; **********************
;
; Return NOT_SUPPORTED status to caller. This function is called when an
; unsupported General Request is made. It simply returns NOT_SUPPORTED status
; to the caller.
;
; Algorithm:
; BEGIN
;    return (NOT_SUPPORTED)
; END
GenReqNotSupported PROC  NEAR
        mov ax, MAC_NOT_SUPPORTED
        ret
GenReqNotSupported ENDP

END_CODE_SEGMENT_RUNTIME

START_CODE_SEGMENT_BIND

        PAGE
;**************************
;* NDISMulticastTableInit *
;**************************
;
; This function clears out the NDIS MCast table. It is called only during
; BIND time, to initialize the table, and at CLOSE time, as required by the
; NDIS spec. The data segment is valid on entry.
;
; Returns: NONE.
;
; Algorithm:
; BEGIN
;    set current number of multicast entries to 0
;    for (i=1 to max number of mlticast entries)
;       zero entry [i]
;    for (i=1 to (number of bits in table / 16))
;       zero word [i]
; END
;
NDISMulticastTableInit  PROC  NEAR
        push di
        pushf

        mov  ax, ds                            ; Set ES = DS
        mov  es, ax
        mov  di, OFFSET NDISMulticastTable     ; ES:DI points to the MCast Table
        cld                                    ; Clear Direction Flag
        mov  NDISMulticastTable.ssc_current, 0 ; Zero current # of addresses
        mov  cx, NDISMulticastTable.ssc_maxnum
        shl  cx, 3                             ; CX=CX*8 to make it a word count
        add  di, 4                             ; Point DI to start of addresses
        mov  ax, 0                             ; Load AX with 0 to zero array
        rep  stosw                             ; zero the array

        popf
        pop  di
        ret
NDISMulticastTableInit  ENDP

END_CODE_SEGMENT_BIND

START_CODE_SEGMENT_RUNTIME

        PAGE
;****************************
;* NDISMulticastTableSearch *
;****************************
;
; This function searches the NDIS MCast Table for the given address. If
; the address is found, the entry number is is returned, else -1 is returned.
; Since the NDIS MCast Table is usually small (16 entries max), and address
; table operations are not time critical, a linear search is used. Bogus, I
; know, but hey, it's small on code size, and speed just don't matter
; at this point in the driver code.
;
; Arguments:
;    ES:SI points to the address you're searching for.
;
; Assumptions:
;    DS on entry is driver's DS.
;
; Returns:
;    Status in AX (Entry Number or -1=Failure)
;    The entry number that AX returns starts counting at Entry Number 0.
;
; Algorithm:
; BEGIN
;    CX = number of entries in NDIS MCast Table
;    if (CX == 0)
;       return(-1) Not Found
;    Point DI to the first entry in the NDIS MCast Table
;    do
;    {
;       if (WORD at ES:[SI].0 == DWORD at DS:[DI].0)
;         if (WORD at ES:[SI].2 == DWORD at DS:[DI].2)
;           if (WORD at ES:[SI].4 == WORD at DS:[DI].4)
;              return(0); Found it
;       DI += 16
;    }
;    while (--CX != 0)
;    return(-1) NotFound
; END
;
NDISMulticastTableSearch  PROC  NEAR
        push di

        mov  cx, NDISMulticastTable.ssc_current
        cmp  cx, 0
        je   SHORT snm_not_found_exit
        mov  di, OFFSET NDISMulticastTable + 4
        mov  ax, 0
;
; ES:SI points to the address you're searching for
; DS:DI points to the entries in the NDISMulticastTable
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
        pop  di
        ret
NDISMulticastTableSearch  ENDP


;****************************
;  ReqHandlePendingRequests *
;****************************
; This routine handles general requests that are pending
; because they were issued inside the ISR
; Those requests are:
; 1. Changes in the multicast table/ station adderss - needs device reset
; 2. CloseAdapter - Reset chip, mask interrupts, confirm request.
; 3. OpenAdapter - Reset device, enable interrupts, confirm request.
;
; Assumption: Interrupts disabled
ReqHandlePendingRequests PROC
	test PendingRequests.ReqFlags, CLOSE_REQUESTED
	jz   rhpr_dont_close

	call	PortReset		
	jmp  rhpr_exit

rhpr_dont_close:	; if not requested to close
	test PendingRequests.ReqFlags, OPEN_REQUESTED OR MULTICAST_CHANGED
	jz   rhpr_exit

        call PortUpdateReceiveFilter         ; Reset the device

rhpr_exit:
	mov  PendingRequests.ReqFlags, 0
	ret				
ReqHandlePendingRequests ENDP

END_CODE_SEGMENT_RUNTIME
END
