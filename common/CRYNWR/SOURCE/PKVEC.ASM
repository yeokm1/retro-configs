; File : pkvec.asm Packet driver interrupt hooks
; Ported from Phil Karn's pkvec.asm
Comment #


/*
    Copyright (C) 1990 Phil Karn

    Copyright (C) 1992 Indian Institute of Technology Bombay
    Written by V. Srinivas and Nitin Kaulavkar,
    Dept of Computer Science and Engineering

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 1, or (at your option)
    any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/
#


.MODEL	LARGE
extrn  _pkint:proc

.DATA
extrn  _rxptr:dword
extrn  _hash_tableptr:dword
Intstk	dw	1024 dup(?)	; Interrupt working stack
Stktop	equ	$		; SP set here when entering interrupt


.CODE
spsave	dw	?		; Save location for SP during interrupts
sssave	dw	?		; Save location for SS during interrupts
dbase	dw	@Data

; _pkvec0 - Packet driver receive call handler #0
	public	_pkvec0
	label	_pkvec0	far
	pushf			; save his interrupt state
	cli			; no distractions
	mov	cs:sssave,ss	; stash user stack context
	mov	cs:spsave,sp

	mov	ss,cs:dbase	; set up interrupt stack
	lea	sp,ds:Stktop

	; save regs, making them available to _pkint()
	push	es
	push	ds
	push	ax
	push	bx
	push	cx
	push	dx
	push	bp
	push	si
	push	di

	mov	ax,ss
	mov	ds,ax
	mov	ax,0	; interface  #0
	push	ax
	call	_pkint
	jmp	pkret

; _pkvec1 - Packet driver receive call handler #1
	public	_pkvec1
	label	_pkvec1	far
	pushf			; save his interrupt state
	cli			; no distractions
	mov	cs:sssave,ss	; stash user stack context
	mov	cs:spsave,sp

	mov	ss,cs:dbase	; set up interrupt stack
	lea	sp,ds:Stktop

	; save regs, making them available to _pkint()
	push	es
	push	ds
	push	ax
	push	bx
	push	cx
	push	dx
	push	bp
	push	si
	push	di

	mov	ax,ss
	mov	ds,ax
	mov	ax,1	; interface #1
	push	ax
	call   _pkint
	jmp	pkret

; _pkvec2 - Packet driver receive call handler #2
	public	_pkvec2
	label	_pkvec2	far
	pushf			; save his interrupt state
	cli			; no distractions
	mov	cs:sssave,ss	; stash user stack context
	mov	cs:spsave,sp

	mov	ss,cs:dbase	; set up interrupt stack
	lea	sp,ds:Stktop

	; save regs, making them available to _pkint()
	push	es
	push	ds
	push	ax
	push	bx
	push	cx
	push	dx
	push	bp
	push	si
	push	di

	mov	ax,ss
	mov	ds,ax
	mov	ax,2	; interface #2
	push	ax
	call	_pkint
	jmp	pkret


; _pkvec3 - Packet driver receive call handler #3
	public	_pkvec3
	label	_pkvec3	far
	pushf			; save his interrupt state
	cli			; no distractions
	mov	cs:sssave,ss	; stash user stack context
	mov	cs:spsave,sp

	mov	ss,cs:dbase	; set up interrupt stack
	lea	sp,ds:Stktop

	; save regs, making them available to _pkint()
	push	es
	push	ds
	push	ax
	push	bx
	push	cx
	push	dx
	push	bp
	push	si
	push	di

	mov	ax,ss
	mov	ds,ax
	mov	ax,3	; interface #3
	push	ax
	call	_pkint
	jmp	pkret

; common return for all packet drivers
	label	pkret	near
	pop	ax	; pop interface # arg
	pop	di
	pop	si
	pop	bp
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	pop	ds
	pop	es

	mov	ss,cs:sssave
	mov	sp,cs:spsave	; restore original stack context
	popf
	retf

; int send_pkt(int intno,char *buffer,unsigned len)

int_no		equ	    [bp+6]
tx_buffer	equ	    [bp+8]
tx_len		equ	    [bp+12]

		Public _send_pkt
_send_pkt	proc	    far
		push bp
		mov bp,sp
		push cx
		push dx
		push si
		push ds
		push es
		push di
; since the  int instruction takes only scalar variables, initially put zero
; as the operand and later modify the code (i.e.) change zero to the
; appropriate int no.  The opcode for int instruction is 0cdh.
		xor ax,ax
		mov es,ax
		mov bx,int_no
		shl bx,1
		shl bx,1
		mov ah,4
		mov cx,tx_len		;get count
		lds si,tx_buffer	;get ptr-> to tx_buffer
		pushf
		cli
		call	dword ptr es:[bx]
		mov ax,0
		jnc exit_send

		mov ax,-1               ; transmission error ?


    exit_send:
		pop di
		pop es
		pop ds
		pop si
		pop dx
		pop cx
		pop bp
		ret
_send_pkt	endp




;  int hash_learn(int interface)
; interface is the segment on which the packet was received
; This function learns the ethernet addresses of the nodes ,the ethernet address
; and the segment number is stored in the 64k hash table. It returns the segment
; on which the packet has to be forwarded, if the address has been previously
; learnt otherwise it returns -1 for broadcast packets and packets for
; which the destination segment in unknown.
; We use a hash function  n *8 mod 64k, this idea is borrowed from
; Vance Morrisons PcBridge.
; Thanks Vance
; _rxptr is a global variable which points to the head of the packet receive
; buffer queue.

interface	equ	[bp+6]

    Public	_hash_learn
_hash_learn proc	far

	    push bp
	    mov bp,sp
	    push ds
	    push es 
	    push si
	    push di

	    mov ax,seg _rxptr
	    mov ds,ax
	    lds si,[_rxptr]
	    push ds
	    mov ax, SEG _hash_tableptr
	    mov ds,ax
	    les di,[_hash_tableptr]
	    pop ds
	    add si, 6                   ; get the source address of the packet
	    mov di, [si+4]              ; compute hash function (LSB * 8 mod 65k)
	    shl di, 1
	    shl di, 1
	    shl di, 1
	    movsw
	    movsw
	    movsw                        ; save the source ethernet address
	    mov al, interface            ; and the interface on which the pkt was received
	    stosb
	    sub si, 12                   ; point  to the destination address
	    test  byte ptr [si],1H       ; Is it a broadcast packet ?
	    jnz	flood
	    mov di,[si+4]               ; compute hash function (LSB * 8 mod 65k)
	    shl di,1
	    shl di,1
	    shl di,1
	    cmpsw
	    jnz flood
	    cmpsw
	    jnz flood
	    cmpsw
	    jnz flood
	    mov al, es:[di]         ; address found in table, get  the interface no
	    mov ah,00
	    jmp   last

flood:
		mov ax,-1           ; the address is not found in the table
				    ; so return -1
last:
		pop   di
		pop   si
		pop   es
		pop   ds
		pop   bp
		ret
_hash_learn 	endp
		end
		
