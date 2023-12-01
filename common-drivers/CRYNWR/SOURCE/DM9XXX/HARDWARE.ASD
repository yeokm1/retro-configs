
; This file contains the hardware constants for addressing the UM9100
; chip on PCI platforms.
;

;; DEC
;;PCIID_DM9100_DEVICE_ID	 EQU 00009h
;;PCIID_VENDOR_ID		 EQU 01011h

;; DAVICOM
;;PCIID_DM9100_DEVICE_ID	 EQU 09100h
;;PCIID_VENDOR_ID		 EQU 01060h

PCIID_DM9102_DEVICE_ID		EQU	9102h

PCIID_DM9100_DEVICE_ID	       EQU 09100h
PCIID_VENDOR_ID 	       EQU 01282h

PCIID_DM9009_DEVICE_ID		EQU 09009H

DM9100_CHIP			EQU 0
DM9009_CHIP			EQU 1
DM9102_CHIP			EQU 2
DC21X4_CHIP			EQU 10


; Hardware offsets for PCI based Adapter
;
HW_K_REG_CR0		   EQU 000h
HW_K_REG_CR1		   EQU 008h
HW_K_REG_CR2		   EQU 010h
HW_K_REG_CR3		   EQU 018h
HW_K_REG_CR4		   EQU 020h
HW_K_REG_CR5		   EQU 028h
HW_K_REG_CR6		   EQU 030h
HW_K_REG_CR7		   EQU 038h
HW_K_REG_CR8		   EQU 040h
HW_K_REG_CR9		   EQU 048h
HW_K_REG_CR10		   EQU 050h
HW_K_REG_CR11		   EQU 058h
HW_K_REG_CR12		   EQU 060h
HW_K_REG_CR13		   EQU 068h
HW_K_REG_CR14		   EQU 070h
HW_K_REG_CR15		   EQU 078h

HW_K_REG_PCIID			EQU 00h
HW_K_REG_PCICS		     EQU 04h
HW_K_REG_PCIRV		     EQU 08h
HW_K_REG_PCILT		     EQU 0Ch
HW_K_REG_PCIIO		     EQU 10h
HW_K_REG_PCIINT 	      EQU 3Ch
HW_K_REG_PCIUSR 	      EQU 40h

;
; Bit mask definitions for CSRs
;
CR0_M_RESERVED		       EQU 0FFF80000h
CR0_M_TXAP			EQU 000060000h
CR0_M_DAS		       EQU 000010000h
CR0_M_CA		      EQU 00000C000h
CR0_M_BL		      EQU 000003F00h
CR0_M_RESERVED07		      EQU 000000080h
CR0_M_DGW		       EQU 00000007Ch
CR0_M_BA		      EQU 000000002h
CR0_M_SR		      EQU 000000001h
CR0_V_RESERVED		       EQU 19
CR0_V_TXAP			EQU 17
CR0_V_DAS		       EQU 16
CR0_V_CA		      EQU 14
CR0_V_BL		      EQU 8
CR0_V_RESERVED07		      EQU 7
CR0_V_DGW		       EQU 2
CR0_V_BA		      EQU 1
CR0_V_SR		      EQU 0

CR0_K_TXAP_NONE 		EQU 0
CR0_K_TXAP_200_USEC		EQU 1
CR0_K_TXAP_800_USEC		EQU 2
CR0_K_TXAP_1600_USEC		EQU 3
CR0_K_TXAP_128_USEC		EQU 4

CR0_K_CA_0LW		      EQU 0
CR0_K_CA_8LW		      EQU 1
CR0_K_CA_16LW		      EQU 2
CR0_K_CA_32LW		      EQU 3

CR0_K_BL_0LW		      EQU 0
CR0_K_BL_1LW		      EQU 1
CR0_K_BL_2LW		      EQU 2
CR0_K_BL_4LW		      EQU 4
CR0_K_BL_8LW		      EQU 8
CR0_K_BL_16LW		      EQU 16
CR0_K_BL_32LW		      EQU 32	  ; currently invalid

CR0_K_DGW_0LW		       EQU 0
CR0_K_DGW_1LW		       EQU 1
CR0_K_DGW_2LW		       EQU 2
CR0_K_DGW_3LW		       EQU 3
CR0_K_DGW_4LW		       EQU 4

CR1_M_RESERVED		       EQU 0FFFFFFFEh
CR1_M_TPD		       EQU 000000001h
CR1_V_RESERVED		       EQU 1
CR1_V_TPD		       EQU 0

CR2_M_RESERVED		       EQU 0FFFFFFFEh
CR2_M_RPD		       EQU 000000001h
CR2_V_RESERVED		       EQU 1
CR2_V_RPD		       EQU 0

CR5_M_RESERVED			EQU 0FC000000h
CR5_M_SBEB			EQU 003800000h
CR5_M_TXS			EQU 000700000h
CR5_M_RXS			EQU 0000E0000h
CR5_M_NIS			EQU 000010000h
CR5_M_AIS			EQU 000008000h
CR5_M_RESERVED_2		EQU 000004000h
CR5_M_SBE			EQU 000002000h
CR5_M_GPT			EQU 000000800h
CR5_M_ETI			EQU 000000400h
CR5_M_RXWT			EQU 000000200h
CR5_M_RXPS			EQU 000000100h
CR5_M_RXDU			EQU 000000080h
CR5_M_RXCI			EQU 000000040h
CR5_M_TXFU			EQU 000000020h
CR5_M_RESERVED_3		EQU 000000010h
CR5_M_TXJT			EQU 000000008h
CR5_M_TXDU			EQU 000000004h
CR5_M_TXPS			EQU 000000002h
CR5_M_TXCI			EQU 000000001h
CR5_V_RESERVED			EQU 26
CR5_V_SBEB			EQU 23
CR5_V_TXS			EQU 20
CR5_V_RXS			EQU 17
CR5_V_NIS			EQU 16
CR5_V_AIS			EQU 15
CR5_V_RESERVED_2		EQU 14
CR5_V_SBE			EQU 13
CR5_V_GPT			EQU 11
CR5_V_ETI			EQU 10
CR5_V_RXWT			EQU 9
CR5_V_RXPS			EQU 8
CR5_V_RXDU			EQU 7
CR5_V_RXCI			EQU 6
CR5_V_TXFU			EQU 5
CR5_V_RESERVED_3		EQU 4
CR5_V_TXJT			EQU 3
CR5_V_TXDU			EQU 2
CR5_V_TXPS			EQU 1
CR5_V_TXCI			EQU 0

CR5_K_SBEB_PARITY_ERROR 	EQU 0
CR5_K_SBEB_MASTER_ABORT 	EQU 1
CR5_K_SBEB_TARGET_ABORT 	EQU 2

CR5_K_TXS_STOPPED		EQU 0
CR5_K_TXS_RUN_DESC_ACCESS	EQU 1
CR5_K_TXS_RUN_SETUP_MOVE	EQU 2
CR5_K_TXS_RUN_MOVE_DATA 	EQU 3
CR5_K_TXS_RUN_WRITE_OWNER	EQU 4
CR5_K_TXS_RUN_WAIT		EQU 5
CR5_K_TXS_RUN_WRITE_STATUS	EQU 6
CR5_K_TXS_SUSPEND		EQU 7

CR5_K_RXS_STOPPED		EQU 0
CR5_K_RXS_RUN_DESC_ACCESS	EQU 1
CR5_K_RXS_RUN_WAIT		EQU 2
CR5_K_RXS_RUN_MOVE_DATA 	EQU 3
CR5_K_RXS_RUN_WRITE_OWNER	EQU 4
CR5_K_RXS_RUN_WRITE_STATUS	EQU 5
CR5_K_RXS_SUSPEND		EQU 6
CR5_K_RXS_PURGE 		EQU 7

CR6_M_DM9009_ALWAYS		EQU 002000000h	;;DM9009 reserved bits
CR6_M_RESERVED1_1		EQU 080000000h	;;Always 1
CR6_M_RXA			EQU 040000000h	;;Reveive All(30)
CR6_M_RESERVED2_1		EQU 020000000h
CR6_M_RESERVED3_0		EQU 038000000h	;;Always 0
CR6_M_RESERVED4_1		EQU 004000000h
CR6_M_SCM			EQU 001000000h	;;Scrambler Mode(24)
CR6_M_MSF			EQU 000800000h	;;MII Symbol Function(23)
CR6_M_TXTM			EQU 000400000h	;;Transmit Threshold Mode(22)
CR6_M_SFT			EQU 000200000h	;;Store and Forward Transmission(21)
CR6_M_STT			EQU 000100000h	;;Shortest Transmit Threshold(20)
CR6_M_HBD			EQU 000080000h	;;HartBit Disable(19)
CR6_M_MSPS			EQU 000040000h	;;MII/SRL Port Select(18)
CR6_M_RESERVED5_0		EQU 000020000h
CR6_M_RESERVED6_0		EQU 000010000h
CR6_M_TSB			EQU 00000C000h	;;Threshold Setup Bits(15:14)
CR6_M_TXSC			EQU 000002000h	;;Transmit Start/stop Command(13)
CR6_M_FCM			EQU 000001000h	;;Force Collision Mode(12)
CR6_M_LBM			EQU 000000C00h	;;LookBack Mode(11:10)
CR6_M_FDM			EQU 000000200h	;;Full_Duplex Mode(9)
CR6_M_ISRW			EQU 000000100h	;;Inhibit Simultaneous Read/Write
CR6_M_PAM			EQU 000000080h	;;Pass All Multicast(7)
CR6_M_PM			EQU 000000040h	;;Promiscuous Mode(6)
CR6_M_RESERVED8_0		EQU 000000020h
CR6_M_IAFM			EQU 000000010h	;;Inverse Address Mode(4)
CR6_M_PBF			EQU 000000008h	;;Pass Bad Frame(3)
CR6_M_HOFM			EQU 000000004h	;;Hash-Only Filtering Mode(2)
CR6_M_RXSC			EQU 000000002h	;;Received Start/stop Command(1)
CR6_M_HPFM			EQU 000000001h	;;Hash/Perfect Filtering Mode(0)
CR6_V_SCM			EQU 24
CR6_V_MSF			EQU 23
CR6_V_TXTM			EQU 22
CR6_V_SFT			EQU 21
CR6_V_STT			EQU 20
CR6_V_HBD			EQU 19
CR6_V_MSPS			EQU 18
CR6_V_TSB			EQU 14
CR6_V_TXSC			EQU 13
CR6_V_FCM			EQU 12
CR6_V_LBM			EQU 10
CR6_V_FDM			EQU 9
CR6_V_PAM			EQU 7
CR6_V_PM			EQU 6
CR6_V_IAFM			EQU 4
CR6_V_PBF			EQU 3
CR6_V_HOFM			EQU 2
CR6_V_RXSC			EQU 1
CR6_V_HPFM			EQU 0

CR6_K_10MB_TSB_72_BYTES 	EQU 0
CR6_K_10MB_TSB_96_BYTES 	EQU 1
CR6_K_10MB_TSB_128_BYTES	EQU 2
CR6_K_10MB_TSB_160_BYTES	EQU 3

CR6_K_100MB_TSB_128_BYTES	EQU 0
CR6_K_100MB_TSB_256_BYTES	EQU 1
CR6_K_100MB_TSB_512_BYTES	EQU 2
CR6_K_100MB_TSB_1024_BYTES	EQU 3

CR6_K_100MB_INIT	       EQU (CR6_M_HBD) OR (CR6_M_SFT)

; Define the transmit FIFO threshold that we will use, and the corresponding
; minimum packet size for which we may need software CRC calculation.
;
CR6_K_10MB_TSB_DEFAULT		EQU	CR6_K_10MB_TSB_72_BYTES ; use max threshold
;;--- DM9009's CR6 default value
;;CR6_DM9009_INIT		  EQU	  CR6_M_DM9009_ALWAYS OR CR6_M_RXA OR CR6_M_HBD OR CR6_M_PAM OR CR6_K_10MB_TSB_128_BYTES
CR6_DM9009_INIT 		EQU	CR6_M_DM9009_ALWAYS OR CR6_M_HBD OR CR6_M_PAM OR CR6_K_10MB_TSB_128_BYTES

SW_CRC_MIN			EQU 144 		; CRC packet size min

CR7_M_RESERVED1 		EQU 0FFFE0000h
CR7_M_NISE			EQU 000010000h
CR7_M_AISE			EQU 000008000h
CR7_M_RESERVED2 		EQU 000004000h
CR7_M_SBEE			EQU 000002000h
CR7_M_RESERVED3 		EQU 000001000h
CR7_M_GPTE			EQU 000000800h
CR7_M_ETIE			EQU 000000400h
CR7_M_RXWTE			EQU 000000200h
CR7_M_RXPSE			EQU 000000100h
CR7_M_RXDUE			EQU 000000080h
CR7_M_RXCIE			EQU 000000040h
CR7_M_TXFUE			EQU 000000020h	;;Transmit FIFO Underflow Enable(5)
CR7_M_RESERVED4 		EQU 000000010h
CR7_M_TXJTE			EQU 000000008h
CR7_M_TXDUE			EQU 000000004h
CR7_M_TXPSE			EQU 000000002h
CR7_M_TXCIE			EQU 000000001h
CR7_V_RESERVED1 		EQU 17
CR7_V_NISE			EQU 16
CR7_V_AISE			EQU 15
CR7_V_RESERVED2 		EQU 14
CR7_V_SBEE			EQU 13
CR7_V_GPTE			EQU 11
CR7_V_ETIE			EQU 10
CR7_V_RXWTE			EQU 9
CR7_V_RXPSE			EQU 8
CR7_V_RXDUE			EQU 7
CR7_V_RXCIE			EQU 6
CR7_V_TXFUE			EQU 5
CR7_V_RESERVED4 		EQU 4
CR7_V_TXJTE			EQU 3
CR7_V_TXDUE			EQU 2
CR7_V_TXPSE			EQU 1
CR7_V_TXCIE			EQU 0

CR7_K_DEFAULT_OFF	       EQU 0
CR7_K_DEFAULT_ON	       EQU CR7_M_NISE OR CR7_M_AISE OR CR7_M_RXCIE OR CR7_M_TXCIE


CR8_M_RESERVED		       EQU 0FFFE0000h
CR8_M_MISSED_FRAME_OVERFLOW    EQU 000010000h
CR8_M_MIDDED_FRAME_COUNT       EQU 00000FFFFh
CR8_V_RESERVED		       EQU 17
CR8_V_MISSED_FRAME_OVERFLOW    EQU 16
CR8_V_MIDDED_FRAME_COUNT       EQU 0

;;CR9_M_DN			 EQU 080000000h
;;CR9_M_RESERVED		 EQU 07FFFFF00h
;;CR9_M_DT			 EQU 0000000FFh
;;CR9_V_DN			 EQU 31
;;CR9_V_RESERVED		 EQU 8
;;CR9_V_DT			 EQU 0

CR11_M_RESERVED 	       EQU 0FFFF0000h
CR11_M_FDX_AUTO_CONFIG	       EQU 00000FFFFh
CR11_V_RESERVED 	       EQU 16
CR11_V_FDX_AUTO_CONFIG	       EQU 0

; CR12 constants
CR12_M_RESERVED 	EQU 0FFFFFE00h
CR12_M_GPC		EQU 000000100h
CR12_M_MD		EQU 0000000FFh
CR12_M_LNK		EQU 000000004h
CR12_M_NCR		EQU 000000002h

CR12_V_RESERVED 	EQU 9
CR12_V_GPC		EQU 8
CR12_V_MD		EQU 0

CR12_K_INIT_VAL 	EQU 00000013Fh
CR12_K_ONBOARD_LOOPBACK EQU 000000008h
CR12_K_INBOARD_LOOPBACK EQU 00000000Ah
CR12_K_NORMAL_MODE	EQU 00000000Bh

CR13_M_RESERVED 	       EQU 0FFFF0000h
CR13_M_OE57		       EQU 000008000h
CR13_M_OE24		       EQU 000004000h
CR13_M_OE13		       EQU 000002000h
CR13_M_IE		       EQU 000001000h
CR13_M_SEL		       EQU 000000F00h
CR13_M_ASE		       EQU 000000080h
CR13_M_SIM		       EQU 000000040h
CR13_M_ENI		       EQU 000000020h
CR13_M_EDP		       EQU 000000010h
CR13_M_AUI		       EQU 000000008h
CR13_M_CAC		       EQU 000000004h
CR13_M_PS		       EQU 000000002h
CR13_M_SRL		       EQU 000000001h
CR13_V_RESERVED 	       EQU 16
CR13_V_OE57		       EQU 15
CR13_V_OE24		       EQU 14
CR13_V_OE13		       EQU 13
CR13_V_IE		       EQU 12
CR13_V_SEL		       EQU 8
CR13_V_ASE		       EQU 7
CR13_V_SIM		       EQU 6
CR13_V_ENI		       EQU 5
CR13_V_EDP		       EQU 4
CR13_V_AUI		       EQU 3
CR13_V_CAC		       EQU 2
CR13_V_PS		       EQU 1
CR13_V_SRL		       EQU 0

; values associated with 93LC46B Serial ROM
;============================================
SROM_93LC46B_LEN	EQU	64  ; In words. That is 128 Bytes.


; SROM version and field codes
;-----------------------------
UM9100_SROM_V0_1	EQU	01h
UM9100_SROM_V0_3	EQU	03h
SROM_FORMAT_OFF 	EQU	12h
SROM_ADAPTER_COUNT_OFF	EQU	13h
SROM_IEEE_OFF		EQU	14h
SROM_ADAPTER0_OFF	EQU	1Ah
SROM_CHECKSUM_OFF	EQU	7Eh
FNET_MEDIA_BLK_SIZE	EQU	03h
FNET_COMM_MASK		EQU	71H
FNET_COMM_OFF		EQU	12H

; 90100 SROM definitions (SROM_93LC46B)
;----------------------------------------
SROM_93LC46B_MAX_CYCLES 	EQU 25
SROM_93LC46B_LAST_ADDRESS	EQU 03Fh
SROM_93LC46B_LAST_ADDRESS_BIT	EQU 6	  ;Special assembler implementation
SROM_M_Output_Data		EQU 8

SROM_CR9_READ  EQU 04000h
SROM_CR9_WRITE EQU 02000h
SROM_SEL_SROM	EQU 0800h
SROM_DATA_1	EQU 04h
SROM_DATA_0	EQU 0
SROM_CLK	EQU 02h
SROM_CS 	EQU 01h

; Define a structure that contains the values to be written to the registers to
; configure the SIA for a particular mode.
;
SIA_CONFIG	STRUCT
	CR13   DWORD   ?
	CR14   DWORD   ?
	CR15   DWORD   ?
SIA_CONFIG	ENDS

SIA_CONFIG_PTR	TYPEDEF PTR SIA_CONFIG

SIA_Config_Autodetect	equ	5h	    ; flag to do autodetect speed & Half-Duplex
SIA_Config_AutoFD	equ	4h	    ; flag to do autodetect speed & Full-Duplex
TPFD_SIAConfig		equ	0h
TP_SIAConfig		equ	1h
BNC_SIAConfig		equ	2h
AUI_SIAConfig		equ	3h

PCIID_M_DEVICE_ID		 EQU 0FFFF0000h
PCIID_M_VENDOR_IO		 EQU 00000FFFFh
PCIID_V_DEVICE_ID		 EQU 16
PCIID_V_VENDOR_IO		 EQU 0

PCICS_M_PARITY_ERROR		 EQU 080000000h
PCICS_M_SYSTEM_ERROR		 EQU 040000000h
PCICS_M_MASTER_ABORT		 EQU 020000000h
PCICS_M_TARGET_ABORT		 EQU 010000000h
PCICS_M_RESERVED		 EQU 008000000h
PCICS_M_DEVSEL			 EQU 006000000h
PCICS_M_DATA_PARITY		 EQU 001000000h
PCICS_M_BACK_TO_BACK		 EQU 000800000h
PCICS_M_RESERVED_2		 EQU 0007FFC00h
PCICS_M_SERR_ENABLE		 EQU 000000200h
PCICS_M_RESERVED_3		 EQU 000000180h
PCICS_M_PARITY_ERROR_DETECTED	 EQU 000000040h
PCICS_M_RESERVED_4		 EQU 000000038h
PCICS_M_BUS_MASTER		 EQU 000000004h
PCICS_M_MEMORY_ACCESS		 EQU 000000002h
PCICS_M_IO_ACCESS		 EQU 000000001h
PCICS_V_PARITY_ERROR		 EQU 31
PCICS_V_SYSTEM_ERROR		 EQU 30
PCICS_V_MASTER_ABORT		 EQU 29
PCICS_V_TARGET_ABORT		 EQU 28
PCICS_V_RESERVED		 EQU 27
PCICS_V_DEVSEL			 EQU 25
PCICS_V_DATA_PARITY		 EQU 24
PCICS_V_BACK_TO_BACK		 EQU 23
PCICS_V_RESERVED_2		 EQU 10
PCICS_V_SERR_ENABLE		 EQU 9
PCICS_V_RESERVED_3		 EQU 7
PCICS_V_PARITY_ERROR_DETECTED	 EQU 6
PCICS_V_RESERVED_4		 EQU 3
PCICS_V_BUS_MASTER		 EQU 2
PCICS_V_MEMORY_ACCESS		 EQU 1
PCICS_V_IO_ACCESS		 EQU 0

PCIRV_M_BASE_CLASS		 EQU 0FF000000h
PCIRV_M_SUB_CLASS		 EQU 000FF0000h
PCIRV_M_RESERVED		 EQU 00000FF00h
PCIRV_M_Revision_Major_Number	 EQU 0000000F0h
PCIRV_M_Revision_Minor_Number	 EQU 00000000Fh
PCIRV_V_BASE_CLASS		 EQU 24
PCIRV_V_SUB_CLASS		 EQU 16
PCIRV_V_RESERVED		 EQU 8
PCIRV_V_Revision_Major_Number	 EQU 4
PCIRV_V_Revision_Minor_Number	 EQU 0

PCILT_M_RESERVED		 EQU 0FFFF0000h
PCILT_M_LATENCY_TIMER		 EQU 00000FF00h
PCILT_M_RESERVED_2		 EQU 0000000FFh
PCILT_V_RESERVED		 EQU 16
PCILT_V_LATENCY_TIMER		 EQU 8
PCILT_V_RESERVED_2		 EQU 0

PCIIO_M_PCI_IO_BASE_ADDRESS	 EQU 0FFFFFF80h
PCIIO_M_RESERVED		 EQU 00000007Eh
PCIIO_M_MEMORY_IO		 EQU 000000001h
PCIIO_V_PCI_IO_BASE_ADDRESS	 EQU 7
PCIIO_V_RESERVED		 EQU 1
PCIIO_V_MEMORY_IO		 EQU 0

PCIMEM_M_PCI_MEM_BASE_ADDRESS	  EQU 0FFFFFF80h
PCIMEM_M_RESERVED		  EQU 00000007Eh
PCIMEM_M_MEMORY_SPACE		  EQU 000000001h
PCIMEM_V_PCI_MEM_BASE_ADDRESS	  EQU 7
PCIMEM_V_RESERVED		  EQU 1
PCIMEM_V_MEMORY_SPACE		  EQU 0

PCIINT_M_RESERVED		  EQU 0FFFF0000h
PCIINT_M_INTERRUPT_PIN		  EQU 00000FF00h
PCIINT_M_INTERRUPT_LINE 	  EQU 0000000FFh
PCIINT_V_RESERVED		  EQU 16
PCIINT_V_INTERRUPT_PIN		  EQU 8
PCIINT_V_INTERRUPT_LINE 	  EQU 0

PCIUSR_M_RESERVED		  EQU 0FFFF0000h
PCIUSR_M_USER_SPECIAL_USE	  EQU 00000FF00h
PCIUSR_M_RESERVED_2		  EQU 0000000FFh
PCIUSR_V_RESERVED		  EQU 16
PCIUSR_V_USER_SPECIAL_USE	  EQU 8
PCIUSR_V_RESERVED_2		  EQU 0

HW_K_SETUP_FRAME_SIZE		EQU 192

;
;  Descriptor definitions
;
;     Transmit Descriptor
;     -------------------
;
; The DM9100 Transmit Descriptor is described in the DM9100 specification.
; The names of the fields, TDES0-3 are taken straight from the spec.
; This structure, and the associated constants, define the format of the
; transmit descriptor used by the DM9100. A transmit descriptor must
; be allocated a physically contiguous, longword aligned region of memory. The
; transmit buffers to which the descriptors point may be of arbitrary alignment
; and size.
;
; The p_XmtBuffer and p_XmtNext fields of the descriptor are unique to this
; driver implementation. They are virtual NEAR pointers to the transmit buffer
; and the next descriptor respectively. The descriptor skip length in CR0 is
; set to 1 longword in order to skip this extra longword at the end of each
; descriptor.
;

XMT_DESCRIPTOR	STRUC
   TDES0       DD 0
   TDES1       DD 0
   TDES2       DD 0
   TDES3       DD 0
   p_XmtBuffer DW 0
   p_XmtNext   DW 0
   p_Dummy1    DD 0
   p_Dummy2    DD 0
   p_Dummy3    DD 0
XMT_DESCRIPTOR	ENDS

TDES0_M_OWN		EQU 080000000h	; OWN Bit 1=MAC 0=Host
TDES0_M_ES		EQU 000008000h	; Error Summary (UF|EC|LC|NC|LO|TO|LF)
TDES0_M_TXJT		EQU 000004000h	; Transmit Jabber Expired
TDES0_M_LOC		EQU 000000800h	; Loss of Carrier
TDES0_M_NC		EQU 000000400h	; No Carrier
TDES0_M_LC		EQU 000000200h	; Late Collision
TDES0_M_EC		EQU 000000100h	; Excessive Collisions
TDES0_M_HF		EQU 000000080h	; Heartbeat Fail
TDES0_M_CC		EQU 000000078h	; Collision Count
TDES0_M_LF		EQU 000000004h	; Link Fail
TDES0_M_FUE		EQU 000000002h	; FIFO Underflow Error
TDES0_M_DE		EQU 000000001h	; Deferred

TDES0_V_OWN		EQU 31
TDES0_V_ES		EQU 15
TDES0_V_TXJT		EQU 14
TDES0_V_LOC		EQU 11
TDES0_V_NC		EQU 10
TDES0_V_LC		EQU 9
TDES0_V_EC		EQU 8
TDES0_V_HF		EQU 7
TDES0_V_CC		EQU 3
TDES0_V_LF		EQU 2
TDES0_V_FUE		EQU 1
TDES0_V_DE		EQU 0

TDES1_M_CI		EQU 080000000h	; Completion Interrupt
TDES1_M_ED		EQU 040000000h	; End Segment
TDES1_M_BD		EQU 020000000h	; Begin Segment
TDES1_M_FMB1		EQU 010000000h	; Filtering Mode Bit 1
TDES1_M_SETF		EQU 008000000h	; Setup Frame
TDES1_M_CAD		EQU 004000000h	; CRC Append Disable
TDES1_M_EOR		EQU 002000000h	; End of Ring
TDES1_M_CE		EQU 001000000h	; Chain Enable
TDES1_M_PD		EQU 000800000h	; Padding Disable
TDES1_M_FMB0		EQU 000400000h	; Filtering Mode Bit 0
TDES1_M_BL2		EQU 0003FF800h	; Size in bytes of Buffer 2
TDES1_M_BL1		EQU 0000007FFh	; Size in bytes of Buffer 1

;;-+, 980415, Hu-Tiong
;;TDES1_M_DUMMY 	  EQU TDES1_M_EOR AND (not (TDES1_M_BL2 OR TDES1_M_BL1 OR TDES1_M_ED OR TDES1_M_BD))
TDES1_M_DUMMY		EQU TDES1_M_CE AND (not (TDES1_M_BL2 OR TDES1_M_BL1 OR TDES1_M_ED OR TDES1_M_BD))
;;-+

TDES1_V_CI		EQU 31
TDES1_V_ED		EQU 30
TDES1_V_BD		EQU 29
TDES1_V_FMB1		EQU 28
TDES1_V_SETF		EQU 27
TDES1_V_CAD		EQU 26
TDES1_V_EOR		EQU 25
TDES1_V_CE		EQU 24
TDES1_V_PD		EQU 23
TDES1_V_FMB0		EQU 22
TDES1_V_BL2		EQU 11
TDES1_V_BL1		EQU 0

XMT_BUFFER_SIZE 	EQU 1520

;
;     Receive Descriptor
;     ------------------
;
;
; The DM9100 Receive Descriptor is described in the DM9100 specification.
; The names of the fields, RDES0-3 are takes straight from the spec.
; This structure, and the associated constants, define the format of the
; receive descriptor used by the DM9100. A receive descriptor must be
; allocated a physically contiguous, longword aligned region of memory. The
; receive buffers to which the descriptors point must also be physically
; contiguous and longword alignedand a MOD 4 length.
;
; The p_RcvBuffer and p_RcvNext fields of the descriptor are unique to this driver
; implementation. They are virtual NEAR pointers to the receive buffer and
; the next descriptor respectively. The descriptor skip length in CR0 is
; set to 1 longword in order to skip this extra longword at the end of each
; descriptor.
;

RCV_DESCRIPTOR	STRUC
   RDES0	 DD 0
   RDES1	 DD 0
   RDES2	 DD 0
   RDES3	 DD 0
   p_RcvBuffer	 DW 0
   p_RcvNext	 DW 0
   p_Dummy1	 DD 0
   p_Dummy2	 DD 0
   p_Dummy3	 DD 0
RCV_DESCRIPTOR	ENDS

RDES0_M_OWN		EQU 080000000h	; OWN bit 0=HOST 1=MAC
RDES0_M_LENGTH		EQU 07FFF0000h	; Length of frame in bytes including CRC
RDES0_M_ES		EQU 000008000h	; Error Summary (OF|CE|CS|TL|LE|RF)
RDES0_M_DUE		EQU 000004000h	;;Descriptor Unavailable Error
					; Length Error (rcv buffer too small)
RDES0_M_LBOM		EQU 000003000h	; Data Type
RDES0_M_RF		EQU 000000800h	; Runt Frame
RDES0_M_MF		EQU 000000400h	; MCast frame
RDES0_M_BD		EQU 000000200h	; Begin Descriptor
RDES0_M_ED		EQU 000000100h	; End Descriptor
RDES0_M_EFL		EQU 000000080h	; Excessive Frame Length (>1518 bytes)
RDES0_M_LCS		EQU 000000040h	; Late Collision Seen
RDES0_M_FT		EQU 000000020h	; Frame Type 1=DIX 0=802.3
RDES0_M_RXWT		EQU 000000010h	; Receive Watchdog Expired (frame >2K)
RDES0_M_PLE		EQU 000000008h	; Physical Layer Error
RDES0_M_AE		EQU 000000004h	; Alignment Error
RDES0_M_CE		EQU 000000002h	; CRC Error
RDES0_M_FOE		EQU 000000001h	; FIFO Overflow Error

RDES0_V_OWN		EQU 31
RDES0_V_LENGTH		EQU 16
RDES0_V_ES		EQU 15
RDES0_V_DUE		EQU 14
RDES0_V_LBOM		EQU 12
RDES0_V_RF		EQU 11
RDES0_V_MF		EQU 10
RDES0_V_BD		EQU 9
RDES0_V_ED		EQU 8
RDES0_V_EFL		EQU 7
RDES0_V_LCS		EQU 6
RDES0_V_FT		EQU 5
RDES0_V_RXWT		EQU 4
RDES0_V_AE		EQU 2
RDES0_V_CE		EQU 1
RDES0_V_FOE		EQU 0

RDES0_K_FT_DIX		EQU 1
RDES0_K_FT_802		EQU 0

RDES0_K_LBOM_NORMAL	EQU 0
RDES0_K_LBOM_INTERNAL	EQU 1
RDES0_K_LBOM_EXTERNAL	EQU 2
RDES0_K_LBOM_RESERVED	EQU 3

RDES1_M_EOR		EQU 002000000h	; End Of Ring
RDES1_M_CE		EQU 001000000h	; Chain Enable
RDES1_M_BL2		EQU 0003FF800h	; Size in bytes of buffer 2 (MOD 4)
RDES1_M_BL1		EQU 0000007FFh	; Size in bytes of buffer 1 (MOD 4)

RDES1_V_EOR		EQU 25
RDES1_V_CE		EQU 24
RDES1_V_BL2		EQU 11
RDES1_V_BL1		EQU 0

RCV_BUFFER_SIZE 	EQU 620h   ; Smallest MOD 4 length that can accommodate MTU
;;RCV_BUFFER_SIZE	  EQU 1520   ; Smallest MOD 4 length that can accommodate MTU

;; SROM contents structure
SROM_NS_Contents	STRUC
  NS_SS_Vendor_ID    DW      0		     ; Sub-System Vendor ID
  NS_SS_ID	     DW      0		     ; Sub-System ID
  NS_Cardbus_Low     DW      0		     ; Cardbus CIS Pointer Low
  NS_Cardbus_High    DW      0		     ; Cardbus CIS Pointer High
  NS_ID_Reserved1    DB      8 DUP (0)	     ; Reserved
  NS_ID_Bk_Crc	     DB      0		     ; ID Block CRC
  NS_ID_Reserved2    DB      0		     ; Reserved
  NS_SROM_version    DB      03h	     ; SROM Format Version
  NS_Controller_cnt  DB      01h	     ; Controller Count
  NS_Ether_Addr      DB      6 DUP (0)	     ; IEEE Network Address
  NS_Dev_Number      DB      0		     ; Controller Device Number
  NS_IL_Offset	     DW      1Eh	     ; Controller Info Leaf Offset
  NS_Inf_Reserved3   DB      0		     ; Reserved
;; -- Info Leaf
  NS_Sel_Conn_type   DW      0		     ; Selected Connection Type
  NS_Gen_Pur_Ctrl    DB      80h	     ; General Purpose Control
  NS_Blk_cnt	     DB      6		     ; Block Count
;; -- Info Leaf Block
  NS_F1_Length_0     DB      8Eh	     ; Format 1 length bytes
  NS_Type1	     DB      1		     ; Extended format type 1
  NS_PHY_Number      DB      1		     ; PHY Address
  NS_GPR_Seq_Len     DB      0		     ; GPR sequence Length
  NS_RST_Seq_Len     DB      2		     ; Reset Sequence Length
  NS_RST_Seq_0	     DB      80h	     ; Reset Sequence 0
  NS_RST_Seq_1	     DB      00h	     ; Reset Sequence 1
  NS_Media_Cap	     DW      7800h	     ; Media Capabilities
  NS_Nway_Adv	     DW      01E0h	     ; Nway Advertisemnet
  NS_FDX_Map	     DW      5000h	     ; Full Duplex Bits
  NS_TTM_Map	     DW      1800h	     ; Tx Theshold Mode Bits
;; --
  NS_F1_Length_1     DB      85h	     ; Format 1 length
  NS_Type2	     DB      80h	     ; New Delay Type
  NS_Delay_Seq_0     DW      2000h	     ;
  NS_Delay_seq_1     DW      4000h	     ;
;; --
  NS_F1_Length_2     DB      85h
  NS_Type3	     DB      00h
  NS_10BaseT_Code    DB      00h
  NS_GprData10	     DB      00h
  NS_Comm10	     DW      001Dh
;; --
  NS_F1_Length_3     DB      85h
  NS_Type4	     DB      00h
  NS_100BaseT_Code   DB      01h
  NS_GprData100      DB      00h
  NS_Comm100	     DW      008Dh
;; --
  NS_F1_Length_4     DB      85h
  NS_Type5	     DB      00h
  NS_10BaseFD_Code   DB      04h
  NS_GprData10FD     DB      00h
  NS_Comm10FD	    DW	    001Dh
;; --
  NS_F1_Length_5     DB      85h
  NS_Type6	     DB      00h
  NS_100BaseFD	     DB      05h
  NS_GprData100FD    DB      00h
  NS_Comm100FD	     DW      008Dh
  NS_Reserved4	     DB      49 DUP (0)
  NS_SROM_CRC	     DB      2 DUP (0)
SROM_NS_Contents	ENDS

SROM_MotolorA_Contents	      STRUC
  MA_SS_Vendor_ID    DW      0		     ; Sub-System Vendor ID
  MA_SS_ID	     DW      0		     ; Sub-System ID
  MA_Cardbus_Low     DW      0		     ; Cardbus CIS Pointer Low
  MA_Cardbus_High    DW      0		     ; Cardbus CIS Pointer High
  MA_ID_Reserved1    DB      8 DUP (0)	     ; Reserved
  MA_ID_Bk_Crc	     DB      0		     ; ID Block CRC
  MA_ID_Reserved2    DB      0		     ; Reserved
  MA_SROM_version    DB      03h	     ; SROM Format Version
  MA_Controller_cnt  DB      01h	     ; Controller Count
  MA_Ether_Addr      DB      6 DUP (0)	     ; IEEE Network Address
  MA_Dev_Number      DB      0		     ; Controller Device Number
  MA_IL_Offset	     DW      1Eh	     ; Controller Info Leaf Offset
  MA_Inf_Reserved3   DB      0		     ; Reserved
;; -- Info Leaf
  MA_Sel_Conn_type   DW      0		     ; Selected Connection Type
  MA_Gen_Pur_Ctrl    DB      80h	     ; General Purpose Control
  MA_Blk_cnt	     DB      6		     ; Block Count
;; -- Info Leaf Block
  MA_F1_Length_2     DB      85h
  MA_Type3	     DB      00h
  MA_10BaseT_Code    DB      00h
  MA_GprData10	     DB      00h
  MA_Comm10	     DW      001Dh
;; --
  MA_F1_Length_3     DB      85h
  MA_Type4	     DB      00h
  MA_100BaseT_Code   DB      01h
  MA_GprData100      DB      00h
  MA_Comm100	     DW      008Dh
;; --
  MA_F1_Length_4     DB      85h
  MA_Type5	     DB      00h
  MA_10BaseFD_Code   DB      04h
  MA_GprData10FD     DB      00h
  MA_Comm10FD	    DW	    001Dh
;; --
  MA_F1_Length_5     DB      85h
  MA_Type6	     DB      00h
  MA_100BaseFD	     DB      05h
  MA_GprData100FD    DB      00h
  MA_Comm100FD	     DW      008Dh
  MA_Reserved4	     DB      49 DUP (0)
  MA_SROM_CRC	     DB      2 DUP (0)
SROM_MotolorA_Contents	      ENDS
