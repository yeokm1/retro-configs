_TEXT	SEGMENT  WORD PUBLIC 'CODE'
_TEXT	ENDS
_DATA	SEGMENT  WORD PUBLIC 'DATA'
_DATA	ENDS
CONST	SEGMENT  WORD PUBLIC 'CONST'
CONST	ENDS
_BSS	SEGMENT  WORD PUBLIC 'BSS'
_BSS	ENDS

DGROUP	GROUP  	CONST, _BSS, _DATA
	ASSUME  CS: _TEXT, DS: DGROUP, SS: DGROUP

_DATA	SEGMENT
	ASSUME DS: DGROUP
_DATA	ENDS

include	lmstruct.inc
include	bicnic.inc

PUBLIC	__acrtused
__acrtused	equ	9876h


IFNDEF  EZSTART
ifdef	LARGE
extrn	_internal_loopback:	far
else
extrn	_internal_loopback:	near
endif
ENDIF

ifdef	LARGE
SFO	equ	2	; Stack Frame offset . . .
else
SFO	equ	0
endif

_TEXT      	SEGMENT
		ASSUME	CS: _TEXT

SysDescriptor	struc
ByteCount	dw	?
ModelByte	db	?
SubModelByte	db	?
BIOSRev		db	?
FeatureInfo1	db	?
FeatureInfo2	db	?
FeatureInfo3	db	?
FeatureInfo4	db	?
SysDescriptor	ends

;; Defs for FeatureInfo1:
FD_DMA3		equ	80h	; Fixed Disk uses DMA ch. 3
TWO_PICS	equ	40h	; System has 2 8259 PIC's
RTC_PRESENT	equ	20h	; Real Time Clock Present
KET_INT_SEQ	equ	10h	; Keyboard Intercept (Int 15h) called in Int 09h
EXT_WAIT	equ	08h	; Wait for external event supported
EX_BIOS_ALLOC	equ	04h	; External BIOS data area is allocated
;MCA_BUS		equ	02h	; Micro Channel Bus
;RESERVED	equ	01h	; Reserved
ifdef	LARGE
PARAMOFST1	equ	06h
PARAMOFST2	equ	08h
else
PARAMOFST1	equ	04h
PARAMOFST2	equ	06h
endif

;; Defs for other routines . . .
TENTH_SECOND_LOOPS	EQU	25000

PUBLIC	_real_timable
PUBLIC	_fake_tenth_second
PUBLIC	__inp
PUBLIC	__outp
PUBLIC	_recheck_16bit_access
PUBLIC	_check_16bit_access


IFNDEF  EZSTART
PUBLIC	InternalLoopback
ifdef	LARGE
InternalLoopback 	proc	far
else
InternalLoopback	proc	near
endif
                push    ds
		push	bp

		mov	ax, DGROUP
		mov	ds, ax

		call	_internal_loopback
		add	sp, 4
		ret
InternalLoopback	endp
ENDIF


ifdef	LARGE
_real_timable	proc	far
else
_real_timable	proc	near
endif
		push	bp
		mov	bp, sp

		push	bx
		push	es

		mov	ah, 0C0h
		int	15h
		or	ah, ah
		jnz	NoRTC
		test	es:[bx].FeatureInfo1, RTC_PRESENT
		jz	NoRTC
		xor	ax, ax
		dec	ax
RTCExit:
		pop	es
		pop	bx
		pop	bp
		ret

NoRTC:		xor	ax, ax
		jmp	RTCExit
_real_timable	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	_inp ()	Used when MSC library inclusion is not desired.
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	LARGE
__inp	proc	far
else
__inp	proc	near
endif
	push	bp
	mov	bp, sp

	xor	ax, ax
	mov	dx, [bp+PARAMOFST1]
	in	al, dx

	pop	bp
	ret
__inp	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	_outp ()	Used when MSC library inclusion is not desired.
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	LARGE
__outp	proc	far
else
__outp	proc	near
endif
	push	bp
	mov	bp, sp

	xor	ax, ax
	mov	dx, [bp+PARAMOFST1]
	mov	al, [bp+PARAMOFST2]
	out	dx, al

	pop	bp
	ret
__outp	endp

ifdef	LARGE
_fake_tenth_second	proc	far
else
_fake_tenth_second	proc	near
endif
		push	bp
		mov	bp, sp
		push	cx
		mov	cx, TENTH_SECOND_LOOPS
_fake_loop:
		loop	_fake_loop
		pop	cx
		pop	bp
		ret

_fake_tenth_second		endp

		PUBLIC	_get_time

IFDEF	LARGE
_get_time	proc	far
else
_get_time	proc	near
endif
		push	bp
		mov	bp,sp
		push	cx

		mov	ah, 0
		int	1Ah		; cx:dx

		or	al, al		; has it gone past 24 hours worth?
		jz	_show_real_time
		mov	dx, 0FFFFh	; fake time so caller will break out
		mov	cx, 0FFFFh
_show_real_time:
		mov	ax, dx
		mov	dx, cx

		pop	cx
		pop	bp
		ret
_get_time 	endp

ifdef	LARGE
_check_16bit_access	proc	far
else
_check_16bit_access	proc	near
endif

		push	bp
		mov	bp, sp
		push	ax
		push	dx
		push	ds

		cli
		lds	bp, [bp+4+SFO]
		mov	dx, ds:[bp].io_base
		add	dx, REG_LAAR
		mov	al, ds:[bp].laar_enter
		out	dx, al

		cmp	ds:[bp].nic_type, NIC_790_CHIP
		jne	MemsNotDisabled1

		add	dx, REG_MSR - REG_LAAR
		mov	al, MSR_MENB
		out	dx, al
		in	al, dx
MemsNotDisabled1:

		pop	ds
		pop	dx
		pop	ax
		pop	bp
		ret
_check_16bit_access	endp

ifdef	LARGE
_recheck_16bit_access	proc	far
else
_recheck_16bit_access	proc	near
endif

		push	bp
		mov	bp, sp
		push	ax
		push	dx
		push	ds

		lds	bp, [bp+4+SFO]
		mov	dx, ds:[bp].io_base
		cmp	ds:[bp].nic_type, NIC_790_CHIP
		jne	DisableMemNot

		mov	al, 0
		out	dx, al
		in	al, dx
DisableMemNot:

		add	dx, REG_LAAR
		mov	al, ds:[bp].laar_exit
		out	dx, al
		sti

		pop	ds
		pop	dx
		pop	ax
		pop	bp
		ret
_recheck_16bit_access	endp

_TEXT	ENDS
	END       

