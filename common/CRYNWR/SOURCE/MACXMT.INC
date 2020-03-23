;****************************************************************************
;*
;*    Copyright (c) 1994-1997
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
; This file contains the constants for addressing the transmit descriptors
; of the DC2104X/DC21140 chips on  PCI  platforms. It also contains constants
; that are relevant to the transmit process
;
; Written by: Dror Efraty
;  Date:      15-Apr-1997
;
;----------------------------------------------------------------------------


XMT_SETUP_FRAME_SIZE           EQU 192
XMT_NUMBER_OF_ADDRESSES        EQU 16
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



