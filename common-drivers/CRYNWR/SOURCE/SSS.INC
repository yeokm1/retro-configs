;******************************************************************************
;
;	Service Specific Status Table
;
;******************************************************************************

SSS_MACSTAT_MASK	equ	07h	; bit mask for sss_macstat
SSS_MULTI_UNI_FILTER    equ     01h     ;
SSS_BROADCAST_FILTER    equ     02h     ;
SSS_PROMISCOUS_FILTER   equ     04h     ;
SSS_NOT_INSTALLED	equ	00h	; hardware not installed
SSS_FAILED_DIAG		equ	01h	; hardware failed startup diagnostics
SSS_CONFIG_PROB		equ	02h	; hw failed due to config problem
SSS_HARDWARE_FAULT	equ	03h	; hw not operational due to hw fault
SSS_SOFT_FAULTS		equ	04h	; hw marginal due to soft faults
SSS_OPERATIONAL		equ	07h	; hardware fully operational
SSS_BOUND		equ	08h	; MAC is bound (if set)
SSS_OPEN		equ	10h	; MAC is open (if set)
SSS_DIAG_RUNNING	equ	20h	; adapter diagnostics are in progress

servspecstat	struc
sss_length	dw	0		; length of table
sss_diagsrun	dd	0		; date/time of last diags
sss_macstat	DWORD_PTR	{0, 0}	; status of mac driver
sss_filter	dw	0		; current packet filter
sss_mediaspec	dd	0		; pointer to media specific table
sss_clearrun	dd	0		; date/time of last clearstatistics
sss_frames_rx	dd	0		; total frames received
sss_crc_err	dd	0		; frames with CRC error
sss_bytes_rx	dd	0		; total bytes received
sss_nospace_rx	dd	0		; frames discarded - no buffer space
sss_multi_rx	dd	0		; multicast frames received
sss_broad_rx	dd	0		; broadcast frames received
sss_rx_errors	dd	0		; frames received with errors
sss_to_big	dd	0		; frames exceeding max size
sss_to_small	dd	0		; frames smaller than min size
sss_mbytes_rx	dd	0		; multicast bytes received
sss_bbytes_rx	dd	0		; broadcast bytes received
sss_hard_err	dd	0		; frames discarded - hardware error
sss_frames_tx	dd	0		; total frames transmitted
sss_bytes_tx	dd	0		; total bytes transmitted
sss_multi_tx	dd	0		; multicast frames transmitted
sss_broad_tx	dd	0		; broadcast frames transmitted
sss_bbytes_tx	dd	0		; broadcast bytes transmitted
sss_mbytes_tx	dd	0		; multicast bytes transmitted
sss_no_trans	dd	0		; frames not transmitted - timeout
sss_hard_tx	dd	0		; frames not transmitted - hw error
servspecstat	ends
SSS_TABLE_SIZE equ      SIZE servspecstat

