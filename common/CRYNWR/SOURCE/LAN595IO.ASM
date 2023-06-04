
;input a word from I/O port
inw	macro
	call	inw_routine
	endm

; Input a word from I/O port, 16 bits at one time
inw_16	PROC	NEAR
	in	ax,dx
	ret
inw_16	ENDP

; Input a word from I/O port, 2 8 bits reads
inw_2_8	PROC	NEAR
	in		al, dx			; Read low address byte
	mov		ah, al			; Save byte
	inc		dx				; Next I/O address
	in		al, dx			; Read high address byte
	xchg	ah, al			; Swap bytes 
	dec		dx				; Restore I/O address
	ret
inw_2_8	ENDP

; Write a word to an I/O port
outw	macro
	call	outw_routine
	endm

; Output a word to I/O port, 16 bits at one time
outw_16	PROC	NEAR
	out		dx, ax			; Write to the I/O port
	ret
outw_16	ENDP


; Output a word to I/O port, 2 8 bit writes
outw_2_8	PROC	NEAR
	out		dx, al			; Write low address byte
	xchg	ah, al			; Get next byte
	inc		dx				; Next I/O address
	out		dx, al			; Write high address byte
	xchg	ah, al			; Restore AX
	dec		dx				; Rrestore DX
	ret
outw_2_8	ENDP


	extrn	is_186: byte		;=0 if 808[68], =1 if 80[123]86.

	.286
quick_rep_ins_16	PROC	NEAR
; Does a repeated in instruction by performing 16 bit reads (186 or better)
; CX holds the number of ins - no minimum value
	shr		cx, 1			; Convert the byte count to a word count
	rep		insw			; Does the entire transfer to the buffer
	jnc		done_q_i_16		; Jump if cx was initially even
	insb					; Read the last byte
done_q_i_16:
	ret
quick_rep_ins_16	ENDP
	.8086


rep_ins_16	PROC	NEAR
; Does a repeated in instruction by performing 16 bit reads.
; CX holds the number of ins - no minimum value
	shr		cx, 1			; Convert the byte count to a word count
	jcxz	rep_i_16_1	; Jump if no words to copy 
next_i_16:
	in		ax, dx			; Get the next word from the port
	stosw					; Store this word in the buffer
	loop	next_i_16		; Continue if there are more words
	jnc		done_i_16		; Jump if cx was initially even
rep_i_16_1:
	in		al, dx			; Get the last byte from the low address
	stosb					; Store this last byte in the buffer
done_i_16:
	ret
rep_ins_16	ENDP


	.286
quick_rep_ins_2_8	PROC	NEAR
; Does a repeated in instruction by performing 2 8 bit writes (186 or better)
; CX holds the number of ins - no minimum value
	shr		cx, 1			; Convert the byte count to a word count
	jcxz	rep_q_i_2_8_1	; Jump if no words to copy 
next_q_i_2_8:
	insb					; Store the byte from the low address port
	inc		dx				; Advance to the high address port
	insb					; Store the byte from the high address port
	dec		dx				; Go back to the low address port
	loop	next_q_i_2_8	; Continue if more words to read
rep_q_i_2_8_1:
	jnc		done_q_i_2_8	; Jump if cx was initially even
	insb					; Store the last byte from the low address port
done_q_i_2_8:
	ret
quick_rep_ins_2_8	ENDP
	.8086

rep_ins_2_8	PROC	NEAR
; Does a repeated in instruction by performing 2 8 bit writes.
; CX holds the number of ins - no minimum value
	shr		cx, 1			; Convert the byte count to a word count
	jcxz	rep_i_2_8_1		; Jump if no words to copy 
next_i_2_8:
	in		al, dx			; Get the byte from the low address port
	mov		ah, al			; Store the low byte
	inc		dx				; Advance to the high adress port
	in		al, dx			; Get the byte from the high address port
	xchg	al, ah			; Swap the bytes
	stosw					; Store the word
	dec		dx				; Go back to the low address port
	loop	next_i_2_8		; Continue if more words to read
rep_i_2_8_1:
	jnc		done_i_2_8		; Jump if cx was initially even
	in		al, dx			; Get the last byte from the low address
	stosb					; Store this last byte in the buffer
done_i_2_8:
	ret
rep_ins_2_8	ENDP


	.286
quick_rep_outw_16	PROC	NEAR
; Does a repeated out instruction by performing 16 bit writes (186 or better)
; CX holds the number of outs and will be at least RUNT
	inc		cx				; To cope with odd packet lengths
	shr		cx, 1			; Convert the byte count to a word count
	rep		outsw			; Does the entire transfer
	ret
quick_rep_outw_16	ENDP
	.8086


rep_outw_16	PROC	NEAR
; Does a repeated out instruction by performing 16 bit writes.
; CX holds the number of outs and will be at least RUNT
	inc		cx				; To cope with odd packet lengths
	shr		cx, 1			; Convert the byte count to a word count
next_o_16:					; Do the transfer of the buffer, a word at a time
	lodsw					; Get the next word form the buffer
	out		dx, ax			; Send it to the port
	loop	next_o_16		; Continue if there are more bytes
done_o_16:
	ret
rep_outw_16	ENDP


	.286
quick_rep_outw_2_8	PROC	NEAR
; Does a repeated out instruction by performing 2 8 bit writes (186 or better) 
; CX holds the number of outs and will be at least RUNT
	inc		cx				; To cope with odd packet lengths
	shr		cx, 1			; Convert the byte count to a word count
next_q_o_2_8:
	outsb					; Output 8 bits to the low address
	inc		dx				; Advance to the high address port
	outsb					; Output 8 bits to the high address
	dec		dx				; Restore the low address port
	loop	next_q_o_2_8	; Continue if there are more bytes
	ret
quick_rep_outw_2_8		ENDP
	.8086


rep_outw_2_8	PROC	NEAR
; Does a repeated out instruction by performing 2 8 bit writes.
; CX holds the number of outs and will be at least RUNT
	inc		cx				; To cope with odd packet lengths
	shr		cx, 1			; Convert the byte count to a word count
next_o_2_8:
	lodsw					; Load the next word from the buffer
	out		dx, al			; Outputs 8 bits to the low address
	inc		dx				; Advance to the high address port
	mov		al, ah			; Get teh next byte to ouput
	out		dx, al			; Output 8 bits to the high address
	dec		dx				; Restore the low address port
	loop	next_o_2_8		; Continue if there are more bytes
	ret
rep_outw_2_8	ENDP

