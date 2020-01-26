; ODIPKT.ASM - Adapter provides Packet Driver interface over ODI
;
; (c) Copyright Daniel D. Lanciani 1991-1996.  All rights reserved.
;
; This unmodified source file and its executable form may be used and
; redistributed freely.  The source may be modified, and the source or
; executable versions built from the modified source may be used and
; redistributed, provided that this notice and the copyright displayed by
; the exectuable remain intact, and provided that the executable displays
; an additional message indicating that it has been modified, and by whom.
;
; Daniel D. Lanciani releases this software "as is", with no express or
; implied warranty, including, but not limited to, the implied warranties
; of merchantability and fitness for a particular purpose.
;
; Please send bug reports to ddl@danlan.com or
;
; Dan Lanciani
; 185 Atlantic Road
; Gloucester, MA 01930
; (978) 283-4974

version	equ	21	; for driver_info
iftype	equ	71	; for driver_info/access_type
nhand	equ	8	; max active handles
mmatch	equ	8	; max length of header match
mmulti	equ	8	; max multicast addresses
pkvec	equ	69h	; default control vector
;prescan	equ	1	; be a pre-scan stack when chaining
nosacca	equ	123	; ARCnet type for Ethertype ACCA

hinfo	struc			; per-handle data
nmatch	dw	-1		; header match length
match	db	mmatch dup (?)	; header match bytes
recvo	dw	?		; receiver offset
recvs	dw	?		; receiver segment
hinfo	ends

CODE	segment word public 'CODE'
	assume cs:CODE, ds:CODE, es:nothing, ss:CODE

	org	100h
stack	label	byte
at100h:	jmp	start

copyright db	'ODIPKT 3.1', 13, 10
	db	'(c) Copyright Daniel Lanciani 1991-1996.  All rights reserved.'
	db	13, 10, 'This software is provided with NO WARRANTY.', 13, 10
	db	'$'
myname	db	'ODIPKT', 0	; for driver_info
class	db	1		; for driver_info
cmap	db	0		; class mapping flag
inhere	db	0		; on switched stack
chain	db	0		; chained stack
arcarp	db	0, 7, 8, 0, 1, 4, 0, 0
	db	10 dup (?)
	align	2
savpko	dw	0		; saved vector offset
savpks	dw	0		; saved vector segment
rqueue	dd	0		; queue of pending receives
psup	dd	0		; LSL protocol support entry
gsup	dd	0		; LSL general support entry
control	dd	0		; MLID control entry
config	dd	0		; MLID configuration table
myvec	dw	4 * pkvec	; 4 * my vector
alen	dw	6		; address length
off	dw	12		; header offset for match
fmin	dw	60		; minimum frame size
rmode	dw	3		; current receiver mode
rmmap	dw	0, 1, 5, 7, 7, 15
nmulti	dw	0		; number of multicast addresses
mtab	db	mmulti * 6 dup (?)
htab	hinfo	nhand dup (<>)	; the handle table
htabe	label	byte
stab	dw	14 dup (0)	; for get_statistics
ptab	db	1, 9, 14, 6	; for get_parameters
	dw	1514, mmulti * 6, 0, 0, 0

sECB	db	52 dup (0)	; transmit ECB

StkChn	dd	0		; Link
Board	dw	0
Posit	dw	0
Handler	dd	0
Cont	dd	0
	dw	0		; ID
	dw	03dfh		; Mask
	dw	0		; Reserved

upcall	proc	far
transcom:push	ds
	push	bp
	mov	ax, cs
	mov	ds, ax
	cmp	word ptr es:8[si], 0
	jz	trans1
	add	stab + 20, 1
	adc	stab + 22, 0
trans1:	mov	bx, 1
	call	psup
	pop	bp
	pop	ds
	ret

recvcom:push	di
	cmp	cs:chain, 0
	jz	rcvnc
	cld
	push	ds
	les	di, [di]
	mov	ax, cs
	mov	ds, ax
	cmp	class, 3
	jnz	@f
	test	byte ptr es:8[di], 80h
	jz	@f
	mov	al, es:14[di]
	and	ax, 1fh
	add	di, ax
@@:	add	di, off
	mov	ax, di

	mov	bx, offset htab
chain1:	mov	cx, [bx].nmatch
	cmp	cx, -1
	jz	@f
	jcxz	chain2
	lea	si, [bx].match
	mov	di, ax
	repe	cmpsb
	jz	chain2
@@:	add	bx, size hinfo
	cmp	bx, offset htabe
	jc	chain1
	pop	ds
	pop	di
	mov	ax, 8001h
	and	ax, ax
	ret
chain2:	pop	ds
	pop	di
	push	di

rcvnc:	xor	bx, bx
	call	cs:psup
	mov	dx, ds
	jz	havebuf
	jmp	nobuf
havebuf:mov	cx, 4[di]
	sub	cx, [di]

	cmp	cs:cmap, 8
	jnz	rcvna1
	mov	cx, 14
rcvna1:

	mov	word ptr es:10[si], offset recvcom2
	mov	word ptr es:12[si], cs
	push	si
	mov	ax, cs:word ptr ptab + 4
	mov	word ptr es:50[si], ax
	lea	ax, 52[si]
	mov	word ptr es:44[si], 1
	mov	word ptr es:46[si], ax
	mov	word ptr es:48[si], es
	add	word ptr es:46[si], cx
	sub	word ptr es:50[si], cx
	lds	si, [di]
	mov	di, ax
	cld

	cmp	cs:cmap, 8
	jnz	rcvna2
	xor	ah, ah
	mov	al, 2[si]
	or	al, al
	jnz	rcvna3
	mov	al, 3[si]
rcvna3:	push	si
	add	si, ax
	cmp	byte ptr 1[si], 0ffh
	jnz	rcvna4
	add	si, 4
rcvna4:	mov	al, [si]
	mov	ah, 255
	pop	si
ifdef	nosacca
	cmp	al, nosacca
	jnz	rcvna8
	mov	ax, 0accah
	jmp	short rcvna7
rcvna8:
endif
	cmp	al, 212
	jnz	rcvna6
	mov	ax, 0800h
	jmp	short rcvna7
rcvna6:	cmp	al, 213
	jnz	rcvna7
	mov	ax, 0806h
rcvna7:	xchg	ah, al
	mov	es:12[di], ax
	push	di
	mov	cx, 6
	xor	ax, ax
	rep	stosw
	pop	di
	mov	ax, [si]
	mov	es:11[di], al
	mov	es:5[di], ah
	or	ah, ah
	jnz	rcvna5
	mov	word ptr es:[di], -1
	mov	word ptr es:2[di], -1
	mov	word ptr es:4[di], -1
	jmp	short rcvna5
rcvna2:

	rep	movsb
rcvna5:	pop	si
	pop	di
	mov	ds, dx
	xor	ax, ax
	ret
nobuf:	pop	di
	mov	ds, dx
	mov	ax, 8001h
	add	cs:stab + 16, 1
	adc	cs:stab + 18, 0
	and	ax, ax
	ret

recvcom2:push	bp
	push	ds
	mov	ax, cs
	mov	ds, ax
recv0:	cmp	inhere, 0
	jz	notbusy
	add	stab + 16, 1
	adc	stab + 18, 0
	jmp	busy
notbusy:inc	inhere
	mov	bx, ss
	mov	cx, sp
	mov	ss, ax
	mov	sp, offset stack
	push	bx
	push	cx
	push	es
	push	si
	cld
	mov	cx, es:42[si]
	add	cx, es:46[si]
	add	si, 52
	sub	cx, si
	cmp	cx, fmin
	jnc	enuf
	mov	cx, fmin
enuf:	push	es
	push	si
	push	cx
	add	stab, 1
	adc	stab + 2, 0
	add	stab + 8, cx
	adc	stab + 10, 0
	mov	bx, offset htab
recv1:	mov	cx, [bx].nmatch
	cmp	cx, -1
	jz	recv5
	jcxz	recv2
	mov	di, si
	cmp	class, 3
	jnz	norif
	test	byte ptr es:8[di], 80h
	jz	norif
	mov	al, es:14[di]
	and	ax, 1fh
	add	di, ax
norif:	add	di, off
	lea	si, [bx].match
	repe	cmpsb
	jnz	recv5
recv2:	pop	cx
	push	cx
	push	bx
	xor	ax, ax
	call	dword ptr [bx].recvo
	pop	bx
	cld
	mov	ax, es
	or	ax, di
	jz	recv7
	pop	cx
	pop	si
	pop	ds
	push	ds
	push	si
	push	cx
	push	di
	shr	cx, 1
	rep	movsw
	jnc	recv3
	movsb
recv3:	pop	si
	pop	cx
	push	cx
	mov	ax, es
	mov	ds, ax
	push	bx
	cmp	cs:cmap, 8
	jnz	noararp
	cmp	word ptr 12[si], 0608h
	jnz	noararp
	call	arar2etar
noararp:mov	ax, 1
	call	dword ptr cs:[bx].recvo
	pop	bx
	cld
	cli
	mov	ax, cs
	mov	ds, ax
recv5:	pop	cx
	pop	si
	pop	es
	add	bx, size hinfo
	cmp	bx, offset htabe
	jnc	recv6
	push	es
	push	si
	push	cx
	jmp	recv1
recv7:	cli
	mov	ax, cs
	mov	ds, ax
	add	stab + 24, 1
	adc	stab + 26, 0
	jmp	short recv5
recv6:	pop	si
	pop	es
	pop	cx
	pop	bx
	mov	ss, bx
	mov	sp, cx
	dec	inhere
	mov	ax, cs
	mov	ds, ax
	mov	bx, 1
	call	psup
	les	si, rqueue
	mov	ax, es
	or	ax, si
	jz	recv8
	mov	ax, es:[si]
	mov	word ptr rqueue, ax
	mov	ax, es:2[si]
	mov	word ptr rqueue + 2, ax
	mov	ax, cs
	jmp	recv0
recv8:	pop	ds
	pop	bp
	ret
busy:	mov	di, offset rqueue
busy1:	mov	ax, [di]
	or	ax, 2[di]
	jz	busy2
	lds	di, [di]
	jmp	short busy1
busy2:	mov	es:[si], ax
	mov	es:2[si], ax
	mov	[di], si
	mov	2[di], es
	jmp	short recv8
pcont:	mov	ax, 8008h
	and	ax, ax
	ret
upcall	endp

arar2etar:mov	word ptr 14[si], 100h
	mov	byte ptr 18[si], 6
	mov	ax, 30[si]
	mov	40[si], ax
	mov	ax, 28[si]
	mov	38[si], ax
	mov	al, 27[si]
	mov	37[si], al
	xor	ax, ax
	mov	36[si], al
	mov	34[si], ax
	mov	32[si], ax
	mov	ax, 25[si]
	mov	30[si], ax
	mov	ax, 23[si]
	mov	28[si], ax
	mov	al, 22[si]
	mov	27[si], al
	xor	ax, ax
	mov	26[si], al
	mov	24[si], ax
	mov	22[si], ax
	ret

nofunc:	mov	dh, 11
	jmp	bad

driver_info:pop	bx
	mov	bx, cs
	mov	ds, bx
	mov	bx, version
	mov	ch, class
	mov	dx, iftype
	xor	cl, cl
	mov	si, offset myname
	mov	al, 6
	jmp	good1

access_type:pop	bx
	push	ds
	push	cs
	pop	ds
	cmp	al, class
	jz	access_type1
	mov	dh, 2
	jmp	short access_type5
access_type1:cmp	bx, iftype
	jz	access_type7
	cmp	bx, -1
	jz	access_type7
;	mov	dh, 3
;	jmp	short access_type5
access_type7:and	dl, dl
	jz	access_type2
	mov	dh, 4
	jmp	short access_type5
access_type2:cmp	cx, mmatch + 1
	jc	access_type3
	mov	dh, 14
	jmp	short access_type5
access_type3:mov	bx, offset htab
access_type4:cmp	[bx].nmatch, -1
	jz	access_type6
	add	bx, size hinfo
	cmp	bx, offset htabe
	jc	access_type4
	mov	dh, 9
access_type5:pop	ds
	jmp	bad1
access_type6:mov	[bx].nmatch, cx
	mov	[bx].recvo, di
	mov	[bx].recvs, es
	mov	di, ds
	mov	es, di
	lea	di, [bx].match
	pop	ds
	rep	movsb
	mov	ax, bx
	jmp	good1

release_type:pop	bx
	mov	cs:[bx].nmatch, -1
	jmp	good1

send_pkt:push	ds
	mov	bx, ds
	mov	dx, cs
	mov	ds, dx
	add	stab + 4, 1
	adc	stab + 6, 0
	add	stab + 12, cx
	adc	stab + 14, 0
	mov	word ptr sECB + 48, bx

	cmp	cmap, 8
ifdef	nosacca
	jz	armap
	jmp	send_pkt4
armap:
else
	jnz	send_pkt4
endif
	mov	es, bx
	mov	ax, es:[si]
	mov	word ptr sECB + 24, ax
	mov	ax, es:2[si]
	mov	word ptr sECB + 26, ax
	mov	ax, es:4[si]
	mov	word ptr sECB + 28, ax
	mov	ax, word ptr es:12[si]
	mov	sECB + 16 + 5, ah
	cmp	ax, 0608h
	jnz	sndna1
	mov	sECB + 16 + 5, 213
	mov	ax, es:20[si]
	mov	word ptr arcarp + 6, ax
	mov	al, es:27[si]
	mov	arcarp + 8, al
	mov	ax, es:28[si]
	mov	word ptr arcarp + 9, ax
	mov	ax, es:30[si]
	mov	word ptr arcarp + 11, ax
	mov	al, es:37[si]
	mov	arcarp + 13, al
	mov	ax, es:38[si]
	mov	word ptr arcarp + 14, ax
	mov	ax, es:40[si]
	mov	word ptr arcarp + 16, ax
	mov	cx, 18
	mov	si, offset arcarp
	mov	word ptr sECB + 48, cs
	jmp	short send_pkt4
sndna1:
ifdef	nosacca
	cmp	ax, 0caach
	jnz	sndna2
	mov	sECB + 16 + 5, nosacca
	jmp	short send_pkt5
sndna2:
endif
	cmp	ax, 0008h
	jnz	send_pkt5
	mov	sECB + 16 + 5, 212
send_pkt5:add	si, 14
	sub	cx, 14
send_pkt4:

	mov	word ptr sECB + 42, cx
	mov	word ptr sECB + 46, si
	mov	word ptr sECB + 50, cx
	xor	bx, bx
	call	psup
	jnz	send_pkt3
	push	si
	mov	di, si
	mov	si, offset sECB
	mov	cx, 26
	rep	movsw
	mov	cx, word ptr sECB + 50
	lds	si, dword ptr sECB + 46
	shr	cx, 1
	rep	movsw
	jnc	send_pkt1
	movsb
send_pkt1:mov	dx, cs
	mov	ds, dx
	pop	si
	lea	ax, 52[si]
	mov	es:46[si], ax
	mov	es:48[si], es
	mov	bx, 12
	call	psup
	sti
	pop	ds
	jmp	good
send_pkt3:add	stab + 20, 1
	adc	stab + 22, 0
	pop	ds
	mov	dh, 12
	jmp	bad

terminate:push	ds
	mov	ax, cs
	mov	ds, ax
	mov	cx, nmulti
	jcxz	terminate2
	mov	si, offset mtab
terminate1:push	si
	push	cx
	mov	ax, cs
	mov	es, ax
	mov	ax, Board
	mov	bx, 3
	call	control
	pop	cx
	pop	si
	add	si, alen
	loop	terminate1
terminate2:xor	ax, ax
	mov	es, ax
	mov	bx, myvec
	mov	ax, savpko
	mov	es:[bx], ax
	mov	ax, savpks
	mov	es:2[bx], ax
	mov	ax, Board
	mov	bx, 9
	cmp	chain, 0
	jz	terminate3
ifdef	prescan
	mov	bx, 31
else
	mov	bx, 30
endif
	mov	si, cs
	mov	es, si
	mov	si, offset StkChn
terminate3:call	psup
	mov	ax, cs
	mov	es, ax
	mov	ah, 49h
	int	21h
	pop	ds
	jmp	good

get_address:cmp	cx, cs:alen
	jnc	get_address1
	mov	dh, 9
	jmp	bad
get_address1:push	ds
	lds	si, cs:config
	add	si, 28+6
	mov	cx, cs:alen
	sub	si, cx
	rep	movsb
	pop	ds
	mov	cx, cs:alen
	jmp	good

reset_interface:mov	dh, 15
	jmp	bad

get_parameters:mov	di, cs
	mov	es, di
	mov	di, offset ptab
	jmp	good

set_rcv_mode:mov	bx, cx
	dec	bx
	cmp	bx, 6
	jnc	set_rcv_mode1
	shl	bx, 1
	push	cx
	mov	ax, cs:rmmap[bx]
	mov	bx, 4
	mov	cx, -1
;	call	cs:control
	pop	cx
;	jnz	set_rcv_mode1	; XXX no longer supported by ODI
	mov	cs:rmode, cx
	jmp	good
set_rcv_mode1:mov	dh, 8
	jmp	bad

get_rcv_mode:mov	ax, cs:rmode
	jmp	good

set_multicast_list:mov	ax, cx
	xor	dx, dx
	mov	bx, cs:alen
	div	bx
	and	dx, dx
	jz	set_multicast_list1
	mov	dh, 14
	jmp	bad
set_multicast_list1:cmp	ax, mmulti + 1
	jc	set_multicast_list6
	mov	dh, 9
	jmp	bad
set_multicast_list6:push	ds
	push	cx
	push	ax
	push	es
	push	di
	mov	ax, cs
	mov	ds, ax
	mov	cx, nmulti
	jcxz	set_multicast_list3
	mov	si, offset mtab
set_multicast_list2:push	si
	push	cx
	mov	ax, cs
	mov	es, ax
	mov	ax, Board
	mov	bx, 3
	call	control
	pop	cx
	pop	si
	add	si, alen
	loop	set_multicast_list2
set_multicast_list3:pop	si
	pop	ds
	pop	ax
	pop	cx
	mov	bx, cs
	mov	es, bx
	mov	di, offset mtab
	cld
	rep	movsb
	mov	bx, cs
	mov	ds, bx
	mov	nmulti, ax
	mov	cx, ax
	jcxz	set_multicast_list5
	mov	si, offset mtab
set_multicast_list4:push	si
	push	cx
	mov	ax, cs
	mov	es, ax
	mov	ax, Board
	mov	bx, 2
	call	control
	pop	cx
	pop	si
	add	si, alen
	loop	set_multicast_list4
set_multicast_list5:pop	ds
	jmp	good

get_multicast_list:mov	di, cs
	mov	es, di
	mov	di, offset mtab
	mov	ax, cs:nmulti
	mov	cx, cs:alen
	mul	cx
	mov	cx, ax
	jmp	good

get_statistics:mov	si, cs
	mov	ds, si
	mov	si, offset stab
	jmp	good

set_address:mov	dh, 13
	jmp	bad

funcs	dw	nofunc
	dw	driver_info
	dw	access_type
	dw	release_type
	dw	send_pkt
	dw	terminate
	dw	get_address
	dw	reset_interface
	dw	nofunc
	dw	nofunc

	dw	get_parameters
	dw	nofunc
	dw	nofunc
	dw	nofunc
	dw	nofunc
	dw	nofunc
	dw	nofunc
	dw	nofunc
	dw	nofunc
	dw	nofunc

	dw	set_rcv_mode
	dw	get_rcv_mode
	dw	set_multicast_list
	dw	get_multicast_list
	dw	get_statistics
	dw	set_address

nfuncs	equ	($ - offset funcs) / 2

intpk	proc	far
	jmp	short dopk
	nop
sig	db	'PKT DRVR', 0
dopk:	cli
	cld
	push	bx
	cmp	ah, nfuncs
	jc	dopk1
	jmp	nofunc

dopk1:	mov	bl, ah
	xor	bh, bh
	shl	bx, 1
	jmp	cs:funcs[bx]

bad:	pop	bx
bad1:	stc
	sti
	ret	2
good:	pop	bx
good1:	clc
	sti
	ret	2
intpk	endp

start:	mov	ax, cs
	mov	ds, ax
	cld

	mov	dx, offset copyright
	mov	ah, 9
	int	21h

	mov	bx, 81h
	call	space
	call	number
	jc	start0
	mov	Board, ax
	call	space
	call	number
	jc	start0
	add	ax, ax
	add	ax, ax
	mov	myvec, ax

start0:	xor	ax, ax
	mov	es, ax
	mov	bx, myvec
	les	di, es:[bx]
	add	di, 3
	mov	si, offset sig
	mov	cx, 9
	repe	cmpsb
	jnz	start1
	mov	dx, offset already
pexit:	mov	ah, 9
	int	21h
	int	20h

start1:	xor	ax, ax
	mov	es, ax
	xor	bx, bx
	xor	dx, dx
	mov	ah, 0c0h
start11:push	ax
	push	ds
	int	2fh
	pop	ds
	cmp	al, 0ffh
	pop	ax
	jz	start13
start12:inc	ah
	jnz	start11
	mov	dx, offset nolsl
	jmp	pexit
start13:mov	cx, dx
	or	cx, bx
	jz	start12
	mov	di, si
	mov	si, offset lslname
	cld
	mov	cx, 8
	repe	cmpsb
	jz	start14
	xor	bx, bx
	xor	dx, dx
	jmp	start12

start14:mov	word ptr psup, bx
	mov	word ptr psup + 2, dx
	mov	si, cs
	mov	es, si
	mov	si, offset psup
	mov	bx, 2
	call	psup
	mov	ax, word ptr gsup
	or	ax, word ptr gsup + 2
	jnz	start2
	mov	dx, offset lslfail
	jmp	pexit

start2:	mov	bx, 18
	mov	ax, Board
	call	psup
	jz	start3
	mov	dx, offset nocont
	jmp	pexit
start3:	mov	word ptr control, si
	mov	word ptr control + 2, es
	mov	ax, Board
	xor	bx, bx
	call	control
	jz	start4
	mov	dx, offset noconf
	jmp	pexit
start4:	mov	word ptr config, si
	mov	word ptr config + 2, es
	mov	al, es:114[si]
	or	al, al
	jz	trynew
	cmp	al, 16
	jc	oldok
trynew:	mov	al, es:118[si]
oldok:	xor	ah, ah
	cmp	al, 8
	jnc	noloirq
	add	ax, 8
	jmp	short haveirq
noloirq:cmp	al, 16
	jnc	noirq
	add	ax, 70h - 8
haveirq:mov	word ptr ptab + 12, ax
noirq:	mov	ax, es:60[si]
	cmp	ax, 4
	jz	istok
	cmp	ax, 11
	jz	istok
	cmp	ax, 3
	jz	is8023
	cmp	ax, 5
	jz	is8023
	cmp	ax, 10
	jz	is8023
	cmp	ax, 7
	jz	ispcn2
	cmp	ax, 15
	jz	ispcn2
	cmp	ax, 16
	jz	ispcn2
	cmp	ax, 14
	jz	isarc
	mov	dx, offset t_unk
	jmp	short gottype
istok:	mov	dx, offset t_tok
	mov	off, 14
	mov	ax, es:40[si]
	mov	word ptr ptab + 4, ax
	mov	class, 3
	mov	fmin, 14
	jmp	short gottype
ispcn2:	mov	dx, offset t_pcn2
	mov	off, 14
	mov	class, 11
	jmp	short gottype
is8023:	mov	dx, offset t_8023
	mov	off, 14
	mov	class, 11
	jmp	short gottype
isarc:	mov	dx, offset t_arc
	mov	cmap, 8
gottype:mov	ah, 9
	int	21h

	mov	word ptr Handler, offset recvcom
	mov	word ptr Handler + 2, cs
	mov	word ptr Cont, offset pcont
	mov	word ptr Cont + 2, cs

	cmp	cmap, 8
	jz	nochain
	mov	si, cs
	mov	es, si
	mov	si, offset StkChn
ifdef	prescan
	mov	bx, 28
else
	mov	bx, 27
endif
	call	psup
	cmp	ax, 0
	mov	dx, offset chnmsg1
	jz	usechn
	cmp	ax, 8009h
	jnz	nochain
	mov	Posit, 1
	mov	si, cs
	mov	es, si
	mov	si, offset StkChn
	mov	bx, 27
	call	psup
	cmp	ax, 0
	mov	dx, offset chnmsg2
	jz	usechn

nochain:mov	si, cs
	mov	es, si
	mov	si, offset Handler
	mov	ax, Board
	mov	bx, 8
	call	psup
	jz	start5
	mov	dx, offset rfail
	jmp	pexit

usechn:	mov	ah, 9
	int	21h
	mov	chain, 1
start5:	mov	word ptr sECB + 10, offset transcom
	mov	word ptr sECB + 12, cs
	mov	word ptr sECB + 14, -1
	mov	ax, Board
	mov	word ptr sECB + 22, ax
	mov	word ptr sECB + 44, 1

	xor	ax, ax
	mov	es, ax
	pushf
	cli
	mov	bx, myvec
	mov	ax, es:[bx]
	mov	savpko, ax
	mov	ax, es:2[bx]
	mov	savpks, ax
	mov	es:[bx], offset intpk
	mov	es:2[bx], cs
	popf

	mov	dx, offset goodins
	mov	ah, 9
	int	21h

	mov	es, ds:[2ch]
	mov	ah, 49h
	int	21h
	mov	word ptr ds:[2ch], 0

	mov	cx, 5
	xor	bx, bx
cloop:	mov	ah, 3eh
	int	21h
	inc	bx
	loop	cloop

	mov	dx, offset start
	int	27h

number:	xor	ax, ax
	mov	cx, -1
	mov	base, 10
	cmp	byte ptr [bx], '0'
	jnz	number1
	xor	cx, cx
	mov	base, 8
	inc	bx
	cmp	byte ptr [bx], 'x'
	jz	@f
	cmp	byte ptr [bx], 'X'
	jnz	number1
@@:	mov	base, 16
	inc	bx
number1:mov	dl, byte ptr [bx]
	cmp	dl, '0'
	jc	@f
	cmp	dl, '9' + 1
	jnc	@f
	sub	dl, '0'
	jmp	short number2
@@:	cmp	dl, 'a'
	jc	@f
	cmp	dl, 'f' + 1
	jnc	@f
	sub	dl, 'a' - 10
	jmp	short number2
@@:	cmp	dl, 'A'
	jc	number3
	cmp	dl, 'F' + 1
	jnc	number2
	sub	dl, 'A' - 10
number2:xor	dh, dh
	cmp	dx, base
	jnc	number3
	xor	cx, cx
	push	dx
	mov	dx, base
	mul	dx
	pop	dx
	add	ax, dx
	inc	bx
	jmp	short number1
number3:add	cx, 1
	ret

space:	cmp	byte ptr [bx], ' '
	jz	space1
	cmp	byte ptr [bx], 9
	jz	space1
	ret
space1:	inc	bx
	jmp	short space

base	dw	10
lslname	db	'LINKSUP$'
already	db	'A driver is already installed at this vector.', 13, 10, '$'
t_unk	db	'Using Ethernet framing, class 1', 13, 10, '$'
t_tok	db	'Using Token Ring framing, class 3', 13, 10, '$'
t_pcn2	db	'Using PCN2 framing, class 11', 13, 10, '$'
t_8023	db	'Using 802.3 framing, class 11', 13, 10, '$'
t_arc	db	'Using ARCNET framing, class 1', 13, 10, '$'
goodins	db	'ODIPKT is installed and ready.', 13, 10, '$'
nolsl	db	'The Link Support Layer is not loaded.', 13, 10, '$'
lslfail	db	'The Link Support Layer failed to init.', 13, 10, '$'
nocont	db	'Cannot get MLID control entry', 13, 10, '$'
noconf	db	'Cannot get MLID configuration', 13, 10, '$'
rfail	db	'Failed to register protocol stack', 13, 10, '$'
ifdef	prescan
chnmsg1	db	'Registered as high priority chained prescan stack', 13, 10, '$'
chnmsg2	db	'Registered as chained prescan stack', 13, 10, '$'
else
chnmsg1	db	'Registered as high priority chained default stack', 13, 10, '$'
chnmsg2	db	'Registered as chained default stack', 13, 10, '$'
endif

CODE	ends
	end	at100h
