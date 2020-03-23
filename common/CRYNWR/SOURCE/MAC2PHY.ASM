;*******************************************************************************
;
; MAC2PHY.ASM
;
; Source file for Dec Fast Ethernet board that holds information
; and supporting routines for its MAC interface to the Physical (world).
; The purpose of this file is to hide the different MAC-PHY interface
; schemes from the above SW.
; The Upper driver layer Needs to know which media and operation mode to select
; and not how to select them.
;
; Limitations:
;       1. No Nic implementing with both MiiPhy and SymScr.
;           As for today we do not support Nics implemrnting both MiiPhy and SymScr
;           at the same time.
;
;       2. No Dynamic Autosense between MiiPhy and SIA
;           As for today we do not support dynamic autosensing between an Mii Phy
;           and SIA media.
;
; Written by:   Moti Haimovsky
; Date:         19-Aug-1995
;
;
; Copyright (C) 1994 by Digital Equipment Corporation
; All rights reserved.
;
; Modification History:
;
; By              Date        Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; Moti Haimovsky  31-Oct-1995 2.20 -Modified MII phy GPR reset seq. and
;                                   Mii phy GPR sequence to word array handling
; Moti Haimovsky   2-Nov-1995      -Fixed bug in GetMediumPhyType
; Moti Haimovsky   6-Nov-1995      -Added stopping the Tx machine in WritCSR6 if
;                                   CSR6<TTM> is being changed.
; Moti Haimovsky   7-Nov-1995      -Modified Mac2PhyCheckAndAdjustSelectedConnection
;                                   and ConvertConnectionToPhyCapabilitiesBitMask
;                                   routines
; Moti Haimovsky  13-Nov-1995      -Fixed bug in Mac2PhyCheckAndAdjustSelectedConnection
;                                   when thesting OM to be autosense.
; Moti Haimovsky  13-Nov-1995      -Modified Mac2PhyCheckAndAdjustSelectedConnection routine
;                                   To modify Connection AutosenseTp to hold Autosense
;                                   OperationMode and First Valid medium found since its
;                                   values are going to be written to CSR6 and MAC regs in
;                                   DriverReset PRIOR of performing autosense and we wand these
;                                   values to be legal.
; Moti Haimovsky  14-Nov-1995      -Fixed bug in WriteCSR6 when calling to WriteSIARegs with
;                                   uninitialized AX and SI (Tulipx only)
; Moti Haimovsky  16-Nov-1995      -Added stopping the Rx and Tx machines in WritCSR6 if
;                                   CSR6<TTM> or CSR6<FD> are to be changed.
; Moti Haimovsky  21-Nov-1995      -Removed DC chip type checking in Mac2PhyInit
; Moti Haimovsky  26-Nov-1995      -Modified Mac2PhyCheckAndAdjustSelectedConnection to check
;                                   If an MII PHY is autosense capable when selected connection
;                                   is autosense.
; Moti Haimovsky  21-Dec-1995 2.30 -Fixed bug in PrepareChipForCSR6Modifications - Not saving the
;                                   original CSR6 value and hence - no  knowledge on TX an RX
;                                   machines status.
; Moti Haimovsky  16-Sep-1996 2.42 -Modified CreateNicWorkingEnvironment procedure to identify
;				    the presence of a ML6692 Mii Phy.
; Moti Haimovsky  27-Oct-1996 2.50 -Modified Mac2Phy to be a separate compilation unit.
; Moti Haimovsky  17-Nov-1996      -Added ErrorRoutine to be used in an ininitialized routine entries.
; Moti Haimovsky  08-Jan-1997 2.60 -Combined FD and LineSpeed modifications handling to One routine
;				    called Post_SetConnection imlemented in dc21x4.
; Moti Haimovsky  15-Jun-1997 	   -Modified PerformExternalReset routine to wait 500mSec for RESET to complete.
;*******************************************************************************

;******************************************************************************
;*                               MAC to Physical interface                    *
;******************************************************************************
;
;                               IEEE 802.3: ETHERNET
;                               ====================
;
;          +-----------------------------------------------------------+   ---
;          |               Logical Link Control (LLC)                  |    ^
;          +-----------------------------------------------------------+    |
;          |               Media Access Control (MAC)                  |    |
;          +-----------------------------------------------------------+    |
;          |                 Physical Signaling (PLS)                  |    |
;          +--------------------------++-------------------------------+   DTE
;     ^                               || Attchment Unit                     |
;     |                               || Interface, (AUI)                   |
;     |    +--------------------------++-------------------------------+    |
;    MAU   |             Physical Medium Attachment (PMA)              |    v
;     |    +--------------------------++-------------------------------+   ---
;     |                               || Medium Dependent
;     v                               || Interface, (MDI)                   Medium
;    ==========================================================================
;
;
;                          PMA, (real life), connectivity
;                          ------------------------------
;
;                             +--------------------+
;                             |         MAC        |
;                             +---------++---------+
;                                       || 7 wires interface
;                                       ||
;                               +-------++-------+
;                               |      SIA       |
;                               +-------++-------+
;                                  AUI  ||              Coax Transciver Interface
;                     (Usually 3 paires)||========================
;                                  +----++----+
;                                  |    TPI   |============
;                                  +----------+       RJ45 Interface 2 pairs
;
; PMA supports:
;       - 10Base5: Thick coax.
;       - FOIRL
;       - 10Base2: Thin coax.
;       - 10Beoad36: Broadband coax.
;       - 1Base5: 1Mb/s over TP.
;       - 10Base10FO: Fiber optic (3 types of fiber: FP-Passive, FB-Sync, FL-Async).
;       - 10Base-T: UTP.
;               Includes link integrity test: Link pulses, The base for NWAY:
;                       - When there is nothing to XMT TD=TP_IDLE
;                       - TP_IDLE:
;                         - Every Xms a pulse is sent
;                         - link_test_max > X >link_test_min
;                       - if no link is received and no activity is seen
;                         for link_loss_timer ms, the link fails
;                       - From link fail to Link pass:
;                         - Activity on RD.
;                         - lc_max link pulses were received.

;
;                               IEEE 802.3u:100Base-T
;                               =====================
;
;          +-----------------------------------------------------------+
;          |                         LLC                               |
;          +-----------------------------------------------------------+
;          |                         MAC                               |
;          +---+---------+-----+--------------+-----+--------------+---+
;              |   PLS   |     |Reconciliation|     |Reconciliation|
;              +---++----+     +------++------+     +------++------+
;               AUI||              MII||                MII||
;                  ||          +------++------+     +------++------+  ---
;                  ||          |     PLS      |     |     PCS      |   ^
;           +------++------+   +------++------+     +--------------+   |
;           |     PMA      |       AUI||            |     PMA      |  PHY
;           +------++------+          ||            +--------------+   |
;                  ||          +------++------+     |     PMD      |   v
;                  ||          |     PMA      |     +------++------+  ---
;                  ||          +------++------+            ||
;               MDI||              MDI||                MDI||
;                  ||                 ||                   ||            Medium
;       =====================================================================
;               1/10MBps             10MBps              100MBps
;

;                            100Base-T Terminology
;                            ---------------------
; 100Dase-T
;       The standatd of CSMA/CD at 100Mb/s.
;
; 100Base-T4
;       A specific PHY layer (PCS+PMA+PMD) for 100Mb/s over 4 pairs UTP3.
;       Half-Duplex only.
;
; 100Base-X
;       A specific PCS and PMA.
;       Supports 100Base-T MII, repeater and Nway.
;       Preserves full duplex behaviour of underlying PMD channels.
;       Supports UTP5,STP and Fiber cables.
;
; 100Base-TX
;       A specific PHY layer (PCS+PMA+PMD) for 100Mb/s over 2 pairs UTP5 & STP.
;       PCS & PMA are 100Base-X.
;       100Base-TX = 100Base-X + TP-PMD
;
; 100Base-FX
;       A specific PHY layer (PCS+PMA+PMD) for 100Mb/s over Fiber
;       PCS & PMA are 100Base-X.
;       100Base-FX = 100Base-X + FDDI PMD  (Fiber)
;
;
;******************************************************************************

;******************************************************************************
;*                               DC_MAC Architecture                          *
;******************************************************************************
;
;
;                                   DC21X4 (Main)
;                                   -------------
;
;         +------------------------------------------------------------------+
;         |                             DC_MAC                               |
;         +------------------------------------------------------------------+
;  Variuos PHY
;  Interface
;
;         +-------------+   +-------------+   +-------------+  +-------------+  --------------
;         |    CSR6     |   |    CSR6     |   |    CSR6     |  |    CSR6     |              ^
;    ---- +-------------+   +-------------+   +-------------+  +-------------+ ---       DC21x4
;    ^    |    CSR12    |   | CSR15 CTRL  |   | CSR12 CTRL  |  | CSR12 CTRL  |  GEP      Internal
;   SIA   +-------------+   +-------------+   +-------------+  +-------------+ Registers  (MAC)
;Registers|    CSR13    |   | CSR15 DATA  |   | CSR12 DATA  |  | CSR12 DATA  |   v       Registers
;         +-------------+   +-------------+   +-------------+  +-------------+ ---------------
;         |    CSR14    |         || MII            ||               ||                     ^
;         +-------------+         || I/F            ||               ||===============++    |
;    v    |    CSR15    |    +----------+     SIA   ||        MII    ||        SYM/SCR|| External
;    ---- +-------------+    | MII PHY  |  Interface||      Interface||               ||  (PHY)
;       SIA     ||           +----------+                        +---------+     +---------+|
;    Interface  ||                ||                             | MII PHY |     |   PHY   ||
;                                 ||                             +---------+     +---------+|
;                                                                    ||               ||    |
;                                                                                           V
;          Tulip 2,3  and      Twinet with       Fasternet                Fasternet
;    Twinet (in 10Mbps mode)    MII PHY        (WO MII PHY)       (with MII or SYM/SCR PHY)
;    -----------------------  -------------    ------------       -------------------------
;******************************************************************************

;******************************************************************************
;                     10/100 Mb/s Entity Relationship Diagram
;                     ---------------------------------------
;
;                               +---------------------+
;                               |                     |
;                               |      MAC entity     |
;                               |                     |
;                               +---------------------+
;                                     ||
;                                     ||
;                                +----||---+
;                                | +---------+
;                                | | +---------+
;                                | | |   PHY   |
;                                +-| |  entity |
;                                  +-|         |
;                                    +---------+
;                                         |
;                                         |
;                                    +---------+
;                                    |         |
;                                    |   MAU   |
;                                    |         |
;                                    +---------+
;                                         |
;                                         |
;                                    +---------+
;                                    |         |
;                                    |   NWAY  |
;                                    |         |
;                                    +---------+
;
;******************************************************************************

;******************************************************************************
;                     		Mac2Phy structure
;                     		-----------------
;
;                +-------------------------------------------------------+
;                |                     MAC entity			 |
;                |                               			 |
;                |                    (Mac2Phy.inc) 		         |
;                +-------------------------------------------------------+
;                                          ||           Phys.inc
;              	        +-----------------------------------------+
;              	        |              Phys entity	     	  |
;              	        |                                 	  |
;              	        |(Includes Internal Phy handling routines)|
;              	        +-----------------------------------------+
;                                          ||
;                                          ||
;          Phy       ++====================++====================++
;          Entities  ||Mii_Gen.Inc         ||Sym_Gen.inc         ||Sia_Gen.Inc
;             +---------------+	    +---------------+	  +---------------+
;             |    MII Phy    |     |    SYM Phy    |     |    SIA Phy    |
;             |(External &    |     |               |     |           	  |
;             | Internal   )  |     |(Internal only)|     |(Internal only)|
;             +---------------+	    +---------------+	  +---------------+
;                    ||   		 ||                      ||
;                    ||                  ||                      ||
;            +------------+       +------------+           +-----------+
;            | +------------+    | +------------+         | +------------+
;            | |    MAU     |    | |    MAU     |         | |    MAU     |
;            | |MII_Phy.Inc |    | |            |         | |            |
;            + |DC_Media.inc|    + |DC_Media.inc|         | |DC_Media.inc|
;              +------------+      +------------+           +------------+
;                    ||                  ||                      ||
;                    ||                  ||                      ||
;               +---------+              ||                 +----------+
;               |         |              ||                 |          |
;               |   NWAY  |              ||                 |   NWAY   |
;               |         |              ||                 |          |
;               +---------+              ||                 +----------+
;                    ||                  ||                     ||
;                    ||                  ||                     ||
;                    ||                  ||                     ||
;
;******************************************************************************

;******************************************************************************
;*                        INCLUDE FILES USED BY MAC2PHY                       *
;******************************************************************************
include	 Seg_Defs.inc
.386
include	 Nic.inc
.8086
include	 MAC2PHY.ASH
.386
include	 DC_Regs.inc
include  DC_Media.inc
include	 Phys.inc
include  AutoSens.inc         ;Holds AutoSense and AutoDetect handling routines
include  Mii_Gen.inc
include  SIA_Gen.inc
include  SYM_Gen.inc

;******************************************************************************
;*                              MAC2PHY  VARIABLES                            *
;******************************************************************************
START_DATA_SEGMENT_RUNTIME

	even
Phys	PhysSTRUC <>

END_DATA_SEGMENT_RUNTIME

;******************************************************************************
;*                        MAC to PHY  External Routines                       *
;******************************************************************************
;	PROC	Mac2PhyInit
;	PROC	Mac2PhyCheckAndAdjustSelectedConnection
;	PROC	Mac2PhySetConnection
;	PROC	Mac2PhyGetConnectionStatus
;	PROC	Mac2PhyLinkHandler
;	PROC	Mac2PhyAutodetect
;	PROC	Mac2PhyAutosense
;******************************************************************************

START_CODE_SEGMENT_INIT

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         Mac2PhyInit             proc
;
; Description:
;               Initializes the MAC module.
; On Entry:
;               NIC already containes the SROM parsed data
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
Mac2PhyInit             proc

	;-----------------------------
	;Perform external system reset
	;-----------------------------
	call    PerformExternalReset

	;---------
	;Phys Init
	;---------
	call	PhysInit
	jc	SHORT M2PI_ErrorExit

	;------------------------------------
	;Make basic environment calaculations
	;------------------------------------
	call    CreateNicWorkingEnvironment

M2PI_Exit:
	clc
	ret

M2PI_ErrorExit:
	DataAddress 	dx, MediaNotFoundErr
	stc
	ret

Mac2PhyInit             endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         Mac2PhyCheckAndAdjustSelectedConnection
;
; Description:
;               Adjust the selected connection according to the phs present
;               and their supported media accroding to the following roules:
;
;                  If Illegal Medium
;                       return (FAIL)
;                  endif
;		   If connection is Autosense or Nway
;			Perform AS preperations and checking
;		   Else  ;(connection is ForceMedium)
;			Perform ForceMedium preperations
;                  Endif
;
;
; On Entry:
;
; On Return:
;
;               Note:
;
; Notice:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Mac2PhyCheckAndAdjustSelectedConnection proc

	push    si

	;If illlegal connection - Return FAIL
	;------------------------------------
	IsLegalConnection Nic.SelectedMedia
	jc      SHORT M2PCAASC_ErrorExit

	;Handle check & conversion according to OM (ForceMedia or Autosense)
	;-------------------------------------------------------------------
	test    Nic.SelectedOperationMode, ModeAUTOSENSE or ModeAUTODETECT or ModeNWAY
	jz      SHORT M2PCAASC_ForceMedia

	;Connection is AutoSense -> Do autosense adjustments
	;---------------------------------------------------
	call	CheckAndAdjustAutosenseConnection
	jc	M2PCAASC_ErrorExit
	jmp	SHORT M2PCAASC_Exit

	;Connection is Force medium -> Do Force medium adjustments
	;---------------------------------------------------------
M2PCAASC_ForceMedia:
	call	CheckAndAdjustForceMedium
	jnc	SHORT M2PCAASC_Exit

M2PCAASC_ErrorExit:
	pop     si
	DataAddress	dx, MediaNotSupportedErr
	stc
	ret

M2PCAASC_Exit:
	pop     si
	clc
	ret

Mac2PhyCheckAndAdjustSelectedConnection endp

END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_BIND
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         Mac2PhyAutodetect
;
; Description:
;       Performs Power-Up autosense
;       Automaticlly finds and Sets The mac & associated phy to operate in
;       the connection found with link or the default connection
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
Mac2PhyAutodetect       proc

	push	ax
	push	ecx
        push	si

	;------------------------
	;Put the chip in Run-mode
	;------------------------
	call    PutDeviceInRunMode

	;-------------------------
	;Print an openning message
        ;-------------------------
	DataAddress 	dx, AutoDetectionMessage
	call    DisplayMessage

	;--------------------------
	;Perform Power-Up autosense
        ;--------------------------
	call	Phys.AsNway.PowerUpAutosense
	jc	SHORT M2PAD_Exit

	;---------------------------------------------
	;Notify the MAC for possible connection change
        ;---------------------------------------------
	call	Post_SetConnection

M2PAD_Exit:
	;----------------------------------------------------
	;Restore Original activity mode (Sleep Snooze or Run)
	;----------------------------------------------------
	mov	cx, Nic.PowerMode
	call	PutDeviceInMode

        pop	si
	pop	ecx
	pop	ax
	clc
	ret

Mac2PhyAutodetect       endp

END_CODE_SEGMENT_BIND

START_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       NullRoutine     proc
;       assumes:
;
;       returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NullRoutine     proc    near
	ret
NullRoutine     endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       ErrorRoutine     proc
;       assumes:
;
;       returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ErrorRoutine     proc    near

	DataAddress	dx, ErrorRoutineMessage
	stc
	ret

ErrorRoutine     endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         Mac2PhySetConnection (Connection : IN ConnectionType)
;
; Description:
;       Sets The mac & associated phy to operate in the desired connection
;
; On Entry:
;       Nic.SelectedConnection
;
; On Return:
;       Carry reset - Success
;       Upon Failure:
;                    Carry - set
;                    DX    - Pointer to error message.
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Mac2PhySetConnection    proc

	push	ax
        push	bx
	push	si

	;-----------------------
	;Get the Appropriate phy
        ;-----------------------
	mov	si, Nic.SelectedConnectionType
	call	GetConnectionPhyType
	jc	SHORT M2PSC_Exit


	;-------------------------------------
	;Call the Phy's set connection routine
	;-------------------------------------
	call	PhysSetConnection
	jc	SHORT M2PSC_Exit

	;---------------------------------------------------------------------
	;Call Phy module to perform connection setting dependent modifications
	;---------------------------------------------------------------------
	call	PhysExecuteConnectionDependencies

	;---------------------------------------------
	;Notify the MAC for possible connection change
        ;---------------------------------------------
	call	Post_SetConnection
	clc

M2PSC_Exit:
	pop	si
	pop	bx
	pop	ax
	ret

Mac2PhySetConnection    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         Mac2PhyGetConnectionStatus
;
; Description:
;       Returns The mac's current connection status.
;
; On Entry:
;
; On Return:
;	ax - Connection status (ah - Nway status, al - Media status)
;                    Carry - set
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Mac2PhyGetConnectionStatus    proc

	push	bx
	push	si

	;----------------------------------
	;Get the Appropriate phy and medium
        ;----------------------------------
	mov	si, Nic.SelectedConnectionType
	mov	ax, Phys.SelectedPhy

	cmp	ax, PHY_TYPE_UNKNOWN
	jne	SHORT M2PGCS_GetStatus

	;Get Medium phy type
        ;-------------------
	call	GetConnectionPhyType
	jc	SHORT M2PGCS_ErrorExit


	;--------------------------------------------
	;Call the Phy's get connection status routine
	;--------------------------------------------
M2PGCS_GetStatus:
	call	PhysGetConnectionStatus

M2PGCS_Exit:
	pop	si
	pop	bx
	ret

M2PGCS_ErrorExit:
	mov	ah, NWAY_UNKNOWN
	mov	al, MEDIA_STATE_UNKNOWN
	stc
	jmp	SHORT M2PGCS_Exit

Mac2PhyGetConnectionStatus    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         Mac2PhyAutosense
;
; Description:
;       Performs dynamic autosensing
;       Automaticlly finds and Sets The mac & associated phy to operate in
;       the connection found with link or the default connection
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
Mac2PhyAutosense        proc

	push	ax
	push	si

	;--------------------------
	;Call the AutoSense routine
        ;--------------------------
	call	Phys.AsNway.DynamicAutosense
	jc	SHORT M2PAS_Exit

	;---------------------------------------------
	;Notify the MAC for possible connection change
        ;---------------------------------------------
	call	Post_SetConnection

M2PAS_Exit:
	pop	si
        pop	ax
	ret

Mac2PhyAutosense        endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         Mac2PhyLinkHandler
;
; Description:
;	LinkInterrupt handling routine provided by Mac2Phy and used by driver ISR
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
Mac2PhyLinkHandler	proc

	call	Phys.AsNway.LinkISR
	call	Post_SetConnection		;Notify the MAC for possible connection change
	ret

Mac2PhyLinkHandler	endp

END_CODE_SEGMENT_RUNTIME

;******************************************************************************
;*                              Internal  Routines                            *
;******************************************************************************
START_CODE_SEGMENT_INIT

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         PerformExternalReset
;
; Description:
;       Resets the external system (if connected to a gep and srom notfies
;
; On Entry:
;		Interrupts are at any state but will be ENABLED in the routine.
;
;
; On Return:
;               Flags:
;
;
;               Note:
;
; returns:
;        	Interrupts state PRESERVED.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PerformExternalReset     proc

	push    bx
	push	cx
        pushf

	;Perform the RESET sequence
        ;--------------------------
	lea     bx, Nic.ExternalReset[0]
	call    SetGep

	;Wait 500mSec for RESET to complete (according to MII spec)
	;---------------------------------------------------------- 
	mov	cx, 10000
	push	WORD PTR 120            	;10000 * 50u = 500mSec
PER_DelayLoop:
	cli
	call	Delay
	sti    					;Let the system breath
	loop	PER_DelayLoop
	add	sp, 2                           ;Free delay param from stack 

        popf       				;Restor Flags.
	pop	cx
	pop     bx
	ret

PerformExternalReset     endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         CreateNicWorkingEnvironment	 proc
;
; Description:
;
; On Entry:
;               NIC already containes the SROM parsed data
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
CreateNicWorkingEnvironment	proc

	push	eax
	push	bx
        push	cx

	;------------------------------------
	;Make basic environment calaculations
	;------------------------------------

	;Create Nic's Full Phys' capabilities
	;------------------------------------
	xor     eax, eax                                  ;eax <- Temp storage
	lea     bx, Phys.PhysEntry[0]			  ;Get First PHY
	mov     cx, NUM_SUPPORTED_PHYS                    ;cx <- loop counter
CNWE_AssemblePhysCapabilitiesLoop:
	or      eax, (GenPhyAttribSTRUC PTR [bx]).PhyAbilities.PhyCapabilities
	add     bx, SIZE GenPhyAttribSTRUC                ;bx points at next field
	loop    CNWE_AssemblePhysCapabilitiesLoop         ;Check again
	mov	Phys.PhysAbilities.PhyCapabilities, eax   ;Save result

	;Create Full Nway advertisement word
	;-----------------------------------
	ConnectionCapabilitiesToNway ax         ;Create Full Nway advertisement word
	mov     Phys.AsNway.NwayLCW, ax     	;Save it as our Nway advertisement word.

	;---------------------------------
	;Find the AS-Nway Phy to work with
        ;---------------------------------

	; - Do the PHYs support AutoSensing at all ?
	;-------------------------------------------
	test    Phys.PhysAbilities.ConnectionCapabilities, PhyAsNwayCapable
	jz      SHORT CNWE_DoneAsNway

	;If Mii phy is present - Work with it as the Nway Phy
	;----------------------------------------------------
	mov	phys.AsNway.ASNwayPhy, PHY_TYPE_MII
	cmp	Phys.PhysEntry[PHY_TYPE_MII].PhyPresence, Present
	je	SHORT CNWE_DoneAsNway

	;Else - If SIA Phy is present - Work with it as the AS or Nway Phy
	;-----------------------------------------------------------------
	mov	Phys.AsNway.ASNwayPhy, PHY_TYPE_SIA
	cmp	Phys.PhysEntry[PHY_TYPE_SIA].PhyPresence, Present
	je	SHORT CNWE_DoneAsNway

	;Else (Sym Phy Must be present) - Work with it as the AS or Nway Phy
        ;-------------------------------------------------------------------
	mov	phys.AsNway.ASNwayPhy, PHY_TYPE_SYM
CNWE_DoneAsNway:

	;------------------------------------------------------------------------------------
	;If Mii phy is present - Check if its a ML6692 type of PHY
	;ML MII Phy is a Phy supporting 10MBps Nway advertisement
	;while NOT 10MBps capable This check will be done only if the LCW advertizes 10BaseT. 
	;------------------------------------------------------------------------------------
	cmp	Phys.PhysEntry[PHY_TYPE_MII].PhyPresence, Present 	;If No MII phy - Nothing to check
	jne	SHORT CNWE_DoneMiiPhyTypeChecking

	test	Phys.AsNway.NwayLCW, Nway10BaseT		 	;Do we wish to Negotiate 10BaseT ?
	jz	SHORT CNWE_DoneMiiPhyTypeChecking                       ; No - No special handling

	test	Phys.PhysEntry[PHY_TYPE_MII].PhyAbilities.NwayCapabilities, Nway10BaseTCapable
	jz	SHORT CNWE_DoneMiiPhyTypeChecking                       ;Phy is NOT 10Base-T capable at all

	test	Phys.PhysEntry[PHY_TYPE_MII].PhyAbilities.ConnectionCapabilities, Phy10BaseTCapable
	jnz	SHORT CNWE_DoneMiiPhyTypeChecking                       ;Phy suooprts 10BaseT by itself -> Not ML

	mov	Nic.MiiPhysList[0].MiiPhySromID, ML6692
CNWE_DoneMiiPhyTypeChecking:

CNWE_Exit:
	pop	cx
	pop	bx
        pop	eax
	ret

CreateNicWorkingEnvironment	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         CheckAndAdjustAutosenseConnection   (Connection : IN ConnectionType)
;
; Description:
;
; On Entry:
;               Nic.SelectedConnectionType      Connection type
;
; On Return:
;               Flags:
;
;               Note:
;
; Remarks:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
CheckAndAdjustAutosenseConnection	proc

	push	bx

	;-------------------------------------------
	; - Do the PHYs support AutoSensing at all ?
	;-------------------------------------------
	test    Phys.PhysAbilities.ConnectionCapabilities, PhyAsNwayCapable
	jz      SHORT CAAASC_ErrorExit

	;----------------------
	;Set AutosenseNway bits
        ;----------------------
	or	Nic.SelectedOperationMode, ModeNWAY or ModeAUTODETECT or ModeAUTOSENSE

	;-------------------------------------------
	;Call the AS-Nway Phy prepare for AS routine
	;-------------------------------------------
	mov	bx, Phys.AsNway.ASNwayPhy
	lea	bx, Phys.PhysEntry[bx]
	call	(GenPhyAttribSTRUC PTR [bx]).PhyRoutines.PrepareForAsNwayConnection

CAAASC_Exit:
	pop	bx
	ret

CAAASC_ErrorExit:
	stc
	pop	bx
	ret

CheckAndAdjustAutosenseConnection 	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         CheckAndAdjustForceMedium   (Connection : IN ConnectionType)
;
; Description:
;
; On Entry:
;               Nic.SelectedConnectionType      Connection type
;
; On Return:
;               Flags:
;
;               Note:
;
; Remarks:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
CheckAndAdjustForceMedium	proc

	push	ax
	push	bx
        push	si

	; - Check Media Existance
	;------------------------
	movzx   si, Nic.SelectedMedia
	call    GetMediumPhyType
	jc      CAAFM_Exit                   ;If failed -> could not find a PHY supporting this medium.

	;Save converted medium.
        ;----------------------
	mov	ax, si
	mov     Nic.SelectedMedia, al

	;Handle TP NO LINK TEST
	;----------------------
	test	Nic.SelectedOperationMode, ModeLINK_DISABLE
	jz	SHORT CAAFM_ModeIsNotILT
	call	TP_To_TPILT
CAAFM_ModeIsNotILT:

CAAFM_Exit:
	pop	si
	pop	bx
        pop	ax
	ret

CheckAndAdjustForceMedium 	endp

END_CODE_SEGMENT_INIT

;-----------------;
; Sanity checking ;
;-----------------;

;OS type checking
;----------------
IF OS EQ DOS
	%OUT MAC2PHY.ASM Compiling for DOS.
ELSEIF OS EQ OS2
	%OUT MAC2PHY.ASM Compiling for OS2.
ELSE
	.ERR
	%OUT MAC2PHY.ASM Illegal OS value.
ENDIF

;NOS type checking
;-----------------
IF NOS EQ ODI
	%OUT MAC2PHY.ASM Compiling for ODI.
ELSEIF NOS EQ NDIS2
	%OUT MAC2PHY.ASM Compiling for NDIS2.
ELSE
	.ERR
	%OUT MAC2PHY.ASM Illegal NOS value.
ENDIF


End

