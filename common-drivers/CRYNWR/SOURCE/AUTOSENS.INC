;*******************************************************************************
;
; AUTOSENS.INC
;
; Include file for Dec Tulip and Fast Ethernet boards that handles the AutoSense
; and AutoDetect algoritms used by DC21040, DC21041, DC21140 chips.
;
; There are 2 major autosense categories:
;   AutoDetect (or Power-Up autosense) and Autosense (or dynamic autosense)
;   which are implemented here.
;
;   AutoDetect:
;     A Process done once during Driver init phase and is aimed for finding the
;     active media i.e. one of the board's medias that is actually connected to the Net.
;     and to use it at run-time.
;
;   AutoSense:
;     A task performed as long as the driver is running and is aimed to locate the medium
;     connected to the net at a given moment and to use it for transmitting or receiving
;     data.
;
;   Not all the chips and Nics are capable of performing AutoSense, all of them are capable
;   of performing autodetect.
;
;   The following describes the Nics and chips supporting autosense and autodetect:
;
; 1. FASTERNET  (DC21140)  - Without MII PHY !!
;       +-----------+---------------------------------+--------------------------+
;       |  DC21140  | Connectors  Relays   SD HW fix  |  AutoDetect  AutoSense   |
;       +-----------+---------------------------------+--------------------------+
;       |  Rev 1.1  |     2          0          n     |    yes          no       |
;       |           |     1          2          n     |    yes          no_op    |
;       |           |     1          1          n     |    yes          no       |
;       |           |     1          1          y     |    yes          yes      |
;       +-----------+---------------------------------+--------------------------+
;       |  Rev 1.2  |     2          0          n     |    yes          yes      |
;       |  & up     |     1          2          n     |    yes          no_op    |
;       |           |     1          1          n     |    yes          yes      |
;       +-----------+---------------------------------+--------------------------+
;
;2. TULIP3  (DC21041)
;       Supports both AUTOSENSE and AUTODETECT.
;
;3. TULIP   (DC21040)
;       Supports AUTODETECT only.
;
;
;
; Written by:   Moti Haimovsky
; Date:         18-Jul-1995
;
;
; Copyright (C) 1995 by Digital Equipment Corporation
; All rights reserved.
;
; Modification History:
;
;       By            Date     Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; Haimovsky Moti  18-Jul-1995 2.13  Initial version
;
; Haimovsky Moti  20-Oct-1995 2.20  Added Mii phy autosense and autodetect support
; Haimovsky Moti   5-Nov-1995       Moditfied MiiAutoSense not to update MAC parameters
;                                   if media wasn't changed.
; Haimovsky Moti  16-Sep-1996 2.42  Modified Mii phy autosense and autodetect support routines
;                                   in order to support ML6692 Phy.
; Haimovsky Moti  01-Oct-1996       Fixed bug in SendMediaTestPacket. when calling to ResetDevice
;                                   Nic.SelectedConnection shoul be in Force BNC an not Autosense.
; Adi Shaliv      27-Oct-1996 2.50  Added Multia support to PortAutoDetectTulip, check for
;                                   BNC and AUI in reverse order.
; Haimovsky Moti  27-Oct-1996       Modifications needed for NDIS2-ODI unification.
; Moti Haimovsky  08-Nov-1996     - Added Phyer preliminary support
; Moti Haimovsky  08-Jan-1997 2.60- moved Autodetect related routines to the BIND segnent for NDIS2
;				    support.
; Moti Haimovsky  17-Feb-1997  	   -MULTIA indication is now in NIC, ODI Supports it too
; Moti Daniel	  03-Feb-1998 2.62 -Changed MiiPrepareForAsNwayConnection, 
;				    PhyerPrepareForAsNwayConnection and TwinetPrepareForAsNwayConnection 
;				    to use faked media parameter returned from FakeAUI routine
;*******************************************************************************

;*******************************************************************************
;                           C O D E    S E G M E N T
;*******************************************************************************
START_DATA_SEGMENT_RUNTIME

;*******************************************************************************
;                    CONSTANTS AND VARIABLES USED BY AUTOSENSE
;*******************************************************************************

Timer_Disabled  equ     0
SPA_Timer       equ     1
ANC_Timer       equ     2
LINK_Timer      equ     3
MII_Timer       equ     4
UNDEFINED_Timer equ     0FFh

SPA_Time        equ     5000
ANC_Time        equ     3000
LINK_Time       equ     1000
MII_Time        equ     5000
MII_NwayConfigTime equ  LINK_Time

AutoSenseTimerSTRUC     struc
	TimerType       dw      0
	TimerValue      dw      0
AutoSenseTimerSTRUC ends

AutoSenseTimer  AutoSenseTimerSTRUC <SPA_Timer, SPA_Time>


END_DATA_SEGMENT_RUNTIME



;*******************************************************************************
;                           I N I T    S E G M E N T
;*******************************************************************************
START_DATA_SEGMENT_BIND

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                               AUTO    DETECT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                         AUTO-DETECT    VARIABLES
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
AUTO_DETECT_ENABLED     equ     1
AutoDetect              db      0       ;Written by SelectWorkingParameters

IF OS EQ OS2
SwitchToMediaTypeMessage        dw      offset DGroup:SwitchingToUTPMessage
				dw      offset DGroup:SwitchingToBNCMessage
				dw      offset DGroup:SwitchingToAUIMessage
				dw      offset DGroup:SwitchingToSymScrMessage
				dw      offset DGroup:MediaUnknownMessage
				dw      offset DGroup:MediaUnknownMessage
				dw      offset DGroup:SwitchingToT4Message
				dw      offset DGroup:SwitchingToFxMessage
ELSE
SwitchToMediaTypeMessage        dw      offset CGroup:SwitchingToUTPMessage
				dw      offset CGroup:SwitchingToBNCMessage
				dw      offset CGroup:SwitchingToAUIMessage
				dw      offset CGroup:SwitchingToSymScrMessage
				dw      offset CGroup:MediaUnknownMessage
				dw      offset CGroup:MediaUnknownMessage
				dw      offset CGroup:SwitchingToT4Message
				dw      offset CGroup:SwitchingToFxMessage
ENDIF

END_DATA_SEGMENT_BIND

START_CODE_SEGMENT_RUNTIME
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MoveToTP
;
; Description:  Writes new values to CSR13_Value, CSR14_Value, CSR15_Value and
;               initialize SIA in TP mode.
;
; On Entry:
;               Note:   Interrupts are disabled.
;
; On Return:
;               Flags:
;
;               Note:   Interrupts are disabled.
;
; Remarks:      This routine is called by AutoDetectAlgorithm.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	even
MoveToTP proc near

	push    ax
	push    si

	mov     si, MediaTp
	mov     ax, PHY_TYPE_SIA
	call    PhysSetConnection
	jc      SHORT MTTp_Exit
	mov     Nic.SelectedMedia, MediaTP    ;Update selection indication
	call    WaitForMediaStabilization

MTTp_Exit:
	pop     si
	pop     ax
	ret

MoveToTP endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MoveToAUI
;
; Description:  Writes new values to CSR13_Value, CSR14_Value, CSR13_Value and
;               initialize SIA in AUI mode.
;
; On Entry:
;               Note:   Interrupts are disabled.
;
; On Return:
;               Flags:
;
;               Note:   Interrupts are disabled.
;
; Remarks:      This routine is called by AutoDetectAlgorithm.
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MoveToAUI proc near

	push    ax
	push    si

	mov     si, MediaAui
	mov     ax, PHY_TYPE_SIA
	call    PhysSetConnection
	jc      SHORT MTAui_Exit
	mov     Nic.SelectedMedia, MediaAUI    ;Update selection indication
	call    WaitForMediaStabilization

MTAui_Exit:
	pop     si
	pop     ax
	ret

MoveToAUI endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MoveToBNC
;
; Description:  Writes new values to CSR13_Value, CSR14_Value, CSR13_Value and
;               initialize SIA in BNC mode.
;
; On Entry:
;               Note:   Interrupts are disabled.
;
; On Return:
;               Flags:
;
;               Note:   Interrupts are disabled.
;
; Remarks:      This routine is called by AutoDetectAlgorithm.
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MoveToBNC proc near

	push    ax
	push    si

	mov     si, MediaBNC
	mov     ax, PHY_TYPE_SIA
	call    PhysSetConnection
	jc      SHORT MTBnc_Exit
	mov     Nic.SelectedMedia, MediaBNC    ;Update selection indication
	call    WaitForMediaStabilization

MTBnc_Exit:
	pop     si
	pop     ax
	ret

MoveToBNC endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MoveToSymScr
;
; Description:  Writes new values to CSR13_Value, CSR14_Value, CSR13_Value and
;               initialize SIA in SymScr mode.
;
; On Entry:
;               Note:   Interrupts are disabled.
;
; On Return:
;               Flags:
;
;               Note:   Interrupts are disabled.
;
; Remarks:      This routine is called by AutoDetectAlgorithm.
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MoveToSymScr    proc    near

	push    ax
	push    si

	mov     si, MediaSymScr
	mov     ax, PHY_TYPE_SYM
	call    PhysSetConnection
	jc      SHORT MTsym_Exit
	mov     Nic.SelectedMedia, MediaSymScr    ;Update selection indication
	call    WaitForMediaStabilization

MTsym_Exit:
	pop     si
	pop     ax
	ret

MoveToSymScr    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         WaitForMediaStabilization
;
; Description:  Writes new values to CSR13_Value, CSR14_Value, CSR13_Value and
;               initialize SIA in AUI mode.
;
; On Entry:
;               Note:   Interrupts are disabled.
;
; On Return:
;               Flags:
;
;               Note:   Interrupts are disabled.
;
; Remarks:      This routine is called by AutoDetectAlgorithm.
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
GEP_READ_DELAY                  equ     400000  ;200mSec in Tick-counter ticks

WaitForMediaStabilization       proc

	pushf
	push    cx

	;Wait For Media Stabilization
	;----------------------------
	cli
	mov     cx, 100
	push    WORD PTR GEP_READ_DELAY/100
WaitForMediaStabilization_:
	call    Delay                                   ;Let Media and link to stabilize
	loop    WaitForMediaStabilization_
	add     sp, 2

	pop     cx
	popf
	ret

WaitForMediaStabilization       endp

END_CODE_SEGMENT_RUNTIME

;*******************************************************************************
;                           TULIP   AUTOSENSING
;*******************************************************************************
START_CODE_SEGMENT_INIT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         TulipPrepareForAsNwayConnection ( )
;
; Description:
;
;
; On Entry:
;
; On Return:
;
;               Flags:
;
;               Note:   Interrupts are enabled.
;
; returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
TulipPrepareForAsNwayConnection proc

	mov     Phys.AsNway.ASNwayPhy, PHY_TYPE_SIA
	mov     Phys.AsNway.PowerUpAutosense, offset CGroup:AutoDetectAlgorithmTULIP
	mov     Phys.AsNway.DynamicAutosense, offset CGroup:NullRoutine
	mov     Phys.AsNway.LinkISR,          offset CGroup:NullRoutine

	;-------------------------------------------------------
	;Keep Autosense bit ONLY - since we do not support Nway
	;-------------------------------------------------------
	and     Nic.SelectedOperationMode, NOT (ModeNWAY or ModeAUTODETECT or ModeAUTOSENSE)
	or      Nic.SelectedOperationMode, ModeAUTODETECT or ModeAUTOSENSE

	;Adjust medium to be a populated one
	;-----------------------------------
	call    PhysAdjustNonMiiMedium

	ret

TulipPrepareForAsNwayConnection endp

END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_BIND

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         AutoDetectAlgorithmTulip
;
; Description:
;
;       Select TP (10BaseT)
;
;       Start Tx and Rx processes
;
;       Wait 2.4s and read SIA status
;
;       if SIA status<Link_Fail> is set
;
;          Select BNC (10Base2)
;
;          Send a 64_bytes packet with the following specification:
;               - destination address = Source address = station address
;               - Incorrect CRC (add CRC disabled)
;                 (runt packet can also be sent by setting DISABLE_PADDING
;                  in the descriptor for a packet < 64 bytes)
;
;          Poll with timeout on Txm completion
;
;          if Tx_Status<ERROR_SUMMARY) is set or Timeout
;
;               - Select AUI (10Base5)
;
;          clear Txm interrupt bits in CSR5
;
;
; Called at:    Init time
;
; On Entry:     Interrupts disabled
;               Already issued the 'call DriverReset'. This is a pre requisite
;               to properly use buffers and descriptors without too much
;               complications in SendMediaTestPacket!
;
; On Return:
;               Call to DriverReset was issued in SendMediaTestPacket to
;               reinitialize Tx ring using existing code.
;
;               Flags:
;
;               Note:   Interrupts are disabled.
;
; returns:
;               DX      Destroyed
;               EAX     Destroyed
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
AutoDetectAlgorithmTULIP                proc

	;-----------------------------------
	;If there is a TP connector go to TP
	;-----------------------------------
	;Change Media selection to TP
	;----------------------------
	call    MoveToTP
	jc      SHORT ADA_TLP_TP_Failed

	;Print Move to TP message
	;------------------------
	DataAddress     dx, SwitchingToMessage
	call    DisplayMessage
	DataAddress     dx, SwitchingToUTPMessage
	call    DisplayMessage

	;Check TP link status
	;--------------------
	mov     cx, 50                          ;Max time = 50 * 50mSec = 2500mSec
						;
ADA_TLP_WaitForLinkTestToEnd:                           ;Do {

	mov     si, MediaTP
	mov     ax, PHY_TYPE_SIA

	call    PhysGetConnectionStatus

	cmp     al, MEDIA_LINK_PASS
	je      SHORT ADA_TLP_Exit
						
	cmp     al, MEDIA_LINK_FAIL
	je      SHORT ADA_TLP_TP_Failed

	;Delay for 50mSec                       ; Link configuring -> wait a while and Try again.
	;----------------
	push    cx
	mov     cx, 10000                       ;    Delay = 10K * 5uSec = 50mSec
ADA_TLP_Delay1:
	call    PostResetDelay                  ;       Delay = 5uSec
	Loop    ADA_TLP_Delay1
	pop     cx                              ;   }

	loop    ADA_TLP_WaitForLinkTestToEnd    ;While (Max time not expired)

	;Either found a link fail or time out to find link pass! or no TP
	;----------------------------------------------------------------
ADA_TLP_TP_Failed:
ADA_TLP_NoTP:

	;-------------------------------------
	; If It is MULTIA board Try AUI first
	;-------------------------------------
	cmp      Nic.PCType, MULTIA_PC
	jne      SHORT ADA_TLP_BNC

	;-------------------------------------
	;If there is a AUI connector go to AUI
	;-------------------------------------
	;Change Media selection to AUI
	;-----------------------------
	call    MoveToAUI
	jc      SHORT ADA_TLP_MULTIA_NoAUI

	;Print Move to AUI message
	;-------------------------
	DataAddress     dx, SwitchingToMessage
	call    DisplayMessage
	DataAddress     dx, SwitchingToAUIMessage
	call    DisplayMessage

	;------------------------------------------------
	;Trying AUI connection requires sending a packet.
	;------------------------------------------------
	call    SendMediaTestPacket
	jnc     SHORT ADA_TLP_Exit


ADA_TLP_MULTIA_NoAUI:
	;------------------------------------------
	;if BNC connector is present Switch to BNC.
	;------------------------------------------
	call    MoveToBNC
	jc      SHORT ADA_TLP_Exit

	;Print Move to BNC message
	;------------------------
	DataAddress     dx, SwitchingToMessage
	call    DisplayMessage
	DataAddress     dx, SwitchingToBNCMessage
	call    DisplayMessage

	jmp     SHORT ADA_TLP_Exit

	;-------------------------------------
	;If there is a BNC connector go to BNC
	;-------------------------------------
	;Change Media selection to BNC
	;-----------------------------
ADA_TLP_BNC:
	call    MoveToBNC
	jc      SHORT ADA_TLP_NoBNC

	;Print Move to BNC message
	;-------------------------
	DataAddress     dx, SwitchingToMessage
	call    DisplayMessage
	DataAddress     dx, SwitchingToBNCMessage
	call    DisplayMessage

	;Trying BNC connection requires sending a packet.
	;------------------------------------------------
	call    SendMediaTestPacket
	jnc     SHORT ADA_TLP_Exit
ADA_TLP_NoBNC:

	;------------------------------------------
	;if AUI connector is present Switch to AUI.
	;------------------------------------------
	call    MoveToAUI
	jc      SHORT ADA_TLP_NoAUI

	;Print Move to AUI message
	;------------------------
	DataAddress     dx, SwitchingToMessage
	call    DisplayMessage
	DataAddress     dx, SwitchingToAUIMessage
	call    DisplayMessage
ADA_TLP_NoAUI:

ADA_TLP_Exit:
	;-----------------------------------------------------
	;As for today we do not support Tulip  autosensing
	;-----------------------------------------------------
	and     Nic.SelectedOperationMode, NOT (ModeAutoSense or ModeAutoDetect or ModeNway)

	clc
	ret

AutoDetectAlgorithmTULIP                endp

END_CODE_SEGMENT_BIND

;*******************************************************************************
;                           TULIP3   AUTOSENSING
;*******************************************************************************
START_CODE_SEGMENT_INIT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         Tulip3PrepareForAsNwayConnection ( )
;
; Description:
;
;
; On Entry:
;
; On Return:
;
;               Flags:
;
;               Note:   Interrupts are enabled.
;
; returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Tulip3PrepareForAsNwayConnection        proc

	push    ax

	;------------------------------------------
	;Init and Check if needs autosensing at all
	;------------------------------------------
	call    PhysAdjustNonMiiMedium                                   ;Adjust medium to be a populated one
	mov     Phys.AsNway.ASNwayPhy, PHY_TYPE_SIA                      ;SIA is our autosense Phy
	mov     Phys.AsNway.PowerUpAutosense, offset CGroup:NullRoutine  ;No routines Yet
	mov     Phys.AsNway.DynamicAutosense, offset CGroup:NullRoutine
	mov     Phys.AsNway.LinkISR,          offset CGroup:NullRoutine

	;In tulip3 only If more then one Medium (BNC AUI or TP) is present - allow autosense
	;-----------------------------------------------------------------------------------
	xor     ax, ax
	cmp     Nic.media[TP].MediaPresence, Present
	jne     SHORT T3PFANC_DoneTP
	inc     ax
T3PFANC_DoneTP:
	cmp     Nic.media[BNC].MediaPresence, Present
	jne     SHORT T3PFANC_DoneBNC
	inc     ax
T3PFANC_DoneBNC:
	cmp     Nic.media[AUI].MediaPresence, Present
	jne     SHORT T3PFANC_DoneAUI
	inc     ax
T3PFANC_DoneAUI:
	cmp     ax, 1
	jle     T3PFANC_NoAutosenseCapability

	;--------------------------
	;Board is Autosense capable
	;--------------------------
	;Keep Autosense bit ONLY - since we do not support Nway
	;-------------------------------------------------------
	and     Nic.SelectedOperationMode, NOT (ModeNWAY or ModeAUTODETECT or ModeAUTOSENSE)
	or      Nic.SelectedOperationMode, ModeAUTODETECT or ModeAUTOSENSE

	;Init routines entries
	;---------------------
	mov     Phys.AsNway.ASNwayPhy, PHY_TYPE_SIA
	mov     Phys.AsNway.PowerUpAutosense, offset CGroup:AutoDetectAlgorithmTULIP3
	mov     Phys.AsNway.DynamicAutosense, offset CGroup:AutoSenseTULIP3
	mov     Phys.AsNway.LinkISR,          offset CGroup:LinkIsrTULIP3

	pop     ax
	ret

	;------------------------------
	;Board is NOT Autosense capable
	;------------------------------
T3PFANC_NoAutosenseCapability:
	and     Nic.SelectedOperationMode, NOT (ModeNWAY or ModeAUTODETECT or ModeAUTOSENSE)
	pop     ax
	ret

Tulip3PrepareForAsNwayConnection        endp

END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_BIND

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         AutoDetectAlgorithmTulip3
;
; Description:
;
;       Perform TULIP autodetect algorithm
;       Clear CSR5 LP/LF interrupts
;       Disable SPA Timer
;       If medium is TP - done (since LP/LF interrupts are used)
;       Else Set SPA timer for monitoring network activity
;
; Called at:    Init time
;
; On Entry:     Interrupts disabled
;               Already issued the 'call DriverReset'. This is a pre requisite
;               to properly use buffers and descriptors without too much
;               complications in SendMediaTestPacket!
;
; On Return:
;               Call to DriverReset was issued in SendMediaTestPacket to
;               reinitialize Tx ring using existing code.
;
;               Flags:
;
;               Note:   Interrupts are disabled.
;
; returns:
;               DX      Destroyed
;               EAX     Destroyed
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
AutoDetectAlgorithmTULIP3               proc
	
	push    eax
	push    dx

	;------------------------
	;Perform Tulip autodetect
	;------------------------
	call    AutoDetectAlgorithmTulip

	;---------------------
	;Prepare for AutoSense
	;---------------------
	;Tulip autodetect had ended with disabling autosense - Enable it
	;---------------------------------------------------------------
	or      Nic.SelectedOperationMode, ModeAutoSense

	;Read and clear SRA
	;------------------
	mov     dx, Nic.CSR12_Address
	in      eax, dx
	or      eax, CSR12_SRA
	out     dx, eax

	;Clear and Enable Link status interrupts
	;----------------------------------------
	mov     eax, CSR5_LNF or CSR5_LNP
	mov     dx, Nic.CSR5_Address
	out     dx, eax

	or      Nic.Shadow_CSR7, (CSR7_LFE or CSR7_LPE)

	;If Selected medium is TP - Disable SPA timer
	;Else                     - Set SPA timer
	;--------------------------------------------
	mov     AutoSenseTimer.TimerType, Timer_Disabled
	cmp     Nic.SelectedMedia, MediaTP
	je      SHORT ADAT3_DoneAD

	mov     AutoSenseTimer.TimerType, SPA_Timer
	mov     AutoSenseTimer.TimerValue, SPA_Time

ADAT3_DoneAD:
	clc
	pop     dx
	pop     eax
	ret

AutoDetectAlgorithmTULIP3               endp

END_CODE_SEGMENT_BIND

START_CODE_SEGMENT_RUNTIME
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         AutoSenseTULIP3 ( )
;
; Description:
;       This routine is Called at call-back time and is responsible of
;       Checking the BNC/AUI network activity for deciding which media to choose.
;
;
; On Entry:
;
; On Return:
;
;               Flags:
;
;               Note:   Interrupts are enabled.
;
; returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
AutoSenseTULIP3 proc

	push    eax
	push    bx
	push    dx

	;--------------------------
	;Is TIMER Enabled at all ?
	;--------------------------
	cmp     AutoSenseTimer.TimerType, SPA_Timer
	jne     SHORT AST3_Exit

	;----------------------------------------
	;Did network Activity check time arrive ?
	;----------------------------------------
	sub     AutoSenseTimer.TimerValue, AES_INTERVAL
	jg      SHORT AST3_Exit                                 ;Time did not arrive yet -> Exit
	mov     AutoSenseTimer.TimerValue, SPA_Time             ;Rearm the timer

	;------------------------------------------------
	;IF BNC or AUI Get and check medium port activity
	;ELSE (TP) - Disable Timer and exit
	;------------------------------------------------
	cmp     Nic.SelectedMedia, MediaTP
	je      SHORT AST3_DisableExit

	;Read and clear SRA
	;------------------
	mov     dx, Nic.CSR12_Address
	in      eax, dx
	push    eax
	or      eax, CSR12_SRA
	out     dx, eax
	pop     eax

	;If current port (BNC or AUI) has activity - Done
	;------------------------------------------------
	test    eax, CSR12_SRA
	jnz     AST3_Exit

	mov     bx, offset CGroup:MoveToBNC
	cmp     Nic.SelectedMedia, MediaAUI
	je      SHORT AST3_SwitchMedia
	mov     bx, offset CGroup:MoveToAUI
AST3_SwitchMedia:
	call    bx
AST3_Exit:
	clc
	pop     dx
	pop     bx
	pop     eax
	ret

AST3_DisableExit:
	mov     AutoSenseTimer.TimerType, Timer_Disabled
	jmp     SHORT AST3_Exit


AutoSenseTULIP3    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         LinkIsrTULIP3 ( )
;
; Description:
;       This routine is called at interrupt time and is the part of the autosense
;       algorithn. The routine does the following:
;
;
;
; On Entry:
;
; On Return:
;
;               Flags:
;
;               Note:   Interrupts are enabled.
;
; returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
LinkIsrTULIP3   proc

	push    eax
	push    bx
	push    dx
	push    si


	;---------------------
	;LP Interrupt handling
	;---------------------
	test    Nic.CSR5_image, CSR5_LNP                        ;If Link Pass - Move to TP (
	jz      SHORT LIT3_NotLPint                             ;(unless already there)

	cmp     Nic.SelectedMedia, MediaTP
	je      SHORT LIT3_Exit

	call    MoveToTP
	jc      SHORT LIT3_Exit                                 ;If NO TP - Stay in prev medium.
	mov     AutoSenseTimer.TimerType, Timer_Disabled        ;No use for timer in TP
	jmp     SHORT LIT3_Exit
LIT3_NotLPint:

	;---------------------
	;LF Interrupt handling
	;---------------------
	test    Nic.CSR5_image, CSR5_LNF                        ;If Link FAIL - Move to BNC/AUI
	jz      SHORT LIT3_Exit
	
	;If TP - Move to BNC
	;        Move to AUI (if BNC does not exist)
	;-------------------------------------------
	cmp     Nic.SelectedMedia, MediaTP
	jne     SHORT LIT3_NotInTP

	call    MoveToBNC
	jnc     SHORT LIT3_AUIBNCselection
	call    MoveToAUI
	jnc     SHORT LIT3_AUIBNCselection
	clc
	jmp     SHORT LIT3_Exit

LIT3_NotInTP:
	;If AUI/BNC - Move to BNC/AUI
	;         Remain in current medium If no BNC/AUI
	;-----------------------------------------------
	mov     bx, offset CGroup:MoveToBNC
	cmp     Nic.SelectedMedia, MediaBNC
	jne     SHORT LIT3_SwitchPort
	mov     bx, offset CGroup:MoveToAUI
LIT3_SwitchPort:
	call    bx
	jnc     SHORT LIT3_AUIBNCselection      ;Switched AUI/BNC - need to do callback modifications.
	clc                                     ;Didn't switch ports - Exit

LIT3_Exit:
	 pop    si
	 pop    dx
	 pop    bx
	 pop    eax
	 ret

LIT3_AUIBNCselection:
	;--------------------------------------------------------
	;BNC/AUI ports autosensing is based on ctivity sensing in
	;given time intervals
	;--------------------------------------------------------
	;Read and clear SRA
	;------------------
	mov     dx, Nic.CSR12_Address
	in      eax, dx
	or      eax, CSR12_SRA
	out     dx, eax

	;Start Timer
	;-----------
	mov     AutoSenseTimer.TimerType, SPA_Timer
	mov     AutoSenseTimer.TimerValue, SPA_Time
	jmp     SHORT  LIT3_Exit

LinkIsrTULIP3      endp

END_CODE_SEGMENT_RUNTIME

;*******************************************************************************
;                           FASTERNET   AUTOSENSING
;*******************************************************************************

;*******************************************************************************
;   The following describes the Nics and chips supporting autosense and autodetect:
;
; 1. FASTERNET  (DC21140)  - Without MII PHY !!
;       +-----------+---------------------------------+--------------------------+
;       |  DC21140  | Connectors  Relays   SD HW fix  |  AutoDetect  AutoSense   |
;       +-----------+---------------------------------+--------------------------+
;       |  Rev 1.1  |     2          0          n     |    yes          no       |
;       |           |     1          2          n     |    yes          no_op    |
;       |           |     1          1          n     |    yes          no       |
;       |           |     1          1          y     |    yes          yes      |
;       +-----------+---------------------------------+--------------------------+
;       |  Rev 1.2  |     2          0          n     |    yes          yes      |
;       |  & up     |     1          2          n     |    yes          no_op    |
;       |           |     1          1          n     |    yes          yes      |
;       +-----------+---------------------------------+--------------------------+
;
;*******************************************************************************
START_CODE_SEGMENT_INIT


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         FnetPrepareForAsNwayConnection ( )
;
; Description:
;
;
; On Entry:
;
; On Return:
;
;               Flags:
;
;               Note:   Interrupts are enabled.
;
; returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
FnetPrepareForAsNwayConnection  proc

	;-------------------------
	;Fasternet without MII PHY
	;-------------------------

	mov     Phys.AsNway.ASNwayPhy, PHY_TYPE_UNKNOWN
	mov     Phys.AsNway.PowerUpAutosense, offset CGroup:SiaSymAutoDetectFASTERNET
	mov     Phys.AsNway.DynamicAutosense, offset CGroup:SiaSymAutoSenseFASTERNET
	mov     Phys.AsNway.LinkISR,          offset CGroup:NullRoutine

	;-------------------------------------------------------
	;Keep Autosense bit ONLY - since we do not support Nway
	;-------------------------------------------------------
	and     Nic.SelectedOperationMode, NOT (ModeNWAY or ModeAUTODETECT or ModeAUTOSENSE)
	or      Nic.SelectedOperationMode, ModeAUTODETECT or ModeAUTOSENSE

	;-------------------------------------------------------------------------------
	;If Selected operation mode is autosense and the on-board chip is FasterNet
	;then turn-ON ! CSR6<SCR> bit on all the 10MBps "SIA" media (TP AUI and BNC)
	;Otherwize 10MBps activity (when in 10MBps medium) may be inerpreted as 100MBps
	;Link
	;--------------------------------------------------------------------------------
	mov     cx, Nic.MediaPrecedence.NumMedia                  ;Get Num of media to change
	or      cx, cx
	jz      SHORT FPFAN_DoneWithModeAutoSense                 ;If no such media - Exit

FPFAN_AddCSR6_SCR_To10MBpsSIAMedia:                               ;for (Medium in Media Precedence list) do:
	IndexToOffset   MediaPriorityStruc.MediaPriorityList, cx, 1, si              ;Get medium from list
	movzx   si, Nic.MediaPrecedence.MediaPriorityList[si]
	cmp     si, MediaAUI                                      ;is it TP BNC or AUI ?
	jg      SHORT FPFAN_Not10MBpsSIAMedia
	GetMediaEntry   si, si                                    ;If (TP BNC or AUI) then:
	or      Nic.Media[si].CSR6_OM, CSR6_SCR                   ;     enable CSR6<scr>
FPFAN_Not10MBpsSIAMedia:
	loop    FPFAN_AddCSR6_SCR_To10MBpsSIAMedia                ;end loop

FPFAN_DoneWithModeAutoSense:
	;No need do adjust medium since already done in SROM
	;----------------------------------------------------
	ret

FnetPrepareForAsNwayConnection  endp

END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_BIND

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         Sense100BaseTxLinkDC21140
;
; Description:
;
;
;
; On Entry:     Interrupts enabled but may be disabled internally
;
; On Return:
;
;               Flags:
;
;               Note:   Interrupts are enabled.
;
; returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
FIRST_LOOP_FLAG         equ     1
SCRAMBLER_FLAG          equ     2
LINK_ESTABLISED         equ     4
RETRY_FLAG              equ     8

MII100_TICK             equ    30       ; 2.5 ms   (81.9  uS/tick)
MII10_TICK              equ     3       ; 2.5 ms   (819   uS/tick)
SIA10_Tick              equ    12       ; 2.5 ms   (204.8 uS/tick)
FIVE_mSec               equ     2       ;*2.5 ms
ONE_Sec                 equ   400       ;*2.5 ms

Sense100BaseTxVarsSTRUC         struc
	Flags           dw      0
	AssertionTime   dw      0
	TimeOut         dw      0       ; = (3 * AssertionTime)
	FnetCSR6        dd      0
Sense100BaseTxVarsSTRUC         ends

Sense100BaseTxLinkDC21140       proc

	;Initialize Local variables
	;--------------------------
	push    bp
	sub     sp, SIZE Sense100BaseTxVarsSTRUC  ;Notice that Bp is init here since we use
	mov     bp, sp                            ;[bp].<struc>
	mov     (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, RETRY_FLAG            ;Set retry Flag
	push    eax

SBTL_SetScramblerFlagAccordingToDevRev:
	;If FasterNet rev1.1 - reset  Scrambler flag
	;Else                  Set ScramblerFlag
	;-------------------------------------------
	and     (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, NOT SCRAMBLER_FLAG
	cmp     Nic.Rev, CFRV_REV1_1
	je      SHORT SBTL_Fasternet1_1
	or      (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, SCRAMBLER_FLAG
SBTL_Fasternet1_1:

SBTL_First_10_100_SenseLoop:
	;Set First Loop Flag
	;-------------------
	or      (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, FIRST_LOOP_FLAG

SBTL_10_100_SenseLoop:
	;If scrambler is being used then {
	;       T = 5ms                                ;(T - is Link sense continuously minimal assertion Time)
	;       Select 100BaseTx with Scrambler
	;}
	;Else {
	;       T = 1s
	;       Select 100BaseTx without Scrambler
	;------------------------------------------
	mov     eax, Nic.media[SymScr].CSR6_OM                          ;Save Original value
	mov     (Sense100BaseTxVarsSTRUC PTR [bp]).FnetCSR6, eax
	or      Nic.media[SymScr].CSR6_OM, CSR6_SCR                     ;Assume Scarmbler is required
	mov     (Sense100BaseTxVarsSTRUC PTR [bp]).AssertionTime, FIVE_mSec
	test    (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, SCRAMBLER_FLAG
	jnz     SHORT SBTL_DoneSetting100BaseTx
	and     Nic.media[SymScr].CSR6_OM, NOT CSR6_SCR                 ;Wrong assumption - clear scrambler bits
	mov     (Sense100BaseTxVarsSTRUC PTR [bp]).AssertionTime, ONE_Sec
SBTL_DoneSetting100BaseTx:

	;Calculate TimeOut
	;-----------------
	mov     ax, 3
	mul     (Sense100BaseTxVarsSTRUC PTR [bp]).AssertionTime
	mov     (Sense100BaseTxVarsSTRUC PTR [bp]).TimeOut, ax

	;If Nic supports 100BaseTx media - select it
	;If not, Handle it as if link test has failed
	;--------------------------------------------
	cmp     Nic.Media[SymScr].MediaPresence, Present
	jne      SBTL_Handle10BaseTx

	;Select 100BaseTx media
	;----------------------
	cli
	call    MoveToSymScr
	sti
	mov     eax, (Sense100BaseTxVarsSTRUC PTR [bp]).FnetCSR6
	mov     Nic.media[SymScr].CSR6_OM, eax        ;Restore Original value

	;Search for a Link Status asserted for at least 1sec in the following 3 sec.
	;---------------------------------------------------------------------------
	mov     cx,(Sense100BaseTxVarsSTRUC PTR [bp]).TimeOut
					   ;Cx <-loop counter
	mov     bx, cx                     ;Set Contig. assertion time counter

	;Activate the on-chip timer in cyclic mode of 2.5mSec ticks
	;----------------------------------------------------------
	mov     dx,  Nic.CSR11_Address
	mov     eax, MII100_TICK or CSR11_CON
	out     dx, eax

SBTL_100ContinuousAssertionCheck:

	;Read and check for timer expiration (==1Tick)
	;---------------------------------------------
	mov     dx, Nic.CSR5_Address
	in      eax, dx
	test    eax, CSR5_TM
	jz      SHORT SBTL_100TickHandled
	out     dx, eax                                 ;Clear TM  bit
	dec     cx                                      ;1 Tick less
SBTL_100TickHandled:

	;Check 100MBps link status
	;-------------------------
	mov     ax, PHY_TYPE_SYM
	mov     si, MediaSymScr
	call    PhysGetConnectionStatus
	cmp     al, MEDIA_LINK_PASS
	je      SHORT SBTL_100LinkSensed
	mov     bx, cx                                  ;Start all-over again
SBTL_100LinkSensed:

SBTL_100TimeOutCheck:
	;Was link contiguously sensed for T time ?
	;-----------------------------------------
	or      (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, LINK_ESTABLISED               ;Assume successful link establishment
	push    bx
	sub     bx, cx
	cmp     bx, (Sense100BaseTxVarsSTRUC PTR [bp]).AssertionTime
	pop     bx
	jge     SHORT SBTL_Done100ContinuousAssertionCheck
	and     (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, NOT LINK_ESTABLISED           ;Wrong assumption

	;Did we Time-out ?
	;-----------------
	cmp     cx, 0
	jge     SHORT SBTL_100ContinuousAssertionCheck

SBTL_Done100ContinuousAssertionCheck:

	;Stop the timer and clear its Associated CSR5 bit
	;------------------------------------------------
	xor     eax, eax
	mov     dx, Nic.CSR11_Address
	out     dx, eax
	mov     dx, Nic.CSR5_address
	mov     eax, CSR5_TM
	out     dx, eax

	;If Link was established - select 100BaseTx
	;------------------------------------------
	test    (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, LINK_ESTABLISED
	jz      SHORT   SBTL_Handle10BaseTx     ;Link wasn't established - try 10MBps media

	;If Worked W.O scrambler - put scrambler in.
	;-------------------------------------------
	test    (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, SCRAMBLER_FLAG
	jnz     SBTL_Exit
	cli
	call    MoveToSymScr
	sti
	jmp     SBTL_Exit

	;If Nic supports 10BaseTx media - select it
	;If not, Handle it as if 10BaseTx Link has Failed
	;------------------------------------------------
SBTL_Handle10BaseTx:
	or      (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, LINK_ESTABLISED          ;assume link

	cli
	call    MoveToTP
	sti
	jc      SHORT SBTL_10BaseTxLinkFailed

	;Check that 10BaseTx symbol link is asserted (2 consucutive readings) within 1.5T
	;--------------------------------------------------------------------------------
	;Define T according to the selected port since in influence CSR11 TICK time
	;--------------------------------------------------------------------------
	mov     bx, MII10_TICK
	test    Nic.Media[Tp].CSR6_OM, CSR6_PS
	jnz     SHORT SBTL_DoneWith10MBpsMediaClockRate
	mov     bx, SIA10_TICK
SBTL_DoneWith10MBpsMediaClockRate:

	;Set Timer to 1.5T
	;-----------------
	xor     eax, eax
	mov     ax, (Sense100BaseTxVarsSTRUC PTR [bp]).TimeOut
					   ;cx <- amount of assertion Time
	shr     ax, 1                      ;1.5T is the max time (=3/2 T)
	adc     ax, bx                     ;ax = ax div 2 (if LSB==1 -> CF=1)
	and     eax, NOT CSR11_CON         ;Run only Once

	mov     dx, Nic.CSR11_Address
	out     dx, eax

	;Search fo a link during 1.5T
	;----------------------------
SBTL_SearchFor10BaseTxLink:
	xor     bx, bx                               ;Bx - link counter
	mov     cx, 2
SBTL_Sense10BaseTxLink:
	inc     bx                                   ;Assume link
	mov     ax, PHY_TYPE_SIA
	mov     si, MediaTP
	call    PhysGetConnectionStatus              ;Si already holds the Media type
	cmp     al, MEDIA_LINK_PASS
	je      SHORT SBTL_10LinkSensed
	xor     bx, bx
SBTL_10LinkSensed:
	loop    SBTL_Sense10BaseTxLink
	cmp     bx, 2
	je      SHORT SBTL_10BaseTxLinkEstablished

	;Read and check for timer expiration
	;-----------------------------------
	mov     dx, Nic.CSR5_Address
	in      eax, dx
	test    eax, CSR5_TM
	jz      SHORT SBTL_SearchFor10BaseTxLink     ;Not T.O - Try again

	;Timed-out W.O link
	;------------------
SBTL_10BaseTxLinkFailed:
	and     (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, NOT LINK_ESTABLISED

SBTL_10BaseTxLinkEstablished:
	;Stop the timer and clear its Associated CSR5 bit
	;------------------------------------------------
	xor     eax, eax
	mov     dx, Nic.CSR11_Address
	out     dx, eax
	mov     dx, Nic.CSR5_address
	mov     eax, CSR5_TM
	out     dx, eax

	;If (10BaseTx link asserted){
	;       if (First loop){
	;               Reset First loop flag;
	;               goto SBTL_10_100_SenseLoop;
	;       }
	;       else{
	;               Select 10BaseT as the media;
	;       }
	;}
	;else{
	;       if (First loop) {
	;               if (Scrambler Flag) {
	;                       Reset Scrambler Flag;
	;                       goto SBTL_First_10_100_SenseLoop;
	;               }
	;               else{
	;                       Failed selecting Media !!
	;               }
	;       else {
	;               If (Retry Flag) {
	;                       Reset Retry Flag;
	;                       goto SBTL_SetScramblerFlagAccordingToDevRev;
	;               }
	;               else {
	;                       Failed selecting Media !!
	;               }
	;}
	;---------------------------------------------------------
	test    (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, LINK_ESTABLISED
						    ;If (10BaseTx link asserted){
	jz      SHORT SBTL_No10BaseTxLinkEstablished
	test    (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, FIRST_LOOP_FLAG
						    ;        if (First loop){
	jz      SHORT SBTL_Exit
	and     (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, NOT FIRST_LOOP_FLAG
						    ;           Reset First loop flag;
	jmp     SBTL_10_100_SenseLoop               ;           goto SBTL_10_100_SenseLoop;
SBTL_No10BaseTxLinkEstablished:                     ;else{
	test    (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, FIRST_LOOP_FLAG
						    ;       if (First loop){
	jz      SHORT SBTL_NotLinkAndNotFirstLoop
	test    (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, SCRAMBLER_FLAG
						    ;           if (Scrambler Flag) {
	jz      SHORT SBTL_Exit
	and     (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, NOT SCRAMBLER_FLAG
						    ;                   Reset Scrambler Flag;
	jmp     SBTL_First_10_100_SenseLoop         ;                   goto SBTL_First_10_100_SenseLoop;
SBTL_NotLinkAndNotFirstLoop:                        ;           else {
	test    (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, RETRY_FLAG
						    ;           If (Retry Flag) {
	jz      SHORT SBTL_Exit
	and     (Sense100BaseTxVarsSTRUC PTR [bp]).Flags, NOT RETRY_FLAG
						    ;                   Reset Retry Flag;
	jmp     SBTL_SetScramblerFlagAccordingToDevRev  ;               goto SBTL_SetScramblerFlagAccordingToDevRev;

SBTL_Exit:
	mov     bx, (Sense100BaseTxVarsSTRUC PTR [bp]).Flags
						     ;Save Flags in bx

	;Free Local Variables
	;--------------------
	pop     eax
	add     sp, SIZE Sense100BaseTxVarsSTRUC
	pop     bp

	;Set Zero flag if link was establised
	;------------------------------------
	and     bx, LINK_ESTABLISED                 ;Keep Link status flag only
	xor     bx, LINK_ESTABLISED

	ret

Sense100BaseTxLinkDC21140       endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         SiaSymAutoDetectFASTERNET
;
; Description:
;
;               for (i=Nic.MediaPrecedence.NumMedias; i>0; i--) {
;                   CurrentMedia = Nic.MediaPrecedence.MediaPriorityList[i];
;                   if ((CurrentMedia == (MediaTp or MediaSymSCR)
;                        && NOT MediaTpOrSymScrAlreadyTested){
;                       Link = Call Sense100BaseTxLinkDC21140;
;                       if (Link){
;                            Break;
;                       }
;                   }
;                   else{
;                       SelectMedia (CurrentMedia);
;                       WaitForLinkTestToComplete;
;                       Link = Call GetLinkStatus(CurrentMedia);
;                       if (Link){
;                            SelectTheCurrentMedium;
;                            Break;
;                       }
;                   }
;                } End Loop;
;
;                if (! Link){                   ;No Link had been detected on any medium.
;                       SelectTheDefaultMedia
;                }
;
;
; Called at:    Init time
;
; On Entry:     Interrupts disabled but may be enabled inside the routine
;
; On Return:
;               Flags:
;               Interrupts: Disabled
;               Note:   Interrupts are disabled.
;
; returns:
;               DX      Destroyed
;               EAX     Destroyed
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MediaTpOrSymScrAlreadyTested    equ     0

SiaSymAutoDetectFASTERNET       proc

	;------------------------------------------------------------
	;Create MediaTpOrSymScrAlreadyTested local variable on stack
	;------------------------------------------------------------
	push    bp
	sub     sp, 2
	mov     bp, sp
	mov     WORD PTR [bp+MediaTpOrSymScrAlreadyTested], 0

	;---------------------
	;Let the system breath
	;---------------------
	sti

	;-------------------------------------------------
	;for (i=Nic.MediaPrecedence.NumMedias ; i>0; i--) {
	;-------------------------------------------------
	mov     cx, Nic.MediaPrecedence.NumMedia

ADA21140_FindMediaWithLink:
	;--------------------------------------------------------------
	;       CurrentMedia = Nic.MediaPrecedence.MediaPriorityList[i]
	;--------------------------------------------------------------
	IndexToOffset   MediaPriorityStruc.MediaPriorityList, cx, 1, si
	movzx   si, Nic.MediaPrecedence.MediaPriorityList[si]

	;--------------------------------------------------------
	;           if ((CurrentMedia == (MediaTp or MediaSymSCR)
	;                && NOT MediaTpOrSymScrAlreadyTested)
	;               Link = Call Sense100BaseTxLinkDC21140;
	;               if (Link){
	;                    Break;
	;               }
	;           }
	;-------------------------------------------------------
	cmp     si, MediaTP
	je      SHORT ADA21140_MediaTP_or_SymScr
	cmp     si, MediaSymScr
	jne     SHORT ADA21140_MediaNotTpNorSymScr

ADA21140_MediaTP_or_SymScr:
	cmp     WORD PTR [bp+MediaTpOrSymScrAlreadyTested], 0   ;Is this the first time we test Tp or SymScr ?
	jne     SHORT ADA21140_TryNextMedia                     ;No - Link failed on this medium - no need to retest it
	mov     WORD PTR [bp+MediaTpOrSymScrAlreadyTested], 1   ;Mark Meduim tested.

	;Print switching to... Message
	;-----------------------------
	DataAddress     dx, SwitchingBetweenTpSymScr
	call    DisplayMessage
	push    cx
	push    si
	call    Sense100BaseTxLinkDC21140
	pop     si
	pop     cx
	jz      SHORT ADA21140_UseThisMedia             ;Link Established use this media
	jmp     SHORT ADA21140_TryNextMedia
	;-------------------------------------------------------
	;           else{
	;               SelectMedia (CurrentMedia);
	;               WaitForLinkTestToComplete;
	;               Link = Call GetLinkStatus(CurrentMedia);
	;               if (Link){
	;                    SelectTheCurrentMedium;
	;                    Break;
	;               }
	;           }
	;-------------------------------------------------------
ADA21140_MediaNotTpNorSymScr:

	;Print switching to... Message
	;-----------------------------
	push    si
	DataAddress     dx, SwitchingToMessage
	call    DisplayMessage
	shl     si, 1
	mov     dx,  SwitchToMediaTypeMessage[si]
	call    DisplayMessage
	pop     si

	mov     ax, si
	mov     Nic.SelectedMedia, al
	push    bx
	call    GetMediumPhyType
	pop     bx
	call    PhysSetConnection                       ;SI <- Media type  , AX<- Phy Type

	call    WaitForMediaStabilization

	;Get media link status
	;---------------------
	call    PhysGetConnectionStatus                 ;Current media in si , AX - Phy type
	cmp     al, MEDIA_LINK_PASS                     ;       Break;
	je      SHORT ADA21140_UseThisMedia             ;Link Established use this media

ADA21140_TryNextMedia:
	loop    ADA21140_FindMediaWithLink

	;Link was never established - Move to default medium
	;---------------------------------------------------
	movzx   ax, Nic.DefaultMedia
	mov     Nic.SelectedMedia, al
	mov     ax, PHY_TYPE_UNKNOWN
	call    PhysSetConnection

	;Print switching to... Message
	;-----------------------------
	DataAddress     dx, SwitchingToMessage
	call    DisplayMessage
	shl     si, 1
	mov     dx,  SwitchToMediaTypeMessage[si]
	call    DisplayMessage

ADA21140_UseThisMedia:
ADA21140_Exit:
	;--------------------------------------------
	;Make appropriate preperations for auto-sense
	;--------------------------------------------
	;If Board is Not AutoSense capable then clear the AutoSense/AutoDetect bit
	;Since The operation has been completed for good.
	;-------------------------------------------------------------------------
	cmp     Nic.AutoSenseCapable, AUTOSENSE_CAPABLE
	je      SHORT ADA21140_NicIsAutoSenseCapable
	and     Nic.SelectedOperationMode, NOT (ModeAutoDetect or ModeAutoSense or ModeNway)
ADA21140_NicIsAutoSenseCapable:


	;------------------------------------------------------------
	;Free MediaTpOrSymScrAlreadyTested local variable from stack
	;------------------------------------------------------------
	add     sp, 2
	pop     bp

	;------
	;Return
	;------
	clc
	cli
	ret

SiaSymAutoDetectFASTERNET       endp

END_CODE_SEGMENT_BIND

START_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         SIA_SYM_AutoSenseDC21140
;
; Description:
;
; Called at:    Call-back time
;
; On Entry:     Interrupts disabled
;
; On Return:
;               Flags:
;
;               Note:   Interrupts are disabled.
;
; returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SiaSymAutoSenseFASTERNET        proc    near

	;Did AutoSense time arrive
	;-------------------------
	sub     AutoSenseTimer.TimerValue, AES_INTERVAL
	jg      SHORT ASA21140_Exit                     ;Time did not arrive yet -> Exit
	mov     AutoSenseTimer.TimerValue, SPA_Time     ;Initialize the timer

	;------------------------------------------------------------------
	;If current medium does not support Link-Sense - Can't autosense it
	;       return ;
	;end if
	;------------------------------------------------------------------
	movzx   si, Nic.SelectedMedia
	mov     ax, PHY_TYPE_UNKNOWN            ;Let the phy figgure this one out
	call    PhysGetConnectionStatus
	cmp     al, MEDIA_LINK_NOT_SUPPORTED
	jne     SHORT   ASA21140_SelectedMediumIsSensable
	ret
ASA21140_SelectedMediumIsSensable:

	;------------------------------------------------------------------
	;for (Medium in Media Precedence list (Highest priority first)) do:
	;       if LinkSensed (Medium)
	;               break;
	;       end if
	;end loop
	;------------------------------------------------------------------
	mov     cx, Nic.MediaPrecedence.NumMedia                   ;for (Medium in Media Precedence list) do:
ASA21140_SearchForMediaWithLink:
	IndexToOffset   MediaPriorityStruc.MediaPriorityList, cx, 1, si
								   ;Get medium from list
	movzx   si, Nic.MediaPrecedence.MediaPriorityList[si]
	mov     ax, PHY_TYPE_UNKNOWN                               ;Let the phy figure this one out
	call    PhysGetConnectionStatus                            ;If LinkSensed (Medium)
	cmp     al, MEDIA_LINK_PASS                                ;    Break;
	je      SHORT ASA21140_FoundLink                           ;
	loop    ASA21140_SearchForMediaWithLink                    ;end loop

	;-----------------------------------------------------------------------------------
	;If (a link was sensed) then
	;       if (Medium <> Selected) then
	;               switch to this medium since:
	;                       if Current > Selected -> a medium link of higher precedence is Up
	;                       if Current < Selected -> Selected medium link is down
	;       end if
	;Else (No link was sensed):
	;       If (Nic.UserSelectedDefaultMedia) and then (Nic.defaultmedia <> Nic.SelectedMedia)then
	;               mov to default media
	;       Else
	;               stay in the selected medium
	;       endif
	;end if
	;-----------------------------------------------------------------------------------
								   ;Else (No link was sensed):
	cmp     Nic.UserSelectedDefaultMedia, TRUE                 ;If (Nic.UserSelectedDefaultMedia) and then (Nic.defaultmedia <> Nic.SelectedMedia)then
	jne     SHORT ASA21140_NoNeedToChangeSelectedMedia
	movzx   si, Nic.DefaultMedia

ASA21140_FoundLink:
	mov     ax, si                                  ;               Switch to medium
	cmp     al, Nic.SelectedMedia                   ;      if (Medium <> Selected) then
	je      SHORT  ASA21140_NoNeedToChangeSelectedMedia

	mov     Nic.SelectedMedia, al
	mov     ax, PHY_TYPE_UNKNOWN                    ;Let the phy figure this one out
	call    PhysSetConnection

ASA21140_NoLinkWasSensed:
ASA21140_NoNeedToChangeSelectedMedia:
ASA21140_Exit:

	ret

SiaSymAutoSenseFASTERNET        endp

END_CODE_SEGMENT_RUNTIME

;*******************************************************************************
;                           TWINET   AUTOSENSING
;*******************************************************************************
START_CODE_SEGMENT_INIT

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         TwinetPrepareForAsNwayConnection ( )
;
; Description:
;
;       This routine prepares the driver & Hdw for supporting Twinet AS-Nway
;       In-case of twinet1 or ,twinet2 not having TP, we will perform Power-Up
;       autosense ala Tulip3 including SymScr (in Twinet2).
;
;       In twinet2 with TP we will perform Nway.
;       It was intendend to enable the following interrupt at all times:
;       ANC,LP10,LF10,LC100 but due to a hole in 100TX spec -> when in 10BaseT
;       activity may be recognized as 100MBps existance hence getting false link 100
;       detection -> unnecasserry interrupts which slow down the driver and system.
;       work arund to this problem is: when the selected medium is 10MBps one LC100
;       unterrupt will be disabled.
;       What will happen is:
;       1. In TwinetPrepareForAsNwayConnection proc
;               enable CSR7 ANC,LP10,LF10
;
;       2. In AutoDetectNwayTWINET2 proc
;               If (connection had been resolved) then
;                       if connection is 10BaseT or 10BaseT-FD then
;                               Disable LC100  (in Shadow_CSR7)
;                       else
;                               Enable LC100   (in Shadow_CSR7)
;                       endif
;               endif
;
;       3. In LinkIsrNwayTWINET2
;               When Nway configuring =>
;                       If (connection had been resolved) then
;                               if resolved connection is 10BaseT or 10BaseT-FD then
;                                       Disable LC100  (in Shadow_CSR7)
;                               else
;                                       Enable LC100   (in Shadow_CSR7)
;                               endif
;                       endif
;
;               Default =>  Null
;
;       4. In AutoSenseNwayTWINET2
;               Null
;
;
; On Entry:
;
; On Return:
;
;               Flags:
;
;               Note:   Interrupts are enabled.
;
; returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
TwinetPrepareForAsNwayConnection        proc

	push    di
	push    si
	push    cx
	push	bx
	push	ax

	mov     Phys.AsNway.ASNwayPhy, PHY_TYPE_SIA
	cmp     Nic.rev, CFRV_REV2
	jl      TwPFANC_Twinet1

	;--------------------------------------
	;Twinet2 wo TP can only do Power-up AS
	;--------------------------------------
	cmp     Nic.Media[TP].MediaPresence, Present
	je      SHORT TwPFANC_Twinet2WithTP

	;Keep Autosense bit ONLY - since we do not support Nway
	;-------------------------------------------------------
	and     Nic.SelectedOperationMode, NOT (ModeNWAY or ModeAUTODETECT or ModeAUTOSENSE)
	or      Nic.SelectedOperationMode, ModeAUTODETECT or ModeAUTOSENSE

	mov     Phys.AsNway.PowerUpAutosense, offset CGroup:SiaSymAutoDetectTWINET2
	mov     Phys.AsNway.DynamicAutosense, offset CGroup:NullRoutine
	mov     Phys.AsNway.LinkISR,          offset CGroup:NullRoutine
	call    PhysAdjustNonMiiMedium
	jmp     TwPFANC_Exit

	;----------------------------
	;Twinet2 with TP can do NWAY
	;----------------------------
TwPFANC_Twinet2WithTP:
	;Keep Nway bit ONLY - since we support Nway
	;--------------------------------------------
	and     Nic.SelectedOperationMode, NOT (ModeNWAY or ModeAUTODETECT or ModeAUTOSENSE)
	or      Nic.SelectedOperationMode, ModeNway

	;Init autosense/Nway routines entries
	;------------------------------------
	mov     Phys.AsNway.PowerUpAutosense, offset CGroup:AutoDetectNwayTWINET2
	mov     Phys.AsNway.DynamicAutosense, offset CGroup:AutoSenseNwayTWINET2
	mov     Phys.AsNway.LinkISR,          offset CGroup:LinkIsrNwayTWINET2
	mov     Phys.AsNway.ASNwayPhy, PHY_TYPE_SIA

	;Enable Link status interrupts
	;-----------------------------
	or      Nic.Shadow_CSR7, (CSR7_LFE or CSR7_ANE or CSR7_LPE or CSR7_LCE)

	;Init the Medium Nway is done through
	;------------------------------------
	;In twinet2 TP Nway there is a problem where during Nway config no pending XMTs can be
	;Transmitted, this can cause False TX hang detection which causes the chip to reset and
	;enter a loop of Nway <-> Resets.
	;The simple solution - not to check for TX hang during Nway config fails on IPX load
	;test where disconnecting the cable and then stopping the test cause the IPXLOAD test to
	;wait for ever for Trasmits to end hnd hence soft hangs the PC.
	;A solution to the problem is perfom the Nway negotiation while in AUI which is imlementing
	;lieing sends and hence prevents both false TX hang indications and IPXLOAD stuck.
	;-------------------------------------------------------------------------------------------
	call    FakeAUI
	mov     SIANwayMedium, al
	mov     Nic.Media[bx].MediumRoutines.MSelectMedium, offset CGroup:MSelectPointedMediumTwinet2SIANway
	jmp     SHORT TwPFANC_AdjustMedia

	;--------------------------------------------
	;(Twinet1 that has only SIA wo Nway) == Tulip
	;--------------------------------------------
TwPFANC_Twinet1:

	;Keep Autosense bit ONLY - since we do not support Nway
	;------------------------------------------------------
	and     Nic.SelectedOperationMode, NOT (ModeNWAY or ModeAUTODETECT or ModeAUTOSENSE)
	or      Nic.SelectedOperationMode, ModeAUTODETECT or ModeAUTOSENSE

	mov     Phys.AsNway.PowerUpAutosense, offset CGroup:AutoDetectAlgorithmTULIP
	mov     Phys.AsNway.DynamicAutosense, offset CGroup:NullRoutine
	mov     Phys.AsNway.LinkISR,          offset CGroup:NullRoutine

TwPFANC_AdjustMedia:
	call    PhysAdjustNonMiiMedium

	;----------------------
	;Twinet without MII PHY
	;----------------------
	;If Selected operation mode is Nway/autosense   and
	;the on-board chip is TwiNet                    and
	;Media SymScr or Fx are present                 then
	;turn-ON ! CSR6<PCS> bit on all the SIA media
	; (TP TpFD AUI and BNC) for 100Mbps 'Link' detection.
	;--------------------------------------------------------------------------
	;Selected OM is AS/Nway and chip is twinet for shure

	;Start from TpFD
	;---------------
	mov     cx, MediaTpFD

	;Do we have 100Mbps HD media at all ?
	;------------------------------------
	cmp     Nic.media[SymScr].MediaPresence, Present
	je      SHORT TwPFAN_AddCSR6_PCS_To10MBpsSIAMedia
	cmp     Nic.media[BaseFX].MediaPresence, Present
	jne     SHORT TwPFANC_DonePcsSetting

TwPFAN_AddCSR6_PCS_To10MBpsSIAMedia:                               ;for (Medium in Media Precedence list) do:
	mov     si, cx
	GetMediaEntry   si, si                                   ;If (TP BNC or AUI) then:
	or      Nic.Media[si].CSR6_OM, CSR6_PCS                   ;     enable CSR6<PCS>
	dec     cx
	jge     TwPFAN_AddCSR6_PCS_To10MBpsSIAMedia               ;end loop
TwPFANC_DonePcsSetting:
	clc                     ;Clear prev calc residues

TwPFANC_Exit:
	pop	ax
	pop	bx
	pop     cx
	pop     si
	pop     di
	ret

TwinetPrepareForAsNwayConnection        endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         FakeAUI  ( )
;
; Description:
;               Routine fakes BNC/AUI media presence (if absent) by copying
;               TP CSR6 and GEP to AUI entry (SIA values are already set to AUI)
;
; On Entry:
;
; On Return:
;               Flags:
;
;               Note:   Interrupts are enabled.
;
; returns:	ax : media to fake with (BNC/AUI)
;		bx : holds media entry
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
FakeAUI proc

	push    edx
	push    cx
	push    si

	
	;If BNC is Present then work with BNC
	;------------------------------------
	mov	ax, MediaBNC				; ax holds media type
	mov	bx, BNC					; bx holds media entry
	cmp     Nic.Media[BNC].MediaPresence, Present
	je      SHORT FA_Exit                           ;BNC is present - no need to fake it

	;If AUI is Present then work with AUI
	;------------------------------------
	mov	ax, MediaAUI				; ax holds media type
	mov	bx, AUI					; bx holds media entry
	cmp     Nic.Media[AUI].MediaPresence, Present
	je      SHORT FA_Exit                           ;AUI is present - no need to fake it

	;------------------------------------------------------
	;If AUI is Not Present then Fake AUI from TP parameters
	;------------------------------------------------------
	mov     Nic.Media[AUI].MediaPresence, Faked   ;Fake AUI presence
							
	;AUI CSR6_OM is as TP's
	;----------------------
	mov     edx, Nic.media[TP].CSR6_OM
	mov     Nic.media[AUI].CSR6_OM, edx

	;AUI GEP sequence is as TP's
	;---------------------------
	mov     cx, Nic.media[TP].Gep.SequenceCount
	mov     Nic.media[AUI].Gep.SequenceCount, cx
	shl     cx, 1                                     ;Cx - Num of BYTES in GEP sequence
	xor     si, si                                    ;SI - First GPR word
FA_CopyGEPSequence:
	cmp     si, cx                                    ;Do we have another GPR copy to handle?
	je      SHORT FA_DoneCopyGEPSequence
	mov     dx, Nic.Media[TP].Gep.SequenceData[si]    ;Copy the GEP sequence word
	mov     Nic.Media[AUI].Gep.SequenceData[si], dx
	add     si, 2                                     ;Move to next seq. word
	jmp     SHORT FA_CopyGEPSequence
	
FA_DoneCopyGEPSequence:

FA_Exit:
	or      Nic.Media[bx].MediumInternalRegs.CSR14, TWINET2_CSR14_TAS   ;Enable TP Link pulses while in selected media

	pop     si
	pop     cx
	pop     edx
	ret

FakeAUI endp

END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_BIND

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         SiaSymAutoDetectTWINET2  ( )
;
; Description:
;
;
; On Entry:
;
; On Return:
;
;               Flags:
;
;               Note:   Interrupts are enabled.
;
; returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SiaSymAutoDetectTWINET2         proc

	push    ax
	push    dx

	;Check SymScr link status
	;------------------------
	call    MoveToSymScr
	jc      SHORT SSADD21142_DoneWithSymScr

	DataAddress     dx, SwitchingToMessage
	call    DisplayMessage
	DataAddress     dx, SwitchingToSymScrMessage
	call    DisplayMessage

	;Get Phy's medium Link status
	;----------------------------
	mov     si, Nic.SelectedConnectionType
	mov     ax, PHY_TYPE_SYM
	call    PhysGetConnectionStatus
	cmp     al, MEDIA_LINK_PASS
	je      SHORT SSADD21142_Exit
SSADD21142_DoneWithSymScr:

	;Try the SIA media
	;-----------------
	call    AutoDetectAlgorithmTULIP

SSADD21142_Exit:
	pop     dx
	pop     ax
	ret

SiaSymAutoDetectTWINET2         endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         AutoDetectNwayTWINET2 ( )
;
; Description:
;
;
; On Entry:
;
; On Return:
;       Chip's interrups are disabled.
;
;               Flags:
;
;               Note:   Interrupts are enabled.
;
; returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
AutoDetectNwayTWINET2           proc

	pushf
	push    eax
	push	bx
	push    cx
	push    dx
	push    si
	push    bp
	push    WORD PTR 15             ;try 15 * 240m = 3Sec to find a link
	mov     bp, sp

	sti                             ;Let the system breath

	;---------------------------
	;Print starting Nway Message
	;---------------------------
	DataAddress     dx, StartingNwayMessage
	call    DisplayMessage

	;----------
	;Start Nway
	;----------
	mov     Nic.SelectedConnectionType,  ConnectionAutoSenseNway
	call    Mac2PhySetConnection

	;---------------------------------------------
	;Wait for Valid connection indication from MAC
	;---------------------------------------------
	;Valid connection will be recignized by:
	; 1. Nway completion
	; 2. common Medium is a supported medium
	;
	;Try this search for 3 Seconds which is a reasonable amount of time
	;for Nway to complete.
	;-------------------------------------------------------------------
ADNT2_FindValidConnection:
	mov     ax, PHY_TYPE_SIA
	call    PhysGetConnectionType
	jnc     SHORT ADNT2_FoundValidConnection

	;Delay for 240Msec before trying again
	;-------------------------------------
	dec     WORD PTR [bp]
	jz      SHORT ADNT2_DidNotFindValidConnection

	mov     cx, 48000
ADNT2_WaitLoop:
	cli
	call    PostResetDelay          ;Delay for 5uSec
	sti
	loop    ADNT2_WaitLoop
	jmp     SHORT ADNT2_FindValidConnection

	;--------------------------------------
	;Valid connection was found - Handle it
	;--------------------------------------
	;We will do the following:
	; 1. Set the Phy to the resolved connection
	; 2. Set the MAC to the resolved connection
	; 3. Set Nway status variable to Link check for allowing 1 sec of link stabilization
	;------------------------------------------------------------------------------------
ADNT2_FoundValidConnection:

	;Set the Phy to the resolved connection
	;---------------------------------------
	push    ax
	movzx   si, al
	mov     ax, PHY_TYPE_UNKNOWN
	call    PhysSetConnection                       ;Force Phy to the selected connection
	pop     ax

	;Update Selected connection and Nway variables
	;----------------------------------------------
	mov     Nic.SelectedConnectionType, ax
	mov     AutoSenseTimer.TimerType,  LINK_Timer   ;Initialize the timer For Link stab. time
	mov     AutoSenseTimer.TimerValue, LINK_Time
	mov     Phys.AsNway.ASNwayState.OMStatus, NWAY_LINK_CHECK

	;Clear media link interrupts
	;-----------------------------
	mov     dx, Nic.CSR5_Address
	mov     eax, CSR5_ANC                           ;Only ANC is acceptable at this time.
	out     dx, eax

	;Connection Had been resolved - Adjust Link Interrupt bits
	;---------------------------------------------------------
	call    Twinet2NwayAdjustLinkInterruptBits

	;Exit
	;----
	jmp     SHORT ADNT2_DoneWithMediaTesting

	;------------------------------
	; NO Valid connection was found
	;------------------------------
	; No Valid connection will not be printed 
	; if the SIANwayMedium is actually present in the NIc since
	; it may be connected to the network.
	;-----------------------------------------------------------
ADNT2_DidNotFindValidConnection:
	mov	bx, BNC					; bx holds BNC media entry
	cmp	SIANwayMedium, MediaBNC			; Is our SIA Nway medium BNC or AUI ?
	je      SHORT ADNT2_CheckForFake   		
	mov	bx, AUI					; bx holds AUI media entry
ADNT2_CheckForFake:
	cmp     Nic.Media[bx].MediaPresence, Present
	je	SHORT ADNT2_DoneWithMediaTesting
	
	DataAddress     dx, NoMediumFound		; Display the mesage
	call    DisplayMessage

	;-----------------------------------
	;Exit the Power-up autosense routine
	;-----------------------------------
ADNT2_DoneWithMediaTesting:
	add     sp, 2
	pop     bp
	pop     si
	pop     dx
	pop     cx
	pop	bx
	pop     eax
	popf
	ret

AutoDetectNwayTWINET2           endp

END_CODE_SEGMENT_BIND

START_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         AutoSenseNwayTWINET2 ( )
;
; Description:
;       This routine is Called at call-back time and is responsible of
;       Checking the medium link-status when link stabilization time passes
;       (media change is done at Interrupt time)
;
;
; On Entry:
;
; On Return:
;
;               Flags:
;
;               Note:   Interrupts are enabled.
;
; returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
AutoSenseNwayTWINET2    proc

	push    ax
	push    si

	;--------------------------------------------------------
	;We enter this callback only if Nway status is LinkCheck
	;-------------------------------------------------------
	cmp     Phys.AsNway.ASNwayState.OMStatus, NWAY_LINK_CHECK
	jne     SHORT ASNTw_Exit

	;----------------------------
	;Did Link check time arrive ?
	;----------------------------
	sub     AutoSenseTimer.TimerValue, AES_INTERVAL
	jg      SHORT ASNTw_Exit                                ;Time did not arrive yet -> Exit
	mov     AutoSenseTimer.TimerValue, ANC_Time             ;Initialize the timer (just to be safe)

	;Get and check medium link status
	;If LF Restart Nway
	;--------------------------------
	mov     ax, Phys.SelectedPhy
	movzx   si, Nic.SelectedMedia
	call    PhysGetConnectionStatus
	jc      SHORT ASNTw_RestartNway

	cmp     al, MEDIA_LINK_PASS
	jne     SHORT ASNTw_RestartNway

	;If LP -> update Local variables
	;-------------------------------
	mov     Phys.AsNway.ASNwayState.OMStatus, NWAY_COMPLETE

ASNTw_Exit:
	pop     si
	pop     ax
	ret

ASNTw_RestartNway:
	call    Mac2PhySetConnection
	jmp     SHORT ASNTw_Exit


AutoSenseNwayTWINET2    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         LinkIsrNwayTWINET2 ( )
;
; Description:
;       This routine is called at interrupt time and is the hart of the Nway
;       algorithn. The routine does the following:
;
;       Case NwayStatus is :
;               When NWAY_CONFIGURING ->
;                       If ANC Interrupt then
;                               Get resolved connection type
;                               If (Error) then
;                                       restart Nway
;                                       return
;                               Endif
;                               NwayStatus = NWAY_LINK_CHECK
;                               AutoSenseTimer.TimerValue = LINK_Time
;                               Get resolved medium Phy type
;                               If (PhyType == SIA )
;                                       return
;                               else
;                               Call PhysSetConnection (Phy, Medium)
;                               return
;                       EndIf
;               When NWAY_COMPLETED ->
;                       Get Medium Link Status
;                       If (Link Fail)
;                               restart Nway
;                       EndIf
;               Default  ->
;                       return
;       End Case
;
;
;
; On Entry:
;
; On Return:
;
;               Flags:
;
;               Note:   Interrupts are enabled.
;
; returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
LinkIsrNwayTWINET2      proc

	push    ax
	push    si

	;----------------------
	; When NWAY_CONFIGURING
	;----------------------
	cmp     Phys.AsNway.ASNwayState.OMStatus, NWAY_CONFIGURING
	jne     SHORT LISTw_NotConfiguring

	;       ANC Interrupt handling
	;-----------------------------
	test    Nic.CSR5_image, CSR5_ANC                ;Only ANC is acceptable at this time.
	jz      SHORT LISTw_Exit

	;       Get resolved connection type
	;-----------------------------------
	mov     ax, Phys.SelectedPhy                    ;Ax <- Phy type
	mov     si, Nic.SelectedConnectionType          ;SI <- Connection (including Nway indication)
	call    PhysGetConnectionType
	jc      SHORT LISTw_RestartNway

	;Set the Phy to the resolved connection
	;---------------------------------------
	push    ax
	movzx   si, al
	mov     ax, PHY_TYPE_UNKNOWN
	call    PhysSetConnection                       ;Force Phy to the selected connection
	pop     ax

	;       Update Selected connection and Nway variables
	;----------------------------------------------------
	mov     Nic.SelectedConnectionType, ax
	mov     AutoSenseTimer.TimerType,  LINK_Timer   ;Initialize the timer For Link stab. time
	mov     AutoSenseTimer.TimerValue, LINK_Time
	mov     Phys.AsNway.ASNwayState.OMStatus, NWAY_LINK_CHECK

	;Connection Had been resolved - Adjust Link Interrupt bits
	;---------------------------------------------------------
	call    Twinet2NwayAdjustLinkInterruptBits
	jmp     SHORT LISTw_Exit
LISTw_NotConfiguring:

	;-------------------
	; When NWAY_COMPLETE
	;-------------------
	cmp     Phys.AsNway.ASNwayState.OMStatus, NWAY_COMPLETE
	jne     SHORT LISTw_NotComplete

	;       Get Connection Status
	;       If (Status == LF) -> Reastart Nway
	;-----------------------------------------
	mov     ax, Phys.SelectedPhy
	movzx   si, Nic.SelectedMedia                   ;Get Dorced medium status
	call    PhysGetConnectionStatus
	jc      SHORT LISTw_RestartNway

	cmp     al, MEDIA_LINK_PASS
	jne     SHORT LISTw_RestartNway
LISTw_NotComplete:

LISTw_Exit:
	 pop    si
	 pop    ax
	 ret

LISTw_RestartNway:
	;Restart Nway
	;------------
	call    Mac2PhySetConnection
	jmp     SHORT LISTw_Exit

LinkIsrNwayTWINET2      endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:       Twinet2NwayAdjustLinkInterruptBits        proc
;
; Description:
;       This routine Modifies Lwinet2 Link interrupt mask according to the
;       resolved medium when Nway completes.

;       It was intendend to enable the following interrupt at all times:
;       ANC,LP10,LF10,LC100 but due to a hole in 100TX spec -> when in 10BaseT
;       activity may be recognized as 100MBps existance hence getting false link 100
;       detection -> unnecasserry interrupts which slow down the driver and system.
;       work arund to this problem is: when the selected medium is 10MBps one LC100
;       unterrupt will be disabled.
;
; On Entry:
;
;
; On Return:
;               Flags:
;
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Twinet2NwayAdjustLinkInterruptBits      proc

	;---------------------------------------------
	;if connection is 10BaseT or 10BaseT-FD then
	;       Disable LC100  (in Shadow_CSR7)
	;else
	;       Enable LC100   (in Shadow_CSR7)
	;endif
	;---------------------------------------------
	or      NIc.Shadow_CSR7, CSR7_LCE               ;Assume LC100 int is needed
							;Is our assumption correct ?
	cmp     Nic.SelectedMedia, MediaSymScr
	je      SHORT T2NALIB_Done
	cmp     Nic.SelectedMedia, MediaSymScrFD
	je      SHORT T2NALIB_Done
	cmp     Nic.SelectedMedia, Media100BaseFx
	je      SHORT T2NALIB_Done
	cmp     Nic.SelectedMedia, Media100BaseFxFD
	je      SHORT T2NALIB_Done

	;------------------------------------------------------------------------------
	;Selected Medium is either 10MBps one or 100 with meaningless LC int such as T4
	;Disable LC100
	;------------------------------------------------------------------------------
	and     Nic.Shadow_CSR7, not CSR7_LCE

T2NALIB_Done:
	ret

Twinet2NwayAdjustLinkInterruptBits      endp

END_CODE_SEGMENT_RUNTIME



;*******************************************************************************
;                       MII   AUTOSENSE   ROUTINES
;*******************************************************************************
START_CODE_SEGMENT_INIT

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:       MiiPrepareForAsNwayConnection     proc
;
; Description:
;       This routine initializes the driver's autosense routines entries and
;       interrupt bit masks so MII phy autosensing will be performed.
;
;       As for today we have 2 types of MII phys - Classic type and ML6692 type
;       - The ClASSIC type of phys are wholistic phys which can by themselvs support
;       all the media they declare they support or advertize these kined of phys
;       can be treated as "launch and forget" with the nic periodicly monitors them and
;       syncronizes the mac if needed.
;       - The ML6992 Type of phys are phys that implement 100MBps path only while
;         allowing 10MPbs to be routed through them and are being able to advertize
;         10MBps support.
;         These type of Phys need special driver/Mac settings and monitoring and are
;         treated quite diffrently than CLASSIC type of Phys.
;
; On Entry:
;
;
; On Return:
;               Flags:
;
;
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiPrepareForAsNwayConnection   proc

	push	ax
	push	bx

	;----------------------
	;Assume Generic Mii Phy
	;----------------------
	mov     Phys.AsNway.PowerUpAutosense, offset CGroup:MiiAutoDetect
	mov     Phys.AsNway.DynamicAutosense, offset CGroup:MiiAutoSense
	mov     Phys.AsNway.LinkISR,          offset CGroup:NullRoutine

	;Is this a Generic Phy ?
	;-----------------------
	cmp     Nic.MiiPhysList[0].MiiPhySromID, GENERIC_PHY
	je      SHORT MPFANC_Exit                       ;If Generic MII PHY - done

	;-------------------
	;ML6692 Phy handling
	;-------------------
	cmp     Nic.MiiPhysList[0].MiiPhySromID, ML6692
	jne     SHORT MPFANC_Exit


	;ML6692 with Fasternet
	;---------------------
	;only Thing to do is Set the SIA medium to put Decchip to to TP
	;---------------------------------------------------------------
	mov     MiiAsML6692SiaMedium, MediaTP
	cmp     Nic.Dev, FASTERNET
	je      SHORT MPFANC_Exit

	;ML6692 with Twinet or Phyer
	;---------------------------
	;ML6692 has 10 LF interrupt and Interrupt handler.
	;-------------------------------------------------
	mov     Phys.AsNway.LinkISR, offset CGroup:MiiLinkISR_ML6692
	or      Nic.Shadow_CSR7, CSR7_LFE

	;Init the Medium Nway is done through
	;------------------------------------
	;In twinet TP there is a problem where during LF no pending XMTs can be
	;Transmitted, this can cause False TX hang detection which causes the chip to reset and
	;enter a loop of Nway <-> Resets.
	;The simple solution - not to check for TX hang during Nway config fails on IPX load
	;test where disconnecting the cable and then stopping the test cause the IPXLOAD test to
	;wait for ever for Trasmits to end hnd hence soft hangs the PC.
	;A solution to the problem is perfom the Nway negotiation while in AUI which is imlementing
	;lieing sends and hence prevents both false TX hang indications and IPXLOAD stuck.
	;-------------------------------------------------------------------------------------------
	call    FakeAUI
	mov     MiiAsML6692SiaMedium, ax

MPFANC_Exit:

	pop	bx
	pop	ax
	ret

MiiPrepareForAsNwayConnection   endp

END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_BIND

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiAutoDetect   ()
;
; Description:
;       Returns the capabilities of the Phy.
;
; On Entry:
;
;
; On Return:
;               Flags:
;
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiAutoDetect   proc

	pushf
	push    ax
	push    cx
	push    dx
	push    si
	push    bp
	push    WORD PTR 15             ;try 15 * 240m = 3Sec to find a link
	mov     bp, sp

	sti                             ;Let the system breath

	;-------------------------
	;Print an openning message
	;-------------------------
	DataAddress     dx, PerformingMiiPhyAutodetect
	call    DisplayMessage

	;---------------------
	;Set Phy to connection
	;---------------------
	call    Mac2PhySetConnection

	;-------------------------------------------------
	;Wait for Valid connection indication from the Phy
	;-------------------------------------------------
	;Try this search for 3 Seconds which is a reasonable amount of time
	;for nway to complete.
	;-------------------------------------------------------------------
MAD_FindValidConnection:
	mov     ax, PHY_TYPE_MII
	call    PhysGetConnectionType
	jnc     SHORT MAD_FoundValidConnection

	;Delay for 240Msec before trying again
	;-------------------------------------
	dec     WORD PTR [bp]
	jz      SHORT MAD_DidNotFindValidConnection

	mov     cx, 48000
MAD_WaitLoop:
	cli
	call    PostResetDelay          ;Delay for 5uSec
	sti
	loop    MAD_WaitLoop
	jmp     SHORT MAD_FindValidConnection

	;--------------------------
	;Valid connection was found
	;--------------------------
MAD_FoundValidConnection:
	;Update media selection & line speed
	;-----------------------------------
	mov     Phys.AsNway.ASNwayState.OMStatus, NWAY_COMPLETE
	call    MiiAsUpdateConnection

MAD_DoneWithMediaTesting:
	add     sp, 2
	pop     bp
	pop     si
	pop     dx
	pop     cx
	pop     ax
	popf
	ret

	;------------------------------
	; NO Valid connection was found
	;------------------------------
MAD_DidNotFindValidConnection:
	DataAddress     dx, NoMediumFound
	call    DisplayMessage
	jmp     SHORT MAD_DoneWithMediaTesting

MiiAutoDetect   endp

END_CODE_SEGMENT_BIND

START_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiAutoSense   ()
;
; Description:
;
;
; On Entry:
;
;
; On Return:
;               Flags:
;
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiAutoSense    proc

	;-------------------------
	;Did AutoSense time arrive
	;-------------------------
	sub     AutoSenseTimer.TimerValue, AES_INTERVAL
	jg      SHORT MAS_Fin                           ;Time did not arrive yet -> Exit

	;------------------------------------------
	;Call the appropriate MII sutosense routine
	;-----------------------------------------------------------------------------------------
	; As for today we have 2 types of MII Phys
	; Generic Phys - Can automaticlly handle Nway and media selection
	;                While the driver has only to sync the mac with the Phy's
	;                selected connection.
	; ML6692 Phy   - Can handle Nway but needs certian Mac settings while Nway is configuring
	;                or when link failes or media changes.
	;-----------------------------------------------------------------------------------------
	cmp     Nic.MiiPhysList[0].MiiPhySromID, ML6692
	je      SHORT MAS_HandleML6692PhyType

	call    MiiAutoSense_Generic
	jmp     SHORT MAS_Exit

MAS_HandleML6692PhyType:
	call    MiiAutoSense_ML6692

MAS_Exit:
	;Schedule Mii autosense callback according to Nway status
	;---------------------------------------------------------
	mov     AutoSenseTimer.TimerValue, MII_Time     ;Initialize the timer as if Nway is complete
	cmp     Phys.AsNway.ASNwayState.OMStatus, NWAY_COMPLETE
	je      SHORT MAS_Fin
	mov     AutoSenseTimer.TimerValue, MII_NwayConfigTime
MAS_Fin:
	ret

MiiAutoSense    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiAsUpdateConnection
;
; Description:
;
;
; On Entry:
;
;
; On Return:
;               Flags:
;
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiAsUpdateConnection   proc

	push    ax
	push    bx
	push    dx
	push    si

	;-----------------------------
	;Get New Connection's Phy type
	;-----------------------------
	mov     si, ax
	call    GetMediumPhyType
	jc      SHORT MAUC_RestartNway                  ;If no such Phy - Restart Nway

	;---------------------------------------------------
	;If same connection as before - No update is needed
	;---------------------------------------------------
	push    ax
	mov     ax, si
	cmp     al, Nic.SelectedMedia
	pop     ax
	je      SHORT MAUC_Exit

	;--------------------------------
	;Update Nic's connection variable
	;--------------------------------
	push    ax
	mov     ax, si
	mov     Nic.SelectedMedia, al                                   ;Update the selected media
	and     Nic.SelectedOperationMode, ModeAUTOSENSE or ModeNWAY    ;Keep autosense bits
	or      Nic.SelectedOperationMode, ah
	pop     ax

	;------------------------------------------------------
	;Handle phy/media update according to meduim's phy type
	;------------------------------------------------------
	cmp     ax, PHY_TYPE_MII
	jne     SHORT MAUC_NotMiiPhy

	;----------------------------
	;Medium's phy type is Mii Phy
	;----------------------------
	pushf
	cli
	call    SetInternalPhyToConnection              ;Update internal Phy (our chip regs)
	popf
	jmp     SHORT MAUC_Exit

	;-------------------------------
	;Medium's phy type is SIA or SYM
	;-------------------------------
MAUC_NotMiiPhy:                                         ;Set the Non MII phy to connection
	call    PhysSetConnection

MAUC_Exit:
	pop     si
	pop     dx
	pop     bx
	pop     ax
	ret

	;------------
	;Restart Nway
	;------------
MAUC_RestartNway:
	call    Mac2PhySetConnection
	jmp     SHORT MAUC_Exit

MiiAsUpdateConnection   endp


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiAutoSense_Generic   ()
;
; Description:
;
;
; On Entry:
;
;
; On Return:
;               Flags:
;
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiAutoSense_Generic    proc

	push    ax

	mov     ax, PHY_TYPE_MII
	call    PhysGetConnectionType                           ;If failed to get connection then
	jc      SHORT MASG_ErrorExit                            ;   try next time

	mov     Phys.AsNway.ASNwayState.OMStatus, NWAY_COMPLETE ;Mark: Nway is complete
	call    MiiAsUpdateConnection

MASG_Exit:
	pop     ax
	ret

MASG_ErrorExit:
	mov     Phys.AsNway.ASNwayState.OMStatus, NWAY_CONFIGURING        ;Mark: Nway is configuring
	jmp     SHORT MASG_Exit

MiiAutoSense_Generic    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiLinkISR_ML6692   ()
;
; Description:
;       Routine to catch 10MBps (SIA) LF interrups in order to speed-up
;       ML6692 Nway handling.
;
; On Entry:
;
;
; On Return:
;               Flags:
;
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiLinkISR_ML6692       proc

	mov     AutoSenseTimer.TimerValue, AES_INTERVAL ;Initialize the timer
	call    MiiAutoSense                            ;Fake an Autosense callback
	ret

MiiLinkISR_ML6692       endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiAutoSense_ML6692   ()
;
; Description:
;
;
; On Entry:
;
;
; On Return:
;               Flags:
;
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiAutoSense_ML6692     proc

	push    ax
	push    bx
	push    si

	;------------------------------------------
	;Switch (Phys.AsNway.ASNwayState.OMStatus)
	;       Case NWAY_CONFIGURING   ->
	;       Case NWAY_COMPLETE      ->
	;       Default                 -> Exit
	;------------------------------------------
	cmp     Phys.AsNway.ASNwayState.OMStatus, NWAY_CONFIGURING
	je      SHORT MASML_NwayConfiguring

	cmp     Phys.AsNway.ASNwayState.OMStatus, NWAY_COMPLETE
	je      SHORT MASML_NwayComplete

	;Default -> Exit
	;---------------
	jmp     SHORT MASML_Exit

	;----------------
	;Nway configuring
	;----------------
MASML_NwayConfiguring:
	mov     ax, PHY_TYPE_MII
	call    PhysGetConnectionType
	jc      SHORT MASML_Exit
	mov     Phys.AsNway.ASNwayState.OMStatus, NWAY_COMPLETE

	;Update our connection and connection variables
	;----------------------------------------------
	call    MiiAsUpdateConnection
	jmp     SHORT MASML_Exit

	;-------------
	;Nway Complete
	;-------------
MASML_NwayComplete:

	;--------------------------------------------------------------------
	;
	;If ((MiiPhyGetConnectionStatus (&ConnectionStatus)) == FAILED) then
	;       Restart Nway
	;else
	;       if (ConnectionStatus != LP) then
	;               Restart Nway
	;       else
	;          if ((MiiGetConnectionType (&ConnectionType)) == FAILED) then
	;               Restart Nway
	;          else
	;             if (ConnectionType != Nic.SelectedConnection) then
	;               Restart Nway
	;          endif
	;       endif
	;endif
	;--------------------------------------------------------------------
	;Tests performes on ML6692 with Twinet2 show LP test is not needed
	;for Nway to correctly complete or restart this is why its commented out.
	;I left it here for showing the full implementation of the algorithm
	;------------------------------------------------------------------------
	;mov     ax, PHY_TYPE_MII
	;mov     si, Nic.SelectedConnectionType
	;call    PhysGetConnectionStatus
	;jc      SHORT MASML_RestartNway

	;cmp    al, MEDIA_LINK_PASS
	;jne    SHORT MASML_RestartNway

	;If NOT the same connection as before -> Restart nway
	;----------------------------------------------------
	mov     ax, PHY_TYPE_MII
	call    PhysGetConnectionType
	jc      SHORT MASML_RestartNway

	mov     si, ax
	call    GetMediumPhyType
	jc      SHORT MASML_RestartNway                  ;If no such Phy - Restart Nway

	mov     ax, si
	cmp     al, Nic.SelectedMedia
	jne     SHORT MASML_RestartNway

MASML_Exit:
	pop     si
	pop     bx
	pop     ax
	ret

MASML_RestartNway:
	call    Mac2PhySetConnection
	mov     Phys.AsNway.ASNwayState.OMStatus, NWAY_CONFIGURING        ;Mark: Nway is configuring
	jmp     SHORT MASML_Exit

MiiAutoSense_ML6692     endp

END_CODE_SEGMENT_RUNTIME

