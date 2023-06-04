if LANGUAGE eq US_ENGLISH
	public	usage_msg, copyright_msg

bad_key_msg		db	"Unknown keyword on the command line.", CR,LF
usage_msg	label	byte
	db "usage: ",short_name
 	db " [options] <packet_int_no> <slot_no> {connector} {speed} {duplex}",CR,LF
	db "connector=[AUTO|UTP|BNC|AUI] speed=[SLOW|FAST] duplex=[HALF|FULL]",CR,LF,'$'
copyright_msg	label byte
	db "Packet driver for ",long_name,", version "
	db '0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
	db "Supports: PCI.",CR,LF
	db "Portions written by Morien W. Roberts; "

need_pci_msg		db	"A PCI BIOS is required for this driver.",CR,LF,'$'
irq_problem_msg		db	"Problem reading IRQ from PCI configuration.",CR,LF,'$'
self_test_msg		db	"Performing self test of chip....",'$'
self_test_ok_msg	db	"     PASSED.",CR,LF,'$'
self_test_no_msg	db	"     FAILED.",CR,LF,'$'
virtual_services	db	"Using virtual memory services of memory manager."
					db	CR,LF,'$'
no_virtual_services	db	"Not using any memory manager services.",CR,LF,'$'
problem_in_phys_add	db	"Problem with virtual memory services.",CR,LF,'$'
if	CHIP EQ INTEL_82596
iscp_init_problem	db	"Problem with ISCP command.",CR,LF,'$'
else
load_base_msg		db	"Config failure - loading base registers.",CR,LF,'$'
fix_root_msg		db	"Multicast setup workaround used for ",'$'
fix_10bits			db	"10 Mbits",CR,LF,'$'
fix_100bits			db	"100 Mbits",CR,LF,'$'
fix_both			db	"both 10 Mbits and 100 Mbits",CR,LF,'$'
support_10_msg		db	"This board only supports 10 Mbits", CR,LF,'$'
support_100_msg		db	"This board supports 100 Mbits", CR,LF,'$'
phy_dev_code_0		db	"No PHY device installed",CR,LF,'$'
phy_dev_code_1		db	"Intel 82553 (PHY 100) A or B step",CR,LF,'$'
phy_dev_code_2		db	"Intel 82553 (PHY 100) C step",CR,LF,'$'
phy_dev_code_3		db	"Intel 82503 10Mps",CR,LF,'$'
phy_dev_code_4		db	"National DP83840 100BASE-TX, C step",CR,LF,'$'
phy_dev_code_5		db	"Seeq 80C240 - 100BASE-T4",CR,LF,'$'
phy_dev_code_6		db	"Seeq 80C24 - 10Mps",CR,LF,'$'
phy_dev_code_7		db	"Intel 82555",CR,LF,'$'
phy_dev_code_8		db	"Unknown-8",CR,LF,'$'
phy_dev_code_9		db	"Unknown-9",CR,LF,'$'
phy_dev_code_10		db	"Unknown-10",CR,LF,'$'
phy_dev_code_11		db	"Unknown-11",CR,LF,'$'
phy_dev_code_X		db	"Unknown",CR,LF,'$'
phys_1_msg			db	"PHY device 1 - ",'$'
phys_2_msg			db	"PHY device 2 - ",'$'
no_support_p_layer	db	"PHY device not supported in this driver",CR,LF,'$'
no_support_2_phy	db	"This driver does not support 2 PHY devices",CR,LF,'$'
tx_full_msg		db	"Negotiated speed 100Mbs (100Base-TX) full duplex",CR,LF,'$'
t4_half_msg		db	"Negotiated speed 100Mbs (100Base-T4) half duplex",CR,LF,'$'
tx_half_msg		db	"Negotiated speed 100Mbs (100Base-TX) half duplex",CR,LF,'$'
t_full_msg		db	"Negotiated speed 10Mbs (10Base-T) full duplex",CR,LF,'$'
t_half_msg		db	"Negotiated speed 10Mbs (10Base-T) half duplex",CR,LF,'$'
def_10_half_msg		db	"Using 10Mbs link at half duplex",CR,LF,'$'
def_10_full_msg		db	"Using 10Mbs link at full duplex",CR,LF,'$'
def_100_half_msg	db	"Using 100Mbs link at half duplex",CR,LF,'$'
def_100_full_msg	db	"Using 100Mbs link at full duplex",CR,LF,'$'
frcd_10_half_msg	db	"FORCED 10Mbs link at half duplex",CR,LF,'$'
frcd_10_full_msg	db	"FORCED 10Mbs link at full duplex",CR,LF,'$'
frcd_100_half_msg	db	"FORCED 100Mbs link at half duplex",CR,LF,'$'
frcd_100_full_msg	db	"FORCED 100Mbs link at full duplex",CR,LF,'$'
wait_neg_msg		db	"Waiting for negotiation to complete ",'$'
no_lp_msg		db	"Link partner does not support negotiation",CR,LF,'$'
negotiation_problem	db	CR,LF,"* * * * * * * "
					db	"WARNING - NWAY negotiation failed to complete "
					db	"* * * * * * *",CR,LF,'$'
no_neg_bits_msg	db	"ERROR - Link partner negotiatied no capabilities",CR,LF,'$'
no_common_capability	db "No common link capability",CR,LF,'$'
auto_detect_nr_msg	db	"AUTO DETECT OF MEDIA "
					db	"NOT YET AVAILABLE FOR THIS CARD",CR,LF,'$'
endif
config_msg 			db	"Config failure - config operation failed.",CR,LF,'$'
ether_add_msg		db	"Config failure - setting ethernet address.",CR,LF,'$'
int_no_name			db	"Interrupt number ",'$'
base_addr_name		db	"I/O port ",'$'
separator1_msg		db	", $"
separator3_msg		db	" & $"
specified_failed 	db	"An ",long_name
					db	" was not found at specified address.",CR,LF,'$'
scan_failed 		db	"Scan of I/O space did not find ",long_name,CR,LF,'$'
reading_eeprom_chksum	db	"Reading EEPROM and calculating checksum...",'$'
eeprom_chksum_bad	db	CR,LF,"EEPROM Failed checksum validation; ",CR,LF,'$'

using_auto_msg	db	"Auto detecting media",CR,LF,'$'
using_10B_T_msg	db	"Using twisted pair cable",CR,LF,'$'
using_AUI_msg	db	"Using AUI interface",CR,LF,'$'
using_10B_2_msg	db	"Using coax cable",CR,LF,'$'

	public ether_add_msg1, ether_add_msg2
ether_add_msg1		db	"Config failure - ethernet 1.",CR,LF,'$'
ether_add_msg2		db	"Config failure - ethernet 2.",CR,LF,'$'
endif
