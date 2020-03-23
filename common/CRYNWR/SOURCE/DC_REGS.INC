;*******************************************************************************
;
; DC_REGS.INC
;
; Include file for Dec Tulip and Fast Ethernet board that holds the devices'
; registers description and their layout.
;
; Written by:   Moti Haimovsky
; Date:         27-Jul-1994
;
;                                       
; Copyright (C) 1994 by Digital Equipment Corporation
; All rights reserved.
;
; Modification History:
;
; By              Date        Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
;
; Moti Haimovsky  10-Aug-1994 0.31  - Added reading EISA_LineSpeed from the EISA
;				      configuration file.
;                                   - Added equate for minimum CFLT we need for
;				      proper operation.
; Moti Haimovsky  21-Aug-1994 1.0    - Changed CSR10 EXTERNAL_POINT_TO_POINT to be
;				      0Bh for supporting the Motorola Implementation
;				      FasterNet board.
; Moti Haimovsky  2-Sep-1994 1.01   - Changed I/O Port Selection from CSR10 to CSR12
;				      In-Order to support Fasternet Pass II
;   	    			    - Changed CSR12 EXTERNAL_POINT_TO_POINT to be
;				      0Fh for overcoming 10Mbps port activity
;				      interfearing with 100Mbps port activity.
; Moti Haimovsky  4-Sep-1994  	    - Added Fasternet pass 1.1 CFRV definition
; Moti Haimovsky 12-Sep-1994  	    - Changed CSR12 EXTERNAL_POINT_TO_POINT to be
;				      0Bh since 10Mbps port activity interfearing
;				      with 100Mbps port activity had been fixed
;				      in FasterNet pass1.1.
; Moti Haimovsky 13-Oct-1994 1.02   - Added Reading SROM in FasterNet pass1.1
; Moti Haimovsky 02-Dec-1994 2.00   - Fixed bug in SROM checksum calc.
;				    - Changed default PBL and CAL to 32 (tulip pass1
;				      will remain in 16 due to a bug).
; Moti Haimovsky 30-Jan-1995 2.01   - Added Tulip3 support
; Moti Haimovsky 16-Feb-1995 2.10   - Changed CSR12 init val to 11fh according to
;				      Yuval's mail.
;				      Changed csr12MaxVal to 1ff
; Moti Haimovsky 26-Feb-1995 2.10   - Added CSR12 values for SymScr, SymScrFD and TP_FD
;				      according to the PHY we use.
; Moti Haimovsky 28-Feb-1995 	    - Modified CSR6 MII_10 values to include <TTM>
; Moti Haimovsky 28-Feb-1995 2.11   - Modified CSR6 MII_100 Tx Threshold value from
;				      Full-Packet to 128Bytes since is significantly
;				      improves driver's performance in 'good' pci
;				      machines.
; Moti Haimovsky 27-Mar-1995	    - Moved UNDEF_USER_xxxx from this File to DC_KWDS.INC
;			      	      (Where it should be)
; Moti Haimovsky 30-Mar-1995	    - Changed TxThr Default in Tulip and Tulip3 to 96
; Moti Haimovsky 22-Jun-1995  2.13  - Changed CSR6 default value of FasterNet to include
;				      TM0, due tothe need to use Link-Long timer.
; Moti Haimovsky 25-Jun-1995        - Added CFDA definitions for SLEEP and SNOOZE modes.
; Moti Haimovsky 23-Jul-1995        - Added CSR11 Register definitions.
;
; Moti Haimovsky 04-Sep-1995  2.14  - Added PHY bit definitions in csr9
;
; Moti Haimovsky  5-Nov-1995  2.15  - Modigied default PBL and CAL to 16 lonwords to
;				      overcome tulip & Fnet bug in 32longword bursts.
; Moti Haimovsky  8-Nov-1995        - Modified default PBL and CAL of Fasternet to 32 lonwords
;				      since it has no bug in 32longword bursts.
;
; Moti Haimovsky 29-Oct-1995  2.20  - Modified Tulip3 SIA defaults to be ASE_AND
; Moti Haimovsky  6-Nov-1995        - Modified CFDA definitions for SLEEP SNOOZE and RUN
;				      modes.
; Moti Haimovsky 22-Nov-1995        - Modified Tulip3 Media values according to the new
;				      spec.
; Moti Haimovsky 30-Nov-1995  2.30  - Adding support for TwiNet
; Moti Haimovsky 25-Dec-1995        - Added TwiNet GEP values, modified GEP max values
;				      to 0FFFFh
; Moti Haimovsky 30-Jan-1996  2.40  - Modified CSR7 Normal int mask to include ERM (ERI support)
; Moti Haimovsky 09-May-1996  2.33  - Added CSR8 Mask definitions.
;				      Added TWINET_CSR13/4/5_SYM definitions
; Moti Haimovsky 24-Jun-1996  2.40  - Added Twinet2 Nway definitions.
; Moti Haimovsky 30-Jun-1996  	    - Added Twinet2 Link change and ANC Interrupts definiotions.
;				      to CSR5 & CSR7 regs.
; Moti Haimovsky 20-Aug-1996  2.41  - Modified Twinet2 SIA definitions due to problems noticed
;				      when working with QSI in 10MBps.
; Adi Shaliv     20-Aug-1996        - Add Multia Board values for BNC  CSR13,14,15
; Moti Haimovsky 05-Nov-1996  2.50  - Added Phyer support
; Moti Haimovsky 13-Nov-1996	    - Added CSR12_SRA definition to be used by TULIP3 autosensing.
; Moti Haimovsky 13-Jan-1997  2.60  - Moved PCI Regs definitions to SYSSRVCS module.
; Moti Haimovsky 09-Feb-1997        - Added extended PCi command bits efinitions to CSR0.
; Moti Haimovsky 13-Apr-1997        - modified CSR7_INTERRUPTS_MASK_VAL to be driver specific
;				      (NDIS2 or ODI)
; Moti Haimovsky 14-Apr-1997        - added CSR7_INTERRUPTS_MASK_OFF const.
; Motti Daniel	 12-Oct-1997	    - Adding PCI_CFLT_MASK to mask the CFLT part of the register.
; Motti Daniel	 03-Feb-1998  2.62  - Add ConfigCFCS_IOSpaceAccess bit definition.
;*******************************************************************************


.386

; DCxxxx EISA Board definitions:     ; DCxxxx PCI Board definitions:
; ==============================     ===============================

;          <-- 32  bits ->	          <-- 32  bits ->
;          +-------------+		  +-------------+ --------------------
;   0z008  |    CFID     |	     00h  |    CFID     |            	     ^
;          +-------------+	          +-------------+            	     |
;   0z00C  |    CFCS     |	     04h  |    CFCS     |            Access to
;          +-------------+	          +-------------+            these regs
;   0z018  |    CFRV     |	     08h  |    CFRV     |          Via PCI BIOS
;          +-------------+		  +-------------+       calls (int 1Ah)
;   0z01C  |    CFLT     |	     0Ch  |    CFLT     |                    |
;          +-------------+	          +-------------+                    |
;   0z028  |    CBIO     | 	     10h  |    CBIO     |                    |
;          +-------------+	          +-------------+                    |
;          :             :                :             :                    |
;          +-------------+	          +-------------+                    |
;    ????  |    CBER     | 	     34h  |    CBER     | Tulip3 only        |
;          +-------------+	          +-------------+                    |
;	   :		 : 		  :		:                    |
;          +-------------+   	          +-------------+ ---------------    |
;    ????  |    CFIT     |   	     3Ch  |    CFIT     | Not implemented    |
;          +-------------+                +-------------+ in Tulip      |    |
;    ????  |    CFDA     |           40h  |    CFDA     | pass1         v    v
;          +-------------+                +-------------+ --------------------
;          <-- 32  bits ->		  <-- 32  bits ->
;          +-------------+		  +-------------+
;   0z000  |    CSR0     |      Base+00h  |    CSR0     |
;          +-------------+    		  +-------------+
;   0z010  |    CSR1     |      Base+08h  |    CSR1     |
;          +-------------+		  +-------------+
;   0z020  |    CSR2     |      Base+10h  |    CSR2     |
;          +-------------+		  +-------------+
;   0z030  |    CSR3     |    	Base+18h  |    CSR3     |
;          +-------------+		  +-------------+
;   0z040  |    CSR4     |    	Base+20h  |    CSR4     |
;          +-------------+		  +-------------+
;   0z050  |    CSR5     |    	Base+28h  |    CSR5     |
;          +-------------+		  +-------------+
;   0z060  |    CSR6     |    	Base+30h  |    CSR6     |
;          +-------------+		  +-------------+
;   0z070  |    CSR7     |    	Base+38h  |    CSR7     |
;          +-------------+		  +-------------+
;   0z080  |    CSR8     |    	Base+40h  |    CSR8     |
;          +-------------+		  +-------------+
;   0z090  |    CSR9     |    	Base+48h  |    CSR9     |
;          +-------------+		  +-------------+
;   0z0A0  |    CSR10    |    	Base+50h  |    CSR10    |
;          +-------------+		  +-------------+
;   0z0B0  |    CSR11    |    	Base+58h  |    CSR11    |
;          +-------------+		  +-------------+
;   0z0C0  |    CSR12    |    	Base+60h  |    CSR12    |
;          +-------------+		  +-------------+   ------
;   0z0D0  |    CSR13    |    	Base+68h  |    CSR13    |
;          +-------------+		  +-------------+     Not implemented
;   0z0E0  |    CSR14    |    	Base+70h  |    CSR14    |     in FasterNet
;          +-------------+		  +-------------+
;   0z0F0  |    CSR15    |    	Base+78h  |    CSR15    |
;          +-------------+		  +-------------+   -------
;	   <--   8 bits ->
;          +-------------+
;   0zC80  |EISA ID byte0|
;          +-------------+
;   0zC81  |EISA ID byte1|
;          +-------------+
;   0zC82  |EISA ID byte2|
;          +-------------+
;   0zC83  |EISA ID byte3|
;          +-------------+
;   0zC84  |     EBC     |
;          +-------------+
;          :             :
;          +-------------+
;   0zC88  |EISA REG 0   |
;          +-------------+
;   0zC89  |EISA REG 1   |
;          +-------------+
;   0zC8A  |EISA REG 2   |
;          +-------------+
;          :             :
;          +-------------+
;   0zC8F  |EISA REG 3   |
;          +-------------+
;   0zC90  |ENET ADD PORT|
;          +-------------+

;-----------------------------------------------------------------------------
;NOTICE:
;   On PCI machines the PCI registers located in the PCI config space and are
;   are accessed via the PCI BIOS CALL, the above registers are not mapped to
;   the I/O space of the pc, thats why they do not appear in the TULIP
;   registers I/O layout represented in PCI_TulipCSRstruc.
;-----------------------------------------------------------------------------


DC_PCIBoardStruc               struc
	PCI_CSR0	dd      ?
	PCI_hole0       dd      ?
	PCI_CSR1        dd      ?
	PCI_hole1       dd      ?
	PCI_CSR2        dd      ?
	PCI_hole2       dd      ?
	PCI_CSR3        dd      ?
	PCI_hole3       dd      ?
	PCI_CSR4        dd      ?
	PCI_hole4       dd      ?
	PCI_CSR5        dd      ?
	PCI_hole5       dd      ?
	PCI_CSR6        dd      ?
	PCI_hole6       dd      ?
	PCI_CSR7        dd      ?
	PCI_hole7       dd      ?
	PCI_CSR8        dd      ?
	PCI_hole8       dd      ?
	PCI_CSR9        dd      ?
	PCI_hole9       dd      ?
	PCI_CSR10       dd      ?
	PCI_hole10      dd      ?
	PCI_CSR11       dd      ?
	PCI_hole11      dd      ?
	PCI_CSR12       dd      ?
	PCI_hole12      dd      ?
	PCI_CSR13       dd      ?
	PCI_hole13      dd      ?
	PCI_CSR14       dd      ?
	PCI_hole14      dd      ?
	PCI_CSR15       dd      ?
	PCI_hole15      dd      ?
DC_PCIBoardStruc               ends


;******************************************************************************
;     D C x x x x    C S R s   B I T   M A S K S   A N D   S H A D O W S
;******************************************************************************


;CSR0 register
;-------------
CAL_BITS_MASK	equ	0C000h
CAL_BITS_LOCATION equ	14
CAL_0     	equ   	0       ;Cache alignment = 0  No alignment (burst will be performed according to PBL)
CAL_1     	equ   	1       ;Cache alignment = 1   8-Longword boundary alignment
CAL_2     	equ   	2       ;Cache alignment = 2  16-Longword boundary alignment
CAL_3     	equ   	3       ;Cache alignment = 3  32-Longword boundary alignment
DEF_CAL   	equ   CAL_3   	;Default to 3 (0 is now a bug in Tulip pass 1)
MIN_CAL   	equ   CAL_0   	;Is used for CAL keyword processing
MAX_CAL   	equ   CAL_3   	;Is used for CAL keyword processing

PBL_BITS_MASK	equ	03F00h
PBL_BITS_LOCATION equ	8
PBL_0     	equ   	0       ;Programmable burst length UNLIMITED ;Do not use it due to Tulip Bug
PBL_1     	equ   	1       ;Programmable burst length of 1
PBL_2     	equ   	2       ;Programmable burst length of 2
PBL_4     	equ   	4       ;Programmable burst length of 4
PBL_8     	equ   	8       ;Programmable burst length of 8
PBL_16    	equ   	16      ;Programmable burst length of 16
PBL_32    	equ   	32      ;Programmable burst length of 32      ;Do not use it due to Tulip Bug
DEF_PBL   	equ   	PBL_32
MIN_PBL   	equ   	PBL_0   ;Is used for PBL keyword processing
MAX_PBL   	equ   	PBL_32  ;Is used for PBL keyword processing

CSR0_SWR      	equ         01h     ;SW reset bit
CSR0_MRM	equ	200000h     ;Memory Read Multiple bit
CSR0_MRL	equ	800000h     ;Memory Read Line bit
CSR0_MWI	equ    1000000h     ;Memory Write Invalidate bit

CSR0_DEFAULT  equ   (DEF_PBL SHL PBL_BITS_LOCATION) + (DEF_CAL SHL CAL_BITS_LOCATION)


;CSR5 important bit masks:
;-------------------------
CSR5_TI         equ       1h    ;Transmit interrupt bit mask
CSR5_TPS        equ       2h    ;Transmit process stopped bit mask
CSR5_TU         equ       4h    ;Transmit buffer unavailable bit mask
CSR5_TJT        equ       8h    ;Transmit Jabber timeout bit mask
CSR5_LNP        equ      10h    ;Link Pass(10BaseT link is UP againe)(TULIP3 ONLY)
CSR5_ANC 	equ 	 10h    ;Nway complete mask (part of abnormal interrupt) (Twinet2).
CSR5_UNF        equ      20h    ;Transmit Transmit underflow bit mask
CSR5_RI         equ      40h    ;Receive interrupt bit mask
CSR5_RU         equ      80h    ;Receive buffer unavailable bit mask
CSR5_RPS        equ     100h    ;Receive process stopped bit mask
CSR5_RWT        equ     200h    ;Receive watchdog timeout bit mask
CSR5_AT         equ     400h    ;AUI/TP interrupt bit mask    - TULIPx only
CSR5_TM         equ     800h    ;(Internal)Timer Expired - (TULIP3 & FASTERNET only)
CSR5_FD         equ     800h    ;Full duplex short frame received bit mask (TULIP1 ONLY)
CSR5_LNF        equ    1000h    ;Link fail bit mask           - TULIPx only
CSR5_SE         equ    2000h    ;System error (PCI bus) bit mask
CSR5_Er         equ    4000h    ;Early receive interrupt (TULIP3 Only)
CSR5_AIS        equ    8000h    ;Abnormal interrupt summary bit mask
CSR5_NIS        equ   10000h    ;Normal interrupt summary bit mask
CSR5_RS         equ  0E0000h    ;Receive process status bits mask
CSR5_TS         equ 0700000h    ;Transmit process status bits mask
CSR5_EB         equ 3800000h    ;PCI bus error status bits mask
CSR5_LC 	equ 08000000h   ;SymScr Link change Interrupt (part of abnormal interrupt) (Twinet2 only).



;CSR6 bits def:
;--------------
TX_THRESHOLD_72         equ     0          ;TX_THRESHOLD_128 in FASTERNET
TX_THRESHOLD_96         equ     1          ;TX_THRESHOLD_256 in FASTERNET
TX_THRESHOLD_128        equ     2          ;TX_THRESHOLD_512 in FASTERNET
TX_THRESHOLD_160        equ     3          ;TX_THRESHOLD_1024 in FASTERNET 
TX_THRESHOLD_FP        	equ     4          ;Full packet in in FASTERNET or TX_THRESHOLD_160 in others.
TX_THRESHOLD_MIN        equ     TX_THRESHOLD_72
TX_THRESHOLD_MAX        equ     TX_THRESHOLD_160
TX_THRESHOLD_DEF        equ     TX_THRESHOLD_96    ;Not Min Due to Swiss cheese in Tulip

OM_NORMAL		equ	0
OM_INTERNAL_LOOPBACK	equ	1
OM_EXTERNAL_LOOPBACK	equ	2

CSR6_START_RX_COMMAND   equ       2h
CSR6_PB			equ	  8h	;Pass bad frames
CSR6_SB			equ      20h	;Start/Stop backoff counter
CSR6_PROMISCUOUS_MODE   equ      40h    ;promiscuous
CSR6_PM			equ	 80h	;Pass all Multicast
CSR6_FKD		equ     100h	;Flaky Oscillator Disable
CSR6_FD			equ     200h    ;Full Duplex
CSR6_START_TX_COMMAND   equ    2000h

; FASTERNET only
;---------------
CSR6_PS			equ   40000h    ;Port Select
CSR6_HBD		equ   80000h    ;Heart Beat Disabled
CSR6_IMM                equ  100000h    ;Immediate Transmission
CSR6_FP                 equ  200000h    ;Full Packet
CSR6_MII_RATE		equ  400000h      ;Selects MII/SYM 100Mbps (0) or 10Mbps (1)
CSR6_TTM		equ CSR6_MII_RATE ;data rate and tx threshold
CSR6_CS                 equ  800000h    ;operates MII/SYM port in SYM mode
CSR6_PCS                equ  CSR6_CS
CSR6_SCR                equ 1000000h    ;MII/SYM port to work in Scramble mode
CSR6_TM0		equ 2000000h    ;TM0 Link-Long timer mode should be 1 in Fasternet only.




;CSR6 Port and data rate selections
;----------------------------------
;Tulip
;------
TULIP_CSR6_SIA_10M	equ     0

;FasterNet & Twinet
;------------------
;--------------------------------------------------------------------------------------------
; PS     HBD	TTM	PCS	SCR	Active	    Data     Dev	     Function
;<18>   <19>	<22>    <23>    <24>    Port	    Rate
;--------------------------------------------------------------------------------------------
; 0	 0	 1	 X       X      SIA         10	  FASTERNET+TWINET   SIA port
; 1	 1	 1	 0	 0	MII	    10	  FASTERNET+TWINET   For working with MII phy
; 1	 1	 0	 0	 0	MII	    100   FASTERNET+TWINET   For working with MII phy
; 1	 1	 0	 1	 0	MII/SYM     100	  FASTERNET          For working with 100BaseFX Phy
; 1	 1	 0	 1	 1	MII/SYM/SCR 100   FASTERNET          For working with 100BaseTX (SymScr) Phy
;---------------------------------------------------------------------------------------------
CSR6_PORT_SPEED_SELECTION_MASK  equ	CSR6_PS or CSR6_HBD or CSR6_TTM or \
					CSR6_PCS or CSR6_SCR
							 
CSR6_SIA_10M				equ   	(CSR6_TTM)
CSR6_MII_10M				equ   	(CSR6_PS or CSR6_HBD or CSR6_TTM)
CSR6_MII_100M	 			equ   	(CSR6_PS or CSR6_HBD)
CSR6_MII	 			equ   	CSR6_MII_100M
CSR6_SYM_100M 				equ   	(CSR6_PS or CSR6_HBD or CSR6_PCS)
CSR6_SYM_SCR_100M 			equ   	(CSR6_PS or CSR6_HBD or CSR6_PCS or CSR6_SCR)

;CSR6 default:
;-------------
;TX threshold of 72 bytes, stop transmit, FC=0, OM=0, FD=0
;FKD=0, PM=0, PR=0, SB=0, PB=0, stop receive.

TULIP_CSR6_DEFAULT	equ	(TX_THRESHOLD_DEF SHL 14) OR TULIP_CSR6_SIA_10M
TULIP3_CSR6_DEFAULT	equ	(TX_THRESHOLD_DEF SHL 14) OR TULIP_CSR6_SIA_10M
FASTERNET_CSR6_DEFAULT	equ	(TX_THRESHOLD_MIN SHL 14) OR CSR6_SIA_10M OR CSR6_TM0
TWINET_CSR6_DEFAULT	equ	(TX_THRESHOLD_MIN SHL 14) OR CSR6_SIA_10M OR CSR6_TM0




;------------------------------------------
;CSR7 (interrupt mask register) definitions
;------------------------------------------
CSR7_TIM equ 00001h     ;Transmit interrupt. Masks CSR5_TI.
CSR7_TSM equ 00002h     ;Transmit stopped. Masks CSR5_TPS.
CSR7_TUM equ 00004h     ;Transmit buffer unavailable due to driver starvation
			;(upper layers did not deliver enough TX packets). This
			;is the nature! This disabled interrupt wanted to
			;report: end of current job. Masks CSR5_TU.
CSR7_TJM equ 00008h     ;Transmit jabber timeout is also reported in TX
			;descriptor. Masks CSR5_TJT.
CSR7_LPE equ 00010h     ;LinkPass mask (part of abnormal interrupt) (TULIP3 only).
CSR7_ANE equ 00010h     ;Nway complete mask (part of abnormal interrupt) (Twinet2).
CSR7_UNM equ 00020h     ;Transmit underruns are also reported in TX descriptor.
			;Masks CSR5_UNF.
CSR7_RIM equ 00040h     ;Receive interrupt. Masks CSR5_RI.
CSR7_RUM equ 00080h     ;Receive buffer unavaiable. Masks CSR5_RU.
CSR7_RSM equ 00100h     ;Receive stopped. Masks CSR5_RPS. We are not going to
			;stop the receive, and hence we will not get this kind
			;of interrupt.
CSR7_RWM equ 00200h     ;Receive watchdog timeout is also marked at the RX
			;descriptor, so, why should we get an interrupt?
			;Actually, it's not one more interrupt, since it comes
			;with the RI...but why not to make the life more easy?
			;Masks CSR5_RWT.
CSR7_ATM equ 00400h     ;AUI/TP is only sensed at init time. We do not support
			;changes of the external switch on the fly.
			;Masks CSR5_AT.
CSR7_FDM equ 00800h     ;full duplex. Masks CSR5_FD.        (TULIP1,2 only)
CSR7_TMM equ 00800h     ;Timer expired mask. Masks CSR5_TM. (TULIP3 & FasterNet)
CSR7_LFE equ 01000h     ;link fail. Masks CSR5_LNF.
CSR7_SEM equ 02000h     ;System error (PCI errors). Masks CSR5_SE.
CSR7_ERM equ 04000h     ;CSR7_ERM Masks CSR5_ER (Early receive interrupt).
CSR7_AIM equ 08000h     ;CSR7_AIM Masks CSR5_AIS.
CSR7_NIM equ 10000h     ;CSR7_NIM Masks CSR5_NIS
CSR7_LCE equ 08000000h  ;SymScr Link change Enable mask (part of abnormal interrupt) (Twinet2 only).

IF NOS EQ ODI

;Enabled normal interrupts:
;  TI (enabled by CSR7_TIM), TU enabled by CSR7_TUM), RI (enabled by CSR7_RIM).
;Enabled abnormal interrupts:
;  SE(enabled by CSR7_SEM), TJT(enabled by CSR7_TJM), UNF(enabled by CSR7_UNM).
;Disabled abnormal interrupts:
   ;TPS(enabled by CSR7_TSM), AT(enabled by CSR7_ATM), RWT(enabled by CSR7_RWM),
   ;RPS (enabled by CSR7_RSM), FD(enabled by CSR7_FDM), RU(enabled by CSR7_RUM),
   ;LNF (enabled by CSR7_LFM).
;------------------------------------------------------------------------------
CSR7_Normal_Int_mask    	equ     CSR7_NIM+CSR7_RIM+CSR7_TIM+CSR7_TUM+CSR7_ERM  ;Note that GenerateTUInterrupt
										      ;Relys on TUM to be opened.
CSR7_Abnormal_Int_mask  	equ     CSR7_AIM+CSR7_SEM+CSR7_TJM+CSR7_UNM

CSR7_INTERRUPTS_MASK_VAL 	equ    	CSR7_Normal_Int_mask+CSR7_Abnormal_Int_mask

ELSE

CSR7_INTERRUPTS_MASK_VAL 	equ    	CSR7_NIM or CSR7_AIM or CSR7_RIM
CSR7_INTERRUPTS_MASK_OFF	equ	0	

ENDIF

;----------------
;CSR8 definitions
;----------------
CSR8_MASK_MISSED_FRAMES		equ	1FFFFh
CSR8_MASK_RX_OVERFLOW 		equ  1FFE0000h


;----------------
;CSR9 definitions
;----------------

;CSR9 definitions  (FASTERNET and TULIP3 only)
;---------------------------------------------
CSR9_DataMask	equ	0FFh
CSR9_REG	equ	400h    ;External register select
CSR9_SR         equ	800h    ;Serial ROM select (used with RD or WR operation)

;CSR9 Boot rom mode bits
;-----------------------
CSR9_BR         equ    1000h    ;Boot ROM select   (used with RD or WR operation)
CSR9_WR         equ    2000h    ;Write operation if selecting SROM or
			        ;Flashes the BOOT-Rom (if BootRom is selected).	
CSR9_RD         equ    4000h    ;Read from the BootRom or SROM.
CSR9_MODE       equ    8000h    ;Operation mode of TULIP3 - Simulate TULIP2 or
				;work as tulip3 (read only bit).

TULIP3_MODE_AT_TULIP2	equ	CSR9_MODE

;CSR9 Srom mode bits
;-------------------
CSR9_SCS	equ	1h	;Serial rom chip select
CSR9_SCLK	equ	2h	;Serial rom serial clock
CSR9_SDI	equ	4h	;Serial rom Data In
CSR9_SDO	equ	8h	;Serial rom Data out
CSR9_MDC	equ 10000h	;MMI Clock
CSR9_MDO	equ 20000h	;MMI Data out (Write to Phy)
CSR9_MMD0       equ 20000h	;MMI mode bits
CSR9_MMD1       equ 40000h      ;MMI mode bits
CSR9_MDI	equ 80000h      ;MII Data in (Read from Phy)

CSR9_MII_READ	equ CSR9_MMD1 or CSR9_RD     	;Bits combinations fot PHY read
CSR9_MII_WRITE	equ CSR9_WR     		;Bits combinations fot PHY write


;-----------------
;CSR11 definitions
;-----------------

;CSR11 definitions  (FASTERNET only)
;-----------------------------------
CSR11_CON	equ	10000h


;-----------------------------------
;CSR12 definitions  (FASTERNET only)
;-----------------------------------
CSR12_DEFAULT				equ	EXTERNAL_POINT_TO_POINT


;CSR12 definitions (CSR12 bit masks) (TULIP only):
;-------------------------------------------------
CSR12_NCR	equ	2	; No Carrier
CSR12_LKF	equ	4	; Link Fail
CSR12_SRA	equ   100h	; Selected port receive activity
	
;CSR12 definitions (CSR12 bit masks) (Twinet & PHYER Only):
;---------------------------------------------------------
CSR12_LF100T 	equ	2	;Link fail of 100Base-T status (SYM Phy only)
CSR12_LPN	equ	8000h	;Link Partnet Nway able indication

;GPR definitions (FASTERNET & TWINET& PHYER)
;-------------------------------------------
GPR_MinValue		equ	0h
GPR_InitMaxValue	equ	0FFFFh
GPR_DataMaxValue	equ	0FFFFh

;Fasternet
;---------
GPR_InitValue				equ	11fh
EXTERNAL_POINT_TO_POINT			equ	0Bh
EXTERNAL_POINT_TO_POINT_TpFD		equ	03h
EXTERNAL_POINT_TO_POINT_SymScr		equ	1Bh
EXTERNAL_POINT_TO_POINT_SymScrFD	equ	1Bh
ONBOARD_LOOPBACK			equ	8h
INBOARD_LOOPBACK			equ	0ah

;Twinet
;------
TWINET_GPR_InitValue			equ	8FFh
TWINET_GPR_DataValue			equ	0F0h


;******************************************************************************
;		  S I A   R E G I S T E R S  -  T U L I P  
;******************************************************************************
;SIA Regs (CSRs 13,14,15) - (TULIP only - NOT TULIP3!!!)
;-------------------------------------------------------

;Programming the SIA for different media types:
;----------------------------------------------

;CSR15, CSR14, CSR13 programming values for TP selection
;-------------------------------------------------------
CSR13_TP		equ	08F01h
CSR14_TP   		equ	0FFFFh
CSR15_TP   		equ	00000h

;CSR15, CSR14, CSR13 programming values for TP Ignore Link Test selection
;------------------------------------------------------------------------
CSR13_TP_ILT		equ	08F01h
CSR14_TP_ILT   		equ	0CFFFh
CSR15_TP_ILT   		equ	00000h

;CSR15, CSR14, CSR13 programming values for TP Full Duplex selection
;-------------------------------------------------------------------
CSR13_TP_FD		equ	08F01h
CSR14_TP_FD		equ	0FFFDh
CSR15_TP_FD		equ	00000h

;CSR15, CSR14, CSR13 programming values for AUI selection
;--------------------------------------------------------
CSR13_AUI  		equ	08F09h
CSR14_AUI  		equ	00705h
CSR15_AUI  		equ	00006h    

;CSR15, CSR14, CSR13 programming values for BNC selection
;--------------------------------------------------------
CSR13_BNC  		equ     0EF09h
CSR14_BNC  		equ     00705h
CSR15_BNC  		equ     00006h    

;CSR15, CSR14, CSR13 programming values for BNC selection on MULTIA board
;-------------------------------------------------------------------------
MULTIA_CSR13_BNC        equ     03041h
MULTIA_CSR14_BNC        equ     00000h
MULTIA_CSR15_BNC        equ     00006h

;CSR15, CSR14, CSR13 default values (TULIP ONLY !)
;-------------------------------------------------
 CSR13_DEFAULT		equ	CSR13_TP
 CSR14_DEFAULT		equ     CSR14_TP
 CSR15_DEFAULT		equ     CSR15_TP



;******************************************************************************
;		  S I A   R E G I S T E R S  -  T U L I P 3  
;******************************************************************************
;SIA Regs (CSRs 13,14,15) - (TULIP3 only)
;----------------------------------------

;	       Auto-Sensing Disabled, Auto-Negotiation Disabled
;              ------------------------------------------------
;Mode                      CSR13  CSR14  CSR15  AUI_BNC Pin  CSR6<FD>  CSR6<OM>
;------------------------------------------------------------------------------
;10BASE-T forced           EF01   7F3F   0008    high(AUI)      0        00
;to half-duplex
;
;;10BASE-T forced          EF01   4F3F   0008    high(AUI)      0        00
;to half-duplex with
;No link test
;
;10BASE-T forced           EF01   7F3D   0008    high(AUI)      1        00
;to full-duplex 
;
;BNC (10BASE-2)            EF09   0705   0006    low (BNC)      0        00
;
;AUI (10BASE-5)            EF09   0705   000E    high(AUI)      0        00


TULIP3_CSR13_ASD_AND_TP  	equ	0EF01h
TULIP3_CSR14_ASD_AND_TP  	equ	 7F3Fh
TULIP3_CSR15_ASD_AND_TP  	equ      0008h

TULIP3_CSR13_ASD_AND_TP_NLT  	equ	0EF01h
TULIP3_CSR14_ASD_AND_TP_NLT	equ	 4F3Fh
TULIP3_CSR15_ASD_AND_TP_NLT	equ      0008h

TULIP3_CSR13_ASD_AND_TP_FD	equ     0EF01h
TULIP3_CSR14_ASD_AND_TP_FD  	equ      7F3Dh
TULIP3_CSR15_ASD_AND_TP_FD  	equ      0008h

TULIP3_CSR13_ASD_AND_BNC  	equ     0EF09h
TULIP3_CSR14_ASD_AND_BNC  	equ      0705h
TULIP3_CSR15_ASD_AND_BNC  	equ      0006h

TULIP3_CSR13_ASD_AND_AUI  	equ     0EF09h
TULIP3_CSR14_ASD_AND_AUI  	equ      0705h
TULIP3_CSR15_ASD_AND_AUI  	equ      000Eh


;              Auto-Sensing Disabled, Auto-Negotiation Enabled
;              -----------------------------------------------
;Mode                      CSR13  CSR14  CSR15  AUI_BNC Pin  CSR6<FD>  CSR6<OM>
;------------------------------------------------------------------------------
;10BASE-T advertising       EF01   7FFF   0008    High (AUI)     1        00
;half and full duplex 
;
;10BASE-T advertising       EF01   7FBF   0008    High (AUI)     1        00
;full duplex only
;
;10BASE-T  advertising      EF01   7FFF   0000    High (AUI)     0        00
;half duplex only
;


;	       Auto-Sensing Enabled, Auto-Negotiation Disabled
;              -----------------------------------------------
;Mode                      CSR13  CSR14  CSR15  AUI_BNC Pin  CSR6<FD>  CSR6<OM>
;------------------------------------------------------------------------------
;10BASE-T forced            EF01   FF3F   0008    High (AUI)     0        00
;to half-duplex 
;
;10BASE-T forced            EF01   FF3D   0008    High (AUI)     1        00
;to full-duplex 
;
;BNC (10BASE-2)             EF09   F73D   0006    low (BNC)      0        00
;
;AUI (10BASE-5)             EF09   F73D   000E    high(AUI)      0        00
;
TULIP3_CSR13_ASE_AND_TP  	equ	0EF01h
TULIP3_CSR14_ASE_AND_TP  	equ	0FF3Fh
TULIP3_CSR15_ASE_AND_TP  	equ      0008h

TULIP3_CSR13_ASE_AND_TP_FD	equ     0EF01h
TULIP3_CSR14_ASE_AND_TP_FD  	equ     0FF3Dh
TULIP3_CSR15_ASE_AND_TP_FD  	equ      0008h

TULIP3_CSR13_ASE_AND_BNC  	equ     0EF09h
TULIP3_CSR14_ASE_AND_BNC  	equ     0F73Dh
TULIP3_CSR15_ASE_AND_BNC  	equ      0006h

TULIP3_CSR13_ASE_AND_AUI  	equ     0EF09h
TULIP3_CSR14_ASE_AND_AUI  	equ     0F73Dh
TULIP3_CSR15_ASE_AND_AUI  	equ      000Eh

;	       Auto-Sensing Enabled, Auto-Negotiation Enabled
;              -----------------------------------------------
;Mode                      CSR13  CSR14  CSR15  AUI_BNC Pin  CSR6<FD>  CSR6<OM>
;------------------------------------------------------------------------------
;10BASE-T advertising       EF01   FFFF   0008    High (AUI)     1        00
;half and full duplex 
;
;10BASE-T advertising       EF01   FFBF   0008    High (AUI)     1        00
;full duplex only
;
;10BASE-T advertising       EF01   FFFF   0008    High (AUI)     0        00
;half duplex 
;
;BNC(10BASE-2) advertising  EF09   F7FD   0006    low (BNC)      1        00
;half and full duplex on TP
;
;BNC(10BASE-2) advertising  EF09   F7BD   0006    low (BNC)      1        00
;full duplex only on TP
;
;BNC(10BASE-2) advertising  EF09   F7FD   0006    low (BNC)      0        00
;half duplex only on TP
;
;AUI(10BASE-5) advertising  EF09   F7FD   000E    high(AUI)      1        00
;half and full duplex on TP
;
;AUI(10BASE-5) advertising  EF09   F7BD   000E    high(AUI)      1        00
;full duplex only on TP
;
;AUI(10BASE-5) advertising  EF09   F7FD   000E    high(AUI)      0        00
;half duplex only on TP


;Tulip3 Media selection defaults
;-------------------------------
TULIP3_CSR13_TP_DEFAULT		   equ	TULIP3_CSR13_ASE_AND_TP
TULIP3_CSR14_TP_DEFAULT		   equ	TULIP3_CSR14_ASE_AND_TP
TULIP3_CSR15_TP_DEFAULT		   equ	TULIP3_CSR15_ASE_AND_TP

TULIP3_CSR13_TP_NLT_DEFAULT	   equ	TULIP3_CSR13_ASD_AND_TP_NLT
TULIP3_CSR14_TP_NLT_DEFAULT	   equ	TULIP3_CSR14_ASD_AND_TP_NLT
TULIP3_CSR15_TP_NLT_DEFAULT	   equ	TULIP3_CSR15_ASD_AND_TP_NLT

TULIP3_CSR13_TPFD_DEFAULT	   equ	TULIP3_CSR13_ASD_AND_TP_FD
TULIP3_CSR14_TPFD_DEFAULT	   equ	TULIP3_CSR14_ASD_AND_TP_FD
TULIP3_CSR15_TPFD_DEFAULT	   equ	TULIP3_CSR15_ASD_AND_TP_FD

TULIP3_CSR13_AUI_DEFAULT 	   equ  TULIP3_CSR13_ASE_AND_AUI
TULIP3_CSR14_AUI_DEFAULT 	   equ  TULIP3_CSR14_ASE_AND_AUI
TULIP3_CSR15_AUI_DEFAULT 	   equ  TULIP3_CSR15_ASE_AND_AUI

TULIP3_CSR13_BNC_DEFAULT 	   equ 	TULIP3_CSR13_ASE_AND_BNC
TULIP3_CSR14_BNC_DEFAULT 	   equ  TULIP3_CSR14_ASE_AND_BNC
TULIP3_CSR15_BNC_DEFAULT 	   equ	TULIP3_CSR15_ASE_AND_BNC



;******************************************************************************
;		  S I A   R E G I S T E R S  -  T W I N E T  
;******************************************************************************
;	       Auto-Sensing Disabled, Auto-Negotiation Disabled
;              ------------------------------------------------
;Mode                      CSR13  CSR14  CSR15  AUI_BNC Pin  CSR6<FD>  CSR6<OM>
;------------------------------------------------------------------------------
;10BASE-T forced           EF01   7F3F   0008    high(AUI)      0        00
;to half-duplex
;
;;10BASE-T forced          EF01   4F3F   0008    high(AUI)      0        00
;to half-duplex with
;No link test
;
;10BASE-T forced           EF01   7F3D   0008    high(AUI)      1        00
;to full-duplex 
;
;BNC (10BASE-2)            EF09   0705   0006    low (BNC)      0        00
;
;AUI (10BASE-5)            EF09   0705   000E    high(AUI)      0        00

TWINET_CSR13_ASD_AND_TP  	equ	TULIP3_CSR13_ASD_AND_TP
TWINET_CSR14_ASD_AND_TP  	equ	TULIP3_CSR14_ASD_AND_TP
TWINET_CSR15_ASD_AND_TP  	equ     TULIP3_CSR15_ASD_AND_TP

TWINET_CSR13_ASD_AND_TP_NLT  	equ     TULIP3_CSR13_ASD_AND_TP_NLT
TWINET_CSR14_ASD_AND_TP_NLT	equ	TULIP3_CSR14_ASD_AND_TP_NLT
TWINET_CSR15_ASD_AND_TP_NLT	equ     TULIP3_CSR15_ASD_AND_TP_NLT

TWINET_CSR13_ASD_AND_TP_FD	equ     TULIP3_CSR13_ASD_AND_TP_FD
TWINET_CSR14_ASD_AND_TP_FD  	equ     TULIP3_CSR14_ASD_AND_TP_FD
TWINET_CSR15_ASD_AND_TP_FD  	equ     TULIP3_CSR15_ASD_AND_TP_FD

TWINET_CSR13_ASD_AND_BNC  	equ     TULIP3_CSR13_ASD_AND_BNC
TWINET_CSR14_ASD_AND_BNC  	equ     TULIP3_CSR14_ASD_AND_BNC
TWINET_CSR15_ASD_AND_BNC  	equ     TULIP3_CSR15_ASD_AND_BNC

TWINET_CSR13_ASD_AND_AUI  	equ     TULIP3_CSR13_ASD_AND_AUI
TWINET_CSR14_ASD_AND_AUI  	equ     TULIP3_CSR14_ASD_AND_AUI
TWINET_CSR15_ASD_AND_AUI  	equ     TULIP3_CSR15_ASD_AND_AUI


;              Auto-Sensing Disabled, Auto-Negotiation Enabled
;              -----------------------------------------------
;Mode                      CSR13  CSR14  CSR15  AUI_BNC Pin  CSR6<FD>  CSR6<OM>
;------------------------------------------------------------------------------
;10BASE-T advertising       EF01   7FFF   0008    High (AUI)     1        00
;half and full duplex 
;
;10BASE-T advertising       EF01   7FBF   0008    High (AUI)     1        00
;full duplex only
;
;10BASE-T  advertising      EF01   7FFF   0000    High (AUI)     0        00
;half duplex only
;


;	       Auto-Sensing Enabled, Auto-Negotiation Disabled
;              -----------------------------------------------
;Mode                      CSR13  CSR14  CSR15  AUI_BNC Pin  CSR6<FD>  CSR6<OM>
;------------------------------------------------------------------------------
;10BASE-T forced            EF01   FF3F   0008    High (AUI)     0        00
;to half-duplex 
;
;10BASE-T forced            EF01   FF3D   0008    High (AUI)     1        00
;to full-duplex 
;
;BNC (10BASE-2)             EF09   F73D   0006    low (BNC)      0        00
;
;AUI (10BASE-5)             EF09   F73D   000E    high(AUI)      0        00
;
TWINET_CSR13_ASE_AND_TP  	equ	TULIP3_CSR13_ASE_AND_TP
TWINET_CSR14_ASE_AND_TP  	equ	TULIP3_CSR14_ASE_AND_TP
TWINET_CSR15_ASE_AND_TP  	equ     TULIP3_CSR15_ASE_AND_TP

TWINET_CSR13_ASE_AND_TP_FD	equ     TULIP3_CSR13_ASE_AND_TP_FD
TWINET_CSR14_ASE_AND_TP_FD  	equ     TULIP3_CSR14_ASE_AND_TP_FD
TWINET_CSR15_ASE_AND_TP_FD  	equ     TULIP3_CSR15_ASE_AND_TP_FD

TWINET_CSR13_ASE_AND_BNC  	equ     TULIP3_CSR13_ASE_AND_BNC
TWINET_CSR14_ASE_AND_BNC  	equ     TULIP3_CSR14_ASE_AND_BNC
TWINET_CSR15_ASE_AND_BNC  	equ     TULIP3_CSR15_ASE_AND_BNC

TWINET_CSR13_ASE_AND_AUI  	equ     TULIP3_CSR13_ASE_AND_AUI
TWINET_CSR14_ASE_AND_AUI  	equ     TULIP3_CSR14_ASE_AND_AUI
TWINET_CSR15_ASE_AND_AUI  	equ     TULIP3_CSR15_ASE_AND_AUI

;	       Auto-Sensing Enabled, Auto-Negotiation Enabled
;              -----------------------------------------------
;Mode                      CSR13  CSR14  CSR15  AUI_BNC Pin  CSR6<FD>  CSR6<OM>
;------------------------------------------------------------------------------
;10BASE-T advertising       EF01   FFFF   0008    High (AUI)     1        00
;half and full duplex 
;
;10BASE-T advertising       EF01   FFBF   0008    High (AUI)     1        00
;full duplex only
;
;10BASE-T advertising       EF01   FFFF   0008    High (AUI)     0        00
;half duplex 
;
;BNC(10BASE-2) advertising  EF09   F7FD   0006    low (BNC)      1        00
;half and full duplex on TP
;
;BNC(10BASE-2) advertising  EF09   F7BD   0006    low (BNC)      1        00
;full duplex only on TP
;
;BNC(10BASE-2) advertising  EF09   F7FD   0006    low (BNC)      0        00
;half duplex only on TP
;
;AUI(10BASE-5) advertising  EF09   F7FD   000E    high(AUI)      1        00
;half and full duplex on TP
;
;AUI(10BASE-5) advertising  EF09   F7BD   000E    high(AUI)      1        00
;full duplex only on TP
;
;AUI(10BASE-5) advertising  EF09   F7FD   000E    high(AUI)      0        00
;half duplex only on TP


;TWINET Media selection defaults
;-------------------------------
TWINET_CSR13_TP_DEFAULT		   equ	TWINET_CSR13_ASE_AND_TP
TWINET_CSR14_TP_DEFAULT		   equ	TWINET_CSR14_ASE_AND_TP
TWINET_CSR15_TP_DEFAULT		   equ	TWINET_CSR15_ASE_AND_TP

TWINET_CSR13_TP_NLT_DEFAULT	   equ	TWINET_CSR13_ASD_AND_TP_NLT
TWINET_CSR14_TP_NLT_DEFAULT	   equ	TWINET_CSR14_ASD_AND_TP_NLT
TWINET_CSR15_TP_NLT_DEFAULT	   equ	TWINET_CSR15_ASD_AND_TP_NLT

TWINET_CSR13_TPFD_DEFAULT	   equ	TWINET_CSR13_ASD_AND_TP_FD
TWINET_CSR14_TPFD_DEFAULT	   equ	TWINET_CSR14_ASD_AND_TP_FD
TWINET_CSR15_TPFD_DEFAULT	   equ	TWINET_CSR15_ASD_AND_TP_FD

TWINET_CSR13_AUI_DEFAULT 	   equ  TWINET_CSR13_ASE_AND_AUI
TWINET_CSR14_AUI_DEFAULT 	   equ  TWINET_CSR14_ASE_AND_AUI
TWINET_CSR15_AUI_DEFAULT 	   equ  TWINET_CSR15_ASE_AND_AUI

TWINET_CSR13_BNC_DEFAULT 	   equ 	TWINET_CSR13_ASE_AND_BNC
TWINET_CSR14_BNC_DEFAULT 	   equ  TWINET_CSR14_ASE_AND_BNC
TWINET_CSR15_BNC_DEFAULT 	   equ  TWINET_CSR15_ASE_AND_BNC


;Constant for TWINET in MII mode
;-------------------------------
TWINET_CSR13_MII    equ    0
TWINET_CSR14_MII    equ    0
TWINET_CSR15_MII    equ	   8h

;Constant for TWINET in SYM mode
;-------------------------------
TWINET_CSR13_SYM    equ		TWINET_CSR13_MII
TWINET_CSR14_SYM    equ		TWINET_CSR14_MII
TWINET_CSR15_SYM    equ		TWINET_CSR15_MII


;	       Twinet2 Auto-Sensing Enabled, Auto-Negotiation Enabled
;              -----------------------------------------------
;Mode                      CSR13  CSR14  CSR15  AUI_BNC Pin  CSR6<FD>  CSR6<OM>
;------------------------------------------------------------------------------
;10BASE-T advertising       0001   FFFF   0008    High (AUI)     1        00
;half and full duplex 
;
;10BASE-T advertising       0001   FFBF   0008    High (AUI)     1        00
;full duplex only
;
;10BASE-T advertising       0001   FFFF   0008    High (AUI)     0        00
;half duplex 
;
;BNC(10BASE-2) advertising  0009   F7FD   0006    low (BNC)      1        00
;half and full duplex on TP
;
;BNC(10BASE-2) advertising  0009   F7BD   0006    low (BNC)      1        00
;full duplex only on TP
;
;BNC(10BASE-2) advertising  0009   F7FD   0006    low (BNC)      0        00
;half duplex only on TP
;
;AUI(10BASE-5) advertising  0009   F7FD   000E    high(AUI)      1        00
;half and full duplex on TP
;
;AUI(10BASE-5) advertising  0009   F7BD   000E    high(AUI)      1        00
;full duplex only on TP
;
;AUI(10BASE-5) advertising  0009   F7FD   000E    high(AUI)      0        00
;half duplex only on TP

TWINET2_CSR13_ASE_AND_TP	equ	1
TWINET2_CSR14_ASE_AND_TP	equ	0FF3Fh 	
TWINET2_CSR15_ASE_AND_TP	equ	8

TWINET2_CSR13_ASE_AND_TP_FD	equ	1
TWINET2_CSR14_ASE_AND_TP_FD	equ	0FF3Dh 	
TWINET2_CSR15_ASE_AND_TP_FD	equ	8

TWINET2_CSR13_ASE_AND_BNC	equ	9
TWINET2_CSR14_ASE_AND_BNC	equ	0F73Dh 	
TWINET2_CSR15_ASE_AND_BNC	equ	6

TWINET2_CSR13_ASE_AND_AUI	equ	9
TWINET2_CSR14_ASE_AND_AUI	equ	0F73Dh 	;No media advertisement bits
TWINET2_CSR15_ASE_AND_AUI	equ	0Eh

;Twinet2 CSR14 Nway addendum bits
;--------------------------------
TWINET2_CSR14_NWAY_TP		equ	   40h
TWINET2_CSR14_NWAY_TX           equ	10000h
TWINET2_CSR14_NWAY_TXFD         equ     20000h
TWINET2_CSR14_NWAY_T4           equ     40000h
TWINET2_CSR14_ANE		equ	   80h
TWINET2_CSR14_TAS		equ	 8000h

;TWINET2 Media selection defaults
;-------------------------------
TWINET2_CSR13_TP_DEFAULT	   equ	TWINET2_CSR13_ASE_AND_TP
TWINET2_CSR14_TP_DEFAULT	   equ	TWINET2_CSR14_ASE_AND_TP
TWINET2_CSR15_TP_DEFAULT	   equ	TWINET2_CSR15_ASE_AND_TP

TWINET2_CSR13_TP_NLT_DEFAULT	   equ	TWINET_CSR13_TP_NLT_DEFAULT
TWINET2_CSR14_TP_NLT_DEFAULT	   equ	TWINET_CSR14_TP_NLT_DEFAULT
TWINET2_CSR15_TP_NLT_DEFAULT	   equ  TWINET_CSR15_TP_NLT_DEFAULT

TWINET2_CSR13_TPFD_DEFAULT	   equ	TWINET2_CSR13_ASE_AND_TP_FD
TWINET2_CSR14_TPFD_DEFAULT	   equ	TWINET2_CSR14_ASE_AND_TP_FD
TWINET2_CSR15_TPFD_DEFAULT	   equ	TWINET2_CSR15_ASE_AND_TP_FD

TWINET2_CSR13_AUI_DEFAULT 	   equ  TWINET2_CSR13_ASE_AND_AUI
TWINET2_CSR14_AUI_DEFAULT 	   equ  TWINET2_CSR14_ASE_AND_AUI
TWINET2_CSR15_AUI_DEFAULT 	   equ  TWINET2_CSR15_ASE_AND_AUI

TWINET2_CSR13_BNC_DEFAULT 	   equ 	TWINET2_CSR13_ASE_AND_BNC
TWINET2_CSR14_BNC_DEFAULT 	   equ  TWINET2_CSR14_ASE_AND_BNC
TWINET2_CSR15_BNC_DEFAULT 	   equ  TWINET2_CSR15_ASE_AND_BNC



;-------------------------------------
;CFCS definitions (ConfigCFCS values):
;-------------------------------------
ConfigCFCS_IOSpaceAccess	equ	1	;enable IO space access to device registers
ConfigCFCS_BusMaster	equ	4	;master bit ON
ConfigCFCS_DEFAULT      equ 	5       ;No parity check, master, I/O space


;-------------------------------------
;CFLT definitions (ConfigCFLT values):
;-------------------------------------
MIN_CFLT_WE_ACCEPT	equ	050h		;Minimum CFLT value we accept
						;from BIOS in PCI machines. If
						;we get a lower value from BIOS
						;we force this minimum value.
						;Otherwise, we will suffer from
						;underruns and overruns.
MIN_CFLT                equ     01h             ;Minimum value CFLT reg accept
MAX_CFLT                equ     0FFh            ;Max value CFLT reg accept

configCFLT_DEFAULT      equ     MAX_CFLT SHL 8

PCI_CFLT_MASK		equ	0FFFF00FFh

;Line Speed Register (Fictional register used for reading the LineSpeed
;Selected by the user from the eisa configuration file)
;-----------------------------------------------------------------------
UNDEF_LINE_SPEED		equ	0FFh
FASTERNET_DEFAULT_LINE_SPEED	equ	100
TULIP_DEFAULT_LINE_SPEED	equ	10


;******************************************************************************
;		C O N F I G U R A T I O N   R E V I S I O N
;******************************************************************************

;CFRV definitions
;----------------
UNDEF_REV		equ	0FFh

;Equates for TulipRev variable
;-----------------------------
TULIP_CFRV_REV1		equ	0000h ;0000 is Tulip pass 1 Rev no.0

;-------------------------
;Equates for CFRV variable
;-------------------------
CFRV_REV1	equ     0010h
CFRV_REV1_1	equ     0011h
CFRV_REV2	equ	0020h
CFRV_REV2_1	equ	0021h 
CFRV_REV2_2	equ	0022h 

;******************************************************************************
;		C O N F I G U R A T I O N   I D
;******************************************************************************
;CFID definitions
;----------------
UNDEV_DEV	      equ   0FFh
TULIP_CFID_VAL        equ   00021011h ;0002 is Tulip     chip ID, 1011h is DEC ID.
TULIP3_CFID_VAL       equ   00141011h ;0014 is Tulip3    chip ID, 1011h is DEC ID.
FASTERNET_CFID_VAL    equ   00091011h ;0009 is Fasternet chip ID, 1011h is DEC ID.
TWINET_CFID_VAL       equ   00191011h ;0019 is TwiNet    chip ID, 1011h is DEC ID.

;******************************************************************************
;		  D E V I C E    and    R E V I S I O N  
;******************************************************************************
;Equates for device and revision
;-------------------------------
TULIP		      equ	TULIP_CFID_VAL SHR 16	     	;0002 is Tulip chip ID.
TULIP_REV1            equ	(TULIP) SHL 8 + TULIP_CFRV_REV1
TULIP_REV2_2          equ	(TULIP) SHL 8 + CFRV_REV2_2

TULIP3		      equ	TULIP3_CFID_VAL SHR 16	     	;0014 is Tulip chip ID.
TULIP3_REV1           equ	(TULIP3) SHL 8 + CFRV_REV1

FASTERNET	      equ	FASTERNET_CFID_VAL SHR 16       ;0009 is Fasternet chip ID.
FASTERNET_REV1	      equ	(FASTERNET) shl 8 + CFRV_REV1

TWINET	      	      equ	TWINET_CFID_VAL SHR 16          ;0019 is Twinet chip ID.
TWINET_REV1	      equ	(TWINET) shl 8 + CFRV_REV1
TWINET_REV1_1	      equ	(TWINET) shl 8 + CFRV_REV1_1


;CFDA definitions (high word ONLY)
;---------------------------------
CFDA_POWER_MODE_MASK 	equ    0C000h
CFDA_SNOOZE_MODE 	equ	4000h
CFDA_SLEEP_MODE		equ     8000h
CFDA_RUN_MODE		equ     0


