
;--------------------------------------------------------------------+
; Name : skip_blanks
;
; Description: Pointer to 1st that it is not space charater.
;
; Enter :
;       DS:SI -> point to string.
;
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+
        public  skip_blanks
skip_blanks:
        lodsb                           ;skip blanks.
        cmp     al,' '
        je      skip_blanks
        cmp     al, 09h                 ;; HT = 09h(TAB)
        je      skip_blanks
        dec     si
        ret

;--------------------------------------------------------------------+
; Name : get_number
;
; Description: Get a hex number, skipping leading blanks.
;
; Enter :
;       SI -> string of digits.
;       DI -> DWORD to store th number in.
;
; Return :
;       Carray flag set : There are no digits, [di] in not modified.
;       Carray flag reset : BX:CX = number, and store BX:CX at [di].
;
; Destroied registers :
;
;---------------------------------------------------------------------+
        public  get_number
get_number:
        mov     bp,10                   ;we default to 10.
        jmp     short get_number_0

        public  get_hex
get_hex:
        mov     bp,16

get_number_0:
        call    skip_blanks
        call    get_digit               ;is there really a number here?
                                        ;; Return AL with hex.
        jc      get_number_3            ;; Not digital
        xor     ah,ah
        cmp     ax,bp                   ;larger than our base?
        jae     get_number_3            ;yes.
        or      al,al                   ;Does the number begin with zero?
        jne     get_number_4            ;no.
        mov     bp,8                    ;yes - they want octal.
get_number_4:
        xor     cx,cx                   ;get a hex number.
        xor     bx,bx
get_number_1:
        lodsb
        cmp     al,'x'                  ;did they really want hex?
        je      get_number_5            ;yes.
        cmp     al,'X'                  ;did they really want hex?
        je      get_number_5            ;yes.
        call    get_digit               ;convert a character into an int.
        jc      get_number_2            ;not a digit (neither hex nor dec).
        xor     ah,ah
        cmp     ax,bp                   ;larger than our base?
        jae     get_number_2            ;yes.

        push    ax                      ;save the new digit.

        mov     ax,bp                   ;multiply the low word by ten.
        mul     cx
        mov     cx,ax                   ;keep the low word.

        push    dx                      ;save the high word for later.

        mov     ax,bp
        mul     bx
        mov     bx,ax                   ;we keep only the low word (which is our high word)

        pop     dx

        add     bx,dx                   ;add the high result from earlier.

        pop     ax                      ;get the new digit back.

        add     cx,ax                   ;add the new digit in.
        adc     bx,0
        jmp     get_number_1
get_number_5:
        mov     bp,16                   ;change the base to hex.
        jmp     get_number_1
get_number_2:           ;; Store number to DI
        dec     si
        mov     [di],cx                 ;store the parsed number.
        mov     [di+2],bx
        clc
        jmp     short get_number_6
get_number_3:
        cmp     al,'?'                  ;did they ask for the default?
        stc
        jne     get_number_6            ;no, return cy.
        add     si,2                    ;skip past the question mark.
        mov     cx,-1
        mov     bx,-1
        jmp     get_number_2            ;and return the -1.
get_number_6:
        ret

;--------------------------------------------------------------------+
; Name : get_digit
;
; Description: Decide digit number.
;
; Enter :
;       carray flag reset : AL = digit.
;       carray flag set   : Not a digit.
;
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+
        public  get_digit

get_digit:
        cmp     al,'0'                  ;decimal digit?
        jb      get_digit_1             ;no.
        cmp     al,'9'                  ;. .?
        ja      get_digit_2             ;no.
        sub     al,'0'
        clc
        ret

get_digit_2:                            ;; > 9
        cmp     al,'a'                  ;hex digit?
        jb      get_digit_3
        cmp     al,'f'                  ;hex digit?
        ja      get_digit_3
        sub     al,'a'-10
        clc
        ret

get_digit_3:
        cmp     al,'A'                  ;hex digit?
        jb      get_digit_1
        cmp     al,'F'                  ;hex digit?
        ja      get_digit_1
        sub     al,'A'-10
        clc
        ret

get_digit_1:                            ;; Not decimal digit
        stc
        ret

;--------------------------------------------------------------------+
; Name : print_number
;
; Description: Print the name and the decimal number.
;
; Enter :
;       DX -> dollar terminated name of number.
;       DI -> printed number (DWORD).
;
; Return : The cursor advanced to next line.
;
; Destroied registers :
;
;---------------------------------------------------------------------+
        public  print_number
print_number:
        mov     ah,9                    ;print the name of the number.
        int     21h
        mov     al,'0'
        call    chrout
        mov     al,'x'
        call    chrout
        mov     ax,[di]                 ;print the number in hex.
        mov     dx,[di+2]
        call    dwordout
        mov     al,' '
        call    chrout
        mov     al,'('
        call    chrout
        mov     ax,[di]                 ;print the number in decimal.
        mov     dx,[di+2]
        call    decout
        mov     al,')'
        call    chrout
        call    crlf
        ret

;--------------------------------------------------------------------+
; Name : chrout
;
; Description: Print a character to screen.
;
; Enter :
;       INT 21h, AH = 02h
;
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+

        public  chrout

chrout:
        push    ax                      ;print the char in al.
        push    dx
        mov     dl,al
        mov     ah,2
        int     21h
        pop     dx
        pop     ax
        ret

;--------------------------------------------------------------------+
; Name : dwordout, wordout, byteout, digout
;
; Description:
;       dwordout - DWORD length digit characters print.
;        wordout - WORD length digit characters print.
;        byteout - BYTE length digit character print.
;         digout - Translate byte length to ASCII code.
;
; Enter :
;       DWORD -> DX:AX.
;        WORD -> AX.
;        BYTE -> AL.
;
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+
        public  dwordout, wordout, byteout, digout
dwordout:
        mov     cl,'0'                  ;prepare to eliminate leading zeroes.
        xchg    ax,dx                   ;just output 32 bits in hex.
        call    wordout                 ;output dx.
        xchg    ax,dx

wordout:
        push    ax
        mov     al,ah
        call    byteout
        pop     ax

byteout:
        mov     ah,al
        shr     al,1
        shr     al,1
        shr     al,1
        shr     al,1
        call    digout
        mov     al,ah

digout:
        and     al,0fh
        add     al,90h  ;binary digit to ascii hex digit.
        daa
        adc     al,40h
        daa
        cmp     al,cl                   ;leading zero?
        je      digout_1
        mov     cl,-1                   ;no more leading zeros.
        jmp     chrout

digout_1:

        ret

;--------------------------------------------------------------------+
; Name : decout
;
; Description: Print DWORD decimal number.
;
; Enter :
;       DX:AX -> number to print.
;
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+
        public  decout
decout:
        mov     si,ax                   ;get the number where we want it.
        mov     di,dx
        or      ax,dx                   ;is the number zero?
        jne     decout_nonzero
        mov     al,'0'                  ;yes - easier to just print it, than
        jmp     chrout                  ;  to eliminate all but the last zero.

decout_nonzero:
        xor     ax,ax                   ;start with all zeroes in al,bx,bp
        mov     bx,ax
        mov     bp,ax
        mov     cx,32                   ;32 bits in two 16 bit registers.

decout_1:
        shl     si,1
        rcl     di,1
        xchg    bp,ax
        call    addbit
        xchg    bp,ax
        xchg    bx,ax
        call    addbit
        xchg    bx,ax
        adc     al,al
        daa
        loop    decout_1
        mov     cl,'0'                  ;prepare to eliminate leading zeroes.
        call    byteout                 ;output the first two.
        mov     ax,bx                   ;output the next four
        call    wordout                 ;output the next four
        mov     ax,bp
        jmp     wordout

addbit: adc     al,al
        daa
        xchg    al,ah
        adc     al,al
        daa
        xchg    al,ah
        ret

;--------------------------------------------------------------------+
; Name : crlf
;
; Description: Print carray-return & line_feed
;
; Enter :
;
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+
        public  crlf
crlf:
        push    ax
        push    dx
        mov     dl,13
        mov     ah,2
        int     21h
        mov     dl,10
        mov     ah,2
        int     21h
        pop     dx
        pop     ax
        ret

;--------------------------------------------------------------------+
; Name : printmsg
;
; Description: Print message with carray-return & line_feed.
;
; Enter :
;       DX : message address.
;
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+
        public printmsg
printmsg:
        mov     ah, 9
        int     21h
        call    crlf
        ret

