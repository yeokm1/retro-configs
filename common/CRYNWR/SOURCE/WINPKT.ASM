version	equ	2
; File WINPKT.ASM						8 Dec 1991
; Provides a Packet Driver interface between Windows 3 Enhanced mode 
; applications and a real Packet Driver. This attempts to solve the problem
; of Windows moving applications around in memory willy nilly. Install WINPKT
; after the Packet Driver and before starting Windows. 
; Command line is:
;	WINPKT  WINPKT_interrupt number PD_interrupt_number
; with both in the range of 60h to 7fh.
; Build with the Clarkson Packet Driver Collection subprograms:
; 	masm WINPKT;
; 	link WINPKT;
; 	exe2bin WINPKT.EXE WINPKT.COM
; 	del WINPKT.EXE
;
	include defs.asm

;	Copyright, 1988-1992, Russell Nelson
;	Copyright, 1991, Roger F. James
;	Code revised slightly, formatting cleaned up enormously, added
;	documentation, Joe R. Doupnik, jrd@cc.usu.edu, Utah State Univ,
;	8 Dec 1991.

;   This program is free software; you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation, version 1.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License
;   along with this program; if not, write to the Free Software
;   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

code    segment word public
	assume  cs:code, ds:code, es:nothing

	org 2ch
phd_environ dw  0
	org 80h
phd_dioa    label   byte
	org 100h
start:	jmp start_1
	even

;Debugging stuff
;total_pkts	dw  0
;gvm_pkts	dw  0
;bvm_pkts	dw  0

per_handle  struc
in_use		db  0		; non-zero if this handle is in use
their_handle	dw  0		; lower layer handle
recv_handler	dd  0		; receiver upcall
vm_id		dw  0		; VM_ID for this handler
per_handle  ends

handles	per_handle MAX_HANDLE dup(<>)
end_handles label   byte

is_186		db	0		;=0 if 808[68], =1 if 80[123]86.
is_286		db	0		;=0 if 80[1]8[68], =1 if 80[234]86.
is_386		db	0		;=0 if 80[12]8[68], =1 if 80[34]86.

regs    struc               ; stack offsets of incoming regs
	_ES dw  ?
	_DS dw  ?
	_BP dw  ?
	_DI dw  ?
	_SI dw  ?
	_DX dw  ?
	_CX dw  ?
	_BX dw  ?
	_AX dw  ?
	_IP dw  ?
	_CS dw  ?
	_F  dw  ?           ; flags, Carry flag is bit 0
regs    ends

CY	equ 0001h
EI	equ 0200h


bytes   struc			; stack offsets of incoming regs
    	dw  ?			; es, ds, bp, di, si are 16 bits
    	dw  ?
    	dw  ?
    	dw  ?
    	dw  ?
	_DL db  ?
	_DH db  ?
	_CL db  ?
	_CH db  ?
	_BL db  ?
	_BH db  ?
	_AL db  ?
	_AH db  ?
bytes   ends

old_isr		dd  0		; old pkt driver int
their_2f_isr	dd  0		; original int 2f ISR

; The following are globals that assume that the code that access them
; single threads.
MAX_BUFFER_LEN  equ 1520
our_buffer  db  MAX_BUFFER_LEN dup (0)
buffer_flag db  0
buffer_len  dw  0
their_handler   dd  0		; receiver handler to call
their_bx    dw  0
;
;

vmm_running db  0		; 386 virtual machine manager is running
our_handle  dw  0		; current top level handle

	include	movemem.asm

our_isr:
	jmp our_isr_0		; the required signature.
	db  'PKT DRVR',0
	db  'WINPKT',0

our_isr_0:			; check if it one of the calls we
	assume  ds:nothing	; want to intercept (passes addresses)
	cmp	ah,2		; f_access_type?
	je	our_isr_2	; e = yes
	cmp	ah,3		; f_release_type?
	je	our_isr_2
	cmp	ah,5		; f_terminate
	je	our_isr_2
	cmp	ah,8		; f_stop
	je	our_isr_2
our_isr_1:			; nothing needing intercepion
	jmp	old_isr         ; chain to the original Packet Driver

our_isr_2:
	push	ax		; We are interested in this one
	push	bx		; so save some registers
	push	cx
	push	dx
	push	si
	push	di
	push	bp
	push	ds
	push	es
	cld
	mov	bx,cs		; set up DS
	mov	ds,bx
	assume	ds:code

	mov	bp,sp		; use bp to access the original regs
	and	_F[bp],not CY   ; start by clearing the carry flag

	cmp	ah,2            ; f_access_type?
	jne	our_isr_3	; ne = no (it's special here)
	jmp	f_access_type	
our_isr_3:
	cmp	ah,3		; f_release_type?
	jne	our_isr_4	; ne = no
	jmp	f_release_type
our_isr_4:
	cmp	ah,5		; f_terminate?
	jne	our_isr_5	; ne = no
	jmp	f_terminate
our_isr_5:
	jmp	f_stop		; must be f_stop

our_isr_error:
	mov	_DH[bp],dh	; error code
	or	_F[bp],CY       ; return their carry flag
our_isr_return:
	pop	es
	pop	ds
	pop	bp
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	iret

; Windows (and many many other programs) use the Int 2Fh Multiplexor link,
; and each is supposed to grab it's own calls as seen in AX, or chain them
; to the previous Int 2Fh owner. Windows 3 uses function 16h for most work.
; This is our Int 2Fh routine.
our_2f_isr:
	assume	ds:nothing, es:nothing
	cmp	ax,1608h	; Windows Enhanced "Init completed" broadcast?
	jne	our_2f_1	; ne = not that function, chain it
	mov	vmm_running,1   ; remember that Windows has started
	jmp	their_2f_isr    ; pass it on down the chain
our_2f_1:
	cmp	ax,1609h	; Windows Enhanced "Begin Exit" broadcast?
	jne	our_2f_2	; ne = no
	mov	vmm_running,0   ; remember that Windows has stopped
our_2f_2:
	jmp	their_2f_isr	; propagate broadcasts down the Int 2Fh chain

our_handler:			; Receive upcalls from the Packet Driver
	or	ax,ax		; first (AX=0) call to get buffer?
	jnz	our_handler_2	; nz = no, must be second upcall
	cmp	buffer_flag,1	; must buffer, is it free?
	je	our_handler_1   ; e = no, busy
	cmp	cx,MAX_BUFFER_LEN ; pkt larger than our buffer?
	ja	our_handler_1   ; a = yes, too large
	mov	buffer_flag,1   ; mark buffer as busy now
	mov	buffer_len,cx   ; store pkt length
	mov	ax,cs
	mov	es,ax		; segment of our buffer
	mov	di,offset our_buffer ; tell PD es:di is the buffer address
	retf

our_handler_1:
	xor	ax,ax		; reject the packet by returning es:di = NULL
	mov	es,ax
	xor	di,di
	retf

our_handler_2:			; second upcall, packet transfer complete
	mov	their_bx,bx	; save their registers
	mov	dx,bx
	mov	bx,cs		; set our data segment
	mov	ds,bx
	assume	ds:code

	mov	bx,offset handles	; array of PD handles
our_handler_3:
	cmp	[bx].their_handle,dx	; dx is upcoming handle
	je	our_handler_4		; found their handle
	add	bx,(size per_handle)    ; next handle
	cmp	bx,offset end_handles   ; examined all handles?
	jb	our_handler_3		; b = no, continue.
                			; get here if no matching handle
	mov	buffer_flag,0		; mark the buffer free
	retf

our_handler_4:              		; found the handle
;	inc	total_pkts
	mov	ax,[bx].recv_handler.segm ; appliation's call address
	mov	their_handler.segm,ax
	mov	ax,[bx].recv_handler.offs
	mov	their_handler.offs,ax
	push    bx
	mov	ax,1683h        ; Windows, get current vir mach ident
	int	2fh
	mov	ax,bx		; ident returned in bx
	pop	bx
	cmp	ax,[bx].vm_id	; same as the one the app is using?
	je	our_handler_5	; e = yes, correct VM is running
	jmp	our_handler_7   ; no, another VM is running, switch to wanted
our_handler_5:
;	inc	gvm_pkts
	call	pass_to_app	; copy buffer to application, via double call
	retf

pass_to_app:
	xor	ax,ax		; set up register for first upcall to app
	mov	bx,their_bx	; handle from Packet Driver
	mov	cx,buffer_len	; packet size
	push    ds
	call    their_handler	; do first upcall (request buffer address)
	pop	ds
	mov	ax,es		; check for 0:0 as reject value
	or	ax,ax
	jnz	pass_to_app_1	; nz = have an address
	or	di,di		; check for 0:offset (rather unlikely)
	jnz	pass_to_app_1	; nz = have an offset
	mov	buffer_flag,0   ; packet is being declined, free our buffer
	ret
pass_to_app_1:			; copy from our buffer to app's es:di
	push	di
	mov	cx,buffer_len
	mov	si,offset our_buffer
	cld
	call	movemem		; copy frame into apps buffer
	mov	ax,1		; set up regs for second upcall
	mov	bx,their_bx	; handle
	mov	cx,buffer_len	; report packet length too
	pop	si
	mov	dx,es
	push	ds
	mov	ds,dx
	assume	ds:nothing

	call	their_handler	; call the application
	pop	ds
	assume	ds:code
	mov	buffer_flag,0	; free buffer
	ret

; Windows Enhanced, request virtual machine in bx, and call back at es:di 
; when it's ready (which, knowing Windows, may take quite a while, hence 
; the requirement to buffer the packet to clear the lan board and ints).
our_handler_7:
;	inc	bvm_pkts
	mov	ax,1685h	; request switch VMs and callback
	mov	bx,[bx].vm_id	; virtual machine of the app
	xor	cx,cx		; flags (bits 0 and 1), zero is don't wait
	mov	dx,40h		; dx:si is priority boost
	xor	si,si
	movseg	es,cs
	mov	di,offset our_callback
	int	2fh
	retf

	assume ds:nothing
our_callback:			; get here with correct virtual machine
	push	ax		; call application twice (a la PD) to deliver
	push	bx		; the buffered packet
	push	cx
	push	dx
	push	si
	push	di
	push	ds
	push	es
	push	bp
	mov	ax,cs
	mov	ds,ax		; set up our ds
	assume	ds:code

	call    pass_to_app
	pop	bp
	pop	es
	pop	ds
	assume  ds:nothing
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	iret

	assume  ds:code
f_access_type:				; register for a packet Type
	mov	bx,offset handles	; array of PD handles
access_type_1:
	cmp	[bx].in_use,0		; is this handle in use?
	je	access_type_2		; e = yes, found a free one
	add	bx,(size per_handle)    ; next handle
	cmp	bx,offset end_handles   ; examined all handles?
	jb	access_type_1		; b = no, continue
	jmp	access_type_space	; no handle found, return error
access_type_2:
	mov	our_handle,bx		; save our handle
	mov	[bx].in_use,1		; make handle as in-use
	cmp	vmm_running,0		; is Windows Enhanced mode running?
	je	access_type_3		; e = no, don't bother to redirect
	mov	[bx].recv_handler.segm,es
	mov	[bx].recv_handler.offs,di
	mov	bx,cs
	mov	es,bx
	mov	di,offset our_handler	
access_type_3:
	push	ds
	mov	bx,_DS[bp]
	mov	ds,bx
	assume  ds:nothing

	mov	bx,_BX[bp]		; restore callers registers
	pushf
	call	old_isr			; call Packet Driver
	pop	ds
	assume	ds:code
	mov	bx,our_handle
	jnc	access_type_4		; nc = success
	mov	[bx].in_use,0		; failed, free our handle
	jmp	our_isr_error
access_type_4:
	mov	[bx].their_handle,ax	; handle returned in ax
	mov	_AX[bp],ax		; save return handle
	cmp	vmm_running,0		; Windows Enhanced mode running?
	je	access_type_5		; e = no
	push	bx			; Windows "Get Current Virtual Mach"
	mov	ax,1683h
	int	2fh			; get current VM_ID to bx
	mov	ax,bx
	pop	bx
	mov	[bx].vm_id,ax		; save ident as part of our handle
access_type_5:
	jmp	our_isr_return

access_type_space:
	mov	dh,NO_SPACE
	jmp	our_isr_error

f_release_type:
	mov	bx,_BX[bp]		; restore callers registers
	pushf
	call	old_isr
	jnc	release_type_1		; nc = success
	jmp	our_isr_error
release_type_1:
	mov	ax,_BX[bp]		;just in case
	mov	bx,offset handles
release_type_2:
	cmp	[bx].their_handle,ax	; compare handles
	je	release_type_3		; e = found a match
	add	bx,(size per_handle)    ; next handle
	cmp	bx,offset end_handles   ; examined all handles?
	jb	release_type_2		; b = no, continue
	jmp	err_bad_handle		; no handle found, return error
release_type_3:
	mov	[bx].in_use,0		; say handle is no longer in use
	jmp	our_isr_return

err_bad_handle:
	mov	dh,BAD_HANDLE		; dh is error code
	jmp	our_isr_error

f_terminate:
	mov	bx,_BX[bp]      	; restore callers registers
	pushf
	call	old_isr
	jnc	terminate_1     	; nc = success
	jmp	our_isr_error
terminate_1:
	mov	ax,_BX[bp]      	; just in case
	mov	bx,offset handles
terminate_2:
	cmp	[bx].their_handle,ax    ; compare handles
	je	terminate_3     	; e = found a match
	add	bx,(size per_handle)    ; next handle
	cmp	bx,offset end_handles   ; examined all handles?
	jb	terminate_2     	; b = no, continue
	jmp	err_bad_handle      	; no match, return error
terminate_3:
	mov	[bx].in_use,0		; mark handle as free
	mov	bx,offset handles	; check that all handles are free
terminate_4:
	cmp	[bx].in_use,0		; is this handle free?
	jne	terminate_5		; ne = no, so can't exit completely
	add	bx,(size per_handle)    ; next handle
	cmp	bx,offset end_handles   ; examined all handles?
	jb	terminate_4		; b = no, continue examination

	mov	ah,35h			; got owner of Int 2Fh
	mov	al,2fh
	int	21h			; to see if it's still us
	mov	ax,es
	mov	cx,cs
	cmp	ax,cx			; our segment?
	jne	terminate_5		; ne = no, can't terminate
	cmp	bx,offset our_2f_isr	; our offset?
	jne	terminate_5		; ne = no, can't terminate
	mov	al,2fh			; restore Int 2f
	mov	ah,25h
	push    ds
	lds	dx,their_2f_isr		; previous owner now is current owner
	int	21h
	pop	ds

	movseg	es,cs
	mov	ah,49h			; free our memory
	int	21h
	jmp	our_isr_return
terminate_5:
	mov	dh,CANT_TERMINATE	; error code
	jmp	our_isr_error

; Stop the packet driver doing upcalls. Also a following terminate will
; always succed (no in use handles any longer).
f_stop:
	mov	bx,_BX[bp]		; restore caller's registers
	pushf
	call	old_isr
	mov	bx,offset handles
f_stop_2:
	mov	[bx].in_use,0		; say handle is free
	add	bx,(size per_handle)    ; next handle
	cmp	bx,offset end_handles	; done all?
	jb	f_stop_2		; b = not yet
	clc
	ret

end_resident	label byte
	include	printnum.asm
	include decout.asm
	include digout.asm
	include chrout.asm

usage_msg   label   byte
	db	' Usage: WINPKT <packet_int_number>',CR,LF
	db	' Install WINPKT after the regular Packet Driver, but'
	db	CR,LF,' before starting Windows 3.$'

copyright_msg   label   byte
	db	"Virtual packet driver for Windows 3.x, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
	db	"Portions Copyright 1991 Roger F. James",CR,LF,'$'

copyleft_msg    label   byte
	db "Packet driver skeleton copyright 1988-90, Russell Nelson.",CR,LF
	db "This program is free software; see the file COPYING for details."
	db	CR,LF
	db	"NO WARRANTY; see the file COPYING for details.",CR,LF
	db	CR,LF
crlf_msg db	CR,LF,'$'

entry_point   db  0,0,0,0

not_found_msg   db  CR,LF,'There is no packet driver at $'
new_int_msg	db  CR,LF,'Virtual packet driver installed on interrupt $'

not_found_error:
	mov	dx,offset not_found_msg
	mov	di,offset entry_point
	call	print_number
	mov	ax,4c05h		; exit to DOS with errorlevel = 5
	int	21h

usage_error:
	mov	dx,offset usage_msg
error:	mov	ah,9
	int	21h
	mov	ax,4c0ah        	; give errorlevel 10
	int	21h

start_1:cld
	mov	dx,offset copyright_msg
	mov	ah,9
	int	21h
	mov	dx,offset copyleft_msg
	mov	ah,9
	int	21h
	mov	si,offset phd_dioa+1
	call	skip_blanks     	; end of line?
	cmp	al,CR
	je	usage_error		; e = yes

chk_options:
	call	skip_blanks
	cmp	al,'-'          ; any options?
	jne	no_more_opt
usage_error_j_1:
	jmp usage_error
no_more_opt:
	mov	di,offset entry_point
	call	get_number
	call	skip_blanks
	cmp	al,CR
	jne	usage_error

	mov	al,entry_point
	call	verify_packet_int
	jnc	packet_int_ok		; nc = success
	jmp	error
packet_int_ok:
	jne	not_found_error		; error if no Packet Driver

;Determine the processor type.  The 8088 and 8086 will actually shift ax
;over by 33 bits, while the 80[123]86 use a shift count mod 32.
	mov	cl,33
	mov	ax,0ffffh
	shl	ax,cl			;186 or better?
	jz	processor_identified	;no.
	mov	is_186,1

	push	sp
	pop	ax
	cmp	ax,sp			;286 or better?
	jne	processor_identified	;no.
	mov	is_286,1

	pushf
	pop	ax
	or	ax,7000h		;the 386 lets us set these bits
	push	ax
	popf				;this should be a real popf.
	pushf
	pop	ax
	test	ax,7000h		;did the bits get set?
	je	processor_identified
	mov	is_386,1

processor_identified:

	mov	ah,35h          	; get Packet Driver interrupt routine
	mov	al,entry_point
	int	21h
	mov	old_isr.offs,bx		; save here
	mov	old_isr.segm,es
	mov	ah,25h			; install our packet interrupt
	mov	dx,offset our_isr
	int	21h

	mov	ah,35h			; get Int 2Fh interrupt routine
	mov	al,2fh
	int	21h
	mov	their_2f_isr.offs,bx	; save here
	mov	their_2f_isr.segm,es
	mov	ah,25h          ;install our 2f interrupt
	mov	dx,offset our_2f_isr
	int	21h

	mov	ah,49h			; free our environment, because
	mov	es,phd_environ		; we won't need it
	int	21h
	mov	bx,1            	; get the stdout handle
	mov	ah,3eh			; close it in case they redirected it
	int	21h
	mov	dx,offset end_resident
	add	dx,0fh			; round up to next highest paragraph
	mov	cl,4
	shr	dx,cl
	mov	ah,31h			; terminate, stay resident
	xor	al,al
	int	21h

	include verifypi.asm
	include getnum.asm
	include getdig.asm
	include skipblk.asm
	include printea.asm
	include	crlf.asm

code    ends

	end	start
