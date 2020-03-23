

DM9801_E3E4:
	mov	eax, DM9801PhyID
	cmp	al, 00h
	ja	DM9801_E4E5E6
	;Read DM9801 Peak Level and Noise Level Register
	;-----------------------------------------------
	mov	bx, DM9801_PEAK_NOISE
	call	PhyWordRead			;AX = Returned Value

	;Init DM9801 Noise Ceiling and Noise Floor Register
	;(set Noise Ceiling = 0F0h
	; set Noise Floor   = Reg 24 Noise Level + 3)
	;--------------------------------------------------
	mov	ah, 0F0h
;;	  add	  al, 3
	add	al, 0dh
	mov	bx, DM9801_NOISE_FLOOR
	mov	si, ax				;SI = Written PHY Data (1 word)
	call	PhyWordWrite

	jmp	SetPNAExit
;; stone 05/07/2001 Check DM9801 E3E4E5E6 IC to modify PHY register 17.
;;----------------------------------------------------------------------------
DM9801_E4E5E6:
	mov	bx, 11h 			 ;Read PHY register 17.
	call	PhyWordRead			 ;AX = Returned Value.
	or	ax, 08h 			 ;Or 08h to PHY register 17.

	mov	bx, 11h
	mov	si, ax
	call	PhyWordWrite

	mov	bx, DM9801_NOISE_FLOOR
	call	PhyWordRead			;AX = Returned Value
	mov	PHY_24_L, ax
	shr	PHY_24_L, 8
	shl	PHY_24_L, 8

	mov	bx, DM9801_PEAK_NOISE
	call	PhyWordRead			;AX = Returned Value
	shl	ax, 8
	shr	ax, 8
	or	PHY_24_L, ax


	;Init DM9801 Noise Ceiling and Noise Floor Register
	; set Noise Floor   = Reg 24 Noise Level + 3)
	;--------------------------------------------------
	mov	bx, DM9801_NOISE_FLOOR
	mov	si, PHY_24_L			      ;SI = Written PHY Data (1 word)
	add	si, 0dh
	call	PhyWordWrite
