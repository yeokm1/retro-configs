
IFDEF DISPLAY
.386
include rtdata.inc
extrn   Printdig : near
extrn   printcrlf : near
extrn   charout : near
;;
;; Display all CR
;;
        pushfd
        push    dx
        push    eax
        push    bx
        push    cx

        mov     cx, 50
        mov     al, '-'
start_dash:
        call    charout
        loop    start_dash
        call    printcrlf

        mov     dx, p_CR0
        in      eax, dx
        mov     bl, 3
        call    Printdig
        call    printcrlf
        mov     dx, p_CR1
        in      eax, dx
        mov     bl, 3
        call    Printdig
        call    printcrlf
        mov     dx, p_CR2
        in      eax, dx
        mov     bl, 3
        call    Printdig
        call    printcrlf
        mov     dx, p_CR3
        in      eax, dx
        mov     bl, 3
        call    Printdig
        call    printcrlf
        mov     dx, p_CR4
        in      eax, dx
        mov     bl, 3
        call    Printdig
        call    printcrlf
        mov     dx, p_CR5
        in      eax, dx
        mov     bl, 3
        call    Printdig
        call    printcrlf
        mov     dx, p_CR6
        in      eax, dx
        mov     bl, 3
        call    Printdig
        call    printcrlf
        mov     dx, p_CR7
        in      eax, dx
        mov     bl, 3
        call    Printdig
        call    printcrlf
        mov     dx, p_CR8
        in      eax, dx
        mov     bl, 3
        call    Printdig
        call    printcrlf
        mov     dx, p_CR9
        in      eax, dx
        mov     bl, 3
        call    Printdig
        call    printcrlf
        mov     dx, p_CR10
        in      eax, dx
        mov     bl, 3
        call    Printdig
        call    printcrlf
        mov     dx, p_CR11
        in      eax, dx
        mov     bl, 3
        call    Printdig
        call    printcrlf
        mov     dx, p_CR12
        in      eax, dx
        mov     bl, 3
        call    Printdig
        call    printcrlf
        mov     dx, p_CR13
        in      eax, dx
        mov     bl, 3
        call    Printdig
        call    printcrlf
        mov     dx, p_CR14
        in      eax, dx
        mov     bl, 3
        call    Printdig
        call    printcrlf
        mov     dx, p_CR15
        in      eax, dx
        mov     bl, 3
        call    Printdig
        call    printcrlf

        mov     cx, 50
        mov     al, '-'
end_dash:
        call    charout
        loop    end_dash
        call    printcrlf

        pop     cx
        pop     bx
        pop     eax
        pop     dx
        popfd
ENDIF   ;;DISPLAY
