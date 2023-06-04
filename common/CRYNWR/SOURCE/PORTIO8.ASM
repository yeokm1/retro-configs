	; Valid transfer modes
	TOSHIBA_MODE	EQU		4
	BI_DIR_MODE		EQU		2
	NIBBLE_MODE		EQU		1
	transf_mode		db		1 ; Specifies the transfer mode
	MAX_TICKS	EQU		10h	; Time to wait for a timeout in p_port handshake
	; #### value probably too conservative, minimum value for MAX_TICKS ?
	LPT_CTL_IRQENABLE	EQU	10h ; Bit to enable the printer to interrupt
	
	Word_To_Write		dw	?
    First_Byte_Read		db	?
    public Input_Byte
    Input_Byte			db	?
	public Nibble_Read
	Nibble_Read			db	?
	printer_no			db	0	; Which of the 3 printers has the port
	instrg_routine		dw	offset instrg_nibble	; Routine to read bytes
	public	readbyte_routine
   	readbyte_routine	dw	offset readbyte_nibble ; Routine to get a byte
	Saved_Control		db	?	; Original values of the LPT Control port
	Saved_Data			db	?	; Original values of the LPT Data port
	orig_mask			db	?	; Original master 8259 interrupt mask
	public	ticks
	ticks				dw	?	; Used by the watchdog timer
	store_status		dw	?	; Used in check for transfer mode
	toshiba_msg		db	"Toshiba 8-bit input capability",CR,LF,'$'
	bi_dir_msg		db	"Printer port has full 8-bit input capability",CR,LF,'$'
	pea_strobe_rd_begin	db	05h	; PEA_STROBE_READ_BEGIN
	pea_strobe_rd_end	db	04h	; PEA_STROBE_READ_END
	public sel_rd_8005_reg
	sel_rd_8005_reg		db	70h OR WFI_STATE	; SEL_READ_8005_REG


		public 	let_in_ether
let_in_ether	PROC	NEAR
; Enable the printer portion of the PEA - allowing ethernet interrupts.
; If this routine is not called then the PEA will not interrupt.
; Routine is basically that of the disable_ether macro in RAVEN.MAC
; Order is important, IRQ should be enabled first
        push    ax                      ; Only ax and dx will be used
		push	dx
        mov     dx, CS:LPT_Address.controlreg
        mov     al, cs:Saved_Control    ; control bits to restore
        or      al, LPT_CTL_IRQENABLE   ; Must be set to allow ints
        out     dx, al                  ; Set it back
        mov     al, PEA_ENABLE_PRINTER  ; set appropriate bits to disable
	    write_pea_cmd_register_disable  ; do it
        mov     al, CS:Saved_Data       ; Restore data register contents
        mov     dx, CS:LPT_Address.datareg
        out     dx, al
		pop		dx
        pop     ax
		ret
let_in_ether ENDP

		public	store_curr_values
store_curr_values	PROC	NEAR
; Checks to see if the printer is in the middle of a printing a character
; and lets it finish if so.
; Stores the current values of the control and data registers.
        mov     dx, CS:LPT_Address.controlreg
        in      al, dx                  ; Save LPT Control port bits
        test    al, PRINTING            ; Was printer printing?
        jz      not_printing            ; No
        and     al, FINISH_PRINT        ; Finish the current byte
        out     dx, al                  
not_printing:
        mov     CS:Saved_Control, al
        and     al, DEFAULT_CONTROL     ; Default bits required to proceed
        ;mov     CS:Saved_Control, al
        mov     dx, CS:LPT_Address.datareg
        in      al, dx                  ; Save data register contents
        mov     CS:Saved_Data, al
        ret
store_curr_values	ENDP

restore_orig_value	PROC	NEAR
; Restore the original control and data values for the printer port
        mov     dx, CS:LPT_Address.controlreg
		mov		al, CS:Saved_Control
        out		dx, al
        mov     dx, CS:LPT_Address.datareg
		mov		al, CS:Saved_Data
        out		dx, al
		ret
restore_orig_value	ENDP

enable_printer_irq	PROC	NEAR
; Turns on the IRQ enable for the printer port
		push	ax
		push	dx
		mov		dx, cs:LPT_Address.controlreg
		in		al, dx
        or      al, LPT_CTL_IRQENABLE
		out		dx, al
		mov		cs:Saved_Control, al
		pop		dx
		pop		ax
enable_printer_irq	ENDP

; Get status of the PEA
		public	get_pea_status
get_pea_status	PROC	NEAR
        selectreg_read PEA_BOARD_STATUS_REG, 0
        call	cs:readbyte_routine		; read a byte
        xor     ah, ah                  ; clear out upper byte of ax
		ret
get_pea_status	ENDP

;; Select the specified register on the 8005 for writing
;;      On Entry: Reg al = 8005 register (A0-A3)
;;                bytesel = 0 or 1 to select which byte to write
;;
;; Selects the 8005 register at which subsequent I/O is directed.
;;
selectreg_write_al  macro   bytesel
        or      al, SEL_WRITE_8005_REG OR bytesel
        mov     dx, cs:LPT_Address.datareg
        out     dx, al
        strobe_cmd
        endm

;input a word from IO port
inw	macro
		call	inw_proc			; Subroutine avoids big code
endm

		public inw_proc
inw_proc	PROC	NEAR
;;
;;     Input a word from the 8005 via the parallel port -
;;        DL = contains the 8005 register selected.
;;
        push    dx                      ; Save dl (8005 register)
		mov		ax,dx						; Get reister to read into al
        selectreg_read_al 0             ; Select to read first byte of register
        call	cs:readbyte_routine				; get a byte
        mov     cs:First_Byte_Read, al     ;
        pop     ax                      ; Get 8005 register
        push     ax                     ; Save again
        selectreg_read_al  1            ; Select to read next byte of register
        call	cs:readbyte_routine        ; get the other byte (in AL)
        mov     ah, cs:First_Byte_Read     ; to swap the byte order
		xchg	ah, al					; Byte now in correct order
; xchg could be removed if byte read in different order
; but necessary for WINDOW register reads.
		pop		dx						; recover original contents of dx
		ret
inw_proc	ENDP

;
; Read a byte (two nibbles) from 8005 via the LPT data port -
;      On Exit:  AL and Input_Byte = byte read from LPT data port.
readbyte_nibble	PROC NEAR
        strobe_read_begin               ; start strobe to read
        dec     dx                      ; Set data port
        dec     dx                      ;
        mov     al, HI_NIBBLE           ; Select the hi nibble
        out     dx, al                  ; Go do it
        wait_ack			            ; Wait for acknowledge to indicate done
        in      al, dx                  ; Get the nibble (this is the hi-nibble)
        mov     CS:Nibble_Read, al         ; Save it away
        mov     al, LO_NIBBLE           ; Select the low nibble-bit 7 must be 0
        dec     dx                      ; Get to the data reg
        out     dx, al                  ; Selected
        inc     dx                      ; Get to status reg
        in      al, dx                  ; Get next nibble (low nibble)
        mov     ah, CS:Nibble_Read         ; Get first nibble (high nibble)
        push    cx                      ; Save reg
        push    bx                      ; Save reg
        ; High nibble massage
        mov     bh, ah                  ; Save for now
        and     bh, 80h                 ; Errant bit
        shl     ah, 1                   ; 3 contiguous bits of high nibble
        or      ah, bh                  ; Bits 7-4
        and     ah, 0f0h                ; Clear other bits
        ; Low nibble massage
        mov     bl, al                  ; Save for now
        and     bl, 80h                 ; Errant bit
        mov     cl, 4                   ; To allow 8086 operation
        shr     bl, cl                  ; Shift into correct position
        mov     cl, 3                   ; 8086 operation
        shr     al, cl                  ; 3 contiguous bits of low nibble
        or      al, bl                  ; Bits 0-4
        and     al, 0fh                 ; Clear other bits
        or      al, ah                  ; Put them together
        pop     bx                      ; Restore reg
        pop     cx                      ; Restore reg
        mov     cs:Input_Byte, al          ; Save byte
        strobe_read_end                 ; return to known state
        wait_ack_done					; Wait for ACK to disappear
        mov     al, cs:Input_Byte          ; return in al
        ret
readbyte_nibble	ENDP

; Read a byte (bidirectional) from 8005 via the LPT data port -
;      On Exit:  AL and Input_Byte = byte read from LPT data port.
readbyte_bi_dir	PROC	NEAR
        strobe_read_begin               ; start strobe to read
        wait_ack						; Wait for acknowledge to indicate done
        mov     dx, cs:LPT_Address.datareg ;
        in      al, dx                  ; read the byte
        mov     cs:Input_Byte, al
        strobe_read_end                 ; return to known state
        wait_ack_done					; Wait for ACK to disappear
        mov     al, cs:Input_Byte          ; return in al
		ret
readbyte_bi_dir	ENDP

;write a byte to an IO port
outb	macro			; Subroutine avoids big code
if INTERFACE EQ P_PORT
	call	outb_proc
else
	out	dx, al
endif
endm

		public	outb_proc
outb_proc	PROC	NEAR
;;     Write a byte to the parallel port.
;;     Reg al = byte to write.
;;     Reg dl = 8005 register
        push    dx                      ; Save dl (8005 register)
        mov     cs:Word_To_Write, ax		; NOTE all 16 bits saved
		mov		ax,dx			; Get 8005 register into al
        selectreg_write_al 0    ; and select the 8005 register (first byte)
        mov     ax, cs:Word_To_Write
        writebyte exit_addr     ; write al (the ah is not written)
		mov     ax, cs:Word_To_Write ; Resore AX value
		pop		dx				; Restore original dx
		ret
outb_proc	ENDP

;write a word to an IO port
outw	macro			; Subroutine avoids big code
		call	outw_proc
endm

		public outw_proc
outw_proc	PROC	NEAR
;;     Write a word to the parallel port.
;;     Reg ax = word to write.
;;     Reg dl = 8005 register
        push    dx                      ; Save dl (8005 register)
        mov     cs:Word_To_Write, ax
		mov		ax,dx			; Get 8005 register into al
        selectreg_write_al 0    ; and select the 8005 register (first byte)
        mov     ax, cs:Word_To_Write
        writebyte exit_addr     ; write al
		pop		ax				; Get the 8005 register again
		push	ax				; Save again
        selectreg_write_al 1    ; and select the 8005 register (next byte)
        mov     ax, cs:Word_To_Write
        xchg    ah, al          ; get next byte
        writebyte exit_addr     ; write the next byte
        mov     ax, cs:Word_To_Write ; Resore AX value
		pop		dx				; Restore original dx
		ret
outw_proc	ENDP

test_p_port	PROC	NEAR
; Checks to see if the parallel port does the handshake expected of the
; parallel port. Returns with carry set if handshake failed.
		call	store_curr_values	; Store what is currently at the port
		mov		dx,	CONFIG2
		mov		ax, RESET_BIT
        mov     Word_To_Write, ax
		mov		ax, dx				; Get 8005 register into al
        or      al, SEL_WRITE_8005_REG
        mov     dx, cs:LPT_Address.datareg
        out     dx, al
		strobe_cmd_begin
		strobe_cmd_end
		dec		dx
		in		al, dx
		test	al, BUSY_HIGH
		jz		ok_1
		call	watch_dog
		jc		ret_1
ok_1:
        mov     ax, Word_To_Write
        mov     dx, cs:LPT_Address.datareg
        out     dx, al                  ; write the byte
        
		mov     dx, cs:LPT_Address.controlreg
        mov     al, PEA_STROBE_WRITE_BEGIN
        out     dx, al
        mov     dx, CS:LPT_Address.statusreg
        in      al, dx                  ; Read value in
        test    al, PEA_ACK             ; operation complete?
        jz		ok_2
		call	watch_ack_low
		jc		ret_1
ok_2:     
		mov     dx, cs:LPT_Address.controlreg
        mov     al, PEA_STROBE_WRITE_END
        out     dx, al
        mov     dx, CS:LPT_Address.statusreg
        in      al, dx                  ; Read value in
        test    al, PEA_ACK             ; operation complete?
        jnz     ret_1
		call	watch_ack_high
		jnc		ret_1
		call	restore_orig_value		; Setup port as before
		stc
ret_1:
		ret
test_p_port	ENDP


find_p_port PROC NEAR
; Interrupt masking assumes that we deal only with an IRQ7(default) or an IRQ5
		in		al, 21h				; Get master mask
		mov		orig_mask, al		; Store for later
		cmp		int_no, 5			; Only check for IRQ5
		jnz		int7				; Otherise assume IRQ7
		or		al, 020h			; Mask off IRQ5
		jmp		set_mask
int7:	or		al, 080h			; Mask off IRQ7
set_mask:
		out		dx, al				; Tell the PIC chip
		mov		bh, 00h				; bx = pointer to printer address array
try_next_printer:
		mov		bl, printer_no
		inc		printer_no			; Setup next printer
		cmp		printer_no, 3		; Tried all three printers
		jg		no_p_port			; No more to try
		shl		bx, 1						; Make bx be a word offset
		mov		si, offset printer_address	; Start of the printer address array
		mov		ax, [si+bx]					; Get the printer address into ax
		mov		LPT_Address.datareg, ax		; Setup the three addresses
		inc		ax
		mov		LPT_Address.statusreg, ax
		inc		ax
		mov		LPT_Address.controlreg, ax
		call	test_p_port			; See if anything is there
		jc		try_next_printer	; did not pass handshake test
; Found a p_port, enabling of its interrupt mask occurs later
; For now must proceed with that printer's interrupts disabled.
		ret
no_p_port:
		mov		al, orig_mask		; Get the original mask
		out		21h, al				; Tell the PIC chip
		stc
		ret
find_p_port ENDP


;this code is exactly like the "rep insb" instruction.  It works even if
;you've got an 8088.

	extrn	is_186: byte		;=0 if 808[68], =1 if 80[123]86.

repinsb:
	cmp	is_186,0		; Can we use rep insb?
	je	repinsb_1		; no - have to do it slowly.
	.286
	rep	insb
	.8086
	jmp	short icnteven
repinsb_1:
; If buffer doesn't begin on a word boundary, get the first byte
	test	di,1			; if(buf & 1){
	jz	ibufeven		;
	in	al,dx			; al = in(dx);
	stosb				; *di++ = al
	dec	cx			; cx--;
ibufeven:
	shr	cx,1			; cx = cnt >> 1; (convert to word count)
; Do the bulk of the buffer, a word at a time
	jcxz	inobuf			; if(cx != 0){
rb:	in	al,dx			; do { al = in(dx);
	mov	ah,al
	in	al,dx			; ah = in(dx);
	xchg	al,ah
	stosw				; *si++ = ax; (di is word pointer)
	loop	rb			; } while(--cx != 0);
; now check for odd trailing byte
inobuf:
	jnc	icnteven
	in	al,dx
	stosb				; *di++ = al
icnteven:
	ret


;this code is exactly like the "rep outsb" instruction.  It works even if
;you've got an 8088.
repoutsb:
	cmp	is_186,0		; Can we use rep outsb?
	je	out86			; no - have to do it slowly.
	.286
	rep	outsb
	.8086
	jmp	short ocnteven
out86:
	test	si,1			; (buf & 1) ?
	jz	obufeven		; no
	lodsb				; al = *si++;
	out	dx,al			; out(dx,al);
	dec	cx			; cx--;
obufeven:
	shr	cx,1			; cx = cnt >> 1; (convert to word count)
; Do the bulk of the buffer, a word at a time
	jcxz	onobuf			; if(cx != 0){
xb:	lodsw				; do { ax = *si++; (si is word pointer)
	out	dx,al			; out(dx,lowbyte(ax));
	mov	al,ah
	out	dx,al			; out(dx,hibyte(ax));
	loop	xb			; } while(--cx != 0); }
; now check for odd trailing byte
onobuf:
	jnc	ocnteven
	lodsb				;   out(dx,*si++);
	out	dx,al
ocnteven:
	ret

;------------------------------------------------------------------
; Read in a sequence of bytes - from the register specified in DL
;------------------------------------------------------------------
		;extrn	instrg_routine: word	; Routine to perform the read
										; either instrg_bi_dir or instrg_nibble
		public	repins_dl
repins_dl	PROC	NEAR
		push	dx
		mov		al, dl	; Get register into al
        mov     dx, cs:LPT_Address.datareg ; Control port address
;       or		al, SEL_READ_8005_REG
        or		al, sel_rd_8005_reg
        out     dx, al
        strobe_cmd 		; Strobe the command out
		call	cs:instrg_routine
		pop		dx
		ret
repins_dl	ENDP

;------------------------------------------------------------------
; Perform and instring type of operation - full 8 bit input
;------------------------------------------------------------------
instrg_bi_dir PROC NEAR
        jcxz    ibd3
        mov     dx, CS:LPT_Address.controlreg ; Control port address
;
; Read the next byte
; DX = LPT control port
;
ibd1:
;       mov     al, PEA_STROBE_READ_BEGIN ; Strobe read begin
        mov     al, CS:pea_strobe_rd_begin; Strobe read begin
        out     dx, al                    ; To control port

; Wait for the ACK to see valid data
;
        dec     dx                      ; Status port address
ibd2:
        in      al, dx                  ; Read value in
        test    al, PEA_ACK             ; operation complete?
        jnz     ibd2                    ; Check forever
        dec     dx                      ; Get data port
        in      al, dx                  ; read the byte - it is ready
        stosb                           ; save the byte
; strobe read end
        inc     dx                      ; Back to control register
        inc     dx                      ;
;       mov     al, PEA_STROBE_READ_END
        mov     al, CS:pea_strobe_rd_end
        out     dx, al
        wait_ack_done
        inc     dx                      ; To control register
        loop    ibd1                      ; Get the next byte
ibd3:
        ret
instrg_bi_dir	ENDP

;------------------------------------------------------------------
; Perform and instring type of operation - 4 bit input
; Registers used: ax, cx, dx
;------------------------------------------------------------------
instrg_nibble	PROC	NEAR
        jcxz	inib3
        push    bx                      ; Save register
        push    si                      ; Save register
							; #### probably no longer need to save SI
        mov     dx, CS:LPT_Address.controlreg ; Control port address
; Read the next byte
inib1:
;       mov     al, PEA_STROBE_READ_BEGIN ; Strobe read begin
        mov     al, CS:pea_strobe_rd_begin	  ; Strobe read begin
        out     dx, al                    ; To control port

; Select the hi nibble
        dec     dx                      ; Set data port
        dec     dx                      ;
		mov     al, HI_NIBBLE           ; Select the hi nibble
        out     dx, al                  ; Go do it

; Wait for the ACK to see valid data
        inc     dx                      ; Status port address
inib2:
        in      al, dx					; Read value in
        test    al, PEA_ACK				; operation complete?
        jnz     inib2					; Check forever

; status port is setup
        in      al, dx                  ; Get the nibble (this is the hi-nibble)
        mov     CS:Nibble_Read, al		; Save it away
        mov     al, LO_NIBBLE           ; Select the low nibble-bit 7 must be 0
        dec     dx                      ; Get to the data reg
        out     dx, al                  ; Selected
        inc     dx                      ; Get to status reg
        in      al, dx                  ; Get next nibble (low nibble)
        mov     ah, CS:Nibble_Read      ; Get first nibble (high nibble)
        push    cx                      ; Save reg

        ; High nibble massage
        mov     bh, ah                  ; Save for now
        and     bh, 80h                 ; Errant bit
        shl     ah, 1                   ; 3 contiguous bits of high nibble
        or      ah, bh                  ; Bits 7-4
        and     ah, 0f0h                ; Clear other bits
        ; Low nibble massage
        mov     bl, al                  ; Save for now
        and     bl, 80h                 ; Errant bit
        mov     cl, 4                   ; For 8086 operation
        shr     bl, cl					; Shift into correct position
        mov     cl, 3
        shr     al, cl                  ; 3 contiguous bits of low nibble
        or      al, bl                  ; Bits 0-4
        and     al, 0fh                 ; Clear other bits
        
		or      al, ah                  ; Put nibbles together
        pop     cx                      ; Restore reg
        stosb                           ; save the byte

; strobe read end
        inc     dx                      ; Back to control register
;       mov     al, PEA_STROBE_READ_END
        mov     al, pea_strobe_rd_end
        out     dx, al
        wait_ack_done
        inc     dx                      ; To control register
        loop    inib1                      ; Get the next byte

        pop     si                      ; Restore
        pop     bx                      ; Restore
inib3:
        ret
instrg_nibble	ENDP

set_toshiba_routines	PROC NEAR
		mov		instrg_routine, offset instrg_bi_dir
		mov		readbyte_routine, offset readbyte_bi_dir
		mov		pea_strobe_rd_begin, 0E5h
		mov		pea_strobe_rd_end, 0E4h
		mov		sel_rd_8005_reg, 30h OR WFI_STATE
		ret
set_toshiba_routines	ENDP

set_bi_dir_routines	PROC NEAR
		mov		instrg_routine, offset instrg_bi_dir
		mov		readbyte_routine, offset readbyte_bi_dir
		mov		pea_strobe_rd_begin, 25h
		mov		pea_strobe_rd_end, 24h
		mov		sel_rd_8005_reg, 30h OR WFI_STATE
		ret
set_bi_dir_routines	ENDP

set_nibble_routines	PROC NEAR
		mov		instrg_routine, offset instrg_nibble
		mov		readbyte_routine, offset readbyte_nibble
		mov		pea_strobe_rd_begin, 05h
		mov		pea_strobe_rd_end, 04h
		mov		sel_rd_8005_reg, 70h OR WFI_STATE
		ret
set_nibble_routines	ENDP


set_transfer_mode	PROC NEAR
; Set up transfer mode for inputs from the port
; STAT register is first read in nibble mode and then compared with vale read
; using other modes.  If any agree then we have found a faster transfer mode.
		loadport
		setport	STAT
		inw								; Read status register
		mov		store_status, ax		; Store for a comparison
		call	set_bi_dir_routines		; Try the 8-bit routines
		loadport
		setport	STAT
		inw								; Read status register
		cmp		ax, store_status		; Same value as before ?
		jne		try_toshiba				; Try another mode
		mov		dx, offset bi_dir_msg	; Announce what we found
		jmp		announce_it
try_toshiba:
		call	set_toshiba_routines	; Try the toshiba routines
		loadport
		setport	STAT
		inw								; Read status register
		cmp		ax, store_status		; Same value as before ?
		jne		use_nibble_routines		; No - must use nibble mode
		mov		dx, offset toshiba_msg	; Announce Toshiba mode
announce_it:
		mov		ah, 9					;     and leave
		int		21h
		ret
use_nibble_routines:
		call	set_nibble_routines
		ret
set_transfer_mode	ENDP


;------------------------------------------------------------------
; Write in a sequence of bytes - to the register specified in DL
;------------------------------------------------------------------
		public	repouts_dl
repouts_dl		PROC	NEAR
		push	dx
		mov		al, dl	; Get register into al
        mov     dx, cs:LPT_Address.datareg   ; Select LPT data port
        or      al, SEL_WRITE_8005_REG
        out     dx, al                  ; Write to the data port
        strobe_cmd						; Strobe the command out
        OUTSTRG
		pop		dx
        ret
repouts_dl	ENDP


		public get_ticks
get_ticks PROC NEAR
		; Result returned in cx
		push	ax
		push	dx
		mov		ah, 0			 ; Real time clock   ah=func 00h
		int		1Ah				 ;  get system timer count cx,dx
		push	dx
		pop		cx
		pop		dx
		pop		ax
		ret
get_ticks ENDP

watch_dog PROC NEAR
		push	cx
		call	get_ticks
		mov		cs:ticks, cx
		pop		cx
try_again:
		in		al, dx
		test	al, 80h
		jz		ret_ok
		call	get_ticks
		sub		cx, cs:ticks
 		cmp		cx, MAX_TICKS
		jl		try_again
		stc
ret_ok:
		ret
watch_dog ENDP

watch_ack_low  PROC NEAR
; Needs to see the PEA_ACK bit go low
; Times out and returns carry set if this does not happen
		push	cx					; get_ticks uses cx
		call	get_ticks			; Current 'time'
		mov		cs:ticks, cx		; Store for later comparisons
		pop		cx					; Restore
try_again_1:
		in		al, dx				; Get the printer status
        test    al, PEA_ACK			; Seen what we want ?
		jz		ret_ok_1			; Yes - so go and return
		call	get_ticks			; Have we waited long enough ?
		sub		cx, cs:ticks
 		cmp		cx, MAX_TICKS
		jl		try_again_1			; Still time to try again
		stc
ret_ok_1:
		ret
watch_ack_low  ENDP

watch_ack_high  PROC NEAR
; Needs to see the PEA_ACK bit go high
; Times out and returns carry set if this does not happen
; Virtually identical to the above routine - probably should be combined.
		push	cx
		call	get_ticks
		mov		cs:ticks, cx
		pop		cx
try_again_2:
		in		al, dx
        test    al, PEA_ACK
		jnz		ret_ok_2			; Only thing different from above
		call	get_ticks
		sub		cx, cs:ticks
 		cmp		cx, MAX_TICKS
		jl		try_again_2
		stc
ret_ok_2:
		ret
watch_ack_high  ENDP


get_eeprom_data PROC NEAR
		; Called with :
		; cx = number of bytes to read
		; bx = starting offset in the EEPROM
		; di = buffer to place the data
		mov	al,0
		mov	dx,LPT_Address.datareg
		out	dx,al

		mov	ax, bx			; Offset into the EEPROM
get_next_eeprom_byte:
		push	cx			; No. left to read
		push	ax			; Address of next byte in eeprom

		mov	al,0D0h
		mov	dx,LPT_Address.datareg
		out	dx,al

		strobe_cmd_begin
		strobe_cmd_end

		dec	dx
		in	al,dx
		test	al,BUSY_HIGH
		jz	eeprom_ok
		call	watch_dog
		jnc		eeprom_ok
		pop		ax			; Clean up the stack
		pop		cx
		ret

;Select the EEPROM for reading
eeprom_ok:
		mov	al,0
		writebyte_eeprom
		mov	al,1
		writebyte_eeprom
		mov	al,1
		writebyte_eeprom
		mov	al,0
		writebyte_eeprom

		pop	ax		; Next eprom address
		inc	ax
		push	ax	; Sotore next value
		dec	ax

write_eeprom_address:
		; Called with AX containing the address
		mov	cx,6			; number of address bits in the address
next_add_bit:
		push	ax
		push	cx
		dec	cx
		shr	ax,cl
		writebyte_eeprom
		pop	cx
		pop	ax
		loop	next_add_bit

		mov	dx,LPT_Address.datareg
		mov	al,0
		out	dx,al

		xor	bx,bx			; Byte will be assembled in bx
		mov	cx,10h			; Number of bits to fetch

get_next_bit:
		next_eeprom_bit
		dec	cx				; Decrement the count
		shl	ax,cl			; Shift w/zeros fill
		inc	cx
		or	bx,ax
		loop	get_next_bit
		xchg	bh,bl
		mov	[di], bx		; store the byte
		add	di,2			; advance the buffer pointer

		mov	al,80h
		mov	dx,LPT_Address.datareg
		out	dx,al
		strobe_cmd_begin
		strobe_cmd_end

		pop	ax
		pop	cx
		dec	cx
		jcxz	no_more
		jmp	get_next_eeprom_byte
no_more:
		retn
get_eeprom_data ENDP



		public	our_17h_isr
; Required as their interrupt disables the printers IRQ
our_17h_isr	PROC	NEAR
		pushf					; remember they return with an iret
		extrn	their_17h_isr : dword
		call	CS:their_17h_isr
; Quicker to always enable the IRQ even if int 17h called for other printers
		push	dx
		push	ax
        mov     dx, CS:LPT_Address.controlreg
        mov     al, cs:Saved_Control    ; control bits to restore
        or      al, LPT_CTL_IRQENABLE   ; Must be set to allow ints
        out     dx, al                  ; Set it back
		pop		ax
		pop		dx
		iret
our_17h_isr	ENDP
