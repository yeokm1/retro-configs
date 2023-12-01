_TEXT	SEGMENT  WORD PUBLIC 'CODE'
_TEXT	ENDS
_DATA	SEGMENT  WORD PUBLIC 'DATA'
_DATA	ENDS
CONST	SEGMENT  WORD PUBLIC 'CONST'
CONST	ENDS
_BSS	SEGMENT  WORD PUBLIC 'BSS'
_BSS	ENDS
DGROUP	GROUP	CONST, _BSS, _DATA
	ASSUME  CS: _TEXT, DS: DGROUP, SS: DGROUP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GETPOINTER	MACRO
IFDEF	SMALL
		lds	bp, [bp+4]		;adapter ptr
ENDIF
IFDEF	LARGE
		lds	bp, [bp+6]		;adapter_ptr
ENDIF
		ENDM 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.xlist
include	bicnic.inc
include	eerom.inc
include	lmstruct.inc
.list

_TEXT      	SEGMENT
		ASSUME	CS: _TEXT
		PUBLIC	_Write584Checksum, _Read584Checksum

IFDEF LARGE
_Read584Checksum 	proc	far
ELSE
_Read584Checksum 	proc	near
ENDIF
		push	bp
		mov	bp, sp
                push    ds
		GETPOINTER

		call	Read584Checksum

		pop	ds
		pop	bp
		ret

_Read584Checksum	endp
	
IFDEF LARGE
_Write584Checksum 	proc	far
ELSE
_Write584Checksum 	proc	near
ENDIF
		push	bp
		mov	bp, sp
                push    ds
		GETPOINTER

		call	Write584Checksum

		pop	ds
		pop	bp
		ret

_Write584Checksum	endp
include	reerom.asm	
include	weerom.asm
_TEXT	ENDS
	END       
