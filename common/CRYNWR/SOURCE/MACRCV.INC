
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
; This file contains the constants for addressing the receive descriptors
; of the DC2104X/DC21140 chips on  PCI  platforms. It also contains constants
; that are relevant to the receive process.
;
; Written by: Dror Efraty
;  Date:      15-Apr-1997
;
;----------------------------------------------------------------------------

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

