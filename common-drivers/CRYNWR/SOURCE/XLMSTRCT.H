//
//    XLMSTRCT.H
//

typedef struct
{
   char lan_addr[6];
   char id_byte;
   char la_checksum;
   char la_sum;
   char la_pad_byte;
} Lan_Addr_Rom;

typedef struct
{
   unsigned short test_type;
   unsigned short test_flags;
   unsigned short access_size;
   unsigned short not_used;
} Test_Mode;

typedef struct
{   
   unsigned long far *ptr_tx_aborts;
   unsigned long far *ptr_tx_overlapped;
   unsigned long far *ptr_deferring;
   unsigned long far *ptr_rx_disabled;
   unsigned long far *ptr_runt_pkts;
   unsigned long far *ptr_bad_next_pp;
} Statix;

typedef struct
{   
   unsigned short ram_offset;       // RAM offset address 
   unsigned short ram_length;       // RAM length to be tested 
   unsigned short w_pattern;        // Write pattern for RAM test
   unsigned short r_pattern;        // Read pattern for RAM test.
   Test_Mode ram_test_mode;         // RAM test modes
   unsigned long  count;            // Ram test iterations.
   unsigned short LANAd_instance;
   Lan_Addr_Rom LANAd_register;     // Contents of LAN address register */
   Lan_Addr_Rom LANAd_eerom0;       // Contents of Bank 9 EEROM
   Lan_Addr_Rom LANAd_eerom1;       // Contents of Bank B EEROM
   unsigned short micro_code_rev;   // Revision of Token Ring micro code
   Statix statistics;               // Extra statistics
   char brom_hold;                  // 
   char bic_test_array[8];          //
   char loopback_mode;              //
   unsigned long CollTable[16];     //
} ExtAdapterStructure;

// General Equates 

#define NIC_TEST_PATTERN      0x5A
#define TEST_BYTE_NUL         0x00  // If this value is used for BIC register 
                                    //  test, the register is not tested.

// Equates for test_mode.test_type
#define ROM_SIGNATURE_TEST    0x01
#define SPACE_TEST            0x02
#define READ_WRITE_TEST       0x04
#define RW_IO_TEST            0x08

// Equates for test_mode.test_flags
#define NO_LOOP               0x01
#define LOOP_FOR_COUNT        0x02
#define CUSTOM_PATTERN        0x04

// Equates for test_mode.access_size
#define BYTE_ACCESS           0x01
#define WORD_ACCESS           0x02


// Equates used by LM_SelectRom
#define SELECT                1
#define DESELECT              0

