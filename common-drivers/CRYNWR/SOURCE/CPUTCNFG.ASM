;******************************************************************************
;******************************************************************************
;	A George Kalwitz Production, 1990
;******************************************************************************
;******************************************************************************
;
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

; macro to get passed parameters from the stack
GETPOINTER	MACRO
IFDEF	SMALL
		lds	bp, [bp+4]		;adapter ptr
ENDIF
IFDEF	LARGE
		lds	bp, [bp+6]		;adapter_ptr
ENDIF
		ENDM 

GETPARAMS	MACRO
IFDEF	SMALL
		mov	ax, [bp+6]		;machine flag
		mov	dx, [bp+4]		;base I/O address
ENDIF
IFDEF	LARGE
		mov	ax, [bp+8]		;machine flag
		mov	dx, [bp+6]		;base I/O address
ENDIF
		ENDM 

	
_TEXT      	SEGMENT
		ASSUME	CS: _TEXT
 
public	_LM_PutCnfg
	
include	popff.mac
include	lmstruct.inc
include	weerom.asm
include	putcnfg.asm
include	getcnfg.inc
include eerom.inc
include	bicnic.inc
extrn	SumEERomData:		near
extrn	SelectOtherRegister:	near
extrn	RecallEERomData:	near

IFDEF LARGE
_LM_PutCnfg 	proc	far
ELSE
_LM_PutCnfg 	proc	near
ENDIF
		push	bp
		mov	bp, sp
                push    ds
		GETPOINTER

		call	LM_PutCnfg

		pop	ds
		pop	bp
		ret

_LM_PutCnfg	endp

_TEXT	ENDS
	END       
