version equ     4

        include defs.asm        ;SEE ENCLOSED COPYRIGHT MESSAGE
NCB_NOWAIT         equ 80h         ;  Command wait flag

NCB_RESET          equ 32h         ;  Reset adapter
NCB_CANCEL         equ 35h         ;  Cancel command
NCB_STATUS         equ 33h         ;  Get NETBIOS intf status
NCB_UNLINK         equ 70h         ;  Unlink   (RPL)
NCB_ADDNAME        equ 30h         ;  Add name
NCB_ADDGNAME       equ 36h         ;  Add group name
NCB_DELNAME        equ 31h         ;  Delete name
NCB_FINDNAME       equ 78h         ;  Find name
NCB_CALL           equ 10h         ;  Call
NCB_LISTEN         equ 11h         ;  Listen
NCB_HANGUP         equ 12h         ;  Hang up
NCB_SEND           equ 14h         ;  Send
NCB_CHSEND         equ 17h         ;  Chain send
NCB_RECEIVE        equ 15h         ;  Receive
NCB_RECANY         equ 16h         ;  Receive any
NCB_SESSTATUS      equ 34h         ;  Get session status
NCB_SDATAGRAM      equ 20h         ;  Send datagram
NCB_SBROADCAST     equ 22h         ;  Send broadcast
NCB_RDATAGRAM      equ 21h         ;  Receive datagram
NCB_RBROADCAST     equ 23h         ;  Receive broadcast
NCB_TRACE          equ 79h         ;  Start trace

;
; Network Control Block structure
;
ncb             struc
ncb_command     db ?
ncb_retcode     db ?
ncb_lsn         db ?
ncb_num         db ?
ncb_buffer      dd ?
ncb_length      dw ?
ncb_callname    db 16 dup(?)
ncb_name        db 16 dup(?)
ncb_rto         db ?
ncb_sto         db ?
ncb_post        dd ?
ncb_lana_num    db ?
ncb_cmd_cplt    db ?
ncb_reserve     db 14 dup(?)
ncb             ends

;
; ARP packet structure
;
arp		struc 
arp_hw		dw ? 		; Hardware address length, bytes 
arp_prot	dw ? 		; Protocol type 
arp_hwalen	db ? 		; hardware address length, bytes 
arp_pralen 	db ? 		; Length of protocol address 
arp_opcode      dw ? 		; ARP opcode (request/reply) 
arp_shwaddr	db 6 dup(?)	; Sender hardware address field 
arp_sprotaddr	dd ?		; Sender Protocol address field 
arp_thwaddr	db 6 dup(?)	; Target hardware address field 
arp_tprotaddr	dd ?		; Target protocol address field 
arp		ends

code    segment word public
        assume  cs:code, ds:code
;***************************************************************
prefix          db "TCPIP"

        public  int_no
int_no  db      0,0,0,0
ip_adress       dw      2 dup(0)
rq_size         dw      3
padding         dd      0

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class    db      1,0             ;from the packet spec
driver_type     db      0               ;from the packet spec
driver_name     db      'netbios',0     ;name of the driver.
driver_function	db	2
parameter_list	label	byte
	db	1			;major rev of packet driver
	db	9			;minor rev of packet driver
	db	14			;length of parameter list
	db	EADDR_LEN		;length of MAC-layer address
	dw	1500			;MTU, including MAC headers
	dw	MAX_MULTICAST * EADDR_LEN	;buffer size of multicast addrs
	dw	0			;(# of back-to-back MTU rcvs) - 1
	dw	0			;(# of successive xmits) - 1
int_num	dw	0			;Interrupt # to hook for post-EOI
					;processing, 0 == none,

	public	rcv_modes
rcv_modes	dw	4		;number of receive modes in our table.
		dw	0,0,0,rcv_mode_3

lana_num        db 0
local_ncb_num   db 0  			; handle returned by add_name


        public  nbsend, nbrcv1, nbrcv2, rcv_buffer1 ; MAP
nbsend          ncb <>
nbrcv1          ncb <>
nbrcv2          ncb <>


MAX_DG          equ 1500 
rcv_buffer1     db MAX_DG dup(?)

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


;
; recv_find() requires a pointer to the Ethernet packet type.  Since
; the incoming packet does not contain an Ethernet packet type field,
; memory must be allocated to hold the Ethernet packet type.  Space is
; required for both IP and ARP types.
;
ip_type		label	byte
		db	08
		db	00	

arp_type	label	byte
		db	08
		db	06	

gw_switch	db	00


        public  send_pkt
send_pkt:
        assume ds: nothing
;enter with ds:si -> packet, cx = packet length.
;exit with nc if ok, or else cy if error, dh set to error number.
	cmp	cx,GIANT		; Is this packet too large?
	ja	send_pkt_toobig

        push    es
        push    bx
        push    ds

;strip off Ethernet header
	add	si,12
	mov	ax, word ptr ds:[si]
	add	si,2
	sub	cx,14
;
; Check packet type.  If an ARP packet then construct an ARP reply
; packet. Otherwise, process the incoming IP packet.
;
	cmp	ax,0608h
	jne	noarp
	call	arp_reply
	jmp	send_ok
noarp:
	
        push    cs
        pop     es
;
; Set up NCB for a "SEND DATAGRAM" operation
;
        mov     bx,offset cs:nbsend

        mov     cs:[bx].ncb_buffer.offs,si
        mov     ax,ds
        mov     cs:[bx].ncb_buffer.segm,ds
        mov     cs:[bx].ncb_length,cx

        push    bx
        lea     di,cs:nbsend.ncb_callname
;
; If gateway switch set then contruct NETBIOS name based on the destination
; IP address in the IP packet. Otherwise, construct the NETBIOS name
; based on the destination Ethernet address.
;
	mov	al,gw_switch
	cmp	al,0
	je	use_hw_addr
	mov	bx, word ptr ds:[si+16]
	mov	dx, word ptr ds:[si+18]
	jmp	conv_addr
use_hw_addr:
	mov	bx, word ptr ds:[si-12]
	mov	dx, word ptr ds:[si-10]
conv_addr:
        push    cs
        pop     ds
        call    ip_to_nbname
        pop     bx
;
; Pass "Send Datagram" NCB to NETBIOS
;
        int     5ch
;
; If "Send Datagram" operation is unsuccessful then print return code and
; set carry bit.  Otherwise, clear the carry bit.
;
        cmp     al,0
        jz      send_ok
        add     ax,32
        call    tty
        mov     al,'S'
        call    tty
        stc
        jmp     send_done
send_ok:
        clc
send_done:
        pop     ds
        pop     bx
        pop     es
        ret

send_pkt_toobig:
	mov	dh,NO_SPACE
	stc
	ret

;
; Formulate a dummy ARP reply packet.  ds:si points at the incoming
; IP packet.
;
arp_reply:
;
; Save the registers.  Not sure that we need to but it works and I 
; don't want to change it right now.
;
	push	ds
	push	es
	push	si
	push	di
	push	cx
;
; Check to see if the ARP request is to find the hardware address
; of the local host.  If so, then don't formulate a reply packet.
;
	mov	cx,4
	mov	ax,si
	mov	di,ax
	mov	ax,ds
	mov	es,ax
	add	di,arp_sprotaddr
	add	si,arp_tprotaddr
	repe	cmpsb			; Compare source and target
					; protocol address
	jnz	arp_reply_2
	pop	cx
	pop	di
	pop	si
	pop	es
	pop	ds
	ret
arp_reply_2:
;
; Restore registers.
;
	pop	cx
	pop	di
	pop	si
	push	si
	push	di
	push	cx
;
; Restore Ethernet header.
;
	add	cx,14
	sub	si,14 
;
; Ask application layer for a memory buffer in which to store
; incoming packet.
;
	push	ds
	push	si			;save si in case we reject it.
	push	bx
	push	cx

	mov	ax,cs
	mov	es,ax
	mov	ds,ax
	mov	di, offset arp_type
	mov	dl,cs:driver_class
	call	recv_find		;look up our type.
	pop	cx
	pop	bx
	pop	si
	pop	ds

	mov	ax,es			;is this pointer null?
	or	ax,di
	je	arp_reply_1		;yes - just free the frame.

	push	cx
	push	es
	push	di
;
; Save si,di for future use.
;
	mov	bx,si
	mov	dx,di
;
; Set up ARP Reply by first copying the ARP Request packet.
;
	rep	movsb
;
; Skip Ethernet header
;
	add	bx,14
	add 	dx,14
;
; Swap target and source protocol addresses from ARP request to ARP 
; reply packet.
;
	mov	si,bx
	mov	di,dx	
	mov	cx,4
	add	si,arp_tprotaddr
	add	di,arp_sprotaddr
	rep	movsb

	mov	si,bx
	mov	di,dx
	mov	cx,4
	add	si,arp_sprotaddr
	add	di,arp_tprotaddr
	rep	movsb
;
; Swap target and source hardware addresses from ARP request to ARP 
; reply packet.
;
	mov	si,bx
	mov	di,dx
	mov	cx,6
	add	si,arp_shwaddr
	add	di,arp_thwaddr
	rep	movsb
;
; Load source hardware address in ARP reply packet.
;
	mov	si,bx
	mov	di,dx
	add	di,arp_shwaddr
	mov	es:[di],word ptr 0000h
	add	di,2
	mov	cx,4
	add	si,arp_tprotaddr	; Set Ethernet address in ARP reply
					; to target IP address
	rep	movsb
;
; Set opcode to REPLY.
;
	mov	di,dx
	mov	word ptr es:[di].arp_opcode,0200h
; 
; Give ARP reply packet that has been constructed to the application
; layer.
;
	pop	si
	pop	ds
	pop	cx
	assume	ds:nothing

	call	recv_copy
	assume	ds:code

arp_reply_1:

	pop	cx
	pop	di
	pop	si
	pop	es
	pop	ds

	ret


	public	set_address
set_address:
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
	assume	ds:nothing
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
	ret

        public  reset_interface
reset_interface:
;reset the interface.
        ret


;called when we want to determine what to do with a received packet.
;enter with cx = packet length, es:di -> packet type.
        extrn   recv_find: near

;called after we have copied the packet into the buffer.
;enter with ds:si ->the packet, cx = length of the packet.
        extrn   recv_copy: near

        extrn   count_in_err: near
        extrn   count_out_err: near
        extrn   dwordout: near
        extrn   error: near

        public  recv
recv:
;called from the recv isr.  All registers have been saved, and ds=cs.
;Upon exit, the interrupt will be acknowledged.
        assume  ds:code
        ret

        public nbint  ; MAP
nbint   proc far
        push ds
;
; Set data segment to code segment so that we can reference local
; variables.
;
        push cs
        pop  ds
;
; Retrieve size of received packet
;
        mov  cx,[bx].ncb_length
;
; Check return code.  If there was an error then don't process the
; packet any further.
;
        mov  al,[bx].ncb_retcode
        cmp  al,0               ; ok
        jnz  bad_nbint
;
; Add Ethernet header.  As well, ensure that minimum packet size is 60
; bytes; some application packages actually check for minimum packet size.
;
	add	cx,14 
	cmp	cx,60
	jge	recv_next
	mov	cx,60
recv_next:
	push	si			;save si in case we reject it.
	push	bx
	push	cx

	movseg	es,cs
	mov	di, offset ip_type
	mov	dl,cs:driver_class
	call	recv_find		;look up our type.

	pop	cx
	pop	bx
	pop	si
	mov	ax,es			;is this pointer null?
	or	ax,di

	jne  nb_next 
        jmp  skip_copy 
nb_next:
	push bx
	push cx
	push es
	push di
;
; Fix up the Ethernet header added to the incoming packet.
;
	call	fix_header
;
; Copy the received packet into buffer allocated by the application
; software.
;
	sub	cx,14
        mov     si,[bx].ncb_buffer.offs
        rep     movsb
	pop si
	pop ds
	pop cx
	assume ds:nothing
        call    recv_copy
	push cs
	pop ds
	assume ds:code
	pop bx
skip_copy:
        mov     [bx].ncb_length,MAX_DG  ; reestablish dg-length
;
; Set up to receive another packet.  Construct "receive datagram"
; NCB.
;
        push    ds
        pop     es
        int	5ch
;
; Check return code.  Print error indication if NETBIOS does not
; accept NCB.
;
        mov	al,[bx].ncb_retcode   ; JS added return code
        cmp     al,0ffh
        jz      nbint_pending_ok1
        mov     al,'?'
        call    tty
        add     ax,32
        call    tty
        mov     al,'.'
        call    tty

nbint_pending_ok1:
        jmp     short nbint_done

bad_nbint:
        add     ax,32
        call    tty
        mov     al,'R'
        call    tty
	jmp	skip_copy

nbint_done:
        pop ds
        iret
nbint   endp

;
; Set destination and source addressess and packet type in an
; Ethernet header.
;
fix_header:
;
; Set destination address.
;
	push	cx
	mov	ax,0000h
	stosw
	mov	ax,ip_adress.offs	;was 0c3c4h
	stosw
	mov	ax,ip_adress.segm	;was 0c2cch
	stosw
;
; Set source address.  NCB callname contains the string "TCPIP" +
; source host IP address.  Extract host IP address and copy into
; Ethernet header as the source address.
;
	mov	ax,0000h
	stosw
	mov	ax,word ptr [bx].ncb_callname+5
	stosw
	mov	ax,word ptr [bx].ncb_callname+7
	stosw
;
; Set packet type to IP.
;
	mov	ax, 0008h
	stosw	

	pop	cx
	ret



        public  nb_stop
nb_stop:
        ;                   unregister name
        push    cs
        pop     es
        lea      bx,nbrcv1
        mov     [bx].ncb_command,NCB_DELNAME
;        mov     al,lana_num
;        mov     [bx].ncb_lana_num,al
        int     5ch
        cmp     al,0
        jz      good_delete
        add     ax,32
        call    tty
        mov     al,'I'
        call    tty
good_delete:
        ret


	public tty
tty:
        push    bx
        mov     ah,14
        int     10h
        pop     bx
        ret

ip_to_nbname:
        ;      call with es:di = *ncb_name
        ;            bx and dx = ip_address

        mov     cx,5
        mov     si,offset prefix
        rep     movsb

        mov     [di],bx
        mov     [di+2],dx
        ret

	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret

;any code after this will not be kept.  Buffers used by the program, if any,
;are allocated from the memory between end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
end_free_mem	label	byte

        public  usage_msg
usage_msg       db      "usage: nb [options] <packet_int_no> <ip.ad.dr.ess> [receive queue size]",CR,LF,'$'

        public  copyright_msg
copyright_msg   db      "Packet driver for a netbios device, version ",'0'+version,CR,LF,'$'
                db      "Portions Copyright 1990, Michael Haberler",CR,LF,'$'

ip_adress_name  db      "IP Adress ",'$'
rq_size_name    db      "Receive Queue ",'$'
bad_name_msg    db      " bad returncode from nb add_name",CR,LF,'$'
bad_rcv_msg     db      " bad returncode from nb receive dg",CR,LF,'$'
good_name_msg   db      " good returncode from nb add_name",CR,LF,'$'
good_rcv_msg    db      " good returncode from nb receive dg",CR,LF,'$'
temp_dw         dw      ?
        extrn   set_recv_isr: near

;enter with si -> argument string, di -> word to store.
;if there is no number, don't change the number.
        extrn   get_number: near
	extrn	skip_blanks: near

;-> the assigned Ethernet address of the card.
	extrn	rom_address: byte

        public  parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	call	skip_blanks
	cmp	al,'-'			;did they specify a switch?
	jne	not_switch
	cmp	byte ptr [si+1],'g'	;did they specify '-g'?
	je	got_gw_switch
	stc				;no, must be an error.
	ret
got_gw_switch:
	mov	gw_switch,1
	add	si,2			;skip past the switch's characters.
	jmp	parse_args		;go parse more arguments.
not_switch:

        mov     di, offset temp_dw
        mov     bx, offset ip_adress_name
        call    get_number
        mov     ax,temp_dw
        mov     byte ptr ip_adress+0,al
        inc     si
        mov     di, offset temp_dw
        mov     bx, offset ip_adress_name
        call    get_number
        mov     ax,temp_dw
        mov     byte ptr ip_adress+1,al
        inc     si
        mov     di, offset temp_dw
        mov     bx, offset ip_adress_name
        call    get_number
        mov     ax,temp_dw
        mov     byte ptr ip_adress+2,al
        inc     si
        mov     di, offset temp_dw
        mov     bx, offset ip_adress_name
        call    get_number
        mov     ax,temp_dw
        mov     byte ptr ip_adress+3,al

        ret



        public  etopen
etopen:
;if all is okay,
;        mov     bx,offset nbsend
        lea     bx,nbsend
        mov     [bx].ncb_command,NCB_ADDNAME
        mov     al,lana_num
        mov     [bx].ncb_lana_num,al

        push    ds
        push    cs
        push    cs
        pop     ds
        pop     es

        push    bx
        lea     di,nbsend.ncb_name
        mov     bx,ip_adress
        mov     dx,ip_adress+2
        call    ip_to_nbname
        pop     bx

;fake up an Ethernet address.
	mov	word ptr rom_address[0],word ptr 0000h
        mov     bx,cs:ip_adress
	mov	word ptr rom_address[4],bx
	mov	bx,cs:ip_adress+2
	mov	word ptr rom_address[2],bx

;	mov	di, offset nbsend.ncb_name
;	mov	cx,16
;mike:
;	mov	al, [di]
;	call	tty
;	inc	di
;	dec	cx
;	jnz	mike


        mov     cx,16
        mov     di,offset nbrcv1.ncb_name
        mov     si,offset nbsend.ncb_name
        rep     movsb
        mov     cx,16
        mov     di,offset nbrcv2.ncb_name
        mov     si,offset nbsend.ncb_name
        rep     movsb

        int     5ch     ; add_name, -> returns rc in al
        cmp     al,0
        jz      good_name
        mov     dx,0
        mov     ah,0
        call    dwordout
        mov     dx,offset bad_name_msg
        pop     ds
	stc
	ret

good_name:
;        mov     dx,offset good_name_msg
;        call    say

        mov     al,[bx].ncb_num
        mov     local_ncb_num,al
        mov     [bx].ncb_command,NCB_SDATAGRAM  ;set send command code

        ;       start receive operations
;        mov     bx,offset nbrcv1
        lea     bx,nbrcv1
        mov     al,NCB_RDATAGRAM+NCB_NOWAIT  ;set rcv command
        mov     [bx].ncb_command,al

        mov     al,local_ncb_num
        mov     [bx].ncb_num,al

        mov     ax,MAX_DG
        mov     [bx].ncb_length,ax

        mov     ax,ds
        mov     [bx].ncb_buffer.segm,ax
        mov     [bx].ncb_buffer.offs,offset rcv_buffer1

        mov     [bx].ncb_post.segm,ax
        mov     [bx].ncb_post.offs,offset nbint

        mov     al,lana_num
        mov     [bx].ncb_lana_num,al
        int     5ch

        cmp     al,0ffh
        jz      pending_ok1
        cmp     al,00h
        jnz     bad_init

pending_ok1:
        mov     dx,offset good_rcv_msg
	mov	ah,9
	int	21h

        pop     ds
        clc
        ret
;if we got an error,
bad_init:
        mov     ah,0
        mov     dx,0
        call    dwordout
        call    nb_stop
        pop     ds
        mov     dx,offset bad_rcv_msg
        stc
        ret

	public	print_parameters
print_parameters:
	ret

say:
        mov     ah,9
        int     21h
        ret


code    ends

	end

