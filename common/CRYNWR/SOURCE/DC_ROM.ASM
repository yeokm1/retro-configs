;*******************************************************************************
;
; DC_ROM.INC
;
; Include file for Dec Tulip and Fast Ethernet boards that handles the various ROM
; types and formats used by the our chips (DC21040, DC21041, DC21140).
;
; Ther are several Roms and formats to support:
;  Tulip2 has 2 Different roms:
;    - EISA Rom which is a stand-alone rom holding the IEEE address of the Nic in
;      the Old-fashion DEC format.
;    - PCI rom which is an Srom connedted Via CSR9 while the chip is responsible
;      for activating its signals (Holding IEEE address only)
; Fasternet and Tulip3 Have an Srom connected via CSR9 and the driver is responsible
; for activating its HDW signals.
; This Rom have 2 formats:
; - Classic (also called Legacy) which Holds the IEEE address rom at the beginning and
;   board specific data followed.
; - New format Wich can support more then one chip in the same rom (for Quad-Tulip)
;   and has a different format.
;
; This module provides the support routines for handling the above Roms and their
; different formats.
;
;Written by:   Moti Haimovsky
; Date:         7-Feb-1995
;
;
; Copyright (C) 1994 by Digital Equipment Corporation 
; All rights reserved.
;
; Modification History:
;
;       By            Date     Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; Haimovsky Moti  26-Feb-1995 2.10  Added support for reading the new SROM
;                                   (Format and version) and parsing its
;                                   parameters.
; Haimovsky Moti  25-Jun-1995 2.13  Fixed bug in finding the device leaf in a
;                                   Multi-device SROM.
;                                   Fixed Incorrect Ethernet address Calculation in a
;                                   Multi-device SROM.
; Haimovsky Moti  12-Jul-1995       Added support for SROM 1.0 new features:
;                                       Media activity invalid bit
;                                       AutoSenseDisable & AutoDetect (8800h & 0800h)
;                                       New Media       100BaseT4
;                                                       100BaseFx
;                                                       100BaseFxFD
;                                       Order of media appearance in Media leaf is its precedence (Low to High)
;                                       Add enable AutoSense bit in Selected connection type
;                                       Add default media bit in mediaCode entry                                                                
; Haimovsky Moti  13-Jul-1995       Added IndexToOffset macro
; Haimovsky Moti  17-Jul-1995       Modified NIC's structure and the routines using it.
; Haimovsky Moti  26-Jul-1995       Minor fixes to the above rooutines.
; Haimovsky Moti  25-Jun-1995 2.14  Fixed bug in DetermineNIcAutoSenseCapabilities
;                                   Routine used to set Carry upon exit.
; Haimovsky Moti  12-Sep-1995 @@@@  Marked sub Activr invalid from cx in ParseSrom v10
;                                   for supporting temp Phy support. (search for @@@)
; Haimovsky Moti  22-Oct-1995 2.20 -New MII Media codes
; Haimovsky Moti  29-Oct-1995       Added IsLegalConnection.
;                                  -Fixed bugs in Error handling when read SROM failes.
;                                  -Modified readSrom to put device in RUN mode prior
;                                   reading it.
; Moti Haimovsky  31-Oct-1995      -Modified MII phy GPR reset seq. and
;                                   Mii phy GPR sequence to word array.
; Moti Haimovsky   6-Nov-1995      -Added Power management entry in NIC struc.
; Moti Haimovsky  12-Nov-1995      -Fixed error handlig bug in ParseSROM_Classic
; Moti Haimovsky  19-Nov-1995      -Removed temp mii phy support.
; Moti Haimovsky  20-Nov-1995      -Added Srom V3.0 support wich also involved
;                                   modifying ParseSROM_V1_0 routine.
; Haimovsky Moti  30-Nov-1995 2.30 -Added Twinet support in Nic and SROM parsing.
; Haimovsky Moti  02-May-1996 2.33 -Modify handling Fasternet CSR6 parsing to keep HBD bit.
;                 06-May-1996      -Changed Media entry format to be a general one for all (SIA & SYM)
;
; Moti Haimovsky  19-Aug-1996 2.41 -Added parsing SROM V4.0.
;
; Moti Haimovsky  10-Sep-1996 2.42 -Changed the memory buffre used for reading the SROM data to
;				    from RxResourcesPoolPTR to TxResourcesPoolPTR due to the
;				    new memory allocation scheme which allocates the RX buffers and
;				    descriptors over the Init code.
;				   -Added MII phy ID entry in order to support ML6692
; Gal Kaplan      15-Aug-1996      -Minor OEM-specific changes for NDIS2 integration
; Moti Haimovsky  23-Sep-1996 2.50 -Modifications for NDIS2-ODI unification
;				   -Fixed bug in GetDeviceEntryInSROM with only 1 dev. entry,
;				    assumed Handle field is 0 instead of ignoring it completly.
; Moti Haimovsky  31-Sep-1996	   -Change the command "add	ax, SIZE ExtendedFormatHeader.EF_Length"
;				    to "add	ax, TYPE ExtendedFormatHeader.EF_Length" since TASM resolved
;				    the SIZE operation to the csize of the whole struct nad not the EF_Length.
;				    it resolves TYPE correctly. but remember that TYPE will FAIL if EF_Length
;				    is an Array of elements (TYPE will then return one element size only)
; Moti Haimovsky  11-Apr-1997 2.52 -Modified raed&parse Srom params to support SROM V4.0 occupying the
;				    whole SROM space
; Moti Haimovsky  13-Apr-1997 2.60 -Modified IEEE address handling to use DidUserOverrideIEEEAddress
;				    for detirmning if user override IEEE adderesss and saving the
;				    SROM address in public variable. 
; Moti Daniel	  24-Sep-1997 2.61 -Adding support to 4K SROM the changes in detail are :
;				    Change MakeSureSROM_IsIdle because the modern SROMs needs more time to stabilize
;				    Adding SROM_ADDRESS_LENGTH_1K SROM_SIZE_IN_BYTES_1K ADDRESS_LENGTH_4K SROM_SIZE_IN_BYTES_4K
;				    to support diffrent SROM sizes.
; 				    Adding ROM_Init to initiialize SROM size that is to set srom_length & srom_address_size.
;				    Change in ReadAndParseSRomParameters to use srom_length.
;				    Change in ReadSROMWord to use srom_address_size.
;				    Change the delay in SromDelay from 840nSec to 1680nSec to support modern SROMs.
;*******************************************************************************
;******************************************************************************
;*                                 S R O M                                    *
;******************************************************************************
include  SEG_DEFS.INC
.386
include	 nic.inc
.8086
include	 DC_ROM.ASH
.386
include	 dc_regs.inc

START_DATA_SEGMENT_INIT
;******************************************************************************
;*                          S R O M     F O R M A T                           *
;******************************************************************************
;
;                                   -----------
;                                   Srom Legacy
;                                   -----------
;       Chips' SROM support
;     +-----------------+----------+---------------+------------+
;     |   Block Format  |   21041  |    21140/A    |    21142   |
;     +-----------------+----------+---------------+------------+
;     |  Legacy         |    Yes   |Yes (DC21140 only)    No    |
;     +-----------------+----------+---------------+------------+
;
;
;                                   ---------
;                                   Srom V3.0
;                                   ---------
;       Chips' SROM support
;     +-----------------+----------+---------------+------------+
;     |   Block Format  |   21041  |    21140/A    |    21142   |
;     +-----------------+----------+---------------+------------+
;     | Compact         |    Yes   |    Non MII    |      No    |
;     | Extended Type 0 |    No    |    Non MII    |      No    |
;     | Extended Type 1 |    No    |      MII      |      No    |
;     | Extended Type 2 |    No    |      No       |    Non MII |
;     | Extended Type 3 |    No    |      No       |      MII   |
;     +-----------------+----------+---------------+------------+
;
;
;
;                                   ---------
;                                   Srom V1.0
;                                   ---------
;       Chips' SROM support
;     +-----------------+----------+---------------+------------+
;     |   Block Format  |   21041  |    21140/A    |    21142   |
;     +-----------------+----------+---------------+------------+
;     | Compact         |    Yes   |    Non MII    |      No    |
;     +-----------------+----------+---------------+------------+
;
;               15                    8 7                     0
;               +----------------------+----------------------+     ------
;               |          Sub-System Vendor ID (0s)          |  0       
;               +----------------------+----------------------+          
;               |             Sub-System ID (0s)              |  2
;               +----------------------+----------------------+          I
;               |                                             |  4       D
;               |                  Reserved (0s)              |
;               |                   (12 bytes)                | 
;               |                                             | 14       B
;               +----------------------+----------------------+          L
;               |                ID_Checksum (0s)             | 16       O
;               +----------------------+----------------------+          C
;               |    Adapter Count (n) | SROM Format Version  | 18       K
;               +----------------------+----------------------+
;               |            IEEE Network address             | 20
;               |                (6 bytes)                    |          
;               |                                             | 24       
;               +----------------------+----------------------+     ------
;                                      |Adapter0 Device_Number| 26            
;               +----------------------+----------------------+
;               |        Adapter0 info (Leaf offset)          | 27
;               +----------------------+----------------------+
;                                      |Adapter1 Device_Number| 29
;               +----------------------+----------------------+
;               |        Adapter1 info (Leaf offset)          | 30
;               +----------------------+----------------------+
;                                      |Adapter2 Device_Number| 32
;               +----------------------+----------------------+
;               |        Adapter2 info (Leaf offset)          | 33
;               +----------------------+----------------------+
;                                      |Adapter n-1 Dev_Number|
;               +----------------------+----------------------+
;               |        Adapter n-1 info (Leaf offset)       |
;               +----------------------+----------------------+
;               |            Sign-on message (ASCIIZ)         |
;               |  (Size according so space remaines is SROM  | 
;               |                                             |
;               +----------------------+----------------------+
;               |             Adapter_0 info leaf             |
;               |                                             |
;               +----------------------+----------------------+
;               |             Adapter_1 info leaf             |
;               |                                             |
;               +----------------------+----------------------+
;               |             Adapter_2 info leaf             |
;               |                                             |
;               +----------------------+----------------------+
;               |            Adapter_n-1 info leaf            |
;               |                                             |
;               +----------------------+----------------------+
;               |                                             |
;               |                     0's                     |
;               |                                             |
;               +----------------------+----------------------+
;               |      2 Least Significant Bytes of CRC32     |126
;               +----------------------+----------------------+
;
;
;                                   ---------
;                                   Srom V4.0
;                                   ---------
;
;               15                    8 7                     0
;               +----------------------+----------------------+     ------
;               |          Sub-System Vendor ID (0s)          |  0       
;               +----------------------+----------------------+          
;               |             Sub-System ID (0s)              |  2
;               +----------------------+----------------------+          I
;               |           CardBus CIS pointer low           |  4       D
;               +----------------------+----------------------+          
;               |          CardBus CIS pointer high           |  6
;               +----------------------+----------------------+          
;               |                                             |  8       
;               |                  Reserved (0s)              |
;               |                    (8 bytes)                | 
;               |                                             | 14       B
;               +----------------------+----------------------+          L
;               |   ID_Reserved2 (0s)  |  ID_Checksum (0s)    | 16       O
;               +----------------------+----------------------+          C
;               |    Adapter Count (n) | SROM Format Version  | 18       K
;               +----------------------+----------------------+
;               |            IEEE Network address             | 20
;               |                (6 bytes)                    |          
;               |                                             | 24       
;               +----------------------+----------------------+     ------
;                                      |Adapter0 Device_Number| 26            
;               +----------------------+----------------------+
;               |        Adapter0 info (Leaf offset)          | 27
;               +----------------------+----------------------+          S
;                                      |Adapter1 Device_Number| 29       R
;               +----------------------+----------------------+          O
;               |        Adapter1 info (Leaf offset)          | 30       M
;               +----------------------+----------------------+
;                                      |Adapter2 Device_Number| 32
;               +----------------------+----------------------+          A
;               |        Adapter2 info (Leaf offset)          | 33       d
;               +----------------------+----------------------+          a
;                                      |Adapter n-1 Dev_Number|          p
;               +----------------------+----------------------+          t
;               |        Adapter n-1 info (Leaf offset)       |          e
;               +----------------------+----------------------+          r
;               |            Sign-on message (ASCIIZ)         |
;               |  (Size according so space remaines is SROM  | 
;               |                                             |          I
;               +----------------------+----------------------+          n
;               |             Adapter_0 info leaf             |          f
;               |                                             |          o
;               +----------------------+----------------------+
;               |             Adapter_1 info leaf             |
;               |                                             |         (
;               +----------------------+----------------------+          S
;               |             Adapter_2 info leaf             |          a
;               |                                             |          m
;               +----------------------+----------------------+          e
;               |            Adapter_n-1 info leaf            |
;               |                                             |          a
;               +----------------------+----------------------+          s
;               |                                             |
;               |                     0's                     |
;               |                                             |          V
;               +----------------------+----------------------+          3
;               |           Manufacturere Reserved            |92        .
;               +----------------------+----------------------+          0
;               |  2 LS Bytes of CRC32 (calc on bytes 0:93)   |94         )
;               +----------------------+----------------------+     ------
;               |                                             |96
;               |             Magic Packet  Block             |
;               |                                             |
;               |                                             |
;               |                                             |
;               |                                             |126
;               +----------------------+----------------------+     ------

;******************************************************************************
;*                          S R O M     S I Z E                               *
;******************************************************************************
;
SROM_ADDRESS_LENGTH_1K		EQU		6
SROM_SIZE_IN_BYTES_1K		EQU		128
ADDRESS_LENGTH_4K    		EQU		8
SROM_SIZE_IN_BYTES_4K       	EQU		128

;------------------------
;Fromat related constants
;------------------------
FORMAT_LEGACY           equ      0
FORMAT1_0               equ      1
FORMAT3_0               equ      3
FORMAT4_0               equ      4
FORMAT_VERSION_LOC      equ     18

;Format 1.0
;----------
;Format V1.0 constants
;------------------------
ADAPTER_COUNT_LOC_v1_0  equ     19
LEAVES_START_LOC_v1_0   equ     26
LEAF_PTR_SIZE_v1_0      equ      2      ;(sizeof(WORD))
ENET_ADDR_LOC_v1_0      equ     20


;Adapter Sign-On String
;----------------------
DE500String             db      "DE500-XA"
DE500StringLength       equ     $-DE500String
DE500StringLocation     equ     1Dh

;Format 4.0
;----------
;Format V4.0 constants
;------------------------
SROM_V4_ADAPTER_INFO_LENGTH     equ     96



AdapterLeafPTR  struc
	DeviceNumber    db      ?
	LeafOffset      dw      ?
AdapterLeafPTR  ends

;                          Adapter info Leaf format
;                          ------------------------
;-------------------------
;DC21041 info leaf format:
;-------------------------
;               15                    8 7                     0
;               +----------------------+----------------------+
;               |          Selected Connection Type           | 0
;               +----------------------+----------------------+
;                                      |    Media Count (k)   | 2
;               +----------------------+----------------------+
;               |                Media_1 block                | 3 (Variable size)
;               +----------------------+----------------------+
;               |                Media_2 block                |   (Variable size)
;               +----------------------+----------------------+
;               |                Media_k block                |   (Variable size)
;               +----------------------+----------------------+
;
;
;DC21041 Selected Connection Type
;--------------------------------
; Is fully defined in DC21140 leaf.  Notice however that there is a difference
; in the AutoSense definitions. the translation SW will transform DC21041 AutoSense
; to DC21140 AutoSense for ease of use.
;       0x0000  TP
;       0x0100  TP with Nway
;       0x0204  TP Full Duplex
;       0x0400  TP w.o Link Pass test
;       0x0001  BNC
;       0x0002  AUI
;       0x0800  AutoSense
;       0x0900  AutoSense with Nway

;DC21041 Media Block Format
;--------------------------
;                                        7   6  5             0
;                                      +---+---+--------------+     
;               15                     |Res|EXT|  Media Code  |
;               +----------------------+----------------------+          
;               |              Media Specific Data            |  
;               |      (Exists only when EXT bit is set)      |
;               +----------------------+----------------------+
;
;Possible Media code values are:
;       00h     TP
;       01h     BNC
;       02h     AUI
;       04h     TP Full Duplex

;DC21X4_MEDIA_CODE_MASK         equ     3Fh    ;Defined in Nic.inc
DC21041_EXT_MASK                equ     40h




;DC21041 Media Specific Data Format
;----------------------------------
;               15                    8 7                     0
;               +----------------------+----------------------+
;               |                 CSR13 <15..0>               | 
;               +----------------------+----------------------+
;               |                 CSR14 <15..0>               |
;               +----------------------+----------------------+
;               |                 CSR15 <15..0>               |
;               +----------------------+----------------------+
SIARegsSTRUC    struc
	SIA_CSR13   dw      0
	SIA_CSR14   dw      0
	SIA_CSR15   dw      0
SIARegsSTRUC    ends

;-------------------------
;DC21140 info leaf format:
;-------------------------
;               15                    8 7                     0
;               +----------------------+----------------------+
;               |          Selected Connection Type           | 0
;               +----------------------+----------------------+
;               |    Media Count (k)   |General Purpose Cntrl | 2
;               +----------------------+----------------------+
;               |                Media_1 block                | 4 (Variable size)
;               +----------------------+----------------------+
;               |                Media_2 block                |   (Variable size)
;               +----------------------+----------------------+
;               |                Media_k block                |   (Variable size)
;               +----------------------+----------------------+
;
;
;DC21140 Selected connection type
;--------------------------------
;             15 14  12  11  10  9   8  7                     0
;           +---+------+---+---+---+---+----------------------+
;           |   |  Res |   |   |   |   |      Media Code      | 
;           +---+------+---+---+---+---+----------------------+
;             |          |   |   |   |
; Dynamic AutoSense      |   |   |   Nway
;    Disable             |   |   |
;                AutoSense   |   Full Duplex
;                            |
;                 No Link Test
;
;DynamicAutosenseDisable is valid only when ConnectionType == AutoSense.
;
;Possible Selected connection type values are:
;       0000h   TP
;       0100h   TP with Nway
;       0204h   TP Full Duplex
;       0400h   TP No link test (w.o link pass test)
;       0001h   BNC
;       0002h   AUI
;       0003h   SymScr (100BaseTx)
;       0205h   SymScr Full Duplex
;       0006h   100BaseT4
;       0007h   100BaseFx (Fiber)
;       0208h   100BaseFx Full Duplex
;       0800h   Powerup & Dynamic Autosense (In Fasternet - Only rev 1.2 and above, or DE500 Nic)                  
;       8800h   Powerup AutoSense & Disable dynamic autosense (Also called AutoDetect)
;       0900h   Powerup & AutoSense with Nway
;       8900h   AutoDetect with Nway
;      0FFFFh   No selected media information

DC21140_DISABLE_AUTOSENSE_MASK  equ     8000h


;DC21140 Media Block Format
;--------------------------
;                                       7   6 5                0
;                                      +--+--+----------------+     
;                                      | Res |  Media Code    | 0
;                                      +--+--+----------------+          
;               15                     |      GEP Data        | 1
;               +----------------------+----------------------+
;               |               Command (2 Bytes)             | 3
;               +----------------------+----------------------+
;
;Possible values are:
;       00      TP      (10M)
;       01      BNC     (10M)
;       02      AUI     (10M, Reserved)
;       03      SymSCR  (100BaseTx)
;       04      TP FullDuplex
;       05      SymScr FullDuplex
;       06      100BaseT4
;       07      100BaseFx       (Fiber)
;       08      100BseFxFD      (Fiber Full-Duplex)

;DC21X4_MEDIA_CODE_MASK          equ     3Fh  ;defined in Nic.inc
DC21140_MEDIA_BLOCK_SROM_SIZE   equ     4


;DC21140 Command Format
;----------------------
;                        1
;                 15  14 3         8  7   6   5   4   3   2   1   0
;               +---+---+-----------+---+---+---+---+---+---+---+---+
;               |   |   |     0     |   |   |   |   |           |   |
;               +---+---+-----------+---+---+---+---+---+---+---+---+
;                 |   |               |   |   |   |       |       |
;    Active Invalid   |              POL  |   | CSR6      |   CSR6<PS>
;         Default Media                   |   | <TTM>     |
;                                   CSR6<SCR> |      Media_Sense
;                                        CSR6<CS>     bit number
;    If Active Invalid == 0 then
;    ---------------------------
;       GPR Activity    Polarity        Indicates 
;           Bit           Bit           That the media is...
;       -------------+-------------+------------------------
;            0             0           Not Active
;            0             1               Active
;            1             0               Active       
;            1             1           Not Active
;       -------------+-------------+------------------------


DC21140_LINK_SENSE_PIN_MASK             equ     0Eh
DC21140_POLARITY_BIT_MASK               equ     80h
DC21140_DefaultMedia_MSAK               equ   4000h     ;When set specifies that this is the Default Media
DC21140_ActiveInvalid_MASK              equ   8000h
DC21140_CSR6_BITS_MASK                  equ     71h
DC21140_CSR6_BITS_REAL_LOCATION         equ     18
DC21140_CSR6_BITS_MASK_REAL_LOCATION    equ     (DC21140_CSR6_BITS_MASK SHL DC21140_CSR6_BITS_REAL_LOCATION)

;ACTIVE_INVALID          equ     1                       ;Defined in Nic.Inc
;NOT_ACTIVE_INVALID      equ     0                       ;Defined in Nic.Inc
;ACTIVE_VALID            equ     NOT_ACTIVE_INVALID      ;Defined in Nic.Inc

;                                   ---------
;                                   Srom V3.0
;                                   ---------
;General Format
;--------------
;   The same as Format V1.0

;DC21041 info leaf format:
;-------------------------
;   The same as Format V1.0

;DC21140 info leaf format:
;-------------------------
;   The same as Format V1.0
;               15                    8 7                     0
;               +----------------------+----------------------+
;               |          Selected Connection Type           | 0
;               +----------------------+----------------------+
;               |    Media Count (k)   |General Purpose Cntrl | 2
;               +----------------------+----------------------+
;               |                Info_Block_1                 | 4 (Variable size)
;               +----------------------+----------------------+
;               |                Info_Block_2                 |   (Variable size)
;               +----------------------+----------------------+
;               |                Info_Block_K                 |   (Variable size)
;               +----------------------+----------------------+
;
;DC21140 Info Block Format
;-------------------------
DC21140_INFO_BLOCK_FORMAT_INDICATION    equ     80h

;Can be of 2 types:
;
; - Compact format
;   --------------                    7   6   5                0
;                                    +---+---+----------------+     
;                                    | 0 |Res|  Media Code    | 0        
;                                    +---+---+----------------+          
;               15                   |GeneralPurpose Port Data| 1
;               +--------------------+------------------------+
;               |               Command (2 Bytes)             | 3
;               +----------------------+----------------------+
; Notice that bit7 in media code field must be 0
;
; The same as the media info block in SROM Format V1.0

COMPACT_FORMAT_BLOCK_SIZE       equ     5

;
;
; - Extended format
;   ---------------
;                       7    6                 0
;                       +---+--------------------+
;                       | 1 |     Length         | 0        
;                       +---+--------------------+          
;                       |         Type           | 1
;                       +------------------------+
;                       |      Block Data        | Length-1 bytes
;                       +------------------------+
;
; Notice that bit7 in media code field must be 1
;
; Length - size in bytes of this info block.
; Type   - Type of extended block which may be:
;
ExtendedFormatHeader    struc
	EF_Length       db      ?
	EF_Type         db      ?
ExtendedFormatHeader    ends

EXTENDED_FORMAT_BLOCK_SIZE_MASK equ  (NOT DC21140_INFO_BLOCK_FORMAT_INDICATION)
EXTENDED_FORMAT_BLOCK_TYPE_0    equ     0
EXTENDED_FORMAT_BLOCK_TYPE_1    equ     1
;
;
;
;       00 - Extended format - Block type 0
;            ------------------------------
;                                     7    6                 0
;    ----                            +---+--------------------+
;                                    | 1 |       5            | 0  Length
;    Block                           +---+--------------------+          
;    Type                            |           00           | 1  Type
;     0                              +---+---+----------------+-----------
;                                    | 0 |Res|  Media Code    | 2        ^
;                                    +---+---+----------------+      Block Data    
;               15                   |GeneralPurpose Port Data| 3   (Same as
;               +----------------------+----------------------+      Compact format)
;               |               Command (2 Bytes)             | 4,5
;    ----       +----------------------+----------------------+-----------
;
;
;
;       01 - Extended format - Block type 1  (Fasternet and Fasternet3 only !)
;            ------------------------------
;                       7    6                  0
;                       +---+--------------------+
;                       | 1 |     Length         | 0        
;                       +---+--------------------+          
;                       |         Type           | 1
;             -----     +------------------------+
;                       |       Phy Number       | 2 
;                       +------------------------+
;                       |  GPR Sequence Length   | 3
;                       +------------------------+
;                       |      GPR Sequence      | 4
;                       +                        +
;                       |(GPR seq. length bytes) |
;                       +------------------------+
;                       | Reset Sequence Length  | 4+Gpr_len
;                       +------------------------+
;                       |     Reset Sequence     | 5+Gpr_len
;          Block        +                        +
;                       |(Reset seq.length bytes)|
;          Data         +------------------------+
;                       |   Media Capabilities   | 5+Gpr_len+Rst_len
;                       +                        +
;                       |       (2 bytes)        |
;                       +------------------------+
;                       |   Nway Advertisement   | 7+Gpr_len+Rst_len
;                       +                        +
;                       |       (2 bytes)        |
;                       +------------------------+
;                       |      FDX bit map       | 9+Gpr_len+Rst_len
;                       +                        +
;                       |       (2 bytes)        |
;                       +------------------------+
;                       |      TTM bit map       | 11+Gpr_len+Rst_len
;                       +                        +
;                       |       (2 bytes)        | 12+Gpr_len+Rst_len
;             -----     +------------------------+
;
;
;
;
;--------------
;TWINET support
;--------------
;
;DC21142 leaf format
;-------------------
;
;
;         15                    7                       0  in leaf
;        +-----------------------------------------------+
;        |         Selected Connection Type              |  0
;        +---------------------+-------------------------+
;                              |   Block Count  (k)      |  2
;        +---------------------+-------------------------+
;        |               Info_block_1                    |  3
;        +-----------------------------------------------+
;        |               Info_block_2                    |
;        +-----------------------------------------------+
;        |                   .                           |
;        |                   .                           |
;        +-----------------------------------------------+
;        |               Info_block_k                    |
;        +-----------------------------------------------+
;
;
;DC21142 info block type for non-MII media
;-----------------------------------------
;
;
;                          7     6                      0   Offset (bytes)
;                       +-----+--------------------------+
;                       |  1  |        Length            | 0
;                       +-----+--------------------------+
;                       |              Type = 2          | 1
;               --------+-----+-----+--------------------+    -----------
;                       | Res | Ext |    Media code      | 2      Same as DC21041
;                       +-----+-----+--------------------+          media block
;                Block  |    Media specific data         | 3           Format
;                       +--------------------------------+    -----------
;                Data   |   General Purpose port ctrl    | a (3 or 9)
;                       |                                |
;                       +--------------------------------+
;                       |   General Purpose port data    | a+2
;                       |                                | 
;               --------+--------------------------------+
DC21142_INFO_BLOCK_FORMAT_INDICATION    equ     DC21140_INFO_BLOCK_FORMAT_INDICATION
EXTENDED_FORMAT_BLOCK_TYPE_2    equ     2
;
;DC21X4_MEDIA_CODE_MASK         equ     3Fh  			;defined in Nic.inc
DC21142_EXT_MASK                equ     DC21041_EXT_MASK
;
;
;DC21142 Media Specific Data Format
;----------------------------------
;Same as DC21041 Media Specific Data Format
;
;                        15             8 7             0
;                       +----------------+---------------+
;                       |        CSR13 <15..0>           |
;                       +----------------+---------------+
;                       |        CSR14 <15..0>           |
;                       +----------------+---------------+
;                       |        CSR15 <15..0>           |
;                       +----------------+---------------+
;
;
;
;Gen. Purpose Control
;-------------------
;The value of the General Purpose mask register for this medium.
;
;Gen. Purpose  port data
;-----------------------
;These 16 data bits are written to the General Purpose data register for this medium
;                       adapter_n (DC21142), when this media
;
;                       +----------------+---------------+
;                       |    GPR CTRL (CSR15 <31..16)    |
;                       +----------------+---------------+
;                       |    GPR DATA (CSR15 <31..16>)   |
;                       +----------------+---------------+
;
;
;
;DC21142 Info block for MII phy chip
;-----------------------------------
;
;                          7     6                      0   Offset (bytes)
;                       +-----+-----+--------------------+
;                       |  1  |        Length            | 0
;                       +-----+-----+--------------------+
;                       |              Type = 3          | 1
;               --------+--------------------------------+
;                       |          Phy Number            | 2
;                       +--------------------------------+
;                       |      GPR Sequence Length       | 3
;                       +--------------------------------+
;                       |         GPR Sequence           | 4
;                       |                                |
;                       |     (GPR Seq. Length bytes)    |
;               Block   +--------------------------------+
;                       |      Reset Sequence Length     | 4+GPR_len
;                       +--------------------------------+
;                       |        Reset Sequence          | 5+GPR_len
;                       |                                |
;                       |   (Reset Seq. Length bytes)    |
;               Data    +--------------------------------+
;                       |       Media Capabilities       | 5+GPR_len+Rst_len
;                       |           (2 bytes)            |
;                       +--------------------------------+
;                       |       Nway advertisement       | 7+GPR_len+Rst_len
;                       |           (2 bytes)            |
;                       +--------------------------------+
;                       |          FDX bit map           | 9+GPR_len+Rst_len
;                       |           (2 bytes)            |
;                       +--------------------------------+
;                       |          TTM bit map           |11+2*GPR_len+2*Rst_Len
;                       |           (2 bytes)            |12+GPR_len+Rst_Len
;                       +--------------------------------+
;                       |    MII connector interrupt     |3+2*GPR_len+2*Rst_Len
;               --------+--------------------------------+
;
EXTENDED_FORMAT_BLOCK_TYPE_3    equ     3
;
; GPR length      8     Number of words in the GPR sequence field.
; GPR sequence          A sequence of words that are written every time the adapter
;                       switches media to one supported by this phy chip.
;                       The first word must be a control word.
;
; Reset length    8     Number of bytes in the Reset sequece field.
; Reset sequence        Sequence of words to  be written in the order
;                       given here. 
;                       The first word must be a control word.
;
;
; Media capabilities
;                           15  14  13  12  11 10                          0
;                         +---+---+---+---+---+-----------------------------+
;                         |   |   |   |   |   |         Reserved            |
;                         +---+---+---+---+---+-----------------------------+
;                           |   |   |   |   |
;                   100BaseT4   |   |   |   10Mb-Hdx
;                    100BaseX-Fdx   |   10Mb-Fdx
;                        100BaseX-Hdx
;
;
; Nway advertisement   
;                          15           10  9   8   7   6   5  4           0
;                         +---------------+---+---+---+---+---+-------------+
;                         |   Reserved    |   |   |   |   |   |  Reserved   |
;                         +---------------+---+---+---+---+---+-------------+
;                                           |   |   |   |   |
;                                   100BaseT4   |   |   |   10Mb-Hdx
;                                    100BaseX-Fdx   |   10Mb-Fdx
;                                        100BaseX-Hdx
;
;
; Full Duplex bits      Indicates the value to write to CSR6<FDX> for this
;                       medium.
;
; Tx Threshold bits     Indicates the value to write to CSR6<TTM> for this
;                       medium.
;
; MII Connector         Indicates whether insertion/removal of the MII connector
;  Interrupt            generates an interrupt, and if so - via which general
;                       purpose pin. The possible values are as as follows:
;
;                       0x00 - no interrupt on insert/remove of MII connector
;                       0x01 - interrupt generated on GEP0
;                       0x02 - interrupt generated on GEP1
;
;                       The interrupt must also be enabled via the General Purpose
;                       control and data info (above) to take effect.

;
;       DC21143 (equ DC21142 Rev2 and above)
;       ----------------------------------- 
;
; DC21143 Info Block Format  
; -------------------------
; Same as DC21142
;         15                    7                       0  in leaf
;        +-----------------------------------------------+
;        |         Selected Connection Type              |  0
;        +---------------------+-------------------------+
;                              |   Block Count  (k)      |  2
;        +---------------------+-------------------------+
;        |               Info_block_1                    |  3
;        +-----------------------------------------------+
;        |               Info_block_2                    |
;        +-----------------------------------------------+
;        |                   .                           |
;        |                   .                           |
;        +-----------------------------------------------+
;        |               Info_block_k                    |
;        +-----------------------------------------------+
;
;
; DC21143 supports only extended info blocks.
;
; DC21143 Extended Format - Block Type 2
; --------------------------------------
; Identical to Block Type 2 used for the 21142.
;
;
; DC21143 Extended Format - Block Type 3
; --------------------------------------
; Identical to Block Type 3 used for the 21142. 
;
;
; DC21143 Extended Format - Block Type 4
; --------------------------------------
; This block is for describing SYM media only. 
; This info block should only be used to describe non-MII media.
;
;
;                                                  
;        7   6                   0  Byte Offset
;       +---+---+-----------------+
;       | 1 |    Length  (8)      |     0
;       +---+---+-----------------+
;       |      Type (0x4)         |     1
;       +-------+-----------------+
;       |  Res  |   Media Code    |     2
;       +-------+-----------------+
;       | General Purpose Control |     3
; BLOCK |       (2 bytes)         |
; DATA  +-------------------------+
;       |  General Purpose Data   |     5
;       |       (2 bytes)         |
;       +-------------------------+
;       |        Command          |     7
;       |       (2 bytes)         |
;       +-------------------------+
;
;
EXTENDED_FORMAT_BLOCK_TYPE_4   equ      4
;
;A description of the command field now follows.
;
;DC21143 Media code (for Type 4 block)
;-------------------------------------
; Possible values are:
;       0x03   100BaseTx (Symbol Scrambler)
;       0x05   100BaseTx Full_Duplex
;       0x06   100BaseT4
;       0x07   100BaseFx (Fiber)
;       0x08   100BaseFx Full_Duplex
;
;
;DC21143 Command Format
;----------------------
; Same as DC21140 Command Format
;                        1
;                 15  14 3         8  7   6   5   4   3   2   1   0
;               +---+---+-----------+---+---+---+---+---+---+---+---+
;               |   |   |     0     |   |   |   |   |           |   |
;               +---+---+-----------+---+---+---+---+---+---+---+---+
;                 |   |               |   |   |   |       |       |
;    Active Invalid   |              POL  |   | CSR6      |   CSR6<PS>
;         Default Media                   |   | <TTM>     |
;                                   CSR6<SCR> |      Media_Sense
;                                        CSR6<CS>     bit number
;

DC21143_LINK_SENSE_PIN_MASK             equ     DC21140_LINK_SENSE_PIN_MASK
DC21143_POLARITY_BIT_MASK               equ     DC21140_POLARITY_BIT_MASK
DC21143_DefaultMedia_MSAK               equ     DC21140_DefaultMedia_MSAK
DC21143_ActiveInvalid_MASK              equ     DC21140_ActiveInvalid_MASK
DC21143_CSR6_BITS_MASK                  equ     DC21140_CSR6_BITS_MASK
DC21143_CSR6_BITS_REAL_LOCATION         equ     DC21140_CSR6_BITS_REAL_LOCATION
DC21143_CSR6_BITS_MASK_REAL_LOCATION    equ     DC21140_CSR6_BITS_MASK_REAL_LOCATION

;------------------------------------------------------------------------------------------------
;       05 - Extended format - Block type 5
;            ------------------------------
;                                 7  6                          0
;    ----                       +---+----------------------------+
;                               | 1 |                            | 0  Length
;    Block                      +---+----------------------------+          
;    Type                       |              05                | 1  Type
;     5                         +---+---+------------------------+-----------
;                               |      Reset Sequence Length     | 2
;                               +--------------------------------+
;                               |        Reset Sequence          | 3
;                               |                                |
;                               |   (Reset Seq. Length words)    |
;                               +--------------------------------+-----------
EXTENDED_FORMAT_BLOCK_TYPE_5    equ     5
;------------------------------------------------------------------------------------------------

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                       G L O B A L   V A R I A B L E S
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	even
;Static Variable to be used during SROM parsing of DC21140 & DC21142 Info leaves
;-------------------------------------------------------------------------------
GPR_Control     	dw      ?
HandleGPRSequence       dw      0

IEEEAddressSROM		db	6 dup (0)
srom_address_size       dw ?
srom_length        dw ?

END_DATA_SEGMENT_INIT

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                           S R O M   R O U T I N E S
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
START_CODE_SEGMENT_INIT

	even
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ROM_Init
;
; Description:  void ROM_Init();
;
;       Returns:
;                 CARRY set if error.
;       Note:
;
; Remarks:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ROM_Init    proc    near

        push    cx
        push    di

	;Tulip has no SROM -> no init is needed.
	;---------------------------------------
	cmp	 Nic.Dev, TULIP
	je	 SHORT ISS_Exit
		 
        ;Chip must be in RUN mode before reading the SROM
        ;------------------------------------------------
        call    PutDeviceInRunMode

        xor     si, si

        ;Make sure ROM is idle
        ;---------------------
        call    MakeSureSROM_IsIdle
                                          ; Trying to read 6 bits length srom
        mov     srom_address_size, SROM_ADDRESS_LENGTH_1K
        mov     srom_length, SROM_SIZE_IN_BYTES_1K
        call    ReadSROMWord
        jnc     ISS_Exit
										; Trying to read 8 bits length srom
        mov     srom_address_size, ADDRESS_LENGTH_4K    
        mov     srom_length, SROM_SIZE_IN_BYTES_4K                ; possible 512...
        call    ReadSROMWord
        jc      ISS_ErrorExit

ISS_Exit:
        ;Restore Original activity mode (Sleep Snooze or Run)
        ;----------------------------------------------------
        mov     cx, Nic.PowerMode
        call    PutDeviceInMode
        pop     di
        pop     cx
        clc
        ret

ISS_ErrorExit:
        ;Restore Original activity mode (Sleep Snooze or Run)
        ;----------------------------------------------------
        mov     cx, Nic.PowerMode
        call    PutDeviceInMode
        pop     di
        pop     cx
        stc
        ret

ROM_Init  endp

	even
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                     PARSING CLASSIC (LEGACY) SROM FORMAT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ParseSROM_Classic
;
; Description:
;       assumes:  DS  - CGroup
;                 BX  - Pointer to Data
;                 Nic - Variable holding Nic data params.
;       Note:           
;       Returns:
;               Upon ERROR - Carry - SET 
;                            DX    - Holding error message ptr
;
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseSROM_Classic       proc    near

	push	di
	push    eax

	;Is it a Valid ethernet address and checksum ?
	;---------------------------------------------
	sub     sp, 8                           ;Prepare space on stack
	mov     bp, sp
	mov     ax, [bx]
	mov     ss:[bp], ax
	mov     ax, [bx+2]
	mov     ss:[bp+2], ax
	mov     ax, [bx+4]
	mov     ss:[bp+4], ax
	mov     ax, [bx+6]
	mov     ss:[bp+6], ax
	call    VerifyIEEEAddressChecksum
	jc      SHORT PSC_NotClassic

	;Classic! - First Handle ETH. address
	;------------------------------------
	mov     ss:[bp+6], ax                  ;Save VerifyIEEEAddressChecksum return value
	call    HandleEthernetAddressRom       ;classic! - Handle IEEE address
PSC_NotClassic:

	;Save return status in ax
	;------------------------
	pushf
	pop     ax

	;Free saved space, check if Classic and crash if NOT
	;---------------------------------------------------
	add     sp, 8                          ;Get rid of eth address on stack

	;Restore return status 
	;---------------------
	push    ax
	popf

	pop     eax                            ;restor EAX
	pop	di
	jc      PSC_ErrorExit                  ;If Carry SET - Not classic !

	;Go and enable the supported media
	;---------------------------------
	cmp     Nic.Dev, FASTERNET
	je      SHORT   PSC_FasterNet
	cmp     Nic.Dev, TULIP3
	je      SHORT PSC_Tulip3

	;If reached this point it can't be the classic rom since its implementd
	;on tulip3 and fasternet only
	;-----------------------------------------------------------------------
	jmp     SHORT PSC_ErrorExit

	;FASTERNET
	;---------
PSC_FasterNet:
	mov     Nic.Media[TP].MediaPresence,       Present
	mov     Nic.Media[TpFD].MediaPresence,     Present
	mov     Nic.Media[SymScr].MediaPresence,   Present
	mov     Nic.Media[SymScrFD].MediaPresence, Present

	;Connection type and DefaultMedia are both SymScr 
	;------------------------------------------------
	mov     Nic.SelectedConnectionType, ConnectionSymScr
	mov     Nic.DefaultMedia, MediaSymScr 

	;AutoSense is NOT supported
	;--------------------------
	mov     Nic.AutoSenseCapable, NOT  AUTOSENSE_CAPABLE
	mov     Nic.MediaPrecedence.NumMedia, 0                 ;No autosensable Medis
	jmp     SHORT PSC_Exit

	;TULIP 3
	;-------
PSC_Tulip3:
	mov     Nic.Media[TP].MediaPresence,   Present
	mov     Nic.Media[TpFD].MediaPresence, Present
	mov     Nic.Media[AUI].MediaPresence,  Present
	mov     Nic.Media[BNC].MediaPresence,  Present

	;Selected connection type to be AUTOSENSE
	;-----------------------------------------
	mov     Nic.SelectedConnectionType, ConnectionAutoSense

PSC_Exit:
	clc
	ret
PSC_ErrorExit:
	DataAddress	dx, SROM_ReadFailed
	stc
	ret

ParseSROM_Classic       endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                     PARSING SROM V1.0 FORMAT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ParseSROM_v1_0
;
; Description:
;       assumes:  DS  - CGroup
;                 BX  - Pointer to Data
;                 Nic - Variable holding Nic data params.
;       Note:           
;		  DI - register preserved
;       Returns:
;               Upon ERROR - Carry - SET 
;                            DX    - Holding error message ptr
;
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseSROM_v1_0  proc

	push	di

	call    ParseSROM_V1ToV3

        pop	di
	ret

ParseSROM_v1_0  endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ParseSROM_V1ToV3
;
; Description:
;       assumes:  DS  - CGroup
;                 BX  - Pointer to Data
;                 Nic - Variable holding Nic data params.
;       Note:           
;		  DI - register preserved
;       Returns:
;               Upon ERROR - Carry - SET 
;                            DX    - Holding error message ptr
;
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseSROM_V1ToV3  proc    near

	push	di

	;Get device entry in SROM
	;------------------------
	call	GetDeviceEntryInSROM
	jc     	PSV10_Exit

	;Handle Ethernet address
	;-----------------------
	push	bx
	lea	bx, [bx][ENET_ADDR_LOC_v1_0]
	call	HandleEthernetAddressInSROM
	pop	bx

	;Parse Adapter's info leaf
        ;-------------------------
	call	ParseAdapterInfoLeaf
	jc	SHORT PSV10_Exit
	clc

PSV10_Exit:
	pop	di
	ret

ParseSROM_V1ToV3  endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          GetDeviceEntryInSROM
;
; Description:
;       Returns a pointer to the device/Adapter Info block entry in the SROM
;       and the device# as indicated in the SROM.
;
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the beginnig of the SROM data space.
;                 Srom format is 1.0 or compatible (in its most general structure).
;       Returns:
;                 SI - Leaf offset from the start of the SROM.
;                 CX - Device/Adapter #
;       Note:
;               Carry flag SET if failed to find the device entry
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
GetDeviceEntryInSROM    proc

	;Start from adapter 0 assuming 1 entry only
	;------------------------------------------
	xor     cx, cx                     			;Start from adapter 0
	mov     si, LEAVES_START_LOC_v1_0  			;Let si point to start of leaves ptr list
	cmp     BYTE PTR [bx][ADAPTER_COUNT_LOC_v1_0], 1        ;If one entry - It Must be ours
	je      SHORT GDEIS_OneEntryOnly

	;More than one entry - Need to associate the correct one
	;To our Chip - Use the Dev# from handle for that
	;--------------------------------------------------------
        push	bx
	mov     bx, Nic.PCIDeviceAccessHandle   ;Handle in BX
	call    PCIGetDeviceNumber 		;Result in AL
	pop	bx

	;Find Device entry in data (if device NOT fount return error)
	;------------------------------------------------------------
GDEIS_AdapterSearchLoop:
	cmp     al, [bx][si].AdapterLeafPTR.DeviceNumber
	je     SHORT GDEIS_FoundAdapter

	;KeepSearching
	;-------------
	add     si, SIZE AdapterLeafPTR
	inc     cl
	cmp     cl, [bx][ADAPTER_COUNT_LOC_v1_0]
	jb      SHORT GDEIS_AdapterSearchLoop

	;If reached this point - Adapter was not found
	;---------------------------------------------
	DataAddress	dx, UnableToLocateROM
	stc
	ret

GDEIS_FoundAdapter:
GDEIS_OneEntryOnly:
	;Adapter was found - CX=Adapter#, SI<-LeafOffset
	;----------------------------------------------- 
	mov     si, [bx][si].AdapterLeafPTR.LeafOffset
	clc
	ret

GetDeviceEntryInSROM    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          HandleEthernetAddressInSROM
;
; Description:
;       Calculates and saves the Device specific ethernet address according to
;       The address read from the SROM and the Device# also read from the SROM.
;
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 CX - Device/Adapter #
;       Modifies:
;                 Driver's advertized ethernet address.
;       Note:
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
HandleEthernetAddressInSROM     proc

	push    cx                              ;Save cx
	push    si                              ;save si

	;Media ethernet address = EthernetAddress + Adapter#
	;---------------------------------------------------
	sub     sp, 6                           ;Prepare space on stack
	mov     bp, sp
	
	mov     al, [bx+5]
	add     al, cl
	mov     ss:[bp+5], al
	
	mov     al, [bx+4]
	adc     al, 0
	mov     ss:[bp+4], al

	mov     al, [bx+3]
	adc     al, 0
	mov     ss:[bp+3], al

	mov     al, [bx+2]
	adc     al, 0
	mov     ss:[bp+2], al

	mov     al, [bx+1]
	adc     al, 0
	mov     ss:[bp+1], al

	mov     al, [bx]
	adc     al, 0
	mov     ss:[bp], al
	
	call    HandleEthernetAddressROM
	add     sp, 6                           ;Get rid of eth address on stack

	pop     si                              ;Restor si
	pop     cx                              ;restor cx
	ret

HandleEthernetAddressInSROM     endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseAdapterInfoLeaf
;
; Description:
;       Handle (Parses) Adapter's info leaf
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters Info leaf offset from the beginning of the SROM
;       Modifies:
;                 Nic data structure.
;       Note:
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseAdapterInfoLeaf    proc

	;Init #of media supported by AutoSense
	;-------------------------------------
	mov     Nic.MediaPrecedence.NumMedia, 0

	;modify Nic.SelectedConnectionType only if one is selected
	;Notice that there is no problem if No media was selected
	;--------------------------------------------------------
	cmp     WORD PTR [bx][si], NoSelectedConnection     
	je      SHORT PAIL_DoneSettingConnection            ;If NO selected connection - Done
	mov     dx, [bx][si]                                ;Get selected connection.
	IsLegalConnection dl
	jc      SHORT PAIL_DoneSettingConnection            ;If Illegal connection - Done.
	mov     Nic.SelectedConnectionType, dx              ;Save selected Connection.
PAIL_DoneSettingConnection:

	;Let SI point at Next field
	;--------------------------
	add     si, 2                           

	;Read and parse Info leaves according to our device
	;--------------------------------------------------

	cmp     Nic.Dev, FASTERNET
	je      SHORT PAIL_HandleDC21140NIC

	cmp     Nic.Dev, TWINET
	je      SHORT PAIL_HandleDC21142NIC

	cmp     Nic.Dev, TULIP3
	je      SHORT PAIL_HandleDC21041NIC

	stc                                    ;Unknown device Error
	jmp     SHORT PAIL_Exit

	;Handle DC21140 Nic
	;------------------
PAIL_HandleDC21140NIC:
	call    ParseDC21140InfoLeaf
	jmp     PAIL_Exit                       ;Done handling media - Exit

	;Handle DC21142 & DC21144 Nics
	;-----------------------------
PAIL_HandleDC21144NIC:
PAIL_HandleDC21142NIC:
	call    ParseDC21142InfoLeaf
	jmp     PAIL_Exit                       ;Done handling media - Exit

	;Handle DC21041 Nic
	;------------------
PAIL_HandleDC21041NIC:
	call    ParseDC21041InfoLeaf
	jmp     PAIL_Exit                       ;Done handling media - Exit

PAIL_Exit:
	ret

ParseAdapterInfoLeaf    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseDC21041InfoLeaf
;
; Description:
;       Handle (Parses) Adapter's info leaf
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters DC21041 Info leaf offset from the beginning
;                       of the SROM
;       Modifies:
;                 Nic data structure.
;                 SI
;       Note:    
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseDC21041InfoLeaf    proc

	;Get Media count
	;---------------
	cmp     BYTE PTR [bx][si], 0
	je      SHORT PDC21041IL_NoInfoBlocks
	movzx   cx, BYTE PTR [bx][si]           ;CX to hold #of media in NIC
	inc     si                              ;SI to point at Media block

	;Parse Media blocks (DC21041 info block has Media blocks only)
	;-------------------------------------------------------------
PDC21041IL_ParseInfoBlock:
	call    ParseDC21041InfoBlock
	loop    PDC21041IL_ParseInfoBlock

PDC21041IL_NoInfoBlocks:
	clc
	ret

ParseDC21041InfoLeaf    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseDC21041InfoBlock
;
; Description:
;       Handle (Parses) DC21041 info leaf
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters dc21040 Info block offset from the beginning
;                       of the SROM
;       Modifies:
;                 Nic data structure.
;                 SI
;       Note:
;          As for Rev 1.0 and 3.0 DC21041 info block holds only media information
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseDC21041InfoBlock   proc

	call    ParseDC21041MediaBlockCompact
	ret

ParseDC21041InfoBlock   endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseDC21041MediaBlockCompact
;
; Description:
;       Handle (Parses) the following Adapter's media block
;
;       DC21041 Media Block Format
;       --------------------------
;                                        7   6  5             0
;                                      +---+---+--------------+     
;               15                     |Res|EXT|  Media Code  |
;               +----------------------+----------------------+          
;               |              Media Specific Data            |  
;               |      (Exists only when EXT bit is set)      |
;               +----------------------+----------------------+
;
;       DC21041 Media Specific Data Format
;       ----------------------------------
;               15                    8 7                     0
;               +----------------------+----------------------+
;               |                 CSR13 <15..0>               | 
;               +----------------------+----------------------+
;               |                 CSR14 <15..0>               |
;               +----------------------+----------------------+
;               |                 CSR15 <15..0>               |
;               +----------------------+----------------------+
;
;   Possible Media code values are:
;       00h     TP
;       01h     BNC
;       02h     AUI
;       04h     TP Full Duplex
;
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters dc21040 media block offset from the beginning
;                       of the SROM
;       Modifies:
;                 Nic data structure.
;                 SI
;                 DI
;       Note:
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseDC21041MediaBlockCompact   proc

	;Get Media type
	;--------------
	movzx   di, BYTE PTR [bx][si]
	inc     si                                     ;Si to Point to next byte

	;If NOT a known/legal media skip it
	;----------------------------------
	IsLegalMedia    di
	jnc     SHORT DC21041MB_KnownMedia             ;Its legal, use it

	;Skip media
	;----------
	test    BYTE PTR [bx][si]-1, DC21041_EXT_MASK  ;do we use external SIA ?
	jz      SHORT PDC21041MB_Exit
	add     si, SIZE SIARegsSTRUC                  ;Point at next Media Entry
	jmp     SHORT PDC21041MB_Exit                  ;Exit

	;Insert Media Parameters into Media data array
	;---------------------------------------------
DC21041MB_KnownMedia:
	GetMediaEntry di, di
	mov     Nic.Media[di].MediaPresence, Present    ;Media is present

	test    BYTE PTR [bx][si]-1, DC21041_EXT_MASK   ;do we use external SIA ?
	jz      SHORT PDC21041MB_NotExternalSIA

	mov     ax, (SIARegsSTRUC PTR [bx][si]).SIA_CSR13
	mov     Nic.Media[di].MediumInternalRegs.CSR13, ax

	mov     ax, (SIARegsSTRUC PTR [bx][si]).SIA_CSR14
	mov     Nic.Media[di].MediumInternalRegs.CSR14, ax

	mov     ax, (SIARegsSTRUC PTR [bx][si]).SIA_CSR15
	mov     Nic.Media[di].MediumInternalRegs.CSR15, ax

	;Point at next Media Entry
	;-------------------------
	add     si, SIZE SIARegsSTRUC           ;Point at next Media Entry
PDC21041MB_NotExternalSIA:

PDC21041MB_Exit:
	ret

ParseDC21041MediaBlockCompact   endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseDC21140InfoLeaf
;
; Description:
;       Handle (Parses) Adapter's info leaf
;
;       DC21140 info leaf format:
;       -------------------------
;               15                    8 7                     0
;               +----------------------+----------------------+
;               |          Selected Connection Type           | 0
;               +----------------------+----------------------+
;               |    Media Count (k)   |General Purpose Cntrl | 2
;               +----------------------+----------------------+
;               |                Media_1 block                | 4 (Variable size)
;               +----------------------+----------------------+
;               |                Media_2 block                |   (Variable size)
;               +----------------------+----------------------+
;               |                Media_k block                |   (Variable size)
;               +----------------------+----------------------+
;
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters Info leaf offset from the beginning of the SROM
;       Modifies:
;                 Nic data structure.
;       Note:
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseDC21140InfoLeaf    proc

	;Update General Purpose Control word
	;-----------------------------------
	movzx   dx, BYTE PTR [bx][si]          ;DX holds General purpose control
	or      dx, 100h                       ;Turn on WRITE bit
	mov     GPR_Control, dx
	inc     si                             ;Let si point at next field

	;Get Info Blocks count
	;---------------------
	cmp     BYTE PTR [bx][si], 0
	je      SHORT PDC21140IL_NoInfoBlocks
	movzx   cx, BYTE PTR [bx][si]           ;CX to hold #of Info blocks in NIC
	inc     si                              ;SI to point at Info block

	;The difference between V1.0 and V3.0 is the info block format
	;-------------------------------------------------------------
	cmp     BYTE PTR [bx][FORMAT_VERSION_LOC], FORMAT1_0
	je      SHORT PDC21140IL_HandleFormat1_0
	cmp     BYTE PTR [bx][FORMAT_VERSION_LOC], FORMAT3_0
	je      SHORT PDC21140IL_HandleFormat3_0
	;If reached this point - Unknown Format version
	jmp     SHORT PDC21140IL_ErrorExit

PDC21140IL_HandleFormat1_0:
	;SROM V1.0 has only media blocks
	;-------------------------------
	push    cx                              ;Save loop counter
	call    ParseDC21140MediaBlockCompact
	pop     cx                              ;Restor loop counter
	loop    PDC21140IL_HandleFormat1_0
	jmp     SHORT PDC21140IL_HandleDefaultMedia

PDC21140IL_HandleFormat3_0:
	;SROM V3.0 has Info blocks
	;-------------------------
	push    cx                              ;Save loop counter
	call    ParseDC21140InfoBlock
	pop     cx                              ;Restor loop counter
	loop    PDC21140IL_HandleFormat3_0

	;Handle default media
	;--------------------
PDC21140IL_HandleDefaultMedia:
	call    HandleDefaultMedia

PDC21140IL_NoInfoBlocks:
	clc
	ret

PDC21140IL_ErrorExit:
	DataAddress	dx, UnsupportedSROMVersion
	stc
	ret

ParseDC21140InfoLeaf    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          HandleDefaultMedia
;
; Description:
;       Handles Default media selection for DC21140.
;
;       If a default media is specified in SROM then
;               return
;       Else
;               If MediaPrecedenceList is Not empty then
;                       get Highest precedence medium
;                       Make it our default medium
;               Else
;                       Return
;               EndIf
;       EndIF
;
;       assumes:
;               DC21140 info leaf had already been parsed.
;       Modifies:
;                 Nic data structure.
;       Note:
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
HandleDefaultMedia      proc

	push    cx
	push    si

	;Handle default media if None was selected
	;-----------------------------------------
	cmp     Nic.DefaultMedia, NoSelectedMedia
	jne     SHORT HDM_DefaultMediaAlreadyHandled

	mov     cx, Nic.MediaPrecedence.NumMedia
	dec     cx
	jl      SHORT HDM_NoDefaultMediaToHandle            ;If no AutoSense media - No DefaultMedia either

	IndexToOffset   MediaPriorityStruc.MediaPriorityList, cx, 0, si
	mov     al, Nic.MediaPrecedence.MediaPriorityList[si] ;Get Highest priority media
	mov     Nic.DefaultMedia, al                          ;Put it as the default medium
HDM_NoDefaultMediaToHandle:
HDM_DefaultMediaAlreadyHandled:

	pop     si
	pop     cx
	ret

HandleDefaultMedia      endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseDC21140MediaBlockCompact
;
; Description:
;       Handle (Parses) DC21140 media block (compact)
;
;       DC21140 Media Block Format
;       --------------------------
;                                       7   6 5                0
;                                      +--+--+----------------+     
;                                      | Res |  Media Code    | 0
;                                      +--+--+----------------+          
;               15                     |      GEP Data        | 1
;               +----------------------+----------------------+
;               |               Command (2 Bytes)             | 3
;               +----------------------+----------------------+
;
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters Info leaf offset from the beginning of the SROM
;       Modifies:
;                 Nic data structure.
;       Note:
;                 
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseDC21140MediaBlockCompact   proc

	push    eax

	;Handle DC21140 Media
	;--------------------
	movzx   di, BYTE PTR [bx][si]                   ;di to hold media code

	;If NOT a known media skip it
	;----------------------------
	IsLegalMedia    di
	jnc     SHORT PDC21140MB_KnownMedia            ;Its legal, use it

	;Skip media
	;----------
	add     si, DC21140_MEDIA_BLOCK_SROM_SIZE      ;Point at next Media Entry
	jmp     PDC21140MB_Exit                        ;Exit

	;Insert Media Parameters into Media data array
	;---------------------------------------------
PDC21140MB_KnownMedia:
	GetMediaEntry di, di
	mov     Nic.Media[di].MediaPresence, Present    ;Media is present in Nic
	inc     si                                      ;SI to point to next field

	;Handle GEP Control
	;------------------
	mov     ax, GPR_Control     
	mov     Nic.Media[di].Gep.SequenceData[Gep_Control], ax

	;Handle GEP data
	;---------------
	movzx   ax, BYTE PTR [bx][si]                  ;Read GP-Data
	mov     Nic.Media[di].Gep.SequenceData[Gep_Data], ax
	inc     si                                      ;Point to next field

	;Handle Command word
	;-------------------
	call    ParseCommandWord

	;Restore original Media value
	;----------------------------
	mov     al, BYTE PTR [bx][si]-2
	and     al, DC21X4_MEDIA_CODE_MASK

	;Handle default media
	;--------------------
	test    WORD PTR [bx][si], DC21140_DefaultMedia_MSAK
	jz      SHORT DoneWithDefaultMediaHandling
	mov     Nic.DefaultMedia, al
	mov     Nic.UserSelectedDefaultMedia, TRUE
DoneWithDefaultMediaHandling:

	;Insert media type in the precedence list (Lowest priority in Lowest entry)
	;Only if Media has a sense mask && Media is NOT FD
	;---------------------------------------------------------------------------
	IsMediaFD  ax
	je      SHORT DontInsertThisMedia
	test    WORD PTR [bx][si], DC21140_ActiveInvalid_MASK
	jnz     SHORT DontInsertThisMedia
	push    si
	inc     Nic.MediaPrecedence.NumMedia
	IndexToOffset   MediaPriorityStruc.MediaPriorityList, Nic.MediaPrecedence.NumMedia, 1, si
	mov     Nic.MediaPrecedence.MediaPriorityList[si], al
	pop     si
DontInsertThisMedia:

	;Point at next Media entry
	;-------------------------
	add     si, 2                                  ;Point to next field

PDC21140MB_Exit:
	pop     eax
	ret

ParseDC21140MediaBlockCompact   endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                     PARSING SROM V3.0 FORMAT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ParseSROM_v3_0
;
; Description:
;       assumes:  DS  - CGroup
;                 BX  - Pointer to Data
;                 Nic - Variable holding Nic data params.
;       Note:           
;       Returns:
;               Upon ERROR - Carry - SET 
;                            DX    - Holding error message ptr
;
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseSROM_v3_0  proc

	call    ParseSROM_V1ToV3
	ret

ParseSROM_v3_0  endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseDC21140InfoBlock
;
; Description:
;       Handle (Parses) DC21140 info block
;
;
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters DC21140 Info Block offset from the beginning
;                       of the SROM.
;       Modifies:
;                 Nic data structure.
;       Note:
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseDC21140InfoBlock   proc

	;SROM V3.0 has 2 Info blocks formats:
	;  1. Compact Format.
	;  2. Extended Format.
	;Which are handled differently
	;-----------------------------------
	test    BYTE PTR [bx][si], DC21140_INFO_BLOCK_FORMAT_INDICATION
	jnz     SHORT  PDC21140IB_HandleExtendedFormat

	;Handle Compact Format
	;---------------------
	call    ParseDC21140InfoBlockCompact
	jmp     SHORT PDC21140IB_Exit

	;Handle Extended Format
	;---------------------
PDC21140IB_HandleExtendedFormat:
	call    ParseDC21140InfoBlockExtended

PDC21140IB_Exit:
	ret

ParseDC21140InfoBlock   endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseDC21140InfoBlockCompact
;
; Description:
;       Handle (Parses) Adapter's DC21140 Compact info block
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters DC21140 Info Block offset from the beginning
;                       of the SROM
;       Modifies:
;                 Nic data structure.
;                 SI
;       Note:
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseDC21140InfoBlockCompact    proc

	;Compact Format == MediaBlock
	;----------------------------
	call    ParseDC21140MediaBlockCompact
	ret

ParseDC21140InfoBlockCompact    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseDC21140InfoBlockExtended
;
; Description:
;       Handle (Parses) DC21140 extended 
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters Info leaf offset from the beginning of the SROM
;       Modifies:
;                 Nic data structure.
;       Note:
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseDC21140InfoBlockExtended   proc

	;Save the Pointer to the beginning of the block
        ;----------------------------------------------
	push 	si

	;Handle extended block type 0
        ;----------------------------
	cmp	(ExtendedFormatHeader PTR [bx][si]).EF_TYPE, EXTENDED_FORMAT_BLOCK_TYPE_0
	jne	SHORT PDC21140IBE_NotBlockType_0
	call	ParseDC21140ExtendedFormatType_0
	jmp	SHORT PDC21140IBE_AdvanceToNextBlock
PDC21140IBE_NotBlockType_0:

	;Handle extended block type 1
	;----------------------------
	cmp	(ExtendedFormatHeader PTR [bx][si]).EF_TYPE, EXTENDED_FORMAT_BLOCK_TYPE_1
	jne	SHORT PDC21140IBE_NotBlockType_1
	call	ParseDC21140ExtendedFormatType_1
	jmp	SHORT PDC21140IBE_AdvanceToNextBlock
PDC21140IBE_NotBlockType_1:

	;Handle Extended block type 5
	;----------------------------
	cmp	(ExtendedFormatHeader PTR [bx][si]).EF_TYPE, EXTENDED_FORMAT_BLOCK_TYPE_5
	jne	SHORT PDC21140IBE_NotBlockType_5
	call	ParseExtendedFormatType_5
	jmp	SHORT PDC21140IBE_AdvanceToNextBlock
PDC21140IBE_NotBlockType_5:


PDC21140IBE_AdvanceToNextBlock:
	pop 	si 			;Restore the Pointer to the beginning of the block

	;Advance to next block
	;---------------------
	movzx	ax, (ExtendedFormatHeader PTR [bx][si]).EF_Length      	     ;Get length field
	and	ax, EXTENDED_FORMAT_BLOCK_SIZE_MASK  ;Get rid of irrelevant bits
	add	ax, TYPE ExtendedFormatHeader.EF_Length
						     ;add Length field size since its not
						     ;included in the block length calculation
	add	si, ax                               ;advanc the pointer to the next block

	ret

ParseDC21140InfoBlockExtended   endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseDC21140ExtendedFormatType_0
;
; Description:
;       Handle (Parses) DC21140 Extended Format Type_0
;
;       +--------------------+       +--------------------+
;       |   Block Type 0     |  ==   |   DC21140 Compact  |
;       |                    |       |                    |
;       |                    |       +--------------------+
;       |                    |     +
;       |                    |       +--------------------+
;       |                    |       |      Header        |
;       +--------------------+       +--------------------+
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters Info leaf offset from the beginning of the SROM
;       Modifies:
;                 Nic data structure.
;       Note:
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseDC21140ExtendedFormatType_0        proc

	;Skip Extended format header
	;---------------------------
	add     si, SIZE ExtendedFormatHeader

	;Extended format Block type 0 == DC21140InfoBlockCompact
	;-------------------------------------------------------
	call    ParseDC21140InfoBlockCompact

	ret

ParseDC21140ExtendedFormatType_0        endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseDC21140ExtendedFormatType_1
;
; Description:
;       Handle (Parses) Mii Phy type 1
;
;       01 - Extended format - Block type 1
;            ------------------------------
;                       7    6                  0
;                       +---+--------------------+
;                       | 1 |     Length         | 0        
;                       +---+--------------------+          
;                       |         Type           | 1
;             -----     +------------------------+
;                       |       Phy Number       | 2 
;                       +------------------------+
;                       |  GPR Sequence Length   | 3
;                       +------------------------+
;                       |      GPR Sequence      | 4
;                       +                        +
;                       |(GPR seq. length bytes) |
;                       +------------------------+
;                       | Reset Sequence Length  | 4+Gpr_len
;                       +------------------------+
;                       |     Reset Sequence     | 5+Gpr_len
;          Block        +                        +
;                       |(Reset seq.length bytes)|
;          Data         +------------------------+
;                       |   Media Capabilities   | 5+Gpr_len+Rst_len
;                       +                        +
;                       |       (2 bytes)        |
;                       +------------------------+
;                       |   Nway Advertisement   | 7+Gpr_len+Rst_len
;                       +                        +
;                       |       (2 bytes)        |
;                       +------------------------+
;                       |      FDX bit map       | 9+Gpr_len+Rst_len
;                       +                        +
;                       |       (2 bytes)        |
;                       +------------------------+
;                       |      TTM bit map       | 11+Gpr_len+Rst_len
;                       +                        +
;                       |       (2 bytes)        | 12+Gpr_len+Rst_len
;             -----     +------------------------+
;
;
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters Info leaf offset from the beginning of the SROM
;       Modifies:
;                 Nic data structure.
;       Note:
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseDC21140ExtendedFormatType_1        proc

	mov     HandleGPRSequence, offset CGroup:HandleGPRSequenceByteProc
	call    ParseMiiPhyEntry
	ret

ParseDC21140ExtendedFormatType_1        endp


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseDC21142InfoLeaf
;
; Description:
;       Handle (Parses) Adapter's info leaf
;
;DC21142 leaf format
;-------------------
;
;
;         15                    7                       0  in leaf
;        +-----------------------------------------------+
;        |         Selected Connection Type              |  0
;        +---------------------+-------------------------+
;                              |   Block Count  (k)      |  2
;        +---------------------+-------------------------+
;        |               Info_block_1                    |  3
;        +-----------------------------------------------+
;        |               Info_block_2                    |
;        +-----------------------------------------------+
;        |                   .                           |
;        |                   .                           |
;        +-----------------------------------------------+
;        |               Info_block_k                    |
;        +-----------------------------------------------+
;
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters Info leaf offset from the beginning of the SROM
;       Modifies:
;                 Nic data structure.
;       Note:
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseDC21142InfoLeaf    proc

	;TWINET is NOT supported in SROM V1.0 
	;------------------------------------
	cmp     BYTE PTR [bx][FORMAT_VERSION_LOC], FORMAT1_0
	je      SHORT PDC21142IL_ErrorExit

	;Get Media/Block count
	;---------------------
	cmp     BYTE PTR [bx][si], 0
	je      SHORT PDC21142IL_ErrorExit      ;No Blocks to handle -> Error

	movzx   cx, BYTE PTR [bx][si]           ;CX to hold #of Info blocks in NIC
	inc     si                              ;SI to point at Info block

PDC21142IL_HandleFormat3_0:
	;SROM V3.0 has Info blocks
	;-------------------------
	push    cx                              ;Save loop counter
	call    ParseDC21142InfoBlock
	pop     cx                              ;Restor loop counter
	loop    PDC21142IL_HandleFormat3_0

	clc
	ret

PDC21142IL_ErrorExit:
	DataAddress	dx, UnsupportedDC21x4SROMVersion
	stc
	ret

ParseDC21142InfoLeaf    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseDC21142InfoBlock
;
; Description:
;       Handle (Parses) Adapter's info leaf
;
;
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters DC21140 Info Block offset from the beginning
;                       of the SROM.
;       Modifies:
;                 Nic data structure.
;       Note:
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseDC21142InfoBlock   proc

	;SROM V3.0 has 2 Info blocks formats:
	;  1. Compact Format.
	;  2. Extended Format.
	;Twinet supports only Extended format
	;------------------------------------
	test    BYTE PTR [bx][si], DC21142_INFO_BLOCK_FORMAT_INDICATION
	jnz     SHORT  PDC21142IB_HandleExtendedFormat

	;Handle Compact Format
	;---------------------
	add     si, COMPACT_FORMAT_BLOCK_SIZE ;Twinet does not support compact fomat -
	jmp     SHORT PDC21142IB_Exit         ;Skip it.

	;Handle Extended Format
	;---------------------
PDC21142IB_HandleExtendedFormat:
	call    ParseDC21142InfoBlockExtended

PDC21142IB_Exit:
	ret

ParseDC21142InfoBlock   endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseDC21142InfoBlockExtended
;
; Description:
;       Handle (Parses) Adapter's info leaf
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters Info leaf offset from the beginning of the SROM
;       Modifies:
;                 Nic data structure.
;       Note:
; Remarks:
;       Also called ParseDC21143InfoBlockExtended since DC21143 == DC21142 rev 2 and above
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseDC21142InfoBlockExtended	proc
ParseDC21143InfoBlockExtended:

	;Save the Pointer to the beginning of the block
        ;----------------------------------------------
	push 	si

	;Handle extended block type 2
        ;-------------------------------------------------
	cmp	(ExtendedFormatHeader PTR [bx][si]).EF_TYPE, EXTENDED_FORMAT_BLOCK_TYPE_2
	jne	SHORT PDC21142IBE_NotBlockType_2
	call	ParseDC21142ExtendedFormatType_2
	jmp	SHORT PDC21142IBE_AdvanceToNextBlock
PDC21142IBE_NotBlockType_2:

	;Handle extended block type 3
	;----------------------------
	cmp	(ExtendedFormatHeader PTR [bx][si]).EF_TYPE, EXTENDED_FORMAT_BLOCK_TYPE_3
	jne	SHORT PDC21142IBE_NotBlockType_3
	call	ParseDC21142ExtendedFormatType_3
	jmp	SHORT PDC21142IBE_AdvanceToNextBlock
PDC21142IBE_NotBlockType_3:

	;Twinet2 (DC21143) supports Extended block type 4
	;------------------------------------------------
	cmp	(ExtendedFormatHeader PTR [bx][si]).EF_TYPE, EXTENDED_FORMAT_BLOCK_TYPE_4
	jne	SHORT PDC21143IBE_NotBlockType_4
	call	ParseDC21142ExtendedFormatType_4
	jmp	SHORT PDC21142IBE_AdvanceToNextBlock
PDC21143IBE_NotBlockType_4:

	;Twinet2 (DC21143) supports Extended block type 5
	;------------------------------------------------
	cmp	(ExtendedFormatHeader PTR [bx][si]).EF_TYPE, EXTENDED_FORMAT_BLOCK_TYPE_5
	jne	SHORT PDC21143IBE_NotBlockType_5
	call	ParseExtendedFormatType_5
	jmp	SHORT PDC21142IBE_AdvanceToNextBlock
PDC21143IBE_NotBlockType_5:

	;Twinet supports only Extended block types 2,3,4,5
	; - Skip other extended blocks.
	;-----------------------------------------------------
	;jmp	SHORT PDC21142IBE_AdvanceToNextBlock

PDC21142IBE_AdvanceToNextBlock:
	pop 	si 			;Restore the Pointer to the beginning of the block

	;Advance to next block
	;---------------------
	movzx	ax, (ExtendedFormatHeader PTR [bx][si]).EF_Length      	     ;Get length field
	and	ax, EXTENDED_FORMAT_BLOCK_SIZE_MASK  ;Get rid of irrelevant bits
 	add	ax, TYPE ExtendedFormatHeader.EF_Length
						     ;add Length field size since its not
						     ;included in the block length calculation
	add	si, ax                               ;advance the pointer to the next block

	ret

ParseDC21142InfoBlockExtended	endp

ExtendedFormatHeaderArray  ExtendedFormatHeader  7 dup (<>)
 
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseDC21142ExtendedFormatType_2
;
; Description:
;       Handle (Parses) DC21140 Extended Format Type_2
;
;       +--------------------+       +--------------------+       +--------------------+
;       |   Block Type 4     |  ==   |   Block Type 2     |  ==   |   DC21040 Compact  |
;       |                    |       |  (W.O EXT SIA)     |       |                    |
;       |                    |       +--------------------+       +--------------------+
;       |                    |     +                            +
;       |                    |       +--------------------+       +--------------------+
;       |                    |       |  Command Parsing   |       |TwinetGEP(CTRL&DATA)|
;       |                    |       +--------------------+       +--------------------+
;       |                    |     +
;       |                    |       +--------------------+
;       |                    |       |      Header        |
;       +--------------------+       +--------------------+
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters Info leaf offset from the beginning of the SROM
;       Modifies:
;                 Nic data structure.
;       Note:
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseDC21142ExtendedFormatType_2        proc

	;Skip Extended format header
	;---------------------------
	add     si, SIZE ExtendedFormatHeader

	;Insert Media Parameters into Media data array
	;---------------------------------------------
	call    ParseDC21041MediaBlockCompact  ;Twinet SIA format is as Tulip's
	jc      SHORT PDC21142EFT2_Exit

	;Get GPR Control
	;---------------
	mov     ax, WORD PTR [bx][si]
	mov     Nic.Media[di].Gep.SequenceData[Gep_Control], ax   ;DI is modified in ParseDC21041MediaBlockCompact

	;Get GPR Data
	;------------
	mov     ax, WORD PTR [bx][si+2]
	mov     Nic.Media[di].Gep.SequenceData[Gep_Data], ax

PDC21142EFT2_Exit:
	ret

ParseDC21142ExtendedFormatType_2        endp
  
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseDC21142ExtendedFormatType_3
;
; Description:
;       Handle NII phy block type3
;
;       Block Type3 == BlockType1 (with GPR sequence and GPR rest sequence different) +
;                      MII phy Interrupt #
;
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters Info leaf offset from the beginning of the SROM
;       Modifies:
;                 Nic data structure.
;       Note:
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseDC21142ExtendedFormatType_3        proc

	mov     HandleGPRSequence, offset CGroup:HandleGPRSequenceWordProc
	call    ParseMiiPhyEntry

	;Get PHY Insertion/Removal Interrupt number 
	;------------------------------------------
	mov     al, BYTE PTR [bx][si]
	mov     Nic.MiiPhysList[di].MIIConnectorInterrupt, al
	inc     si

	ret

ParseDC21142ExtendedFormatType_3        endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseDC21142ExtendedFormatType_4
;
; Description:
;       
;       Handle (Parses) DC21140 Extended Format Type_4
;
;       +--------------------+       +--------------------+       +--------------------+
;       |   Block Type 4     |  ==   |   Block Type 2     |  ==   |   DC21040 Compact  |
;       |                    |       |  (W.O EXT SIA)     |       |                    |
;       |                    |       +--------------------+       +--------------------+
;       |                    |     +                            +
;       |                    |       +--------------------+       +--------------------+
;       |                    |       |  Command Parsing   |       |TwinetGEP(CTRL&DATA)|
;       |                    |       +--------------------+       +--------------------+
;       |                    |     +
;       |                    |       +--------------------+
;       |                    |       |      Header        |
;       +--------------------+       +--------------------+
;
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters Info leaf offset from the beginning of the SROM
;       Modifies:
;                 Nic data structure.
;       Note:
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseDC21142ExtendedFormatType_4        proc

	call    ParseDC21142ExtendedFormatType_2

	;Get and Parse Command
	;---------------------
	add     si, 4
	call    ParseCommandWord

	ret

ParseDC21142ExtendedFormatType_4        endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          ParseExtendedFormatType_5
;
; Description:
;       
;       Handle (Parses) Extended Format Type_5
;
;    ----                       +---+----------------------------+
;                               | 1 |                            | 0  Length
;    Block                      +---+----------------------------+          
;    Type                       |              05                | 1  Type
;     5                         +---+---+------------------------+-----------
;                               |  Reset Sequence Length (Words) | 2
;                               +--------------------------------+
;                               |        Reset Sequence          | 3
;                               |                                |
;                               |   (Reset Seq. Length words)    |
;                               +--------------------------------+-----------
;
;       assumes:  DS  - CGroup
;                 BX  - Pointer to the SROM Ethernet address.
;                 SI  - Adapters Info leaf offset from the beginning of the SROM
;       Modifies:
;                 Nic data structure.
;       Note:
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseExtendedFormatType_5       proc

	push    di

	;Skip Extended format header
	;---------------------------
	add     si, SIZE ExtendedFormatHeader
	lea     di, Nic.ExternalReset[0]
	call    HandleGPRSequenceWordProc

	pop     di
	ret

ParseExtendedFormatType_5       endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                          GENERAL ROUTINES
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ParseCommandWord        proc
;
; Description:
;       Parses Command word to CSR6 OM bits and external link sense data.
;
;       assumes:  DS  - CGroup
;                 Nic - Variable holding Nic data params.
;                 BX:SI  - Points at command word entry
;                 DI  - Points at media entry in Nic. 
;       Note:           
;       Returns:
;               
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseCommandWord        proc

	push    eax
	push    cx

	;Handle Media Activity Indication
	;---------------------------------
	mov     ax, [bx][si]                                                      ;Read command Field
	mov     Nic.Media[di].ExternalLinkSense.ActiveInvalid, ACTIVE_INVALID     ;Assume active invalid -> No Media sense
	test    ax, DC21140_ActiveInvalid_MASK
	jnz     SHORT PCW_DoneWithMediaActivityHandling
	mov     Nic.Media[di].ExternalLinkSense.ActiveInvalid, NOT_ACTIVE_INVALID ;Now We Know that active valid
PCW_DoneWithMediaActivityHandling:

	;Handle Link Sense pin # and construct the LinkSenseMask from it
	;---------------------------------------------------------------
	and     ax, DC21140_LINK_SENSE_PIN_MASK           ;Keep LinkSense pin# only
	shr     al, 1                                     ;Align the#
	push    cx
	mov     cl, 1
	sub     cl, BYTE PTR (Nic.Media[di].ExternalLinkSense.ActiveInvalid) ;No Activity Indication -> No mask
	xchg    cl, al                                     ;8086 allows shifts using only CL as a counter
	shl     al, cl                                     ;Set the bit corresponding to the pin# (If any)
	mov     Nic.Media[di].ExternalLinkSense.LinkSenseMask, al ;Save it
	pop     cx

	;Handle Polarity bit mask
	;------------------------
	mov     ax, [bx][si]                            ;Read command Field
	mov     ah, 0FFh                                ;if Polarity is 1 this is the mask
	test    al, DC21140_POLARITY_BIT_MASK           ;Keep Polarity bit only
	jnz     SHORT PCW_PolarityValueIsSet
	xor     ah, ah                                  ;Polarity is 0 -> This is the mask
PCW_PolarityValueIsSet:
	mov     Nic.Media[di].ExternalLinkSense.Polarity, ah   ;Save it

	;Handle CSR6
	;-----------
	mov     ax, WORD PTR [bx][si]                   ;Read command Field
	and     eax, DC21140_CSR6_BITS_MASK             ;Clear Irrelevant bits
	shl     eax, DC21140_CSR6_BITS_REAL_LOCATION
	and     Nic.Media[di].CSR6_OM, NOT (DWORD PTR DC21140_CSR6_BITS_MASK_REAL_LOCATION)
	or      Nic.Media[di].CSR6_OM, eax      ;Save it

	pop     cx
	pop     eax
	ret

ParseCommandWord        endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:      ParseMiiPhyEntry           proc
;
; Description:
;       Parses Command word to CSR6 OM bits and external link sense data.
;
;       assumes:  DS  - CGroup
;                 Nic - Variable holding Nic data params.
;                 BX:SI  - Points at command word entry
;                 DI  - Points at media entry in Nic. 
;       Note:           
;       Returns:
;               
; Remarks:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ParseMiiPhyEntry        proc

	;Skip Extended format header
	;---------------------------
	add     si, SIZE ExtendedFormatHeader

	;Get Phy#
	;--------
	movzx   di, BYTE PTR [bx][si]
	inc     si

	;If illegal Phy# - exit
	;----------------------
	cmp     di, MAX_PHY_TABLE
	jge     PMPE_Exit

	;Convert Phy# to Phy entry in Nic.
	;---------------------------------
	IndexToOffset MII_PHY_ENTRY, di, 0, di

	;fill Phy entry in Nic with Phy data from SROM
	;---------------------------------------------

	;Get and Fill GPR sequence
	;-------------------------
	push    di
	lea     di, Nic.MiiPhysList[di].MacEntry.Gep[0]
	call    HandleGPRSequence
	pop     di

	;Get and Fill GPR Reset sequence
	;-------------------------------
	push    di
	lea     di, Nic.MiiPhysList[di].GepReset[0]
	call    HandleGPRSequence
	pop     di

	;Get Media capabilities
	;----------------------
	mov     ax, WORD PTR [bx][si]
	mov     Nic.MiiPhysList[di].MediaCapabilities, ax
	add     si, 2

	;Get Nway advertisement
	;----------------------
	mov     ax, WORD PTR [bx][si]
	mov     Nic.MiiPhysList[di].NwayAdvertisement_, ax
	add     si, 2

	;Get FDX bit map
	;---------------
	mov     ax, WORD PTR [bx][si]
	mov     Nic.MiiPhysList[di].FullDuplexBits, ax
	add     si, 2

	;Get TTM bit map
	;---------------
	mov     ax, WORD PTR [bx][si]
	mov     Nic.MiiPhysList[di].TxThresholdModeBits, ax
	add     si, 2

	;If reached this point - Legal Phy
	;---------------------------------
	inc     Nic.NumMiiPhys

PMPE_Exit:
	ret

ParseMiiPhyEntry        endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:      HandleGPRSequenceByteProc          proc
;
; Description:
;       Parses Command word to CSR6 OM bits and external link sense data.
;
;       assumes:  DS  - CGroup
;                 Nic - Variable holding Nic data params.
;                 BX:SI  - Points at command word entry
;                 DI  - Points at media entry in Nic. 
;       Note:           
;       Returns:
;               
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
HandleGPRSequenceByteProc       proc

	;Get GPR sequence length
	;-----------------------
	movzx   cx, BYTE PTR [bx][si]                      ;Get Seq.length
	inc     si                                         ;Point to GPR sequence field
	cmp     cx, MAX_GPR_SEQUENCE                       ;If Seq. length > Nic's Limit then
	jg      SHORT HGSB_Exit                            ;  Exit

	mov     (GPR_STRUC PTR [di]).SequenceCount, cx     ;Save Sequence length

	cmp     cx, 0                                      ;If no GPR sequence then
	je      SHORT HGSB_DoneWithGPR                     ;  Skip GPR sequence

	;Get GPR sequence
	;----------------
	push    di                                         ;Save Nic's Phy entry

	;Get GPR Init as first word in sequence
	inc     (GPR_STRUC PTR [di]).SequenceCount         ;Add room for GPR_Init
	mov     ax, GPR_Control                            ;Add GEP Control
	mov     (GPR_STRUC PTR [di]).SequenceData[0], ax
	add     di, 2                                      ;Point at next Nic's Phy field

HGSB_FillGPRSequence:
	movzx   ax, BYTE PTR [bx][si]
	inc     si
	mov     (GPR_STRUC PTR [di]).SequenceData[0], ax
	add     di, 2
	loop    HGSB_FillGPRSequence
	pop     di
HGSB_DoneWithGPR:
HGSB_Exit:

	ret

HandleGPRSequenceByteProc       endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:   HandleGPRSequenceWordProc             proc
;
; Description:
;       Parses Command word to CSR6 OM bits and external link sense data.
;
;       assumes:  DS  - CGroup
;                 Nic - Variable holding Nic data params.
;                 BX:SI  - Points at command word entry
;                 DI  - Points at media entry in Nic. 
;       Note:           
;       Returns:
;               
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
HandleGPRSequenceWordProc       proc

	;Get GPR sequence length
	;-----------------------
	movzx   cx, BYTE PTR [bx][si]                      ;Get Seq.length
	inc     si                                         ;Point to GPR sequence field
	cmp     cx, MAX_GPR_SEQUENCE                       ;If Seq. length > Nic's Limit then
	jg      SHORT HGSW_Exit                            ;  Exit

	mov     (GPR_STRUC PTR [di]).SequenceCount, cx    ;Save Sequence length

	cmp     cx, 0                                      ;If no GPR sequence then
	je      SHORT HGSW_DoneWithGPR                     ;  Skip GPR sequence

	;Get and Fill GPR sequence
	;-------------------------
	push    di                                         ;Save Nic's Phy entry
HGSW_FillGPRSequence:
	mov     ax, WORD PTR [bx][si]
	add     si, 2
	mov     (GPR_STRUC PTR [di]).SequenceData[0], ax
	add     di, 2
	loop    HGSW_FillGPRSequence
	pop     di
HGSW_DoneWithGPR:

HGSW_Exit:
	ret

HandleGPRSequenceWordProc       endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:          CountNumOfSensableMedia
;
; Description:
;       Counts the Number Of Sensable Media located In NIC
;
;       assumes:  DS  - CGroup
;                 Nic - Variable holding Nic data params.
;       Note:
;       Returns:
;               AX - Number of sensable media
; Remarks:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
CountNumOfSensableMedia         proc

	;Assume No sensable media
	;------------------------
	xor     ax, ax          ;No Sensable media

	;If fasternet - The precedence list has this value
	;-------------------------------------------------
	cmp     Nic.Dev, FASTERNET
	jne     SHORT CNOSM_NotFasterNet
	mov     ax, Nic.MediaPrecedence.NumMedia
	jmp     SHORT CNOSM_Exit
CNOSM_NotFasterNet:

	; We assume that media presence values in FasterNet can be only present/absent
	;-----------------------------------------------------------------------------
	add     ax, Nic.Media[TP].MediaPresence
	add     ax, Nic.Media[BNC].MediaPresence
	add     ax, Nic.Media[AUI].MediaPresence
	add     ax, Nic.Media[SymScr].MediaPresence
	add     ax, Nic.Media[SymScrFD].MediaPresence

CNOSM_Exit:
	ret

CountNumOfSensableMedia         endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         DoesFasternetBoardImplemetationSupportAutosensing
;
; Description:
;       Checks if Board supports autosensing
;
;       assumes:  DS  - CGroup
;                 Nic - Variable holding Nic data params.
;       Note:           
;       Returns:
;                 ZERO flag Set   - Board supports Autosensing
;                 ZERO flag ReSet - Board does NOT support Autosensing
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DoesFasternetBoardImplemetationSupportAutosensing       macro   StartAddressOfSROMData
	push    cx
	push    si
	push    di
	push    es

	;As for today only DE500 supports AutoSense on Fasternet1.1 boards
	;-----------------------------------------------------------------
	push    ds                            ;ds == Data Segment
	pop     es                            ;es <- ds
	mov     si, StartAddressOfSROMData     
	add     si, DE500StringLocation        ;si <- Location of DE500 string in SROM
	mov     cx, DE500StringLength          ;cx <- String lenght
	DataAddress	di, DE500String        ;di <- Expcted data in
	cld
  repz  cmpsb                                  ;Cmp between the strings untill difference is
					       ;found or string ends (Zero flag=1 -> strings are identical)
	pop     es
	pop     di
	pop     si
	pop     cx

endm


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         DetermineNIcAutoSenseCapabilities
;
; Description:
;        
; Determines if the Nic supports AutoSensing according to the following
; criteria:
; 2.1 If FASTERNET
;               The way the dynamic autosensing is enabled or disabled
;               is function of the chip Rev and the SROM Rev:
;
;                                   |     SROM V1             SROM V2 and UP
;               --------------------+-----------------------------------------
;               DC21140 rev1.1      |     Disabled        Disabled if 0x8000
;                                   |  except for DE500 
;                                   |
;               DC21140 rev1.2 & up |     Enabled         Disabled if 0x8000
;                                   |
;               --------------------+-----------------------------------------
;
;
;2.2. If TULIP3
;         Always supports AUTOSENSE 
;
;2.3. If TULIP
;         Never supports AutoSensing.
;
;2.3. If TWINET
;         Always supports AutoSensing.
;
;       assumes:  DS - CGroup
;                 Prarameters passed on stack:
;                       SROM FormatVesion - WORD
;                       Srom Data PTR     - WORD
;       Note:
;       Returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SromVersionParam        equ     6
SromStartAddressParam   equ     4

DetermineNIcAutoSenseCapabilities       proc

	push    bp
	mov     bp, sp

	;TULIP chip does NOT support AUTOSENSE - No need to handle it
	;------------------------------------------------------------
	cmp     Nic.Dev, TULIP
	je      DNASC_Exit

	;Is It TULIP3 chip?
	;------------------
	cmp     Nic.Dev, TULIP3
	jne     SHORT DNASC_NotTULIP3

	;Tulip3 is AutoSense capable
	;---------------------------
	mov     Nic.AutoSenseCapable, AUTOSENSE_CAPABLE
	jmp     SHORT DNASC_Exit
DNASC_NotTULIP3:

	;Is It TWINET chip?
	;------------------
	cmp     Nic.Dev, TWINET
	jne     SHORT DNASC_NotTwinet

	;Twinet is AutoSense capable
	;---------------------------
	mov     Nic.AutoSenseCapable, AUTOSENSE_CAPABLE
	jmp     SHORT DNASC_Exit
DNASC_NotTwinet:


	;-----------------
	;FasterNet section
	;-----------------
	;Is It Fasternet chip?
	;---------------------
	cmp     Nic.Dev, FASTERNET
	jne     SHORT DNASC_NotFASTERNET

	cmp     Nic.NumMiiPhys, 0
	jne     SHORT DNASC_FnetWithoutMII
	mov     Nic.AutoSenseCapable, AUTOSENSE_CAPABLE
	jmp     SHORT DNASC_Exit

	;If its Fasternet and we've reached this point- Its fasternet without MII PHY
	;So we need to do special checking for fing=ding out if its autosense capable
	;----------------------------------------------------------------------------
DNASC_FnetWithoutMII:
	call    HandleFasternetAutosenseCapabilitiesWithoutMiiPHY
	jmp     SHORT DNASC_Exit
DNASC_NotFASTERNET:

	;If reached this point - Unsupported Chip
	;----------------------------------------
	stc
	pop     bp
	ret

DNASC_Exit:
	;Get rid if AutoSense incapable bit
	;----------------------------------
	and     Nic.SelectedConnectionType, NOT DC21140_DISABLE_AUTOSENSE_MASK

	clc
	pop     bp
	ret

DetermineNIcAutoSenseCapabilities       endp


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:        HandleFasternetAutosenseCapabilitiesWithoutMiiPHY        proc
;
; Description:
;       ;Fasternet may or may-not support AutoSense.
;       ;the way the dynamic autosensing is enabled or disabled in FasterNet
;       ;is a function of the chip Rev and the SROM Rev:
;       ;
;       ;                     |  SROM V1 and Up   |  SROM LEGACY  |
;       ; --------------------+-------------------+---------------+
;       ; DC21140 rev1.1      |     Disabled      |     Disabled  |
;       ;                     |  except for DE500 |               |
;       ;                     |                   |               |
;       ; DC21140 rev1.2 & up | Disabled if 0x8000|     Disabled  |
;       ;-----------------------------------------+---------------+  
;
;       Assumes:
;               SS:BP - Pointer to data storage containing
;                               SromStartAddressParam  (WORD)
;                          and  SromVersionParam       (WORD)

;       Note:
;       Returns:
;
; Remarks:
;       Fasternet board implementation may be on of the following:
;
;         +-----------+---------------------------------+--------------------------+
;         |  DC21140  | Connectors  Relays   SD HW fix  |  AutoDetect  AutoSense   |
;         +-----------+---------------------------------+--------------------------+
;         |  Rev 1.1  |     2          0          n     |    yes          no       |
;         |           |     1          2          n     |    yes          no_op    |
;         |           |     1          1          n     |    yes          no       |
;         |           |     1          1          y     |    yes          yes      |
;         +-----------+---------------------------------+--------------------------+
;         |  Rev 1.2  |     2          0          n     |    yes          yes      |
;         |  & up     |     1          2          n     |    yes          no_op    |
;         |           |     1          1          n     |    yes          yes      |
;         +-----------+---------------------------------+--------------------------+
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
HandleFasternetAutosenseCapabilitiesWithoutMiiPHY       proc

	;If LEGACY Format Can't support autosensing
	;------------------------------------------
	cmp     WORD PTR [bp+SromVersionParam], FORMAT_LEGACY
	je      SHORT HFWMP_Exit

	;Count #of AutoSensable media and if <=1 -> Nic is NOT autosensable.
	;------------------------------------------------------------------- 
	call    CountNumOfSensableMedia
	cmp     ax, 1
	jle     SHORT HFWMP_Exit

	;Srom Version1 and above
	;-----------------------
	cmp     WORD PTR [bp+SromVersionParam], FORMAT1_0
	jg      SHORT HFWMP_FormatGreaterThan_1


	;SROM format == 1.0
	;------------------
	;If Fasternet Rev 1.1 Just special board implementations are AutoSense capable
	;-----------------------------------------------------------------------------
	cmp     Nic.Rev, CFRV_REV1_1
	jne     SHORT HFWMP_DoneWithFasterNetRev1_1

	mov     Nic.AutoSenseCapable, NOT AUTOSENSE_CAPABLE      ;Assume board incapable of autosensing
	DoesFasternetBoardImplemetationSupportAutosensing [bp+SromStartAddressParam]
	jne     SHORT HFWMP_DoneWithThisBoardImplementation

	;Board Implementation supports Autosensing
	;-----------------------------------------
HFWMP_DoneWithFasterNetRev1_1:
	mov     Nic.AutoSenseCapable, AUTOSENSE_CAPABLE
HFWMP_DoneWithThisBoardImplementation:
	jmp     SHORT HFWMP_Exit


	;SROM format > 1.0
	;-----------------
HFWMP_FormatGreaterThan_1:
	;If Nic.SelectedConnectionType is autosense - Check autosense capabilities
	;-------------------------------------------------------------------------
	mov     Nic.AutoSenseCapable, NOT AUTOSENSE_CAPABLE      ;Assume board incapable of autosensing
	cmp     Nic.SelectedConnectionType, NoSelectedConnection ;Do we have a selected connection at all ?
	je      SHORT HFWMP_SelectedConnectionIsNotAutoSense
	test    Nic.SelectedOperationMode, ModeAUTOSENSE         ;Is the Operation mode AutoSense ?
	jz      SHORT HFWMP_SelectedConnectionIsNotAutoSense

	test    Nic.SelectedConnectionType, DC21140_DISABLE_AUTOSENSE_MASK
	jnz     SHORT HFWMP_ROMIndicatesNoAutoSenseCapability

	;Mark Nic is capable performing autosense.
	;-----------------------------------------  
	mov     Nic.AutoSenseCapable, AUTOSENSE_CAPABLE
HFWMP_ROMIndicatesNoAutoSenseCapability:

HFWMP_SelectedConnectionIsNotAutoSense:

HFWMP_Exit:
	ret

HandleFasternetAutosenseCapabilitiesWithoutMiiPHY       endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ReadAndParseSRomParameters
;
; Description:  
;       Ethernet address on Tulip pass2.x PCI board is accesed through CSR9
;       which controls a serial ROM holding ethernet address only and is
;       fully controlled by HDW.
;
;       assumes:  DS - CGroup
;                 DI - *Data
;                 ES - The segment containing the Data and Checksum.
;       Note:           
;       Returns:
;               Upon ERROR - Carry - SET 
;                            DX    - Holding error message ptr
;
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ReadAndParseSRomParameters      proc    near

	push    ds
	pop     es                                  ;Es to point to Ds

	;Read SROM
	;---------
	xor     si, si                              ;Start From address 0
	mov     cx, srom_length                     ;Read all the SROM
	or      bx, 1                               ;Calculate checksum

	;Get temp location to read srom to
	;---------------------------------
	call    TempMemoryAllocation
	call    ReadSROM
	jnc     SHORT RAPSP_ParseSROMParameters

	;If failed to read SROM maybe its because it is V4.0 format
	;(Srom V4.0 is a shrunk srom V3.0 with valid CRC at bytes 94,95)
	;---------------------------------------------------------------
	push    eax
	push    di
	mov     cx, SROM_V4_ADAPTER_INFO_LENGTH-2       ;Remove rom Checksum bytes from ROM data CRC calc
	mov     si, di                                  ;Si to point to Data read
	call    CRC_Calc                          	;If leagal checksum in bytes 94,95 then
	cmp     ax, [si]                                ;  it's a shrunk format. (version 4.0 for instance)
	pop     di
	pop     eax
	je      SHORT RAPSP_ParseSROMParameters

	;If failed to read SROM maybe its because it is in a "CLASSIC" format
	;--------------------------------------------------------------------
	mov     bx, di
	call    ParseSROM_Classic
	jnc     SHORT RAPSP_FormatLegacy
	DataAddress	dx, SROM_ReadFailed
	jmp     SHORT RAPSP_ErrorExit

	;Go and Determine Nic's AutoSense capabilities
	;---------------------------------------------
RAPSP_FormatLegacy:
	push    WORD PTR FORMAT_LEGACY
	jmp     SHORT RAPSP_DetermineNIcAutoSenseCapabilities

	;Parse SROM parameters according to Srom Format Version
	;------------------------------------------------------
RAPSP_ParseSROMParameters:
	mov     bx, di
	cmp     BYTE PTR [bx][FORMAT_VERSION_LOC], FORMAT1_0
	je      SHORT RAPSP_HandleFormat1_0
	cmp     BYTE PTR [bx][FORMAT_VERSION_LOC], FORMAT3_0
	je      SHORT RAPSP_HandleFormat3_0
	cmp     BYTE PTR [bx][FORMAT_VERSION_LOC], FORMAT4_0
	je      SHORT RAPSP_HandleFormat4_0

	;If reached this point - Unknown Format
	DataAddress	dx, UnsupportedSRomVersion
	jmp     SHORT RAPSP_ErrorExit

RAPSP_HandleFormat1_0:
	call    ParseSROM_v1_0
	jc      SHORT RAPSP_ErrorExit
	;Go and Determine Nic's AutoSense capabilities
	push    WORD PTR FORMAT1_0
	jmp     SHORT RAPSP_DetermineNIcAutoSenseCapabilities

RAPSP_HandleFormat4_0:
	mov     BYTE PTR ds:[bx][FORMAT_VERSION_LOC], FORMAT3_0             ;For the driver V4.0 is as V3.0
RAPSP_HandleFormat3_0:
	call    ParseSROM_v3_0
	jc      SHORT RAPSP_ErrorExit
	;Go and Determine Nic's AutoSense capabilities
	push    WORD PTR FORMAT3_0
	jmp     SHORT RAPSP_DetermineNIcAutoSenseCapabilities

	;Determine Nic's AutoSense capabilities
	;--------------------------------------
RAPSP_DetermineNIcAutoSenseCapabilities:
	push	di					;Start of Shadow SROM
	call    DetermineNIcAutoSenseCapabilities
	add     sp, 4                                   ;Get rid of data on stack
	jmp     SHORT RAPSP_Exit

RAPSP_ErrorExit:
	stc
	ret
RAPSP_Exit:
	clc
	ret

ReadAndParseSRomParameters      endp



;******************************************************************************
;*           E T H E R N E T   A D D R E S S    R O M  (tulip pass2)          *
;******************************************************************************

;****************************************************************************
;
;       VerifyIEEEAddressChecksum
;
;       Verifys the Ethernet address ROM passed on stack.
;
; Inputs:
;       The following format is expected to be found on stack:
;                 E-NET ID byte 1
;                 E-NET ID byte 2
;                 E-NET ID byte 3
;                 E-NET ID byte 4
;                 E-NET ID byte 5
;                 E-NET ID byte 6
;                 checksum byte 1
;                 checksum byte 2
;       BP - points to the begining of the above data (located on stack).
; Outputs:
; Return values:
;       If checksum OK :
;          Ax == 0
;          carry bit is cleared
;       else
;          carry bit is set
;          reg AX <> 0
;          reg DX points to error message
;
;      EAX - Destroyed!
;****************************************************************************
VerifyIEEEAddressChecksum       proc    near

	xor     eax, eax                          ;Verify that not all bits of
	cmp     eax, [bp+0]                       ;IEEE address and checksum are
	jne     SHORT VIAC_IEEEAddressNotAllZeros ;zeros.
	cmp     eax, [bp+4]
	je      SHORT VIAC_BadIEEERomChecksum
VIAC_IEEEAddressNotAllZeros:
	dec     eax                              ;Verify that not all bits of
	cmp     eax, [bp+0]                      ;IEEE address and checksum are
	jne     SHORT VIAC_IEEEAddressNotAllOnes ;ones.
	cmp     eax, [bp+4]
	je      SHORT VIAC_BadIEEERomChecksum
VIAC_IEEEAddressNotAllOnes:

	mov     ah, [bp+0]                      ;Calculate the IEEE address
	mov     al, [bp+1]                      ;checksum
	shl     ax, 1
	jnc     SHORT VIAC_IEEE_NoCarry1
	sub     ax, 0FFFFh
VIAC_IEEE_NoCarry1:
	mov     ch, [bp+2]
	mov     cl, [bp+3]
	add     ax, cx
	jnc     SHORT VIAC_IEEE_NoCarry2
	sub     ax, 0FFFFh
VIAC_IEEE_NoCarry2:
	shl     ax, 1
	jnc     SHORT VIAC_IEEE_NoCarry3
	sub     ax, 0FFFFh
VIAC_IEEE_NoCarry3:
	mov     ch, [bp+4]
	mov     cl, [bp+5]
	add     ax, cx
	jnc     SHORT VIAC_IEEE_NoCarry4
	sub     ax, 0FFFFh
VIAC_IEEE_NoCarry4:

	cmp     ax, 0FFFFh
	jne     SHORT VIAC_IEEE_NoFFFF

	xor     ax, ax                          ;if (sum==FFFFh) then sum=0

VIAC_IEEE_NoFFFF:
	mov     ch, [bp+6]                      ;Compare calculated checksum
	mov     cl, [bp+7]                      ;to that of the IEEE prom.
	sub     ax, cx
	jnz     SHORT VIAC_BadIEEERomChecksum

	clc
	ret

VIAC_BadIEEERomChecksum:
	DataAddress	dx, SROM_ReadFailed
	stc
	ret

VerifyIEEEAddressChecksum       endp

;****************************************************************************
;
;       HandleEthernetAddressROM
;
;       DEC Ethernet address ROM has a specific format:
;               32 bytes ROM. ROM entries are accesible in Tulip Evaluation
;               board through dedicated EISA port 0zC90 (ENET_ADD_PORT).
;               Succesive reads from this port give next ROM entry in each read
;               in a loop on all entries.
;               The 32 entries are:
;                 E-NET ID byte 1
;                 E-NET ID byte 2
;                 E-NET ID byte 3
;                 E-NET ID byte 4
;                 E-NET ID byte 5
;                 E-NET ID byte 6
;                 checksum byte 1
;                 checksum byte 2
;                 checksum byte 2
;                 checksum byte 1
;                 E-NET ID byte 6
;                 E-NET ID byte 5
;                 E-NET ID byte 4
;                 E-NET ID byte 3
;                 E-NET ID byte 2
;                 E-NET ID byte 1
;                 E-NET ID byte 1
;                 E-NET ID byte 2
;                 E-NET ID byte 3
;                 E-NET ID byte 4
;                 E-NET ID byte 5
;                 E-NET ID byte 6
;                 checksum byte 1
;                 checksum byte 2
;                 Test pattern = FF
;                 Test pattern = 00
;                 Test pattern = 55
;                 Test pattern = AA
;                 Test pattern = FF
;                 Test pattern = 00
;                 Test pattern = 55
;                 Test pattern = AA
;       Check the Ethernet address ROM.
;       If there is a user defined Ethernet address (override)
;          routine will not read the ROM.
;       Else
;          If board is EISA
;             read Ethernet address from PLX EISA registers
;          Else
;             read Ethernet address from serial ROM through Tulip CSR9
;
;       If there is a user defined Ethernet address (override), routine will
;       not read the ROM.
;
; Inputs:
;       IOAddress1
;       MSMPhysNodeAddress
;       if TULIP3 || FASTERNET then
;               EthernetAddressRpm is on Stack and No checksum calc is needed
;
; Outputs:
;       MSMPhysNodeAddress - updated if not user defined
;
; Return values:
;       If user defined Ethernet address or successfully found Ethernet ROM
;       address:
;          carry bit is cleared
;       else
;          carry bit is set
;          reg AX contains error code
;          reg DX points to error message
;
;****************************************************************************
START_OF_ETH_ADDRESS_ON_STACK   equ     14        ;distance due to: return address + eax
						  ;                 +reserved 8 bytes on stac
HandleEthernetAddressROM        proc    near

	push    eax

	call	DidUserOverrideIEEEAddress
	je      HEAR_Exit             ;UserDefinedNodeAddress - No search is needed

	sub     sp, 8                 ;reserve 8 bytes on stack for
	mov     cx, 8                 ;IEEE address and checksum

	cmp     Nic.Dev, TULIP
	je      SHORT GetEthernetAddressFromBoard

	;Tulip3 and Fasternet use SROM and its Eth address is passed on stack
	;--------------------------------------------------------------------
	mov     si, sp                 ;DS:[SI+14] = Source
	add     si, START_OF_ETH_ADDRESS_ON_STACK
	jmp     HEAR_Tulip3orFasterNet

GetEthernetAddressFromBoard:

	mov     ax, ss
	mov     es, ax                ;ES to point to Storage segment
	mov     di, sp                ;Di points to Storage offset

	;User did not specify Node address. Handle the on board Ethernet
	;address ROM. Select handling algorithm according to board type (also
	;bus type).
	;--------------------------------------------------------------------
HandleEthernetAddressPCI:
	;Get Ethernet address from TULIP pass 2.x PCI board
	;--------------------------------------------------
	call    ReadAddressRomPCI
	jc      SHORT HEAR_ErrorExit

VerifyAddressChecksum:
	;This code is common to the EISA and PCI IEEE address verivication.
	;At this point, stack contains 6 IEEE address bytes + the checksum
	;-----------------------------------------------------------------
	mov     bp, sp                          ;Bp points to IEEE address&checksum
	call    VerifyIEEEAddressChecksum
	jc      SHORT HEAR_ErrorExit

	mov     si, sp                 		;SS:[SI] source of IEEE address
HEAR_Tulip3orFasterNet:

	;Move IEEE address to MLIDNodeAddress
	;------------------------------------
	call	SetIEEEAddressSROM

	add     sp, 8                  		;unreserve the 8 bytes.
HEAR_Exit:
	pop     eax
	clc             ;No error code
	ret

HEAR_ErrorExit:
	add     sp, 8
	pop     eax
	stc
	ret

HandleEthernetAddressROM        endp

;****************************************************************************
;
; Name:         SetIEEEAddressSROM
;
; Description:  This routine Checks sets the Driver's IEEE address variable
;
; On Entry:
;		SS:SI  pointer to the new IEEE Address.
;
; On Return:
;               all registers are  Preserved
;
;               Flags:
;
;
;****************************************************************************
SetIEEEAddressSROM	proc	near

	pushf
        push	es
	push	cx
        push	di

        CLD
	mov     cx, 6                  			;CX - number of bytes to transfer.
	lea     di, IEEEAddressSROM
	push    ds
	pop     es                     			;ES:[DI] destination
    rep movs    BYTE PTR ES:[DI], BYTE PTR SS:[SI]

	pop	di
	pop	cx
	pop	es
        popf
	ret

SetIEEEAddressSROM	endp



;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ReadAddressRomPCI
;
; Description:  
;       Ethernet address on Tulip pass2.x PCI board is accesed through CSR9
;       which controls a serial ROM holding ethernet address only and is
;       fully controlled by HDW.
;
;       assumes:  DS - CGroup
;                 DI - *Data
;                 CX - Len (to read)
;                 ES - The segment containing the Data and Checksum.
;       Note:           
;       Returns:
;               Upon ERROR - Carry - SET 
;                            DX    - Holding error message ptr
;
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ReadAddressRomPCI       proc    near

	mov     dx, Nic.CSR9_Address  	;point at serial ROM register
	out     dx, eax           	;reset the serial ROM address pointer by 
				  	;writing any value to CSR9.
RARP_NextSerialDataLoop:
	push    cx             ;next serial ROM byte should be ready within
	mov     cx, 10         ;50 usec.
RARP_RetrySerialROM:
	in      eax, dx         ;try get 1'st byte of Ethernet address
	or      eax, eax
	jns     SHORT RARP_SerialROMDataReady
	call    PostResetDelay  ;wait 5usec
	loop    RARP_RetrySerialROM

	;Serial ROM loop ended without data ready! Something is wrong!
	;-------------------------------------------------------------
	pop     cx
	DataAddress	dx, SROM_ReadFailed
	stc
	ret

RARP_SerialROMDataReady:
	pop     cx
	mov     ES:[di], al       ;data is in AL
	add     di, 1
	loop    RARP_NextSerialDataLoop

	;exit proc
	;---------
	clc
	ret

ReadAddressRomPCI       endp

;******************************************************************************
;*         N E W    F A S H I O N    S R O M  (Fasternet and tulip pass3)     *
;******************************************************************************
;Srom specifications
;--------------------
SROM_93LC46B_MAX_CYCLES         equ     25
SROM_93LC46B_LAST_ADDRESS       equ     3Fh
SROM_93LC46BLAST_ADDRESS_BIT    equ     5
SROM_93LC46B_LENGTH             equ     128

SROM_MAX_CYCLES         equ     SROM_93LC46B_MAX_CYCLES
SROM_LAST_ADDRESS       equ     SROM_93LC46B_LAST_ADDRESS
SROM_LAST_ADDRESS_BIT   equ     SROM_93LC46BLAST_ADDRESS_BIT
SROM_DELAY_COUNT        equ     4

;Srom related bits in CSR9
;-------------------------
SROM_CSR9_READ          equ     CSR9_RD
SROM_CSR9_WRITE         equ     CSR9_WR
SROM_SEL                equ     CSR9_SR

;Whenn SROM is selected then CSR9<0-3> have the following meaning:
;-----------------------------------------------------------------
SROM_DATA_1             equ     0004h
SROM_DATA_0             equ     0000h
SROM_CS                 equ     0001h
SROM_CLK                equ     0002h
SROM_DOUT_MASK          equ     0008h

;Related Data structures
;-----------------------
ChecsumStruc    struc
	Accumulator     dw      0
	Value_          dw      0
	ChecksumStatus  dw      0
ChecsumStruc ends

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         SromDelay       
;
; Description:  Delays the program the amount of time needed by the Srom
;               after signals transition.
;               The delay is a busy wait with interrupts disabled.
;
;       assumes:
;               Interrupts At any state 
;       Note:
;
; Remarks:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SromDelay       Proc    near

	push    ax
	pushf                                   ;Save flags
	push    word ptr SROM_DELAY_COUNT       ;Push delay count
	cli
	call    Delay
	pop     ax                              ;Get rid of Delay parameter.
	pop     ax                              ;Get OLD flags value
	test    ah, 2                           ;Check IF (Interrupt Flag)
	jz      SHORT SD_Exit
	sti
SD_Exit:
	pop     ax
	ret

SromDelay       endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         MakeSureSROM_IsIdle
;
; Description:  void MakeSureSROM_IsIdle(void)
;
;               This procedure makes sure that the serial rom was not interrupted
;               during a read cycle (by system reset ) and hence is not Idle
;               it does so by invoking it with the longest command possible
;               (measured in clocks), this will surly terminate every unfinished
;               command and put the ROM in Idle.
;
;       assumes: 
;
;       Note:
;
; Remarks:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MakeSureSROM_IsIdle     proc    near

	push    eax
	push    dx

	;Make sure SROM is in idle state (deliver it enough clocks with CS set,
	; Din = 0.
	;----------------------------------------------------------------------

	mov     dx, Nic.CSR9_Address

	mov     eax, SROM_CSR9_WRITE or SROM_SEL  ;Select SRom access
	out     dx, eax
	call    SromDelay

	or      al, SROM_CLK                           ;Clock UP
	out     dx, eax
	call    SromDelay

	and     al, not SROM_CLK                       ;Clock DOWN
	out     dx, eax
	call    SromDelay

	or      al, SROM_CS                            ;Select SRom
	out     dx, eax
	call    SromDelay

	or      al, SROM_CLK                           ;Clock UP
	out     dx, eax
	call    SromDelay

	and     al, not SROM_CLK                       ;Clock DOWN
	out     dx, eax
	call    SromDelay

	and     al, not SROM_CS                        ;DeSelect SRom
	out     dx, eax
	call    SromDelay

	pop     dx
	pop     eax
	ret

MakeSureSROM_IsIdle     endp


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ReadSROMWord
;
; Description:  int ReadSROM(ROM_Address, Len, Data, Checksum)
;
;                 SI -  ROM_Address - Offset in SROM.
;                                   Must be EVEN number. Else a bad data is read.
;
;       Returns:
;                 AX    - word read
;                 E(ax) - Destroyed
;                 CARRY set if error.
;       Note:
;
; Remarks:
;       I assume that the Rom address size is no greater then 8Bits.
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ReadSROMWord    proc    near

	push    cx
	push    dx
	push    bp

	;Initiate Read data sequence and signals
	;---------------------------------------
	mov     dx, Nic.CSR9_Address
	mov     eax, SROM_CSR9_WRITE or SROM_SEL or SROM_CS

	;Output READ command to the SROM (sequence of 110)
	;-------------------------------------------------
	or      ax, SROM_DATA_1         ;Write 1
	out     dx, eax
	call    SromDelay

	or      ax, SROM_CLK            ;clock UP
	out     dx, eax
	call    SromDelay

	and     ax, NOT SROM_CLK        ;Clock DOWN
	out     dx, eax
	call    SromDelay

	out     dx, eax                 ;Write 1
	call    SromDelay

	or      ax, SROM_CLK            ;Clock UP
	out     dx, eax
	call    SromDelay
					;Clock DOWN
	and     ax, NOT SROM_CLK
	out     dx, eax
	call    SromDelay

	and     ax, NOT SROM_DATA_1
	out     dx, eax                 ;Write 0
	call    SromDelay

	or      ax, SROM_CLK            ;Clock UP
	out     dx, eax
	call    SromDelay
					;Clock DOWN
	and     ax, NOT SROM_CLK
	out     dx, eax
	call    SromDelay

	;Output the WORD Address of the SROM (Bit by Bit from MSB to LSB)
	;----------------------------------------------------------------
	mov     cx, srom_address_size
	push    si

RSW_WriteAddressBit:
	pop     si
	push    si                            ;for correct shifting
	dec     cl                            
	shr     si, cl                        ;shift the appropriate address bit
	inc     cl                            ;restore cl
	and     si, 1                         ;mask all irrelevant address bits
	shl     si, 2                         ;Align to Data bit loacation (in CSR9) 
	and     ax, not SROM_DATA_1           ;Clear prev. address bit
	or      ax, si                        ;Move the address bit to ax
	out     dx, eax                       ;Write it to csr9
	call    SromDelay

	or      ax, SROM_CLK
	out     dx, eax                       ;Clock UP
	call    SromDelay

	and     ax, not SROM_CLK
	out     dx, eax                       ;Clock DOWN
	call    SromDelay

	loop    RSW_WriteAddressBit

	pop     si                            ;Restor SI

	;Verify that the SROM output data became now 0.
	;----------------------------------------------
	in      eax, dx
	test    eax, SROM_DOUT_MASK
	jnz     SHORT RSW_ReadFailed

	;Input the WORD of data from the SROM
	;------------------------------------
	push    WORD PTR 0              ;Create Temporary data storage
	mov     bp, sp
	mov     cx, 16

RSW_ReadBit:
	;Clock UP (with appropriate signals)
	;-----------------------------------
	mov     eax, SROM_CSR9_WRITE or SROM_SEL or SROM_CS or SROM_CLK
	out     dx, eax
	call    SromDelay

	;Read the "cx" bit in the word
	;------------------------------
	in      eax, dx                 
	shr     ax, 3                   ;Mov the databit to Bit0
	and     ax, 1                   ;Clear all othe bits
	dec     cx
	shl     ax, cl                  ;Mov the data bit to its relative 
	inc     cx                      ;location in WORD

	;Store the bit in the temporary data storage
	;-------------------------------------------
	or      ss:[bp], ax

	;Clock DOWN (with appropriate signals)
	;-------------------------------------
	mov     eax, SROM_CSR9_WRITE or SROM_SEL or SROM_CS
	out     dx, eax
	call    SromDelay

	loop    RSW_ReadBit

	;Negate the CS (chip select) to end the SROM command
	;---------------------------------------------------
	mov     eax, SROM_CSR9_WRITE or SROM_SEL
	out     dx, eax
	call    SromDelay
	pop     ax                      ;Move word read from Temp storage to ax

RSW_Exit:
	pop     bp
	pop     dx
	pop     cx
	clc
	ret

RSW_ReadFailed:
	pop     bp
	pop     dx
	pop     cx
	DataAddress	dx, SROM_ReadFailed
	stc
	ret

ReadSROMWord    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ReadSROM
;
; Description:  int ReadSROM(ROM_Address, Len, Data, CheckSum)
;
;               WORD *ROM_Address - Offset in SROM.
;                                   Is auto incremented after write.
;                                   Must be EVEN number. Else a bad data is read.
;               WORD Len          - Length in bytes 
;               WORD *Data;       - Pointer to data to buffer to read into.
;               CHECKSUM  Checksum- 0 if checksum calc is not reqiured.
;
;       assumes:  ES, DS - CGroup
;                 SI - Rom Address (in out)
;                 CX - Len
;                 DI - *Data        
;                 BX - CheckSum
;       Note:           
;       Returns:
;               ax, cx, si - Destroyed
;               Upon ERROR - Carry - SET 
;                            DX    - Holding error message ptr
; Remarks:
;       I assume that the Rom address size is no greater then 8Bits.     
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ReadSROM        proc    near

	push    cx
	push    di

	;Chip must be in RUN mode before reading the SROM
	;------------------------------------------------
	call    PutDeviceInRunMode

	;Read the SROM
	;-------------
	;Convert Byte address to word address
	;------------------------------------
	shr     si, 1

	;Make sure ROM is idle
	;---------------------
	call    MakeSureSROM_IsIdle

RS_ReadString:
	;Read the required String
	;------------------------
	call    ReadSROMWord
	jc      SHORT RS_ErrorExit

	inc     si                         ;Point to next WORD

	;Check if User wants the data
	;----------------------------
	cmp     di, 0
	je      SHORT RS_DonePassingDataToUserSpace

	;Check the data size the user requires and write the data
	;to the user data buffer.
	;--------------------------------------------------------
	cmp     cx, 1
	jne     SHORT RS_Word
	mov     BYTE PTR ES:[di], al
	inc     di                          ;point to next byte in user data buffer
	jmp     SHORT RS_DonePassingDataToUserSpace

RS_Word:
	mov     WORD PTR ES:[di], ax
	add     di, 2                       ;point to next word in user data buffer

RS_DonePassingDataToUserSpace:
	sub     cx, 2                       ;Update num of bytes remained to read.
	jg      SHORT RS_ReadString

	;End of READ
	;-----------
	;Restore and save original values
	;--------------------------------
	pop     di
	pop     cx

	push    cx
	push    di

	;Check af checksum is required and act accordingly
	;-------------------------------------------------
	or      bx, bx
	jz      SHORT RS_Exit

	sub     cx, 2    ;Remove rom Checksum bytes from ROM data
	mov     si, di   ;Si to point to Data read
	call    CRC_Calc
	cmp     ax, [si]
	jne     SHORT RS_ErrorExit

RS_Exit:
	;Restore Original activity mode (Sleep Snooze or Run)
	;----------------------------------------------------
	mov     cx, Nic.PowerMode
	call    PutDeviceInMode
	pop     di
	pop     cx
	clc
	ret               

RS_ErrorExit:
	;Restore Original activity mode (Sleep Snooze or Run)
	;----------------------------------------------------
	mov     cx, Nic.PowerMode
	call    PutDeviceInMode
	pop     di
	pop     cx
	stc
	ret               

ReadSROM        endp


;******************************************************************************
;*                                R O M                                       *
;******************************************************************************
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ROM_ReadAndParseRomParameters
;
; Description:
;       Ethernet address on Tulip pass2.x PCI board is accesed through CSR9
;       which controls a serial ROM holding ethernet address only and is
;       fully controlled by HDW.
;
;       assumes:  DS - CGroup
;                 DI - *Data
;                 ES - The segment containing the Data and Checksum.
;       Note:           
;       Returns:
;               Upon ERROR - Carry - SET 
;                            DX    - Holding error message ptr
;
; Remarks:
;       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ROM_ReadAndParseRomParameters   proc    near

	cmp     Nic.Dev, TULIP
	jne     SHORT RAPRP_NotTulip

RAPRP_Tulip:
	;Tulip has only Ethernet address ROM - Handle it.
	;------------------------------------------------
	call    HandleEthernetAddressROM
	jmp     SHORT REPRP_Exit

RAPRP_NotTulip:
	call    ReadAndParseSRomParameters

REPRP_Exit:
	ret
ROM_ReadAndParseRomParameters   endp

END_CODE_SEGMENT_INIT

;-----------------;
; Sanity checking ;
;-----------------;

;OS type checking
;----------------
IF OS EQ DOS
	%OUT DC_ROM.ASM Compiling for DOS.
ELSEIF OS EQ OS2
	%OUT DC_ROM.ASM Compiling for OS2.
ELSE
	.ERR
	%OUT DC_ROM.ASM Illegal OS value.
ENDIF

;NOS type checking
;-----------------
IF NOS EQ ODI
	%OUT DC_ROM.ASM Compiling for ODI.
ELSEIF NOS EQ NDIS2
	%OUT DC_ROM.ASM Compiling for NDIS2.
ELSE
	.ERR
	%OUT DC_ROM.ASM Illegal NOS value.
ENDIF



END
