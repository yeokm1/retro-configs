version	equ	1

	include	defs.asm

; Packet driver for Cabletron DNI Exxxx series cards.
; Portions Copyright 1992-1993 Kai Getrost.
;
; Since I have no official programming info on the DNI cards, nor do I
; have a Microchannel version of the card, this driver doesn't work on
; an MCA bus (to my knowledge).  There's code in here to do stuff when
; running on an MCA bus, but most of it is guesswork.  To enable it,
; uncomment the MCA_STUFF define below, and move the 6 lines of code
; before "include 8390.asm" to the head of recv in 8390.asm.
; -KNG 930924
;
; Define for MCA code:
;MCA_STUFF	equ	1

;For brain-dead assemblers:
REP_INSB	equ	db	0f3h, 06ch
REP_INSW	equ	db	0f3h, 06dh
REP_OUTSB	equ	db	0f3h, 06eh
REP_OUTSW	equ	db	0f3h, 06fh


EN_OFF		equ	0
CT_DATAPORT	equ	10h		; data transfer port
SM_TSTART_PG	equ	1
SM_RSTART_PG	equ	9
SM_RSTOP_PG	equ	20h		; 40h on MCA cards
TEST_VAL	equ	1234h

	include	8390.inc

;This used to be in 8390.asm:
pause_	macro
	push	ax
	in	al, 61h		;use al, not ax!
	pop	ax
endm

reset_8390	macro
local	foo
	loadport
	setport	EN_CCMD
	mov	al, ENC_STOP
	pause_
	out	dx, al
	mov	cx, 80h
foo:
	pause_
	loop	foo
endm

terminate_board	macro
	mov	dh, CANT_TERMINATE
	stc
endm


code	segment word public
	assume cs:code, ds:code

	public	int_no, io_addr
int_no		db	3, 0, 0, 0	;IRQ #; must be dword for get_number
io_addr		dw	300h, 0		;IO port to use

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
driver_type	db	51		;from Cabletron's driver
driver_name	db	"Cabletron DNI", 0	;name of the driver.
driver_function	db	2		;2 = basic/extended
parameter_list	label	byte
	db	1	;major rev of packet driver
	db	9	;minor rev of packet driver
	db	14	;length of parameter list
	db	EADDR_LEN	;length of MAC-layer address
	dw	GIANT	;MTU, including MAC headers
	dw	MAX_MULTICAST * EADDR_LEN	;buffer size of multicast addrs
	dw	0	;(# of back-to-back MTU rcvs) - 1
	dw	0	;(# of successive xmits) - 1
int_num	dw	0	;Interrupt # to hook for post-EOI
			;processing, 0 == none

is_16bit	db	0		;set to 1 if 16 bit card
out_jmp		dw      out_88		;block_output method
in_jmp		dw	in_88		;block_input method
shmem_seg	dw	?		;shared memory segment


	extrn	sys_features: byte
	extrn	is_186: byte

	public	block_input
;enter with AX = board address, CX = count, ES:DI -> buffer to copy to
;buffer-wraparound added 920901 -kng
block_input:
	assume	ds:nothing	; force CS overrides for data refs

;First check for buffer wraparound:
	mov	si, ax				;save start page
	add	ax, cx				;compute end of this frame
	mov	dh, cs:sm_rstop_ptr
	or	dh, dh
	jz	in_okcpy			;no mem, ok to copy (?)
	xor	dl, dl
	cmp	ax, dx				;is it beyond end of buffer?
	jbe	in_okcpy			;jump if not

;Frame is wrapped around; do copy in 2 parts:
	push	cx				;save total length
	mov	cx, dx
	sub	cx, si				;get length of first part
	push	cx				;save it
	call	get_block
	pop	bx
	pop	cx
	sub	cx, bx				;get length of second part
	mov	si, SM_RSTART_PG*256 + 0
in_okcpy:
	call	get_block
	ret

;Copy contiguous block of data.  SI = page, CX = len, ES:DI = buffer
;From ne1000.asm, modified (shared mem added for MCA cards).
get_block:
	cld			; set right direction
  ifdef MCA_STUFF
	test	sys_features, SYS_MCA
	jnz	in_mem
  endif
	loadport
	setport EN_CCMD
	pause_
	mov	al, ENC_NODMA + ENC_PAGE0 + ENC_START
	out	dx, al

	mov	ax, cx		;get the count to be output.
	setport	EN0_RCNTLO	; remote byte count 0
	pause_
	out	dx, al
	setport	EN0_RCNTHI
	pause_
	mov	al, ah
	out	dx, al

	mov	ax, si		; get our page back
	setport	EN0_RSARLO
	pause_
	out	dx, al		; set as hi address
	setport	EN0_RSARHI
	pause_
	mov	al, ah
	out	dx, al

	setport EN_CCMD
	pause_
	mov	al, ENC_RREAD + ENC_START	; read and start
	out	dx, al
	setport	CT_DATAPORT
	pause_

	jmp	[in_jmp]	; do the copy

in_88:				; Default, use 8088 I/O
	in	al, dx		; get a byte
	stosb			; save it
	loop	in_88
	ret

in_186:				; Use 80[123]86 I/O
	REP_INSB
	ret

in_16bit:			; Use 16 bit I/O
	inc	cx
	shr	cx, 1		; round up to nearest word count
	REP_INSW
	ret

  ifdef MCA_STUFF
in_mem:				; Copy from shared memory
	push	ds
	mov	ds, shmem_seg
	inc	cx
	shr	cx, 1
	rep	movsw
	pop	ds
  endif

	ret


	public	block_output
;enter with AX = board address, CX = length, DS:SI -> buffer
;From ne1000.asm, modified for shared mem.
block_output:
	assume	ds:nothing

	cld
  ifdef MCA_STUFF
	test	sys_features, SYS_MCA
	jnz	out_mem
  endif
	push	ax		; save buffer address
	inc	cx		; make even
	and	cx, 0fffeh
	loadport
	setport EN_CCMD
	pause_
	mov	al, ENC_NODMA + ENC_START
	out	dx, al		; stop & clear the chip

;There's some funkiness to remote DMA writes under certain conditions,
;according to the National DP8390 Datasheet Addendum and comments in
;the hppclan driver.  A description and solution to the problem, from
;Glenn Talbott's additions to hppclan.asm, are reproduced here.  -KNG

;; To quote from the National DP8390 Datasheet Addendum, June 1990
;;
;;   11.0 Remote DMA Write
;;
;;   Under certain conditions the NIC may issue /MWR and /PRD before
;;   PRQ for the first DMA transfer. This causes an extraneous byte to be
;;   written inot memory at the first Remote DMA Write location. [...]
;;
;;   To prevent this condition, write a non-zero value into RBCR0 and
;;   issued [sic] the Remote Read DMA command to the NIC (CR=0AH), but
;;   do not give any Read Acknowledges (/RACK). (This causes PRQ to go high.)
;;   Then write the desired byte count into RBCR0 and RBCR1 and give the
;;   Remote Write DMA command (CR=12H). The Remote Write DMA will operate as
;;   normal.
;;
;; My interpretation of the above is          - gft - 910603

	setport	EN0_RCNTLO	; remote byte count 0
	pause_
	mov	al,0ffh		; a non-zero value
	out	dx,al
	setport EN_CCMD
	pause_
	mov     al,ENC_RREAD+ENC_START ; read and start
	out     dx,al		; starts the read setting PRQ for the first
				; DMA transfer, now reprogram everything
				; and start a write instead.

;; BUT WHAT THE NATIONAL DOCUMENTATION DOESN'T TELL YOU ...
;;
;;  When the read is started, the remote byte count register is decremented
;;  (in this case from 0ffh to 0feh). This takes a finite amount of time.
;;  IF you are TOO QUICK in re-programming the remote byte count 0 register
;;  to the correct value, the NEW VALUE GETS DECREMENTED INSTEAD! Then when
;;  you reach the last byte of the buffer and you output it to the IO port,
;;  the NIC has already reached a count of zero and WON'T HANDSHAKE THE LAST
;;  BYTE!. Result, computer HUNG, powercycle to recover. Therefore a stall is
;;  required here, I use at least 1.5uS
;;                                      - gft - 910603
;;
	in	al,61h		; read from NMI Status register for IO delay
	in	al,61h		; ~ 0.5uS on Microchannel and ~ 1.0 on ISA
	in	al,61h		; for a total of ~1.5uS or 3.0uS.

;Now the rest of block_output:   -KNG 921208

	setport	EN0_RCNTLO	; remote byte count 0
	pause_
	mov	al, cl
	out	dx, al
	setport	EN0_RCNTHI
	pause_
	mov	al, ch
	out	dx, al

	pop	ax		; get our page back
	setport	EN0_RSARLO
	pause_
	out	dx, al		; set as lo address
	setport	EN0_RSARHI
	pause_
	mov	al, ah
	out	dx, al

	setport EN_CCMD
	pause_
	mov	al, ENC_RWRITE + ENC_START	; write and start
	out	dx, al
	setport	CT_DATAPORT
	pause_

	jmp	[out_jmp]	; do the copy

out_88:				; Default:  loop for 8088/8086
	lodsb
	out	dx, al
	loop	out_88
	jmp	short block_out_1

out_186:			; Use 80[123]86 I/O
	REP_OUTSB
	jmp	short block_out_1

out_16bit:			; Use 16 bit I/O
	inc	cx
	shr	cx, 1		; convert to word count
	REP_OUTSW
	jmp	short block_out_1

  ifdef MCA_STUFF
out_mem:			; Copy to shared mem
	push	es
	mov	es, shmem_seg
	inc	cx
	shr	cx, 1
	rep	movsw
	pop	es
  endif

block_out_1:
	mov	cx, 0
	setport	EN0_ISR
tx_check_rdc:
	in	al, dx
	test	al, ENISR_RDC	; dma done ?
	jnz	tx_start	; jump if so
	loop	tx_check_rdc	; otherwise loop
	stc
	ret
tx_start:
	clc
	ret


; The following 6 lines seem to be needed at the start of the recv
; routine in 8390.asm, for PS/2s.  -KNG 930924
ifdef MCA_STUFF
xxxxxx  Move to start of recv in 8390.asm:  xxxxxx
	test	sys_features, SYS_MCA
	jz	check_isr
	loadport
	setport	23h
	mov	al, 4
	out	dx, al
endif

	include	8390.asm


int_no_list	db	3, 7, 9			; IRQ list for MCA
out_jmp_list	dw	out_88, out_186, out_16bit
in_jmp_list	dw	in_88, in_186, in_16bit
slot_no		db	0			; BIOS slot number
tmp_pag		db	0			; used in do_test
testbyte	db	0			; used in test_mem

BUF_SIZ		equ	100h
buf		db	BUF_SIZ dup(?)		; used for diags in test_mem

EOM		equ	CR, LF, '$'
	public	usage_msg
usage_msg	db	"Usage:  ctrondni [options] <packet_int_no> <hardware_irq> <io_addr>", EOM

	public	copyright_msg
copyright_msg	db	"Packet driver for Cabletron DNI cards, version "
		db	'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,".",'0'+dp8390_version,CR,LF
		db	"Portions Copyright 1992-1993, Kai Getrost", EOM

cant_find_msg	db	"** Can't find Ethernet controller **", EOM
mem_failed_msg	db	"** Board memory test failed **", EOM
mem_msg		db	"; mem size in kb is ", '$'
bus_msg		db	"Bus is ", '$'
bus_8_msg	db      "8 bit", '$'
bus_16_msg	db	"16 bit", '$'
  ifdef MCA_STUFF
bus_MCA_msg	db	"microchannel", '$'
  else
no_MCA_msg	db	"Microchannel bus unsupported", EOM
  endif
int_no_msg	db	"Interrupt number ", '$'
ioaddr_msg	db	"I/O address ", '$'


	extrn	set_recv_isr: near
	extrn	get_number: near
	extrn	print_number: near
	extrn	decout: near

	public	parse_args
parse_args:
;Exit with cy if error, nc if OK.  Reads IRQ, IO port numbers.

	mov	di, offset int_no
	call	get_number		;read IRQ number
	jc	parse_err		;jump if error
	mov	di, offset io_addr
	call	get_number		;read I/O address
	jc	parse_err
	clc				;no error
	ret
parse_err:
	stc				;error
	ret


	public	init_card
init_card:
;Returns with nc if ok; cy if error.  Determines bus/mem size, tests mem,
;reads Ethernet address, etc.

	test	sys_features, SYS_MCA
	jz	init_1				;jump if not MCA
  ifdef MCA_STUFF
	call	do_MCA_stuff
	jb	init_err
	jmp	init_2
  else
; Microchannel bus detected, but no MCA code:
	mov	dx, offset no_MCA_msg
	stc
	jmp	init_err
  endif

init_1:
	call	get_bus_size			;get bus size (if not MCA)
init_2:

init_3:
;Set block_input/output mode (8-bit loop, 8-bit 80186 I/O, 16-bit 80186)
;MCA is not checked since block_output/input checks it
	xor	bx, bx
	cmp	is_186, 0
	jz	init_cont
	inc	bx
	cmp	is_16bit, 0
	jz	init_cont
	inc	bx
init_cont:
	shl	bx, 1				;offsets are words
	mov	ax, out_jmp_list[bx]
	mov	out_jmp, ax
	mov	ax, in_jmp_list[bx]
	mov	in_jmp, ax

	call	read_address			;get Ethernet address
  ifdef MCA_STUFF
	test	sys_features, SYS_MCA
	jnz	init_5				;jump if MCA; we know mem size
  endif
	call	get_mem_size
init_5:
	call	test_mem			;test board memory
	jb	init_err

	clc					;no error return
	ret
init_err:
	mov	ah, 9
	int	21h				;print error msg
	stc					;error return
	ret


	public	print_parameters
;Prints command line parameters, bus/mem info.
print_parameters:

	mov	ah, 9
	mov	dx, offset bus_msg
	int	21h

;print bus size:
	mov	dx, offset bus_8_msg
  ifdef MCA_STUFF
	test	sys_features, SYS_MCA
	jz	pr_not_MCA
	mov	dx, offset bus_MCA_msg
	jmp	pr_bus
  endif
pr_not_MCA:
	cmp	is_16bit, 0
	jz	pr_bus
	mov	dx, offset bus_16_msg
pr_bus:
	mov	ah, 9
	int	21h

	mov	al, cs:sm_rstop_ptr	;
	add	al, 3			;
	shr	al, 1			; calculate memory size in Kb =
	shr	al, 1			;    (sm_rstop_ptr + 3) / 4
	xor	ah, ah			;
	mov	word ptr buf, ax	;
	mov	dx, offset mem_msg
	mov	di, offset buf
	call	print_number		;print mem size

	mov	dx, offset int_no_msg
	mov	di, offset int_no
	call	print_number		;print int_no
	mov	dx, offset ioaddr_msg
	mov	di, offset io_addr
	call	print_number		; and IO port

	ret


read_address:
;Gets board address into rom_address. From ne1000.asm init_card,
;modified.  Board data is 16 bytes starting at remote dma address 0.
;Put it in a buffer called board_data.
	assume	ds:code

	mov	cx, 10h			; get 16 bytes,
	push	ds
	pop	es			; set es to ds
	mov	di, offset board_data
	mov	si, 0			; from address 0
	call	get_block

	push    ds              	; Copy to current address:
	pop     es
	mov	si, offset board_data	; address is at start of board_data
	mov	di, offset rom_address
	mov	cx, EADDR_LEN		; one address length
	cld
	rep     movsb

	ret	;Cabletron checks if address starts w/00:00:1D; we don't care


ifdef MCA_STUFF
do_MCA_stuff:
;Called only if microchannel card.  Returns CY, DX = error msg if error.
;I don't really know what this does...

	cli
	mov	dx, 100h
	mov	al, slot_no
	or	al, al
	jz	dm_check
	dec	al
	or	al, 8
	out	96h, al		;select MCA channel ?
	inc	dx
	pause_
	in	al, dx
	mov	ah, al
	dec	dx
	pause_
	in	al, dx
	cmp	ah, 56h
	je	dm_cont
	jmp	dm_cantfind

dm_check:
	mov	cx, 8
	mov	bl, 8
dm_loop:
	mov	al, bl
	out	96h, al
	inc	dx
	pause_
	in	al, dx
	mov	ah, al
	dec	dx
	pause_
	in	al, dx
	cmp	ah, 56h
	je	dm_cont
	inc	bl
	loop	dm_loop

dm_cantfind:
	xor	al, al
	out	96h, al
	sti
	mov	dx, offset cant_find_msg
	stc					;error
	ret

dm_cont:
	mov	sm_rstop_ptr, 0
	test	al, 1
	jnz	dm_1
	mov	sm_rstop_ptr, 40h		;16K board mem
dm_1:
	mov	dx, 102h
	mov	al, 81h
	out	dx, al
	inc	dx
	in	al, dx
	mov	bl, al
	inc	dx
	in	al, dx
	mov	bh, al
	xor	al, al
	out	96h, al
	sti

	mov	endcfg, ENDCFG_FT10 + ENDCFG_BMS + ENDCFG_WTS	;word transfer
	mov	ah, bl
	and	ah, 0f0h
	mov	cl, 2
	shr	ah, cl
	or	ax, 0c000h
	mov	shmem_seg, ax
	mov	ah, bl
	and	ah, 0eh
	mov	cl, 3
	shl	ax, cl
	or	ax, 300h
	mov	io_addr, ax		;set IO address

	loadport
	setport	EN0_IMR
	xor	al, al
	pause_
	out	dx, al
	setport	EN0_ISR
	pause_
	out	dx, al
	mov	bl, bh
	and	bx, 3
	mov	al, int_no_list[bx]
	mov	int_no, al		;set IRQ

;PIC stuff was here

	setport	20h
	mov	al, 12h
	out	dx, al
	setport	23h
	mov	al, 7ch
	out	dx, al
	setport	22h
	mov	al, 4
	out	dx, al
	clc
	ret
endif


get_bus_size:
;Determines bus size.  Not called on MCA cards; they use shared mem.
;If 16 bit bus, sets endcfg to ENDCFG_WTS (word transfer mode), is_16bit to 1

	loadport
	setport	EN0_RSARLO
	mov	ax, 100h
	pause_
	out	dx, al
	setport	EN0_RSARHI
	pause_
	mov	al, ah		;Cabletron bug: does AL -> DX, not AH
	out	dx, al

	setport	EN0_RCNTLO
	mov	ax, 40h
	pause_
	out	dx, al
	setport	EN0_RCNTHI
	mov	al, ah
	pause_
	out	dx, al

	setport	EN_CCMD
	mov	al, ENC_RWRITE + ENC_START
	pause_
	out	dx, al

	xor	cx, cx
	setport	EN0_CRDALO
	pause_
	in	al, dx
	or	al, al
	jnz	gbs_1

gbs_2:
	loadport
	setport	CT_DATAPORT
	pause_
	out	dx, ax		;should this be AL instead of AX?

gbs_1:
	inc	cx
	loadport
	setport	EN0_CRDALO
	pause_
	in	al, dx
	cmp	al, 40h
	jne	gbs_2

	setport	EN_CCMD
	mov	al, ENC_NODMA + ENC_START
	pause_
	out	dx, al
	setport	EN0_ISR
	mov	al, 0ffh
	out	dx, al

	cmp     cx, 30h
	jb	gbs_ret			; jump if 8-bit bus
	or	endcfg, ENDCFG_WTS	; use word transfer
	mov	is_16bit, 1

gbs_ret:
	ret


get_mem_size:
;Determines size of on-board memory.
;Call only if not MCA (do_MCA_stuff determines mem size on MCA).

;Write 0's to first word of all possible pages (1-255):
	mov	tmp_pag, 1
	mov	word ptr buf, 0
gms_2:
	mov	si, offset buf
	mov	ah, tmp_pag
	xor	al, al
	mov	cx, 2
	call	block_output
	inc	tmp_pag
	jnz	gms_2

;Write TEST_VAL to first word of page 1:
	mov	si, offset buf
	mov	[si], TEST_VAL
	mov	ax, 100h
	mov	cx, 2
	call	block_output

;Starting at page 11h, look for TEST_VAL every 10h pages (4kb).  Page found
;(rounded to 4kb) is on-board mem size:
	mov	tmp_pag, 11h
gms_3:
	mov	ah, tmp_pag
	xor	al, al
	mov	si, ax
	mov	di, offset buf
	mov	cx, 2
	call	get_block
	cmp	word ptr buf, TEST_VAL
	je	gms_1
	add	tmp_pag, 10h
	jnb	gms_3

gms_1:
	mov	al, tmp_pag
	and	al, 0f0h			;trunc mem size to nearest 4Kb
	mov	sm_rstop_ptr, al

	ret


test_mem:
;Returns CY, DX = msg if failed.
;Tests board memory by writing and reading bit patterns.

	mov	testbyte, 0ffh
	call	do_test
	jb	tm_err
	mov	testbyte, 0
	call	do_test
	jb	tm_err

	clc
	ret
tm_err:
	mov	dx, offset mem_failed_msg
	stc
	ret


do_test:
;Writes `testbyte' to board memory and reads it back.
;Returns CY if failure.

	mov	tmp_pag, SM_TSTART_PG		;? probably
dt_loop:
	mov	al, testbyte
	mov	di, offset buf
	mov	cx, BUF_SIZ
	cld
	rep	stosb				;set buf = testbyte

	mov	si, offset buf
	mov	ah, tmp_pag
	xor	al, al
	mov	cx, BUF_SIZ
	call	block_output			;write pattern to page

	mov	ah, tmp_pag
	xor	al, al
	mov	si, ax
	mov	di, offset buf
	mov	cx, BUF_SIZ
	call	get_block			;read it back

	mov	al, testbyte
	mov	di, offset buf
	mov	cx, BUF_SIZ
	cld
	rep	scasb				;check mem we read
	jne	dt_failed			;jump if != testbyte

	inc	tmp_pag				;go to next page
	mov	al, tmp_pag
	cmp	al, sm_rstop_ptr		;have we done all pages?
	jne     dt_loop				;jump if not

	clc					;no error
	ret
dt_failed:
	stc					;error
	ret


code	ends
	end
