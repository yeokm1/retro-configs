
PNP_IRQ_FRMT		EQU	0022h ; PNP small item IRQ format

PNP_ADD_PORT		EQU	0279h
PNP_WRITE_PORT		EQU	0A79h

GET_PNP_ISA_STRUCT	EQU	40h
PNP_ISA_STRUCT_LEN	EQU	06h
PNP_CSN_CNT_OFF		EQU	01h
PNP_RD_PORT_OFF		EQU	02h
PNP_FUNCTION_OK		EQU	00h
PNP_WAKE			EQU 03h
PNP_RSRC_DATA		EQU 04h
	PNP_RSRC_READY	EQU	01H
PNP_STATUS			EQU 05h
PNP_ACTIVATE		EQU 30h
PNP_CNF_IO_H		EQU	60h
PNP_CNF_IO_L		EQU	61h
PNP_CNF_INT			EQU	70h
PNP_CNF_DMA			EQU	74h

SELECT_PNP_REG macro %1
	mov		dx, PNP_ADD_PORT
	mov		al, %1
	out		dx, al
endm

WRITE_PNP_REG_BL macro %1
	; Set PNP register %1 to the value of bl
	SELECT_PNP_REG %1
	mov		dx, PNP_WRITE_PORT
	mov		al, bl
	out		dx, al
endm


WRITE_PNP_REG macro %1, %2
	; Set PNP register %1 to the value of %2
	SELECT_PNP_REG %1
	mov		dx, PNP_WRITE_PORT
	mov		al, %2
	out		dx, al
endm

READ_PNP_REG macro %1
	; Read PNP register %1
	SELECT_PNP_REG %1
	mov		dx, WORD PTR pnp_isa_struct[PNP_RD_PORT_OFF]
	in		al, dx
endm
