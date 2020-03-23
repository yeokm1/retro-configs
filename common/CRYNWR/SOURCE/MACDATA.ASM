NAME    MACDATA
TITLE   MACDATA  --  Digital Internal Use Only

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
; This file contains all of the driver's run-time global data.
;
; Maintainers:
;       eg      Eric Goldstein
;       mf      Maurene Fritz
;       rv      Rivki Vizen
;       ymf     Yishai Fraenkel
;       as      Adi    Shaliv
;       gk      Gal Kaplan
;
; Revision History:
;
; 23-May-1994   eg  Add ChipRev.
;
;  5-jul-1994   mf  Fix bug in NDISMediaSpecificStatus--initialize late
;                   collisions to 0 (was marked Obsolete and set to FFFFFFFF)
;
; 25-Aug-1994   ymf  Add SMC switches
;
; 12-Sep-1994   rv  Add support to DC21140 - Add ChipType and change DC21040
;                   to DC21x40.
;
; 09-Oct-1994   rv  Change DC21x40 to DC21x4
;
; 11-Oct-1994   rv  Fix bug in driver name.
;
; 15-Feb-1995   ymf Additions to support promiscuous mode
;
; 29-Mar-1995   ymf Major driver restructuring:
;                   - Add NicType struct, holding info about chip
;
; 05-Sep-1995   as      Move Entry1 from srom.asm
;
; 13-Nov-1995   as   Add p_CFDA (CFDD in Fnet3 spec) physical I/O address pointer
;
; 10-Dec-1995   as   Remove EISA support from driver.
;
; 29-Jan-1996   as   Add PCI_HWMechanism, PCI_DevNum, PCI_BusNum for direct
;                    call to PCI in OS/2.
;
; 01-May-1996   as   Add Mac2Phy Error Messages
;
; 09-May-1996   as   Add CSR8_overflow_mask
;
; 15-Aug-1996   gk   Add OEM support for Microdyne
;
; 25-Nov-1996	de   Change in include file names, and in AWK conventions.
;
; 10-Apr-1997	de   Remove unnecessary OS/2 GDT.
;----------------------------------------------------------------------------

.xlist                                  ; disable listing the include file
include seg_defs.inc
include driver.inc
include ndis.inc
include macdata.ash
include dc_regs.inc
include version.inc
.list                                   ; enable listing
.386

; Mac2Phy Printing messages :
;---------------------------
CR EQU 0Dh      ; ASCII Carriage Return
LF EQU 0Ah      ; ASCII Line Feed
ZERO EQU 00h    ; End of String

START_DATA_SEGMENT_INIT

        ;SROM Parsing messages
        ;---------------------
UnableToLocateROM               DB      'FATAL: Unable to locate Adapter ROM! ',0Dh,0Ah,0
SROM_ReadFailed                 DB      'FATAL: Failed to read ROM! ',0Dh,0Ah,0
UnsupportedSROMVersion          DB      'FATAL: Unsupported ROM version ',0Dh,0Ah,0
UnsupportedDC21X4SROMVersion    DB      'FATAL: This DS chip does not support this ROM version ',0Dh,0Ah,0

        ;Media selection Error messages
        ;------------------------------
MediaNotSupportedErr            DB      'FATAL: Unsupported media selection  ',0Dh,0Ah,0
MediaNotFoundErr                DB      'FATAL: Could not find media or PHY to work with  ',0Dh,0Ah,0

;
; The PIC variables control access to the PIC chip. The PIC chip handles the
; delivery of hardware interrupts to the CUP in an Intel based PC AT/XT. The
; IRQ of the adapter is determined at init time, in the InitGetAdapterConfig
; function in the module MACINIT.ASM

;PICIntOff       DB ?    ; Masks for enabling and disabling interrupts at
;PICIntOn        DB ?    ; the PIC Chip
;PICIntMask      DW ?    ; I/O Address of the PICIntMask
;PICAckSlave     DB ?    ; Flag to ACK Slave interrupt for IRQ 9,10,11

;-----------------------------------
;Working with DC21X4 Device messages
;-----------------------------------
WorkingWith21040_Message	  db 'Working with Digital Semiconductor 21040 based Ethernet Controller',0Dh,0Ah,0
WorkingWith21041_Message	  db 'Working with Digital Semiconductor 21041 based Ethernet Controller',0Dh,0Ah,0
WorkingWith21140and21140A_Message db 'Working with Digital Semiconductor 21140 based 10/100 mpbs Ethernet Controller',0Dh,0Ah,0
WorkingWith21142and21143_Message  db 'Working with Digital Semiconductor 21143/2 based 10/100 mbps Ethernet Controller',0Dh,0Ah,0

END_DATA_SEGMENT_INIT

START_DATA_SEGMENT_BIND

        ;Print messages for AutoDetection and media selection
        ;----------------------------------------------------
AutoDetectionMessage      DB    'Performing Power-Up Autosense...',0Dh,0Ah,0
SwitchingToMessage        DB    'Switching to ',0
SwitchingToUTPMessage     DB    '10BaseT (TP) ...',0Dh,0Ah,0
SwitchingToBNCMessage     DB    '10Base2 (BNC) ...',0Dh,0Ah,0
SwitchingToAUIMessage     DB    '10Base5 (AUI) ...',0Dh,0Ah,0
SwitchingToSymScrMessage  DB    '100BaseTx (TP 100) ...',0Dh,0Ah,0
SwitchingToT4Message      DB    'T4...',0Dh,0Ah,0
SwitchingToFxMessage      DB    'Fx...',0Dh,0Ah,0
SwitchingBetweenTpSymScr  DB    'Switching between 10BaseT and 100BaseTx... ',0Dh,0Ah,0
PerformingMiiPhyAutodetect  DB  'Performing Mii Phy Power-Up Autosense ',0Dh,0Ah,0
StartingNwayMessage       DB    'Starting Autonegotiation, please wait ...  ',0Dh,0Ah,0
NoMediumFound		  DB	'WARNING: Could not find a connected medium ',0Dh,0Ah,0

IF OS EQ OS2		; In OS/2 media selection messages are printed at init time
END_DATA_SEGMENT_BIND
START_DATA_SEGMENT_INIT
ENDIF
;Selected Media messages
;-----------------------
WorkingWithMediaMessage         db 'Selected media: ',0
WorkingWith_UTP_Message         db '10BaseT (TP) ',0
WorkingWith_BNC_Message         db '10Base2 (BNC) ',0
WorkingWith_AUI_Message         db '10Base5 (AUI) ',0
WorkingWith_TX_Message          db '100BaseTx (TP 100) ',0
WorkingWith_T4_Message          db '100BaseT4 ',0
WorkingWith_Fx_Message          db '100BaseFx ',0
WorkingWithFDMessage            db 'Full Duplex ',0
WorkingWithILTMessage           db 'No Link Test ',0
WorkingWithAutosenseMessage     db 'Autosense ',0
MediaUnknownMessage		db 'Unknown Medium ',0
NewLineLineFeedMessage          db  0Dh,0Ah,0

; storage to hold Media message addresse
MediaTypeMessage	LABEL	WORD
	TableAddress	WorkingWith_UTP_Message  	;TP
	TableAddress 	WorkingWith_BNC_Message  	;BNC
	TableAddress	WorkingWith_AUI_Message  	;AUI
	TableAddress	WorkingWith_TX_Message		;SymScr = TP 100
	TableAddress	WorkingWith_UTP_Message		;TP , FD from mode
	TableAddress	WorkingWith_TX_Message  	;SymScr = TP 100, FD from mode
	TableAddress	WorkingWith_T4_Message   	;T4
	TableAddress	WorkingWith_Fx_Message   	;FX
	TableAddress	WorkingWith_Fx_Message   	;Fx, FD from mode
	TableAddress	WorkingWith_UTP_Message   	;Mii TP
	TableAddress	WorkingWith_UTP_Message   	;Mii TP, FD from mode
	TableAddress	WorkingWith_BNC_Message   	;Mii BNC (No such media exist)
	TableAddress	WorkingWith_AUI_Message   	;Mii BNC (No such media exist)
	TableAddress	WorkingWith_TX_Message   	;Mii 100baseTx = Mii TP 100
	TableAddress	WorkingWith_TX_Message   	;Mii 100baseTx = Mii TP 100, FD from mode
	TableAddress	WorkingWith_T4_Message   	;Mii T4
	TableAddress	WorkingWith_FX_Message   	;Mii FX
	TableAddress	WorkingWith_FX_Message   	;Mii FX, FD from mode

IF OS EQ OS2		; In OS/2 media selection messages are printed at init time
END_DATA_SEGMENT_INIT
START_DATA_SEGMENT_BIND
ENDIF

;
; These three variables are initialized in the MACINIT.ASM module, and
; define the physically mapped block of memory that is locked down at
; init time for the transmit and receive DMA buffers.
;

p_PhysBlockVirt DW  0
p_PhysBlockPhys DD  0
PhysBlockSize   DW  0

END_DATA_SEGMENT_BIND

START_DATA_SEGMENT_RUNTIME

; syssrvcs messages
;------------------

OS2PhysToGDTFailed		db 'PCI BIOS couldnt put os2 entry point in gdt.',CR,LF,0
AllocateMemoryError             db 'FATAL: Failed to allocate memory',0Dh,0Ah,0
VDSLockMemoryError              db 'FATAL: Failed to lock system memory or retrieve its physical address',0Dh,0Ah,0
NotA386MachineErr               db 'FATAL: DC21X4 driver works only with 386 or above!',0Dh,0Ah,0
SlotValueErr                    db 'FATAL: Slot value error!',0Dh,0Ah,0
BoardNotFoundErr                db 'FATAL: Board not found in system',0Dh,0Ah,0
UnknownBusErr                   db 'FATAL: Failed to find a supported bus',0Dh,0Ah,0
BadDeviceCFIDVal                db 'FATAL: Failed to locate DC21X4 on board',0Dh,0Ah,0
UnsupportedDeviceRevision       db 'FATAL: DC21X4 Does not support this device revision or Operation Mode',0Dh,0Ah,0
DeviceIsDisabled		db 'FATAL: Device is disabled, please check your system bios configuration',0Dh,0Ah,0
NoPciBIOSErr                    db 'FATAL: Faild to find PCI BIOS',0Dh,0Ah,0
PCIBIOSBadStatusErr             db 'FATAL: Bad PCI BIOS status',0Dh,0ah,0
PCIBIOSBadRegErr                db 'FATAL: Bad PCI BIOS Register err',0Dh,0ah,0
PCIBIOSBadCBIOErr               db 'FATAL: PCI BIOS failed to initialize DecChip 21x40 CBIO reg!',0Dh,0Ah,0
BadInterruptAllocation          db 'FATAL: PCI BIOS allocated an illegal Interrupt to DecChip 21x40!',0Dh,0Ah,0
HPE_PCIWarn                     db 'WARNING: Failed to handle Turbo switch',0Dh,0ah,0
HPE_PCIErr                      db 'FATAL: Failed to handle Turbo switch',0Dh,0ah,0
CRCTableErr                     db 'FATAL: Internal CRC table corrupted',0Dh,0Ah,0

WACB_PCIErr                     db 'WARNING: Could not handle Intel chipset bug workaround successfuly',0Dh,0Ah,0
ModifyingPBLMsg               	db 'WARNING: This machine Host to PCI bridge has a known bug.',0Dh,0Ah
				db '         Driver limits DC21X4 bursts as a workaround.',0Dh,0Ah,0
WACB_WarnCacheInWBMode          db 'FATAL: This machine Host to PCI bridge has a known bug when ',0Dh,0Ah
				db '       using cache in WB mode which may cause data corruption or system hang ',0Dh,0Ah
				db '       Please change the cache mode to WT (Write Through) as a workaround',0Dh,0Ah,0
WACB_ModifyingTxTHR             db 'WARNING: The PCI Host Bridge present in this machine requires ',0Dh,0Ah
				db '         that the driver switch to Store and Forward Mode. ',0Dh,0Ah
				db '         Network performance may be affected.',0Dh,0Ah,0



	;Compile Error Messages
	;----------------------

ErrorRoutineMessage		DB 'FATAL: The Error routine had been called  ',0Dh,0Ah,0
;-------------------------------------------------------

;
; The following variables are physical I/O address pointers to the Tulip
; and PLX control registers. These are initialized in the InitTulipRegOffsets
; function in the module macinit.asm during driver init time. As a general
; convention in this driver, any variable prefixed with a p_ is a pointer
; variable.
;


;******************************************************************************
;
;       NDIS 2.01 Data Structures
;
;       These data structures define the NDIS MAC driver's entry points,
;       capabilities, and current status. These structures are accessed
;       by protocols which bind to the driver.
;
;******************************************************************************
;
; NDIS 2.01 Common Characteristics Table
;
; This table defines the basic characteristics of the driver, and provides
; pointers to the other NDIS tables. The data in this table is static with
; the exception of the fields marked with a **. The Module ID is filled in
; by the Protocol Manager (PROTMAN) at initialization. The data segment
; field is filled in by the driver at driver init time.
;
                even
NDISCommonChar  label   byte            ; common characteristic table
                DW      (NDISCommonCharEnd - NDISCommonChar)   ; size
                DB      02              ; major NDIS version (2 bcd digits)
                DB      00              ; minor NDIS version (2 bcd digits)
                DW      0               ; reserved must be NULL
                DB      2               ; major version (2 bcd digits)
                DB      0               ; minor version (2 bcd digits)
                DD      1               ; module function flags
                DB      'DC21x4',0,0,0,0,0,0,0,0,0,0 ; ASCIIZ format name
                DB      1               ; protocol level at upper boundary
                DB      1               ; interface type at upper boundary
                DB      0               ; physical protocol at lower level
                DB      1               ; private interface at lower level
                DW      0FFFFh          ; ** module ID, filled in by PROTMAN
                DW      0 ; OFFSET SysReqDispatch
                DW      0 ; OFFSET NDISServiceSpecificChar
                DW      0 ; OFFSET NDISServiceStatus
                DW      0 ; OFFSET NDISMACUpperDispatch
                DD      0               ; lower dispatch table (none)
                DD      0               ; reserved
                DD      0               ; reserved
NDISCommonCharEnd label   byte

;
; Define the MAC service flags. This constant is placed in the MAC Service
; Specific Characteristics Table, and defines the services offered by this
; driver as well as some of the procedural assumptions made.
;
; Bit#    DC21x4Setting     NDIS 2.01 Definition
; ------  -------------     --------------------
; bit<0>  yes               broadcast supported
; bit<1>  yes               multicast supported
; bit<2>  no                functional/group addressing
; bit<3>  yes               promiscuous mode is supported
; bit<4>  yes               software settable station address
; bit<5>  yes               statistics are always current
; bit<6>  no                initiateDiagnostics not supported
; bit<7>  no                loopback supported
; bit<8>  ReceiveLookahead  primary ReceiveLookahead
; bit<9>  no                IBM Source routing not supported (token ring)
; bit<10> no                reset MAC not supported
; bit<11> yes               open/close adapter supported
; bit<12> no                interrupt request supported
; bit<13> no                source routing bridge supported
; bit<14> yes               OS/2 GDT virtual addresses supported
; bit<15> yes               multiple TransferDatas permitted during a single indication
; bit<16> no                mac normally sets FrameSize = 0 in ReceiveLookahead
;

MAC_SERV_FLAG   equ     01100100000111011b

;
; NDIS 2.01 MAC Service-Specific Characteristics Table
;
; This table is used by the MAC driver to 'advertize' its capabilities,
; policies, and limits to any protocol which binds to the driver. The
; values defined in this table are initial values. The values marked
; with a ** may change at driver init time, based upon options set in
; PROTOCOL.INI. The permanent station address is filled in at init time,
; along with the current station address. The current station address may
; be changed by calling the SetFunctionalAddress request. (DECnet, for
; example, does this)
;

NDISServiceSpecificChar   label   byte            ; service specific char table
                DW      (NDISServiceSpecificCharEnd - NDISServiceSpecificChar)
                DB      FRAME_TYPE      ; type name of MAC
                DW      6               ; length of station address in bytes
                DB      16 dup (0)      ; permanent station address (hardware)
                DB      16 dup (0)      ; current station address (station-id)
                DD      0               ; current functional address of adapter
                DW      OFFSET NDISMulticastTable ; multicast address list
                DD      10000000        ; link speed in bits/second
                DD      MAC_SERV_FLAG   ; service flags, see above
                DW      FRAME_MTU       ; max size of frame rcv/xmt
                DD      FRAME_MTU*2     ; xmit buffer capacity in bytes
                DW      FRAME_MTU       ; xmit buffer alloc block size
                DD      FRAME_MTU*2     ; rcv buffer capacity in bytes
                DW      FRAME_MTU       ; rcv buffer alloc block size
                DB      08h, 00h, 2Bh   ; IEEE vendor code
                DB      0               ; vendor adapter code
                DW      OFFSET NDISVendorDescription ; vendor description
                DW      0               ; ** interrupt level used by adapter
                DW      1               ; transmit queue depth (ack immediately)
                DW      8               ; max # of data blocks in buf descr
NDISServiceSpecificCharEnd   label   byte

                public  NDISVendorDescription
NDISVendorDescription label byte
                DB 'Digital DC21x4 V'
                DB VERSION_MAJOR,'.',VERSION_MINOR,0

; Dc21x4 allowes 16 addresses in its setup packet. We save  two  addresses:
; One for the satation address, the second for broadcast address. Therefore
; the multicast table can hold only 14 addresses.
;--------------------------------------------------------------------------
                PUBLIC  NDISMulticastTable
NDISMulticastTable  LABEL  BYTE
                DW      14              ; Max number of multicast addresses
                DW      0               ; Current number of addresses
                DB      14*16 DUP (0)   ; Storage for 14 BYTE[16] addresses

;
; NDIS 2.01 MAC Service-Specific Status Table
;
; The following table holds statistics for the MAC driver. The stats marked
; by a ** in the description field are REQURED by NDIS 2.01. The statistics
; initialized with 0FFFFFFFFh are NOT IMPLEMENTED by this driver. In the
; case where a stat is not implemented, Obsolete, or Reserved, NDIS 2.01
; REQUIRES that stat to be reported as 0FFFFFFFFh.
;
                even
NDISServiceStatus     label   byte
                DW      (NDISServiceStatusEnd - NDISServiceStatus) ; size
                DD      0FFFFFFFFh      ; date/time of last diags
                DD      0               ; status of mac driver
                DW      0               ; current packet filter
                DW      OFFSET NDISMediaSpecificStatus
                DD      0FFFFFFFFh      ; date/time of last clearstatistics
                DD      0               ; ** Total frames recvd OK
                DD      0               ; ** Total frames recvd with CRC error
                DD      0               ; total bytes received
                DD      0FFFFFFFFh      ; frames discarded - no buffer space
                DD      0               ; multicast frames received
                DD      0               ; broadcast frames received
                DD      0FFFFFFFFh      ; Obsoleted in NDIS 2.01
                DD      0FFFFFFFFh      ; Obsoleted in NDIS 2.01
                DD      0FFFFFFFFh      ; Obsoleted in NDIS 2.01
                DD      0FFFFFFFFh      ; Obsoleted in NDIS 2.01
                DD      0FFFFFFFFh      ; Obsoleted in NDIS 2.01
                DD      0               ; frames discarded - hardware error
                DD      0               ; ** total frames transmitted OK
                DD      0               ; total bytes transmitted
                DD      0               ; multicast frames transmitted
                DD      0               ; broadcast frames transmitted
                DD      0FFFFFFFFh      ; Obsoleted in NDIS 2.01
                DD      0FFFFFFFFh      ; Obsoleted in NDIS 2.01
                DD      0               ; frames not transmitted - timeout
                DD      0               ; frames not transmitted - hardware error
NDISServiceStatusEnd label   byte

;
; NDIS 2.01 802.3 Media Specific Statistics. Stats marked with an asterisk are
; those stats that are required to be kept by the NDIS 2.01 spec.
;
NDISMediaSpecificStatus  label  byte
                DW      (NDISMediaSpecificStatusEnd - NDISMediaSpecificStatus)
                DW      1               ; version of this structure
                DD      0               ; ** frames with alignment error
                DD      0FFFFFFFFh      ; Obsoleted in NDIS 2.01
                DD      0               ; frames with overrun error
                DD      0FFFFFFFFh      ; Obsoleted in NDIS 2.01
                DD      0               ; frames tx after deferring
                DD      0               ; frames not txd after max collision
                DD      0FFFFFFFFh      ; Obsoleted in NDIS 2.01
                DD      0               ; late collisions
                DD      0               ; ** frames tx after exactly 1 collision
                DD      0               ; ** frames tx after N collisions
                DD      0               ; frames tx, CD heart beat
                DD      0FFFFFFFFh      ; Obsoleted in NDIS 2.01
                DD      0               ; carrier sense lost during transmit
                DD      0FFFFFFFFh      ; Obsoleted in NDIS 2.01
                DD      0               ; number of underruns
NDISMediaSpecificStatusEnd  label  byte

;
; NDIS 2.01 MAC Upper Dispatch Table
;
; This table simply contains FAR pointers to the primitive MAC driver
; functions and the common characteristics table.
;
  if 0
NDISMACUpperDispatch     label   byte
                DW      OFFSET NDISCommonChar  ; common char table
                DW      OFFSET GenReqDispatch  ; Request address
                DW      OFFSET XmtNDISTransmitChain
                DW      OFFSET RcvNDISTransferData
                DW      OFFSET RcvNDISReceiveRelease
                DW      OFFSET RcvNDISIndicationOn
                DW      OFFSET RcvNDISIndicationOff
  endif

;
; NDIS 2.01 Protocol Lower Dispatch Table
;
; This table is a copy of the protocol's lower dispatch table. By keeping
; a local copy, we save an extra segment load on each call back to the protocol
; stack. This way we just call indirect via our own data segment. Neat!
;
  if 0
NDISProtLowerDispatch  label  byte  ; protocol entry table
                   DD 0       ; back pointer
                   DD 0       ; Interface flags
RequestConfirm     DD 0       ; RequestConfirm Address
TransmitConfirm    DD 0       ; TransmitConfirm Address
ReceiveLookahead   DD 0       ; ReceiveLookahead indication address
IndicationComplete DD 0       ; IndicationComplete address
ReceiveChain       DD 0       ; ReceiveChain indication address
StatusIndication   DD 0       ; Status indication address

ProtDS  DW 0  ; Data Segment of Protocol Manager.
  endif


IF OS EQ OS2
devhlp          DD  0                 ; Entry point for OS/2 devhlp routine

RxGDTSelector   DW  0                 ; GDT for RcvNDISTransferData addresses
XmtGDTSelector  DW  0                 ; GDT for XmtNDISTransmitChain addresses
ENDIF


END_DATA_SEGMENT_RUNTIME
END
