minver equ     5
;History:1,1
;Mon Feb 17 00:38:00 2003 change rcv isr loop around.
;Sat Feb 15 14:00:16 2003 return cy or nc in recv.
;Wed Jan 29 12:48:33 2003 initialize baseAddr correctly, so we work without VDS.
;Wed Jan 29 09:54:12 2003 turn off forcing
;Tue Dec 17 14:03:40 2002 add support for set_address
;Tue Dec 17 08:38:43 2002 try setting aneg_sel to zero.

        include defs.asm
        extrn  maskint:near    ;in head

;-----
; port offsets from base
;-----
CRPort          = 0             ;Command Register
CFGPort         = 4h            ;Configuration and Media Status Register
PTSCRPort       = 0Ch           ;PCI Test Control Register 
ISRPort         = 10h           ;Interrupt Status Register 
IMRPort         = 14h           ;Interrupt Mask Register 
IERPort         = 18h           ;Interrupt Enable Register 
TXDPPort        = 20h           ;Transmit Descriptor Pointer Register 
TXCFGPort       = 24h           ;Transmit Configuration  Register 
RXDPPort        = 30h           ;Receive Descriptor Pointer Register 
RXCFGPort       = 34h           ;Receive Configuration Register 
WCSRPort        = 40h           ;Wake on LAN Control/Status Register 
RFCRPort        = 48h           ;Receive Filter/Match Control Register 
RFDRPort        = 4Ch           ;Receive Filter/Match Data Register
SRRPort		= 58h		; Silicon Revision Register
PHYID1Port	= 088h		; PHY Identifier Register #1
PHYID2Port	= 08Ch		; PHY Identifier Register #2
MIBCPort        = 05Ch          ;Management Information Base Control Register
BMCRPort        = 080h          ;Basic Mode Control Register
PHYSTSPort	= 0C0h		; PHY Status Register
MICRPort        = 0C4h          ;MII Interrupt Control Register
MISRPort        = 0C8h          ;MII Interrupt Status Register
PAGEPort	= 0CCh		; Page Select

;
;	Extended Register -->Page0
TENBTPort	= 0E8h		; 10BaseT status/control
;
;	Test Registers -->Page1
;
FCOCTLPort	= 0D0h		; False Carrier Sense Counter Register
TMRPort		= 0D4h		; Test Mode
CRMPort		= 0DCh		; CRM
CDCTL2Port	= 0E0h		; CD test control 2
PMDCSRPort	= 0E4h		; PHY Control Register
PGMCGMPort	= 0E8h		; PGM/CGM Control
DSPCFGPort	= 0F4h		; DSP Config
SDCFGPort	= 0F8h		; Signal detect config
TDATAPort	= 0FCh		; Test Data

TRANSMIT_BUF_COUNT      equ     4
RECEIVE_BUF_COUNT       equ     8
TRANSMIT_BUF_SIZE       equ     GIANT
RECEIVE_BUF_SIZE        equ     GIANT+4+2       ;4 for CRC, 2 for alignment

;-----
;c83815 transmit and receive descriptor rings
;-----
;txDescRing and rxDescRing need to be aligned on 4 byte boundaries.  We
;can't use "align 4" because we don't have total control of this segment,
;so we'll stick a pad in after the structures and adjust their starting point
;at run time.

descEntry       struc
  link          dd      0
  cmdsts        dd      0
  bufptr        dd      0
  nearptr       dw      0       ;bufptr relative to cs
  pad           dw      0       ;struct size must be zero mod 4
descEntry       ends

code    segment word public
        assume  cs:code, ds:code
.486

	include	time.asm
        public  card_no
card_no db      0,0,0,0                 ;must be four bytes long for get_number.

        public  int_no
int_no  db      3,0,0,0                 ;must be valid for tail after parse_args
io_addr dw      0,0
isr     dd      0                       ;last read of ISRPort
rfcr	dd	0			;last write of RFCRPort

        public  driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class    db      BLUEBOOK,0      ;null terminated list of classes.
driver_type     db      0               ;unused in the packet spec
driver_name     db      'c83815',0     ;name of the driver.
driver_function db      1
parameter_list  label   byte
        db      1       ;major rev of packet driver specification
        db      9       ;minor rev of packet driver specification
        db      14      ;length of parameter list
        db      EADDR_LEN       ;length of MAC-layer address
        dw      GIANT   ;MTU, including MAC headers
        dw      MAX_MULTICAST * EADDR_LEN       ;buffer size of multicast addrs
        dw      0       ;(# of back-to-back MTU rcvs) - 1
        dw      0       ;(# of successive xmits) - 1
int_num dw      0       ;Interrupt # to hook for post-EOI
                        ;processing, 0 == none,

        public  rcv_modes
rcv_modes       dw      7               ;number of receive modes in our table.
                dw      0               ;there is no mode zero.
                dw      rcv_mode_1
                dw      rcv_mode_2      ;only ours.
                dw      rcv_mode_3      ;ours plus broadcast
                dw      0               ;some multicasts
                dw      rcv_mode_5      ;all multicasts
                dw      rcv_mode_6      ;all packets

dds_struc	struc
dds_size	dd	0		;region size.
dds_offset	dd	0		;offset (using 32 bits)
dds_seg		dw	0		;segment or selector
dds_buffer_id	dw	0
dds_physical	dd	0		;physical address
dds_struc	ends

my_dds		dds_struc<>
vds_active	db	?		;<>0 if memory mapping is on.

txDescIn        dw 0
rxDescOut       dw 0
CurrentStatus	dw 0
SRRVerSion	dw 0
baseAddr        dd 0                            ;32 bit phys addr of DS:0

extrn	is_pci	: byte		;=0 if not PCI, =1 if PCI

        public bad_command_intercept
bad_command_intercept:
;called with ah=command, unknown to the skeleton
;exit with nc if okay, cy, dh=error if not.
        mov     dh,BAD_COMMAND
        stc
        ret

        public  as_send_pkt
; The Asynchronous Transmit Packet routine.
; Enter with es:di->upcall routine, (0:0) if no upcall is desired,
;   ds:si -> packet, cx = packet length,
;   interrupts possibly enabled.
; Exit with nc if ok, or else cy if error, dh set to error number.
;   es:di and interrupt enable flag preserved on exit.
as_send_pkt:
        ret

        public  drop_pkt
; Drop a packet from the queue.
; Enter with es:di -> iocb.
drop_pkt:
        assume  ds:nothing
        ret

        public  xmit
; Process a transmit interrupt with the least possible latency to achieve
;   back-to-back packet transmissions.
; May only use ax and dx.
xmit:
        assume  ds:nothing
        ret


        public  send_pkt
send_pkt:
;enter with ds:si -> packet, cx = packet length.
;exit with nc if ok, or else cy if error, dh set to error number.
        assume  ds:nothing
        ;
        ;Make sure we have a free entry in the ring
        ;
        mov     bx,txDescIn
        mov     eax,cs:[bx].descEntry.cmdsts
	test	eax,1 SHL 31                    ;OWN, can't send if still belongs to c83815
	je	short send_pkt_1
         call   count_out_err
         mov    dh,CANT_SEND
         stc
         ret
send_pkt_1:

        mov     bx,txDescIn
        mov     ax,cx
        mov     ecx,0A0000000h                  ;OWN+INTR
        mov     cx,ax                           ;ecx = cmdsts
        mov     cs:[bx].descEntry.cmdsts,ecx
        push    cs
        pop     es
        mov     di,cs:[bx].descEntry.nearptr
        inc     cx
        shr     cx,1
        rep     movsw                           ;copy his buffer to ours

        loadport
        setport	CRPort
        mov     eax,1
        out     dx,eax                          ;outpd(base + cr, txe);
        mov     eax,cs:[bx].descEntry.link
        sub     eax,baseAddr
        mov     txDescIn,ax
        clc
        ret


        public  set_address
set_address:
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
        assume  ds:nothing
        cmp     cx,EADDR_LEN		;make sure it's right.
        jne      short set_address_2
        mov     cx,EADDR_LEN/2          ;we'll set it one word at a time

set_address_1:
        loadport
        setport	RFCRPort
        mov     eax,3
        sub     ax,cx                   ;eax = 0, 1, 2
        add     ax,ax                   ;eax = 0, 2, 4
        out     dx,eax
        setport	RFDRPort
        outsw
        loop    set_address_1

        setport	RFCRPort
	mov	eax, rfcr
	out	dx, eax

        mov     cx,EADDR_LEN
        clc
        ret
set_address_2:
        mov     dh,CANT_SET
        stc
        ret


rcv_mode_1:
        mov     eax,0
        jmp     short set_rcv_mode
rcv_mode_2:     ;       rfen        apm
        mov     eax,1 SHL 31 + 1 SHL 27
        jmp     short set_rcv_mode
rcv_mode_3:     ;       rfen        aab        apm
        mov     eax,1 SHL 31 + 1 SHL 30 + 1 SHL 27
        jmp     short set_rcv_mode
rcv_mode_5:     ;       rfen        aab        aam        apm
        mov     eax,1 SHL 31 + 1 SHL 30 + 1 SHL 29 + 1 SHL 27
        jmp     short set_rcv_mode
rcv_mode_6:     ;       rfen        aab        aam        aau        apm
        mov     eax,1 SHL 31 + 1 SHL 30 + 1 SHL 29 + 1 SHL 28 + 1 SHL 27
;       jmp     short set_rcv_mode
set_rcv_mode:
	loadport
	setport	RFCRPort
	mov	rfcr, eax
        out     dx,eax
        ret

        public  set_multicast_list
set_multicast_list:
;enter with ds:si ->list of multicast addresses, ax = number of addresses,
;  cx = number of bytes.
;return nc if we set all of them, or cy,dh=error if we didn't.
        mov     dh,NO_MULTICAST
        stc
        ret


        public  terminate
terminate:
; turn off bus mastering
        mov     ax,0B108h               ;Read Config Byte
        mov     di,04h                  ;Configuration Command and Status Register
        int     1Ah
        and     cl,not 5                ;clear BMEN+I/OSEN
        mov     ax,0B10Bh               ;Write Config Byte
        int     1Ah

; unlock the dma block.
	mov	di,offset my_dds
	mov	ax,cs
	mov	es,ax
	mov	dx,0
	mov	ax,8104h
	int	4bh

        ret


        public  reset_interface
reset_interface:
;reset the interface.
        assume  ds:code
        ret


;called when we want to determine what to do with a received packet.
;enter with cx = packet length, es:di -> packet type, dl = packet class.
        extrn   recv_find: near

;called after we have copied the packet into the buffer.
;enter with ds:si ->the packet, cx = length of the packet.
        extrn   recv_copy: near

;call this routine to schedule a subroutine that gets run after the
;recv_isr.  This is done by stuffing routine's address in place
;of the recv_isr iret's address.  This routine should push the flags when it
;is entered, and should jump to recv_exiting_exit to leave.
;enter with ax = address of routine to run.
        extrn   schedule_exiting: near

;recv_exiting jumps here to exit, after pushing the flags.
        extrn   recv_exiting_exit: near

;enter with dx = amount of memory desired.
;exit with nc, dx -> that memory, or cy if there isn't enough memory.
        extrn   malloc: near

        extrn   count_in_err: near
        extrn   count_out_err: near

        public  recv
recv:
;called from the recv isr.  All registers have been saved, ds=cs,
;our interrupt has been acknowledged, and our interrupts have been
;masked at the interrupt controller.
;return nc if we handled the interrupt, or cy if it wasn't ours.
        assume  ds:code
        push    eax
        push    ecx
        push    edi
        loadport
        setport	IERPort
        mov     eax,0
        out     dx,eax                  ;outpd(base + ier, 0);
         loadport
         setport ISRPort
         in     eax,dx
	 test	eax,1 SHL 14 + 1 SHL 5 + 1 SHL 1
	 stc
	 je	short recv_5
recv_1:
         mov    isr,eax

	 test	isr,1 SHL 1          ;rxdesc
	 je	short recv_2
          call  rcv_event
recv_2:

	 test	isr,1 SHL 14          ;phy
	 je	short recv_3
          call  phy_event
recv_3:

	 test	isr,1 SHL 5		;rxorn
	 je	short recv_4
          call  count_in_err
recv_4:
         loadport
         setport ISRPort
         in     eax,dx
	 test	eax,1 SHL 14 + 1 SHL 5 + 1 SHL 1
	 clc
	 je	short recv_5
	 jmp	recv_1
recv_5:
	pushf
        loadport
        setport	IERPort
        mov     eax,1
	popf
        cli
        out     dx,eax                  ;outpd(base + ier, ie);
        pop     edi
        pop     ecx
        pop     eax
        ret

;-----
rcv_event:
;loop till recvs all processed

rcv_event_0:
         mov    bx,rxDescOut
         mov    eax,[bx].descEntry.cmdsts       ;get the status
	 test	eax,1 SHL 31
	 je	rcv_event_1			;own // ret if still belongs to c83815

         mov    ecx,[bx].descEntry.link
         sub    ecx,baseAddr
         mov    rxDescOut,cx
	 test	eax, 08000000h			;ok?
	 je	short rcv_event_2
	 test	eax, 067C0000h			;not RXA|RXO|LONG|RUNT|ISE|CRCE|FAE ?
	 jne	short rcv_event_2

          mov   di,[bx].descEntry.nearptr
          push  cs
          pop   es                              ;es:di -> packet
          push  es
          push  di
          push  bx
          mov   cx,ax
          and   cx,0FFFh
          sub   cx,4                            ;kill the CRC
          add   di,EADDR_LEN+EADDR_LEN          ;skip the addresses
          mov   dl,BLUEBOOK                     ;assume real Ethernet
          mov   ax,es:[di]
          xchg  ah, al
	  cmp	ax, 1500			;802.2?
	  ja	short rcv_event_4		; no
           inc  di                              ;bump di up to 802.2 header
           inc  di
           mov  dl,IEEE8023
rcv_event_4:
          push  cx
          call  recv_find
          pop   cx

          pop   bx
          pop   si
          pop   ds
          assume  ds:nothing

          mov   ax,es                   	;did we get a pointer?
          or    ax,di
	  je	short rcv_event_5		; no.
           push es
           push di
           push cx
           rep  movsb
           pop  cx
           pop  si
           pop  ds
           assume  ds:nothing
           call recv_copy
rcv_event_5:
          push  cs
          pop   ds
          assume ds:code
	  jmp	short rcv_event_3
rcv_event_2:
         ;!OK or (RXA|RXO|LONG|RUNT|ISE|CRCE|FAE)
          call  count_in_err
rcv_event_3:
         ;
         ;Start another receive
         ;
         mov    eax,1 SHL 29            ;INTR
         mov    ax,RECEIVE_BUF_SIZE
         mov    [bx].descEntry.cmdsts,eax
         loadport
         setport CRPort
         mov    eax,5
         out    dx,eax                  ;outpd(base + cr, rxe|txe);
	jmp	rcv_event_0
rcv_event_1:
        ret
;-----
phy_event:
	cli
	pushf
        loadport
	setport	PHYSTSPort
        in      eax,dx
	and	eax,1
	cmp	eax,1		
	jne	phy_event1		; Current Link Status is down
	cmp	CurrentStatus,1		; Previous Link Status is up too
	je	phy_event2

	mov	CurrentStatus,1
	call	ConfigPhyCoef		; Linkstatus Change from down to up
	jmp	phy_event2
phy_event1:
	cmp	CurrentStatus,0		; Check if previous link status is down too
	je	phy_event2
	mov	CurrentStatus,0
	call	EuphyterPhyReset
	call	CheckPhySRR
phy_event2:
	popf
	sti
        ret


        public  timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
        iret

;beginning of the area of memory that the chip knows about (and that we will
;  have to lock down for DMA).
begin_dma	label	byte
;
;the chip requires that the descriptor pointers be on a qword boundary.
;
	align	8

txDescRing      descEntry TRANSMIT_BUF_COUNT dup (<>)
rxDescRing      descEntry RECEIVE_BUF_COUNT  dup (<>)
dummy           db 3 dup (0)

;any code after this will not be kept.  Buffers used by the program, if any,
;are allocated from the memory between end_resident and end_free_mem, and MUST
;be allocated via malloc.
        public end_resident,end_free_mem
end_resident    label   byte
        db      ((RECEIVE_BUF_COUNT*RECEIVE_BUF_SIZE)+(TRANSMIT_BUF_COUNT*TRANSMIT_BUF_SIZE)+3) dup(?)
end_free_mem    label   byte

int_no_name     db      "Interrupt number ",'$'
io_addr_name    db      "I/O port ",'$'

        public  usage_msg,mca_usage_msg
mca_usage_msg	label	byte
usage_msg       db      "usage: c83815 [options] <packet_int_no>",CR,LF,'$'
no_pci_bios_msg db      "No PCI BIOS in this machine.",CR,LF,'$'
no_card_msg     db      "Card not found.",CR,LF,'$'
no_such_register_msg db "Error getting PCI information.",CR,LF,'$'
io_addr_too_high_msg db "I/O port is above 64K.",CR,LF,'$'
no_load_high_msg db     "Cannot load high.",CR,LF,'$'
no_memory_msg   db      "Unable to allocate enough memory, look at end_resident in c83815.ASM",CR,LF,'$'
vds_ver_msg	db	"Using VDS version ",'$'
forced_msg	db	"FORCING 10Mbps and half duplex",CR,LF,'$'

        public  copyright_msg
copyright_msg   db      "Packet driver for the c83815, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+minver,CR,LF
                db      "Portions Copyright 2000, Nortel Networks",CR,LF
                db      "Portions Copyright 2001, Crynwr Software",CR,LF,'$'

;called when you're ready to receive interrupts.
        extrn   set_recv_isr: near

;enter with si -> argument string, di -> dword to store.
;if there is no number, don't change the number.
        extrn   get_number: near

;enter with dx -> argument string, di -> dword to print.
        extrn   print_number: near

;-> the unique Ethernet address of the card.  Filled in by the etopen routine.
        extrn   rom_address: byte

;-> current address.  Normally the same as rom_address, unless changed
;by the set_address() call.
        extrn   my_address: byte

	extrn	chrout: near
	extrn	decout: near
	extrn	crlf: near

;parse_args is called with si -> first parameter (CR if none).
        public  parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
        assume  ds:code
        mov     di,offset card_no
        call    get_number
        clc
        ret

no_memory:
        mov     dx,offset no_memory_msg
etopen_err:
        stc
        ret

	include	hexout.asm

        public  etopen
etopen:
;initialize the driver.  Fill in rom_address with the assigned address of
;the board.  Exit with nc if all went well, or cy, dx -> $ terminated error msg.
        assume  ds:code
	cmp		is_pci, 0
	jne		have_pci_bus
	mov 	dx, offset no_pci_bios_msg	; A PCI bus is required
	stc
	ret

have_pci_bus:
        ;
        ; Find the (first) card
        ;
        mov     ax,0B102h               ;Find PCI device
        mov     dx,100Bh                ;vendor = National Semiconductor
        mov     cx,20h                  ;device = c83815
        movzx   si,card_no              ;index (0 => first instance)
        int     1Ah
        mov     dx,offset no_card_msg
        jc      etopen_err                                                   
        ;                                                                    
        ; Get the base address
        ;
        mov     ax,0B109h               ;Read Config Word
        mov     di,10h                  ;Configuration I/O Base Address Register
        int     1Ah
        mov     dx,offset no_such_register_msg
        jc      etopen_err
        and     cx,0FFFEh               ;strip off I/O bit
        mov     io_addr,cx
        mov     ax,0B109h               ;Read Config Word
        mov     di,12h                  ;Configuration I/O Base Address Register
        int     1Ah
        mov     dx,offset no_such_register_msg
        jc      etopen_err
        mov     dx,offset io_addr_too_high_msg
        cmp     cx,0
        jne     etopen_err
        ;
        ; Get the IRQ
        ;
        mov     ax,0B108h               ;Read Config Byte
        mov     di,3Ch                  ;Configuration Interrupt Select Register
        int     1Ah
        mov     dx,offset no_such_register_msg
        jc      etopen_err
        mov     int_no,cl
hexout_mark	'a'
        ;
        ; Enable bus mastering and I/O
        ;
        mov     ax,0B108h               ;Read Config Byte
        mov     di,04h                  ;Configuration Command and Status Register
        int     1Ah
        mov     dx,offset no_such_register_msg
        jc      etopen_err
        or      cl,5                    ;BMEN+I/OSEN
        mov     ax,0B10Bh               ;Write Config Byte
        int     1Ah
        mov     dx,offset no_such_register_msg
        jc      etopen_err
hexout_mark	'b'
        ;
        ; Set latency timer to 255
        ;
        mov     ax,0B10Bh               ;Write Config Byte
        mov     cl,255
        mov     di,0Dh                  ;Configuration Latency Timer Register
        int     1Ah
        mov     dx,offset no_such_register_msg
        jc      etopen_err

hexout_mark	'c'
        ;
        ; Reset the card
        ;
        loadport
	setport	CRPort
	mov	eax,100h       ;RST
	out	dx,eax
        setport	ISRPort
etopen_1:
         in     eax,dx
	 cmp	eax, 3008000h
	 jne	etopen_1

        ;
        ; Reload EEPROM data
        ;
	loadport
	setport	PTSCRPort
        mov	eax,4        ;EELOAD_EN
	out	dx,eax
etopen_2:
         in     eax,dx
	 test	eax,4			; wait for bit 4 to go away??
	jne	etopen_2
        ;
        ; Read station address
        ;
hexout_mark	'e'
        mov     cx,EADDR_LEN/2          ;we'll get it one word at a time
        push    ds
        pop     es
        mov     di,offset rom_address
etopen_3:
         loadport
         setport RFCRPort
         mov    eax,3
         sub    ax,cx                   ;eax = 0, 1, 2
         add    ax,ax                   ;eax = 0, 2, 4
         out    dx,eax
         setport RFDRPort
         insw
	loop	etopen_3
        ;
        ; Set int_num
        ;
hexout_mark	'f'
        mov     al,int_no
	cmp	al, 8
	jae	short etopen_4
         add    al,8
	jmp	short etopen_5
etopen_4:
         add    al,70h - 8
etopen_5:
        xor     ah,ah
        mov     int_num,ax
        ;
        ; Mask out interrupt
        ;
hexout_mark	'g'
        mov     al,int_no
        call    maskint
        ;
        ; Set up baseAddr to make address conversion easier
        ;
;
; now we lock down the memory that we'll be using for DMA.  That is,
; assuming we're running under some sort of memory mapper.
;
	mov	ax,40h			;is some program providing VDS?
	mov	es,ax
	test	byte ptr es:[7bh],20h
	jz	no_vds

	mov	ax,08102h		;get version information.
	mov	dx,1010b		;no auto-remap, copy data into buffer.
	int	4bh
	cmp	ax,8102h		;did it change into version number?
	je	no_vds			;no, must not be there...

	push	ax
	mov	dx,offset vds_ver_msg
	mov	ah,9
	int	21h
	pop	ax

	push	ax
	mov	al,ah			;print major version number.
	xor	ah,ah
	xor	dx,dx
	call	decout
	mov	al,'.'
	call	chrout
	pop	ax			;print minor version number.
	xor	ah,ah
	xor	dx,dx
	call	decout
	call	crlf

	mov	vds_active,1

	movseg	es,cs
	mov	di,offset my_dds
	mov	[di].dds_size.offs,end_free_mem - begin_dma
	mov	[di].dds_size.segm,0
	mov	[di].dds_offset.offs,offset begin_dma
	mov	[di].dds_offset.segm,0
	mov	[di].dds_seg,cs
	mov	[di].dds_buffer_id,0
	mov	ax,08103h		;request that the memory be locked.
	mov	dx,1010b		;no auto-remap, copy data into buffer.
	int	4bh

	mov	eax,my_dds.dds_physical
	sub	eax,offset begin_dma
	mov	baseAddr,eax		; baseAddr == physical beginning of ds:0
	jmp	short memory_locked

no_vds:
        push    ds
        pop     dx                              ;dx:0 = DS:0
	cmp	dx,0a000h			;can't load high (too lazy to do VDS)
	jb	short etopen_6
         mov    dx,offset no_load_high_msg
         jmp    etopen_err
etopen_6:
        mov     cl,4
        mov     al,dh
        shr     al,cl
        cbw
        shl     dx,cl                           ;ax:dx = 32 bit addr of DS:0
        mov     baseAddr.offs,dx
        mov     baseAddr.segm,ax
memory_locked:

hexout_mark	'h'
        ;
        ; Initialize rings
        ;
InitializeR:	
        mov     di,offset rxDescRing
        add     di,3
        and     di,0FFFCh                       ;force alignment
        mov     si,di
        mov     rxDescOut,si
        push    si
        mov     dx,((RECEIVE_BUF_COUNT*RECEIVE_BUF_SIZE)+(TRANSMIT_BUF_COUNT*TRANSMIT_BUF_SIZE)+3)
        call    malloc
        add     dx,3
        and     dx,0FFFCh                       ;force alignment
        mov     cx,RECEIVE_BUF_COUNT
etopen_7:
         mov    di,si
         add    si,size descEntry
         xor    eax,eax
         mov    ax,si
         add    eax,baseAddr
         mov    [di].descEntry.link,eax
         mov    eax,1 SHL 29            ;INTR
         mov    ax,RECEIVE_BUF_SIZE
         mov    [di].descEntry.cmdsts,eax
         mov    [di].descEntry.nearptr,dx
         movzx  edx,dx
	 mov	eax,baseAddr
         add    eax,edx
         mov    [di].descEntry.bufptr,eax
         add    dx,RECEIVE_BUF_SIZE
	loop	etopen_7
        xor     eax,eax
        pop     ax
        add     eax,baseAddr
        mov     [di].descEntry.link,eax

        mov     di,offset txDescRing
        add     di,3
        and     di,0FFFCh                       ;force alignment
        mov     si,di
        mov     txDescIn,si
        push    si
        mov     cx,TRANSMIT_BUF_COUNT
etopen_8:
         mov    di,si
         add    si,size descEntry
         xor    eax,eax
         mov    ax,si
         add    eax,baseAddr
         mov    [di].descEntry.link,eax
         mov    [di].descEntry.cmdsts,0
         mov    [di].descEntry.nearptr,dx
	 mov	eax,baseAddr
         movzx  edx,dx
         add    eax,edx
         mov    [di].descEntry.bufptr,eax
         add    dx,TRANSMIT_BUF_SIZE
	loop	etopen_8

        xor     eax,eax
        pop     ax
        add     eax,baseAddr
        mov     [di].descEntry.link,eax

        mov     eax,offset rxDescRing
        add     eax,3
        and     eax,0FFFFFFFCh                  ;force alignment
        add     eax,baseAddr                    ;eax = phys addr of rxDescRing
	loadport
	setport	RXDPPort
	out	dx,eax

        mov     eax,offset txDescRing
        add     eax,3
        and     eax,0FFFFFFFCh                  ;force alignment
        add     eax,baseAddr                    ;eax = phys addr of txDescRing
	setport	TXDPPort
	out	dx,eax
        ;
        ; Set the magic values	
        ; marked by Bruce  (Rev 12.1)
;	setport	0CCH
;	setport	0CCH
;	mov	ax,00001h
;	out	dx,ax
;	setport	0E4h
;	mov	ax,189Ch
;	out	dx,ax
;	setport	0FCh
;	mov	ax,0000h
;	out	dx,ax
;	setport	0F4h
;	mov	ax,5040h
;	out	dx,ax
;	setport	0F8h
;	mov	ax,008Ch
;	out	dx,ax
        
	setport	RFCRPort
	mov	eax,1 SHL 31 + 1 SHL 30 + 1 SHL 27    ;rfen | aab | apm
	mov	rfcr, eax
	out	dx,eax

;  revised by Rev 12.1

	setport	PHYSTSPort
	in	eax,dx
	and 	eax,04h
	cmp	eax,04h		;Full Duplex Mode
	jne	HFDPXMEDIA
	setport	TXCFGPort
	mov	eax,0D0C00230h		;corrected 0D0C4023h ("4" meaningless), Rev 12.2
	out	dx,eax
	setport	RXCFGPort
	mov	eax,010500020h
	out	dx,eax
	setport	MISRPort
	mov	ax,0BFFFh	; Bruce2 	;good only for Duplex routine (Rev 12.2)
	out	dx,ax
	jmp	etxcfg

HFDPXMEDIA:
	loadport			;added to insure correct setport (Rev 12.2)
	setport	TXCFGPort
	mov	eax,010C00230h
	out	dx,eax
	setport	RXCFGPort
	mov	eax,000500020h
	out	dx,eax

;  commented out by Rev 12.1
;	setport	TXCFGPort
;	mov	eax,1 SHL 30 + 1 SHL 28 + 7 SHL 20 + 15 SHL 8 + 48 ;flth | atp | txdrth | mxdma | hbi
;	out	dx,eax
;	setport	RXCFGPort
;	mov	eax,8 SHL 1  	;rxdrth
;	out	dx,eax

	setport	MISRPort	;put inside HFDPXMEDIA routine (Rev 12.2)
	mov	ax,1 SHL 14  	;mskLink // int on link status change (values from Rev 11.1)
	out	dx,ax

etxcfg:
	setport	MICRPort
	mov	ax,1 SHL 1   ;inten // enable PHY interrupts
	out	dx,ax

	setport	WCSRPort	;moved to here from just before MISRPort (Rev 12.2)
	mov	eax,0         	;// no PME
	out	dx,eax
        
	setport	CFGPort
        in      eax,dx
        or      eax,1 SHL 17    ;pint_acen
        out     dx,eax

;	setport	BMCRPort
;	mov	ax,0			; set speed selection to 10 and no auto
;	out	dx,ax

;	push	dx			; tell them ANEG_SEL == 0
;	mov	dx,offset forced_msg
;	mov	ah,9
;	int	21h
;	pop	dx

	setport	MIBCPort
	mov	eax,0         ;// enable MIB counters
	out	dx,eax
	setport	CRPort
	mov	eax,5           ;txe | rxe
	out	dx,eax
	setport	IMRPort
	mov	eax,1 SHL 14 + 1 SHL 1 ;rxdesc | phy
	out	dx,eax
        ;
        ; Enable interrupts at the chip level
        ;
	setport	IERPort
        mov     eax,1
        out     dx,eax                  ;outpd(base + ier, ie);
        ;
        ; Now hook in our interrupt
        ;
        call    set_recv_isr

        clc
        ret

        public  print_parameters
print_parameters:
;echo our command-line parameters
        mov     di,offset int_no
        mov     dx,offset int_no_name
        call    print_number
        mov     di,offset io_addr
        mov     dx,offset io_addr_name
        call    print_number
        ret

code    ends

        end
