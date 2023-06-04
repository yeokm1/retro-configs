;//********************************************************************************
;// Module: W3C507.ASM
;// Purpose: Windows compatible Packet Driver (Loaded as a DLL)
;//
;// Author: Bill Simpson
;// Note: Modified from publicly distributed source.
;// Date: 11/4/93
;//********************************************************************************
		name w3c507_asm
                .MODEL LARGE
                .386P

;((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((
;***  DLL Interface Functions ***
; int (ccode) OpenEthernet(void);
; void DriverInfo(int &nFunctionality,int &nVersion,int &nClass,int &nNumber,int &nType);  
; int (handle) AccessType(int nClass,int nNumber,int nType,int nTypeLen,LPSTR pTypeDesc,
;              Pvoid pRcvHandler);
; void ReleaseType(int nHandle);
; int (ccode) SendPkt(int nLen,BYTE far *pPacket);
; int (ccode) TerminateLAN(int nHandle);
; int (length) GetAddress(int nHandle,int nAddrLen,BYTE far *pAddrBuff);
; void ResetInterface(int nHandle);
; void GetParameters(LAN_PARAM_STRUC far *pParams);
; void SetRcvMode(int nHandle,int nRcvMode);
; int (rcv mode) GetRcvMode(int nHandle);
; void SetMultiCastList(int nAddrLen,BYTE far *pAddr);
; void GetMultiCastList(int &nListBytes,BYTE far *pAddrList);
; void GetStatistics(int nHandle,LAN_STATS_STRUC far *pStats);
; void SetAddress(int nAddrLen,BYTE far *pAddr);
;))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))

                public OPENETHERNET
                public DRIVERINFO
                public ACCESSTYPE
                public RELEASETYPE
                public SENDPKT
		public TERMINATELAN
                public GETADDRESS
                public RESETINTERFACE
                public GETPARAMETERS
                public SETRCVMODE
                public GETRCVMODE
                public SETMULTICASTLIST
                public GETMULTICASTLIST
                public GETSTATISTICS
                public SETADDRESS


LAN_PARAM_STRUC struc
nMajVer         db      ?
nMinVer         db      ?
nStrucLen       db      ?
nAddrLen        db      ?
nMaxXmitUnit    dw      ?
nMltCstAdrBufSize       dw      ?
nBack2BackRcv   dw      ?
nSuccessiveXmits        dw      ?
nPostEoiInt     dw      ?
LAN_PARAM_STRUC ends

LAN_STATS_STRUC struc
nPktsRcvd       dd      ?
nPktsXmited     dd      ?
nBytesRcvd      dd      ?
nBytesXmited    dd      ?
nErrsRcvd       dd      ?
nErrsXmited     dd      ?
nPktsLost       dd      ?
LAN_STATS_STRUC ends

MAJVER          equ     10              ;version number of the infrastructure.
MAX_ADDR_LEN    equ     16              ;maximum number of bytes in our address.
MAX_HANDLE      equ     10              ;maximum number of handles.
MAX_P_LEN       equ     8               ;maximum type length
MAX_MULTICAST   equ     8               ;maximum number of multicast addresses.

HT              equ     09h
CR              equ     0dh
LF              equ     0ah

;  Packet Driver Error numbers
NO_ERROR        equ     0               ;no error at all.
BAD_HANDLE      equ     1               ;invalid handle number
NO_CLASS        equ     2               ;no interfaces of specified class found
NO_TYPE         equ     3               ;no interfaces of specified type found
NO_NUMBER       equ     4               ;no interfaces of specified number found
BAD_TYPE        equ     5               ;bad packet type specified
NO_MULTICAST    equ     6               ;this interface does not support
                                        ;multicast
CANT_TERMINATE  equ     7               ;this packet driver cannot terminate
BAD_MODE        equ     8               ;an invalid receiver mode was specified
NO_SPACE        equ     9               ;operation failed because of
                                        ;insufficient space
TYPE_INUSE      equ     10              ;the type had previously been accessed,
                                        ;and not released.
BAD_COMMAND     equ     11              ;the command was out of range, or not
                                        ;implemented
CANT_SEND       equ     12              ;the packet couldn't be sent (usually
                                        ;hardware error)
CANT_SET        equ     13              ;hardware address couldn't be changed
                                        ;(more than 1 handle open)
BAD_ADDRESS     equ     14              ;hardware address has bad length or
                                        ;format
CANT_RESET      equ     15              ;Couldn't reset interface (more than
                                        ;1 handle open).
BAD_IOCB        equ     16              ;an invalid iocb was specified

;a few useful Ethernet definitions.
RUNT            equ     60              ;smallest legal size packet, no fcs
GIANT           equ     1514            ;largest legal size packet, no fcs
EADDR_LEN       equ     6               ;Ethernet address length.
ARCADDR_LEN     equ     1

BLUEBOOK        equ     1
IEEE8023        equ     11

;The following two macros are used to manipulate port addresses.
;Use loadport to initialize dx.  Use setport to set a specific port on
;the board.  setport remembers what the current port number is, but beware!
;setport assumes that code is being executed in the same order as the
;code is presented in the source file.  Whenever this assumption is violated,
;you need to enter another loadport.  Some, but not all examples are:
;in a loop with multiple setports, or a backward jump over a setport, or
;a forward jump over a setport.  If you have any doubt, consult the
;individual driver sources for examples of usage.  If you suspect that
;you have too few loadports, define the symbol "no_confidence" to a
;one.  This will force a loadport before every setport.  If you wish to turn
;it off for some of your code, redefine it to a zero.

loadport        macro
        mov     dx,io_addr
port_no = 0
                endm

;change the port number from the current value to the new value.
setport         macro   new_port_no
   ifdef no_confidence          ;define if you suspect that you don't
      if no_confidence
         loadport               ;  have enough loadports, i.e. dx is
      endif
   endif                                ;  set to the wrong port.
   if new_port_no - port_no EQ 1
      inc dx
   else
      if new_port_no - port_no EQ -1
         dec dx
      else
      if new_port_no - port_no NE 0
         add dx,new_port_no - port_no
      endif
   endif
endif
   port_no = new_port_no
                endm

segmoffs        struc                   ; defines offs as 0, segm as 2
offs            dw      ?
segm            dw      ?
segmoffs        ends

CY              equ     0001h
EI              equ     0200h

iocb            struc                   ; as_send_pkt structure
buffer          dd      ?               ; Pointer to the buffer
len             dw      ?               ; Its length
flags           db      ?               ; Some flags
ret_code        db      ?               ; Completion code
upcall          dd      ?               ; I/O completion upcall
next            dd      ?               ; Private next pointer (queue)
resv            db      4 dup (?)       ; Unused private data
iocb            ends

DONE            equ     1               ; I/O complete flag
CALLME          equ     2               ; Please upcall me flag

send_queueempty macro
; Check if send queue is empty.
; Enter with interrupts disabled.
; Exit with zr (zero) if empty, nz (not zero) if not.
; Destroys ax.
                mov     ax,word ptr send_head   ; Queue empty?
                or      ax,word ptr send_head+2
                endm

send_peekqueue  macro
; Peek into the queue and get the next entry.
; Enter with interrupts disabled.
; Exit with es:di -> iocb.
                les     di,send_head    ; Get head segment:offset
                endm

IO_CONTROL      equ     06h
IO_INTCLR       equ     0ah
IO_CA           equ     0bh
IO_RAM          equ     0eh
IO_INT          equ     0fh

;IO_CONTROL bits:
_RST            equ     80h             ;not reset
LBK             equ     20h             ;loopback
IEN             equ     04h             ;interrupt enable
VB0             equ     01h             ;vb0.

;**********************************************************************************************
.DATA
        public int_no,io_addr,base_addr,base_selector,driver_class,driver_type,driver_name,driver_function,parameter_list
        public int_num,scp_bus,scp_ptr,iscp_busy,iscp_offset,iscp_base,scb_stat,scb_com,scb_cbl,scb_rfa,scb_serrs
        public fd_status,fd_eol,fd_link,fd_ptr,fd_dest,fd_source,fd_cnt,rbd_status,rbd_link,rbd_ptr,rbd_size
        public tcb_status,tcb_com,tcb_link,tcb_ptr,tcb_addr,tcb_len,tbd_status,tbd_link,tbd_ptr,cmd_status
        public cmd_com,mcb_status,mcb_com,mcb_link,mcb_cnt,tdr_status,tdr_com,tdr_link,tdr_time,memory_begin
        public firstfd,lastfd,lastbd,flag,cbconf,cbconf_flags,cbconf_minlen,timeout,timeout_counter,ScpFlag
        public old_rcv_isr,in_use,packet_type,packet_type_len,receiver,receiver_sig,class,handles,end_handles
        public multicast_count,multicast_broad,multicast_addrs,have_my_address,my_address,my_address_len
        public rcv_mode_num,free_handle,found_handle,receive_ptr,send_head,send_tail,our_address,statistics_list
        public packets_in,packets_out,bytes_in,bytes_out,errors_in,errors_out,packets_dropped,nMajVer,nMinVer
        public nStrucLen,nAddrLen,nMaxXmitUnit,nMltCstAdrBufSize,nBack2BackRcv,nSuccessiveXmits,nPostEoiInt
        public nPktsRcvd,nPktsXmited,nBytesRcvd,nBytesXmited,nErrsRcvd,nErrsXmited,nPktsLost,offs,segm,buffer
        public len,flags,ret_code,upcall,next,resv
;---------------------------------------------------------------------------------
int_no          db      15,0,0,0         ; interrupt number
io_addr         dw      300h,0          ; I/O address for card
base_addr       dw      0c000h,0        ; base segment for board
base_selector   dw      ?

driver_class    db      BLUEBOOK,IEEE8023,0             ;from the packet spec
driver_type     db      13              ;from the packet spec
driver_name     db      "3c507",0       ;name of the hardware chip.
driver_function db      2
parameter_list  label   byte
                db      1               ;major rev of packet driver
                db      9               ;minor rev of packet driver
                db      14              ;length of parameter list
                db      EADDR_LEN       ;length of MAC-layer address
                dw      GIANT           ;MTU, including MAC headers
                dw      MAX_MULTICAST * EADDR_LEN       ;buffer size of multicast addrs
                dw      0               ;(# of back-to-back MTU rcvs) - 1
                dw      0               ;(# of successive xmits) - 1
int_num         dw      0               ;Interrupt # to hook for post-EOI
                                        ;processing, 0 == none,

; System Configuration Pointer
scp_struc       struc
scp_bus         db      ?,?,?, ?,?,?    ; bus use flag (0=16 bit, 1=8 bit).
scp_ptr         dd      ?               ; 24pointer to iscp
scp_struc       ends

; Intermediate System Configuration Pointer
iscp_struc      struc
iscp_busy       db      ?,?             ; busy flag (zeroed after init).
iscp_offset     dw      ?               ; 16pointer to iscp
iscp_base       dd      ?               ; base for all 16 pointers, lo, hi
iscp_struc      ends

; System Control Block
scb_struc       struc
scb_stat        dw      ?               ; status
scb_com         dw      ?               ; command
scb_cbl         dw      ?               ; 16pointer to command block list
scb_rfa         dw      ?               ; 16pointer to receive frame list
scb_serrs       dw      4 dup(?)        ; 4 words of error counts
scb_struc       ends

; (Received) Frame Descriptor
fd_struc        struc
fd_status       dw      ?               ; status word for frame
fd_eol          dw      ?               ; end of FD list flag
fd_link         dw      ?               ; 16pointer to next FD
fd_ptr          dw      ?               ; 16pointer to list of RBD's
fd_dest         db      EADDR_LEN dup(?); 48 bits of destination
fd_source       db      EADDR_LEN dup(?); 48 bits of source
fd_cnt          dw      ?               ; length field of frame.
fd_struc        ends

; Receive Buffer Descriptor
rbd_struc       struc
rbd_status      dw      ?               ; status word in RBD
rbd_link        dw      ?               ; 16pointer to next RBD
rbd_ptr         dd      ?               ; 24pointer to actual buffer
rbd_size        dw      ?               ; size of the buffer
rbd_struc       ends

; Transmit Command Block
tcb_struc       struc
tcb_status      dw      ?               ; status word for xmit
tcb_com         dw      ?               ; command to transmit
tcb_link        dw      ?               ; 16pointer to next command
tcb_ptr         dw      ?               ; 16pointer to xmit TBD
tcb_addr        db      EADDR_LEN dup(?); destination address
tcb_len         dw      ?
tcb_struc       ends

; Transmit Buffer Descriptor
tbd_struc       struc
tbd_status      dw      ?               ; bit 15=EOF, 13-0=actual count
tbd_link        dw      ?               ; 16pointer to next TBD
tbd_ptr         dd      ?               ; 24pointer to buffer
tbd_struc       ends

; all commands have at least the following:
cmd_struc       struc
cmd_status      dw      ?               ; status word
cmd_com         dw      ?               ; command word.
cmd_struc       ends

; MC-SETUP Command Block
mcb_struc       struc
mcb_status      dw      ?               ; status word for multicast
mcb_com         dw      ?               ; command to setup multicast
mcb_link        dw      ?               ; 16pointer to next command
mcb_cnt         dw      ?               ; number of multicast addresses.
mcb_struc       ends

; TDR Command Block
tdr_struc       struc
tdr_status      dw      ?               ; status word for TDR
tdr_com         dw      ?               ; command to setup TDR
tdr_link        dw      ?               ; 16pointer to next command
tdr_time        dw      ?               ; error bits and time
tdr_struc       ends

;Memory allocation.
SCPTR           equ     0fff6h          ; hardwired address for SCP
ISCPTR          equ     0ffeeh          ; my address for ISCP, points to SCB
SCB             equ     ISCPTR - 16     ; system control block base
CCBPTR          equ     SCB - 18        ; offset of configure command block
TBDPTR          equ     CCBPTR - 8      ; xmit BD offset
TCBPTR          equ     TBDPTR - 16     ; xmit CB offset
TBUFPTR         equ     TCBPTR - GIANT  ; xmit buffer offset

;the receive buffers appear at lower addresses than TBUFPTR.
RBUFLEN         equ     200
RBUF_TOTAL      equ     (size fd_struc) + (size rbd_struc) + RBUFLEN
FDBASE          equ     TBUFPTR - RBUF_TOTAL

memory_begin    dw      ?

firstfd         dw      FDBASE          ; start of FD queue
lastfd          dw      0               ; end of the FD chain
lastbd          dw      0               ; end of the BD chain
flag            dw      0


; Configuration block for 82586, this comprises one config command
;  Parameters taken from MICOM driver
;
cbconf          dw      0               ; status word
                dw      8002H           ; end of command list + configure command
                dw      0ffffh          ; link to next command (not used)
                dw      080CH           ; fifo=8, byte count=C
                dw      2E00H           ; important! Addr (AL) not inserted on the fly!
                dw      6000H           ; IFS = 60h
                dw      0F200H          ; retry=F, slot time=200h
cbconf_flags    label   byte
                dw      0               ; flags, set to 1 for promiscuous
cbconf_minlen   label   byte
                dw      40H             ; min frame length=40h

timeout         dw      ?               ;number of ticks to wait.
timeout_counter dw      ?               ;old counter zero value.

ScpFlag         db      0               ; bus use flag (0=16 bit, 1=8 bit)

old_rcv_isr     dd      0               ; original owner of board int

per_handle      struc
in_use          db      0               ;non-zero if this handle is in use.
packet_type     db      MAX_P_LEN dup(0);associated packet type.
packet_type_len dw      0               ;associated packet type length.
receiver        dd      0               ;receiver handler.
receiver_sig    db      8 dup(?)        ;signature at the receiver handler.
class           db      ?               ;interface class
per_handle      ends

handles         per_handle MAX_HANDLE dup(<>)
end_handles     label   byte

multicast_count dw      0               ;count of stored multicast addresses.
multicast_broad db      0ffh,0ffh,0ffh,0ffh,0ffh,0ffh   ; entry for broadcast
multicast_addrs db      MAX_MULTICAST*EADDR_LEN dup(?)

have_my_address db      0               ;nonzero if our address has been set.
my_address      db      MAX_ADDR_LEN dup(?)
my_address_len  dw      ?

rcv_mode_num    dw      3

free_handle     dw      0               ; temp, a handle not in use
found_handle    dw      0               ; temp, handle for our packet
receive_ptr     dd      0               ; the pkt receive service routine

send_head       dd      0               ; head of transmit queue
send_tail       dd      0               ; tail of transmit queue

our_address     db      6 dup(?)        ;temporarily hold our address

statistics_list label   dword
packets_in      dd      ?
packets_out     dd      ?
bytes_in        dd      ?
bytes_out       dd      ?
errors_in       dd      ?
errors_out      dd      ?
packets_dropped dd      ?               ;dropped due to no type handler.

;=====================================================================================================
.CODE

;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; OpenEthernet:
;    Checks the hardware (3Com EtherLink 16's (3c507 based)) and sets up chip level parameters.
; int OpenEthernet(void);
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
OPENETHERNET    proc    far
;  chip always looks at SCP for config info which points to ISCP for the
;  pointer to the CONTROL BLOCK which handles everything from there.
;  Kind of indirect, but it works.

        pushad
        push    ds
        push    es
        push    fs

        mov     ax,DGROUP               ;set up our datasegment
        mov     ds,ax

        mov     al,int_no
        call    MaskInt                 ;disable the interrupt.

        ;  Initialize the Ethernet board, set receive type.
        ;  check for correct EPROM location
        call    CheckBoard

        ;  Initialize the Ethernet board.
        sub     base_addr,0e00h
        mov     di,0e000h               ;our initial base address.
        mov     si,ISCPTR-2             ;try the init down a little.

        ;  Now discern the end of memory by repeatedly re-initializing the board
        ;  until the BUSY flag in the ISCP gets reset.
        mov     base_selector,0         ;start with no base selector
re_discern:
        cmp     base_selector,0         ;check for need to free the previous descriptor
        je      get_selector
        mov     ax,1                    ;set up to free the previous descriptor
        mov     bx,base_selector
        int     31h                     ;make it happen
get_selector:
        mov     ax,0                    ;set up to allocate a descriptor
        mov     cx,1                    ;only get 1
        int     31h                     ;make it happen
        mov     base_selector,ax        ;save the selector off
        mov     bx,ax                   ;move the selector into the bx for next INT
        mov     ax,7                    ;set up to set base address
        mov     cx,base_addr            ;set the upper 16 bits of the 32 bit base address (cx:dx)
	shr     cx,12
        mov     dx,base_addr            ;set the lower 16 bits
        shl     edx,4
        int     31h                     ;make it happen
        mov     ax,8                    ;set up to set the segment limit
        mov     bx,base_selector        ;bring back the selector
		  mov     cx,0                    ;set limit to 64k
		  mov     edx,0ffffh                    ;clear the lower 16 bit of 32 bit limit (cx:dx)
        int     31h                     ;make it happen
        mov     es,base_selector        ;set the es to the selector

        call    InitRoot                ;did we find our memory size?
        jc      confng                  ;no, keep trying.
        inc     si                      ;yes, see if we found the real one.
        inc     si
        call    InitRoot                ;try initializing it in a different locn.
        jnc     confok                  ;it worked!  we've found the root.
        dec     si                      ;it didn't work, keep trying.
        dec     si
confng:
        or      di,di                   ;did we try all 64K?
        je      confbad                 ;yes.

        add     base_addr,200h          ;advance the segment by 2000h bytes.
        sub     di,2000h                ;retreat the offset by 2000h bytes.
        jmp     re_discern              ;try this next higher address.
confbad:
        sti
        jmp     timeout_error

confok:
        mov     memory_begin,di
        call    Reconfigure
        jc      confbad

        ;  Ask the board for the Ethernet address, and then use AddAddress to set it.
        push    ds
        pop     es
        mov     di,offset our_address
        mov     cx,EADDR_LEN
        call    CopyAddress

        push    ds
        pop     fs
        mov     si,offset our_address
        mov     cx,EADDR_LEN
        call    AddAddress
        jnc     store_address_2
        sti

timeout_error:
        pop     fs
        pop     es
        pop     ds
        popad
        mov     ax,0                    ;return 0 as error flag
        ret

store_address_2:
        mov     es,base_selector        ;set the es to the selector

        ;  IA sent, setup all of the other data structures on the board
        ;  start with xmit command descriptors
        mov     di,TCBPTR
        mov     es:[di].tcb_status,0
        mov     es:[di].tcb_com,08004h
        mov     es:[di].tcb_link,-1
        mov     es:[di].tcb_ptr,TBDPTR

        add     di,(size tcb_struc)

        mov     es:[di].tbd_status,0
        mov     es:[di].tbd_link,0
        mov     es:[di].tbd_ptr.offs,TBUFPTR
        mov     es:[di].tbd_ptr.segm,0

        ; Note that we allocate fd's, rbd's, and buffers all at the same time.  This
        ; doesn't mean that each pair of fd's and rbd's necessarily have anything to
        ; do with each other.  We just allocate them together because we want to have
        ; the same number of each, and it's easier to compute that way.
        mov     di,TBUFPTR              ;get the last buffer.

        mov     ax,di                   ;compute the amount of free memory.
        sub     ax,memory_begin
        xor     dx,dx
        mov     bx,RBUF_TOTAL           ;each buffer takes this much.
        div     bx
        mov     cx,ax                   ;put the number of buffers into cx.

init_rbuff_0:
        sub     di,RBUF_TOTAL           ;back the pointer down by a little.

        ;init the FD.
        mov     es:[di].fd_status,0
        mov     es:[di].fd_eol,0
        mov     es:[di].fd_ptr,-1
        lea     ax,[di]-RBUF_TOTAL      ;get the address of the next buffer.
        mov     es:[di].fd_link,ax

        ;init the BD.
        lea     bx,[di + (size fd_struc)]
        mov     es:[bx].rbd_status,0
        lea     ax,[bx-RBUF_TOTAL]      ;make a pointer to the next BD
        mov     es:[bx].rbd_link,ax
        lea     ax,[bx+(size rbd_struc)]        ;make a pointer to the buffer.
        mov     es:[bx].rbd_ptr.offs,ax
        mov     es:[bx].rbd_ptr.segm,0
        mov     es:[bx].rbd_size,RBUFLEN        ;length of the buffer.

        loop    init_rbuff_0

init_rbuff_1:
        ;patch the parameters of the last FD and BD so they link around to the head.
        mov     es:[di].fd_eol,8000h
        mov     es:[di].fd_link,FDBASE
        mov     lastfd,di

        lea     bx,[di + (size fd_struc)]
        mov     es:[bx].rbd_link,FDBASE + (size fd_struc)
        mov     es:[bx].rbd_size,RBUFLEN + 8000h
        mov     lastbd,bx

        ;now put the location of the first rbd into the first fd.
        mov     es:[FDBASE].fd_ptr,FDBASE  + (size fd_struc)

        call    EnableNetwork

        ; Test to see if the network is okay.
        mov     di,CCBPTR               ; start of config command block
        xor     ax,ax                   ; zero status word for commmand
        stosw
        mov     ax,8005h                ; TDR command + EL
        stosw
        xor     ax,ax
        dec     ax
        stosw                           ; set link value to -1 (unused)
        inc     ax
        stosw                           ; zero time result.

        mov     ax,100h                 ; do-command command
        call    DoCaWait
        jnc     do_tdr_2                ; finished okay.
        mov     ax,2000h                ; treat a timeout as an open
        jmp     short do_tdr_5
do_tdr_2:
        mov     ax,word ptr es:[CCBPTR].tdr_time
do_tdr_5:
        test    ax,8000h
        jne     do_tdr_3
        test    ax,2000h
        je      do_tdr_4
        cmp     ax,2000h
        je      do_tdr_3
do_tdr_4:
do_tdr_3:

        ;  Start the RU, doesn't need CB, only SCB parms.
        ;   command, to start receiving
        mov     es:[SCB].scb_rfa,FDBASE ; set to frame descriptors
        mov     ax,10h                  ; start RU
        call    DoCaWait

        ; Now reset CX, FR, CNA, and RNR so that we don't get a spurious interrupt.
        mov     ax,es:[SCB].scb_stat    ;get the status.
        and     ax,0f000h               ;isolate the ACK bits.
        mov     es:[SCB].scb_com,ax     ;make a command to
                                        ;acknowledge the interrupt.
        call    DoCa

        ; Now hook in our interrupt
        call    SetRcvISR

        sti

        mov     al, int_no              ; Get board's interrupt vector
        add     al, 8
        cmp     al, 8+8                 ; Is it a slave 8259 interrupt?
        jb      set_int_num             ; No.
        add     al, 70h - 8 - 8         ; Map it to the real interrupt.
set_int_num:
        xor     ah, ah                  ; Clear high byte
        mov     int_num,ax              ; Set parameter_list int num.

        pop     fs
        pop     es
        pop     ds
        popad
        mov     ax,1                    ;return 1 as flag indicating the Open worked
        ret
OPENETHERNET    endp





;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; DriverInfo:
;    Get info on the hardware and this driver.
; void DriverInfo(int &nFunctionality,int &nVersion,int &nClass,int &nNumber,int &nType);
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
DRIVERINFO     proc    far
        assume  ds:DGROUP
        di_FunctionalitySel     equ     word ptr [bp+24]
        di_FunctionalityOff     equ     word ptr [bp+22]
        di_VersionSel           equ     word ptr [bp+20]
        di_VersionOff           equ     word ptr [bp+18]
        di_ClassSel             equ     word ptr [bp+16]
        di_ClassOff             equ     word ptr [bp+14]
        di_NumberSel            equ     word ptr [bp+12]
        di_NumberOff            equ     word ptr [bp+10]
        di_TypeSel              equ     word ptr [bp+8]
        di_TypeOff              equ     word ptr [bp+6]

        push    bp
        mov     bp,sp
        push    es
        push    ds
        mov     ax,DGROUP
        mov     ds,ax

        mov     es,di_FunctionalitySel          
        mov     di,di_FunctionalityOff          
        mov     al,driver_function
        cbw
        mov     es:[di],ax

        mov     es,di_VersionSel                
        mov     di,di_VersionOff                
        mov     word ptr es:[di],MAJVER

        mov     es,di_ClassSel                  
        mov     di,di_ClassOff                  
        mov     al,driver_class
        cbw
        mov     es:[di],ax

        mov     es,di_NumberSel                 
        mov     di,di_NumberOff                 
        mov     word ptr es:[di],0

        mov     es,di_TypeSel                   
        mov     di,di_TypeOff
        mov     al,driver_type
        cbw
        mov     es:[di],ax

        pop     ds
        pop     es
        pop     bp
        ret	20
DRIVERINFO     endp



;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; AccessType:
;    Set the protocol type and the receive handler.  A handle is returned that should
;    be used to access further functions.
;
; int (handle) AccessType(int nClass,int nNumber,int nType,int nTypeLen,LPSTR pTypeDesc,
;                 Pvoid pRcvHandler);
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
ACCESSTYPE     proc    far
        assume  ds:DGROUP
        at_Class                equ     word ptr [bp+20]
        at_Number               equ     word ptr [bp+18]
        at_Type                 equ     word ptr [bp+16]
        at_TypeLen              equ     word ptr [bp+14]
        at_TypeDescSel          equ     word ptr [bp+12]
        at_TypeDescOff          equ     word ptr [bp+10]
        at_RcvHandlerSel        equ     word ptr [bp+8]
        at_RcvHandlerOff        equ     word ptr [bp+6]

        push    bp
        mov     bp,sp
        push    ds
        push    es

        mov     ax,DGROUP
        mov     ds,ax

        ;register caller of pkt TYPE
        mov     bx,offset driver_class
access_type_9:
        mov     al,[bx]                 ;get the next class.
        inc     bx
        or      al,al                   ;end of the list?
        jnz     access_type_1a
        jmp     access_type_class       ;class failed
access_type_1a:
        cmp     byte ptr at_Class,al    ;our class?
        jne     access_type_9           ;no, try again

access_type_1:
        cmp     at_Type,-1              ;generic type?
        je      access_type_2           ;yes.
        mov     al,driver_type
        cbw
        cmp     at_Type,ax              ;our type?
        je      access_type_2
        jmp     access_type_type        ;no.

access_type_2:
        cmp     at_Number,0             ;generic number?
        je      access_type_3
        cmp     at_Number,1             ;our number?
        je      access_type_3
        jmp     access_type_number

access_type_3:
        cmp     at_TypeLen,MAX_P_LEN    ;is the type length too long?
        jbe     access_type_3a
        jmp     access_type_bad         ;yes - can't be ours.

access_type_3a:
        ; now we do two things--look for an open handle, and check the existing
        ; handles to see if they're replicating a packet type.
        mov     free_handle,0           ;remember no free handle yet.
        mov     bx,offset handles
access_type_4:
        cmp     [bx].in_use,0           ;is this handle in use?
        je      access_type_5           ;no - don't check the type.
        mov     al,byte ptr at_Class    ;is this handle the same class as
        cmp     al,[bx].class           ;  they're want?
        jne     short access_type_6
        mov     es,at_TypeDescSel       ;type pointer's segment
        mov     di,at_TypeDescOff       ;type pointer's offset
        mov     cx,at_TypeLen           ;get the minimum of their length
                                        ;  and our length.  As currently
                                        ;  implemented, only one receiver
                                        ;  gets the packets, so we have to
                                        ;  ensure that the shortest prefix
                                        ;  is unique.
        cmp     cx,[bx].packet_type_len ;Are we less specific than they are?
        jb      access_type_8           ;no.
        mov     cx,[bx].packet_type_len ;yes - use their count.
access_type_8:
        lea     si,[bx].packet_type
        or      cx,cx                   ; pass-all TYPE? (zero TYPE length)
        jne     access_type_7           ; ne = no
        mov     bx,offset handles+(MAX_HANDLE-1)*(size per_handle)
        jmp     short access_type_5     ; put pass-all last
access_type_7:
        repe    cmpsb
        jne     short access_type_6     ;go look at the next one.

access_type_inuse:
        mov     ax,-1                   ;a handle has been assigned for TYPE (flag error)
        jmp     access_type_leave

access_type_5:                          ;handle is not in use
        cmp     free_handle,0           ;found a free handle yet?
        jne     access_type_6           ;yes.
        mov     free_handle,bx          ;remember a free handle
access_type_6:
        add     bx,(size per_handle)    ;go to the next handle.
        cmp     bx,offset end_handles   ;examined all handles?
        jb      access_type_4           ;no, continue.

        mov     bx,free_handle          ;did we find a free handle?
        or      bx,bx
        je      access_type_space       ;no - return error.

        mov     [bx].in_use,1           ;remember that we're using it.

        mov     ax,at_RcvHandlerSel     ;remember the receiver type.
        mov     [bx].receiver.segm,ax
        mov     ax,at_RcvHandlerOff
        mov     [bx].receiver.offs,ax

        push    ds                      ;set the ES
        pop     es
        push    ds                      ;save the DS
        mov     ds,at_TypeDescSel       ;Type descriptor's selector
        mov     si,at_TypeDescOff       ;Type descriptor's offset
        mov     cx,at_TypeLen           ;Type length
        mov     es:[bx].packet_type_len,cx      ; remember the TYPE length
        lea     di,[bx].packet_type
        rep     movsb

        lds     si,es:[bx].receiver     ;copy the first 8 bytes
        lea     di,[bx].receiver_sig    ; to the receiver signature.
        mov     cx,8/2
        rep     movsw

        pop     ds                      ;restore the DS

        mov     al,byte ptr at_Class
        mov     [bx].class,al
        mov     ax,bx                   ;return the handle to them.
        jmp     access_type_leave

access_type_space:
        mov     dh,NO_SPACE
        mov     ax,-1
        jmp     access_type_leave

access_type_class:
        mov     dh,NO_CLASS
        mov     ax,-1
        jmp     access_type_leave

access_type_type:
        mov     dh,NO_TYPE
        mov     ax,-1
        jmp     access_type_leave

access_type_number:
        mov     dh,NO_NUMBER
        mov     ax,-1
        jmp     access_type_leave

access_type_bad:
        mov     dh,BAD_TYPE
        mov     ax,-1
        jmp     access_type_leave

access_type_leave:
        pop     es
        pop     ds
        pop     bp
        ret	16
ACCESSTYPE     endp



;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; ReleaseType:
;    Releases the users based on their handle.
;
; void ReleaseType(int nHandle)
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
RELEASETYPE    proc    far
        assume  ds:DGROUP
        rt_Handle       equ     word ptr [bp+6]
        push    bp
        mov     bp,sp
        push    ds

        mov     ax,DGROUP
        mov     ds,ax

        mov     bx,rt_Handle
        mov     [bx].in_use,0

        pop     ds
        pop     bp
        ret	2
RELEASETYPE    endp



;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; SendPkt:
;    Sends out the packet pointed to by the second parameters.
;
; int (ccode) SendPkt(int nLen,BYTE far *pPacket);
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
SENDPKT                proc    far
        assume  ds:DGROUP
        sp_Len          equ     word ptr [bp+10]
        sp_PacketSel    equ     word ptr [bp+8]
	sp_PacketOff    equ     word ptr [bp+6]

	push    bp
        mov     bp,sp
        push    ds
	push    es

	mov	ax,DGROUP		;set up the datasegment
        mov	ds,ax

	mov     es,base_selector        ;base for board

	inc     packets_out
        movzx   ecx,sp_Len              ;get the packet length
        add     bytes_out,ecx           ;add up the received bytes.

	cmp     cx,GIANT                ; Is this packet too large?
        jbe     send_pkt_goodsize       ; no
        mov     ax,-1                   ; yes, flag error and leave
        jmp     send_pkt_leave

send_pkt_goodsize:
        mov     dx,cx                   ;save a copy, might be less than 60, ok

        cmp     dx,RUNT                 ;minimum length for Ether
        jnb     oklen
        mov     dx,RUNT                 ;make sure size at least RUNT
oklen:
        mov     di,TBUFPTR              ;start of xmit buffer
        ;check for previous xmit
xwait:
        mov     bx,es:[SCB].scb_com     ; has previous command been accepted?
        or      bx,bx
        jnz     xwait                   ; not there yet, wait for it

wait_for_transmit_to_complete:
        test    word ptr es:[TCBPTR],4000h
	jnz     wait_for_transmit_to_complete

        push	ds
	mov     ds,sp_PacketSel         ;packet buffer's selector
        mov     si,sp_PacketOff         ;packet buffer's offset
	call    MoveMem
        pop	ds

        ;put the correct size into the TBD
        or      dx,08000h                       ; end of frame bit flag
        mov     es:[TBDPTR].tbd_status,dx       ; store it
        mov     es:[TCBPTR].tcb_status,0        ; zero status wd
        mov     es:[TCBPTR].tcb_com,8004h       ; xmit command in TCB
        mov     es:[SCB].scb_com,0100h          ; execute command
        mov     es:[SCB].scb_cbl,TCBPTR ; say where xmit command is

	call    DoCa

        xor     ax,ax                   ;set good CCode
send_pkt_leave:
        pop     es
        pop     ds
        pop     bp
	ret     6
SENDPKT                endp



;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; TerminateLAN:
;    Terminates activities with the board, deactivates the IRQ and reestablishes the
;    original owner of the IRQ.
;
; int (ccode) TerminateLAN(int nHandle);
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
TERMINATELAN   proc    far
        assume  ds:DGROUP
        tl_Handle       equ     word ptr [bp+6]

        push    bp
        mov     bp,sp
        push    ds

        mov     ax,DGROUP
        mov     ds,ax

        mov     bx,tl_Handle            ; get the handle passed to us
        mov     [bx].in_use,0           ; mark handle as free
        mov     bx,offset handles       ; check that all handles are free
f_terminate_2:
        cmp     [bx].in_use,0           ; is this handle free?
        je      f_terminate_5
        mov     ax,-1                   ;flag an error and leave
        jmp     f_terminate_4

f_terminate_5:
        add     bx,(size per_handle)    ; next handle
        cmp     bx,offset end_handles   ; examined all handles?
        jb      f_terminate_2           ; b = no, continue examination

        ; Now disable interrupts
        mov     al,int_no
        or      al,al                   ;are they using a hardware interrupt?
        je      f_terminate_no_irq      ;no.

        call    MaskInt                 ;clear the 8259

        ; Now return the interrupt to their handler.
        mov     ah,25h                  ;get the old interrupt into es:bx
        mov     al,int_no
        add     al,8
        cmp     al,8+8                  ;is it a slave 8259 interrupt?
        jb      f_terminate_3           ;no.
        add     al,70h - (8+8)          ;map it to the real interrupt.
f_terminate_3:
        push    ds
        lds     dx,old_rcv_isr
        int     21h
        pop     ds

f_terminate_no_irq:
        xor     ax,ax

f_terminate_4:
        pop     ds
        pop     bp
	ret	2
TERMINATELAN   endp



;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; GetAddress:
;    Retrieves the current address and puts it out to a supplied buffer.
;
; int (length) GetAddress(int nHandle,int nAddrLen,BYTE far *pAddrBuff);
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
GETADDRESS     proc    far
        assume  ds:DGROUP
        ga_Handle               equ     word ptr [bp+12]
        ga_AddrLen              equ     word ptr [bp+10]
        ga_AddrBuffSel          equ     word ptr [bp+8]
        ga_AddrBuffOff          equ     word ptr [bp+6]

        push    bp
        mov     bp,sp
        push    ds

        mov     ax,DGROUP
        mov     ds,ax

        mov     es,ga_AddrBuffSel       ;get address buffer's selector
        mov     di,ga_AddrBuffOff       ;get address buffer's offset
        mov     cx,ga_AddrLen           ;get the buffers max length

        cmp     have_my_address,0       ;has our address been set?
        jne     get_address_set         ;yes - go report it.
        call    CopyAddress             ;no, can we get the address?
        jc      get_address_space       ;no - we must not have enough space.

        mov     ax,cx                   ;return with the actual length
        jmp     get_address_space

get_address_set:
        cmp     cx,my_address_len       ;is there enough room?
        jb      get_address_space       ;no.
        cld
        mov     cx,my_address_len       ;yes - get our address length.
        mov     ax,cx                   ;return with the actual length
        mov     si,offset my_address    ;copy it into their area.
        rep     movsb

get_address_space:
        pop     ds
        pop     bp
        ret     8
GETADDRESS     endp


CopyAddress     proc    near
        ;get the address of the interface.
        ;enter with es:di -> place to put the address, cx = size of address buffer.
        ;exit with nc, cx = actual size of address, or cy if buffer not big enough.
        assume  ds:DGROUP

        cmp     cx,EADDR_LEN            ;make sure that we have enough room.
        jb      get_address_2
        mov     cx,EADDR_LEN
        mov     dx,io_addr              ; Get our IO base address.
        cld
get_address_1:
        in      al,dx                   ; get a byte of the eprom address
        stosb                           ; put it away
        inc     dx                      ; next register
        loop    get_address_1           ; go back for rest
        mov     cx,EADDR_LEN
        clc
        ret
get_address_2:
        stc
        ret	
CopyAddress     endp



;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; ResetInterface:
;    Resets the hardware.
;
; void ResetInterface(int nHandle);
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
RESETINTERFACE proc    far
        ri_Handle               equ     word ptr [bp+6]
        ;*** Do this later ***
        ret	2
RESETINTERFACE endp



;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; GetParameters:
;    Gets receive, transmit and error parameters.
;
; void GetParameters(LAN_PARAM_STRUC far *pParams);
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
GETPARAMETERS  proc    far
        gp_ParamsSeg            equ     word ptr [bp+8]
        gp_ParamsOff            equ     word ptr [bp+6]
        ;*** Do this later ***
        ret	4
GETPARAMETERS  endp



;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; SetRcvMode:
;    Sets the mode that the receiver will operate in.
;       Modes: 1-Turn off receiver
;              2-Receive only unicast packets
;              3-mode 2 plus broadcast
;              4-mode 3 plus limited multicast
;              5-mode 4 plus all multicast
;              6-all packets
;
; void SetRcvMode(int nHandle,int nRcvMode);
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
SETRCVMODE     proc    far
        assume  ds:DGROUP
        sr_Handle               equ     word ptr [bp+8]
        sr_RcvMode              equ     word ptr [bp+6]

        jmp     rcv_mode_start

rcv_modes       label   word
        dw      7               ;number of receive modes in our table.
        dw      0               ;There is no mode zero
        dw      0
        dw      rcv_mode_2
        dw      rcv_mode_3
        dw      rcv_mode_4      ;haven't set up perfect filtering yet.
        dw      0
        dw      rcv_mode_6

rcv_mode_start:
        push    bp
        mov     bp,sp
        push    ds

        mov     ax,DGROUP
        mov     ds,ax
        mov     bx,sr_Handle            ;get the handle
        mov     cx,sr_RcvMode           ;get the receive mode

        cmp     cx,rcv_mode_num         ;are we already using that mode?
        je      f_set_rcv_mode_1        ;yes, no need to check anything.

        mov     dx,bx                   ;remember our handle.
        mov     bx,offset handles       ; check that all handles are free
f_set_rcv_mode_2:
        cmp     bx,dx                   ; is this our handle?
        je      f_set_rcv_mode_3        ; yes, of course it's not free.
        cmp     [bx].in_use,0           ; is this handle free?
        jne     f_set_rcv_mode_1        ; ne = no, can't change
f_set_rcv_mode_3:
        add     bx,(size per_handle)    ; next handle
        cmp     bx,offset end_handles   ; examined all handles?
        jb      f_set_rcv_mode_2        ; b = no, continue examination

        mov     cx,sr_RcvMode           ;get the receive mode again
        cmp     cx,rcv_modes            ;do they have this many modes?
        jae     f_set_rcv_mode_1        ;no - must be a bad mode for us.
        mov     bx,cx
        shl     bx,1                    ;we're accessing words, not bytes.
        mov     ax,rcv_modes[bx]+2      ;get the handler for this mode.
        or      ax,ax                   ;do they have one?
        je      f_set_rcv_mode_1        ;no - must be a bad mode for us.
        mov     rcv_mode_num,cx         ;yes - remember the number and
        jmp     ax                      ;  call it.

f_set_rcv_mode_1:
        pop     ds
        pop     bp
        ret	4

;-- sub procedure -----------------------------------------------------
rcv_mode_2:
        and     cbconf_flags,not 3
        or      cbconf_flags,2          ;disable broadcasts.
        mov     cbconf_minlen,40h
        jmp     short rcv_reconfig
rcv_mode_4:
rcv_mode_3:
        and     cbconf_flags,not 3      ;clear promiscuous mode.
        mov     cbconf_minlen,40h
        jmp     short rcv_reconfig
rcv_mode_6:
        and     cbconf_flags,not 3
        or      cbconf_flags,1          ;set promiscuous mode.
        mov     cbconf_minlen,0         ;allow runts.
rcv_reconfig:
        call    Reconfigure

        jmp     f_set_rcv_mode_1
SETRCVMODE     endp



;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; GetRcvMode:
;    Gets the current receive mode.
;       Modes: 1-Turn off receiver
;              2-Receive only unicast packets
;              3-mode 2 plus broadcast
;              4-mode 3 plus limited multicast
;              5-mode 4 plus all multicast
;              6-all packets
;
; int (rcv mode) GetRcvMode(int nHandle);
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
GETRCVMODE     proc    far
        assume  ds:DGROUP
        gr_Handle               equ     word ptr [bp+6]
        push    ds

        mov     ax,DGROUP
        mov     ds,ax
        mov     ax,rcv_mode_num         ;return the current receive mode.

        pop     ds
        ret	2
GETRCVMODE     endp



;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; SetMultiCastList:
;    Set the multicast list with an address.
;
; void SetMultiCastList(int nAddrLen,BYTE far *pAddr);
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
SETMULTICASTLIST       proc    far
        assume  ds:DGROUP
        smc_AddrLen             equ     word ptr [bp+10]
        smc_AddrSel             equ     word ptr [bp+8]
        smc_AddrOff             equ     word ptr [bp+6]

        push    bp
        mov     bp,sp
        push    ds

        mov     ax,DGROUP
        mov     ds,ax

        mov     cx,smc_AddrLen          ;get the address length

        ;verify that they supplied an even number of EADDR's.
        mov     ax,cx
        xor     dx,dx
        mov     bx,EADDR_LEN
        div     bx
        or      dx,dx                   ;zero remainder?
        jne     f_set_multicast_list_2  ;no, we don't have an even number of addresses

        cmp     ax,MAX_MULTICAST        ;is this too many?
        ja      f_set_multicast_list_2  ;yes - return NO_SPACE

f_set_multicast_list_1:
        mov     multicast_count,ax      ;remember the number of addresses.

        push    ds
	push    cx
        mov     ds,smc_AddrSel          ;address selector
        mov     si,smc_AddrOff          ;address offset

        push    ds
        pop     es
        mov     di,offset multicast_addrs
        cld     
        rep     movsb

        pop     cx
        pop     ds

        mov     si,offset multicast_addrs
        call    AddMultiCastList
f_set_multicast_list_2:

        pop     ds
        pop     bp
        ret	6
SETMULTICASTLIST       endp



;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; GetMultiCastList:
;    Gets the multicast list and stores it at the address pointer.
;
; void GetMultiCastList(int &nListBytes,BYTE far *pAddrList);
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
GETMULTICASTLIST       proc    far
        assume  ds:DGROUP
        gmc_ListBytesSel        equ     word ptr [bp+12]
        gmc_ListBytesOff        equ     word ptr [bp+10]
        gmc_AddrListSel         equ     word ptr [bp+8]
        gmc_AddrListOff         equ     word ptr [bp+6]

        push    bp
        mov     bp,sp
        push    ds
        push    es

        mov     ax,DGROUP
        mov     ds,ax

        mov     ax,EADDR_LEN            ;multiply the count by the length.
        mul     multicast_count
        mov     es,gmc_ListBytesSel     ;callers list byte pointer's selector
        mov     di,gmc_ListBytesOff     ;callers list byte pointer's offset
        mov     es:[di],ax              ;store the byte count back at callers var

        mov     es,gmc_AddrListSel      ;callers list pointer's selector
        mov     di,gmc_AddrListOff      ;callers list pointer's offset
        mov     word ptr es:[di],offset multicast_addrs ;store our multicast list pointer 
        mov     es:[di+2],ds            ;   at callers pointer

        pop     es
        pop     ds
        pop     bp
	ret	8
GETMULTICASTLIST       endp



;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; GetStatistics:
;    Gets the multicast list and stores it at the address pointer.
;
; void GetStatistics(int nHandle,LAN_STATS_STRUC far *pStats);
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
GETSTATISTICS  proc    far
        gs_Handle               equ     word ptr [bp+10]
        gs_StatsSel             equ     word ptr [bp+8]
        gs_StatsOff             equ     word ptr [bp+6]

        ;*** Do this later ***
        ret	6
GETSTATISTICS  endp



;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; SetAddress:
;    Overwrite the boards unique address.
;
; void SetAddress(int nAddrLen,BYTE far *pAddr);
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
SETADDRESS     proc    far
        assume  ds:DGROUP
        sa_AddrLen              equ     word ptr [bp+10]
        sa_AddrSel              equ     word ptr [bp+8]
        sa_AddrOff              equ     word ptr [bp+6]

        push    bp
        mov     bp,sp
        push    ds
        push    es
        push    fs

        mov     ax,DGROUP
        mov     ds,ax

        mov     bx,offset handles
        mov     cl,0                    ;number of handles in use.
f_set_address_1:
        add     cl,[bx].in_use          ;is this handle in use?
        add     bx,(size per_handle)    ;go to the next handle.
        cmp     bx,offset end_handles
        jb      f_set_address_1

        cmp     cl,1                    ;more than one handle in use?
        ja      f_set_address_exit      ;yes - we can't set the address

        mov     fs,sa_AddrSel           ;the address's selector
        mov     si,sa_AddrOff           ;the address's offset
        mov     cx,sa_AddrLen

        call    AddAddress
        jc      f_set_address_exit      ;Did it work?

        mov     ax,cx                   ;put the actual length into the ax

        cmp     cx,MAX_ADDR_LEN         ;is it too long for us to remember?
        ja      f_set_address_exit      ;yes, return a too-long error.

        mov     my_address_len,cx       ;remember how long our address is.

        push    ds                      ;save the DS
	push    ds                      ;set ES with DS
        pop     es
        mov     ds,sa_AddrSel           ;address segment
        mov     si,sa_AddrOff
        mov     di,offset my_address
        rep     movsb

        pop     ds                      ;restore the DS
        mov     have_my_address,1

f_set_address_exit:
        pop     fs
        pop     es
        pop     ds
        pop     bp
        ret	6
SETADDRESS     endp



;-----------------------------------------------------------------------------------------------------
Reconfigure     proc    near
        push     es

        mov     es,base_selector        ;get the base address for the board.
        mov     si,offset cbconf        ; configure command
        mov     di,CCBPTR               ; where command will reside
        mov     cx,9
        rep     movsw                   ; copy to board

        ;  issue the configure command
        mov     es:[SCB].scb_cbl,CCBPTR ; where conf command is
        mov     es:[SCB].scb_serrs[0],0 ; zero errs field
        mov     es:[SCB].scb_serrs[2],0 ; zero errs field
        mov     es:[SCB].scb_serrs[4],0 ; zero errs field
        mov     es:[SCB].scb_serrs[6],0 ; zero errs field
        mov     ax,100h                 ; do-command command
        call    DoCaWait

        pop     es
        ret
Reconfigure     endp




AddAddress      proc    near
        ;enter with fs:si -> Ethernet address, CX = length of address.
        ;exit with nc if okay, or cy, dh=error if any errors.
        cmp     cx,EADDR_LEN            ;ensure that their address is okay.
        je      AddAddress_4
        mov     dh,BAD_ADDRESS
        stc
        jmp     short AddAddress_done
AddAddress_4:

        ;  Next step, load our address into the board
        ;  reuses the space that the configure command used, with different command
        mov     es,base_selector        ; set to base address
        mov     es:[SCB].scb_cbl,CCBPTR ; say where conf command is

        mov     di,CCBPTR               ; start of config command block
        xor     ax,ax
        push    ds
	push    fs
        pop     ds
        stosw                           ; zero status word for commmand

        mov     ax,8001h                ; IA setup command + EL
        stosw
        mov     ax,-1
        stosw                           ; set link value to -1 (unused)

        rep     movsb                   ; move their ethernet address in.
        pop     ds                      ; restore the datasegment

        ;start the IA setup command
        mov     ax,100h                 ; do-command command
        call    DoCaWait
        jnc     AddAddress_okay
        mov     dh,-1                   ; no error in the list applies.
        jmp     short AddAddress_done
AddAddress_okay:
        mov     cx,EADDR_LEN            ;return their address length.
        clc
AddAddress_done:
        ret
AddAddress      endp



EnableNetwork   proc    near
        ;connect to network
        loadport
        setport IO_CONTROL
        mov     al,_RST or IEN or VB0
        out     dx,al
        ret
EnableNetwork   endp



Reset586        proc    near
        ;reset the chip
        loadport
        setport IO_CONTROL
        mov     al,LBK
        out     dx,al
        jmp     $+2
        jmp     $+2
        mov     al,_RST or LBK or VB0
        out     dx,al
        setport IO_INTCLR               ;clear the interupt latch.
        out     dx,al
        ret
Reset586        endp
        

DoCa            proc    near
        loadport
        setport IO_CA
        out     dx, al
        ret
DoCa    endp



DoCaWait        proc    near
	;enter with ax = command to execute, es = base_selector.
        ;exit with nc if the command ran to completion.
        ;exit with cy if the command timed out.  Eventually we'll also reset the chip.
        mov     es:[SCB].scb_com,ax     ;set the command.

        mov     si,es:[SCB].scb_cbl     ;
	mov     es:[si].cmd_status,0    ; status word of specific command
        and     ax,0700h
        cmp     ax,0100h                ; is it an action command?
        jne     doca_wait_a             ; no, any other

        call    DoCa

	comment \
        The value for the deadman timer should be greater than the longest
        command execution time.  The command which can take the longest time
        to execute is the transmit command, assuming maximum retries.  To
        determine the maximum amount of time the transmit command may take,
        one must use the following equation: 7143 ST + 14 f, where ST stands
        for Slot Time and f = Maximum Frame Size + IFS + Preamble.  For
        Ethernet/IEEE 802.3 where ST = 512 bits, f = 12144 bits, Preamble =
        64 bits, IFS  96 bits, and one bit = 0.1 usec, the deadman timeout
        should be greater than 0.369 seconds.
        \

        mov     ax,14                   ;36.4 ticks / seconds * .369 seconds
        call    SetTimeout
doca_wait_1:
        test    es:[si].cmd_status,8000h        ; is command complete?
        jnz     doca_wait_2             ;yes.
        call    DoTimeout               ;did we time out yet?
        jne     doca_wait_1             ;not yet.
;reset the chip here, then Configure, IA-Setup, and MC-Setup.
        stc                             ;timeout -- uh-oh.
        ret
doca_wait_2:
        clc
        ret

doca_wait_a:
        call    DoCa
doca_wait_a_0:
        cmp     es:[SCB].scb_com,0      ; has the command been accepted?
        jnz     doca_wait_a_0           ; not yet.
        clc
        ret
DoCaWait        endp



SetTimeout      proc    near
        ;we read the timer chip's counter zero.  It runs freely, counting down
        ;from 65535 to zero.  Whenever the count is above the old count, the
        ;timer must have wrapped around.  When that happens, we count down a tick.
        ;enter with ax = number of ticks (36.4 ticks per second).
        inc     ax                      ;the first times out immediately.
        mov     timeout,ax
        mov     timeout_counter,0
        ret
SetTimeout      endp



DoTimeout       proc    near
	;call periodically when checking for timeout.  Returns nz if we haven't
        ;timed out yet.
        mov     al,0                    ;latch counter zero.
        out     43h,al
        in      al,40h                  ;read counter zero.
        mov     ah,al
        in      al,40h
        xchg    ah,al
        cmp     ax,timeout_counter      ;is the count higher?
        mov     timeout_counter,ax
        jbe     do_timeout_1            ;no.
        dec     timeout                 ;Did we hit the timeout value yet?
        ret
do_timeout_1:
        or      sp,sp                   ;ensure nz.
        ret
DoTimeout       endp



AddMultiCastList        proc    near
	;enter with ds:si ->list of multicast addresses, cx = number of addresses.
	;return nc if we set all of them, or cy,dh=error if we didn't.
	mov     es,base_selector
	mov     es:[SCB].scb_cbl,TBUFPTR        ;use the transmit buffer.

	mov     es:[TBUFPTR].mcb_status,0       ;status word
	mov     es:[TBUFPTR].mcb_com,08003h     ;command word for mc-setup + EL
	mov     es:[TBUFPTR].mcb_link,-1        ;no command link.
	mov     di,TBUFPTR + mcb_cnt
	mov     ax,cx                   ;store the count.
	stosw
	rep     movsb

	comment \
	avoid deferred execution of a CU command during reception.
	If a command is executed with a length of 18 to 20 bytes, and a frame
	is received, the 82586 may deadlock with HOLD active.  We avoid this
	problem by suspending the receiver.
	\

	mov     ax,30h                  ;suspend frame receiving.
	call    DoCaWait

	mov     ax,100h                 ; do-command command
	call    DoCaWait
	jnc     AddMultiCastList_2

	mov     ax,20h                  ;resume frame receiving.
	call    DoCaWait

	mov     dh,NO_MULTICAST         ;for some reason we can't do multi's.
	stc
	ret
AddMultiCastList_2:
	mov     ax,20h                  ;resume frame receiving.
	call    DoCaWait

	clc
	ret
AddMultiCastList        endp


MoveMem         proc    near
	jcxz    movemem_cnte            ; If zero, we're done already.
        test    si,1                    ; Does source start on odd byte?
        jz      movemem_adre            ; Go if not
        movsb                           ; Yes, move the first byte
        dec     cx                      ; Count that byte
movemem_adre:
        shr     cx,1                    ; convert to word count
        rep     movsw                   ; Move the bulk as words
        jnc     movemem_cnte            ; Go if the count was even
        movsb                           ; Move leftover last byte
movemem_cnte:
        ret
MoveMem         endp



CheckBoard      proc    near
	mov     ScpFlag,0               ; 16 bit bus type in scb.

        call    WriteIdPattern

        loadport
        setport IO_RAM
        in      al,dx
        and     al,3                    ;get the window size.
        ;00 = 16K, 01 = 32K, 10 = 48K, 11 = 64K.
        cmp     al,3
        je      check_board_2
        stc
        ret
check_board_2:
        in      al,dx
        test    al,20h                  ;8088 address or 80286 address?
        je      check_board_3
        stc
        ret

check_board_3:
        and     al,18h
        ;00 = 0c000h, 08 = 0c800h, 10 = 0d000h, 18 = 0d800h.
        mov     ah,al
        xor     al,al
        add     ah,0c0h
        mov     base_addr,ax

        setport IO_INT
        in      al,dx
        and     al,0fh
        mov     int_no,al

        setport IO_CONTROL
        mov     al,_RST or IEN or VB0
        out     dx,al
        ret

CheckBoard      endp



WriteIdPattern  proc    near
        mov     dx,100h
        xor     al,al
        out     dx,al                   ;reset hardware pattern generator
        mov     cx,0ffh
        mov     al,0ffh
write_id_pat_1:
        out     dx,al                   ;keep writing matching values...
        shl     al,1
        jnc     write_id_pat_2
        xor     al,0e7h
write_id_pat_2:
        loop    write_id_pat_1
        xor     al,al
        out     dx,al                   ;now put adapter in RUN state.
        ret
WriteIdPattern  endp



InitRoot        proc    near
        ;enter with es:di -> beginning of our system memory window,
	;  si -> place to put ISC.
        ;exit with nc if it worked, cy if it didn't work.
        mov     al,ScpFlag
        mov     es:[SCPTR].scp_bus,al
        mov     es:[SCPTR].scp_ptr.offs,si
        mov     es:[SCPTR].scp_ptr.segm,0

        mov     es:[si].iscp_busy,1             ;set busy bit.
        mov     es:[si].iscp_offset,SCB         ;point to the SCB.
        mov     es:[si].iscp_base.offs,0        ;scb base.
        mov     es:[si].iscp_base.segm,0        ;scb base.

        call    Reset586                ; reset the 586, hardware-specific.

        ;  Issue a CA to initialize the chip after reset
        call    DoCa

        mov     ax,2                    ;don't wait too long.
        call    SetTimeout
init_root_2:
	cmp     es:[si].iscp_busy,0     ;did it clear the busy flag?
        je      init_root_1             ;yes.
        call    DoTimeout
        jne     init_root_2
	stc
        ret
init_root_1:
        clc
	ret
InitRoot        endp



SetRcvISR       proc    near
	mov     ah,35h                  ;get the old interrupt into es:bx
        mov     al,int_no               ; board's interrupt vector
	or      al,al
	je      set_isr_no_irq
        add     al,8
        cmp     al,8+8                  ;is it a slave 8259 interrupt?
	jb      set_recv_isr_1          ;no.
        add     al,70h - 8 - 8          ;map it to the real interrupt.
set_recv_isr_1:
        int     21h
	mov     old_rcv_isr.offs,bx     ;remember the old seg:off.
        mov     old_rcv_isr.segm,es

        mov     ah,25h                  ;now set our ProcessRcvd interrupt.
	push    ds
        push    cs
	pop     ds

	;**** Debug *****
        ;mov     dx,offset RcvISR
	mov     dx,offset RealReturn
	int     21h
	pop     ds

;*** Debug **********
	mov     dx,offset RcvISR
	mov	cx,cs
	mov	ax,0205h
	mov     bl,077h
	int 	031h

        mov     al,int_no               ; Now enable interrupts
        call    UnMaskInt

set_isr_no_irq:
        ret
SetRcvISR       endp



MaskInt         proc    near
        mov     dx,21h                  ;assume the master 8259.
        cmp     al,8                    ;using the slave 8259?
        jb      mask_not_irq2
        mov     dx,0a1h                 ;disable slave 8259
        sub     al,8
mask_not_irq2:
        mov     cl,al
	in      al,dx                   ;disable them on the correct 8259.
        mov     ah,1                    ;set the bit.
        shl     ah,cl
        or      al,ah
        out     dx,al
maskint_1:
        ret
MaskInt         endp



UnMaskInt       proc    near
        mov     dx,21h                  ;assume the master 8259.
        mov     cl,al
        cmp     cl,8                    ;using the slave 8259?
        jb      unmask_not_irq2         ;no
        in      al,dx                   ;get master mask
        and     al,not (1 shl 2)        ; and clear slave cascade bit in mask
        out     dx,al                   ;set new master mask (enable slave int)
        mov     dx,0a1h                 ;go enable int on slave 8259
        sub     cl,8
unmask_not_irq2:

        in      al,dx                   ;enable interrupts on the correct 8259.
        mov     ah,1                    ;clear the bit.
        shl     ah,cl
        not     ah
        and     al,ah
        out     dx,al
        ret
UnMaskInt       endp


RealReturn:
	iret

        
;=========================================================================================
RcvISR:
        ; In order to achieve back-to-back packet transmissions, we handle the
        ; latency-critical portion of transmit interrupts first.  The xmit
        ; interrupt routine should only start the next transmission, but do
        ; no other work.  It may only touch ax and dx (the only register necessary
        ; for doing "out" instructions) unless it first pushes any other registers
        ; itself.
        push    ax
        push    dx

        cld
        push    ds
        push    bx
        push    cx
        push    si
        push    di
        push    bp
        push    es

        mov     ax,DGROUP
        mov     ds,ax           ;set our data segment selector

        mov     al,int_no       ; Disable further device interrupts
        call    MaskInt

        ; this code dismisses the interrupt at the 8259. if the interrupt number
	;  is > 8 then it requires fondling two PICs instead of just one.
        mov     al, int_no      ; get hardware int #
        cmp     al, 8           ; see if its on secondary PIC
        jg      recv_isr_4
        add     al, 60h         ; make specific EOI dismissal
        out     20h, al
        jmp     recv_isr_3      ; all done
recv_isr_4:
        add     al,60h - 8      ; make specific EOI (# between 9 & 15).
        out     0a0h,al         ; Secondary 8259 (PC/AT only)
        mov     al,62h          ; Acknowledge on primary 8259.
        out     20h,al
recv_isr_3:

	sti                     ; Interrupts are now completely safe
        call    ProcessRcvd

	cli                     ;interrupts *must* be off between
                                ;here and the stack restore, because
                                ;if we have one of our interrupts
                                ;pending, we would trash our stack.
        mov     al,int_no       ; Now reenable device interrupts
        call    UnMaskInt

        pop     es
        pop     bp
        pop     di
        pop     si
        pop     cx
        pop     bx

        pop     ds
        pop     dx
        pop     ax
        iret


;*** ISR Routines *******************************************************************************
ProcessRcvd            proc    near
        loadport                        ;clear the interupt latch.
        setport IO_INTCLR
        out     dx,al

        mov     flag,1
recv1:
        mov     es,base_selector        ; base for board
        mov     ax,es:[SCB].scb_stat    ;get the status.
recv_isr_1:
        cmp     es:[SCB].scb_com,0      ;has previous command been accepted?
        jne     recv_isr_1              ;no -- keep waiting.

        and     ax,0f000h               ;isolate the ACK bits to make a
                                        ;  command to ack the interrupt.
        mov     es:[SCB].scb_com,ax     ;set the command.
        call    DoCa
recv_isr_2:
        cmp     es:[SCB].scb_com,0      ; has the command been accepted?
        jnz     recv_isr_2              ; not yet.

        ;  Get whatever packets are on the board
        mov     bx,firstfd              ; get addr of first FD in list
        mov     ax,es:[bx].fd_status    ; status word of frame
        test    ax,08000h               ; frame written?
        jnz     okframe

        jmp     ru_start                ; no, restore receiver if necessary
frame_bad:
        inc     errors_in

ptrupdate_j_1:
        jmp     ptrupdate

        ;  we have a frame, read it in
okframe:
        test    ax,02000h               ;check frame OK bit
        jz      frame_bad               ;bad, fix it.
        mov     si,es:[bx].fd_ptr       ;get pointer to buffer descriptor
        xor     cx,cx                   ;start with zero bytes.
countbuf:                               ;es:si is already set to receive packet
        mov     dx,si                   ;save a copy of current BD ptr
        mov     ax,es:[si].rbd_status   ;get status and count word for BD
        test    ax,04000h               ;is count field there?
        jz      ptrupdate_j_1           ;no - we give up here.
        add     cl,al                   ;add the count into cx.
        adc     ch,0
        mov     si,es:[si].rbd_link     ;go to next BD in list
        test    ax,8000h                ;is this the last frame?
        je      countbuf                ;no - keep counting.

        push    bx
        push    cx

        mov     di,es:[bx].fd_ptr       ;get pointer to buffer descriptor
        mov     di,es:[di].rbd_ptr.offs ;get offset of data
        add     di,EADDR_LEN+EADDR_LEN  ;skip the ethernet addreses and
                                        ;  point to the packet type.
        mov     dl,BLUEBOOK             ;assume bluebook Ethernet.
        mov     ax,es:[di]
        xchg    ah,al
        cmp     ax,1500
        ja      BlueBookPacket
        inc     di                      ;set di to 802.2 header
        inc     di
        mov     dl,IEEE8023
BlueBookPacket:
        call    LookupCallbacks         ;look up our type.

        pop     cx                      ;restore cx,bx
        pop     bx

        mov     ax,es                   ;is this pointer null?
        or      ax,di
        je      ptrupdate               ;yes - just free the frame.

        push    bx                      ;save the BX
        push    cx                      ;save the CX
        push    ds                      ;save the DS
        mov     ax,base_selector
        mov     ds,ax
        mov     si,[bx].fd_ptr          ;get pointer to buffer descriptor
copybuf:
        mov     dx,si                   ;save a copy of current BD ptr
        xor     ch,ch                   ;200 bytes is largest this can be
        mov     cl,byte ptr [si].rbd_status  ;get count word for BD
        mov     si,[si].rbd_ptr.offs    ;get offset of data

        call    MoveMem
        mov     si,dx                   ;get back current BD ptr
	test    [si].rbd_status,8000h   ;check EOF bit
        mov     si,[si].rbd_link        ;go to next BD in list
        jz      copybuf                 ;not done, keep copying it.
        pop     ds                      ;restore the DS
        pop     cx                      ;restore the CX

        push    cx                      ;set up for client call (push the frame length)
        push    word ptr 1              ;signal that the message is fully in
        call    receive_ptr             ;call the client
        add     sp,4

        pop     bx                      ;restore the BX

        ;  we are done with the frame, do the list management
ptrupdate:
        mov     es,base_selector        ; reload board segment
        mov     si,es:[bx].fd_ptr       ; first BD in frame list
nextbd:
        mov     cx,es:[si].rbd_status   ; count word for BD, EOF bit
        test    cx,08000h               ; EOF bit, if set, save si in lastbd
        jnz     dolastbd
        mov     es:[si].rbd_status,0    ; clear status word, EOF bit
        cmp     si,lastbd               ; see if we are wrapping
        jz      dolastbd                ; yes, just undo it
        mov     si,es:[si].rbd_link     ; follow link
        jmp     nextbd
dolastbd:
        mov     di,lastbd               ; where end of BD list is now
        mov     lastbd,si               ; store last known BD
        mov     es:[si].rbd_size,08000h+200; end of list here
        mov     es:[si].rbd_status,0    ; clear status word, EOF bit

        ; size field for not end of list
        mov     es:[di].rbd_size,200    ; remove old end-of-list

        ;  update the FD list flags, new end-of-list
        mov     es:[bx].fd_eol,08000h   ; store new EOL
        mov     es:[bx].fd_status,0     ; clear status word for frame
        mov     di,lastfd               ; get old end-of-list
        mov     es:[di].fd_eol,0        ; zero old one
        mov     lastfd,bx               ; update stored pointer
        mov     si,es:[bx].fd_link      ; where next fd is
        mov     firstfd,si              ; store that info for next time

ru_start:
        ; re-start receive unit
        ;  check to see if the receiver went off because of no resources
        ;  and restart receiver if necessary
        mov     es,base_selector
        mov     ax,es:[SCB].scb_stat    ; status word for SCB
        and     ax,070h         ; receiver status
        cmp     al,020h         ; receiver has no resources
        jnz     hasres

        ;  setup lists for starting the RU on the chip
        ;  we know that there isn't anything in the buffer that we want
        mov     bx,firstfd              ; get first FD on free list (assume free)
        mov     es:[SCB].scb_rfa,bx     ; put into SCB
        mov     si,lastbd               ; pointer to a BD, end of chain
        mov     ax,es:[si].rbd_link     ; pointer to next BD
        mov     es:[bx].fd_ptr,ax       ; set to start of BDs

        ;  Start the RU, doesn't need CB, only SCB parms.
        ;   command, to start receiving again
	mov     ax,10h                  ; start RU
        call    DoCaWait
hasres:
        ret
ProcessRcvd            endp


LookupCallbacks         proc    near
        ;called when we want to determine what to do with a received packet.
        ;enter with cx = packet length, es:di -> packet type, dl = packet class.
        ;exit with es:di = 0 if the packet is not desired, or es:di -> packet buffer
        ;  to be filled by the driver.
        push    cx

        mov     bx,offset handles
recv_find_1:
        cmp     [bx].in_use,0           ;is this handle in use?
        je      recv_find_2             ;no - don't check the type.

        mov     ax,[bx].receiver.offs   ;do they have a receiver?
        or      ax,[bx].receiver.segm
        je      recv_find_2             ;no - they're not serious about it.

        mov     cx,[bx].packet_type_len ;compare the packets.
        lea     si,[bx].packet_type
        jcxz    recv_find_3             ;if cx is zero, they want them all.

        cmp     [bx].class,dl           ;is this the right class?
        jne     recv_find_2             ;no- don't bother

        push    di
        repe    cmpsb
        pop     di
        je      recv_find_3             ;we've got it!
recv_find_2:
        add     bx,(size per_handle)    ;go to the next handle.
        cmp     bx,offset end_handles
        jb      recv_find_1

        inc     packets_dropped

        pop     cx                      ;we didn't find it -- discard it.
        xor     di,di                   ;"return" a null pointer.
        mov     es,di
        ret

recv_find_3:
        pop     cx                      ; the packet_length

        inc     packets_in
        add     bytes_in.offs,cx        ;add up the received bytes.
        adc     bytes_in.segm,0

        les     di,[bx].receiver        ;remember the receiver upcall.
        mov     receive_ptr.offs,di
        mov     receive_ptr.segm,es

        mov     found_handle,bx         ;remember what our handle was.

        push    cx                      ;push the packet length before call
        push    word ptr 0              ;signal a buffer request
        call    receive_ptr             ;ask the client for a buffer.
	add     sp,4
	push	 ds
	pop		 es             ;get the buffer address
	mov     di,ax
        ret
LookupCallbacks        endp


end
