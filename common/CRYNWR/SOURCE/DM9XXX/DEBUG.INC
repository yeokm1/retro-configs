IFDEF	DEBUGDOS
EXTRN	init_debug: near
EXTRN	b_char: near
EXTRN	b_byte: near
EXTRN	d_char: near
EXTRN	d_byte: near
ENDIF

;-- Cloor Attribute Definitions
;------------------------------------------------------------------------
BLACK		EQU	0		; dark colors
BLUE		EQU	1
GREEN		EQU	2
CYAN		EQU	3
RED		EQU	4
MAGENTA 	EQU	5
BROWN		EQU	6
DARKGRAY	EQU	7
LIGHTGRAY	EQU	8		; light colors
LIGHTBLUE	EQU	9
LIGHTGREEN	EQU	10
LIGHTCYAN	EQU	11
LIGHTRED	EQU	12
LIGHTMAGENTA	EQU	13
YELLOW		EQU	14
WHITE		EQU	15

;-- Macro Definitions
;------------------------------------------------------------------------
BRUSH_CHAR	macro	ch
IFDEF	DEBUGDOS
	push	ax
	mov	al, ch
	call	b_char
	pop	ax
ENDIF
	endm

BRUSH_BYTE	macro	bdata
IFDEF	DEBUGDOS
	push	ax
	mov	al, bdata
	call	b_byte
	pop	ax
ENDIF
	endm

DISP_CHAR	macro	ch, attr, x, y
IFDEF	DEBUGDOS
	push	ax
	push	bx
	push	dx

	mov	dl, x
	mov	dh, y
	mov	bh, attr
	mov	al, ch
	call	d_char

	pop	dx
	pop	bx
	pop	ax
ENDIF
	endm

DISP_BYTE	macro	bdata, attr, x, y
IFDEF	DEBUGDOS
	push	ax
	push	bx
	push	dx

	mov	dl, x
	mov	dh, y
	mov	bh, attr
	mov	al, bdata
	call	d_byte

	pop	dx
	pop	bx
	pop	ax
ENDIF
	endm

