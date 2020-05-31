;put into the public domain by Russell Nelson, nelson@crynwr.com
;
;  do_timeout's sequence:
;;;             sub     ax,cs:timeout_value
;;;             shl     ax,1          
;  changed to the sequence:
;;;             XOR     ax,cs:timeout_value
;;;             SHR     ax,1
;  in an effort to keep the timeouts obtained from getting way too short,
;  when the application loads something into the timer latches to shorten
;  the timer's period.  As the Trumpet PING application seems to do!
;  Call the routine's "clock tick rate", the rate at which the
;;;             add     cs:timeout_counter,ax
;  instruction produces a Carry.  Then, with timer latch contents of zero
;  (65536) and a very fast processor, the revised routine's clock tick rate
;  is expected to be four times the original routine's nominal rate.
;  However, if the timer latch contents were to be slowly decreased, one
;  would see the revised routine's clock tick rate peak at under eight
;  times the original routine's nominal rate, with latch contents of about
;  08001h.  And, then slowly decline.  Under the same conditions, the
;  original routine's clock tick rate would rapidly increase.
;  Also, several delaying
;;;             JMP     $+2
;  instructions added to latch_timer.
;  Fred C. Macall  21 June 2003.
;
;  Two TEST al,0E8h instructions added to do_timeout to provide a patch area
;  for adding up to two more SHR ax,1 instructions, if desired.
;  Fred C. Macall  26 June 2003.
;
;we read the timer chip's counter zero.  It runs freely, counting down
;from 65535 to zero.  We sample the count coming in and subract the previous
;count.  Then we double it and add it to our timeout_counter.  When it overflows,
;then we've waited a tick of 27.5 ms.

timeout		dw	?		;number of ticks to wait.
timeout_counter	dw	?		;old counter zero value.
timeout_value	dw	?

	public	set_timeout
set_timeout:
;enter with ax = number of ticks (36.4 ticks per second).
	inc	ax			;the first times out immediately.
	mov	cs:timeout,ax
	mov	cs:timeout_counter,0
	call	latch_timer
	mov	cs:timeout_value,ax
	ret

latch_timer:
	mov	al,0			;latch counter zero.
	out	43h,al
        JMP     $+2                     ;  Delay.
	in	al,40h			;read counter zero.
	mov	ah,al
        JMP     $+2
	in	al,40h
	xchg	ah,al
	ret

	public	do_timeout
do_timeout:
;call at *least* every 27.5ms when checking for timeout.  Returns nz
;if we haven't timed out yet.
	call	latch_timer
	xchg	ax,cs:timeout_value
	XOR	ax,cs:timeout_value
        TEST    al,0E8h                 ;  Room to patch in two more
        TEST    al,0E8h                 ;    SHR ax,1 instructions.
	SHR	ax,1			;  See discussion above.
	add	cs:timeout_counter,ax	;has the counter overflowed yet?
	jnc	do_timeout_1		;no.
	dec	cs:timeout		;Did we hit the timeout value yet?
	ret
do_timeout_1:
	or	sp,sp			;ensure nz.
	ret
