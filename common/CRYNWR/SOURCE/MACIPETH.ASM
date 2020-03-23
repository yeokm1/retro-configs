version equ     1

	include	defs.asm

; PC/FTP Packet Driver source, conforming to version 1.09 of the spec
; Katie Stevens (dkstevens@ucdavis.edu)
; Computing Services, University of California, Davis
; Portions (C) Copyright 1988 Regents of the University of California

; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, version 1.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
; GNU General Public License for more details.

; Change History
;
; 05-90		ks	Katie Stevens (dkstevens@ucdavis.edu):
;			- Created
; 07-19-91	jgn	Jim Noble (noble_jim@po.gis.prc.com):
;			- Added Change History and documented changes
;			- Fixed a bug that caused AppleTalk network numbers to
;			  be byte-swapped when printed
;			- Fixed a bug that caused the wrong buffer address to 
;			  be passed to the packet receiver upcall routine
;			- Made changes in the driver information structure to 
;			  match LocalTalk:  size of MAC-layer address, MTU,
;			  and multicast buffer size
;			- Changed the packet buffer sizes from 1024 to 586,
;			  the maximum amount of data in a DDP packet
;			- Commented-out the noop_upcall completion routine and
;			  changed the completion routine address passed to
;			  the AppleTalk driver to 0000:0000 for all driver
;			  calls
;			- Set the status field to -1 prior to the GetNetInfo
;			  AppleTalk driver call as per the recommendation of
;			  the driver interface spec.
;			- Added structure definitions for short and long 
;			  format DDP packets and used them when adding a
;			  check to ensure that received packets are IP packets
; 07-22-91	jgn	Jim Noble (noble_jim@po.gis.prc.com):
;			- Fixed a bug that would prevent the packet driver
;			  from initializing with a static address if there
;			  were no dynamic addresses available
; 07-23-91	jgn	Jim Noble (noble_jim@po.gis.prc.com):
;			- Added the optional IP address to the usage message
;			- Incremented version to 3
; 06-29-99      etf     Edwin Fukunaga (fukunaga@sky.net):
;                       - Considered changing the name of the driver from
;                         LOCALTLK.COM to MACIP.COM to reflect more exactly
;                         what it does, and to suggest that MacIP runs on
;                         AppleTalk networks that use any type of hardware
;                         (not only LocalTalk)
;                       - Made changes in etopen and send_pkt to cause the
;                         driver to operate without a gateway when a static
;                         address is included in the command line, per MacIP
;                         spec published by Apple Computer, Inc. in 11/94
;                         (this removed the ability to use a gateway with a
;                         static address; those who need it should use version
;                         3 or write version 5.)
;                       - Incremented version to 4
; 07-08-99      etf     Edwin Fukunaga (fukunaga@sky.net):
;                       - Reinstated the ability to use a gateway with a
;                         static address; now typing the -s switch after the
;                         address on the command line causes the driver to
;                         operate without a gateway (-s switch added to
;                         usage_msg and parse_args.)
;                       - Incremented version to 5
; 07-24-99      etf     Edwin Fukunaga (fukunaga@sky.net):
;                       - Added the ability to pretend to be a Class 1
;                         (Bluebook ethernet) driver, by modifying send_pkt,
;                         parse_args, and recv_at_upcall; typing the -e switch
;                         after the software interrupt on the command line
;                         causes the driver to run in Class 1 mode
;                       - Incremented version to 6
; 07-31-99      etf     Edwin Fukunaga (efukunag@umich.edu):
;                       - Reduced network traffic in gatewayless mode by
;                         storing addresses discovered through NBP ARP in a
;                         table, and reusing a given entry until ten idle
;                         minutes pass
;                       - Placed NBP ARP resolution code in a separate
;                         procedure, which is called from send_pkt when needed
;                       - Added new_timer_isr code for aging the NBP ARP table
;                       - Incremented version to 7
; 06-20-2000    etf     Edwin Fukunaga (efukunag@umich.edu):
;                       - Removed the Class 1 mode (it will be provided by a
;                         separate driver named MACIPETH.COM).  Hopefully this
;                         will simplify source code and driver use.  As a
;                         result, version 8 is version 5 with the improvements
;                         of version 7, plus a few others:
;                       - Fixed the failure to remove new_timer_isr from the
;                         interrupt vector table upon aborting of gatewayless
;                         inits (admittedly, a dangerous mistake on my part)
;                       - Changed command-line parameters to (hopefully) make
;                         them more intuitive: -g causes the affirmation of
;                         gateway use (rather than the negation of gateway use
;                         caused by -s, which -g replaces)
;                       - Modified behavior of send_pkt so that after
;                         resolving a previously unknown destination address,
;                         the packet containing that address is sent rather
;                         than dropped (see a note written within send_pkt)
;                       - Incremented version to 8
;                       - I have realized (at long last) that send_no_gateway
;                         has a serious design limitation: because all of its
;                         packet forwarding is based upon final-destination IP
;                         addresses, send_no_gateway is unable to send a
;                         packet even one hop beyond the MacIP network.  This
;                         will be fixed in MACIPETH.COM, but in the Class 5
;                         driver, because of the fact that client applications
;                         never look at address resolution information, it
;                         appears difficult or impossible to fix completely.
;                         It may be possible to send all undeliverable packets
;                         to a default location (i.e. a router), at the very
;                         least.  Maybe in version 9.
; 06-26-2000    etf     Edwin Fukunaga (efukunag@umich.edu):
;                       - Removed Class 5 mode and re-added Class 1 mode
;                       - Redesigned send_pkt and send_arp_response to resolve
;                         the limitation described above; now outgoing packets
;                         are addressed based upon their destination ethernet
;                         addresses, each of which is mapped to a destination
;                         AppleTalk node in the NBP ARP table
;                       - Added command-line parameter <ARP TTL>, which allows
;                         the user to control when NBP ARP table entries
;                         expire (meant to alleviate the problem described in
;                         send_pkt, one of the three mentioned next)
;                       - Documented three potential problems: see send_pkt,
;                         send_arp_response, and recv_at_upcall
;                       - Added to send_pkt a check for padding in small IP
;                         packets, put there by the IP layer to meet minimum
;                         data field length of an ethernet frame (46 bytes)
;                       - Renamed the driver MACIPETH.COM, version 1

code	segment	word public
	assume	cs:code, ds:code

; Definitions specific to the ATALK.SYS driver for PC LocalTalk cards:
; these include Apple LocalTalk PC Card, Sun/TOPS FlashCard
; For a complete description of the LocalTalk commands, structures and
; methods used in this driver, please refer to Apple APDA document #M7055,
; LocalTalk PC Card and Driver Preliminary Notes.

driverstring	db	'AppleTalk', 0		; ATALK.SYS signature string
dot_char	db	'.', 0			; for IP address display

AT_INT		equ	5CH			; Software int# for ATALK.SYS

; General ATALK.SYS driver commands
AT_INIT			equ	01H		; Initialize driver software
AT_GETNETINFO		equ	03H		; Get driver info

; Datagram Delivery Protocol commands for ATALK.SYS driver
DDP_OPENSOCKET		equ	20H
DDP_CLOSESOCKET		equ	21H
DDP_WRITE		equ	22H
DDP_READ		equ	23H
DDP_CANCEL		equ	24H

; Name Binding Protocol commands for ATALK.SYS driver
NBP_REGISTER		equ	30H
NBP_REMOVE		equ	31H
NBP_LOOKUP		equ	32H
NBP_CONFIRM		equ	33H
NBP_CANCEL		equ	34H

; AppleTalk Transaction Protocol commands for ATALK.SYS driver
ATP_SEND_REQUEST	equ	42H

; ATALK.SYS command qualifiers
ASYNC_MASK	equ	8000H		; Start command, then return
INTR_MASK	equ	4000H		; Wait for intr service to complete

XO_BIT		equ	20H		; ATP - exactly once transaction

; Structure for short format DDP packet [jgn]
DDPshort struc
	lap_dst		db	?	; destination node
	lap_src		db	?	; source node
	lap_type	db	?	; 1 for short format DDP packet
	ddps_len	dw	?	; packet length
	ddps_dskt	db	?	; destination socket
	ddps_sskt	db	?	; source socket
	ddps_type	db	?	; 22 for IP packets
DDPshort ends

; Structure for long format DDP packet [jgn]
DDPlong struc
	lap_dst		db	?	; destination node
	lap_src		db	?	; source node
	lap_type	db	?	; 2 for long format DDP packets
	ddpl_len	dw	?	; packet length
	ddpl_chksum	dw	?	; checksum
	ddpl_dnet	dw	?	; destination network
	ddpl_snet	dw	?	; source network
	ddpl_dnode	db	?	; destination node
	ddpl_snode	db	?	; source node
	ddpl_dskt	db	?	; destination socket
	ddpl_sskt	db	?	; source socket
	ddpl_type	db	?	; 22 for IP packets
DDPlong ends

; Structure for AppleTalk node addressing
AddrBlk struc
	ablk_network	dw	0
	ablk_nodeid	db	0
	ablk_socket	db	0
AddrBlk ends

; Structure for general calls to AppleTalk driver (ATALK.SYS)
InfoParams struc
	atd_command	dw		AT_GETNETINFO
	atd_status	dw		0
	atd_compfun	segmoffs	<>
	inf_network	dw		0
	inf_nodeid	db		0
	inf_abridge	db		0
	inf_config	dw		0
	inf_buffptr	segmoffs	<>
	inf_buffsize	dw		0
InfoParams ends
; Parameter block for general calls to AppleTalk driver (ATALK.SYS)
MyInfo	InfoParams	<>

; Address block for our gateway
MyGateway	AddrBlk		<>

; Structure for calls to AppleTalk driver (ATALK.SYS) for Datagram
; Delivery Protocol (DDP) service
DDPParams struc
	ddp_command	dw		0
	ddp_status	dw		0
	ddp_compfun	segmoffs	<>
	ddp_addr	AddrBlk		<>
	ddp_socket	db		0
	ddp_type	db		0
	ddp_buffptr	segmoffs	<>
	ddp_buffsize	dw		0
	ddp_chksum	db		0
DDPParams ends
; Parameter blocks for AppleTalk DDP access
DDPio		DDPParams	<>		; Write on DDP socket
; 2 buffers for packet receive from ATALK.SYS
DDP1inuse	db	0			; Buffer occupied flag
DDP1buffsize	dw	0			; Buffer length during reads
; ethernet header: 6-byte dest addr, 6-byte src addr, 2-byte ethertype [etf]
header1         db      0,0,0C0H,0DH,0D4H,27H,0,0,0C0H,0DH,0D4H,28H,08H,0
DDP1buffer	db	586 dup (0)		; Buffer for DDP read [jgn]
DDP2inuse	db	0			; 2nd Buffer occupied flag
DDP2buffsize	dw	0			; 2nd Buffer length during reads
; ethernet header: 6-byte dest addr, 6-byte src addr, 2-byte ethertype [etf]
header2         db      0,0,0C0H,0DH,0D4H,27H,0,0,0C0H,0DH,0D4H,28H,08H,0
DDP2buffer	db	586 dup (0)		; 2nd Buffer for DDP read [jgn]

; Structure for calls to AppleTalk driver (ATALK.SYS) for Name
; Binding Protocol (NBP) service
NBPParams struc
	nbp_command	dw		0
	nbp_status	dw		0
	nbp_compfun	segmoffs	<>
	nbp_addr	AddrBlk		<>
	nbp_toget	dw		0
	nbp_buffptr	segmoffs	<>
	nbp_buffsize	dw		0
	nbp_interval	db		0
	nbp_retry	db		0
	nbp_entptr	segmoffs	<>
NBPParams ends
; Parameter block for AppleTalk NBP access
NBP		NBPParams	<>

; Structure for name-to-address bind entries
NBPTuple struc
	tup_address	AddrBlk		<>
	tup_enum	db		0
	tup_name	db		99 dup(0)
NBPTuple ends
; Name Binding Tuple for our IP gateway
; Used as NBP buffer in gatewayless mode, in etopen. [etf]
; NBPt.tup_name used in nbp_arp_resolve (called only in gatewayless mode)
;   for storing the dest IP address as a string.  Versions 4, 5, and 6 used a
;   separate variable named NBP_ARP_string. [etf]
NBPt		NBPTuple	<>

; myip_name and myip_name_len moved to resident in version 4. [etf]
myip_name:
	db	09H, "IPADDRESS", 01H, '*', '0'
myip_name_len	equ	12

; Structure for name-to-address table
NBPEntry struc
	tab_next	segmoffs	<>
	tab_entry	NBPTuple	<>
NBPEntry ends
NBPtable	NBPEntry	<>

; Structure for NBP ARP table [etf]
NBP_ARP_entry     struc
        time_left       db      0
        ipaddr          db      0, 0, 0, 0
        tuple           NBPTuple        <>
;       last byte of ethaddr in each entry is filled in during initialization
;       and used as an index into the NBP_ARP_table
        ethaddr         db      0,0,0C0H,0DH,0D4H,0   ; new in macipeth v1
NBP_ARP_entry     ends
NBP_ARP_tab_len         equ     20
NBP_ARP_table   NBP_ARP_entry   NBP_ARP_tab_len dup(<>)

end_NBP_ARP_table       label   byte    ; like end_handles in head.asm [etf]

ARP_TTL                 db      20      ; time out table entries after 20 min
                                        ; or duration entered on command line

free_arp_entry          dw      0       ; temp, points to an entry not in use
                                        ; or the oldest entry still in use

nbp_arp_temp_ipaddr     db      0, 0, 0, 0      ; temp for NBP ARP [etf]

; Structure for calls to AppleTalk driver (ATALK.SYS) for AppleTalk
; Transaction Protocol (ATP) service
ATPParams struc
	atp_command	dw		0
	atp_status	dw		0
	atp_compfun	segmoffs	<>
	atp_addrblk	AddrBlk		<>
	atp_socket	db		0
	atp_fill	db		0
	atp_buffptr	segmoffs	<>
	atp_buffsize	dw		0
	atp_interval	db		0
	atp_retry	db		0
	atp_flags	db		0
	atp_seqbit	db		0
	atp_tranid	dw		0
	atp_userbytes	db		4 dup(0)
	atp_bdsbuffs	db		0
	atp_bdsresps	db		0
	atp_bdsptr	segmoffs	<>
ATPParams ends
; Parameter block for AppleTalk ATP access
ATP		ATPParams	<>

; Structure for BDS elements
BDSElement struc
	bds_buffptr	segmoffs	<>
	bds_buffsize	dw		0
	bds_datasize	dw		0
	bds_userbytes	db		4 dup(0)
BDSElement ends
; Parameter block for our BDS element
BDS		BDSElement	<>

; Struct for IP gateway information
; The uses of the fields in this structure do not match the MacIP spec, but
; that should only make the dynamic-init feedback incorrect, and not affect
; operation.  [etf]
IPGInfo struc
	ipg_opcode	db		0,0,0,1	; IPGP_ASSIGN
	ipg_ipaddress	dd		0	; our IP address
	ipg_ipname	dd		0	; nameserver IP address
        ipg_ipbroad     dd              0       ; broadcast IP address
	ipg_ipfile	dd		0	; file server IP address
	ipg_ipother	dd		4 dup (0)
	ipg_string	db		128 dup (0), '$'
IPGInfo ends
; Parameter block for info about our IP gateway
IPG		IPGInfo		<>

IPG_ERROR	equ	-1

static_address	db	0, 0, 0, 0
use_static	db	0
;no_gateway      db      0                      ; <- new in version 5, changed
use_gateway     db      0                       ; <- in version 8. [etf]
test_address    db      0, 0, 0, 0
temp_4bytes	db	0, 0, 0, 0

IP_ethertype    db      08H, 0          ; ethertype field = 0800h for IP,
ARP_ethertype   db      08H, 06H        ; 0806h for ARP [etf]

; End of Appletalk parameter definitions

; The following values may be overridden from the command line.
; If they are omitted from the command line, these defaults are used.

	public	int_no
int_no	db	0,0,0,0			;must be four bytes long for get_number.

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
; the following three values were modified in macipeth v1 [etf]
; driver_type 9FH is a fake, not registered with FTP Software
driver_class    db      BLUEBOOK,0      ;from the packet spec
driver_type     db      9FH             ;from the packet spec
driver_name     db      'MacIP',0       ;name of the driver.
driver_function	db	2
parameter_list	label	byte
	db	1	;major rev of packet driver
	db	9	;minor rev of packet driver
	db	14	;length of parameter list
;       db      4       ;length of MAC-layer address [jgn]
        db      EADDR_LEN       ; changed in macipeth v1 [etf]
;actually, 586 doesn't include MAC headers (only IP headers), but does any
;application see this value anyway?  (considering that we are not a high-
;performance driver and therefore do not support get_parameters)
        dw      586     ;MTU, including MAC headers [jgn]
	dw	0	;buffer size of multicast addrs [jgn]
	dw	0	;(# of back-to-back MTU rcvs) - 1
	dw	0	;(# of successive xmits) - 1
int_num	dw	0	;Interrupt # to hook for post-EOI
			;processing, 0 == none,

	public	rcv_modes
rcv_modes	dw	4		;number of receive modes in our table.
		dw	0,0,0,rcv_mode_3

	public bad_command_intercept
bad_command_intercept:
;called with ah=command, unknown to the skeleton.
;exit with nc if okay, cy, dh=error if not.
	mov	dh,BAD_COMMAND
	stc
	ret

	public	as_send_pkt
; The Asynchronous Transmit Packet routine.
; Enter with es:di -> i/o control block, ds:si -> packet, cx = packet length,
;   interrupts possibly enabled.
; Exit with nc if ok, or else cy if error, dh set to error number.
;   es:di and interrupt enable flag preserved on exit.
as_send_pkt:
	ret

	public	drop_pkt
; Drop a packet from the queue.
; Enter with es:di -> iocb.
drop_pkt:
	assume	ds:nothing
	ret

	public	xmit
; Process a transmit interrupt with the least possible latency to achieve
;   back-to-back packet transmissions.
; May only use ax and dx.
xmit:
	assume	ds:nothing
	ret

	public	send_pkt
send_pkt:
;enter with es:di->upcall routine, (0:0) if no upcall is desired.
;  (only if the high-performance bit is set in driver_function)
;enter with ds:si -> packet, cx = packet length.
;if we're a high-performance driver, es:di -> upcall.
;exit with nc if ok, or else cy if error, dh set to error number.
	assume	ds:nothing

;now we know that ds:si points to an ethernet frame.
;Check the type of the packet, then:
;   -If it is an IP packet, remove its ethernet header and send it out.
;   -If it is an ARP packet, send an ARP response back to the application.
;   -If it is anything else, return an error to the application.
        cmp     word ptr ds:[si+12], 0008H      ; type field = IP ?
        je      send_is_IP
        cmp     word ptr ds:[si+12], 0608H      ; type field = ARP ?
        jne     send_err                        ; can't handle anything else

        call    send_arp_response
        clc
        ret

send_is_IP:
        sub     cx, 14                          ; take off ethernet header
        add     si, 14
        cmp     cx, 586                         ; bigger than our MTU?
        ja      send_err                        ; too big.

; check for padding after the IP packet (bluebook ethernet's min data field
; size is 46 bytes, but IP packets can be smaller, in which case the
; application adds padding at the end)
        mov     ax, word ptr ds:[si+2]  ; IP pkt length is 2 bytes into pkt
        xchg    ah, al                          ; account for net byte order
; might as well take out these lines for speed; result is the same
;       cmp     cx, ax                          ; padding in the data field?
;       je      send_len_ok                     ; no, data field len = pkt len
        mov     cx, ax                          ; ignore padding

;send_len_ok:
; load info about the packet we are sending
	mov	DDPio.ddp_buffptr.offs, si
	mov	DDPio.ddp_buffptr.segm, ds	; DDPio.buffptr -> IP packet
	mov	DDPio.ddp_buffsize, cx		; DDPio.buffsize = packet len

; Are we sending through a gateway or directly? [etf]
        cmp     use_gateway, 00H
        je      send_no_gateway

; send packet to AppleTalk/DDP/IP gateway
send_gateway:
	mov	cx, (size AddrBlk)		; DDPio.ddp_addr = MyGateway
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	si, offset MyGateway
	mov	di, offset DDPio.ddp_addr
	rep	movsb

	mov	bx, offset DDPio
	call	doATint				; Ask ATALK.SYS to send packet

	cmp	DDPio.ddp_status, 00H		; Packet sent okay?
	je	send_ret			; Yes, status is good
						; No, status gives error
send_err:
	call	count_out_err
	mov	dh, CANT_SEND			; set error flag
	stc
	ret

send_ret:
	clc					; packet sent successfully
	ret

; For information on operating without a gateway, see the MacIP specification,
; as published by Apple Computer, Inc. in November 1994. [etf]
send_no_gateway:
; use the last byte of the destination ethernet address to index into
; NBP_ARP_table and find the entry with this packet's dest AppleTalk address
        mov     bx, offset NBP_ARP_table        ; start at the beginning
        mov     al, byte ptr ds:[si]-9          ; get the byte of the address
        inc     al                              ;   (even though we've taken
                                                ;   off the ethernet header)
send_nogate_looking:
        dec     al
        jz      send_nogate_found               ; when al=0, this is it!
        add     bx,(size NBP_ARP_entry)         ; go to the next entry
        cmp     bx,offset end_NBP_ARP_table     ; examined all entries?
        jb      send_nogate_looking             ; no, continue.
        jmp     send_err                        ; it's not in our table!

send_nogate_found:

; Note a problem with the aging of NBP_ARP_table: it can happen that an entry
; with information about a particular IP address times out, that the same
; entry is filled in with information about a different IP address (due to an
; ARP request packet from the application), and that later the application
; uses the same entry to refer to the first IP address.  This can cause
; packets bound for the first IP address to be sent to the wrong AppleTalk
; node (where the packets will most likely be dropped).  However, the problem
; can only last until the application times out its own ARP entry which refers
; to the first IP address.  When the application's entry about a given IP
; address has expired, before a packet can be sent to that address, the
; application necessarily sends out an ARP request packet, the processing of
; which correctly associates the IP address with an entry in this driver's ARP
; table.  Therefore, this problem can be avoided by making sure that the
; application's ARP entries time out at least as soon as those kept by this
; driver.  The <ARP TTL> command-line option is designed for this purpose.
        cmp     cs:[bx].time_left, 0            ; has the entry timed out yet?
        je      send_err                        ; if yes, we shouldn't use it.

; bx contains the offset of the NBP_ARP_entry with our destination info.
; Send the packet to [bx].tuple.tup_address via DDP.
        mov     cx, (size AddrBlk)      ; DDPio.ddp_addr = [bx].tuple.tup_address
        mov     ax, cs
        mov     ds, ax
        mov     es, ax
;       tuple begins 5 bytes into bx, tup_address begins 0 bytes into tuple
        mov     si, bx
        add     si, 5
        mov     di, offset DDPio.ddp_addr
        rep     movsb

        mov     bx, offset DDPio
        call    doATint

	cmp	DDPio.ddp_status, 00H		; Packet sent okay?
        jne     send_err                        ; No, status gives error
        clc                                     ; Yes, status is good
        ret

;*******************************************
; I lifted this code from etopen.  It is called with the IP address to
; resolve in nbp_arp_temp_ipaddr, and a pointer to an NBP_ARP_entry for
; storing the found information in free_arp_entry. [etf]

nbp_arp_resolve:
; Store the object, type, and zone parts of the entity name for NBP ARP
; address resolution as a string in NBPt.tup_name.
; - object part = dest IP address (passed in nbp_arp_temp_ipaddr) in ASCII
; - type and zone parts are copied from myip_name
        mov     bx, offset NBPt.tup_name
        inc     bx
        xor     dx, dx
        mov     dl, byte ptr nbp_arp_temp_ipaddr
        call    decstr
        mov     al, dot_char
        mov     byte ptr ds:[bx], al
        inc     bx
        mov     dl, byte ptr nbp_arp_temp_ipaddr+1
        call    decstr
        mov     al, dot_char
        mov     byte ptr ds:[bx], al
        inc     bx
        mov     dl, byte ptr nbp_arp_temp_ipaddr+2
        call    decstr
        mov     al, dot_char
        mov     byte ptr ds:[bx], al
        inc     bx
        mov     dl, byte ptr nbp_arp_temp_ipaddr+3
        call    decstr

        mov     ax, bx
        sub     ax, offset NBPt.tup_name
        sub     ax, 1
        mov     NBPt.tup_name, al

        mov     cx, myip_name_len
        movseg  es,cs
        mov     si, offset myip_name
        mov     di, bx
        rep     movsb

; Issue an NBP LkUp to match an AppleTalk address with NBPt.tup_name.
        movseg  ds,cs
        mov     NBP.nbp_command, NBP_LOOKUP
        mov     NBP.nbp_compfun.offs, 0         ; No completion routine [jgn]
        mov     NBP.nbp_compfun.segm, 0
        mov     NBP.nbp_toget, 01H
;       NBP buffer begins five bytes into the NBP_ARP_entry. [etf]
        mov     ax, free_arp_entry
        add     ax, 5
        mov     NBP.nbp_buffptr.offs, ax
        mov     NBP.nbp_buffptr.segm, ds
        mov     NBP.nbp_buffsize, (size NBPTuple)
        mov     NBP.nbp_interval, 1
        mov     NBP.nbp_retry, 2
        mov     NBP.nbp_entptr.offs, offset NBPt.tup_name
        mov     NBP.nbp_entptr.segm, ds
        mov     bx, offset NBP
        call    doATint                         ; do name-bind lookup

        cmp     NBP.nbp_status, 00H             ; if can't resolve address,
        stc                                     ; report error
        jne     nbp_arp_resolve_ret             ; and give up now

        cmp     NBP.nbp_toget, 01H
        stc
        jne     nbp_arp_resolve_ret

        mov     si, free_arp_entry      ; needed for memory addressing [etf]
        mov     bl, ARP_TTL
        mov     [si].time_left, bl      ; make this entry young!
        mov     bx, word ptr nbp_arp_temp_ipaddr
        mov     word ptr [si].ipaddr, bx
        mov     bx, word ptr nbp_arp_temp_ipaddr+2
        mov     word ptr [si].ipaddr+2, bx
        clc                                     ; no error to send_pkt
nbp_arp_resolve_ret:
        ret

;*******************************************
;ARP response variables and code, new in version 6, newer in macipeth v1.
;See RFC 826 for information on ARP. [etf]

arp_packet_size dw      42

arp_packet      struc
ether_dest_addr db      0,0,0C0H,0DH,0D4H,27H
ether_src_addr  db      0,0,0C0H,0DH,0D4H,28H
ether_type      db      08H, 06H
arp_hard_type   db      0, 1
arp_prot_type   db      08H, 0
arp_hard_len    db      6
arp_prot_len    db      4
arp_opcode      db      0, 2
arp_sha         db      0,0,0C0H,0DH,0D4H,28H
arp_spa         db      0, 0, 0, 0
arp_tha         db      0,0,0C0H,0DH,0D4H,27H
arp_tpa         db      0, 0, 0, 0
arp_packet      ends

arp_resp_pkt    arp_packet      <>

;In gateway mode:
;    Respond to outgoing ARP requests for all IP addresses (except our own)
;    with the hardware address 00:00:C0:0D:D4:28.  The application sees the
;    MacIP network as an ethernet network with two nodes: one for itself
;    (00:00:C0:0D:D4:27) and one for all other IP addresses.
;In no_gateway mode:
;    Look for an entry in the NBP_ARP_table which contains NBP ARP address
;    resolution information for the target IP address in the ARP request
;    packet.  If one is found, then renew that entry's information and respond
;    to the ARP request with that entry's corresponding hardware address.  If
;    no such entry exists, then attempt to create one from an inactive entry,
;    and respond to the ARP request with the new entry's hardware address.
;    The application sees the MacIP network as an ethernet network with
;    multiple nodes: one for itself (00:00:C0:0D:D4:27) and one for each other
;    IP address, in the range from 00:00:C0:0D:D4:00 to 00:00:C0:0D:D4:13.
;    Unfortunately, since I have not yet learned how to dynamically allocate
;    table entries, this driver (macipeth v1) can have only 20 entries.

; enter with ds:si -> arp request packet, cx = packet length.
send_arp_response:
;       make sure the request is not for our own IP address
        cmp     use_static, 00H
        jne     send_arp_check_static
        mov     bx, word ptr ds:[si].arp_tpa
        cmp     bx, word ptr IPG.ipg_ipaddress
        jne     send_arp_addr_ok
        mov     bx, word ptr ds:[si].arp_tpa+2
        cmp     bx, word ptr IPG.ipg_ipaddress+2
        jne     send_arp_addr_ok
        ret             ; don't send a response about our own IP address
send_arp_check_static:
        mov     bx, word ptr ds:[si].arp_tpa
        cmp     bx, word ptr static_address
        jne     send_arp_addr_ok
        mov     bx, word ptr ds:[si].arp_tpa+2
        cmp     bx, word ptr static_address+2
        jne     send_arp_addr_ok
        ret             ; don't send a response about our own IP address

send_arp_addr_ok:
;       copy the sender protocol address from the request packet to the
;       target protocol address of the response packet
        mov     bx, word ptr ds:[si].arp_spa
        mov     word ptr cs:arp_resp_pkt.arp_tpa, bx
        mov     bx, word ptr ds:[si].arp_spa+2
        mov     word ptr cs:arp_resp_pkt.arp_tpa+2, bx

;       copy the tpa from the request packet to the spa of the response packet
        mov     bx, word ptr ds:[si].arp_tpa
        mov     word ptr cs:arp_resp_pkt.arp_spa, bx
        mov     bx, word ptr ds:[si].arp_tpa+2
        mov     word ptr cs:arp_resp_pkt.arp_spa+2, bx
;       if we're in gateway mode, then we no longer need the packet at ds:si

        cmp     use_gateway, 00H        ; which mode are we in?
        jne     send_arp_bounce         ; skip over no_gateway stuff

;       also copy the tpa to a temporary location for use in nbp_arp_resolve
;       also store the tpa in ax (first two bytes) and dx (last two)
        mov     bx, word ptr ds:[si].arp_tpa
        mov     word ptr cs:nbp_arp_temp_ipaddr, bx
        mov     ax, bx
        mov     bx, word ptr ds:[si].arp_tpa+2
        mov     word ptr cs:nbp_arp_temp_ipaddr+2, bx
        mov     dx, bx
;       we no longer need the packet at ds:si
        movseg  ds,cs

; I lifted this code from f_access_type.  It cycles through the NBP_ARP_table
; and looks for an entry whose ipaddr matches the one in ax and dx.  If there
; is none, it tries to find an inactive entry (time_left = 0).
        mov     free_arp_entry, 0               ;remember no free entry yet.
        mov     bx, offset NBP_ARP_table
nbp_arp_1:
        cmp     [bx].time_left,0                ; is this entry in use?
        je      nbp_arp_2                       ; no - don't check the ipaddr
        cmp     word ptr [bx].ipaddr, ax        ; yes - check it
        jne     nbp_arp_3
        cmp     word ptr [bx].ipaddr+2, dx
        jne     nbp_arp_3
        mov     free_arp_entry,bx               ; remember this entry
        jmp     nbp_arp_6                       ; we have a match!

send_arp_bounce:
        jmp     send_arp_pkt_ready

nbp_arp_2:
        cmp     free_arp_entry,0                ; found a free entry yet?
        jne     nbp_arp_3                       ; yes.
        mov     free_arp_entry,bx               ; remember a free entry
nbp_arp_3:
        add     bx,(size NBP_ARP_entry)         ; go to the next entry
        cmp     bx,offset end_NBP_ARP_table     ; examined all entries?
        jb      nbp_arp_1                       ; no, continue.

; A matching entry was not found.  If a free entry was found, then call
; nbp_arp_resolve to place resolution info in the free entry.  If no free
; entry, unfortunately we give up.
        cmp     free_arp_entry, 0               ; did we find a free entry?
        jne     nbp_arp_6                       ; yes, use it.
        ret

nbp_arp_6:
        call    nbp_arp_resolve                 ; fill in the entry
        mov     bx, free_arp_entry              ; point bx at dest info again
        jnc     nbp_arp_found                   ; resolve was a success!

        ret     ; could not resolve the IP address, so don't send ARP response

nbp_arp_found:
;       set up arp_resp_pkt with the hardware address from the entry in which
;       NBP ARP resolution info for the requested IP address is stored
        mov     al, byte ptr [bx].ethaddr+5
        mov     byte ptr arp_resp_pkt.ether_src_addr+5, al
        mov     byte ptr arp_resp_pkt.arp_sha+5, al

send_arp_pkt_ready:
;       check if we have a client waiting for arp packets
;       pass to recv_find    es:di->ARP_ethertype, cx=#bytes in packet
;       this line not needed because size is always 42 (macipeth v1)
;       mov     arp_packet_size, cx
        mov     cx, 60                          ; min size of ethernet frame
        mov     di, offset ARP_ethertype
        movseg  es,cs
        mov     dl, driver_class
        movseg  ds,cs
        call    recv_find

;	es:di->client buffer, or es:di=0 means drop the packet
	mov	ax, es
	or	ax, di
        je      send_arp_return

;	copy ds:si->es:di for cx bytes
	push	es				; save the client buffer
	push	di				; address (es:di) [jgn]
        movseg  ds,cs
        mov     si, offset arp_resp_pkt
        mov     cx, arp_packet_size
	rep	movsb

;	tell receiver copy has been made; ds:si->the packet, cx=length
	pop	si				; restore the client buffer
	pop	ds				; address into ds:si [jgn]
        mov     cx, 60                          ; min size of ethernet frame
	call	recv_copy

send_arp_return:
        ret

;*******************************************
; Variables and code for aging the NBP_ARP table, new in version 7. [etf]
old_timer_isr   dd      0               ; original timer isr address

one_sec_countdown       db      18
one_min_countdown       db      60

new_timer_isr:
        pushf                           ; simulate interrupting the timer isr
        call    old_timer_isr

;       after 18 interrupts, approximately one second has passed
        dec     byte ptr one_sec_countdown
;       zero flag means one_sec_countdown reached zero
        jne     new_timer_isr_ret
        mov     byte ptr one_sec_countdown, 18  ;reset the one-second ticker

;       after 18*60 interrupts, one minute has passed
        dec     byte ptr one_min_countdown
;       zero flag means one_min_countdown reached zero
        jne     new_timer_isr_ret
        mov     byte ptr one_min_countdown, 60  ;reset the one-minute ticker

;       once every minute, decrement time_left field of each ARP table entry
;       after ARP_TTL idle minutes, an entry expires
        push    bx
        mov     bx, offset NBP_ARP_table
aging_table_1:
        cmp     cs:[bx].time_left, 0            ; is this entry active?
        je      aging_table_2
        dec     byte ptr cs:[bx].time_left      ; yes, make it older
aging_table_2:
        add     bx,(size NBP_ARP_entry)         ; go to the next entry
        cmp     bx,offset end_NBP_ARP_table     ; examined all entries?
        jb      aging_table_1
        pop     bx

new_timer_isr_ret:
        iret

;*******************************************

	public	set_address
set_address:
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
	assume	ds:nothing
;       mov     dh, BAD_COMMAND         ; Changed in macipeth v1 to follow the
        mov     dh, CANT_SET            ; driver spec v1.09, which says return
        stc                             ; either CANT_SET or BAD_ADDRESS [etf]
        ret


rcv_mode_3:
;receive mode 3 is the only one we support, so we don't have to do anything.
	ret


	public	set_multicast_list
set_multicast_list:
;enter with ds:si ->list of multicast addresses, ax = number of addresses,
;  cx = number of bytes.
;return nc if we set all of them, or cy,dh=error if we didn't.
	mov	dh,NO_MULTICAST
	stc
	ret


	public	terminate
terminate:
	push	ds
;       we didn't change the timer isr if -g was selected. [etf]
        cmp     use_gateway, 00h
        jne     terminate_no_timer_int

;       place old_timer_isr back into vector table entry 08h [etf]
        mov     ah, 25h
        mov     al, 1Ch
        lds     dx, old_timer_isr
        int     21h

terminate_no_timer_int:
	push	cs
	pop	ds

terminate_write:
	; close the DDP socket
	mov	DDPio.ddp_command, DDP_CLOSESOCKET
	mov	bx, offset DDPio
	call	doATint

	mov	NBP.nbp_command, NBP_REMOVE
	mov	NBP.nbp_entptr.offs, offset NBPtable.tab_entry.tup_name
	mov	NBP.nbp_entptr.segm, ds
	mov	bx, offset NBP
	call	doATint

	pop	ds
	ret

	public	reset_interface
reset_interface:
;reset the interface.
	assume	ds:code
	ret


;called when we want to determine what to do with a received packet.
;enter with cx = packet length, es:di -> packet type, dl = packet class.
	extrn	recv_find: near

;called after we have copied the packet into the buffer.
;enter with ds:si ->the packet, cx = length of the packet.
	extrn	recv_copy: near

;call this routine to schedule a subroutine that gets run after the
;recv_isr.  This is done by stuffing routine's address in place
;of the recv_isr iret's address.  This routine should push the flags when it
;is entered, and should jump to recv_exiting_exit to leave.
;enter with ax = address of routine to run.
	extrn	schedule_exiting: near

;recv_exiting jumps here to exit, after pushing the flags.
	extrn	recv_exiting_exit: near

	extrn	count_in_err: near
	extrn	count_out_err: near

	public	recv
recv:
;called from the recv isr.  All registers have been saved, and ds=cs.
;Upon exit, the interrupt will be acknowledged.
;NOTE: this packet driver merely makes calls to another hardware
;driver, ATALK.SYS. ATALK.SYS handles the hardware interrupt service;
;ATALK.SYS then calls this packet driver with FAR subroutine calls.
;the ATALK.SYS FAR subroutine is recv_at_upcall
	assume	ds:nothing
	ret

;*******************************************

; [jgn] Null completion routine is not needed.  Just specify 0000:0000 as the
; address of the completion routine for no call.
;
; NULL completion routine for ATALK.SYS drivers calls
;noop_upcall proc far
;	ret
;noop_upcall endp

;First half routine for DDP socket.
;ATALK.SYS calls this routine when a packet is received.
;ATALK.SYS assumes we are a far procedure.
;	AH = socket
;	CX = size of data packet
;	DS:BX = address of buffer
preview_upcall proc far
	assume	ds:nothing

;	maximum packet we can receive is 586 bytes [jgn]
	cmp	cx, 586				; Max size of DDP data field [jgn]
	ja	preview_drop

;	Is it an IP packet?  DDP type should be 22 [jgn]
	cmp	byte ptr ds:[bx].lap_type, 1	; Is it a short DDP packet?
	jne	ddp_long			; No, must be long DDP
	cmp	byte ptr ds:[bx].ddps_type, 22	; Is it an IP packet?
	jne	preview_drop			; No, refuse packet
	jmp	preview_buff1
ddp_long:
	cmp	byte ptr ds:[bx].ddpl_type, 22	; Is it an IP packet?
	jne	preview_drop			; No, refuse packet

preview_buff1:
	cmp	DDP1inuse, 00H
	jne	preview_buff2
	mov	DDP1inuse, 01H

;	repeat buffer size back to ATALK.SYS in CX
;	ask ATALK.SYS driver to pass us the buffer at DS:BX
;	tell ATALK.SYS address of 2nd half routine in ES:DX
	movseg	ds,cs
	mov	bx, offset DDP1buffer		; ds:bx->buffer
	movseg	es,cs
	mov	dx, offset recv_at_upcall	; es:dx->2nd half routine
	jmp	preview_ret

preview_buff2:
	cmp	DDP2inuse, 00H
	jne	preview_drop
	mov	DDP2inuse, 01H

;	repeat buffer size back to ATALK.SYS in CX
;	ask ATALK.SYS driver to pass us the buffer at DS:BX
;	tell ATALK.SYS address of 2nd half routine in ES:DX
	movseg	ds,cs
	mov	bx, offset DDP2buffer		; ds:bx->buffer
	movseg	es,cs
	mov	dx, offset recv_at_upcall	; es:dx->2nd half routine
	jmp	preview_ret


preview_drop:
;	ask ATALK.SYS to drop the packet
	call	count_in_err
	mov	cx, 00h

preview_ret:
	ret
preview_upcall endp

;Second half routine for DDP socket.
;ATALK.SYS calls this routine when the packet has been copied to our buffer.
;ATALK.SYS assumes we are a far procedure.
;	CX = size of data packet
;	DS:BX = address of buffer
recv_at_upcall proc far
	assume	ds:nothing

; Because of the values in header1 and header2, all packets appear to the
; application to come from 00:00:C0:0D:D4:28.  This doesn't make sense in
; no_gateway mode, in which the application sends outgoing packets to hardware
; addresses between 00:00:C0:0D:D4:00 and 00:00:C0:0D:D4:13.  So far, however,
; 00:00:C0:0D:D4:28 has not caused any problems (such as application ARP
; tables being incorrectly modified based upon received packet headers), so it
; doesn't seem worth the processor time involved to determine which source
; address to show to the application for every incoming packet. (macipeth v1)

recv_buff1:
	cmp	bx, offset DDP1buffer
	jne	recv_buff2

;       place the length of the packet + ethernet frame in cx [etf]
        cmp     cx, 46          ; min length of ethernet data field [etf]
        jae     recv_buff1_len_ok
        mov     cx, 46
recv_buff1_len_ok:
        add     cx, 14          ; add the length of an ethernet header [etf]

;	check if we have a client waiting for packets
;       pass to recv_find    es:di->IP_ethertype, cx=#bytes in packet
	mov	DDP1buffsize, cx
;       mov     di, offset driver_type
        mov     di, offset IP_ethertype         ; changed in version 6 [etf]
	movseg	es,cs
	mov	dl,cs:driver_class
	call	recv_find

;	es:di->client buffer, or es:di=0 means drop the packet
	mov	ax, es
	or	ax, di
	je	recv_pass1

;	copy ds:si->es:di for cx bytes
	push	es				; save the client buffer
	push	di				; address (es:di) [jgn]
	movseg	ds,cs
;       mov     si, offset DDP1buffer
;       header1 points to the beginning of the packet to be copied [etf]
        mov     si, offset header1              ; changed in macipeth v1
	mov	cx, DDP1buffsize
	rep	movsb

;	tell receiver copy has been made; ds:si->the packet, cx=length
	pop	si				; restore the client buffer
	pop	ds				; address into ds:si [jgn]
	mov	cx, DDP1buffsize
	call	recv_copy

recv_pass1:
;	first buffer is free for use again
	mov	DDP1inuse, 00H
	jmp	recv_ret


recv_buff2:
	cmp	bx, offset DDP2buffer
	jne	recv_ret

;       place the length of the packet + ethernet frame in cx [etf]
        cmp     cx, 46          ; min length of ethernet data field [etf]
        jae     recv_buff2_len_ok
        mov     cx, 46
recv_buff2_len_ok:
        add     cx, 14          ; add the length of an ethernet header [etf]

;	check if we have a client waiting for packets
;       pass to recv_find    es:di->IP_ethertype, cx=#bytes in packet
recv_buff2_class5:
	mov	DDP2buffsize, cx
;       mov     di, offset driver_type
        mov     di, offset IP_ethertype         ; changed in version 6 [etf]
	movseg	es,cs
	mov	dl,cs:driver_class
	call	recv_find

;	es:di->client buffer, or es:di=0 means drop the packet
	mov	ax, es
	or	ax, di
	je	recv_pass2

;	copy ds:si->es:di for cx bytes
	push	es				; save the client buffer
	push	di				; address (es:di) [jgn]
	movseg	ds,cs
;       mov     si, offset DDP2buffer
;       header2 points to the beginning of the packet to be copied [etf]
        mov     si, offset header2              ; changed in macipeth v1
	mov	cx, DDP2buffsize
	rep	movsb

;	tell receiver copy has been made; ds:si->the packet, cx=length
	pop	si				; restore the client buffer
	pop	ds				; address into ds:si [jgn]
	mov	cx, DDP2buffsize
	call	recv_copy

recv_pass2:
;	second buffer is now free for use
	mov	DDP2inuse, 00H

recv_ret:
	ret
recv_at_upcall endp

;*******************************************

; Call DOS software interrupt for AppleTalk
; caller must set ds:bx -> parameter block for ATALK.SYS
doATint:
	int	AT_INT				; Interrupt ATALK.SYS driver
	ret



	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret

;*******************************************
; decstr moved from non-resident to resident in version 4. [etf]

; caller must set ds:si -> dest for string, dx 16-bit value to sprint
decstr:
	mov	di,dx
	cmp	dx, 0
	jne	decstr_nonzero
	mov	al,'0'			;yes - easier to just print it, than
	jmp	chrstr			;  to eliminate all but the last zero.
decstr_nonzero:

	xor	ax,ax			;start with all zeroes in al,bx,bp
	mov	bp,ax

	mov	cx,16			;16 bits in one 16 bit registers.
decstr_1:
	rcl	di,1
	xchg	bp,ax
	call	addbit
	xchg	bp,ax
	adc	al,al
	daa
	loop	decstr_1

	mov	cl,'0'			;prepare to eliminate leading zeroes.
	call	bytestr			;output the first two.
	mov	ax,bp
	jmp	wordstr			;output the next four.

addbit:	adc	al,al
	daa
	xchg	al,ah
	adc	al,al
	daa
	xchg	al,ah
	ret

;print the char in al at ds:bx
chrstr:
	mov	byte ptr [bx], al
	inc	bx
	ret

wordstr:
	push	ax
	mov	al,ah
	call	bytestr
	pop	ax
bytestr:
	mov	ah,al
	shr	al,1
	shr	al,1
	shr	al,1
	shr	al,1
	call	digstr
	mov	al,ah
digstr:
	and	al,0fh
	add	al,90h	;binary digit to ascii hex digit.
	daa
	adc	al,40h
	daa
	cmp	al,cl			;leading zero?
	je	digstr_1
	mov	cl,-1			;no more leading zeros.
	jmp	chrstr
digstr_1:
	ret


;any code after this will not be kept after initialization. Buffers
;used by the program, if any, are allocated from the memory between
;end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
end_free_mem	label	byte
;****************************************************************************

	public	usage_msg
usage_msg       db      "usage: macipeth [options] <packet_int_no> [ -g ] [ <IP address> ] [ <ARP TTL> ]",CR,LF ; [jgn],[etf]
                db      "   with -g: find and use a MacIP gateway on the AppleTalk network",CR,LF
                db      "      <IP address> optional, asks the gateway to assign a specific address",CR,LF
                db      "      <ARP TTL> not used",CR,LF
                db      "   without -g: operate independently of gateways",CR,LF
                db      "      <IP address> required, specifies this node's IP address",CR,LF
                db      "      <ARP TTL> optional, specifies age at which address table entries expire",CR,LF
                db      "         (in minutes, default is 20)",CR,LF
                db      "   options:",CR,LF,'$'

	public	copyright_msg
copyright_msg   db      "Class 1 Packet driver for MacIP (TCP/IP over AppleTalk), version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
		db	"Portions Copyright 1990, Regents of the University of California",CR,LF,'$'

no_atalk_sys_msg:
	db	"Couldn't locate ATALK.SYS -- packet driver not installed",CR,LF,'$'
atalk_sys_found_msg:
	db	"ATALK.SYS driver located at software interrupt ",'$'
inf_nodeid_name:
	db	"Attaching to AppleTalk network as node ",'$'
inf_abridge_name:
	db	"AppleTalk network bridge is node ",'$'
ddp_failed_msg:
	db	"Datagram Delivery Protocol socket open failed; return status: ",'$'
ddp_wrong_socket_msg:
	db	"Datagram Delivery Protocol failed; unable to aquire requested socket",CR,LF,'$'
ddp_open_msg:
	db	"Datagram Delivery Protocol open on socket ",'$'
atalk_open_msg:
	db	"Attached to AppleTalk network as (net:node:sock): ",'$'
nbp_no_gateway_msg:
	db	"NBP: IPGATEWAY lookup failed; return status: ",'$'
nbp_ipg_addr_msg:
	db	"IPGATEWAY located on AppleTalk network as (net:node:sock): ",'$'
atp_no_gateway_msg:
	db	"ATP: IPGATEWAY transport setup failed; return status: ",'$'
ipg_gateway_err_msg:
	db	"IP Gateway error: ",'$'
myip_addr_msg:
	db	"My IP address: ",'$'
ns_ip_addr_msg:
	db	"Name Server IP address: ",'$'
bd_ip_addr_msg:
	db	"Broadcast IP address: ",'$'
fs_ip_addr_msg:
	db	"File Server IP address: ",'$'
opcode_msg:
	db	"IPG opcode: ",'$'
nbp_addr_in_use_msg:                                    ; [etf]
        db      "Error: IP address in use by another MacIP node; return status: ",'$'
nbp_no_register_msg:
	db	"NBP: failed, couldn't register our name; return status: ",'$'
ddp_cant_recv:
	db	"DDP: couldn't initiate read on socket; return status: ",'$'
test_arg_msg:
	db	"Test IP arg parsing: ",'$'
null_msg	db	'$'

ipgateway_name:
	db	01H, '=', 09H, "IPGATEWAY", 01H, '*', '0'

; Temporary storage for calls to print_number
dtemp	dw	?,0

	extrn	set_recv_isr: near

;enter with si -> argument string, di -> wword to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with ds:dx -> argument string, ds:di -> dword to print.
	extrn	print_number: near

;enter with al = char to display
	extrn	chrout: near
;enter with ax,dx holding 32 bits to display in decimal (ax holds low word)
	extrn	decout: near
	extrn	byteout: near
	extrn	wordout: near

	extrn	skip_blanks: near

;enter with si -> argument string, di -> word to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;needed for Class-1-related code near the end of etopen (macipeth v1)
        extrn   rom_address: byte               ; new in version 6 [etf]

;called with ds:si -> immediately after the entry_point
;09/13/98 Perhaps the entry '....' will break parse_args, as get_number and
;get_digit do not change si if the passed first-digit pointed to by si is not
;in {0..9}.  This would cause parse_args to place 0.0.0.0 in static_address,
;unless some other extraneous value remains in CX before parse_args is called,
;in which case static_address would contain cl.cl.cl.cl.  [etf]
	public	parse_args
parse_args:
	call	skip_blanks
	lodsb

;If -g option is present, then setup to operate with a MacIP gateway. [etf]
        cmp     al, '-'
        jne     no_g_option
        lodsb
        or      al,20h                          ; convert to lower case
        cmp     al, 'g'
        jne     arg_err_return
        mov     use_gateway, 01H
        jmp     test_bracket

arg_err_return:
        dec     si
        stc
        ret

;If -g option is not present, then we require an IP address.
;If no address is entered, then return an error.
no_g_option:
        cmp     al, CR
        je      arg_err_return
        dec     si              ; we don't yet know what ds:si is, so back up

test_bracket:
        call    skip_blanks
        lodsb
        cmp     al, CR          ; it is possible to have -g and no more args
        je      no_more_args
	cmp	al, '['				; check for square brackets
	je	past_brackets
	dec	si				; not a bracket, back up
past_brackets:
	mov	di, offset temp_4bytes		; get first IP address byte
	call	get_number
	mov	byte ptr test_address, cl
	lodsb
	cmp	al, '.'
	jne	no_more_args

	mov	di, offset temp_4bytes		; get second IP address byte
	call	get_number
	mov	byte ptr test_address+1, cl
	lodsb
	cmp	al, '.'
	jne	no_more_args

	mov	di, offset temp_4bytes		; get third IP address byte
	call	get_number
	mov	byte ptr test_address+2, cl
	lodsb
	cmp	al, '.'
	jne	no_more_args

        mov     di, offset temp_4bytes          ; get fourth IP address byte
	call	get_number
	mov	byte ptr test_address+3, cl

;	mov	dx, offset test_arg_msg
;	mov	di, offset test_address
;push	si
;	call	print_ip_addr
;pop	si

	mov	ax, word ptr test_address
	mov	word ptr static_address, ax
	mov	ax, word ptr test_address+2
	mov	word ptr static_address+2, ax
	mov	use_static, 01H

	lodsb
	cmp	al, ']'
        je      past_second_bracket
        dec     si

past_second_bracket:
;If -g option is not present, look for a value for ARP_TTL.
;If -g option is present, ARP_TTL is irrelevant.
        cmp     use_gateway, 00H
        jne     arg_return

        call    skip_blanks
        lodsb
        cmp     al, CR
        je      no_more_args
        dec     si
        mov     di, offset temp_4bytes          ; get the value
	call	get_number
        mov     byte ptr ARP_TTL, cl
        jmp     arg_return

;exit with nc if all went well, cy otherwise.
no_more_args:
	dec	si
arg_return:
	clc
	ret


;replace interrupt vector table entry 08h (timer interrupt) with our own isr,
;which ages the NBP ARP table for statically addressed gatewayless mode. [etf]
setup_timer_isr:
        mov     ah,35h                  ;remember the timer isr, which will
        mov     al,1Ch                  ;be called by our isr.
        int     21h
        mov     old_timer_isr.offs,bx
        mov     old_timer_isr.segm,es

        mov     ah,25h                  ;trap the timer interrupt
        mov     al,1Ch
        mov     dx,offset new_timer_isr ;with our own isr.
        int     21h

        ret


; Initialize our interface to the ATALK.SYS driver.
; NOTE: this initialization code is modeled after the PC/IP LocalTalk
; driver written by Dan Lanciani (ddl@harvard.harvard.edu); the PCIP
; software package can found at husc6.harvard.edu:pub/pcip/pcip.tar.Z
	public	etopen
etopen:
	assume	ds:code

; ATALK.SYS driver may be loaded at a software interrupt somewhere
; between 5CH and 70H. Locate ATALK.SYS driver by scanning for signature.
isATLoaded:					; Look for ATALK.SYS driver
	cld
	call	ATGetInt			; Load start of intr range
	mov	dx, ax				; Save start value in DX
chkloop:
	cmp	dx, 70H				; Scanned all possible vectors?
	jne	checkstring			; No, check this vector
	xor	ax, ax				; Yes, driver not found
	jmp	chksplit			; Skip ahead to return
checkstring:
	mov	bx, dx				; Load intr# for scan
	shl	bx, 1				; Multiply by 2 (for seg bytes)
	shl	bx, 1				; Multiply by 2 (for off bytes)
	xor	ax, ax
	mov	es, ax				; Lowest page of memory
	lds	si, es:[bx]			; Load vector for scan intr#
	mov	ax, ds				; Load segment this scan intr#
	or	ax, si				; OR with off this scan intr#
	jz	keepchecking			; Keep checking if no bits
	sub	si, 16				; Signature is just before code
	mov	di, offset driverstring		; Load compare string
	mov	cx, 9				; Load length of compare string
	movseg	es,cs
	repe	cmpsb				; Compare ds:si to es:di
	jne	keepchecking			; Keep checking if not matched
	call	ATGetInt			; Matched, get INT# again
	cmp	ax, dx				; INT# already set properly?
	jz	chksplit			; Yes, use this INT#
						; No, we found INT# by scanning
	call	ATPatch				; Modify code to match scan
	call	ATGetInt			; Retrieve final INT#
	jmp	chksplit			; Skip ahead to return

keepchecking:					; Havent found ATALK.SYS driver
	inc	dx				; Check next possible INT#
	jmp	chkloop				; Loop back to check next INT#

chksplit:					; Done with scan for ATALK.SYS
	cmp	ax, 00H				; ATALK.SYS driver found?
	jne	atalk_sys_found			; Yes, skip ahead to continue

	mov	dx, offset no_atalk_sys_msg	; No, ATALK.SYS not loaded
	jmp	error_wrt			; Skip ahead to report error

atalk_sys_found:				; ATALK.SYS driver found
	movseg	ds,cs
	mov	dtemp, dx			; Report intr# of ATALK.SYS
	mov	di, offset dtemp
	mov	dx, offset atalk_sys_found_msg
	call	print_number

; We need to establish our Appletalk node
get_our_info:					; Get info params from ATALK
	mov	MyInfo.atd_command, AT_GETNETINFO
	mov	MyInfo.atd_status, -1		; As per PC LocalTalk spec. [jgn]
	mov	MyInfo.atd_compfun.offs, 0	; No completion routine [jgn]
	mov	MyInfo.atd_compfun.segm, 0
	mov	bx, offset MyInfo
	call	doATint

	cmp	MyInfo.atd_status, 00H		; Already initialized?
	je	get_ddp_socket			; Yes, skip ahead

	mov	MyInfo.atd_command, AT_INIT	; No, initialize our node
	mov	MyInfo.atd_compfun.offs, 0	; No completion routine [jgn]
	mov	MyInfo.atd_compfun.segm, 0
	mov	bx, offset MyInfo
	call	doATint

; We need to establish our AppleTalk/DDP socket
get_ddp_socket:					; Open a DDP socket
	mov	DDPio.ddp_command, DDP_OPENSOCKET
	mov	DDPio.ddp_compfun.offs, 0	; No completion routine [jgn]
	mov	DDPio.ddp_compfun.segm, 0
	mov	DDPio.ddp_buffptr.offs, offset preview_upcall
	mov	DDPio.ddp_buffptr.segm, cs
	mov	DDPio.ddp_socket, 72		; ask for experimental sock#
	mov	DDPio.ddp_type, 22		; ask for IP socket type
	mov	bx, offset DDPio			; ds:bx-> DDP param block
	call	doATint				; ask ATALK.SYS for a socket

	cmp	DDPio.ddp_status, 00H		; error return from ATALK.SYS?
	je	chk_ddp_socket			; no, skip ahead to continue
						; yes, no socket for us
	mov	ax, DDPio.ddp_status
	mov	dtemp, ax
	mov	di, offset dtemp
	mov	dx, offset ddp_failed_msg
	call	print_number			; report error and stat return
	jmp	error_ret

;**** do we really require socket 72?
;**** Answer: yes, per MacIP specification.  [etf]
chk_ddp_socket:					; check the socket we opened
	cmp	DDPio.ddp_socket, 72		; did we get the one requested?
	je	ddp_ready			; yes, socket is as expected
						; no, but must have socket 72
	mov	DDPio.ddp_command, DDP_CLOSESOCKET
	mov	bx, offset DDPio
	call	doATint				; close the assigned socket

	mov	dx, offset ddp_wrong_socket_msg	; load error msg
	jmp	error_wrt			; skip ahead to display and ret

ddp_ready:					; DDP socket 72 is ready
	mov	DDPio.ddp_command, DDP_WRITE	; Use param block for WRITE now

; AppleTalk node and DDP socket have been established
	mov	ax, MyInfo.inf_network
	mov	word ptr dtemp, ax
	mov	al, MyInfo.inf_nodeid
	mov	ah, DDPio.ddp_socket
	mov	byte ptr dtemp+2, al
	mov	byte ptr dtemp+3, ah
	mov	di, offset dtemp
	mov	dx, offset atalk_open_msg
	call	print_at_addr			; display AppleTalk node info
	mov	ax, 00H
	mov	dtemp+2, ax

; If the -g option was not entered in the command line, then skip over the
; gateway-related initialization. [etf]
        cmp     use_gateway, 00H
        je      nbp_bounce

; We need an IP gateway node
nbp_ipgateway:					; Locate our IP gateway node
	movseg	ds,cs
	mov	NBP.nbp_command, NBP_LOOKUP
	mov	NBP.nbp_compfun.offs, 0		; No completion routine [jgn]
	mov	NBP.nbp_compfun.segm, 0
	mov	NBP.nbp_toget, 01H
	mov	NBP.nbp_buffptr.offs, offset NBPt
	mov	NBP.nbp_buffptr.segm, ds
	mov	NBP.nbp_buffsize, (size NBPTuple)
	mov	NBP.nbp_interval, 5
	mov	NBP.nbp_retry, 12
	mov	NBP.nbp_entptr.offs, offset ipgateway_name
	mov	NBP.nbp_entptr.segm, ds
	mov	bx, offset NBP
	call	doATint				; do name-bind lookup

	cmp	NBP.nbp_status, 00H		; status return=error?
	jne	nbp_no_gateway			; yes, report error and exit

	cmp	NBP.nbp_toget, 01H
	je	atp_setup

nbp_no_gateway:					; NBP lookup failed
	mov	ax, NBP.nbp_status
	mov	dtemp, ax
	mov	di, offset dtemp
	mov	dx, offset nbp_no_gateway_msg	; display error msg
	call	print_number

	mov	DDPio.ddp_command, DDP_CLOSESOCKET
	mov	bx, offset DDPio
	call	doATint				; close the assigned socket

	jmp	error_ret			; skip ahead to return

nbp_bounce:                                     ; [etf]
        jmp     nbp_register_ourself

; We need a transport layer to the IP gateway
atp_setup:
	mov	cx, (size AddrBlk)		; MyGateway = NBPt.tup_addr
	movseg	es,cs
	mov	si, offset NBPt.tup_address
	mov	di, offset MyGateway
	rep	movsb

	mov	di, offset NBPt.tup_address	; Display our gateway node
	mov	dx, offset nbp_ipg_addr_msg
	call	print_at_addr

; In version 4, use_static must be 00H for the driver to init with a gateway.  [etf]
; but in version 5, it doesn't.  [etf]
        cmp     use_static, 00H                 ; Do we have a static address? [jgn]
        je      bds_setup                       ; No, don't change anything
        mov     IPG.ipg_opcode+3, 3             ; Yes, change to IPG_SERVER

bds_setup:
	mov	BDS.bds_buffptr.offs, offset IPG
	mov	BDS.bds_buffptr.segm, ds
	mov	BDS.bds_buffsize, (size IPGInfo)

	mov	ATP.atp_command, ATP_SEND_REQUEST
	mov	ATP.atp_compfun.offs, 0		; No completion routine [jgn]
	mov	ATP.atp_compfun.segm, 0
	mov	cx, (size AddrBlk)		; ATP.atp_addr = NBPt.tup_addr
	movseg	es,cs
	mov	si, offset NBPt.tup_address
	mov	di, offset ATP.atp_addrblk
	rep	movsb
	mov	ATP.atp_buffptr.offs, offset IPG
	mov	ATP.atp_buffptr.segm, ds
	mov	ATP.atp_buffsize, (size IPGInfo)
	mov	ATP.atp_interval, 05H
	mov	ATP.atp_retry, 05H
	mov	ATP.atp_flags, XO_BIT
	mov	ATP.atp_bdsbuffs, 01H
	mov	ATP.atp_bdsptr.offs, offset BDS
	mov	ATP.atp_bdsptr.segm, ds
	mov	bx, offset ATP
	call	doATint

	cmp	ATP.atp_status, 00H		; status return=error?
	jne	atp_no_gateway			; yes, report error and exit

	cmp	ATP.atp_bdsbuffs, 01H
	je	chk_ip_opcode

atp_no_gateway:					; ATP setup failed
	mov	ax, ATP.atp_status
	mov	dtemp, ax
	mov	di, offset dtemp
	mov	dx, offset atp_no_gateway_msg	; display error msg
	call	print_number

	mov	DDPio.ddp_command, DDP_CLOSESOCKET
	mov	bx, offset DDPio
	call	doATint				; close the assigned socket

	jmp	error_ret			; skip ahead to return

chk_ip_opcode:
	cmp	IPG.ipg_opcode.offs, IPG_ERROR	; opcode is 32 bit
	jne	save_ipaddr			; check one word at a time
	cmp	IPG.ipg_opcode.segm, IPG_ERROR	; error from IP gateway?
	jne	save_ipaddr			; no, transport established
						; yes, ATP setup failed
	mov	dx, offset ipg_gateway_err_msg	; display IPG error msg
	mov	ah, 9
	int	21H
	mov	dx, offset IPG.ipg_string
	mov	ah, 9
	int	21H
	mov	al, 13				; display CR-LF
	call	chrout
	mov	al, 10
	call	chrout

	mov	DDPio.ddp_command, DDP_CLOSESOCKET
	mov	bx, offset DDPio
	call	doATint				; close the assigned socket

	jmp	error_ret

; AppleTalk/IP transport layer established
save_ipaddr:
	mov	dx, offset myip_addr_msg
; In version 4, use_static must be 00H for the driver to init with a gateway.  [etf]
; but in version 5, it doesn't.  [etf]
        cmp     use_static, 00H
        jne     show_static
show_dynamic:
	mov	di, offset IPG.ipg_ipaddress
        jmp     show_ipaddr
show_static:
        mov     di, offset static_address
show_ipaddr:
	call	print_ip_addr

	mov	dx, offset ns_ip_addr_msg
	mov	di, offset IPG.ipg_ipname
	call	print_ip_addr

	mov	dx, offset bd_ip_addr_msg
	mov	di, offset IPG.ipg_ipbroad
	call	print_ip_addr

	mov	dx, offset fs_ip_addr_msg
	mov	di, offset IPG.ipg_ipfile
	call	print_ip_addr

; We need to register ourself with the AppleTalk Name Binding Agent
nbp_register_ourself:
	mov	al, MyInfo.inf_nodeid
	mov	NBPtable.tab_entry.tup_address.ablk_nodeid, al
	mov	al, DDPio.ddp_socket
	mov	NBPtable.tab_entry.tup_address.ablk_socket, al

	; print our IP address in our NBP table entry
	mov	bx, offset NBPtable.tab_entry.tup_name
	inc	bx
	xor	dx, dx
	cmp	use_static, 00H
	jne	reg_static1
reg_dynamic1:
	mov	dl, byte ptr IPG.ipg_ipaddress
	jmp	reg_format1
reg_static1:
	mov	dl, byte ptr static_address
reg_format1:
	call	decstr
	mov	al, dot_char
	mov	byte ptr ds:[bx], al
	inc	bx
	cmp	use_static, 00H
	jne	reg_static2
reg_dynamic2:
	mov	dl, byte ptr IPG.ipg_ipaddress+1
	jmp	reg_format2
reg_static2:
	mov	dl, byte ptr static_address+1
reg_format2:
	call	decstr
	mov	al, dot_char
	mov	ds:[bx], al
	inc	bx
	cmp	use_static, 00H
	jne	reg_static3
reg_dynamic3:
	mov	dl, byte ptr IPG.ipg_ipaddress+2
	jmp	reg_format3
reg_static3:
	mov	dl, byte ptr static_address+2
reg_format3:
	call	decstr
	mov	al, dot_char
	mov	ds:[bx], al
	inc	bx
	cmp	use_static, 00H
	jne	reg_static4
reg_dynamic4:
	mov	dl, byte ptr IPG.ipg_ipaddress+3
	jmp	reg_format4
reg_static4:
	mov	dl, byte ptr static_address+3
reg_format4:
	call	decstr

	mov	ax, bx
	sub	ax, offset NBPtable.tab_entry.tup_name
	sub	ax, 1
	mov	NBPtable.tab_entry.tup_name, al

	mov	cx, myip_name_len	; append IPADDR command to our IP
	movseg	es,cs
	mov	si, offset myip_name	; ds:si -> source
	mov	di, bx			; es:di -> dest
	rep	movsb

        cmp     use_gateway, 00H        ; [etf]
        jne     nbp_2_register_ourself

; moved from parse_args in version 8
        call    setup_timer_isr

; Issue an NBP LkUp to ensure that noone is using our static_address.
; (See MacIP spec.)  [etf]
        movseg  ds,cs
        mov     NBP.nbp_command, NBP_LOOKUP
        mov     NBP.nbp_compfun.offs, 0         ; No completion routine [jgn]
        mov     NBP.nbp_compfun.segm, 0
        mov     NBP.nbp_toget, 01H
        mov     NBP.nbp_buffptr.offs, offset NBPt
        mov     NBP.nbp_buffptr.segm, ds
        mov     NBP.nbp_buffsize, (size NBPTuple)
        mov     NBP.nbp_interval, 1
        mov     NBP.nbp_retry, 3
        mov     NBP.nbp_entptr.offs, offset NBPtable.tab_entry.tup_name
        mov     NBP.nbp_entptr.segm, ds
        mov     bx, offset NBP
        call    doATint                         ; do name-bind lookup

        cmp     NBP.nbp_status, 00H             ; Is the address in use?
        jne     print_macip_addr                ; no, jump to print it

        mov     ax, NBP.nbp_status              ; yes, report error and exit
        mov     dtemp, ax
        mov     di, offset dtemp
        mov     dx, offset nbp_addr_in_use_msg  ; display error msg
        call    print_number

        mov     DDPio.ddp_command, DDP_CLOSESOCKET
        mov     bx, offset DDPio
        call    doATint                         ; close the assigned socket

        jmp     error_ret                       ; skip ahead to return

; Our address is good, so print it. [etf]
print_macip_addr:
        mov     dx, offset myip_addr_msg
        mov     di, offset static_address
        call    print_ip_addr

	; Register our name with NBP agent
nbp_2_register_ourself:
	mov	NBP.nbp_command, NBP_REGISTER
	mov	NBP.nbp_compfun.offs, 0		; No completion routine [jgn]
	mov	NBP.nbp_compfun.segm, 0
	mov	NBP.nbp_buffptr.offs, offset NBPtable
	mov	NBP.nbp_buffptr.segm, ds
	mov	NBP.nbp_interval, 01H
	mov	NBP.nbp_retry, 03H
	mov	bx, offset NBP
	call	doATint

	cmp	NBP.nbp_status, 00H
        je      atinit_done

nbp_no_register:
	mov	ax, NBP.nbp_status
	mov	dtemp, ax
	mov	di, offset dtemp
	mov	dx, offset nbp_no_register_msg	; display error msg
	call	print_number

	mov	DDPio.ddp_command, DDP_CLOSESOCKET
	mov	bx, offset DDPio
	call	doATint				; close the assigned socket

        jmp     error_ret                       ; skip ahead to return

;**** LocalTalk PC Card initialized, ready to TSR
atinit_done:
	movseg	ds,cs

;added Class-1-related setup code here in macipeth v1
;set up our fake rom address -- 00:00:C0:0D:D4:27
        mov     word ptr rom_address, 00H
        mov     byte ptr rom_address+2, 0C0H
        mov     byte ptr rom_address+3, 0DH
        mov     byte ptr rom_address+4, 0D4H
        mov     byte ptr rom_address+5, 27H
;set up the last byte of ethaddr in each entry in NBP_ARP_table
        mov     bx, offset NBP_ARP_table
        mov     al, 0
setting_table:
        mov     byte ptr [bx].ethaddr+5, al
        inc     al
        add     bx,(size NBP_ARP_entry)         ; go to the next entry
        cmp     bx,offset end_NBP_ARP_table     ; reached end of the table?
        jb      setting_table                   ; no, continue.
                                                ; yes, we're finished.
	clc
	ret

;**** Got an error while initializing LocalTalk PC Card
error_wrt:					; Display an error message
;       we didn't change the timer isr if -g was selected. [etf]
        cmp     use_gateway, 00h
        jne     er_wrt_no_timer_int
;       place old_timer_isr back into vector table entry 08h [etf]
        push    dx
        mov     ah, 25h
        mov     al, 1Ch
        lds     dx, old_timer_isr
        int     21h
        pop     dx
er_wrt_no_timer_int:
	movseg	ds,cs
	stc
	ret

error_ret:				; Board not initialized
;       we didn't change the timer isr if -g was selected. [etf]
        cmp     use_gateway, 00h
        jne     er_ret_no_timer_int
;       place old_timer_isr back into vector table entry 08h [etf]
        push    ds
        mov     ah, 25h
        mov     al, 1Ch
        lds     dx, old_timer_isr
        int     21h
        pop     ds
er_ret_no_timer_int:
	mov	dx,offset null_msg	;error message already printed.
	stc
	ret

	public	print_parameters
print_parameters:
;echo our command-line parameters
	ret

;*******************************************

; Modify ATALK.SYS interrupt number in doATint code (self-modifying code!)
ATPatch:
	mov	al, dl				; Load new interrupt number
	movseg	es,cs
	lea	bx, doATint			; es:bx=offset of doATint code
	inc	bx				; skip to operator for INT
	mov	es:[bx], al			; modify the code
	ret

; Get ATALK.SYS interrupt number
ATGetInt:
	movseg	es,cs
	lea	bx, doATint			; es:bx=offset of doATint code
	inc	bx				; skip to operator for INT
	mov	al, es:[bx]			; load operator for INT
	xor	ah, ah				; zero high byte
	ret					; return INT# to caller

;*******************************************

; caller must set ds:dx -> argument string, ds:di -> AddrBlk struct
print_at_addr:
;enter with dx -> dollar terminated name of number, di ->dword.
;exit with the number printed and the cursor advanced to the next line.
	mov	ah,9			;print the name of the number.
	int	21h
	mov	ax, [di].ablk_network	;print the network number
	xchg	ah, al			; byte-swap network number [jgn]
	mov	dx, 00H
	push	di
	call	decout
	pop	di
	mov	al, ':'
	call	chrout
	xor	ax, ax
	mov	al, [di].ablk_nodeid	; print the nodeid number
	push	di
	call	decout
	pop	di
	mov	al, ':'
	call	chrout
	xor	ax, ax
	mov	al, [di].ablk_socket	; print the socket number
	call	decout
	mov	al,CR
	call	chrout
	mov	al,LF
	call	chrout
	ret

; caller must set ds:dx -> argument string, ds:di -> 32 bit ip address
print_ip_addr:
;enter with dx -> dollar terminated name of number, di ->dword.
;exit with the number printed and the cursor advanced to the next line.
	mov	ah,9			;print the name of the number.
	int	21h
	mov	al, '['
	call	chrout
	xor	ax, ax
	mov	al, [di]		;print first byte in decimal.
	mov	dx, 00H
	push	di
	call	decout
	pop	di
	mov	al, '.'
	call	chrout
	xor	ax, ax
	mov	al, [di+1]		; print second byte in decimal
	push	di
	call	decout
	pop	di
	mov	al, '.'
	call	chrout
	xor	ax, ax
	mov	al, [di+2]		; print third byte in decimal
	push	di
	call	decout
	pop	di
	mov	al, '.'
	call	chrout
	xor	ax, ax
	mov	al, [di+3]		; print fourth byte in decimal
	call	decout
	mov	al, ']'
	call	chrout
	mov	al,CR
	call	chrout
	mov	al,LF
	call	chrout
	ret

code	ends

	end

