;****************************************************************************
;*
;*    Copyright (c) 1994,1995,1996
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
; This file contains the hardware constants for addressing the DC2104X/DC21140
; chips on  PCI  platforms.
;
; Structure of HW.INC file:
;--------------------------
; 1. PCI specific data.
; 2. Bit description of DC21X4's CSR's, and constants related to them.
; 3. SROM (for DC21041/DC21140) description and related constants and structs.
; 4. Structures and definitions relating to different medias, and device-
;    specific information.
; 5. (PCI) Configuration-space definitions, and device-specific stuff.
; 6. XMT (transmit) definitions and data structures.
; 7. RCV (receive) definitions and data structures.
;
;
; Maintainers:
;               dp      David R. Pickett
;               eg      Eric Goldstein
;               mf      Maurene Fritz
;               rv      Rivki Vizen
;               ymf     Yishai M. Fraenkel
;               as      Adi Shaliv
;               de      Dror Efraty
;
; Revision History:
;
; 17-Jan-94     dp      Separated EISA and PCI offsets into separate constants
;                       added some basic comments.
; 22-Oct-93     dp      Created.
;
;  6-Jun-1994   eg      Define CSR6_K_TR_DEFAULT and SW_CRC_MIN.
;
;  6-Jun-1994   eg      Replace SIA autoconfiguration constants with SIA_CONFIG
;                       structure, for defining register values to configure
;                       the SIA.
;
;  5-jul-1994   mf      Add constants for CSR0 PBL values (burst limit)
;
; 31-jul-1994   mf      Add SIA_Config_Autodÿÿect (flag)
;
;  1-aug-1994   mf      Move transmit descriptor definitions to here from MAXMT
;                       Move receive  descriptor definitions to here from MARCV
;
; 12-sep-1994   rv      Add suport to DC21140
;
; 21-sep-1994   rv      Modify CSR10 default value to support the new boards
;
; 09-Oct-1994   rv      Add support to DC21140 pass 1.1
;
; 10-Oct-1994   ymf     Add SROM suppport for DC21140 pass 1.1
;
; 23-Oct-1994   ymf     Add SROM parameters
;
; 06-Apr-1995   ymf     As part of INIT restructuring:
;                       1. Move all SROM description and definitions to here.
;                       2. Define structs and types for storing Nic parameters
;                          preparing towards autosensing.
;                       3. Add and modify constatnts for CSR6, CSR12.
;                       4. Add types relating to PortConfigSIA,GPR.
;                       5. Reorganization.
;
; 20-Apr-1995   ymf     TULIP3 autosense - add constatnts and masks
;
; 08-Jun-1995   ymf     10/100 Autodetection
;                       Revise to accomodate SROM v1.02.
;
; 04-Sep-1995  as       AutoSense - add fields for use in autosense
;                                   to Nic type struct
; 13-Sep-1995  as       Autosense - Add field 'IsDefaultMediaSROM' to Nic
;                         Type struct.
; 24-Sep-1995  as       Add Multia Board values for BNC  CSR13,14,15
;
; 10-Nov-1995  as       Add Constants , Data structure For Mii Phys support
;
; 10-Dec-1995  as       Remove EISA support from driver.
;
; 05-Feb-1996  as       Add Support for DC21142 (TWINET)
;
; 08-Apr-1996  as       Replace NicType.SelectedMedia + NicType.OperationalMode
;                       with NicType.SelectedConectionType union.
;                       Change all this struct element use in all the Driver files.
;
; 25-Nov-1996   de      change in AWK convention.
;                       module name changed from hw.ash to hw.inc
;
; 16-Feb-1997   de      make buffers and descriptors 32 Bytes aligned.
;
;--------------------------------------------------------------------------


;**************************************************
;*   CONFIGURATION-SPACE and Device-Specific info *
;**************************************************
CFDA_NO_SNOOZE_MODE             EQU 0BFFFFFFFh
CFDA_FULL_SNOOZE_MODE           EQU 040000000h
CFDA_NO_SLEEP_MODE              EQU 07FFFFFFFh
CFDA_FULL_SLEEP_MODE            EQU 080000000h
CFDA_PS_MODE                    EQU CFDA_FULL_SLEEP_MODE  ; for TULIP3 power saving mode


HW_K_SETUP_FRAME_SIZE           EQU 192
;
;  Descriptor definitions
;
;     Transmit Descriptor
;     -------------------
;
; The DC21040/DC21140 Transmit Descriptor is described in the DC21040/DC21140
; specification. The names of the fields, TDES0-3 are taken straight from the
; spec. This structure, and the associated constants, define the format of the
; transmit descriptor used by the DC21040/DC21140. A transmit descriptor must
; be allocated a physically contiguous, longword aligned region of memory. The
; transmit buffers to which the descriptors point may be of arbitrary alignment
; and size.
;
; The p_XmtBuffer and p_XmtNext fields of the descriptor are unique to this
; driver implementation. They are virtual NEAR pointers to the transmit buffer
; and the next descriptor respectively. The descriptor skip length in CSR0 is
; set to 1 longword in order to skip this extra longword at the end of each
; descriptor.
;

XMT_DESCRIPTOR  STRUC
   TDES0       DD 0
   TDES1       DD 0
   TDES2       DD 0
   TDES3       DD 0
   p_XmtBuffer DW 0
   p_XmtNext   DW 0
   Xmt_padd    DB 12 DUP (0)       ; for cache line alignment
XMT_DESCRIPTOR  ENDS

DESCRIPTOR_SKIP_LENGTH equ 16

TDES0_M_OWN             EQU 080000000h  ; OWN Bit 1=DC21040/DC21140 0=Host
TDES0_M_ES              EQU 000008000h  ; Error Summary (UF|EC|LC|NC|LO|TO|LF)
TDES0_M_TO              EQU 000004000h  ; Transmit Jabber Expired
TDES0_M_LO              EQU 000000800h  ; Loss of Carrier
TDES0_M_NC              EQU 000000400h  ; No Carrier
TDES0_M_LC              EQU 000000200h  ; Late Collision
TDES0_M_EC              EQU 000000100h  ; Excessive Collisions
TDES0_M_HF              EQU 000000080h  ; Heartbeat Fail
TDES0_M_CC              EQU 000000078h  ; Collision Count
TDES0_M_LF              EQU 000000004h  ; Link Fail
TDES0_M_UF              EQU 000000002h  ; Underflow Error
TDES0_M_DE              EQU 000000001h  ; Deferred
TDES0_M_ALL_ERR         EQU 00000CFFFh  ; All error bits
TDES0_V_OWN             EQU 31
TDES0_V_ES              EQU 15
TDES0_V_TO              EQU 14
TDES0_V_LO              EQU 11
TDES0_V_NC              EQU 10
TDES0_V_LC              EQU 9
TDES0_V_EC              EQU 8
TDES0_V_HF              EQU 7
TDES0_V_CC              EQU 3
TDES0_V_LF              EQU 2
TDES0_V_UF              EQU 1
TDES0_V_DE              EQU 0

TDES1_M_IC              EQU 080000000h  ; Interrupt on Completion
TDES1_M_LS              EQU 040000000h  ; Last Segment
TDES1_M_FS              EQU 020000000h  ; First Segment
TDES1_M_FT1             EQU 010000000h  ; Filter Type 1
TDES1_M_SET             EQU 008000000h  ; Setup Packet
TDES1_M_AC              EQU 004000000h  ; Add CRC Disable
TDES1_M_TER             EQU 002000000h  ; Transmit End of Ring
TDES1_M_TCH             EQU 001000000h  ; Second Address Chained
TDES1_M_DPD             EQU 000800000h  ; Disable Padding
TDES1_M_FT0             EQU 000400000h  ; Filter Type 0
TDES1_M_BUFFER_2_SIZE   EQU 0003FF800h  ; Size in bytes of Buffer 2
TDES1_M_BUFFER_1_SIZE   EQU 0000007FFh  ; Size in bytes of Buffer 1

TDES1_V_IC              EQU 31
TDES1_V_LS              EQU 30
TDES1_V_FS              EQU 29
TDES1_V_FT1             EQU 28
TDES1_V_SET             EQU 27
TDES1_V_AC              EQU 26
TDES1_V_TER             EQU 25
TDES1_V_TCH             EQU 24
TDES1_V_DPD             EQU 23
TDES1_V_FT0             EQU 22
TDES1_V_BUFFER_2_SIZE   EQU 11
TDES1_V_BUFFER_1_SIZE   EQU 0

XMT_BUFFER_SIZE         EQU 1536 ; Buffers are aligned 32 Bytes
;
;     Receive Descriptor
;     ------------------
;
;
; The DC21040/DC21140 Receive Descriptor is described in the DC21040/DC21140
; specification. The names of the fields, RDES0-3 are takes straight from the
; spec. This structure, and the associated constants, define the format of the
; receive descriptor used by the DC21040/DC21140. A receive descriptor must be
; allocated a physically contiguous, longword aligned region of memory. The
; receive buffers to which the descriptors point must also be physically
; contiguous and longword alignedand a MOD 4 length.
;
; The p_buf and p_next fields of the descriptor are unique to this driver
; implementation. They are virtual NEAR pointers to the receive buffer and
; the next descriptor respectively. The descriptor skip length in CSR0 is
; set to 1 longword in order to skip this extra longword at the end of each
; descriptor.
;

RCV_DESCRIPTOR  STRUC
   RDES0   DD 0
   RDES1   DD 0
   RDES2   DD 0
   RDES3   DD 0
   p_buf   DW 0
   p_next  DW 0
   Rx_padd DB 12 DUP (0)       ; for cache line alignment
RCV_DESCRIPTOR  ENDS

RDES0_M_OWN             EQU 080000000h  ; OWN bit 0=HOST 1=DC21040/DC21140
RDES0_M_LENGTH          EQU 07FFF0000h  ; Length of frame in bytes including CRC
RDES0_M_ES              EQU 000008000h  ; Error Summary (OF|CE|CS|TL|LE|RF)
RDES0_M_LE              EQU 000004000h  ; Length Error (rcv buffer too small)
RDES0_M_DT              EQU 000003000h  ; Data Type
RDES0_M_RF              EQU 000000800h  ; Runt Frame
RDES0_M_MF              EQU 000000400h  ; MCast frame
RDES0_M_FS              EQU 000000200h  ; First Descriptor
RDES0_M_LS              EQU 000000100h  ; Last Descriptor
RDES0_M_TL              EQU 000000080h  ; Frame too long (>1518 bytes)
RDES0_M_CS              EQU 000000040h  ; Collision Seen
RDES0_M_FT              EQU 000000020h  ; Frame Type 1=DIX 0=802.3
RDES0_M_RJ              EQU 000000010h  ; Receive Watchdog Expired (frame >2K)
RDES0_M_DB              EQU 000000004h  ; Dribbling Bit
RDES0_M_CE              EQU 000000002h  ; CRC Error
RDES0_M_OF              EQU 000000001h  ; DC21040/DC21140 Rcv DMA FIFO Overflow

RDES0_V_OWN             EQU 31
RDES0_V_LENGTH          EQU 16
RDES0_V_ES              EQU 15
RDES0_V_LE              EQU 14
RDES0_V_DT              EQU 12
RDES0_V_RF              EQU 11
RDES0_V_MF              EQU 10
RDES0_V_FS              EQU 9
RDES0_V_LS              EQU 8
RDES0_V_TL              EQU 7
RDES0_V_CS              EQU 6
RDES0_V_FT              EQU 5
RDES0_V_RJ              EQU 4
RDES0_V_DB              EQU 2
RDES0_V_CE              EQU 1
RDES0_V_OF              EQU 0

RDES0_K_FT_DIX          EQU 1
RDES0_K_FT_802          EQU 0

RDES0_K_DT_NORMAL       EQU 0
RDES0_K_DT_INTERNAL     EQU 1
RDES0_K_DT_EXTERNAL     EQU 2
RDES0_K_DT_RESERVED     EQU 3

RDES1_M_RER             EQU 002000000h  ; Receive End Of Ring
RDES1_M_RCH             EQU 001000000h  ; Second address chained
RDES1_M_BUFFER_2_SIZE   EQU 0003FF800h  ; Size in bytes of buffer 2 (MOD 4)
RDES1_M_BUFFER_1_SIZE   EQU 0000007FFh  ; Size in bytes of buffer 1 (MOD 4)

RDES1_V_RER             EQU 25
RDES1_V_RCH             EQU 24
RDES1_V_BUFFER_2_SIZE   EQU 11
RDES1_V_BUFFER_1_SIZE   EQU 0

RCV_BUFFER_SIZE EQU 1536   ; Buffers are aligned 32 Bytes.

