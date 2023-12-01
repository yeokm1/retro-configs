PAGE    ,132
NAME    MACPORT
TITLE   MACPORT  --  Digital Internal Use Only
;***************************************************************************
;*
;*    Copyright (c) 1994
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
; This file contains all of the routines which manage the DC21040/DC21140
; adapter as a logical port. The port may be thought of as a grouping of the
; transmit and receive objects, along with the other functions and data which
; control the configuration and operation of the asdapter hardware.
;
; Maintainers:
;       eg      Eric Goldstein
;       mf      Maurene Fritz
;       rv      Rivki Vizen
;       ymf     Yishai Fraenkel
;       as      Adi    Shaliv
;	de	Dror Efraty
;
; Revision History:
;
; 10-May-1994   eg      Change PortConfigCSR13 (SIA mode) default to TP.
;
; 11-May-1994   eg      Syntax changes for MASM 6.1.
;
; 23-May-1994   eg      Moved PortConfigRegRead to MACINIT.ASM, renaming it to
;                       InitConfigRegRead and making it local.  This driver
;                       supports PCI BIOS calls under OS/2 only at init time!
;
; 25-May-1994   eg      Fix PCI Ethernet ROM read:  Check data validity.
;
; 31-May-1994   eg      PortCSR6Write waits for TP Link Test, so that packet
;                       transmission doesn't start too soon.
;
;  6-Jun-1994   eg      PortReset initializes CSR6, using new PortConfigCSR6.
;
;  6-Jun-1994   eg      Replace autoconfiguring PortConfigCSR13 with
;                       PortConfigSIA and associated per-mode structures for
;                       programming all 3 SIA registers.  PortCSR6Write and
;                       PortReset configure the SIA in that way.
;                       PortGetPCI/EISAConfig don't touch the SIA at all,
;                       since it isn't necessary.
;
; 12-Jun-1994   eg      HW reset changes, in conjunction with others in MACREQ:
;                       1)  PortUpdateReceiveFilter doesn't start receive
;                           process if packet filter indicates "no receive".
;                       2)  PortReset starts by disabling adapter interrupts.
;                       3)  PortGetPCI/EISAConfig removed.  PortInit calls
;                           PortReset, instead.
;
; 14-Jun-1994   eg      1)  Add TPFD_SIAConfig, for TP_FULL_DUPLEX.
;                       2)  PortInit sets PortConfigCSR6<FD> if TP_FULL_DUPLEX.
;
; 20-Jun-1994   eg      Changes for addition of EISA support:
;                       1)  Moved EISA data structure to MACINIT.ASM, where
;                           it's used.
;                       2)  Make configuration register values global, so that
;                           they can be modified by MACINIT.ASM.
;                       3)  Removed PortConfigRegWrite.  Calls to it replaced
;                           with "out" instructions, since used only with EISA.
;
; 23-jun-1994   mf      1)Handle errors in PortUpdateReceiveFilter from
;                         XmtSendSetupFrame; dont PUSHF and POPF flags
;                       2)In PortUpdateReceiveFilter, setup the filter,
;                         even if status shows no receive.  Check status
;                         before calling RcvEnable.  (That way, we send
;                         a setup packet and determine if we can physically
;                         communicate with the chip.)
;
; 05-jul-1994   mf      Make default burst size 16 (was 0 previously)
;
; 12-jul-1994   mf      Make default burst size 8, to avoid some PCI bridge
;                       chipset problems with larger bursts
;
; 31-jul-1994   mf      Add autodetection to PortInit.  This requires
;                       determining the IEEE address before autodetection.
;                       Also, we set CSR0<DSL> at assembly time, instead
;                       of at run time. (SendMediaTestPacket and PostResetDelay
;                       taken from Novell client driver)
;
; 17-aug-1994   mf      Debugging of Autodetect; add routine PortPrintMessage
;                       (copy of InitPrintMessage; there were problems moving
;                       InitPrintMessage)
;
; 01-Sep-1994   rv+ymf  In beginning of PortInit add to csr0 mask DSL=1LW
;
; 12-Sep-1994   rv      Add support to DC21140
;
; 25-Sep-1994   rv      Add ethernet address checksum
;
; 09-Oct-1994   rv      Add support to DC21140 pass 2
;
; 12-Oct-1994   ymf     Add reading of IEEE addresss from DC21140 pass 1.1 SROM
;                       Added the following routines:
;                       SROMDelay - A timer delay routine for waiting 840 nSEC
;                       ReadSROMWord - Reads one word from 93LC46B SROM.
;                       MakeSureSROMIdle - Literally.
;
; 21-Nov-1994   ymf     Add flag TulipIntPOsted. The flag is raised when chip
;                       is reset. If ISR sees flag on and CSR5 doesn't indicate
;                       an interrupt, it knows to acknowledge the interrupt
;                       without executing standard handler to prevent crash.
;
; 24-Nov-1994   ymf  1. Add additional reading of fields from SROM (for
;                       DC21140 pass 2). Most important is CSR12 general
;                       purpose register values.
;                    2. Added mechanism to detect from where to read CSR12
;                       GPR: PROTOCOL.INI, SROM or predefined constant.
;                    3. moved all SROM business to modules SROM.ASM/H .
;
; 13-Feb-1995   ymf  Change to accomodate DC21041 and new SROM format
;
; 26-Feb-1995   ymf  Add support for old (DEC classic) SROM
;
; 21-Mar-1995   ymf  Change default PBL in CSR0 to 32 LW
;
; 29-Mar-1995   ymf  Major driver-init restructuring:
;                    1. Move SROM code from PortInit to INIT-time processing.
;                    2. Changing mode of reference to SIA parameters.
;                    3. Restructuring PortInit
;                    4. Restructuring PortReset
;                    5. Adding PortConfigGPR variable containing info about
;                       DC21140's operation mode.
;
; 20-Apr-1995   ymf     TULIP3 autosense:
;                       - Modify PortAutodetect to deal only with Present
;                         medias, and set timer trigger.
;                       - Add routine PortResetSIA.
;                       - In PortCSR6Write let DC21041 be as DC21140, not
;                         requiring reset of the SIA.
;
; 13-Jun-1995   ymf     Fasternet (10/100) autodetection:
;                       - Add routine PortAutodetectFnet + associated variables.
;                       - Change PortInit.
;                       - Add routine Delay waiting a chosen num of ticks.
;                       Change PostResetDelay in several lines of code
;                       (made code valid also when wraparound happens).
;                       Move Tx threshold setting from SROM.ASM to PortInit
;                       Move InitTxThreshold to here from MACINIT
;                       Move "Legacy" variable from SROM.ASM to here
;
; 15-Aug-1995   ymf     Add InitPINetAddress to macport.as*
;
; 05-Sep-1995   as      1) Add GetLinkStatusFnet  to macport.as*
;                       2) Add to PortAutoDetectFnet:
;                         -  The Autodetect loop on all medias if didn't
;                            detect TP or SymScr.
;                         -  The Enable or Disable of Dynamic Autosense
;                            according to Fasternet Revesion and Board Type.
;
; 07-Sep-1995   as      Add macro IsFasternetBoardImplemetationSupportsAutosensin
;                       That chack for board Autosense support for Fasternet
;                       Rev 1.1.
;
; 28-Sep-1995   as      Add Multia support to PortAutoDetectTulip, check for
;                       BNC and AUI in reverse order.
;
; 31-Oct-1995   as      Add: 1) SetConnection to MiiPhy if present in
;                               PortReset routine.
;                            2) call to MiiPhyAutodetect if MiiPhy present
;                               to PortInit routine.
;
; 05-Nov-1995   as   Change default PBL for TULIP in CSR0 to 16 LW (was 32LW)
;                     (Workaround for addendum  in TULIP)
;
; 13-Nov-1995   as   Add Support for Fnet-3 Snooze mode in PortReset.
;                    The default is to set Chip to Run mode. only when keyword
;                    SNOOZE=ENABLE the Chip set to Snooze mode.
;
; 20-Nov-1995  as    Add Delay of 200msec For Fasternet (DC21140) in the end of
;                    PortReset.
;
; 10-Dec-1995  as    Remove EISA support from driver.
;
; 31-Dec-1995  as   Add Support for TULIP-3 Snooze mode in PortReset.
;                      The default is to set Chip to Run mode. only when keyword
;                      SNOOZE=ENABLE the Chip set to snooze mode.
;
; 01-Feb-1996  as    Add routines PortConfigRegRead, PortConfigRegWrite
;                    to read & write directly to the PCI configuration space.
;
; 04-Feb-1996  as    Add when Set transmit threshold according to keyword/default
;                    if OPTI chipset (IsOptiC832 = 1) and no user threshold
;                    keyword Set STORE AND FORWARD bit - workaround for
;                    multiple tx underflow in OPTI C832 Chipset.
;
; 12-Feb-1996  as    Add support for DC21142 (TWINET)
;
; 15-Feb-1996  as    Add PortSetSNOOZEMode routine.
;
; 24-Feb-1996  as    Add PortPrintASMedia - print the Autodetect Selected media.
;
; 05-May-1996  as    Change PortConfigCSR0/6 to Nic.CSR0_Value/Nic.Shadow_CSR6.
;                    Change PortConfigCFCS/CFLT to Nic.ConfigCFCS/CFLT.
;                    Delete variables PortConfigGPR/SIA and FnetGPRCtrl/Data.
;
; 19-May-1996  as    Put Device in Run mode as default - (PortSetSNOOZEMode).
;
; 25-Nov-1996  de    Move TULIP3 Autosense support to mac2phy
; 25-Nov-1996  de    Changes in include file names, and in AWK conventions.
;
; 12-Jan-1997  de    using AutoSenseCapable field in Nic, to enable/disable AS.
;
; 04-Feb-1997  de    change InitPiNetAddress and InitTxThreshold names to
;		     KWDPiNetAddress and KWDTxThreshold respectively.
;
; 16-Feb-1997  de    make buffers and descriptors 32 Bytes aligned
;
; 24-Mar-1997  de    add Post_SetConnection, that masks the no_carrier
;		     and loss_of_carrier errors in Full-Duplex mode
;
;************************************************************************
; PortUpdateReceiveFilter - Send a setup frame to the DC21040/DC21140 with the
;                           current contents of the NDISMulticastTable, the
;                           current station address from
;                           NDISServiceSpecificChar table, pad the entry with
;                           copies of the broadcast address.
;                           This routine is also used to enable the driver
;
; PortReset               - Issue a reset to the DC21040/DC21140
;
; PortInit                - Initialize data structures local to MACPORT module
;
; PortUninit              - Uninitialize local data structures.
;
; PortAutoDetect          - Implement the SIA autodetection algorithm
;
; SendMediaTestPacket	  - Send a special test packet for autodetect BNC
;
; PostResetDelay          - Delay for a fixed time
;
; GetLinkStatusFnet       - get the link status of media - linked or not
;
; PortPrintMessage
;
.xlist                                  ; disable listing the include file
include seg_defs.inc
include macro.inc
include dc_regs.inc
include macxmt.inc
include nic.inc
include driver.inc
include ndis.inc
include sss.inc
include macport.ash
.list                                   ; enable listing
.386

START_DATA_SEGMENT_RUNTIME

;-----------------------------------------------------------
; Flag saying if an interrupt was pending before chip reset.
;-----------------------------------------------------------
TulipIntPosted          DW      0

AES_INTERVAL		equ	500

;--------------------------------------------
;  Define messages for Autodetect Algorithm
;--------------------------------------------
CR EQU 0Dh      ; ASCII Carriage Return
LF EQU 0Ah      ; ASCII Line Feed

TwinetSetConnErrMsg      DB ' Failed to set Connection '
		      DB CR,LF,0

END_DATA_SEGMENT_RUNTIME



START_CODE_SEGMENT_RUNTIME

	PAGE
;***************************
;* PortUpdateReceiveFilter *
;***************************
;
; This routine sends a setup frame to the DC21040/DC21140 with the current
; contents of the NDISMulticastTable, and the current station address from the
; NDISServiceSpecificChar table.
;
; The DC21040/DC21140 gets reset as a result of calling this routine. This
; routine assumes that the transmit and receive objects are active when the
; routine is called. Upon exit, the transmit and receive objects are left in
; an active, but reinitialized state.
;
; Returns: Carry set if an error occurred
;
; BEGIN
;    call PortReset
;    call XmtEnable
;    call XmtGetSetupBuffer
;    init setup frame with all FF's
;    copy current MAC address to setup frame
;    copy contents of NDISMulticastTable to setup frame
;    call XmtSendSetupFrame
;    if error
;        return(carry set)
;    if (current Packet Filter says to receive at least some packets)
;       call RcvEnable
;    return(carry clear)
;    }
; END
;
			 ALIGN  4
PortUpdateReceiveFilter  PROC  NEAR
	push es
	push di
	push si
	push eax
	push bx
	push cx
	pushf

	cli
	cld

        and  Nic.Shadow_CSR6, NOT CSR6_PROMISCUOUS_MODE    ; Assume NOT promiscuos
							   ; - setup packet has to be sent.
	call PortReset                  		   ; Reset Adapter
; In XmtEnable we write CSR6. CSR7 is still 0
	call XmtEnable                  ; Reenable transmitter

	cmp  NDISServiceStatus.sss_filter, 0
	je   purf_after_rcv_enable	; Nothing to be done - no packet allowed

	test NDISServiceStatus.sss_filter, FM_PROMISCUOUS
	jz   purf_send_setup_packet	; Nothing to be done - promiscuous mode

        or   Nic.Shadow_CSR6, CSR6_PROMISCUOUS_MODE    ; Set promiscuos bit
	jmp  purf_before_rcv_enable

purf_send_setup_packet:
	mov  ax, ds                     ; ES = DS
	mov  es, ax
	call XmtGetSetupBuffer          ; Returns NEAR pointer to setup buffer
					; in AX.
	mov  di, ax                     ; ES:DI points to setup buffer
	mov  bx, ax                     ; Save NEAR pointer in BX

	call PortInitSetupBuffer

	cmp  NDISServiceStatus.sss_filter, SSS_BROADCAST_FILTER  ; If filter allows only broadcast -
	je   purf_done                  ; no need to fill setup packet - send it immidiately

; Now, place the current station address in the setup frame.
;
					; DS:SI points to the current address
	mov  si, OFFSET NDISServiceSpecificChar.ssc_curraddr

	mov  di, bx                     ; ES:DI points to start of setup buffer
	xor  eax, eax
	lodsw                           ; Load word into AX
	stosd                           ; Store dword EAX in setup buffer
	lodsw                           ; Load word into AX
	stosd                           ; Store dword EAX in setup buffer
	lodsw                           ; Load word into AX
	stosd                           ; Store dword EAX in setup buffer
;
; Now, determine the number of entries in the NDISMulticastTable, and add
; those entries to the setup frame.
;
	mov  cx, NDISMulticastTable.ssc_current
	mov  si, OFFSET NDISMulticastTable.ssc_multiaddr

purf_loop:
	cmp  cx, 0
	je   purf_done

	lodsw                           ; Load word into AX
	stosd                           ; Store dword EAX in setup buffer
	lodsw                           ; Load word into AX
	stosd                           ; Store dword EAX in setup buffer
	lodsw                           ; Load word into AX
	stosd                           ; Store dword EAX in setup buffer

	add  si, 10                     ; DS:SI points to next entry in
					; NDISMulticastTable
	dec  cx
	jmp  purf_loop

purf_done:
	call XmtSendSetupFrame          ; Send the buffer
	jc   purf_error_exit            ; If error, preserve the carry set

purf_before_rcv_enable:
	call RcvEnable                  ; Reenable the receiver

purf_after_rcv_enable:
; Here at last we write CSR7 to enable interrupts.
; We know we can't be in the middle of the ISR, because we can't reset
; the device during the ISR. However, the routine might be called in
; the end of the ISR, while we treat the pending requests. We don't want
; to enable the CSR7 interrupts in that case, because we can't be sure
; that we are in cli section.
	cmp  InterruptSemaphore, 0
	jne  purf_exit

	SET_ADAPTER_INTERRUPT
purf_exit:
	popf
	clc
purf_fin:
	pop cx
	pop bx
	pop eax
	pop si
	pop di
	pop es
	ret

purf_error_exit:
	popf
	stc
	jmp purf_fin

PortUpdateReceiveFilter  ENDP

END_CODE_SEGMENT_RUNTIME

START_CODE_SEGMENT_RUNTIME

	PAGE
;*************
;* PortReset *
;*************
;
; Reset the DC21040/DC21041/DC21140/DC21142/DS21143
;
	   ALIGN  4
PortReset  PROC  NEAR
	push eax
	push dx
	push cx
	push bx
	push si

      	call SoftwareResetDevice

	mov     TulipIntPosted, 1

;---------------------------------------------------------
; Updating SIA/GPR registers  + Mii phy support variables
;----------------------------------------------------------

	call    Mac2PhySetConnection
	jnc     pr_xmt_rcv_reset

	; Set Connection Failed
	;----------------------------
	mov     dx, OFFSET TwinetSetConnErrMsg
	call    DisplayMessage
	jmp     pr_Exit

pr_xmt_rcv_reset:
	call XmtReset

	call RcvReset

; No need to write CSR6 and CSR7, because this is done in
;    PortUpdateReceiveFilter

;	mov  eax, Nic.Shadow_CSR6   ; Restore CSR6
;	mov  dx,  Nic.CSR6_Address
;	out  dx,  eax
;	SET_ADAPTER_INTERRUPT
pr_Exit:
	pop  si
	pop  bx
	pop  cx
	pop  dx
	pop  eax
	ret

PortReset  ENDP


END_CODE_SEGMENT_RUNTIME

START_CODE_SEGMENT_BIND



       ALIGN  4
;***********************
;* SendMediaTestPacket *
;***********************
;
; Description:
;       This routine looks for BNC cable connection. This is done by
;       transmitting a packet and verifying that it was transmitted with no
;       errors. If there are any Tx errors, we assume no cable is connected to
;       the BNC port, and from this reason we detected the Tx error.
;
;   BEGIN
;       Send a runt packet with CRC-error (to make sure that no
;         station will misintrprete it).  (Genetating CRC error is achieved
;     by preventing Tulip from generating its CRC.)
;       Poll (with timeout) on Tx completion.
;       if Tx_Status<ERROR_SUMMARY) is set or Timeout
;               BNC output is not connected to the Ethernet
;               stc (failure code)
;       else
;               clc (success code)
;       return
;   END
;
; On Entry:     Interrupts disabled
;               Adapter is ready to transmit (from PortUpdateReceiveFilter)
;
; On Return:
;
;               Flags: Success = carry clear
;              Failure = carry set
;
;               Note:   Interrupts are disabled.
;
; Remarks:      This routine is called by PortAutoDetect
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
RUNT_FRAME_SIZE     equ 50
RUNT_FR_DIS             equ     TDES1_M_AC or TDES1_M_DPD
TDES1_BUFF          equ TDES1_M_FS+TDES1_M_LS
RUNT_FR_CMD1        equ TDES1_BUFF or RUNT_FR_DIS or RUNT_FRAME_SIZE
RUNT_FR_CMD             equ     RUNT_FR_CMD1  and (not TDES1_M_IC)

SendMediaTestPacket proc    near

	push    bx
	push    cx
	push    bp
	push    edx
	push    di
	push    si

	pushf	             				;save interrupt status
	cli

	mov     bx, XmtCurrentDescriptor                ;Point at transmit descriptor
								;to be initialized.

	;Fill up the Destination IEEE address to be the physical address of the
	;NIC which is stored in NDISServiceSpecificChar
	;----------------------------------------------------------------------
	mov     di, [bx].XMT_DESCRIPTOR.p_XmtBuffer           ;DI points to the buffer.
	mov     si, OFFSET NDISServiceSpecificChar.ssc_curraddr ;SI -> board ENET address.

	mov     edx, [si]                       ;get 4 ENET address bytes
	mov     [di], edx                       ;put in destination address
	mov     [di+6], edx                     ;put in source address
	mov     dx, [si+4]                      ;get last two ENET address bytes
	mov     [di+4], dx                      ;put in destination address
	mov     [di+10], dx                     ;put in destination address

	;Generate the descriptor command to avoid CRC generation (make it a bad
	;frame), no padding (runt frame), short size (runt frame) and no
	;interrupt on completion.
	;----------------------------------------------------------------------
	or [bx].XMT_DESCRIPTOR.TDES1, RUNT_FR_CMD

	;Flip ownership bit in this descriptor, so Tulip will be able to
	;process it.
	;----------------------------------------------------------------
	mov     [bx].XMT_DESCRIPTOR.TDES0, TDES0_M_OWN

	;Kick tulip to start Transmitting
	;--------------------------------
	mov     dx, Nic.CSR1_Address
	out     dx, eax

	;Wait for transmission to end
	;----------------------------
	mov     cx, 7000                ;timeout = 35msec = 7000 * 5usec
PSTP_TxPollLoop:
	test    [bx].XMT_DESCRIPTOR.TDES0, TDES0_M_OWN
	jz      SHORT PSTP_DescHostOwned
	call    PostResetDelay          ;wait 5usec
	loop    PSTP_TxPollLoop         ;next tick change and keep polling

	;Timeout waiting for end of Tx!
	jmp     SHORT PSTP_EndFail

PSTP_DescHostOwned:

	;Check for TX errors (loss of carrier, no carrier, excessive collisions)
	;-----------------------------------------------------------------------
	test    [bx].XMT_DESCRIPTOR.TDES0, TDES0_M_LO OR TDES0_M_NC OR TDES0_M_EC
	jz      SHORT PSTP_EndSuccess

PSTP_EndFail:
	popf
	stc
	jmp     SHORT PSTP_End

PSTP_EndSuccess:
	popf
	clc

PSTP_End:
	pop     si
	pop     di
	pop     edx
	pop     bp
	pop     cx
	pop     bx
	ret

SendMediaTestPacket endp



	PAGE
;************
;* PortInit *
;************
;
; This function initializes the hardware and various global NDIS data
; structures.
;
; Transmit threshold - Maximal value (160/1024) unless specified otherwise
; in PROTOCOL.INI keyword TX_THRESHOLD
; Small thresholds in fasternet may cause (in some machines) undeflows.
;
; BEGIN
;    if (SIA_Mode = Autodetect/Autosense)
;	 Call PortReset to enable AutoDetect
;        PortAutoDetect (Two versions: for DC2104x and DC21140)
;    call PortReset to init the hardware
; END
	  ALIGN  4
PortInit  PROC  NEAR

	call 	PortUpdateReceivefilter

	test    Nic.SelectedConnectionType, ConnectionAutoDetectNway OR ConnectionAutoSense
	jz      pi_done_AS

pi_autodetect_or_sense:
	call    Mac2PhyAutodetect       ; TULIP family autodetection

;Check if NIC is capable of performing AS. (according to NIC's SROM)

	mov     AutosenseCounter, AUTOSENSE_DISABLE

	test    Nic.SelectedConnectionType, ConnectionAutoSenseNway
	jz     	pi_done_AS

	mov     AutosenseCounter, AUTOSENSE_ENABLE

pi_done_AS:

IF OS EQ DOS
	call    DisplaySelectedMedia           ; Print Selected media
ENDIF
	clc
; If Carry flag set the BIND procedure will fail
;-------------------------------------------------
	ret
PortInit  ENDP

END_CODE_SEGMENT_BIND

START_CODE_SEGMENT_RUNTIME


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         Post_SetConnection
;
; Description:
;	Modifies appropriate driver variables depening on FD/HD chip's mode of
;	operation
;
; On Entry:
;
; On Return:
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Post_SetConnection	proc

	;If Unselected media -> Nothing to do
	;------------------------------------
	cmp	Nic.SelectedMedia, NoSelectedMedia
	je	SHORT PSC_Exit

	;Handle FD implications on chip's NoCarrier and LossOfCarrirer
	;(Ignore these indications when in FD)
	;-------------------------------------------------------------
	and	TxDescFilterValue, not (TDES0_M_LO or TDES0_M_NC) ; Assume FD
	IsMediaFD Nic.SelectedConnectionType
	je	SHORT PSC_done_fd
	or      TxDescFilterValue, TDES0_M_LO or TDES0_M_NC       ;It's HD
PSC_done_fd:
	movzx	si, Nic.SelectedMedia
	call	GetMediaLineSpeed
	cmp	ax, 10
	mov	NDISServiceSpecificChar.ssc_linkspeed, 10000000	;10Mbs
	je	PSC_Exit
	mov	NDISServiceSpecificChar.ssc_linkspeed, 100000000	;100Mbs

PSC_Exit:
	ret

Post_SetConnection	endp



;**********************
; PortInitSetupBuffer *
;**********************
; This routine initializes setup buffer.
; If the NDIS receive filter is 1 - only multicast/unicast
; addresses are required - the setup buffer is initialized
; with the station address. Due to the structure of the setup
; packet, this means 3 sequences of a word of the address and
; a filler word of 0FFFFh.
; In any other required filter, broadcast addresses are required
; and the setup buffer is initialized with 0FFs. This has the
; effect of allowing broadcast addresses.
; Preconditions:
;   1. cld
;   2. es:di - Pointer to the setup buffer
; Postconditions:
;   Setup packet is initialized.
; the routine destroys cx, ax, si and di.
PortInitSetupBuffer	proc

	cmp  NDISServiceStatus.sss_filter, SSS_MULTI_UNI_FILTER
	je   pisb_fill_unicast

	mov  cx, XMT_SETUP_FRAME_SIZE
	shr  cx, 2
	mov  eax, 0FFFFFFFFh
	rep  stosd                      ; Initialize setup buffer with FF's
	jmp  pisb_exit

pisb_fill_unicast:
	mov  cx, XMT_NUMBER_OF_ADDRESSES
	mov  ax, 0FFFFh
pisb_unicast_loop:
	mov  si, OFFSET NDISServiceSpecificChar.ssc_curraddr
; store the current station address in the setup buffer.
; this is done by putting 3 times one word of the address,
; followed by 0FFFFh
	movsw
	stosw
	movsw
	stosw
	movsw
	stosw
	loop pisb_unicast_loop

pisb_exit:
	ret
PortInitSetupBuffer	endp


END_CODE_SEGMENT_RUNTIME
END

