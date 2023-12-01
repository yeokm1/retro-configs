PAGE    ,132
NAME    TXHANG_AVOIDANCE
TITLE   TXHANG_AVOIDANCE  --  Digital Internal Use Only

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
; This file contains all of the routines which implement the DC21040
; Transmit hang and Receive hang avoidance algorithms.
;
; Maintainers:
;       eg      Eric Goldstein
;       ymf     Yishai Fraenkel
;       as      Adi Shaliv
;	de	Dror Efraty
;
; Revision History:
;
; 11-May-1994   eg      Syntax changes for MASM 6.1.
;
; 18-Aug-1994   ymf     Using autosens.asm as basis for TxHang avoidance routine
;
; 08-Sep-1994   ymf     Add Rxhang avoidance algorithm
;
; 20-Apr-1995   ymf     Add TULIP3 autodetection code
;
; 05-Sep-1995   as      Add Fasternet autosense code
;
; 31-Oct-1995   as      Add call to MiiPhyAutosense if MiiPhy present
;
; 13-Jan-1996   as      Add call to Mac2PhySetMac that change media without
;			reset to chip.
;
; 12-Feb-1996   as      Add support for DC21142 (Twinet)
;			for now No twinet Autosense support, gust MII Phy autosense
;
; 17-Nov-1996	de	Move Tulip3 autosense support to MAC2PHY
;
; 25-Nov-1996	de	Changes in include file names, and in AWK conventions.
;---------------------------------------------------------------------------

.xlist                                  ; disable listing the include file
include seg_defs.inc
include macro.inc
include dc_regs.inc
include nic.inc
include macrcv.inc
include driver.inc
include sss.inc
include txhang.ash
.list                                   ; enable listing
.386

;
;Local equate
;
AUTOSENSE_DISABLE       EQU     0FFFFh  ; Value indicating autosense counter
					; is irrelevant.
AUTOSENSE_ENABLE        EQU     0       ; Value indicating counter is relevant

TX_HANG_VALUE   	EQU     19    ; TX hang threshold value: approx. 1 second
RX_HANG_VALUE   	EQU     19    ; RX hang      -"-             -"-
NO_RX_HANG		EQU	0
POSSIBLE_RX_HANG	EQU	1
AUTOSENSE_ALARM 	EQU     40    ; AUTOSENSE timer should activate every 2 secs
MAC2PHYAUTOSENSE_ALARM	EQU     10    ; Mac2Phy AUTOSENSE timer should activate every 500 msecs

START_DATA_SEGMENT_RUNTIME

TxHangCounter   DW  ?         ; Timer ticker. high value indicates txhang
TxNumOfHangs    DW  ?         ; Num of hangs. Mainly for debug purposes

RxHangCounter   DW  ?         ; Timer ticker. high value indicates rxhang
RxNumOfHangs    DW  ?         ; Num of hangs. Mainly for debug purposes

TotalReceived   DD  0

RxStatus	DB  NO_RX_HANG

AutosenseCounter  DW  AUTOSENSE_DISABLE ; Default value: autosense disabled

AutoSavedDOSVector     LONG_PTR         {0, 0}

END_DATA_SEGMENT_RUNTIME

START_CODE_SEGMENT_RUNTIME

	PAGE
;********************
;* TxHgTimerHandler *
;********************
;
; This function serves as the ISR for the timer tick. This routine services
; both DOS and OS/2. The entry and exit of the function are defined in macros
; much like in MACISR.ASM. Theses macros are defined in MACRO.ASH.
;
; DOS: Called as INT 1C timer tick handler
;
; OS/2: Callback set in devhlp TickCount call
;
; Algorithm:
; BEGIN
;    OS specific entry stuff
;    if adapter is closed
;	exit
;    if inside the interrupt service routine
;       exit (to avoid reseting the chip while in isr)
;    if TULIP3 autosensing:
;       If active media is TP - Donothing.
;       Else
;            Resd SRA (saying about receive activityin last two seconds)
;    else if FASTERNET autosense:
;      If MiiPhy present:
;          MiiPhyAutosense
;      else
;        for(i= NumOfParticipASMedias; i>0; i--)
;        {
;          if (Active Bit Valid && media[i] Link Sense) {
;              MoveToMedia i;
;              break;
;          }
;        }
;        if (No media Link Sense) {
;           MoveToMedia Nic.DefaultMedia
;        }
;    else TWINET autosense
;	TwinetAutoSense
;
;    If (TxHangCounter > 0)
;       TxHangCounter++
;       Check TU bit in CSR5. If Set -
;          TxHangCounter = 0;
;       If TxhangCounter > 18 (Approx. - More than 1 second has lapsed)
;          Reset and reenable TULIP. (Using PortUpdateFilter).
;    If (RxHangCounter > 0)
;       RxHangCounter++;
;    If RxhangCounter > 18 (Approx. - More than 1 second has lapsed)
;       1. Set RxHangCounter to 0.
;       2. If ownership of current RcvDesc is host - Reset & reenable TULIP
;    OS specific exit stuff
; END

	public	timer_isr
timer_isr:
	ENTER_TIMER_HANDLER

	pushad

        test NDISServiceStatus.sss_macstat._loword, SSS_OPEN
        jz   timer_exit                      ; If MAC is closed bag out

	cmp  InterruptSemaphore, 0   		; If inside the ISR bag out
	jne  timer_exit

; -- Select chip 1
	cmp	Nic.Dev, TULIP
	je	SHORT TxHangCheck	;If DC21040 chip - no need for Autosense


; -- Is Autosense enabled ? --
	cmp     AutosenseCounter, AUTOSENSE_DISABLE
	je	SHORT TxHangCheck

CheckMac2PhyTimerExpiration:
	cmp     AutosenseCounter, MAC2PHYAUTOSENSE_ALARM
	jge     ExecuteMac2PhyAutosense
	inc     AutosenseCounter
	jmp     TxHangCheck

;----------------------------------
;   TULIP3/FASTERNET/TWINET autosensing
;----------------------------------
ExecuteMac2PhyAutosense:
	call 	Mac2PhyAutosense
	mov     AutosenseCounter, AUTOSENSE_ENABLE      ; Enable counter


;----------------------
;    TX hang stuff
;----------------------
TxHangCheck:
	cmp  TxHangCounter, 0   ; If counter=0 nothing to be done
	je   RxHangCheck

	inc  TxHangCounter      ; Increment TxHangCounter

	mov  dx, Nic.CSR5_Address         ; If CSR5 TU bit set - Zero TxHangCounter
	in   eax, dx
	test eax, CSR5_TU
	jz   Check_Hang         ; Jump if clear
	mov  eax, CSR5_TU       ; If set: (1) Clear TU bit.
	out  dx, eax
	mov  TxHangCounter, 0       ;         (2) Set TxHangCounter to 0.
	jmp  RxHangCheck

Check_Hang:
	cmp  TxHangCounter, TX_HANG_VALUE  ; See if Tx machine hangs
	jbe  RxHangCheck                   ; If not - Exit

	mov  TxHangCounter, 0              ; If Yes:(1) Zero TxHangCounter.
	inc  TxNumOfHangs                  ;        (2) Inc hangs counter
	call PortUpdateReceiveFilter       ;        (3) reset Chip.

;----------------------
;     RX hang stuff
;-----------------------

RxHangCheck:
	cmp  RcvIndicationSemaphore, 0	; If indications are disabled
	jne  Timer_Exit			; Don't check RxHang

	;Claculate the Total number of received packets
	;----------------------------------------------
	mov  eax, NDISServiceStatus.sss_hard_err ;
	add  eax, NDISServiceStatus.sss_frames_rx ;

	cmp  eax, TotalReceived
	jne  Timer_no_rx_hang

	inc  RxHangCounter      ; Increment RxHangCounter
	cmp  RxHangCounter, RX_HANG_VALUE  ; See if counter too large
        jbe  Timer_Exit                    ; If not - Exit

	;if the same - check if Rx packet has been received
	;--------------------------------------------------
	mov  si, RcvCurrentDescriptor      ;         If Curr receive descriptor
	test DWORD PTR [si].RCV_DESCRIPTOR.RDES0, RDES0_M_OWN;  not host owned -
	jnz  Timer_no_rx_hang

	;Check if the receieved packet wasn't processed
	;----------------------------------------------
	cmp	RxStatus, POSSIBLE_RX_HANG
	je	SHORT Timer_hang_occured

	mov	RxStatus, POSSIBLE_RX_HANG
	jmp 	SHORT Timer_Exit

	;Create an interrupt by stopping the Tx machine and starting it again
	;--------------------------------------------------------------------
Timer_hang_occured:
	inc  RxNumOfHangs                  ; Inc RxHangs counter
	call GenerateTUInterrupt
	SET_ADAPTER_INTERRUPT		; enable the TU interrupt

Timer_NoNeedToWriteCSR6:

Timer_no_rx_hang:
	mov  RxStatus, NO_RX_HANG
	mov  TotalReceived, eax
	mov  RxHangCounter, 0

Timer_Exit:

	popad
	EXIT_TIMER_HANDLER


END_CODE_SEGMENT_RUNTIME

END
