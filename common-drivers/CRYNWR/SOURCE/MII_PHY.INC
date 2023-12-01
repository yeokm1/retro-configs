;*******************************************************************************
;
; MII_PHY.INC
;
; Include file for Dec Fast Ethernet board that holds information
; and supporting routines about the on-board MII phy chips (if any).
;
; Written by:   Moti Haimovsky
; Date:         15-Aug-1995
;
;
; Copyright (C) 1994 by Digital Equipment Corporation
; All rights reserved.
;
; Modification History:
;
; By              Date        Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; Haimovsky Moti  22-Oct-1995 2.20 - Modified media Conversion tables to reflect
;                                    The addition of Mii media codes in the SROM
; Haimovsky Moti  22-Oct-1995      - Added MiiPhySetCapabilities external routine
; Haimovsky Moti  25-Oct-1995      - Modified conversion routines to support Mii
;                                    connection.
; Haimovsky Moti   1-Nov-1995      - Modified CheckConnectionSupport not to check
;                                    Media support if Nway OM is required
; Haimovsky Moti   7-Nov-1995      - Modified MiiPhySetConnectionType and
;                                    MiiPhyNwaySetLocalAbility not handle dx == 0
;                                    as "Use defauts" any more.
; Haimovsky Moti  19-Nov-1995      - Modified MiiPhyInit to SW reset the Phy prior
;                                    reading its parameters.
; Haimovsky Moti  19-Nov-1995      - Modified GetBroadcomPhyConnectionType to turn-On
;                                    the Autosense Mode if phy is performing A.S
; Haimovsky Moti  27-Dec-1995 2.30 - modified FindMiiPhyDevice routine to find a PHY by
;                                    reading the 2 mandatory regs (status and control) only.
;                                    Modified MiihyInit routine NOT to save the contents of
;                                    registers which it failed to read.
;
; Haimovsky Moti  19-May-1996 2.32+- modified FindMiiPhyDevice routine to find a PHY by
;                                    reading the 2 mandatory regs Twice due to timing issues
;                                    on first miiphy acces when using Micro-linear and TW2
; Haimovsky Moti  28-Feb-1996 2.40/33 Added printing a message when guessing the connection
;                                    in GetConnectionType
; Haimovsky Moti  14-Mar-1996      - Added MiiNationalPhyParallelDetectedConnection routine
;                                    to accurately find Line speed in National when parallel
;                                    Detection is performed.
; Haimovsky Moti  31-Mar-1996      - Added Checking Phy capabilities to be != 0 in Phy init
;                                    for false Phy detection prevention.
; Haimovsky Moti  27-May-1996      - Modified FindMiiPhyDevice to put the MDIO in ThreeState
;				     befor reading the miiPhy regs.
; Haimovsky Moti  01-Jul-1996      - Modified SW reset Phy to search for the MII Phy due to
;				     a problem with National PHY changing its Address in
;				     certian Nic implementations.
; Haimovsky Moti  19-Aug-1996 2.41 - Fixed bug acessing MII Nway field in
;				     MiiPhyNwaySetLocalAbility
; Haimovsky Moti  19-Sep-1996 2.42 - Added a fiction PhyID to ML6692 to be used by Phys module.
; Haimovsky Moti  15-Jun-1997 2.60 - Fixed bug in MiiPhyAdminControl routine not calling PostResetDelay
;				     When waiting for reset to complete.
;*******************************************************************************

;******************************************************************************
;*                     MII PHYs Implementation Explenation                    *
;******************************************************************************
;

;
;                               IEEE 802.3u:100Base-T
;                               =====================
;
;          +-----------------------------------------------------------+
;          |                         LLC                               |
;          +-----------------------------------------------------------+
;          |                         MAC                               |
;          +----------------------------------------+--------------+---+
;                                                   |Reconciliation|
;                                                   +------++------+
;                                                          ||
;                                                       MII||
;                                                          ||    MII PHY
;                                                   +------++------+  ---
;                                                   |     PCS      |   ^
;                                                   +--------------+   |
;                                                   |     PMA      |  PHY
;                                                   +--------------+   |
;                                                   |     PMD      |   v
;                                                   +------++------+  ---
;                                                          ||
;                                                       MDI||
;                                                          ||          Medium
;       =====================================================================
;                                                       10/100MBps
;

;
;
;
;                               PHY Layer
;                               ---------
; Three sub-layers scheme:
;  - PCS: Physical Coding Sub-layer
;  - PMA: Physical Medium Attachment, (old)
;  - PMD: Physical Medium Dependent
;
;

;                    Reconciliation Sub-layer & the MII
;                    ----------------------------------
; Principle: 2 devices implementation:
;  - MAC
;  - PHY
;
; MII Phy chip interface
; ----------------------
;               |                               |
;               |           DC21140             |
;               |                               |
;               |          MII        SYM(/SCR) |
;               |  I/O    MGMNT         MII     |
;               +-------------------------------+
;                  ||       |            ||
;            7 Wire\\      2|            || Data (7 wires for TX
;                  ||   Wire\            \\       7 wires for RX)
;                           |            ||
;                       +-----------------------+
;                       |                       |
;                       |                       | Phy Address
;                       |        MII PHY        |====\====
;                       |                       | 5 Wire
;                       |                       |
;                       |                       |
;                       +-----------------------+
;                              |  |  |  |
;                            Physical Media
;
; MII management interface
; ------------------------
;  The management interface provides a simple, 2 wire, serial interface to connect
;  a management entity (such as fasternet) and a managed PHY for the purpose of
;  controlling the PHY and gathering status from it.
;
;  The MII management interface consists of:
;    2 wires connecting the devices.
;    A frame format and a protocol spec for exchanging management frames.
;    A register set which can be read and written using the above frames.
;

;  Management frame structure
;  --------------------------
;  Frames transmitted on the MII Management interface shall have the following
;  structure.
;
;   +-----------------------------------------------------------------------+
;   |                   Management frame fields                             |
;   +------+-------+----+----+-------+-------+----+------------------+------+
;   |      |  PRE  | ST | OP | PHYAD | REGAD | TA |      DATA        | IDLE |
;   +------+-------+----+----+-------+-------+----+------------------+------+
;   |Read  | 1...1 | 01 | 10 | AAAAA | RRRRR | Z0 | DDDDDDDDDDDDDDDD |   Z  |
;   +------+-------+----+----+-------+-------+----+------------------+------+
;   |Write | 1...1 | 01 | 01 | AAAAA | RRRRR | 10 | DDDDDDDDDDDDDDDD |   Z  |
;   +------+-------+----+----+-------+-------+----+------------------+------+
;  The order of bit transmission shall be from left to right.
;
;   IDLE  (IDLE condition)
;          Idle condition means High impedance state and the MDIO line is pulled
;          to 1.
;   PRE   (Preamble)
;          A sequence of 32 contig logic one bits on MDIO with 32 corresponding
;          clock cycles on MDC.
;   ST    (Start of frame)
;          A pattern indicating start of frame.
;   OP    (Operation code)
;          The operation required (Read/Write)
;   PHYAD (PHY address)
;          The address of the PHY (5 bits) we wish to access.
;   REGAD (Register address)
;          The address of the register (5 bits) we wish to access
;   TA    (Turnaround)
;          Two bit time spacing to avoid contention during a read transaction.
;   DATA
;          16 bitd of data read or written.
;

PRE             equ     0FFFFFFFFh
MII_READ_FRAME  equ     60000000h
MII_WRITE_FRAME equ     50020000h

;MII related bits in CSR9
;------------------------
MII_READ                equ     CSR9_MII_READ
MII_WRITE               equ     CSR9_MII_WRITE
MII_WRITE_TS            equ     CSR9_MII_WRITE or CSR9_MMD1
MII_DATA_1              equ     CSR9_MDO                        ;MDO = 1
MII_DATA_0              equ     00000h                          ;MDO = 0
MII_CLK                 equ     CSR9_MDC                        ;MDC = 1
MII_10BITS_TO_MDO_SHIFT equ     5       ;number of left shifts needed to put
					;MSB of MII_PhyAddr packed with
					;MII_RegNumber in the MDO bit position
					;at CSR9
MII_16BITS_TO_MDO_SHIFT equ     2       ;number of left shifts needed to put
					;MSB of MII write data in the MDO bit
					;position at CSR9
MII_MDI_BIT_POSITION    equ     19
MII_MDO_BIT_POSITION    equ     17
MII_MDO_MASK            equ     CSR9_MDO        ;MDO bit mask
MII_READ_DATA_MASK      equ     CSR9_MDI        ;MDI bit mask

; MII Management register set
; ---------------------------
;      Consists of
;         - 2 registers referred as basic registers who must be implemented
;           by all PHY chips.
;         - Extended registers which are optional.
;
;      +----------------+--------------------------+--------------+
;      |Register Address|      Register Name       |Basic/Extended|
;      +----------------+--------------------------+--------------+
;      |       0        | Control                  |      B       |
;      |       1        | Status                   |      B       |
;      |      2,3       | PHY ID                   |      E       |
;      |       4        | NWAY advertisement       |      E       |
;      |       5        | NWAY Link partner ability|      E       |
;      |       6        | NWAY Expansion           |      E       |
;      |       7        | NWAY Next page transmit  |      E       |
;      |      8-15      | Reserved                 |      E       |
;      |     16-31      | Vendor specific          |      E       |
;      +----------------+--------------------------+--------------+
;
MAX_PHYADD      equ     32
MAX_REGADD      equ     32
;
;Mii PHY Registers
;-----------------
PhyRegsSTRUC    struc
	ControlReg              dw      0         ;B
	StatusReg               dw      0         ;B
	PhyId_1                 dw      0         ;E
	PhyId_2                 dw      0         ;E
	NwayAdvertisement       dw      0         ;E
	NwayLinkPartnerAbility  dw      0         ;E
	NwayExpansion           dw      0         ;E
	NwayNextPageTransmit    dw      0         ;E
	PhyReserved             dw      8 dup (0) ;R
	VendorSpecific          dw     16 dup (0) ;V
PhyRegsSTRUC    ends


; Control Register (Basic register)
; ---------------------------------
;
;      +-----+----------------+---------------------------+-----------------------------+
;      | Bit |      Name      |       Description         |        Comments             |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 15  |Reset           |1=Phy reset                |Up to 0.5 sec reset time,    |
;      |     |                |0=normal operation      (*)|when back to 0 - Done reset  |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 14  |Loop Back       |1=Enable loop-back mode    |                             |
;      |     |                |0=Disable loop-back mode(*)|                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 13  |Speed selection |1=100MBp/s              (*)|Valid only when NWAY disabled|
;      |     |                |0=10MBp/s                  |and phy supports both speeds |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 12  |NWAY Enable     |1=Enable NWAY process   (*)|Valid only if status reg     |
;      |     |                |0=Disable NWAY process     |inicates NWAY support        |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 11  |Power Down      |1=Power down               |PHY will respond to mgmnt    |
;      |     |                |0=Normal operation      (*)|access.                      |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 10  |Isolate         |1=Isolate from MII data    |Phy will respond to mgmnt,   |
;      |     |                |0=Normal operation      (*)|Extern phy(addr 0) deflt is 1|
;      +-----+----------------+---------------------------+-----------------------------+
;      |  9  |Restart NWAY    |1=Restart NWAY process     |Valid only if chip supports  |
;      |     |                |0=Normal operation      (*)|NWAY, when back to 0 - DONE  |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  8  |Duplex mode     |1=Full duplex              |Valid only if NWAY disabled  |
;      |     |                |0=Half duplex           (*)|and chip supports both modes |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  7  |Collision test  |1=Enable COL signal test   |To be used in conjunction    |
;      |     |                |0=Disable COL signal test  |with the loop-back mode      |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 0-6 | Reserved       |                           |Write as 0, Ignore on read   |
;      +-----+----------------+---------------------------+-----------------------------+
;
;
;    15   14   13   12   11   10    9    8    7  6                    0
;  +----+----+----+----+----+----+----+----+----+----------------------+
;  |R/W |R/W |R/W |R/W |R/W |R/W |R/W |R/W |R/W |      Reserved        |
;  |SC  |    |    |    |    |    | SC |    |    |(Write 0,ignore read) |
;  +----+----+----+----+----+----+----+----+----+----------------------+
;    |    |    |    |     |    |    |    |    |
; Reset   |    |   NWAY   |Isolate  |    | Collision
;   Loop-Back  |  enable  |      Restart |   test
;  Speed Selection      Power     NWAY   |
;                        down          Duplex
;                                       mode
;                                      (FD/HD)
; R/W = Read/Write, SC = Self Clearing
;
MiiPhyCtrlReset                 equ     8000h
MiiPhyCtrlLoopBack              equ     4000h
MiiPhyCtrlSpeed100              equ     2000h
MiiPhyCtrlEnableNway            equ     1000h
MiiPhyCtrlPowerDown             equ      800h
MiiPhyCtrlIsolate               equ      400h
MiiPhyCtrlRestartNway           equ      200h
MiiPhyCtrlDuplexMode            equ      100h
MiiPhyCtrlCollisionTest         equ       80h
MiiPhyCtrReservedBitsMask       equ       7Fh


; Status Register (basic register)
; --------------------------------
;
;      +-----+----------------+---------------------------+-----------------------------+
;      | Bit |      Name      |       Description         |        Comments             |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 15  |100Base-T4      |1=Phy supports 100BaseT4   |                             |
;      |     |                |0=No 100Base-T4 support    |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 14  |100Base-X       |1=Phy supports 100Base-X FD|Notice That the spec does not|
;      |     |Full-Duplex     |0=No 100Base-x FD support  |specify if this is FX or TX  |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 13  |100Base-X       |1=Phy supports 100Base-X HD|Notice That the spec does not|
;      |     |Half-Duplex     |0=No 100Base-x HD support  |specify if this is FX or TX  |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 12  |10 Mb/s         |1=Phy supports 10 Mb/s FD  |Notice That the spec does not|
;      |     |Full-Duplex     |0=No 10 Mb/s FD support    |specify if this is FX or TX  |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 11  |10 Mb/s         |1=Phy supports 10 Mb/s HD  |Notice That the spec does not|
;      |     |Half-Duplex     |0=No 10 Mb/s HD support    |specify if this is FX or TX  |
;      +-----+----------------+---------------------------+-----------------------------+
;      |10-6 | Reserved       |                           |Ignore on read               |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  5  |NWAY complete   |1=NWAY process completed   |Regs 4-7 contents are Valid  |
;      |     |                |0=NWAY process NOT complete|only if this bit=1. will be 0|
;      |     |                |                           |If NWAY disabled/not supported
;      +-----+----------------+---------------------------+-----------------------------+
;      |  4  |Remote fault    |1=Remote fault cond detectd|Cleared upon read            |
;      |     |                |0=No Rmote flt cond detectd|Will be 0 if not supported   |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  3  |NWAY ability    |1=PHY supports NWAY        |                             |
;      |     |                |0=PHY does not support NWAY|                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  2  |Link Status     |1=Link is UP           (*) |Can be used to determine if  |
;      |     |                |0=Link is DOWN (Link fail) |The current Medium is Linked |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  1  |Jubber Detect   |1=Jubber condition detected|Cleared upon read            |
;      |     |                |0=No jubber cond detected  |Not implemented in Nic phys  |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  0  |Extended        |1=Extended reg capabilities|Extended regs are regs 2 and |
;      |     |Capabilities    |0=Basic reg capabilities   |above                        |
;      +-----+----------------+---------------------------+-----------------------------+
; (*) Notice that Link status bit is a latched untill read meaning that this
;     May be an indication on previoue failure. you can read this status twice
;     in-order to decide if this is a past failure or present failure indication.
;     (Past failure in conjunction with NWAY may indicate a renegotiation an even a
;      media change).
;
;    15   14   13   12   11   10                  6   5    4    3    2    1    0
;  +----+----+----+----+----+----------------------+----+----+----+----+----+----+
;  | RO | RO | RO | RO | RO |      Reserved        | RO | RO | RO | RO | RO | RO |
;  |    |    |    |    |    |  (ignore when read)  |    | LH |    | LL | LH |    |
;  +----+----+----+----+----+----------------------+----+----+----+----+----+----+
;    |    |    |    |     |                          |    |    |     |   |     |
;100BaseT4|    |  10Mb/s  |                NWAY complete  |    |   Link  |   Extended
; 100BaseX-FD  |    FD    |                     Remote fault   |  Status |   capabilities
;      100BaseX-HD      10Mb/s                        NWAY ability    Jabber
;                        HD                                           detect
;
; RO = Read only, LL = Latched low, LH = Latched high
;
MiiPhyStat100BaseT4             equ     8000h
MiiPhyStat100BaseTxFD           equ     4000h
MiiPhyStat100BaseTx             equ     2000h
MiiPhyStat10BaseTFD             equ     1000h
MiiPhyStat10BaseT               equ      800h
MiiPhyStatReservedBitsMask      equ      7C0h
MiiPhyNwayComplete              equ       20h
MiiPhyRemoteFault               equ       10h
MiiPhyNwayCapable               equ        8h
MiiPhyLinkStatus                equ        4h
MiiPhyJabberDetect              equ        2h
MiiPhyExtendedCapabilities      equ        1h

MiiPhyMediaCapabilitiesMask     equ     MiiPhyStat100BaseT4     or \
					MiiPhyStat100BaseTxFD   or \
					MiiPhyStat100BaseTx     or \
					MiiPhyStat10BaseTFD     or \
					MiiPhyStat10BaseT

MiiPhyCapabilitiesMask          equ     MiiPhyMediaCapabilitiesMask or \
					MiiPhyNwayCapable


;  PHY identifier (registers 2 and 3) (Extended register)
;  ------------------------------------------------------
;
;      +-----+--------------------------------------+-------++------+-------+
;      |a   b c                                    r s     x||Vendor|  Rev# |
;      |         Organizanitionaly Unique  ID               ||model#|       |
;      |1   2 3                                   18 19   24||5    0|3     0|
;      +-----+--------------------------------------+-------++------+-------+
;            |                                              |       |       |
;             15                                   0 15   10 9     4 3     0
;        MSB +--------------------------------------+-------+-------+-------+ LSB
;            |             Register 2               |     Register 3        |
;            |                                      |                       |
;            +--------------------------------------+-------+-------+-------+
;
; The PHY ID is composed from:
;               Bits 2-24 of the Organizanitionaly Unique  ID
;                  6 bits of Manufacturer (vendor) model#
;                  4 bits of device revision#
;
;
; Different Vendors' Phy IDs
; --------------------------
BCM5000_0       equ     03E00000h    ;Broadcom
DP83840_0       equ     20005C00h    ;National
;_80C240                equ                  ;Seeq
ML6692		equ    0	     ;Fiction # assigned to ML6692 type of Phy
GENERIC_PHY     equ    0FFFFFFFFh

;Useful masks
;------------
VENDOR_ID_MASK                  equ    0FFFFFC00h
VENDOR_ID_RIGHT_JUSTIFY         equ     10

VENDOR_MODEL_MASK               equ     3F0h
VENDOR_MODEL_RIGHT_JUSTIFY      equ     4

VENDOR_Rev_MASK                 equ     0Fh


;
;
;                        Auto Negotiation (NWAY) - General
;                        ---------------------------------
;
; - Automatic Detection of the most poweful protocol shared by both sides.
; - Implemented in the PMD layer of the PHY
; - Based on the simultanious exchange of information encapsulated within a
;   burst of closely spaced link integrity test pulses.
;   Thats why its Implemented on TP only!
;
;
;          +------------+   +------------+   +------------+      +------------+
;          | 10Base-T   |   | 100Base-TX |   | 100Base-T4 |      |Future Tech.|
;          |    PMA     |   |     PMA    |   |     PMA    | ...  |     PMA    |
;          +------------+   +------------+   +------------+      +------------+
;            ^ ^     |        ^ ^     |        ^ ^     |           ^ ^     |
;            | |     v        | |     v        | |     v           | |     v
;          +------------------------------------------------------------------+
;          |                    Auto-Negotiation (NWAY)                       |
;          +------------------------------------------------------------------+
;                                     ^         |
;                                  RD |         v TD_AUTONEG
;                               +---------------------+
;                               |  Twisted Pair int.  |
;                               +---------------------+
;
;
; - Technology Dependent Interface
;       Autoneg function provides a mechanism to control connection of the
;       TP data path to a single technology dependent PMA
;
; - Parallel Detection Function
;       Allows detection of link partners that support 100Base-TX,
;       100Base-T4, &/or 10Base-T, but DO NOT implement Nway.
;       "The spec does NOT mention how do we know which medium has been selected !!!!!
;       We assume that the appropriate bit in link partner abilities will be set
;       upon success.
;
;  Link Code Word - LCW
;  --------------------
;(Transmitted from left to right)
;
;    0     1    2    3    4    5    6    7    8    9   10   11   12   13   14   15
;  +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
;  | S0 | S1 | S2 | S3 | S4 | A0 | A1 | A2 | A3 | A4 | A5 | A6 | A7 | RF | Ack| NP |
;  | 1  | 0  | 0  | 0  | 0  |    |    |    |    |    |    |    |    |    |    |    |
;  +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
;                                                                      ^    ^    ^
;        Selector Field            Technology Ability Field            |    |    |
;  <-----------------------> <------------------------------------->   |    |    |
;   (32 different mesages)                                             |    |    |
;                                                            Remote Fault   |    |
;                                                                  Acknowledge   |
;                                                                         Next Page
;
;
; Remote Fault:
;       Advertise the link partner that a fault condition has occured.
;       (programmable).
;
; Acknowledge:
;       Indicate that link partner's link code word has been sucessfully received.
;       (Internally generated).
;
; Next Page
;       Informs about additional LCW carrying arbitrary pieces of data.
;

; Technology Ability field & priority table
; -----------------------------------------
;
;              +----+---------------------------+--------+
;              |Bit | Technology                |Priority|
;              +----+---------------------------+--------+
;              | A0 | 10Base-T (Half-Duplex)    | 5(LSP) |
;              +----+---------------------------+--------+
;              | A1 | 10Base-T Full-Duplex      | 4      |
;              +----+---------------------------+--------+
;              | A2 | 100Base-TX (Half-Duplex)  | 3      |
;              +----+---------------------------+--------+
;              | A3 | 100Base-TX Full-Duplex    | 1(MSP) |
;              +----+---------------------------+--------+
;              | A4 | 100Base-T4                | 2      |
;              +----+---------------------------+--------+
;
;  - both sides exchange information on their technology ability and the selected
;    medium shall be the highest precedence medium that poth sides share.
;

; Next Page
; ---------
;    0     1    2    3    4    5    6    7    8    9   10   11   12   13   14   15
;  +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
;  | C0 | C1 | C2 | C3 | C4 | C5 | C6 | C7 | C8 | C9 | C10| T  |Ack2| MP | Ack| NP |
;  |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |
;  +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
;             Message / Unformatted Code Field               ^    ^    ^
;  <----------------------------------------------------->   |    |    |
;                                                            |    |    |
;                                                        Toggle   |    |
;                                                       Acknowledge2   |
;                                                            Message Page
;       - Optional.
;       - Occures after the Base page have been exchange.
;       - Containes additional (and optional) information such as:
;               - Technology ability bit expansion.
;               - Vendor & PHY Ids.
;
;

; Auto-Negotiation (NWAY) registers
; ---------------------------------
;
; Nway Advertisement register
; ---------------------------
;   Containes the advertised capabilities of the PHY
;
;      +-----+----------------+---------------------------+-----------------------------+
;      | Bit |      Name      |       Description         |        Comments             |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 15  | Next Page      |1=Next Page able           |                             |
;      |     | Indication     |0=Not Next page able       |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 14  |Acknowledge     |1=Rcvd link partner ack    |Automaticlly set by PHY      |
;      |     |                |0=Not acknowledged         |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 13  |Remote Fault    |1=This device detected RF  |                             |
;      |     |                |0=No remot fault detected  |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      |10-12|Reserved        |                           | Write as 0, Read as Don't   |
;      |     |                |                           |             care            |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  9  |100Base-T4      |1=Supported by local PHY   |                             |
;      |     | support        |0=Not supported            |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  8  |100Base-TX FD   |1=Supported by local PHY   |                             |
;      |     | support        |0=Not supported            |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  7  |100Base-TX      |1=Supported by local PHY   |                             |
;      |     | support        |0=Not supported            |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  6  |10Base-T FD     |1=Supported by local PHY   |                             |
;      |     | support        |0=Not supported            |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  5  |10Base-T        |1=Supported by local PHY   |                             |
;      |     | support        |0=Not supported            |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 0-4 | Selector       |00001 - Supports IEEE 802.3|This is the selector field in|
;      |     |                |        CSMA/CD            |the Link Code Word           |
;      +-----+----------------+---------------------------+-----------------------------+
;
; The PHY will write these bits according to its capabilites upon reset.
; These values will be sent "as is" in the LCW
; Nway capabilities advertisement can be limited by resetting "unwanted" capabilites.
; Setting unsupported media bits have no effect (but not recomended due to
;                                                possiblr PHY bugs).
;
;       15   14   13   12        10    9    8    7    6    5  4              0
;     +----+----+----+----+----+----+----+----+----+----+----+----------------+
;     | RO |R/W |R/W |   Reserved   |R/W |R/W |R/W |    |R/W | 0  0  0  0  1  |
;     |         |    |              |    |    |    |    |    |                |
;     +----+----+----+----+----+----+----+----+----+----+----+----------------+
;       |    |    |                    |    |    |    |    |         |
;Next Page   | Remote          100Base-T4   |    | 10BaseT |       Selector
;Indication  | Fault           Support      |    |  FD     |
;   Acknowledge                   100Base-TX FD  | support |
;                                 Support        |      10Base-T
;                                        100Base-TX     support
;                                         Support
; R/W = Read/Write
;

; Nway Link partner ability Register (ANLPAR)
; -------------------------------------------
;  - Containes the advertised capabilities of the Link partner as received during
;    Auto negotiation.
;  - Same as Nway Advertisement register
;  - All the bits are Read-Only
;
MiiPhyNwayNextPageAble          equ     8000h
MiiPhyNwayACK                   equ     4000h
MiiPhyNwayRemoteFault           equ     2000h
MiiPhyNwayReservedBitsMask      equ     1C00h
MiiPhyNway100BaseT4             equ      200h
MiiPhyNway100BaseTxFD           equ      100h
MiiPhyNway100BaseTx             equ       80h
MiiPhyNway10BaseTFD             equ       40h
MiiPhyNway10BaseT               equ       20h
MiiPhyNwaySelectorMask          equ       1Fh

MiiPhyNwayCapabilitiesMask      equ     MiiPhyNway100BaseT4    or \
					MiiPhyNway100BaseTxFD  or \
					MiiPhyNway100BaseTx    or \
					MiiPhyNway10BaseTFD    or \
					MiiPhyNway10BaseT


NWAY_802_3_Selector     equ     1

;
; Nway Expansion register
; -----------------------
;
;      +-----+----------------+---------------------------+-----------------------------+
;      | Bit |      Name      |       Description         |        Comments             |
;      +-----+----------------+---------------------------+-----------------------------+
;      |15-5 | Reserved       |                           | Always 0                    |
;      |     |                |                           |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  4  |MLF - Multiple  |1=NWAY failed, connection  |                             |
;      |     |      Link Fault|  not resolved             |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  3  |LP_NP_ABLE      |1=Link Partner is Next Page Able                         |
;      |     |                |0=Not NP able              |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  2  |NP_ABLE         |1=This Phy is Next Page Able                             |
;      |     |                |0=Not NP able              |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  1  |PAGE_RX         |1=Link Code Page Word rcvd |Automaticly cleared when ALNPAR
;      |     |                |0=Not received             |is read, Set when new code page
;      |     |                |                           |has been received.           |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  0  |LP_AN_ABLE      |1=Link Partner is NWAY ABLE|                             |
;      |     |                |                           |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;
;
;       15   14   13   12          5   4    3    2    1    0
;     +-----------------------------+----+----+----+----+----+
;     |         Reserved            | RO | RO | RO | RO | RO |
;     |          RO                 |    |    |    |    |    |
;     +-----------------------------+----+----+----+----+----+
;                                      |    |    |    |    |
;                                    MLF    |    |Page_RX  |
;                                   LP_NP_ABLE   |   LP_AN_ABLE
;                                           NP_ABLE
; RO = Read Only

MiiPhyNwayExpReservedBitsMask           equ     0FFE0h
MiiPhyNwayExpMultipleLinkFault          equ        10h
MiiPhyNwayExpLinkPartnerNextPageAble    equ         8h
MiiPhyNwayExpNextPageAble               equ         4h
MiiPhyNwayExpReceivedLinkCodePage       equ         2h
MiiPhyNwayExpLinkPartnerNwayAble        equ         1h


;       NWAY Issues
;       -----------
;       - How Do I know which Media has been selected ?
;            Highest precedence in the result of the bitwise AND between
;            Local and Link-Prtner advertised abilities.
;
;       - When Nway is performed aginst a plain hub than parallel Link Detection
;         is performed. How do I know which medium was selected ?
;            If link status is PASS (meaning only one meduim found to be connected)
;            We then assume (!!) that the appropriate bit in the link partner capabilities
;            register will be set.
;
;       - Incosistancy between DC21140 operation mode and the PHY.
;         2 such basic cases:
;           1. Nway is enabled and (Line speed or Duplex mode) were changed:
;                Phy adapt itself accordingly.
;                DC21140 remaines in previous mode untill driver recognizes this.
;           2. Nway Is disabled and (Line speed or Duplex mode) were changed:
;                Both Phy and DC21140 remain in previous mode untill driver
;                recognizes this.
;        Which one is worse ?
;               Both are BAD
;        Which method to use ?
;               The easier to implement - Nway running all the time and driver
;               sumples status reg.
;
;
;
;******************************************************************************
;*                           MII PHY Definitions                              *
;******************************************************************************
;The Routines addresses this structure is designed to hold
;will be filled by InitPhysStrucEntries routine since the real address can't
;be resolved at compile time.

MiiPhyInternalRoutinesSTRUC        struc
	PhyReadRegister         dw      0
	PhyWriteRegister        dw      0
	NWAYGetLocalAbility     dw      0
	NWAYSetLocalAbility     dw      0
	NWAYGetPartnerAbilities dw      0
MiiPhyInternalRoutinesSTRUC        ends

MiiPhySTRUC     struc
	Mii			GenPhyAttribSTRUC < >
	MiiPhyAddress           db      0
	MiiPhyId                dd      GENERIC_PHY
	MiiPhyRegs              PhyRegsSTRUC <>
	MiiPhyInternalRoutines  MiiPhyInternalRoutinesSTRUC <>
MiiPhySTRUC     ends


START_DATA_SEGMENT_RUNTIME

;Data Structure holding Phy's registers mask
;-------------------------------------------
PhyRegsReservedBitsMasks        dw      MiiPhyCtrReservedBitsMask       ;Control reg reserved bits mask
				dw      MiiPhyStatReservedBitsMask      ;Status reg reserved bits mask
				dw      0                               ;PhyID reserved bits mask
				dw      0                               ;PhyID reserved bits mask
				dw      MiiPhyNwayReservedBitsMask      ;NWAY Local ability reserved bits Mask
				dw      MiiPhyNwayReservedBitsMask      ;NWAY Partner ability reserved bits Mask
				dw      MiiPhyNwayExpReservedBitsMask   ;Nway Expansion
				dw  26  dup (0)                         ;Other regs
		
END_DATA_SEGMENT_RUNTIME



;******************************************************************************
;*                           MII PHY External routines                        *
;******************************************************************************
START_CODE_SEGMENT_INIT

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiPhyInit (PhyStrucPtr IN MiiPhySTRUC_PTR)  proc
;
; Description:
;       Initialize the Mii phy entry variables, Searches for a Phy in the given
;       address and if found Initializes it.
;
; On Entry:
;          BX - PhyStrucPtr
;
;
; On Return:
;
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiPhyInit      proc

	push    eax
	push    dx
	push    si

	;Init Phy struc entry
	;--------------------
	call    InitPhyStrucEntry

	;Find if MiiPhy is present in the given address
	;----------------------------------------------
	call    FindMiiPhyDevice
	jc      SHORT MPI_Exit

	;Check if this is a phy who needs special handling
	;-------------------------------------------------
	cmp     (MiiPhySTRUC PTR [bx]).MiiPhyId, BCM5000_0	;broadcom needs special handling
	je      SHORT MPI_ItsNotAGenericPhy       		;Not Mii complient, needs SW reset when
						  		;Switches from 10 to 100

	cmp     (MiiPhySTRUC PTR [bx]).MiiPhyId, DP83840_0      ;National needs special handling.
	je      SHORT MPI_ItsNotAGenericPhy       ;(Phy looses Net when in Isolate mode)

	mov     (MiiPhySTRUC PTR [bx]).MiiPhyId, GENERIC_PHY
MPI_ItsNotAGenericPhy:

	;Reset the Phy
	;-------------
	mov     ax, RESET
	call    (MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyAdminControl

	;Read & save all the Phy's registers
	;-----------------------------------
	xor     dx, dx                                   			;Start from Reg 0
MPI_ReadRegister:
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyReadRegister 	;Read it
	jc      SHORT MPI_SkipThisReg
	mov     si, dx                                   			;mov reg# to SI
	mov     WORD PTR ((MiiPhySTRUC PTR [bx]).MiiPhyRegs[si]), ax            ;Save its value
MPI_SkipThisReg:
	add     dx, 2                                    			;Point next register
	cmp     dx, (SIZE PhyRegsSTRUC)                  			;Did we read all the registers
	jl      SHORT MPI_ReadRegister

	;Check if a PHY has any capability (0 capabilities -> No PHY)
	;------------------------------------------------------------
	cmp     (MiiPhySTRUC PTR [bx]).MiiPhyRegs.StatusReg, 0
	je      SHORT MPI_ErrorExit

	;Get and save PHY capabilities
	;-----------------------------
	mov     ax, (MiiPhySTRUC PTR [bx]).MiiPhyRegs.StatusReg
	and     ax, MiiPhyCapabilitiesMask      		;Clear Irrelevant bits
	cmp     (MiiPhySTRUC PTR [bx]).MiiPhyId, BCM5000_0
	jne     SHORT MPI_NotBCM5000            		;Broadcom implements basic NWAY
	or      ax, MiiPhyNwayCapable           		;called Autosense
MPI_NotBCM5000:
	mov     (MiiPhySTRUC PTR [bx]).Mii.PhyAbilities.ConnectionCapabilities, ax

	;Get and save PHY's NWAY advertisement
	;-------------------------------------
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.NWAYGetLocalAbility
	mov     (MiiPhySTRUC PTR [bx]).Mii.PhyAbilities.NwayCapabilities, ax

	;Put Phy in Operational mode
	;---------------------------
	mov     ax, OPERATIONAL
	call    (MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyAdminControl

	;Mark that Phy entry is Valid
	;----------------------------
	mov     (MiiPhySTRUC PTR [bx]).Mii.PhyPresence, Present

MPI_Exit:
	pop     si
	pop     dx
	pop     eax
	ret

MPI_ErrorExit:
	stc
	jmp     SHORT MPI_Exit

MiiPhyInit      endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiPhyGetCapabilities (PhyStrucPtr IN MiiPhySTRUC_PTR)
;
; Description:
;        Returns the PHY capabilities.
;
; On Entry:
;        BX    - PhyStrucPTR
;        Status register had been read and its value placed in Phy regs struct.
; On Return:
;        AX   - Phys capabilities.
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiPhyGetCapabilities   proc

	mov     eax, (MiiPhySTRUC PTR [bx]).Mii.PhyAbilities.PhyCapabilities
	ret

MiiPhyGetCapabilities   endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiPhySetCapabilities (PhyStrucPtr     IN MiiPhySTRUC_PTR
;                                      PhyCapabilities IN PhyCapabilitiesTYPE)
;
; Description:
;        Sets the PHY MEDIA capabilities by ANDing the original (full) capabilities
;        with the new ones.
;        Notice that NWAY capabilities are not affected
;
; On Entry:
;        BX    - PhyStrucPTR
;        AX   - Phys capabilities.
; On Return:
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiPhySetCapabilities   proc

	push    eax

	push    (MiiPhySTRUC PTR [bx]).Mii.PhyAbilities.ConnectionCapabilities      ;Save Original capabilities
	and     (MiiPhySTRUC PTR [bx]).Mii.PhyAbilities.PhyCapabilities, eax        ;set NEW capabilities
	pop     ax                                  				    ;Restore Original capabilities
	test    ax, MiiPhyNwayCapable               				    ;Do we support NWAY ?
	jz      SHORT MPSC_DoneWithNWAY
	or      (MiiPhySTRUC PTR [bx]).Mii.PhyAbilities.ConnectionCapabilities,\
							         MiiPhyNwayCapable  ;Nway is supported - Set its bit
MPSC_DoneWithNWAY:

	pop     eax
	ret

MiiPhySetCapabilities   endp

END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiPhySetConnectionType (PhyStrucPtr   IN MiiPhySTRUC_PTR,
;                                        Connection    IN ConnectionType,
;                                        Advertisement IN ConnectionAdvertisement )
;
; Description:
;       ;If (Connection == NWAY) then
;       ;    if (Advertisment != 0 ) then
;       ;       Change Localadvertisement
;               Set RestartNway bit
;       ;    EndIf
;       ;    set NWAy bit On in CTRL register
;       ;else
;       ;    Translate Media to appropriate control bits
;       ;    write CTRL reg
;       ;    return (success)
;       ;endIf
;
; On Entry:
;       BX - PhyStrucPtr
;       AX - Connection in SROM format
;       DX - Advertisment
;
; On Return:
;       AX, BX, DX - Preserved.
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiPhySetConnectionType proc

	push    ax
        push	cx
	push    dx

	;Does the Phy support this connection ?
	;--------------------------------------
	mov	cx, (MiiPhySTRUC PTR [bx]).Mii.PhyAbilities.ConnectionCapabilities
	call    CheckPhyConnectionSupport
	jc      SHORT MPSCT_Exit


	;Convert Connection type to Control word
	;---------------------------------------
	call    ConvertConnectionToControl

	;Clear Previous Connection bits from Control word
	;(Leave only Isolate and Power-down bits)
	;------------------------------------------------
	and     (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg, MiiPhyCtrlIsolate or MiiPhyCtrlPowerDown

	;Create the New control word
	;---------------------------
	or      (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg, ax

	;If operation mode is NWAY - set its parameters
	;----------------------------------------------
	test    ax, MiiPhyCtrlEnableNway
	jz      SHORT MPSCT_DoneWithNway
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.NWAYSetLocalAbility    ;Set new advertisement word
MPSCT_DoneWithNway:

	;write the new control word
	;--------------------------
	mov     ax, (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg
	mov     dx, PhyRegsSTRUC.ControlReg
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyWriteRegister

	;Don't save RestartNway bit !
	;----------------------------
	and     (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg, NOT MiiPhyCtrlRestartNway

	;If broadcom - need Reset the Phy in 10 to 100 transition
	;--------------------------------------------------------
	cmp     (MiiPhySTRUC PTR [bx]).MiiPhyId, BCM5000_0
	jne     SHORT MPSCT_DoneWithBroadcom
	call    HandleBroadcomMediaChangeFrom10To100
MPSCT_DoneWithBroadcom:

	clc
MPSCT_Exit:
	pop     dx
	pop	cx
	pop     ax
	ret

MiiPhySetConnectionType endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiPhyGetConnectionStatus ( PhyStrucPtr      IN  MiiPhySTRUC_PTR,
;                                           ConnectionStatus OUT ConnectionStatusType)
;
;
; Description:
;       Returns the connection status of the Phy and rewrites the command Word
;       read from the PHY in its entry in the PhysArray.
;       Connection status has the following attributes:
;               NwayAdminStatus
;               MAUStatus
;
; On Entry:
;         BX  - PhyStrucPtr
;
;
; On Return:
;         AX - ConnectionStatus
;         AH - Nwaystatus
;         AL - LinkStatus
;
; Note:
;         Carry set if NWAY configuring or Link-fail
; returns:
; Remarks:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiPhyGetConnectionStatus       proc

	push    dx


	;Read and save Control Reg since Force speed may be implemented via
	;HDW pin Causing SW selection to be ignored
	;------------------------------------------------------------------
	mov     dx, PhyRegsSTRUC.ControlReg
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyReadRegister
	mov     (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg, ax

	;Read & save Status word
	;-----------------------
	mov     dx, PhyRegsSTRUC.StatusReg
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyReadRegister
	mov     (MiiPhySTRUC PTR [bx]).MiiPhyRegs.StatusReg, ax

	;Assume Connection status unknown
	;--------------------------------
	mov     al, MEDIA_STATE_UNKNOWN
	mov     ah, NWAY_UNKNOWN

	;Set nway status according to Nway complete & ability bits & enable
	;------------------------------------------------------------------
	;If Broadcom Perform a special test
	;----------------------------------
	cmp     (MiiPhySTRUC PTR [bx]).MiiPhyId, BCM5000_0
	jne     SHORT MPGCS_NormalNwayChecking

	mov     ah, NWAY_DISABLED                               	;Assume Nway disabled
	test    (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg, MiiPhyCtrlEnableNway
	jz      SHORT MPGCS_DoneWithNway
	mov     ah, NWAY_COMPLETE                               	;If Not disabled then assume
	jmp     SHORT MPGCS_DoneWithNway                        	;Nway completed


	;Not Broadcom - Perform standard test
	;------------------------------------
MPGCS_NormalNwayChecking:
	mov     ah, NWAY_NOT_SUPPORTED                          ;assume no nway
	test    (MiiPhySTRUC PTR [bx]).MiiPhyRegs.StatusReg, MiiPhyNwayCapable
	jz      SHORT MPGCS_DoneWithNway                        ;assumed correctly

	mov     ah, NWAY_DISABLED                               ;Assume Nway disabled
	test    (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg, MiiPhyCtrlEnableNway
	jz      SHORT MPGCS_DoneWithNway

	mov     ah, NWAY_CONFIGURING                            ;Assume configuration not completed yet
	test    (MiiPhySTRUC PTR [bx]).MiiPhyRegs.StatusReg, MiiPhyNwayComplete
	jz      SHORT MPGCS_ErrorExit
	mov     ah, NWAY_COMPLETE                               ;Nway completed
MPGCS_DoneWithNway:

	;Set link status according to link bit.
	;Sinse tht LinkStatus bit latches Link-Fail status we will use
	;the following metod to find the link status:
	;
	;If status reg indicate LinkPass then
	;       LinkStatus=LINK_PASS
	;else
	;       Read Status Register
	;       If status reg indicate LinkPass then
	;               LinkStatus=LINK_PASS_WITH_PF
	;       else
	;               LinkStatus=LINK_FAIL
	;       endif
	;endif
	;-------------------------------------------------------
	mov     al, MEDIA_LINK_PASS                             ;Assume link pass
	test    (MiiPhySTRUC PTR [bx]).MiiPhyRegs.StatusReg, MiiPhyLinkStatus
	jnz     SHORT MPGCS_DoneWithStatus                      ;Assumption correct

	push    ax                                              ;Link fail needs additional check
	mov     dx, PhyRegsSTRUC.StatusReg
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyReadRegister
	mov     (MiiPhySTRUC PTR [bx]).MiiPhyRegs.StatusReg, ax
	pop     ax
	mov     al, MEDIA_LINK_PASS_WITH_PF                     ;Assume link pass with PF
	test    (MiiPhySTRUC PTR [bx]).MiiPhyRegs.StatusReg, MiiPhyLinkStatus
	jnz     SHORT MPGCS_DoneWithStatus                      ;Assumption correct
	mov     al, MEDIA_LINK_FAIL                             ;Link bit is in Fail state
	jmp     SHORT MPGCS_ErrorExit
MPGCS_DoneWithStatus:

MPGCS_Exit:
	clc
	pop     dx
	ret

MPGCS_ErrorExit:
	stc
	pop     dx
	ret

MiiPhyGetConnectionStatus       endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiPhyGetConnectionType (PhyStrucPtr      IN MiiPhySTRUC_PTR,
;                                        ConnectionStatus OUT ConnectionStatusType)
;
; Description:
;        Returns the selected connection of the PHY.
;        This routine assumes that the Connection status is stable meaning that
;        if Nway is active than it has completed the negotiation and link is not
;        in FAIL state.
;        We recommend calling the Get connection status routine and ceck the above
;        before calling this routine.
; On Entry:
;        BX    - PhyStrucPTR
;
; On Return:
;       AX - selected connection.
; Note:
;
; Remarks:
;       We use the NWAY capable bit in the Phy capabilities field to
;       overcome Broadcome's AutoSense issue.
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiPhyGetConnectionType proc

	push    cx

	;If Broadcom - Call its special handling routine
	;-----------------------------------------------
	cmp     (MiiPhySTRUC PTR [bx]).MiiPhyId, BCM5000_0
	jne     SHORT  MPGCT_NotBroadcom
	call    GetBroadcomPhyConnectionType
	jc      SHORT MPGCT_ErrorExit
	call    HandleBroadcomMediaChangeFrom10To100
MPGCT_DoneWithBroadcom:
	jmp     MPGCT_Exit
MPGCT_NotBroadcom:

	;If NWAY NOT selected
	;   return (selectedMedia taken from the control register)
	;endif
	;----------------------------------------------------------
	test    (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg, MiiPhyCtrlEnableNway
	jnz     SHORT MPGCT_HandleNwayConnection

	;If reached this point NWAY is either Not supported or not selected
	;and connection had been selected via the commandReg
	;------------------------------------------------------------------
	test    (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg, MiiPhyCtrlDuplexMode
	jz      SHORT MPGCT_NotFD

	;This is a Full-Duplex media - handle it
	;---------------------------------------
	mov     ax, ConnectionMii100BaseTxFD                    ;Is it 100 FD  (-> TXFD or FXFD )
	test    (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg, MiiPhyCtrlSpeed100
	jnz     SHORT MPGCT_Exit
				
MPGCT_FDNot100:
	mov     ax, ConnectionMiiTpFD                           ;Its 10 FD   -> TPFD
	jmp     SHORT MPGCT_Exit

	;This is a Half-Duplex media - handle it
	;---------------------------------------
MPGCT_NotFD:
	mov     ax, ConnectionMiiTP                              ;assume tp
	test    (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg, MiiPhyCtrlSpeed100
	jz      SHORT MPGCT_Exit                                ;its 10BaseT

	mov     ax, ConnectionMii100BaseTX                      ;if TX is supported - assume 100BaseTX
	test    (MiiPhySTRUC PTR [bx]).MiiPhyRegs.StatusReg, MiiPhyStat100BaseTx
	jnz     SHORT MPGCT_Exit

	mov     ax, ConnectionMii100BaseT4              ;If reached this point its
	jmp     SHORT MPGCT_Exit                        ;probabely 100BaseT4


	;Its NWAY operation mode - handle it accordingly
	;-----------------------------------------------
MPGCT_HandleNwayConnection:

	;Get Partner abilities and Local abilities and retrieve
	;The selected connection type out of them
	;-------------------------------------------------------
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.NWAYGetLocalAbility
	mov     cx, ax
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.NWAYGetPartnerAbilities
	and     ax, cx
	jnz     SHORT MPGCT_NwayDeclaresSelectedConnection

	;If result is 0 and LikPass it means that Chip had performed Parallel detection
	;So we need to Guess the media. we are shure that its NOT FD one.
	;-------------------------------------------------------------------------------
	;National has a secret register reporting the Line-Speed in this case
	;--------------------------------------------------------------------
	cmp     (MiiPhySTRUC PTR [bx]).MiiPhyId, DP83840_0
	jne     SHORT MPGCT_NotNational
	call    MiiNationalPhyParallelDetectedConnection
	jc      SHORT MPGCT_ErrorExit
	jmp     SHORT MPGCT_Exit

	;Other Phys (not Natoinal nor Broadcom) need medium guessing
	;-----------------------------------------------------------
MPGCT_NotNational:
	mov     ax, (MiiPhySTRUC PTR [bx]).Mii.PhyAbilities.ConnectionCapabilities
	and     ax, NOT (MiiPhyStat10BaseTFD or MiiPhyStat100BaseTxFD)
	shr     ax, 6                                           ;Align it to NWAY bits location
MPGCT_NwayDeclaresSelectedConnection:
	call    ConvertNwayToConnectionType
	jc      SHORT MPGCT_ErrorExit

MPGCT_Exit:
	clc
	pop     cx
	ret
MPGCT_ErrorExit:
	mov     ax, MAC_CONN_UNKNOWN
	stc
	pop     cx
	ret

MiiPhyGetConnectionType endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiPhyAdminStatus (PhyStrucPtr IN MiiPhySTRUC_PTR
;                                  Status      OUT AdminStatusType )  proc
;
; Description:
;
;       This routine return the Phy admin status whic can be one of the following:
;               Reset       - reset process is in progress (not completed yet).
;               PowerDown   - Chip is in Power down mode.
;               StandBy     - Chip is listening to the line but doen't access
;                             The mii data lines.
;               Operational - Chip is fully active
;
; On Entry:
;              BX - PhyStrucPtr
;
; On Return:
;              AX - Status
;
;               Note:   Interrupts are disabled.
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiPhyAdminStatus       proc

	push    cx
	push    dx

	;Read and save Control(!) register   (remember transition time !)
	;---------------------------------
	mov     cx, 3                                     			;Try 3 reads (to make sure
MPAS_ReadControl:                                         			;That 0 is a real value
	mov     dx, PhyRegsSTRUC.ControlReg
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyReadRegister 	;Read control reg
	or      ax, ax
	jnz     SHORT MPAS_DoneReadingControl
	loop    MPAS_ReadControl
MPAS_DoneReadingControl:
	mov     cx, ax                                  ;Cx to hold control reg

	;Is it RESET ?
	;-------------
	mov     ax, RESET
	test    cx, MiiPhyCtrlReset
	jnz     SHORT MPAS_Exit

	;Is it PowerDown ?
	;-----------------
	mov     ax, POWERDOWN
	test    cx, MiiPhyCtrlPowerDown
	jnz     SHORT MPAS_Exit

	;Is it ISOLATE ?
	;---------------
	mov     ax, STANDBY
	test    cx, MiiPhyCtrlIsolate
	jnz     SHORT MPAS_Exit

	;If reached this point - PHY is operational
	;-----------------------------------------
	mov     ax, OPERATIONAL

MPAS_Exit:
	clc
	pop     dx
	pop     cx
	ret
MiiPhyAdminStatus       endp

END_CODE_SEGMENT_RUNTIME


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiPhyAdminControl (PhyStrucPtr IN MiiPhySTRUC_PTR
;                                   Contrrol    IN AdminControlType )  proc
;
; Description:
;
;       This routine Performs the control command on the specified Phy.
;       Control command can be one of the following:
;               Reset       - reset teh phy (returns it to defaults).
;               PowerDown
;               StandBy
;               Operational
; On Entry:
;              BX - PhyStrucPtr
;              AX - Control word
;	       SI - MediumType (in case of BRUT FORCE command)
;
; On Return:
;           All registers are preserved
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
START_DATA_SEGMENT_RUNTIME

AdminControlConversionTable     db      80h     ;Reset
				db       0      ;Operational
				db       4h     ;Isolate/Standby
				db       8h     ;POWERDOWN

END_DATA_SEGMENT_RUNTIME


START_CODE_SEGMENT_RUNTIME

MiiPhyAdminControl      proc

	push    ax
	push    cx
	push    dx

	;Reset command
	;-------------
	cmp     ax, RESET
	jne     SHORT MPAC_NotReset

	;Reset the chip
	mov     ax, (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg
	or      ax, MiiPhyCtrlReset
	mov     dx, PhyRegsSTRUC.ControlReg
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyWriteRegister

	;Search for the Phy (again !)
	;----------------------------
	call	SearchAgainForThePhy

	;Delay Until reset is done and chip stabilizes
	mov     cx, 10000                        	;assume Max of approx. 0.5 sec = 10,000 * (120 * Delay)
MPAC_ResetDelay:
	call    (MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyAdminStatus
	cmp     ax, RESET                        	;Reset process still running ?
	jne     SHORT MPAC_Exit

	;Delay for 50uSec
        ;----------------
	pushf
        cli
        push	WORD PTR 120
	call	Delay
	add	sp, 2
        popf
	loop    MPAC_ResetDelay
	jmp     SHORT   MPAC_Exit

MPAC_NotReset:

	;-------------------
	;BRUT FORCRE command
	;-------------------
	cmp     ax, BRUT_FORCE_CONNECTION
	jne     SHORT MPAC_NotBrutForce

	;Fake Full Phy capabilities
	;--------------------------
	push	(MiiPhySTRUC PTR [bx]).Mii.PhyAbilities.ConnectionCapabilities
	or	(MiiPhySTRUC PTR [bx]).Mii.PhyAbilities.ConnectionCapabilities, 0FFFFh

	;Let ax hold Medium type
	;-----------------------
	mov	ax, si
	xor	ah, ah

	;Set Phy to connection
        ;---------------------
	call	(MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhySetConnectionType

	;Restor original capabilities
        ;----------------------------
	pop	(MiiPhySTRUC PTR [bx]).Mii.PhyAbilities.ConnectionCapabilities

	;Put phy in OPERATIONAL mode
        ;--------------------------
	mov	ax, OPERATIONAL
MPAC_NotBrutForce:

	;----------------------------------------------------------
	;ISOLATE SHUDOWN & OPERATIONAL will be treated the same way
	;----------------------------------------------------------
	;Clear Prev Ctrl bits
	;--------------------
	and     (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg, \
				NOT (MiiPhyCtrlReset or MiiPhyCtrlPowerDown or MiiPhyCtrlIsolate)

	;Get Mode bits
	;-------------
	xor     ah, ah                  ;Clear irrelevant bits (ah)
	push    bx
	lea     bx, AdminControlConversionTable
	xlat
	pop     bx

	;Align to appropriate bit location
	;---------------------------------
	shl     ax, 8

	;Set Ctrl bits
	or      (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg, ax  ;Save new control
	;Write the ctrl register
	mov     ax, (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg
	mov     dx, PhyRegsSTRUC.ControlReg
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyWriteRegister

MPAC_Exit:
	clc
	pop     dx
	pop     cx
	pop     ax
	ret

MiiPhyAdminControl      endp

;******************************************************************************
;*                           MII PHY Internal routines                        *
;******************************************************************************

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiPhyReadRegister (PhyStrucPtr     IN MiiPhySTRUC_PTR
;                                   RegisterAddress IN  REGAD,
;                                   Register        OUT WORD ) proc
;
; Description:  ReadMiiPhyRegister (PhyAddress, RegisterNumber)
;               This routine reads the specified refister from the
;               specified PHY.
;   +-----------------------------------------------------------------------+
;   |                   Management frame fields                             |
;   +------+-------+----+----+-------+-------+----+------------------+------+
;   |      |  PRE  | ST | OP | PHYAD | REGAD | TA |      DATA        | IDLE |
;   +------+-------+----+----+-------+-------+----+------------------+------+
;   |Read  | 1...1 | 01 | 10 | AAAAA | RRRRR | Z0 | DDDDDDDDDDDDDDDD |   Z  |
;   +------+-------+----+----+-------+-------+----+------------------+------+
;
; On Entry:
;               BX  -   PHYStrucPTR
;               DX  -   MII_Reg Address (offset in bytes from start of mii phys regs)
;
;
; On Return:
;               AX     Data read
;
;               Note:   Interrupts are disabled.
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiPhyReadRegister      proc

	push    cx                             ;Do not change push sequence
	push    ebx                            ;since it has importance later-on.
	push    edx
	push    eax

	;Convert register address to register#
	;-------------------------------------
	shr     dx, 1

	;Construct Command word
	;---------------------
	movzx   cx, (MiiPhySTRUC PTR [bx]).MiiPhyAddress     	;Get Phy address
	shl     cx, 7                   			;Align it to bits 11-7

	shl     dx, 2                   			;Align Reg# to bits 6-2
	or      dx, cx                  			;Combine addresses (bits 11-2)
	and     edx, 0FFFFh             			;Clear irrelevant bits
	shl     edx, 16                 			;Align command word written
	or      edx, MII_READ_FRAME     			;add read frame bits

	;Write preamable bits
	;--------------------
	push    edx
	mov     edx, PRE
	mov     cx, 32
	call    WriteMii
	pop     edx

	;Write the command bits
	;----------------------
	mov     cx, 14                  ;Write only 14 bits
	call    WriteMii

	;Generate the WRITE Turnaround bits (ZZ)
	;--------------------------------------
	call    MiiOutThreeState

	;Check that the PHY chip generated a zero bit in the 2'nd clock.
	;---------------------------------------------------------------
	mov     dx, Nic.CSR9_Address
	in      eax, dx
	test    eax, MII_READ_DATA_MASK
	pushf                                   ;Save the result for later testing since
						;we MUST complete the read process.
	;Input the WORD of data from the MII
	;-----------------------------------
	mov     cx, 16
	xor     bx, bx                  ;zero the result

MPRR_ReadLoop:
	mov     eax, (MII_READ           )
	out     dx, eax
	call    DelayMII
	mov     eax, (MII_READ or MII_CLK)
	out     dx, eax
	call    DelayMII
	in      eax, dx
	call    DelayMII
	shr     eax, MII_MDI_BIT_POSITION
	and     al, 1
	shl     bx, 1
	or      bl, al
	loop    MPRR_ReadLoop

	;Generate Idle bit (Z) as an end to the transaction.
	;---------------------------------------------------
	call    MiiOutThreeState

	;Restor the read status and check if read failed or not.
	;-------------------------------------------------------
	popf
	jnz     SHORT MPRR_ReadMiiError

	clc                     ;No error.

MPRR_Exit:
	pop     eax
	mov     ax, bx          ;copy result to AX
	pop     edx
	pop     ebx

	;Clear Reserved bits
	;-------------------
	pushf
	push    si
	mov     si, dx
	mov     cx, PhyRegsReservedBitsMasks[si]    ;Cx to hold reserved bits mask
	not     cx                                  ;we wish to clear res. bits only
	and     ax, cx                              ;Clear reserved bits
	pop     si
	popf

	pop     cx
	ret

MPRR_ReadMiiError:
	stc
	jmp     SHORT MPRR_Exit

MiiPhyReadRegister      endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiPhyWriteRegister (PhyStrucPtr     IN MiiPhySTRUC_PTR
;                                    RegisterAddress IN REGAD,
;                                    Register        IN WORD ) proc
;
; Description:  WriteMiiPhyRegister (PhyAddress, RegisterNumber, Data)
;               This routine writes the appropriate data to the the specified
;               register from the specified PHY.
;
;   +-----------------------------------------------------------------------+
;   |                   Management frame fields                             |
;   +------+-------+----+----+-------+-------+----+------------------+------+
;   |      |  PRE  | ST | OP | PHYAD | REGAD | TA |      DATA        | IDLE |
;   +------+-------+----+----+-------+-------+----+------------------+------+
;   |Write | 1...1 | 01 | 01 | AAAAA | RRRRR | 10 | DDDDDDDDDDDDDDDD |   Z  |
;   +------+-------+----+----+-------+-------+----+------------------+------+
;
; On Entry:
;         BX - PhyStrucPTR
;         DX - MII_RegAddress (offset in bytes from start of mii phys regs)
;         Ax - Data
;
; On Return:
;
;
;               Note:   Interrupts are disabled.
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiPhyWriteRegister     proc

	push    cx
	push    edx
	push    ebx
	push    eax

	;clear reserved data bits
	;------------------------
	push    si
	mov     si, dx
	mov     si, PhyRegsReservedBitsMasks[si]
	not     si
	and     ax, si
	pop     si

	;Convert register address to register#
	;-------------------------------------
	shr     dx, 1

	;Construct Command word
	;---------------------
	movzx   cx, (MiiPhySTRUC PTR [bx]).MiiPhyAddress     	;Get Phy address
	shl     cx, 7                   			;Align it to bits 11-7

	shl     dx, 2                   			;Align Reg# to bits 6-2
	or      dx, cx                  			;Combine addresses (bits 11-2)
	shl     edx, 16                 			;Align command word written
	or      edx, MII_WRITE_FRAME    			;add write frame bits
	mov     dx, ax                  			;add word to be written

	;Write preamable bits
	;--------------------
	push    edx
	mov     edx, PRE
	mov     cx, 32
	call    WriteMii
	pop     edx

	;Write the command & data
	;------------------------
	mov     cx, 32
	mov     ebx, edx
	call    WriteMii

	;Put Mii out to High
	;-------------------
	call    MiiOutThreeState
	clc                     ;No error.

	pop     eax
	pop     ebx
	pop     edx
	pop     cx
	ret
MiiPhyWriteRegister     endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         WriteMii          (MiiData  IN  DWORD,
;                                  DataSize IN  BYTE  )  proc
;
; Description:
;            Writes the Data size bits from the MiiData Dword to the Mii
;            Control lines
; On Entry:
;            EDX - MiiData
;            cx  - Num of bits to write
; On Return:
;
;
;               Note:   Interrupts are disabled.
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
WriteMii        proc

	push    ebx
	push    edx
	push    eax
	push    cx

	mov     ebx, edx                ;Let ebx hold the data
	mov     dx, Nic.CSR9_Address    ;Dx holds CSR9 address

WM_OutBitsLoop:
	mov     eax, ebx                ;get next bit to out to PHY
	shl     ebx, 1
	shr     eax, (31-MII_MDO_BIT_POSITION)
	and     eax, MII_MDO_MASK
	or      eax, (MII_WRITE           )
	out     dx, eax
	call    DelayMII
	or      eax, (MII_WRITE or MII_CLK)
	out     dx, eax
	call    DelayMII
	loop    WM_OutBitsLoop

	pop     cx
	pop     eax
	pop     edx
	pop     ebx
	ret
WriteMii        endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiOutThreeState
;
; Description:  This routine will put the MDIO port in three states for the
;               turn around bits in MII read and at end of MII management
;               sequence.
;
; On Entry:
;
;               Note:   Interrupts are disabled. ???
;
; On Return:
;               All registers are preserved
;               Flags:  None
;
;               Note:   Interrupts disabled.     ?
;
; Remarks:      This routine is called by ?.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiOutThreeState proc

	push    eax
	push    dx

	mov     dx, Nic.CSR9_Address
	mov     eax, (MII_WRITE_TS           )
	out     dx, eax
	call    DelayMII
	mov     eax, (MII_WRITE_TS or MII_CLK)
	out     dx, eax
	call    DelayMII

	pop     dx
	pop     eax
	ret

MiiOutThreeState endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         DelayMII
;
; Description:  This routine generates the basic MII MDC clock delay which
;               generates the required 300nsec half duty cycle.
;               The required time is at least 300nsec.
;               We will use Our Delay routine that with minimum delay which is
;               at least 419nSec.
;
; On Entry:
;
;               Note:   Interrupts are in any state but will be disabled while
;                       performing the routine.
;
; On Return:    EAX     Preserved
;               EBX     Preserved
;               ECX     Preserved
;               EDX     Preserved
;               EBP     Preserved
;               ESI     Preserved
;               EDI     Preserved
;
;               Flags:  none
;
;               Note:   Interrupts preserved.
;
; Remarks:      This routine is called by ?.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DelayMII proc

	pushf                   ;Save interrupt status
	push    WORD PTR 1      ;Delay of 1 Tick (419nsec)
	cli
	call    Delay
	add     sp, 2
	popf
	ret

DelayMII endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiPhyNwayGetLocalAbility (PhyStrucPtr IN  MiiPhySTRUC_PTR
;                                          Ability     OUT NWAYLocalAbility )
;
; Description:
;               Returns the Local abilities of the Phy according to the value
;               written in Nway Local abilities register.
;
; On Entry:
;               BX - PhyStrucPtr
;
; On Return:
;               AX - Local abilities (in NWAY format)
;
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiPhyNwayGetLocalAbility       proc

	;If broadcom - manually construct NWAY capabilities
	; (NO ack, No remote fault, 802.3 selector, media according to status reg)
	;-------------------------------------------------------------------------
	cmp     (MiiPhySTRUC PTR [bx]).MiiPhyId, BCM5000_0
	jne     SHORT MPNGLA_NotBroadcom

	;Get phy capabilities from status register
	;-----------------------------------------
	mov     ax, (MiiPhySTRUC PTR [bx]).Mii.PhyAbilities.ConnectionCapabilities
	shr     ax, 6                               ;Align Media capabilities to NWAY cap.
	jmp     SHORT MPNGLA_Exit
MPNGLA_NotBroadcom:

	;Read and save the Nway advertisement register
	;---------------------------------------------
	mov     dx, PhyRegsSTRUC.NwayAdvertisement
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyReadRegister
	mov     (MiiPhySTRUC PTR [bx]).MiiPhyRegs.NwayAdvertisement, ax

	;Clear irrelevant bits
	;---------------------
	and     ax, MiiPhyNwayCapabilitiesMask

MPNGLA_Exit:
	ret
MiiPhyNwayGetLocalAbility       endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiPhyNwaySetLocalAbility (PhyStrucPtr IN MiiPhySTRUC_PTR,
;                                          MediaBits   IN NWAYLocalAbility)
;
; Description:
;           Modifies the local Phy Local abilities advertisement register value
;           In order to limit the media connections that will be negotiated
;           (/send) to the link partner.
; On Entry:
;           BX - PhyStrucPtr
;           DX - MediaBits
;
; On Return:
;
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiPhyNwaySetLocalAbility       proc

	push    ax

	;If broadcom - Nothing to do
	;---------------------------
	cmp     (MiiPhySTRUC PTR [bx]).MiiPhyId, BCM5000_0
	je      SHORT MPNSLA_Exit

	;Create the new advertisement word
	;---------------------------------
	mov     ax, (MiiPhySTRUC PTR [bx]).Mii.PhyAbilities.NwayCapabilities
								;Get Phy's default capabilities
	and     ax, dx                              					  ;Mask it with new capabilities
	or      ax, NWAY_802_3_Selector             					  ;add Nway selector
	mov     (MiiPhySTRUC PTR [bx]).MiiPhyRegs.NwayAdvertisement, ax  		  ;Save the new advertisement word.

	mov     dx, PhyRegsSTRUC.NwayAdvertisement
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyWriteRegister

MPNSLA_Exit:
	pop     ax
	ret
MiiPhyNwaySetLocalAbility       endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiPhyNwayGetPartnerAbility  (PhyStrucPtr IN  MiiPhySTRUC_PTR,
;                                             Ability     OUT  NWAYLinkPartnerAbility)
;
; Description:
;       Returns the Link partner abilities as written in the Link-partner
;       abilities register (which reflects Link partner's advertizement register).
;
;       A value of 0 will be returned If link partner is not Nway capable or
;       does not support any known medium.
;
; On Entry:
;           BX - PhyStrucPtr
;
; On Return:
;           AX - Ability
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiPhyNwayGetPartnerAbility     proc

	;If broadcom - No knowledge on Partner's abilities
	;------------------------------------------------
	xor     ax, ax
	cmp     (MiiPhySTRUC PTR [bx]).MiiPhyId, BCM5000_0
	je      SHORT MPNGPA_Exit

	;Read the code word received from link partner
	;If partner does not support NWAY - The value read will be 0
	;-----------------------------------------------------------
	mov     dx, PhyRegsSTRUC.NwayLinkPartnerAbility
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyReadRegister
	mov     (MiiPhySTRUC PTR [bx]).MiiPhyRegs.NwayLinkPartnerAbility, ax

	;Clear irrelevant bits
	;---------------------
	and     ax, MiiPhyNwayCapabilitiesMask

MPNGPA_Exit:
	ret

MiiPhyNwayGetPartnerAbility     endp

END_CODE_SEGMENT_RUNTIME

;******************************************************************************
;*                           MII PHY support routines                         *
;******************************************************************************
START_CODE_SEGMENT_INIT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         InitPhysStrucEntries (Phy IN OUT MiiPhySTRUC_PTR)  proc
;
; Description:
;       Initializes the mii phy struc by Filling the pointers to mii phy routines
;       with the addresse of mii phy routins.
;       (these addresses cannot be resolved at compile time).
; On Entry:
;       BX - Pinter to Phy Entry
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
InitPhyStrucEntry       proc

	;Init Phy Routines entries
	;-------------------------
	mov     (MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyInit,                 offset CGroup:MiiPhyInit
	mov     (MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyGetCapabilities,      offset CGroup:MiiPhyGetCapabilities
	mov     (MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhySetCapabilities,      offset CGroup:MiiPhySetCapabilities
	mov     (MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhySetConnectionType,    offset CGroup:MiiPhySetConnectionType
	mov     (MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyGetConnectionType,    offset CGroup:MiiPhyGetConnectionType
	mov     (MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyGetConnectionStatus,  offset CGroup:MiiPhyGetConnectionStatus
	mov     (MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyAdminControl,         offset CGroup:MiiPhyAdminControl
	mov     (MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyAdminStatus,          offset CGroup:MiiPhyAdminStatus

	mov     (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyReadRegister,         offset CGroup:MiiPhyReadRegister
	mov     (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyWriteRegister,        offset CGroup:MiiPhyWriteRegister
	mov     (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.NWAYGetLocalAbility,     offset CGroup:MiiPhyNwayGetLocalAbility
	mov     (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.NWAYSetLocalAbility,     offset CGroup:MiiPhyNwaySetLocalAbility
	mov     (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.NWAYGetPartnerAbilities, offset CGroup:MiiPhyNwayGetPartnerAbility

	ret

InitPhyStrucEntry       endp


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         FindMiiPhyDevice (PhyStrucPtr IN MiiPhySTRUC_PTR)
;
; Description:
;               This routine accepts the MII PHY address and checks if a PHY,
;               exists there by reading the PHY's first 2 registers which are
;               mandatory.
;
; On Entry:
;               BX  -   Pointer to Phy's struc
;               [bx].PhyAddress holds the Phy address
; On Return:
;               DX - Preserved
;               Flags:  Carry flag SET if no such PHY is found
;                       Carry flag ReSET if PHY is found
;
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
FindMiiPhyDevice        proc

	push    dx

	;Put MDIO in Three states so the Mii Phy will recognize that
	;it's connected to a Mac
        ;-----------------------------------------------------------
	call    MiiOutThreeState

	call	IsPhyPresentInThisAddress
	jc      SHORT FMPD_ErrorExit

	;Found a Phy - Get its ID
	;------------------------
	mov     dx, PhyRegsSTRUC.PhyId_2
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyReadRegister
	jc      SHORT FMPD_GenericPhy        ;If ID reg is NOT implemented -> its a Generig PHY
	mov     WORD PTR (MiiPhySTRUC PTR [bx]).MiiPhyId[0], ax
	mov     dx, PhyRegsSTRUC.PhyId_1
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyReadRegister
	jc      SHORT FMPD_GenericPhy        ;If ID reg is NOT implemented -> its a Generig PHY
	mov     WORD PTR (MiiPhySTRUC PTR [bx]).MiiPhyId[2], ax
FMPD_Exit:
	clc
FMPD_ErrorExit:
	pop     dx
	ret

FMPD_GenericPhy:
	mov     (MiiPhySTRUC PTR [bx]).MiiPhyId, GENERIC_PHY
	jmp     SHORT FMPD_Exit

FindMiiPhyDevice        endp

END_CODE_SEGMENT_INIT

START_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          SearchAgainForThePhy     proc
;
; Description:
;       	This routine Searches Again For The Phy after SW resetting the Phy
;		this is done due to a bug in National Phy which changes its address
;		after SW reset in certian Nic implementations and network activity
;
; On Entry:
;
;
; On Return:
;               Flags:
;
;
;               Note:
;                   Using this routine violates the Multi-Phy implementation scheme
;		    and hence can't be used when implementing multiple MII Phys support.
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SearchAgainForThePhy	proc

	;-----------------------------------------------------------
	;Put MDIO in Three states so the Mii Phy will recognize that
	;it's connected to a Mac
        ;-----------------------------------------------------------
	call    MiiOutThreeState

	;------------------------------------------
	;Search for current Phy in current address
	;------------------------------------------
	call	IsPhyPresentInThisAddress
	jnc	SHORT SAFTP_FoundPhy

	;--------------------
	;Start from address 0
	;--------------------
	mov	(MiiPhySTRUC PTR [bx]).MiiPhyAddress, 0

	;-----------------------------------------------------------
	;Find a PHY by successfully reading the PHY's mandatory regs
	;(Control & Status regs) (twice due to ML and TW2 timing)
	;-----------------------------------------------------------
SAFTP_SerchLoop:
	call	IsPhyPresentInThisAddress
	jnc	SHORT SAFTP_FoundPhy

	;Try to find a Phy in the next address
        ;-------------------------------------
	inc	(MiiPhySTRUC PTR [bx]).MiiPhyAddress
	cmp	(MiiPhySTRUC PTR [bx]).MiiPhyAddress, MAX_PHYADD   ;did we pass the legal address range ?
	jl	SHORT SAFTP_SerchLoop

SAFTP_FoundPhy:
	ret

SearchAgainForThePhy	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         IsPhyPresentInThisAddress	proc
;
; Description:
;       	This routine Searches Again For a Phy in the specified address
;
; On Entry:
;              BX  - Mii Phys struc PTR
;
; On Return:
;               Flags:
;
;
;               Note:
; returns:
;              Carry flag SET - No phy was found.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
IsPhyPresentInThisAddress	proc

	push	ax
	push	dx

	mov     dx, PhyRegsSTRUC.ControlReg
IPPITA_ReadRegister:
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyReadRegister
					      ;This routine receives the register address
	jc      SHORT IPPITA_Exit	      ;in BYTES offset from start of Phy regs
	add     dx, 2                         ;while the REGADD is the offset in WORDS
	cmp     dx, PhyRegsSTRUC.StatusReg    ;Thats why we do this Multiplication and
	jle     SHORT IPPITA_ReadRegister     ;addition of 2
	clc
IPPITA_Exit:
	pop	dx
	pop	ax
	ret

IsPhyPresentInThisAddress 	endp

END_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ConvertConnectionToControl      proc
;
; Description:
;
; On Entry:
;               AX - ConnectionType
;               BX - Pointer to PhyEntry
; On Return:
;               Flags:
;
;
;               Note:   Interrupts are disabled.
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
START_DATA_SEGMENT_RUNTIME

MediaToCommanndConversionTable  db      0    ;TP
				db      0    ;BNC
				db      0    ;AUI
				db     20h   ;100BaseTx/SymScr
				db      1h   ;TP-FD
				db     21h   ;100BaseTx-FD /SymScr-FD
				db     20h   ;100BaseT4
				db     20h   ;100BaseFx
				db     21h   ;100BaseFx-FD
				db      0    ;MediaMiiTP
				db      1h   ;MediaMiiTpFD
				db      0    ;MediaMiiBNC
				db      0    ;MediaMiiAUI
				db     20h   ;MediaMii100BaseTX
				db     21h   ;MediaMii100BaseTxFD
				db     20h   ;MediaMii100BaseT4
				db     20h   ;MediaMii100BaseFX
				db     21h   ;MediaMii100BaseFxFD

END_DATA_SEGMENT_RUNTIME

START_CODE_SEGMENT_RUNTIME

ConvertConnectionToControl      proc

	;Convert Media Type to control bits
	;----------------------------------
	push    bx
	lea     bx, MediaToCommanndConversionTable
	xlat
	pop     bx
	xchg    ah, al                          ;Put Media bits in their correct location
						;while preservind the OM bits.
	;Check if Nway bits are also needed
	;----------------------------------
	test    al, ModeNWAY or ModeAUTOSENSE
	mov     al, 0                           ;Clear al bits w.o changing CPU flags
	jz      SHORT CCTC_Exit

	;Autosense or Nway are required
	;If broadcom Don't set the Restart NWAY bit
	;------------------------------------------
	cmp     (MiiPhySTRUC PTR [bx]).MiiPhyId, BCM5000_0
	je      SHORT CCTC_DoneWithRestartNway
	or      ax, MiiPhyCtrlRestartNway
CCTC_DoneWithRestartNway:
	or      ax, MiiPhyCtrlEnableNway
CCTC_Exit:
	ret

ConvertConnectionToControl      endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ConvertNwayToConnectionType     proc
;
; Description:
;               Returns The Highest precedence media type its bit is set
;               In the Nway word.
;
;               according to the following table:
;               +----+---------------------------+--------+
;               |Bit | Technology               |Priority|
;               +----+---------------------------+--------+
;               | A0 | 10Base-T (Half-Duplex)    | 5(LSP) |
;               +----+---------------------------+--------+
;               | A1 | 10Base-T Full-Duplex      | 4      |
;               +----+---------------------------+--------+
;               | A2 | 100Base-TX (Half-Duplex)  | 3      |
;               +----+---------------------------+--------+
;               | A3 | 100Base-TX Full-Duplex    | 1(MSP) |
;               +----+---------------------------+--------+
;               | A4 | 100Base-T4                | 2      |
;               +----+---------------------------+--------+
;
; On Entry:
;               AX - Nway register bits (in advertisment format).
; On Return:
;               Flags:
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ConvertNwayToConnectionType     proc

	push    cx
	mov     cx, ax

	;Is it 100BaseTx FD ?
	mov     ax, ConnectionMii100BaseTxFD
	test    cx, MiiPhyNway100BaseTxFD
	jnz     SHORT CNTCT_Exit

	;Is it 100BaseT4 ?
	mov     ax, ConnectionMii100BaseT4
	test    cx, MiiPhyNway100BaseT4
	jnz     SHORT CNTCT_Exit

	;Is it 100BaseTx ?
	mov     ax, ConnectionMii100BaseTx
	test    cx, MiiPhyNway100BaseTx
	jnz     SHORT CNTCT_Exit

	;Is it 10BaseT FD ?
	mov     ax, ConnectionMiiTPFD
	test    cx, MiiPhyNway10BaseTFD
	jnz     SHORT CNTCT_Exit

	;Is it 10BaseT ?
	mov     ax, ConnectionMiiTP
	test    cx, MiiPhyNway10BaseT
	jnz     SHORT CNTCT_Exit

	;No media found
	;--------------
	stc
	jmp     CNTCT_Fin

CNTCT_Exit:
	;set operation mode to be NWAY or AutoSense which are bound in case of MiiPhy
	;----------------------------------------------------------------------------
	or      ah, ModeNWAY or ModeAUTOSENSE
CNTCT_Fin:
	pop     cx
	ret
ConvertNwayToConnectionType     endp

END_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ConvertMediaTypeToNwayLocalAbility      proc
;
; Description:
;
; On Entry:
;               AX - MediaType (in SROM format)
; On Return:
;               AX - Nway Local ability
;
;               Flags:
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
START_DATA_SEGMENT_RUNTIME

MediaToNwayConversionTable      db     01h   ;TP
				db     00h   ;BNC
				db     00h   ;AUI
				db     04h   ;100BaseTX \SymScr
				db     02h   ;TP-FD
				db     08h   ;100BaseTX-FD  \SymScr-FD
				db     10h   ;100BaseT4
				db     04h   ;100BaseFX
				db     08h   ;100BaseFxFD
				db     01h   ;MediaMiiTP
				db     02h   ;MediaMiiTpFD
				db     00h   ;MediaMiiBNC
				db     00h   ;MediaMiiAUI
				db     04h   ;MediaMii100BaseTX
				db     08h   ;MediaMii100BaseTxFD
				db     10h   ;MediaMii100BaseT4
				db     04h   ;MediaMii100BaseFX
				db     08h   ;MediaMii100BaseFxFD

END_DATA_SEGMENT_RUNTIME

START_CODE_SEGMENT_RUNTIME

ConvertMediaTypeToNwayLocalAbility      proc

	 ;Clear irrelevant bits
	 ;---------------------
	 xor    ah, ah

	;Convert media to Nway advertisement bits
	;----------------------------------------
	push    bx
	lea     bx, MediaToNwayConversionTable
	xlat
	pop     bx
	shl     ax, 5                   ;Put the bit in correct position

	ret
ConvertMediaTypeToNwayLocalAbility      endp

;******************************************************************************
;*                          Broadcom support routines                         *
;******************************************************************************

; Broadcom extended register (address 16)
; ---------------------------------------
;
;      +-----+----------------+---------------------------+-----------------------------+
;      | Bit |      Name      |       Description         |        Comments             |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 15  | JABDIS         |1=Jubber Disabled          | Default 0  (R/W)            |
;      |     |                |1=Jubber Enabled           |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 14  | LINKDIS        |1=Link test Disabled       | Default 0  (R/W)            |
;      |     |                |0=Link test Enabled        |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      |13-9 | reserved       |                           |Write as 0, Ignore on read   |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  8  |FORCEFAIL_EN    |1=Force fail enabled       | Default 1   (R/W)           |
;      |     |                |0=Force fail disabled      |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 7-5 |RV_CNTR         |Revision control indicator | Value is 000  (RO)          |
;      +-----+----------------+---------------------------+-----------------------------+
;      | 4-3 |HSQ:LSQ         |Defines the squelch mode of|10=High squelch, 00=Normal   |
;      |     |                |the carrier sense mechanism|01=Low Squelch,11=Not allowed|
;      |     |                |                           |Default 00     (R/W)         |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  2  |TXDAC power mode|                           |Default 0      (R/W)         |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  1  |Speed Indication|1 = 100Mbps mode           |Default 0       RO           |
;      |     |                |0 =  10Mbps mode           |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;      |  0  |reserved        |                           |                             |
;      +-----+----------------+---------------------------+-----------------------------+
;
;
MII_BROADCOM_EXTENDED_REG_ADDRESS       equ     32

BROADCOM_EXT_REG_FORCE_FAIL_EN_MASK     equ    100h
BROADCOM_EXT_REG_SPEED_MASK             equ      2h

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         HandleBroadcomMediaChangeFrom10To100    proc
;
; Description:
;
; On Entry:
;         BX - PhyStrucPTR
;
; On Return:
;
;
;               Note:
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
HandleBroadcomMediaChangeFrom10To100    proc

	push    ax
	push    dx

	;   If speed has changed from 10 to 100
	;       ReInit the chip
	;--------------------------------------
	mov     dx, MII_BROADCOM_EXTENDED_REG_ADDRESS
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyReadRegister
	push    ax                                   ;Save word read.
	cmp     ax, WORD PTR ((MiiPhySTRUC PTR [bx]).MiiPhyRegs[MII_BROADCOM_EXTENDED_REG_ADDRESS])
	je      SHORT HBMC_NoSpeedChange

	;MII Broadcom Extended reg (offset 16) has been changed
	;Test line speed indication only if FORCE FAIL EN bit is set
	;(Broadcom unique)
	;-----------------------------------------------------------
	test    ax, BROADCOM_EXT_REG_FORCE_FAIL_EN_MASK
	jz      SHORT HBMC_BrdcmSpeedInValid

	;Check if Speed has been changed from 10 to 100
	;-----------------------------------------------
	test    ax, BROADCOM_EXT_REG_SPEED_MASK
	jz      SHORT HBMC_SpeedIs10

	;If reached this point speed has changed to 100 .
	;check if perv speed had been 10
	;------------------------------------------------
	test    WORD PTR ((MiiPhySTRUC PTR [bx]).MiiPhyRegs[MII_BROADCOM_EXTENDED_REG_ADDRESS]),\
									 BROADCOM_EXT_REG_SPEED_MASK
	jnz     SHORT HBMC_NoSpeedChange

	;Speed was changed - reset chip
	mov     ax, RESET
	call    (MiiPhySTRUC PTR [bx]).Mii.PhyRoutines.PhyAdminControl

	;Restore and write Old control value
	;-----------------------------------
	mov     ax, (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg
	mov     dx, PhyRegsSTRUC.ControlReg
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyWriteRegister

HBMC_BrdcmSpeedInValid:
HBMC_SpeedIs10:
HBMC_NoSpeedChange:
	pop     WORD PTR ((MiiPhySTRUC PTR [bx]).MiiPhyRegs[MII_BROADCOM_EXTENDED_REG_ADDRESS])

	pop     dx
	pop     ax
	ret
HandleBroadcomMediaChangeFrom10To100    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         GetBrodcomPhyConnectionType     proc
;
; Description:
;       Checks and returns Broadcom's Phy connection type using Broadcom's
;       Vendor specific registers and the standart Control Reg.
;
; On Entry:
;         BX - PhyStrucPTR
;
; On Return:
;         Upon success:
;               Carry Flag - Cleared
;               AX         - Connection type
;         Upon Failure:
;               Carry Flag - Set
;
;         DX - Destroyed
;
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
GetBroadcomPhyConnectionType    proc

	;Read but don't save broadcom private register  (saving it will affect
	;HandleBroadcomMediaChangeFrom10To100 results
	;---------------------------------------------------------------------
	mov     dx, MII_BROADCOM_EXTENDED_REG_ADDRESS
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyReadRegister

	;MII Broadcom Extended reg reg 16) has been changed
	;Test line speed indication only if FORCE FAIL EN bit is set
	;(Broadcom unique)
	;-----------------------------------------------------------
	test    ax, BROADCOM_EXT_REG_FORCE_FAIL_EN_MASK
	jz      SHORT GBPCT_BrdcmSpeedInValid

	;Read Control reg (which will help us detirmining the Line speed)
	;----------------------------------------------------------------
	push    ax
	mov     dx, PhyRegsSTRUC.ControlReg
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyReadRegister
	mov     (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg, ax
	pop     ax

	;Check if Speed is 10 or 100
	;---------------------------
	test    ax, BROADCOM_EXT_REG_SPEED_MASK
	jz      SHORT GBPCT_SpeedIs10

	;Speed is 100
	;------------
	mov     ax, ConnectionMii100BaseT4                      ;T4 has no FD
	jmp     SHORT GBPCT_TestForNway

GBPCT_SpeedIs10:
	mov     ax, ConnectionMiiTp                             		     ;Assume Tp
	test    (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg, MiiPhyCtrlDuplexMode   ;FD bit serves also as
	jz      SHORT GBPCT_TestForNway                         		     ;Status bit.
	mov     ax, ConnectionMiiTpFD                           		     ;Connection is NWAY TP-FD

GBPCT_TestForNway:
	test    (MiiPhySTRUC PTR [bx]).MiiPhyRegs.ControlReg, MiiPhyCtrlEnableNway
	jz      SHORT GBPCT_DoneWithNway
	or      ah, ModeAUTOSENSE or ModeNWAY
GBPCT_DoneWithNway:
GBPCT_Exit:
	clc
	ret
GBPCT_BrdcmSpeedInValid:
	mov     ax, MAC_CONN_UNKNOWN
	stc
	ret
GetBroadcomPhyConnectionType    endp

;******************************************************************************
;*                          National support routines                         *
;******************************************************************************

;------------------------------------------
; National extended register:
; ---------------------------
;       Register offset:        19h
;       Bit:                     6
;       Bit value:               0 = 100Tx
;                                1 =  10Tx
;       Bit name:               SPEED 10
;------------------------------------------

NATIONAL_PHY_ADDRESS_REGISTER_OFFSET    equ     (2*19h)
NATIONAL_PAR_SPEED_BIT_MASK             equ     40h

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MiiNationalPhyParallelDetectedConnection     proc
;
; Description:
;       Checks and returns National's Phy connection type using National's
;       Vendor specific register.
;       The line speed value read from the register is valid only when parallel
;       detection had been performed.
;
; On Entry:
;         BX - PhyStrucPTR
;
; On Return:
;         Upon success:
;               Carry Flag - Cleared
;               AX         - Connection type
;         Upon Failure:
;               Carry Flag - Set
;
;         DX - preserved
;
;
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MiiNationalPhyParallelDetectedConnection        proc

	push    dx

	;Read but don't save National's private register
	;-----------------------------------------------
	mov     dx, NATIONAL_PHY_ADDRESS_REGISTER_OFFSET
	call    (MiiPhySTRUC PTR [bx]).MiiPhyInternalRoutines.PhyReadRegister
	jc      SHORT MNPPDC_Exit

	;Check Speed bit
	;---------------
	test    ax, NATIONAL_PAR_SPEED_BIT_MASK
	mov     ah, ModeAUTOSENSE or ModeNWAY
	mov     al, MediaMii100BaseTX
	jz      SHORT MNPPDC_Exit
	mov     al, MediaMiiTP

MNPPDC_Exit:
	pop     dx
	ret

MiiNationalPhyParallelDetectedConnection        endp



END_CODE_SEGMENT_RUNTIME
