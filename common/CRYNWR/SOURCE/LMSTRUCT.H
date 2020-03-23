/***********************
 * SMC LMI Driver, 1992,1993,1994
 *
 *	This software is licensed by SMC for use by its customers only.
 *  Copyright (C) 1992-1994 by Standard Microsystems Corp.  All rights reserved.
 *
 ***********************
 */

#define MC_TABLE_ENTRIES      16

#ifndef MAXFRAGMENTS
#define MAXFRAGMENTS          32
#endif

#define MAX_TX_QS             8
#define NUM_TX_QS_USED        3

#define MAX_RX_QS             2
#define NUM_RX_QS_USED        2

typedef unsigned char         BYTE;
typedef unsigned short        WORD;

#ifndef NDIS3X

typedef void far *            FPTR;

#endif

typedef void *                NPTR;
typedef unsigned long         DWORD;

/* needed for sample driver compiles */
#if !defined ISCP_BLOCK_SIZE

#define ISCPBlock void
#define SCGBlock void
#define SCLBlock void
#define ISBlock void
#define ACBlock void
#define FCBlock void
#define BDBlock void

typedef	unsigned char	Byte;		/* This is 1 BYTE  in 808x and 80386 */	
typedef	unsigned short	Word;		/* This is 2 BYTES in 8086 and 80386 */
typedef unsigned long	Dword;		/* This is 4 BYTES in 8086 and 80386 */

#endif
/* end of needed sample driver definitions */

#ifdef __WATCOMC__
#ifndef CODE_386
#pragma aux default "_*"           \
            parm caller []       \
            value no8087         \
            modify [ax bx cx dx]
#endif            
#endif

#ifdef CODE_386
#define PHYSICAL_ADDR         0x80000000
#else
#define PHYSICAL_ADDR         0x8000
#endif

/****************************
 * Multicast Table Structure
 ****************************
 */

typedef struct
{
        BYTE    address[6];
        BYTE    instance_count;
} McTable;
 
/*********************************
 * Fragment Descriptor Definition
 *********************************
 */

typedef struct
        {
        BYTE  *fragment_ptr;
#if defined(CODE_386)
        DWORD   fragment_length;
#else
        WORD  fragment_length;
#endif
        } FragmentStructure;

/***********************************
 * Data Buffer Structure Definition
 ***********************************
 */
 
typedef struct
        {
#if defined(CODE_386)
        DWORD fragment_count;
#else
        WORD  fragment_count;
#endif
        FragmentStructure       fragment_list[MAXFRAGMENTS];
        } DataBufferStructure;

#if defined (PCMCIA)

/***********************************
* PCMCIA Data structure defs
************************************
*/

typedef struct
{
        WORD    InfoLen;
        WORD    Signature;
        WORD    Count;
        WORD    Revision;
        WORD    CSLevel;
        WORD    VStrOff;
        WORD    VStrLen;
        BYTE    VendorString[128];
} INFOSTRUCT;

typedef struct
{
        WORD    Attributes;
        WORD    EventMask;
        BYTE    ClientData[8];
        WORD    CSVersion;

} REGISTERCLIENTSTRUCT;

typedef struct
{
        WORD    Socket;
        WORD    Attributes;
        BYTE    DesiredTuple;
        BYTE    TupleOffset;
        WORD    Flags;
        FPTR    LinkOffset;
        FPTR    CISOffset;
        BYTE    TupleCode;
        BYTE    TupleLink;
} TUPLESTRUCT;

typedef union
{
        WORD    TupleDataMax;
        BYTE    TupleCode;
} TUPLE1;

typedef union
{
        WORD    TupleDataLen;
        BYTE    TupleLink;
} TUPLE2;

typedef struct
{
        WORD    Socket;
        WORD    Attributes;
        BYTE    DesiredTuple;
        BYTE    TupleOffset;
        WORD    Flags;
        FPTR    LinkOffset;
        FPTR    CISOffset;
        TUPLE1  TDat1;          /* This allows access of TUPLEDATA and TUPLESTRUCT      */
        TUPLE2  TDat2;          /* members from the same structure.                     */
        BYTE    TupleData[128];
} TUPLEDATA;

typedef struct
{
        WORD    Socket;
        WORD    BasePort1;
        BYTE    NumPorts1;
        BYTE    Attributes1;
        WORD    BasePort2;
        BYTE    NumPorts2;
        BYTE    Attributes2;
        BYTE    IOAddrLines;

} REQIOSTRUCT;

typedef struct
{
        WORD    Socket;
        WORD    Attributes;
        BYTE    AssignedIrq;
        BYTE    IRQInfo1;
        WORD    IRQInfo2;

} REQIRQSTRUCT;

typedef struct
{
        WORD    Socket;
        WORD    Attributes;
        DWORD   Base;
        DWORD   Size;
        BYTE    AccessSpeed;

} REQMEMSTRUCT;

typedef struct
{
        DWORD   MapMemCardOffset;
        BYTE    MapMemPage;

} MAPMEMPAGESTRUCT;

typedef struct
{
        WORD    ReqCfgSocket;
        WORD    ReqCfgAttribute;
        BYTE    ReqCfgVcc;
        BYTE    ReqCfgVpp1;
        BYTE    ReqCfgVpp2;
        BYTE    ReqCfgIntType;
        DWORD   ReqCfgConfigBase;
        BYTE    ReqCfgStatus;
        BYTE    ReqCfgPin;
        BYTE    ReqCfgCopy;
        BYTE    ReqCfgConfigIndex;
        BYTE    ReqCfgPresent;

} REQCFGSTRUCT;

typedef struct
{
        BYTE    ARIAction;
        BYTE    ARIResource;
        WORD    ARIAttributes;
        DWORD   ARIBase;
        DWORD   ARISize;

} ADJRESINFOSTRUCT;

typedef	struct
{
        WORD    GCISocket;
        WORD    GCIAttribute;
        BYTE    GCIVcc;
        BYTE    GCIVpp1;
        BYTE    GCIVpp2;
        BYTE    GCIIntType;
        DWORD   GCIConfigBase;
        BYTE    GCIStatus;
        BYTE    GCIPin;
        BYTE    GCICopy;
        BYTE    GCIConfigIndex;
        BYTE    GCIPresent;
	BYTE	GCIFirstDevType;
	BYTE	GCIFuncCode;
	BYTE	GCISysInitMask;
	WORD	GCIManufCode;
	WORD	GCIManufInfo;
	BYTE	GCICardValues;
	BYTE	GCIAssignedIRQ;
	WORD	GCIIRQAttributes;
	WORD	GCIBasePort1;
	BYTE	GCINumPorts1;
	BYTE	GCIAttributes1;
	WORD	GCIBasePort2;
	BYTE	GCINumPorts2;
	BYTE	GCIAttributes2;
	BYTE	GCIIOAddrLines;

} GETCFGINFOSTRUCT;

#endif // (PCMCIA)


/***********************************
 * DEC PCI Data structure defs
 ************************************
 *
 */


#if defined (DEC_PCI)


#define MAX_TX_FRAMES_8432   3
#define MAX_TX_DESC_8432     ((MAX_TX_FRAMES_8432 * MAXFRAGMENTS) + 1)
#define MAX_RX_DESC_8432     4
#define MAX_BUFFER_SIZE      1520
#define SETUP_BUFFER_SIZE    192
#define HOST_RAM_ALIGNMENT   32


#define HOST_RAM_SIZE        ( (32 * MAX_TX_DESC_8432)              \
			     + (32 * MAX_RX_DESC_8432)              \
			     + SETUP_BUFFER_SIZE                    \
			     + (MAX_RX_DESC_8432 * MAX_BUFFER_SIZE) \
                             + (MAX_TX_FRAMES_8432 * MAX_BUFFER_SIZE) \
			     + HOST_RAM_ALIGNMENT                   \
			     )

			       

typedef struct {
        DWORD virtual_addr;
        DWORD phy_addr;
} ADDR_TBL;


typedef struct {

        DWORD status;
        DWORD control;
        DWORD buffer_1;
        DWORD buffer_2;
        DWORD reserved[4];

} TxDescriptorStructure ;


typedef struct {

        DWORD status;
        DWORD control;
        DWORD buffer_1;
        DWORD buffer_2;
        DWORD vbuffer_1 ;                   /* virt address of buffer */
        DWORD reserved[3];

} RxDescriptorStructure;


#endif // (DEC_PCI)



/*******************************
 * Adapter Structure Definition
 *******************************
 */

typedef struct
        {
        BYTE            adapter_num;
        BYTE            pc_bus;
        WORD            io_base;
        BYTE            adapter_name[12];
        WORD            irq_value;   
        WORD            rom_size;
        DWORD           rom_base;
        DWORD           rom_access;     /* OS dependent */
        WORD            ram_size;
        DWORD           ram_base;
        DWORD           ram_access;     /* OS dependent */
        WORD            ram_usable;
        WORD            io_base_new;    /* for PutConfig */
        BYTE            node_address[6];
        WORD            max_packet_size;
        WORD            num_of_tx_buffs;
        WORD            receive_mask;
        WORD            adapter_status;
        WORD            media_type;
        WORD            adapter_bus;
        WORD            pos_id; 
        WORD            adapter_flags;
        WORD            adapter_flags1;
        BYTE            slot_num;
        BYTE            rx_lookahead_size;      // Size of UMAC's max lookahead size in 16 bit chunks.
	WORD		media_opts;             // Media options supported by the adapter ...
	WORD		media_set;		// Media type(s) being used by the adapter ...

#if defined (LM8316)
	WORD		dma_channel;		// Direct Memory Access channel
#else
#if defined (LM9232)
	WORD		dma_channel;		// Direct Memory Access channel
#endif
#endif
// Local vars for each adapter 

        WORD            bic_type;
        WORD            nic_type;
        WORD            board_id;
        WORD            board_id2;
        WORD            extra_info;
        WORD            extra_info2;
        WORD            mode_bits;
        WORD            status_bits;
        WORD            xmit_buf_size;
        WORD            xmit_flag_offset;
        WORD            config_mode;      /* 1 to save to EEROM, 0 for local save */
        WORD            page_offset_mask;
        WORD            media_menu;       /* for EZSTART */        
        DWORD           *easp;

#if defined     (TOKEN_RING)

        DWORD           *ptr_rx_fcb_overruns;
        DWORD           *ptr_rx_bdb_overruns;
        DWORD           *ptr_rx_fifo_overruns;
        DWORD           *ptr_tx_fifo_underruns;
        DWORD           *ptr_internal_errors;
        DWORD           *ptr_line_errors;
        DWORD           *ptr_ac_errors;
        DWORD           *ptr_burst_errors;
        DWORD           *ptr_ad_trans_errors;
        DWORD           *ptr_rcv_congest_errors;
        DWORD           *ptr_lost_frame_errors;
        DWORD           *ptr_freq_errors;
        DWORD           *ptr_fr_copied_errors;
        DWORD           *ptr_token_errors;
        DWORD           *ptr_una;
	DWORD		*ptr_bcn_type;
	DWORD		*ptr_local_ring_num;

	BYTE		ring_status_flags;
        BYTE		join_state;
        BYTE		monitor_state;
        WORD            ring_status;
        WORD            authorized_function_classes;
        WORD            authorized_access_priority;
        WORD            microcode_version;
        WORD            group_address_0;
        WORD            group_address[2];
        WORD            functional_address_0;
        WORD            functional_address[2];
        WORD            bitwise_group_address[2];
        WORD            source_ring_number;
        WORD            target_ring_number;
	BYTE		*ptr_ucode ;

/*
   The following values are for lower mac use only!
   They are not used by the upper mac
*/

#ifdef	LM8316
	WORD		*tx_dma_area_ptr;
	WORD		*rx_dma_area_ptr;
	WORD		*extra_dma_area_ptr;
        FCBlock         *tx_dma_fcb;
	WORD		*virt_erx_buffer;
	WORD		*ptr_erx_fraglist;
	WORD		bus_master_control;
#endif

        DWORD           sh_mem_used;

        WORD            config_word0;
        WORD            config_word1;

        ISCPBlock       *iscpb_ptr;
        SCGBlock        *scgb_ptr;
        SCLBlock        *sclb_ptr;
        ISBlock         *isb_ptr;
        WORD            current_isb_index;
        WORD            *misc_command_data;

        ACBlock         *acb_head;
        ACBlock         *acb_curr;
        ACBlock         *acb_next;

        WORD            num_acbs;
        WORD            num_acbs_used;
        WORD            acb_pending;

        FCBlock         *tx_fcb_head            [NUM_TX_QS_USED];
        FCBlock         *tx_fcb_curr            [NUM_TX_QS_USED];
        FCBlock         *tx_fcb_tail            [NUM_TX_QS_USED];

        BDBlock         *tx_bdb_head            [NUM_TX_QS_USED];

        WORD            *tx_buff_head           [NUM_TX_QS_USED];
        WORD            *tx_buff_end            [NUM_TX_QS_USED];
        WORD            *tx_buff_curr           [NUM_TX_QS_USED];
        WORD            tx_buff_size            [NUM_TX_QS_USED];

        WORD            num_tx_fcbs             [NUM_TX_QS_USED];
        WORD            num_tx_bdbs             [NUM_TX_QS_USED];
        WORD            num_tx_fcbs_used        [NUM_TX_QS_USED];
#ifdef	LM8316
        WORD            num_tx_fcbs_queued      [NUM_TX_QS_USED];
#endif
        WORD            tx_buff_used            [NUM_TX_QS_USED];
        WORD            tx_queue_status         [NUM_TX_QS_USED];

        FCBlock         *rx_fcb_head            [NUM_RX_QS_USED];
        FCBlock         *rx_fcb_curr            [NUM_RX_QS_USED];

        BDBlock         *rx_bdb_head            [NUM_RX_QS_USED];
        BDBlock         *rx_bdb_end             [NUM_RX_QS_USED];
        BDBlock         *rx_bdb_curr            [NUM_RX_QS_USED];

        WORD            *rx_buff_head           [NUM_RX_QS_USED];
        WORD            *rx_buff_end            [NUM_RX_QS_USED];

        WORD            num_rx_fcbs             [NUM_RX_QS_USED];
        WORD            num_rx_bdbs             [NUM_RX_QS_USED];
        WORD            receive_queue_number;

        WORD            rx_buff_blk_size        [NUM_RX_QS_USED];
        BYTE            rx_shift_factor         [NUM_RX_QS_USED];      /* mul. factor to get # BDBs from frame length */

        BYTE            trc_mask;
        BYTE            rx_fifo_overrun_count;

        BYTE            lobe_media_test_flag;
        BYTE            DMA_test_state ;

	BYTE		filler;			/* eveinze structure */

/* end of lower mac specific variables */

#endif      

#if     defined(ETHERNET)

/*-------------------------...Error Counter Pointers...----------------------*/

        DWORD           *ptr_rx_CRC_errors;
        DWORD           *ptr_rx_too_big;
        DWORD           *ptr_rx_lost_pkts;
        DWORD           *ptr_rx_align_errors;
        DWORD           *ptr_rx_overruns;
        DWORD           *ptr_tx_deferred;
        DWORD           *ptr_tx_total_collisions;
        DWORD           *ptr_tx_max_collisions;
        DWORD           *ptr_tx_one_collision;
        DWORD           *ptr_tx_mult_collisions;
        DWORD           *ptr_tx_ow_collision;
        DWORD           *ptr_tx_CD_heartbeat;
        DWORD           *ptr_tx_carrier_lost;
        DWORD           *ptr_tx_underruns;
        DWORD           *ptr_ring_OVW;

        BYTE            multi_address[6];

/*
   The following values are for lower mac use only!
   They are not used by the upper mac
*/

#if defined (CODE_386)
        WORD            early_xmit_flags;
        WORD            split_word;
        DWORD           leftover_count;
#endif

/* for 8232 */
        BYTE            max_page_num;
        BYTE            curr_page_num;
        BYTE            early_tx_pend;
        BYTE            rx_pend;
        WORD            early_tx_threshold;
                        
        DWORD           rx_frag;
        WORD            erx_offset;
        WORD            erx_size;
        DWORD           dummy_vector;
#if defined (CODE_386)
        DWORD           xmit_threshold;
#else
        WORD            xmit_threshold;
#endif                 
        WORD            tx_pend;  
//      BYTE            early_tx_slope;
        BYTE            tx_retry;
        WORD            early_rx_slope;
#endif

#if defined (ETHERNET)
#if defined (E3000)

        BYTE   tx_mask;
        BYTE   rx_mask;
        BYTE   rx_status;

        WORD   pkt_byte_offset;
        WORD   total_bytes_to_move;
        WORD   xmit_pkt_size;
        WORD   driver_state;
        WORD   pkt_bytes_looked;
        WORD   etherstar_byte_count;
        WORD   bytes_from_LA;

	     DWORD  *ptr_shrtpkt_errors;
	     DWORD  *ptr_busread_errors;
	     DWORD  *ptr_buswrite_errors;

#if defined (LA_BUFF)
        BYTE   look_ahead_buf[LA_BUFF];
#else
        BYTE   look_ahead_buf[256];
#endif

#endif
#endif


#if defined (ETHERNET)
        BYTE           imr_hold;
        BYTE           rcr_hold;
        BYTE           pstart_hold;
        BYTE           pstop_hold;
        BYTE           local_nxtpkt_ptr;
        BYTE           int_bit;
        BYTE           hdw_int;
        BYTE           ovw_tx_pending;
#if defined(CODE_386)
        DWORD          pstop_32;
        DWORD          wr_frag_cnt;
        DWORD          byte_cnt;
        DWORD          packet_offset;
#else
        WORD           wr_frag_cnt;
        WORD           byte_cnt;
        WORD           packet_offset;
#endif                 

#endif


#if defined (ETHERNET)
        WORD           packet_ptr;
        WORD           int_port;
        WORD           pkt_len;
        BYTE           ring_ovw;
        BYTE           laar_enter;
        WORD           data_buff_seg;
        WORD           leftover_data;
        DWORD          tx_buffer[3];
#if defined(LNKLST)
        WORD           tx_head;
        WORD           tx_tail;
#else
        BYTE           tx_head;
        BYTE           tx_tail;
#endif
        BYTE           tx_count;
        BYTE           tx_pstop;
        WORD           servicing_ints;

//      WORD           lpbk_frag_count;
//      BYTE           lpbk_frag_struct[sizeof (FragmentStructure)];


#if defined(LNKLST)
        WORD           rec_buf_size;
        WORD           tstart;
        WORD           tstop;
        WORD           rstart;
        WORD           rstop;
        BYTE           tbegin;
        BYTE           tend;
        BYTE           rbegin;
        BYTE           rend;
        WORD           num_rdt_entries;
        WORD           next_rdt_entry;
        BYTE           rdt_size;
        BYTE           xmt_size;
        BYTE           rec_size;
#endif
        BYTE           laar_exit;
        WORD           erx_frame_size;
	WORD	       lmac_flags;
        BYTE           erx_addr_type;

/*-----------------------...Multicast Address Table...-----------------------*/
/*      Broadcast address entry + instance count.       */

        BYTE           bc_add[7];
        McTable        mc_table[MC_TABLE_ENTRIES];

	BYTE	       temp_addr[6];

#if defined (PCMCIA)

	WORD	       callback_handler_status;
        WORD           pcm_socket;
        WORD           pcm_card_flags;
        WORD           pcm_client_handle;
        WORD           pcm_ram_win_handle;
        WORD           pcm_reg_win_handle;

        REQIRQSTRUCT   req_irq_struct;
        REQMEMSTRUCT   req_mem_struct;
        REQIOSTRUCT    req_io_struct;
        TUPLEDATA      tuple_data;
        REGISTERCLIENTSTRUCT register_client_struct;
        INFOSTRUCT     info_struct;
        REQCFGSTRUCT   req_cfg_struct;
	GETCFGINFOSTRUCT req_cfg_info_struct;
        MAPMEMPAGESTRUCT map_mem_page_struct;
        ADJRESINFOSTRUCT adj_res_info_struct;

/* end of lower mac specific variables */

#endif // (PCMCIA)

#endif

#if defined (DEC_PCI)

	DWORD   host_ram_phy_addr ;
	DWORD   host_ram_virt_addr ;

/* PCI configuration */

	WORD  device_id;
	DWORD cbio;

/* Registers */

	DWORD op_mode;
	DWORD int_mask;
	DWORD sia_mode0;
	DWORD sia_mode1;
	DWORD sia_mode2;
        DWORD def_bus_mode ;

/* TX descriptor ring  - 16 bytes/descriptor - quadword aligned */

	ADDR_TBL tx_ring;
        ADDR_TBL tx_buff_tbl[MAX_TX_FRAMES_8432] ;
        WORD  tx_buff_idx ;
	TxDescriptorStructure *tx_enqueue;
	TxDescriptorStructure *tx_dequeue;
	DWORD free_tx_desc;

/* Rx descriptor ring - 16 bytes/descriptor - quadword aligned  */
/* Rx buffer - 1.6k/buffer - longword aligned                   */

	ADDR_TBL rx_ring;
	RxDescriptorStructure *rx_dequeue;
	DWORD current_rx_buffer;

/* media used = media detected if AUTO DETECT is used */
        WORD  media_used ;

/* CAM setup buffer -192 bytes - longword aligned */

	ADDR_TBL setup_ptr;

	DWORD mc_count;
	BYTE  multicast_check;

/* rev number */

	BYTE  rev_number;
        BYTE  test_flag;

#endif         // DEC_PCI


#ifdef LM9232
        BYTE    look_ahead_buf[256] ;

        BYTE    MCAddress[6] ;                  /* Used for multicast */
        BYTE    MCWorkArea[8] ;
        BYTE    SCECTxQueueSize;                /* default max tx free count */
        BYTE    TxPacketsInsideSCEC;            /* 1 -> 2048 bytes for 91C90 */
        BYTE    CurrentTxPcktSize;              /* but 256 bytes for 91C92 */
        BYTE    SCECShrForPageSize;
        BYTE    MIRShlTo256ByteUnits;           /* 0 for 91C90/92, 1 for FEAST */

        BYTE    InDriverInitFlag;
        BYTE    OddAddressFlag;
        BYTE    AllocationRequestedFlag;
        
        BYTE    Is386;                          /* Default to 286 */

        WORD    SCECPageSize;
        BYTE    SCECMaxMemForTx;                /* In percentage */
        WORD    SCECMaxPagesForTx;
        WORD    SCEC1518InSCECPages;
        WORD    SCECNumberOfPages;

        WORD    HardwareFrameLength;            /* Used to set SCEC's Control byte */

/**************************************************************************
;*                                                                          *
;*      I/O Port Variables                                                  *
;*                                                                          *
 **************************************************************************/

/*
;storage for IO address locations
;Bank 1
*/

        WORD    TCR;
        WORD    StatusRegister ;
        WORD    RCRRegister ;
        WORD    Counter ;
        WORD    MIR ;
        WORD    MCR ;
        WORD    NotUsed1 ;
        WORD    BankSelect ;
/*     
;Bank 2
*/
        WORD    Configuration ;
        WORD    BaseAddress ;
        WORD    IA0_1 ;
        WORD    IA2_3 ;
        WORD    IA4_5 ;
        WORD    General ;
        WORD    Control ;
        WORD    NotUsed2 ;
/*
;Bank 3
*/
        WORD    MMUCommand ;
        WORD    PNR_ARR ;
        WORD    FifoPorts ;
        WORD    Pointer ;
        WORD    Data0_1 ;
        WORD    Data2_3 ;
        WORD    Interrupt ;
        WORD    NotUsed3 ;

/*
;Bank 4
*/
        WORD    MT0_1 ;
        WORD    MT2_3 ;
        WORD    MT4_5 ;
        WORD    MT6_7 ;
        WORD    NotUsed4 ;
        WORD    ERCV ;
        WORD    Revision ;
        WORD    SCECRAMSize ;

/*
; ----- debug counters -----
*/
#ifdef  DEBUG
        WORD    SQETCount[2] ;
        WORD    ExcessiveDeferralCount[2] ;
        WORD    TXDeferredCount[2] ;
        WORD    TXMulticastCount[2] ;
        WORD    TXBroadcastCount[2] ;
        WORD    RxBroadcastCount[2] ;
        WORD    RxMulticastCount[2] ;
        WORD    SCECRxTooShortCount[2] ;
        WORD    MMUTimeoutCount[2] ;
        WORD    SpuriousEntryToISR[2] ;
#endif 

        WORD    MaxPercentageOnTx[2] ;
 
        BYTE    FoundSCECMaxMemForTx ;

        BYTE    InScecDriverInitFlag ;

/*
;DMA look up tables for IO base registers
*/

        BYTE    base_addr_dat[8] ;
        BYTE    base_addr_dat_L[8] ;
        BYTE    byte_count_dat[8] ;

        BYTE    DMA_base_addr_dat ;
        BYTE    DMA_base_addr_dat_L ;
        BYTE    DMA_byte_count_dat ;

/* 
; Temporary FIX for FEAST Rev. B lockup problem with multiple stations
;
*/
        BYTE    KickStartFlag ;


#endif /* end FEAST */

#ifdef NDIS3X

/* begin ndis specific stuff */

    void * NdisAdapterHandle;     

    void * ConfigurationHandle;

    unsigned char permanent_node_address[6];

#endif


} AdapterStructure;

/************************************
 * SNMP-ON-BOARD Agent Link Structure
 ************************************/

typedef struct {
        BYTE           LnkSigStr[12]; /* signature string "SmcLinkTable" */
        BYTE           LnkDrvTyp;     /* 1=Redbox ODI, 2=ODI DOS, 3=ODI OS/2, 4=NDIS DOS */
        BYTE           LnkFlg;        /* 0 if no agent linked, 1 if agent linked */
        void           *LnkNfo;       /* routine which returns pointer to NIC info */
        void           *LnkAgtRcv;    /* pointer to agent receive trap entry */ 
        void           *LnkAgtXmt;            /* pointer to agent transmit trap entry  */
        void           *LnkGet;                  /* pointer to NIC receive data copy routine */
        void           *LnkSnd;                  /* pointer to NIC send routine */
        void           *LnkRst;                  /* pointer to NIC driver reset routine */
        void           *LnkMib;                  /* pointer to MIB data base */
        void           *LnkMibAct;            /* pointer to MIB action routine list */
        WORD           LnkCntOffset;  /* offset to error counters */
        WORD           LnkCntNum;     /* number of error counters */
        WORD           LnkCntSize;    /* size of error counters i.e. 32 = 32 bits */
        void           *LnkISR;       /* pointer to interrupt vector */
        BYTE           LnkFrmTyp;     /* 1=Ethernet, 2=Token Ring */
        BYTE           LnkDrvVer1 ;   /* driver major version */
        BYTE           LnkDrvVer2 ;   /* driver minor version */
} AgentLink;

/////////////////////////////////////////////////////////////////////////////
// Defs for pcm_card_flags
/////////////////////////////////////////////////////////////////////////////
#define REG_COMPLETE   0x0001
#define INSERTED       0x0002

/////////////////////////////////////////////////////////////////////////////
//
// Adapter RAM test patterns
//
//                                                         
#define RAM_PATTERN_1  0x55AA
#define RAM_PATTERN_2  0x9249
#define RAM_PATTERN_3  0xDB6D

/////////////////////////////////////////////////////////////////////////////
//
// #defs for RAM test
//

#define ROM_SIGNATURE  0xAA55
#define MIN_ROM_SIZE   0x2000

/***************
 * Return Codes
 ***************
 */

#define SUCCESS                 0x0000
#define ADAPTER_AND_CONFIG      0x0001
#define ADAPTER_NO_CONFIG       0x0002
#define NOT_MY_INTERRUPT        0x0003
#define FRAME_REJECTED          0x0004
#define EVENTS_DISABLED         0x0005
#define OUT_OF_RESOURCES        0x0006
#define INVALID_PARAMETER       0x0007
#define INVALID_FUNCTION        0x0008
#define INITIALIZE_FAILED       0x0009
#define CLOSE_FAILED            0x000A
#define MAX_COLLISIONS          0x000B
#define NO_SUCH_DESTINATION     0x000C
#define BUFFER_TOO_SMALL_ERROR  0x000D
#define ADAPTER_CLOSED          0x000E
#define UCODE_NOT_PRESENT       0x000F
#define FIFO_UNDERRUN           0x0010
#define DEST_OUT_OF_RESOURCES   0x0011
#define ADAPTER_NOT_INITIALIZED 0x0012
#define PENDING                 0x0013
#define	UCODE_PRESENT		0x0014
#define NOT_INIT_BY_BRIDGE      0x0015

#define OPEN_FAILED             0x0080
#define HARDWARE_FAILED         0x0081
#define SELF_TEST_FAILED        0x0082
#define RAM_TEST_FAILED         0x0083
#define RAM_CONFLICT            0x0084
#define ROM_CONFLICT            0x0085
#define UNKNOWN_ADAPTER         0x0086
#define CONFIG_ERROR            0x0087
#define CONFIG_WARNING          0x0088
#define NO_FIXED_CNFG           0x0089
#define EEROM_CKSUM_ERROR       0x008A
#define ROM_SIGNATURE_ERROR     0x008B
#define ROM_CHECKSUM_ERROR      0x008C
#define ROM_SIZE_ERROR          0x008D
#define UNSUPPORTED_NIC_CHIP    0x008E
#define NIC_REG_ERROR           0x008F
#define BIC_REG_ERROR           0x0090
#define MICROCODE_TEST_ERROR    0x0091
#define	LOBE_MEDIA_TEST_FAILED	0x0092

// PCMCIA-Specific error codes ...
#define	CS_UNSUPPORTED_REV	0x0093
#define	CS_NOT_PRESENT		0x0094
#define	TUPLE_ERROR		0x0095
#define	REG_CLIENT_ERR		0x0096
#define	NOT_OUR_CARD		0x0097
#define	UNSUPPORTED_CARD	0x0098
#define	PCM_CONFIG_ERR		0x0099
#define	CARD_CONFIGURED		0x009A
#define ADAPTER_NOT_FOUND       0xFFFF

#define ILLEGAL_FUNCTION        INVALID_FUNCTION
/////////////////////////////////////////////////////////////////////////////
// Bit-Mapped codes returned in DX if return code from LM_GET_CONFIG is
// CONFIG_ERROR or CONFIG_WARNING:
/////////////////////////////////////////////////////////////////////////////

//// Errors:
#define IO_BASE_INVALID         0x0001
#define IO_BASE_RANGE           0x0002
#define IRQ_INVALID             0x0004
#define IRQ_RANGE               0x0008
#define RAM_BASE_INVALID        0x0010
#define RAM_BASE_RANGE          0x0020
#define RAM_SIZE_RANGE          0x0040
                                    
//// Warnings:
#define IRQ_MISMATCH            0x0080
#define RAM_BASE_MISMATCH       0x0100
#define RAM_SIZE_MISMATCH       0x0200
#define	BUS_MODE_MISMATCH	0x0400
                                    
/**********************************************
 * Definitions for the field RING_STATUS_FLAGS
 **********************************************
 */

#define	RING_STATUS_CHANGED			0X01
#define	MONITOR_STATE_CHANGED			0X02
#define	JOIN_STATE_CHANGED			0X04

/***************************************
 * Definitions for the field JOIN_STATE
 ***************************************
 */

#define	JS_BYPASS_STATE				0x00
#define	JS_LOBE_TEST_STATE			0x01
#define	JS_DETECT_MONITOR_PRESENT_STATE		0x02
#define	JS_AWAIT_NEW_MONITOR_STATE		0x03
#define	JS_DUPLICATE_ADDRESS_TEST_STATE		0x04
#define	JS_NEIGHBOR_NOTIFICATION_STATE		0x05
#define	JS_REQUEST_INITIALIZATION_STATE		0x06
#define	JS_JOIN_COMPLETE_STATE			0x07
#define	JS_BYPASS_WAIT_STATE			0x08

/******************************************
 * Definitions for the field MONITOR_STATE
 ******************************************
 */

#define MS_MONITOR_FSM_INACTIVE			0x00
#define MS_REPEAT_BEACON_STATE			0x01
#define MS_REPEAT_CLAIM_TOKEN_STATE		0x02
#define MS_TRANSMIT_CLAIM_TOKEN_STATE		0x03
#define MS_STANDBY_MONITOR_STATE		0x04
#define MS_TRANSMIT_BEACON_STATE		0x05
#define MS_ACTIVE_MONITOR_STATE			0x06
#define MS_TRANSMIT_RING_PURGE_STATE		0x07
#define MS_BEACON_TEST_STATE			0x09

/********************************************
 * Definitions for the bit-field RING_STATUS
 ********************************************
 */ 

#define SIGNAL_LOSS                     	0x8000
#define HARD_ERROR                      	0x4000
#define SOFT_ERROR                      	0x2000
#define TRANSMIT_BEACON                 	0x1000
#define LOBE_WIRE_FAULT                 	0x0800
#define AUTO_REMOVAL_ERROR              	0x0400
#define REMOVE_RECEIVED                 	0x0100
#define COUNTER_OVERFLOW                	0x0080
#define SINGLE_STATION                  	0x0040
#define RING_RECOVERY                   	0x0020

/************************************
 * Definitions for the field BUS_TYPE
 ************************************
 */
#define AT_BUS                  0x00
#define MCA_BUS                 0x01
#define EISA_BUS                0x02
#define PCI_BUS                 0x03
#define PCMCIA_BUS              0x04

/************************
 * Defs for adapter_flags 
 ************************
 */

#define RX_VALID_LOOKAHEAD      0x0001
#define FORCED_16BIT_MODE       0x0002
#define ADAPTER_DISABLED        0x0004
#define TRANSMIT_CHAIN_INT      0x0008
#define EARLY_RX_FRAME          0x0010
#define EARLY_TX                0x0020
#define EARLY_RX_COPY           0x0040
#define USES_PHYSICAL_ADDR      0x0080
#define NEEDS_PHYSICAL_ADDR     0x0100
#define RX_STATUS_PENDING       0x0200
#define ERX_DISABLED            0x0400
#define ENABLE_TX_PENDING	0x0800
#define ENABLE_RX_PENDING	0x1000
#define PERM_CLOSE		0x2000	/* For PCMCIA LM_Close_Adapter */
#define IO_MAPPED		0x4000	// IO mapped bus interface (795)
#define ETX_DISABLED            0x8000


/*************************
 * Defs for adapter_flags1
 *************************
 */

#define TX_PHY_RX_VIRT          0x0001
#define NEEDS_HOST_RAM          0x0002
#define NEEDS_MEDIA_TYPE        0x0004


/***********************
 * Adapter Status Codes
 ***********************
 */
 
#define OPEN                    0x0001
#define INITIALIZED             0x0002
#define CLOSED                  0x0003  
#define FAILED                  0x0005
#define NOT_INITIALIZED         0x0006
#define IO_CONFLICT             0x0007
#define CARD_REMOVED            0x0008
#define CARD_INSERTED           0x0009

/************************
 * Mode Bit Definitions
 ************************
 */

#define INTERRUPT_STATUS_BIT    0x8000  /* PC Interrupt Line: 0 = Not Enabled */
#define BOOT_STATUS_MASK        0x6000  /* Mask to isolate BOOT_STATUS */
#define BOOT_INHIBIT            0x0000  /* BOOT_STATUS is 'inhibited' */
#define BOOT_TYPE_1             0x2000  /* Unused BOOT_STATUS value */
#define BOOT_TYPE_2             0x4000  /* Unused BOOT_STATUS value */
#define BOOT_TYPE_3             0x6000  /* Unused BOOT_STATUS value */
#define ZERO_WAIT_STATE_MASK    0x1800  /* Mask to isolate Wait State flags */
#define ZERO_WAIT_STATE_8_BIT   0x1000  /* 0 = Disabled (Inserts Wait States) */
#define ZERO_WAIT_STATE_16_BIT  0x0800  /* 0 = Disabled (Inserts Wait States) */
#define LOOPING_MODE_MASK       0x0007
#define LOOPBACK_MODE_0         0x0000
#define LOOPBACK_MODE_1         0x0001
#define LOOPBACK_MODE_2         0x0002
#define LOOPBACK_MODE_3         0x0003
#define LOOPBACK_MODE_4         0x0004
#define LOOPBACK_MODE_5         0x0005
#define LOOPBACK_MODE_6         0x0006
#define LOOPBACK_MODE_7         0x0007
#define AUTO_MEDIA_DETECT		  0x0008
#define MANUAL_CRC              0x0010
#define EARLY_TOKEN_REL         0x0020  // Early Token Release for Token Ring
#define NDIS_UMAC               0x0040  // Indicates to LMAC that UMAC is NDIS.
#define	UTP2_PORT		0x0080	// For 8216T2, 0=port A, 1=Port B.
#define BNC_10BT_INTERFACE		  0x0600	 // BNC and UTP current media set
#define UTP_INTERFACE           0x0500  // Ethernet UTP Only.
#define BNC_INTERFACE           0x0400
#define AUI_INTERFACE           0x0300
#define AUI_10BT_INTERFACE      0x0200
#define STARLAN_10_INTERFACE    0x0100
#define INTERFACE_TYPE_MASK     0x0700

/****************************
  Media Type Bit Definitions
 ****************************
 *
 * legend:      TP = Twisted Pair
 *              STP = Shielded twisted pair
 *              UTP = Unshielded twisted pair
 */

#define CNFG_MEDIA_TYPE_MASK    0x001e  /* POS Register 3 Mask         */

#define MEDIA_S10               0x0000  /* Ethernet adapter, TP.        */
#define MEDIA_AUI_UTP           0x0001  /* Ethernet adapter, AUI/UTP media */
#define MEDIA_BNC               0x0002  /* Ethernet adapter, BNC media. */
#define MEDIA_AUI               0x0003  /* Ethernet Adapter, AUI media. */
#define MEDIA_STP_16            0x0004  /* TokenRing adap, 16Mbit STP.  */
#define MEDIA_STP_4             0x0005  /* TokenRing adap, 4Mbit STP.   */
#define MEDIA_UTP_16            0x0006  /* TokenRing adap, 16Mbit UTP.  */
#define MEDIA_UTP_4             0x0007  /* TokenRing adap, 4Mbit UTP.   */
#define MEDIA_UTP               0x0008  /* Ethernet adapter, UTP media (no AUI) */
#define MEDIA_BNC_UTP           0x0010  /* Ethernet adapter, BNC/UTP media */
#define MEDIA_UTPFD             0x0011  /* Ethernet adapter, TP full duplex */
#define MEDIA_UTPNL             0x0012  /* Ethernet adapter, TP with link integrity test disabled */
#define MEDIA_AUI_BNC           0x0013  /* Ethernet adapter, AUI/BNC media */
#define MEDIA_AUI_BNC_UTP       0x0014  /* Ethernet adapter, AUI_BNC/UTP */
#define MEDIA_UTPA              0x0015  /* Ethernet UTP-10Mbps Ports A */
#define MEDIA_UTPB              0x0016  /* Ethernet UTP-10Mbps Ports B */
#define MEDIA_STP_16_UTP_16     0x0017  /* Token Ring STP-16Mbps/UTP-16Mbps */
#define MEDIA_STP_4_UTP_4       0x0018  /* Token Ring STP-4Mbps/UTP-4Mbps */

#define MEDIA_STP100_UTP100     0x0020  /* Ethernet STP-100Mbps/UTP-100Mbps */
#define MEDIA_UTP100FD          0x0021  /* Ethernet UTP-100Mbps, full duplex */
        

#define MEDIA_UNKNOWN           0xFFFF  /* Unknown adapter/media type   */

/****************************************************************************
 * Definitions for the field:
 * bic_type (Bus interface chip type)
 ****************************************************************************
 */

#define BIC_NO_CHIP             0x0000  /* Bus interface chip not implemented */
#define BIC_583_CHIP            0x0001  /* 83C583 bus interface chip */
#define BIC_584_CHIP            0x0002  /* 83C584 bus interface chip */
#define BIC_585_CHIP            0x0003  /* 83C585 bus interface chip */
#define BIC_593_CHIP            0x0004  /* 83C593 bus interface chip */
#define BIC_594_CHIP            0x0005  /* 83C594 bus interface chip */
#define BIC_564_CHIP            0x0006  /* PCMCIA Bus interface chip */
#define BIC_790_CHIP            0x0007  /* 83C790 bus i-face/Ethernet NIC chip */
#define BIC_571_CHIP            0x0008  /* 83C571 EISA bus master i-face */
#define BIC_587_CHIP            0x0009  /* Token Ring AT bus master i-face */
#define BIC_574_CHIP            0x0010  /* FEAST bus interface chip */
#define BIC_8432_CHIP           0x0011  /* 8432 bus i-face/Ethernet NIC(DEC PCI) */
#define BIC_9332_CHIP           0x0012  /* 9332 bus i-face/100Mbps Ether NIC(DEC PCI) */
        

/****************************************************************************
 * Definitions for the field:
 * nic_type (Bus interface chip type)
 ****************************************************************************
 */
#define NIC_UNK_CHIP            0x0000  /* Unknown NIC chip      */
#define NIC_8390_CHIP           0x0001  /* DP8390 Ethernet NIC   */
#define NIC_690_CHIP            0x0002  /* 83C690 Ethernet NIC   */
#define NIC_825_CHIP            0x0003  /* 83C825 Token Ring NIC */
/*      #define NIC_???_CHIP    0x0004  */ /* Not used           */
/*      #define NIC_???_CHIP    0x0005  */ /* Not used           */
/*      #define NIC_???_CHIP    0x0006  */ /* Not used           */
#define NIC_790_CHIP            0x0007  /* 83C790 bus i-face/Ethernet NIC chip */
#define NIC_C100_CHIP           0x0010  /* FEAST 100Mbps Ethernet NIC */
#define NIC_8432_CHIP           0x0011  /* 8432 bus i-face/Ethernet NIC(DEC PCI) */
#define NIC_9332_CHIP           0x0012  /* 9332 bus i-face/100Mbps Ether NIC(DEC PCI) */


/****************************************************************************
 * Definitions for the field:
 * adapter_type The adapter_type field describes the adapter/bus
 *              configuration.
 *****************************************************************************
 */
#define BUS_UNK_TYPE            0x0000  /*  */
#define BUS_ISA16_TYPE          0x0001  /* 16 bit adap in 16 bit (E)ISA slot  */
#define BUS_ISA8_TYPE           0x0002  /* 8/16b adap in 8 bit XT/(E)ISA slot */
#define BUS_MCA_TYPE            0x0003  /* Micro Channel adapter              */
#define BUS_EISA32M_TYPE        0x0004  /* EISA 32 bit bus master adapter     */
#define BUS_EISA32S_TYPE        0x0005  /* EISA 32 bit bus slave adapter      */
#define BUS_PCMCIA_TYPE         0x0006  /* PCMCIA adapter */
#define BUS_PCI_TYPE            0x0007  /* PCI bus */


/***************************
 * Receive Mask definitions
 ***************************
 */

#define ACCEPT_MULTICAST        	0x0001
#define ACCEPT_BROADCAST        	0x0002
#define PROMISCUOUS_MODE        	0x0004
#define ACCEPT_SOURCE_ROUTING   	0x0008
#define ACCEPT_ERR_PACKETS      	0x0010
#define ACCEPT_ATT_MAC_FRAMES   	0x0020
#define ACCEPT_MULTI_PROM       	0x0040
#define TRANSMIT_ONLY           	0x0080
#define ACCEPT_EXT_MAC_FRAMES   	0x0100
#define EARLY_RX_ENABLE         	0x0200
#define	PKT_SIZE_NOT_NEEDED		0x0400
#define	ACCEPT_SOURCE_ROUTING_SPANNING	0x0808

#define ACCEPT_ALL_MAC_FRAMES   	0x0120

/****************************        
 config_mode defs
****************************/

#define STORE_EEROM             0x0001  // Store config in EEROM.
#define STORE_REGS              0x0002  // Store config in register set.

//////////////////////////////////////////////////////////
// equates for lmac_flags in adapter structure (Ethernet)
//////////////////////////////////////////////////////////

#define		MEM_DISABLE	0x0001		
#define		RX_STATUS_POLL	0x0002
#define		USE_RE_BIT	0x0004
//#define	RESERVED	0x0008
//#define	RESERVED	0x0010	
//#define	RESERVED	0x0020
//#define	RESERVED	0x0040
//#define	RESERVED	0x0080
//#define	RESERVED	0x0100
//#define	RESERVED	0x0200
//#define	RESERVED	0x0400
//#define	RESERVED	0x0800
//#define	RESERVED	0x1000
//#define	RESERVED	0x2000
//#define	RESERVED	0x4000
//#define	RESERVED	0x8000

// media_opts & media_set Fields bit defs for Ethernet ...
#define		MED_OPT_BNC	0x01
#define		MED_OPT_UTP	0x02
#define		MED_OPT_AUI	0x04
#define		MED_OPT_10MB	0x08
#define		MED_OPT_100MB	0x10
#define		MED_OPT_S10	0x20

// media_opts & media_set Fields bit defs for Token Ring ...
#define		MED_OPT_4MB	0x08
#define		MED_OPT_16MB	0x10
#define		MED_OPT_STP	0x40

#define CS_SIG                  0x5343  // ASCII 'CS' 
#define SMC_PCMCIA_ID           0x0108  // SMC ID Byte value.
#define IO_PORT_RANGE           0x0020  // Number of IO Ports.  
#define ENABLE_IRQ_STEER        0x0002  // For ReqCfgStruct.ReqCfgAttributes
#define FIVE_VOLTS              50      // For ReqCfgStruct.ReqCfgVcc, .Vpp1, .Vpp2
#define TWELVE_VOLTS            120     // For ReqCfgStruct.ReqCfgVcc, .Vpp1, .Vpp2
#define MEM_AND_IO              0x0002  // For ReqCfgStruct.ReqCfgIntType
#define ATTRIBUTE_REG_OFFSET    0x0001  // Hi word of offset of attribute registers
#define REG_COR_VALUE           0x0041  // Value for Config Option Register
#define REGS_PRESENT_VALUE      0x000F  // Value for ReqCfgStruct.ReqCfgPresent
#define LEVEL_IRQ               0x0020  // For ReqIrqStruct.IRQInfo1
#define IRQ_INFO2_VALID         0x0010  // For ReqIrqStruct.IRQInfo1
#define VALID_IRQS              0x8EBC  // For ReqIrqStruct.IRQInfo2
#define OFFSET_SHARED_MEM       0x0002  // Hi word of shared ram offset
#define OFFSET_REGISTER_MEM     0x0003  // Hi word of register memory offset
#define OFFSET_SHMEM_HI         0x0002  // Hi word of shared ram offset
#define OFFSET_SHMEM_LO         0x0000  // Lo word of shared ram offset
#define AMD_ID                  0xA701  // Mfg/Product ID for AMD flash ROM
#define ATMEL_ID                0xD51F  // Mfg/Product ID for ATMEL flash ROM
#define SHMEM_SIZE              0x4000  // Size of shared memory device.
#define SHMEM_NIC_OFFSET        0x0100  // Offset of start of shared memory space for NIC.
#define REG_OFFSET              0x0000  // Offset of PCM card's mem-mapped register set.

#define MAX_8023_SIZE           1500    // Max 802.3 size of frame.
#define DEFAULT_ERX_VALUE       4       // Number of 16-byte blocks for 790B early Rx.
#define DEFAULT_ETX_VALUE       32      // Number of bytes for 790B early Tx.
#define DEFAULT_TX_RETRIES      3       // Number of transmit retries
#define LPBK_FRAME_SIZE         1024    // Default loopback frame for Rx calibration test.
#define MAX_LOOKAHEAD_SIZE      252     // Max lookahead size for ethernet.

//
// FEAST EISA definitions
//
#define EISA_SLAVE_DMA_CUTOFF   128     // DMA threshold

