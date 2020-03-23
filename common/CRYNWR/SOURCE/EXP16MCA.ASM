;keep these in this order.
pos_reg_2	db	?
pos_reg_3	db	?
pos_reg_4	db	?
pos_reg_5	db	?

write_pos_to_eeprom:
;the MCA adapter doesn't use softset.  Instead, the driver copies the POS
;registers to the EEPROM, then life goes on as usual.
	assume	ds:code
	movseg	es,ds
	mov	di,offset pos_reg_2
	mov	dx,102h
	mov	cx,4
wpte_1:
	in	al,dx
	stosb
	inc	dx
	loop	wpte_1

	call	disable_slot

; Get the board BASE IO from POS configuration.

	mov	bl, 15
	sub	bl, pos_reg_3
	and	bx, 0fh
	shl	bx, 1
	mov	bp, io_addresses[bx]

; The 82586 must be reset to reliably read and write the EEPROM.
	call	reset_586

; First build EEPROM word 0 from POS values into AX.
; Read EEPROM value, and mask off fields we will modify.
	xor	ax, ax
	call	read_eeprom
	and	ax, 0c20h

; Set BASE I/O value (bits 0 - 3).
	mov	cl, pos_reg_3
	and	cl, 0fh
	or	al, cl

; Set BOOT ROM (FLASH) enable (bit 4).
	mov	cl, pos_reg_2
	shl	cl, 1
	and	cl, 10h
	or	al, cl

; Set BOOT ROM (FLASH) base segment (bits 6 - 9).
	mov	cl, pos_reg_2
	shl	cx, 1
	shl	cx, 1
	and	cx, 03c0h
	or	ax, cx

; Set connection type (AUI/OTHER) bit 12.
	mov	ch, pos_reg_2
	shl	ch, 1
	shl	ch, 1
	and	ch, 10h
	or	ah, ch

; Set IRQ selection (bits 13 - 15).
	mov	ch, pos_reg_3
	shl	ch, 1
	and	ch, 0e0h
	or	ah, ch

; Write new EEPROM word 0.
	mov	bx, ax
	xor	ax, ax
	call	write_eeprom
	jc	copy_pos_to_eeprom_error_j

; Now build EEPROM word 1 from POS values into AX.
; Read EEPROM value, and mask off fields we will modify.
	mov	ax, 1
	call	read_eeprom
	and	ax, 0ff13h

; Set Memory Base address Adjust value (bits 2 - 3).
	mov	cl, pos_reg_5
	and	cl, 0ch
	or	al, cl

; Set Memory megabyte address selection (bits 5 - 6).
	mov	ch, pos_reg_5
	mov	cl, 5
	shl	ch, cl
	and	ch, 060h
	or	al, ch

; Set auto-connection enable bit (bit 7).
	mov	ch, pos_reg_2
	mov	cl, 6
	shl	ch, cl
	and	ch, 80h
	or	al, ch

; Write new EEPROM word 1.
	mov	bx, ax
	mov	ax, 1
	call	write_eeprom
copy_pos_to_eeprom_error_j:
	jc	copy_pos_to_eeprom_error

; Now build EEPROM word 5 from POS values into AX.
; Read EEPROM value, and mask off fields we will modify. 
	mov	ax, 5
	call	read_eeprom
	and	ax, 0fff9h

; Now set the Boot ROM selection.
	mov	ch, pos_reg_5
	mov	cl, 3
	shr	ch, cl
	and	ch, 06h
	or	al, ch

; Write new EEPROM word 5.
	mov	bx, ax
	mov	ax, 5
	call	write_eeprom
	jc	copy_pos_to_eeprom_error

; Now build EEPROM word 6 from POS values into AX.
; Read EEPROM value, and mask off fields we will modify. 
	mov	ax, 6
	call	read_eeprom
	and	ax, 0ff00h

; Set mapping information for segments C and D (bits 0 - 7).
	mov	al, pos_reg_4

; Write new EEPROM word 6.
	mov	bx, ax
	mov	ax, 6
	call	write_eeprom
	jc	copy_pos_to_eeprom_error

; Now recompute EEPROM checksum and save it.
; First call routine that sums EEPROM values.  We want the sum of all
; values except the checksum which is the last word in the eeprom.
	mov	cx, 3fh
	call	check_eeprom

; Calculate word value that if summed with what we have will result
; as 0BABAH.
	mov	ax, 0babah
	sub	ax, bx

; Write new checksum value in AX to the last word in the EEPROM.
	mov	bx, ax
	mov	ax, 3fh
	call	write_eeprom

copy_pos_to_eeprom_error:

	ret

