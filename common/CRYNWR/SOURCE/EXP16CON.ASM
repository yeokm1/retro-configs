;-----------------------------------------------------------------------------
; It is safe to assume that the command unit is up and running ready
; for the first send.  And that there are at least two send buffers 
; available.
;
; This procedure works by sending a 64 byte packet to itself.  We do not turn
; on loopback, so we do not expect to see a receive.  Instead, we
; expect to see that the send completed OK.  If the send does not complete OK, 
; then this routine switches to other connectors and the test is repeated. 
;-----------------------------------------------------------------------------
auto_connector:

; Let's start doing the test send with AUI option first.  If we tried BNC
; first, and they were using AUI, it would seem like the BNC worked.  So
; we switch to AUI, which turns off the BNC power supply.
	MOV	connection_type, CONN_AUI
	CALL	write_connector_setting_to_hardware

; Test connection to see if it works.  Jump if it does.
	call	test_send
	clc
	je	auto_connector_exit

; Toggle AUI/Other setting and try to send a packet.  Jump if send 
; works.  Now try sending on BNC.
	MOV	connection_type, CONN_BNC
	CALL	write_connector_setting_to_hardware
	call	test_send
	clc
	je	auto_connector_exit

; Here if we just tried a send the BNC.  If this is 
; a three connector card, then we toggle the BNC/TPE setting.
; Jump if connection is found.
	MOV	connection_type, CONN_TPE
	CALL	write_connector_setting_to_hardware
	call	test_send
	clc
	je	auto_connector_exit
	stc
auto_connector_exit:
	ret


test_packet	label	byte
	db	EADDR_LEN dup(?)
	db	EADDR_LEN dup(?)
	db	00h,2eh			;A 46 in network order
	db	0,0			;DSAP=0 & SSAP=0 fields
	db	0f3h,0			;Control (Test Req + P bit set)

;-----------------------------------------------------------------------------
; This procedure sends a packet on the wire and wait for the send to
; complete.  It the checks to see if the send completed OK and returns
; the results.
;-----------------------------------------------------------------------------
test_send:

	mov	si,offset rom_address	;set the destination address.
	movseg	es,cs
	mov	di,offset test_packet
	repmov	EADDR_LEN
	mov	si,offset rom_address	;set the source address.
	repmov	EADDR_LEN

	mov	cx,60
	mov	si,offset test_packet
	call	send_pkt

	CALL	ReadTickCounter
	MOV	CX, AX

	mov	bp,io_addr
	lea	dx, [bp].@TxCB_Status
send_test_wait:
	in	ax,dx
	test	ax,8000h		;did it finish?
	jne	send_test_done

; See if we have been here for a millisecond.  Jump if not.
	call	ReadTickCounter
	neg	ax
	add	ax, cx
	cmp	ax, one_mil
	jb	send_test_wait

	in	ax,dx			;get the transmit status back again.

send_test_done:

	mov	cx, ax			; Save status in CX.

; The send block at the head of the list completed OK.  Clear the
; transmit command block status.
	xor	ax, ax
	out	dx, ax

; Send is complete.  Get the status and compare to OK send and return.
; Save flags for return.

	and	cx, 0f000h
	cmp	cx, 0a000h
	ret

