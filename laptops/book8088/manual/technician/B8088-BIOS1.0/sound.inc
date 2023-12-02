;=========================================================================
; sound.inc - Play power-on sound. This also tests PIT and PORT B functionality
;-------------------------------------------------------------------------
;
;=========================================================================

notes	dw	pic_freq/554		; D flat
	dw	-1			; silent
	dw	pic_freq/227		; D flat
	dw	pic_freq/370		; G flat
	dw	pic_freq/227		; D flat
	dw	pic_freq/415		; A flat
	dw	0

;=========================================================================
; sound - Play power-on sound.
; Input:
;	none
; Output:
;	none, destroys some registers
;-------------------------------------------------------------------------
sound:
	cld
	mov	si,notes			; set SI to notes table

	mov	al,0B6h			; set PIC channel 2 to mode 3
	out	pit_ctl_reg,al

.loop:
    cs	lodsw				; load next note to AX
	cmp	ax,0
	jz	.exit
	jl	.silent			; don't turn on speaker if silent note
	out	pit_ch2_reg,al		; load divisor's low byte to PIC
	mov	al,ah
	out	pit_ch2_reg,al		; load divisor's high byte to PIC

;	in	al,ppi_pb_reg		; read current value of PORT B 读取端口已删除
        	mov         al,03h			; turn on the speaker 直接D1=1打开扬声器，其他位无意义
        	out    	ppi_pb_reg,al		; write the new value

.silent:
	mov	cx,3000h
	call	delay_15us		; delay while note is playing

;	in	al,ppi_pb_reg		; read current value of PORT B 读取端口已删除，无需读取
	mov	al,00h			; turn off the speaker 直接赋值0，关闭扬声器
        	out     	ppi_pb_reg,al		; write the new value

        	mov    	 cx,0100h
	call	delay_15us		; delay after the note
        
        	jmp     .loop			; play the next note
.exit:
	ret

;=========================================================================
; beep - Play a beep sound
; Input:
;	BL - duration in 0.1 second
; Output:
;	BL = 0
;-------------------------------------------------------------------------
beep:
	push	ax
	mov	al,0B6h			; set PIC channel 2 to mode 3
	out	pit_ctl_reg,al
	mov	ax,pic_freq/700			; approximately 200 Hz
	out	pit_ch2_reg,al		; load divisor's low byte to PIC
	mov	al,ah
	out	pit_ch2_reg,al		; load divisor's high byte to PIC
;	in	al,ppi_pb_reg		; read current value of PORT B 读取端口已删除，无需读取
	MOV	al,03h			; turn on the speaker  直接赋值D0=1，因为其他位已删除
	out	ppi_pb_reg,al		; write the new value
.loop:
	mov	cx,6666			; 0.1 second delay
	call	delay_15us
	call	delay_15us
	dec	bl
	jnz	.loop
	mov	al,0			; turn off the speaker
	out	ppi_pb_reg,al		; write the new value
	pop	ax
	ret



