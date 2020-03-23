;--------------------------------------------------------------------------
; PLX PCI (9036) Register Definitions
; Refer To The PCI Specification For Detailed Explanations
;--------------------------------------------------------------------------
;- Register Offsets
PLXP_VENDOR_ID_REGISTER  equ     00h          ;- PCI Vendor ID Register
PLXP_DEVICE_ID_REGISTER  equ     02h          ;- PCI Device ID Register
PLXP_COMMAND_REGISTER    equ     04h          ;- PCI Command Register
PLXP_STATUS_REGISTER     equ     06h          ;- PCI Status Register
PLXP_REV_ID_REGISTER     equ     08h          ;- PCI Revision ID Register
PLXP_CLASS_CODE_REGISTER equ     09h          ;- PCI Class Code Register
PLXP_CACHE_LINE_REGISTER equ     0Ch          ;- PCI Cache Line Register
PLXP_LATENCY_TIMER       equ     0Dh          ;- PCI Latency Timer Register
PLXP_HEADER_TYPE         equ     0Eh          ;- PCI Header Type Register
PLXP_BIST_REGISTER       equ     0Fh          ;- PCI Built-In SelfTest Register
PLXP_BAR_0_REGISTER      equ     10h          ;- PCI Base Address Register 0
PLXP_BAR_1_REGISTER      equ     14h          ;- PCI Base Address Register 1
PLXP_BAR_2_REGISTER      equ     18h          ;- PCI Base Address Register 2
PLXP_BAR_3_REGISTER      equ     1Ch          ;- PCI Base Address Register 3
PLXP_BAR_4_REGISTER      equ     20h          ;- PCI Base Address Register 4
PLXP_BAR_5_REGISTER      equ     24h          ;- PCI Base Address Register 5
PLXP_EXPANSION_ROM       equ     30h          ;- PCI Expansion ROM Base Register
PLXP_INTERRUPT_LINE      equ     3Ch          ;- PCI Interrupt Line Register
PLXP_INTERRUPT_PIN       equ     3Dh          ;- PCI Interrupt Pin Register
PLXP_MIN_GNT_REGISTER    equ     3Eh          ;- PCI Min-Gnt Register
PLXP_MAX_LAT_REGISTER    equ     3Fh          ;- PCI Max_Lat Register
PLXP_NODE_ADDR_REGISTER  equ     40h          ;- PCI Node Address Register
PLXP_BOARD_TYPE          equ     47h          ;- PCI ConfigSpace 47

;--------------------------------------------------------------------------
; Run Time Registers
; These are 6 32-bit WORD Run Time registers. They are stored sequentially
; in the EEPROM.
;--------------------------------------------------------------------------
PLXP_INTERRUPT_CONTROL	EQU		00h		;Interrupt Control Register
	INT_STAT			EQU		10h
PLXP_USER_PINS			EQU		04h		;User Pins Register
PLXP_FLASH_CONTROL		EQU		08h		;Flash PROM Control Register
PLXP_FLASH_WINDOW		EQU		0Ch		;Flash PROM Window Register
PLXP_LAN_CONTROL		EQU		10h		;EEPROM And LAN Control Register
PLXP_MASTER_CONTROL		EQU		14h		;Master Control Register

PLXP_CA_OFFSET			equ		20h			;- Offset For CA Command
PLXP_PORT_OFFSET		equ		24h			;- Offset For PORT Command
	RESET_CMD				equ		00h
	SELF_TEST_CMD			equ		01h
	ALT_SCP_CMD				equ		02h
	DUMP_CMD				equ		03h

;- Interrupt Control Register
;- Register Bit Definitions
LATCHED_INTWRITE_BIT     equ     BIT_3
LATCHED_INTREAD_BIT      equ     BIT_4
INTERRUPT_MASK_BIT       equ     BIT_5
SOFTWARE_INTERRUPT_BIT   equ     BIT_6
LAN_0_INTERRUPT_ENABLE   equ     BIT_8

;- User Pins register bit definitions
PLXP_USER_0              equ     BIT_0        ;- User Bit 0
PLXP_USER_1              equ     BIT_1        ;- User Bit 1
PLXP_USER_2              equ     BIT_2        ;- User Bit 2
PLXP_USER_3              equ     BIT_3        ;- User Bit 3

;- EEPROM And LAN (Intel 82596 / 82556) Control Register
;- Register Bit Definitions
LOAD_CONFIGURATION_BIT   equ     BIT_4
LAN_0_RESET_BIT          equ     BIT_8
SOFTWARE_RESET_BIT       equ     BIT_12

;- MASTER CONTROL register bit definitions
BURST_LENGTH_BIT         equ     BIT_12

; System Configuration Pointer (SCP) SYSBUS bit definitions
SYSBUS_BIT_0			EQU	BIT_0		;Don't Care bit
SYSBUS_32_MODE			EQU	BIT_1		;Enhanced 32-bit Segmented
SYSBUS_LINEAR_MODE		EQU	BIT_2		;Linear (Flat Space)
SYSBUS_LOCK_DIS			EQU	BIT_4		;Lock Function Disabled
SYSBUS_INT_LOW			EQU	BIT_5		;Active Low Interrupt Pin
SYSBUS_CSW				EQU	BIT_6		;CSW (Channel Switch)
SYSBUS_BIT_7			EQU	BIT_7		;Don't Care bit

DEFAULT_T_ON			EQU	8000h
DEFAULT_T_OFF			EQU	2
DEFAULT_FIFO			EQU	08h
IFS_SPACING				EQU	60h
SLOT_TIME				EQU	200h

; SCB_STATUS bits
	THROTTLE_BIT	EQU	08h
	RU_STATUS_BITS	EQU	0F0h
	RU_IDLE			EQU 000h
	RU_SUSPENDED	EQU 010h
	RU_NO_RESOURCES	EQU 020h
	RU_READY		EQU 040h
	RU_NO_RBD		EQU 080h
	RU_NO_RS_NO_RBD	EQU 0A0h
	CU_STATUS_BITS	EQU	0700h
	CU_IDLE			EQU 0000h
	CU_SUSPENDED	EQU 0100h
	CU_ACTIVE		EQU 0200h
	RNR_ST_BIT		EQU	1000h
	CNA_ST_BIT		EQU	2000h
	FR_ST_BIT		EQU	4000h
	CX_ST_BIT		EQU	8000h
	SCB_STATUS_MASK	EQU	CX_ST_BIT + FR_ST_BIT + CNA_ST_BIT + RNR_ST_BIT

; SCB_CMD bits
	RU_NOP			EQU 000h
	RU_START		EQU 010h
	RU_RESUME		EQU 020h
	RU_SUSPEND		EQU 030h
	RU_ABORT		EQU 040h
	RU_LOAD_HDS		EQU	050h
	RESET_CHIP_BIT	EQU 080h

	CU_NOP			EQU 00h
	CU_START		EQU 100h
	CU_RESUME		EQU 200h
	CU_SUSPEND		EQU 300h
	CU_ABORT		EQU 400h
	CU_LD_B_T		EQU 500h
	CU_LD_B_T_R		EQU 600h
	ACK_RNR			EQU 1000h
	ACK_CNA			EQU 2000h
	ACK_FR			EQU	4000h
	ACK_CX			EQU	8000h

ISCP_BUSY_MARK		EQU	01h

; Command Block (CB) Field Definitions
CB_CMD_MASK              equ     BIT_0_2      ;- CB 3-bit CMD Mask
CB_EL_BIT                equ     BIT_15       ;- CB EL Bit
CB_S_BIT                 equ     BIT_14       ;- CB Suspend Bit
CB_I_BIT                 equ     BIT_13       ;- CB Interrupt Bit
;-
CB_TX_SF_BIT             equ     BIT_3        ;- TX CB Flexible Mode
CB_TX_NC_BIT             equ     BIT_4        ;- TX No CRC Insertion Enable
CB_TX_EOF_BIT            equ     BIT_15       ;- TX CB/TBD EOF Bit
;-
;- CB Status Word
;-
CB_STATUS_MASK           equ     (BIT_12|BIT_13|BIT_14|BIT_15)
					      ;- CB Status Mask (4-bits)
CB_STATUS_COMPLETE       equ     BIT_15       ;- CB Complete Bit
CB_STATUS_BUSY           equ     BIT_14       ;- CB Busy Bit
CB_STATUS_OK             equ     BIT_13       ;- CB OK Bit
CB_STATUS_ABNORMAL       equ     BIT_12       ;- CB A Bit
CB_STATUS_FAIL           equ     BIT_12       ;- CB Fail (F) Bit
CB_STATUS_COPYDONE       equ     BIT_4        ;- CB Copy Done Bit

; Transmit CB Statistics Bits
CB_TX_COLL_CNT_MASK      equ     (BIT_0|BIT_1|BIT_2|BIT_3)
					      ;- Collision Count Mask
CB_TX_MAX_COLLISIONS     equ     BIT_5        ;- Maximum Collisions Bit
CB_TX_HEARTBEAT          equ     BIT_6        ;- Heartbeat Indicator
CB_TX_DEFERRED           equ     BIT_7        ;- Transmission Deferred
CB_TX_DMA_UNDERRUN       equ     BIT_8        ;- DMA underrun
CB_TX_NO_CTS             equ     BIT_9        ;- Loss Of Clear-To-Send
CB_TX_NO_CARRIER_SENSE   equ     BIT_10       ;- No Carrier Sense Signal
CB_TX_LATE_COLLISION     equ     BIT_11       ;- Late Collision


; Config CB Parameter Fields
; byte 0
CB_CFIG_PREFETCH_BIT	EQU	80h		;Write Prefetch Bit Enabled
; byte 1
CB_CFIG_NO_MONITOR_MODE	EQU	0C0h	;Monitor Mode Disabled
; byte 2
CB_CFIG_SAVE_BAD_FRAMES	EQU	80h		;Save Bad Frames Enabled
; byte 3
CB_CFIG_ADDRESS_LEN		EQU	06h		;Maximum Address Length
CB_CFIG_NO_SRCADR		EQU	08h		;No Source Address Insertion
CB_CFIG_PREAMBLE_LEN	EQU	20h		;Preamble Length = 8 bytes
CB_CFIG_LOOPBACK_MODE	EQU	0C0h	;External Loopback Mode
; byte 5
CB_CFIG_IFS				EQU	IFS_SPACING	;Interframe Spacing
; byte 6
CB_CFIG_SLOTTIME_LOW	EQU	(SLOT_TIME MOD 256) ;Slot Time (Low) 512 TX Clocks
; byte 7
CB_CFIG_SLOTTIME_HIGH	EQU	(SLOT_TIME/256)	;Slot Time (Low) 512 TX Clocks
CB_CFIG_MAX_RETRIES		EQU	0F0h	;Max 15 Retries
; byte 8
CB_CFIG_PROMISCUOUS		EQU	01h		;Promiscuous Mode Enable
CB_CFIG_BROADCAST_DIS	EQU	02h		;Broadcast Mode Disable
CB_CFIG_MANCHESTER		EQU	04h		;Manchester Encoding Enable
CB_CFIG_TX_NO_CRS		EQU	08h		;Transmit on no CRS
CB_CFIG_NO_CRC_INSERT	EQU	10h		;No CRC Insertion
CB_CFIG_CRC_16BIT		EQU	20h		;CRC 16 Enabled
CB_CFIG_HDLC_BIT_STUFF	EQU	40h		;HDLC Bit Stuffing
CB_CFIG_NO_PADDING		EQU	80h		;Padding Disabled
; byte 9
CB_CFIG_EXTERNAL_CRS	EQU	04h		;External Carrier Sense
CB_CFIG_EXTERNAL_CDT	EQU	80h		;External Collision Detect
; byte 11
CB_CFIG_PRECRS_DISABLE	EQU	01h		;No Preamble Until CRS
CB_CFIG_LENGTH_DISABLE	EQU	02h		;Length Field Disabled
CB_CFIG_NO_CRC_IN_MEM	EQU	04h		;Transfer CRC To Memory
CB_CFIG_AUTO_RETX		EQU	08h		;Auto Retransmit Enabled
CB_CFIG_NO_CDT_SAC		EQU	10h		;No CDT By Source Addr Compare
CB_CFIG_MCAST_DISABLE	EQU	20h		;Multicast All Disabled
; byte 12
CB_CFIG_FDX_ENABLE		EQU	40h		;Full Duplex Enabled
; byte 13
CB_CFIG_MULTIIA_ENABLE	EQU	40h		;Multiple IA Addr Enabled
CB_CFIG_BACKOFF_DISABLE	EQU	80h		;Disable Backoff

;- 82556 Configuration Bits Definition
CB_CFIG_LATE_SCB         equ     BIT_0        ;- Update SCB After New Tx Start
CB_CFIG_RESUME_READ_CB   equ     BIT_1        ;- Enable Suspend / Resume
CB_CFIG_TNO_INT          equ     BIT_2        ;- Tx Not OK Interrupt
CB_CFIG_CI_INT           equ     BIT_3        ;- Command Complete Interrupt
CB_CFIG_COPY_BIT         equ     BIT_4        ;- Enable Copy Bit
CB_CFIG_TX_THRESHOLD     equ     BIT_5        ;- Setup Tx Threshold

; System Configuration Pointer (SCP)
SCP_STRUC			struc
	scp_reserved0	dw	0
	scp_sysbus		dw	?			;- SYSBUS Config byte
	scp_reserved1	db	4	dup (0)
	scp_iscp_add	dd	?			;- ISCP Physical Address
SCP_STRUC			ends

; Intermediate System Configuration Pointer (ISCP)
ISCP_STRUC			struc
	iscp_busy		db	?			;- Initialization Busy Flag
	iscp_reserved0	db	0
	iscp_scb_offset	dw	?			;- Offset Of SCB Address
	iscp_scb_lo_add	dw	?			;- Base Of SCB Address (A15 - A0)
	iscp_scb_hi_add	dw	?			;- Base Of SCB Address (A23 - A16)
	iscp_filler		db	6	dup (0)
ISCP_STRUC			ends

; System Control Block (SCB)
SCB_STRUC	struc
	scb_status		dw	?			;- SCB Status
	scb_command		dw	?			;- SCB Command
	scb_cbl_add		dw	?			;- CB List Offset
	scb_rfa_add		dw	?			;- RFA Offset
	scb_crc_err		dd	?			;- RX CRC Errors
	scb_alig_err	dd	?			;- RX Unaligned Frames / CRC Errors
	scb_rsrce_err	dd	?			;- RX Frames Discarded (No Resources)
	scb_dma_err		dd	?			;- RX DMA Overruns
	scb_rcvd_err	dd	?			;- RX Collisions Count
	scb_short_err	dd	?			;- Short Frame Errors
	scb_off_timer	dw	?			;- Bus Throttle T-OFF Timer
	scb_on_timer	dw	?			;- Bus Throttle T-ON Timer
	scb_header_size	dw	?			;- Header RFD Data Size
	scb_filler		dw	?			;- All Zeroes, Reserved.
SCB_STRUC               ends

; Transmit Command Block (TxCB)
TXCB_STRUC			struc
    tx_status			dw	?		; Command Block Status
    tx_command			dw	?		; Command Block Command
    tx_link_ptr			dw	?		; Offset To Next CB
	tx_tbd_ptr			dw	?		; TBD Offset
	tx_count			dw	?		; Data Bytes In TCB past header
	tx_thresh			db	0		; TX Threshold for FIFO Extender
	tx_filler			db	0
TXCB_STRUC			ends

; Received Frame Descriptor
RFD_STRUCT	struc
rfd_status	dw	?				; Status word for frame
rfd_eol		dw	?				; End of RFD list flag
rfd_link	dw	?				; 16 pointer to next RFD
rfd_ptr		dw	?				; 16 pointer to list of RBD's
rfd_cnt		dw	?				; Actual size of data in buffer after header
rfd_size	dw	?				; Size of data buffer after header
rfd_dest	db	EADDR_LEN dup(?); 48 bits of destination
rfd_source	db	EADDR_LEN dup(?); 48 bits of source
rfd_len		dw	?				; Length field of frame.
RFD_STRUCT	ends

; Receive Buffer Descriptor
RBD_STRUCT	struc
rbd_status	dw	?				; Status word in RBD
rbd_link	dw	?				; 16 bit pointer to next RBD
rbd_ptr		dd	?				; 32 bit pointer to actual buffer
rbd_size	dw	?				; Size of the buffer
rbd_filler1	dw	?				; Not used
rbd_voffset	dw	?				; Virtual offset to data buffer
RBD_STRUCT	ends

C_ATTENTION	macro
	LOAD_PORT	PLXP_CA_OFFSET		; Issue a channel attention to the 82596
	in	al, dx
	endm

WAIT_CMD_ACCEPTED macro
	local	lab1
lab1:
	cmp		WORD PTR cs:scb_buff.scb_command, 0
	jne		lab1
	endm

