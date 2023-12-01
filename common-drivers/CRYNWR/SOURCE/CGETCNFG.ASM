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

DGROUP	GROUP  	CONST, _BSS, _DATA
	ASSUME  CS: _TEXT, DS: DGROUP, SS: DGROUP

_DATA	SEGMENT
	ASSUME DS: DGROUP
;include adapname.inc
_DATA	ENDS

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
 
public	_LM_GetCnfg
public	_GetBoardID

ifdef	SETUP_MODE
public	_LM_Get_SoftCnfg
endif

include	bicnic.inc
include	lmstruct.inc
include	getcnfg.asm
IFDEF LARGE
_LM_GetCnfg 	proc	far
ELSE
_LM_GetCnfg 	proc	near
ENDIF
		push	bp
		mov	bp, sp
                push    ds
		GETPOINTER

		call	LM_GetCnfg

		pop	ds
		pop	bp
		ret

_LM_GetCnfg	endp

ifdef	SETUP_MODE
IFDEF LARGE
_LM_Get_SoftCnfg 	proc	far
ELSE
_LM_Get_SoftCnfg 	proc	near
ENDIF
		push	bp
		mov	bp, sp
                push    ds
		GETPOINTER

		call	LM_Get_SoftCnfg

		pop	ds
		pop	bp
		ret

_LM_Get_SoftCnfg	endp
endif
IFDEF LARGE
_GetBoardID 	proc	far
ELSE
_GetBoardID 	proc	near
ENDIF
		push	bp
		mov	bp, sp
		GETPARAMS

		call	GetBoardID

		pop	bp
		ret

_GetBoardID	endp

_TEXT	ENDS
	END       
