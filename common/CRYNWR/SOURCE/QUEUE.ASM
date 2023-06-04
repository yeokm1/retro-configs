
;put into the public domain by Russell Nelson, nelson@crynwr.com

; here we define a queue of variable-sized objects.  Each object is preceded
; by the length of the object.  If the length is zero, then the next real item
; is found at queue_begin.  Queue_push doesn't check to see if you're pushing
; an item that simply will not fit on the queue.


queue_length	dw	10000,?		;length of the queue.
queue_tail	dw	?		;points after the last item in the queue.
queue_head	dw	?		;points to the first item in the queue.
queue_end	dw	?		;points to the end of the queue, but
					;there is room for one more event after
					;this one.

  if 0
queue_dump:
	mov	ax,offset queue_begin
	call	wordout
	mov	al,' '
	call	chrout

	mov	ax,queue_tail
	call	wordout
	mov	al,' '
	call	chrout

	mov	ax,queue_head
	call	wordout
	mov	al,' '
	call	chrout

	mov	ax,queue_end
	call	wordout
	call	crlf
	ret
  endif


queue_init:
;initialize the queue.
	mov	bx,offset queue_begin
	mov	queue_head,bx
	mov	queue_tail,bx
	add	bx,queue_length
	sub	bx,2			;we may go past end by as much as 2.
	mov	queue_end,bx		;initialize the head of the queue.
	ret


queue_pull:
;exit with nc, si,cx describing next item on queue,
;  or cy if no more items.

queue_pull_0:
	mov	si,queue_head		;load si, cx.
	cmp	si,queue_tail		;quit when we hit the tail.
	je	queue_pull_2
	mov	cx,code:[si]		;get this one's length.
	jcxz	queue_pull_1		;zero means wrap around.
	add	si,2			;advance si to next.
	add	si,cx
	xchg	si,queue_head		;update queue_head.
	add	si,2
	clc
	ret
queue_pull_1:
	mov	queue_head,offset queue_begin	;wrap around to beginning.
	jmp	queue_pull_0
queue_pull_2:
	stc
	ret


queue_push:
;enter with cx = number of bytes that we require in the queue.
;exit with nc, di -> data part of our entry,
;  or cy if there isn't room.
;this code is slightly suboptimal in that if there isn't enough room at the
;end of the queue to hold the current item, it will wrap the queue tail around.
;if it then runs into the queue head, the space at the end is now wasted.
;You may wish to discard old entries rather than new.  If that is the case,
;then if queue_push returns cy, call queue_pull and try again.
queue_push_0:
	mov	di,queue_tail		;get the pointer.
	cmp	di,queue_head		;if the tail is before the head,
	jb	queue_push_2		;  we just compare.
	add	di,2			;leave room for the count.
	add	di,cx
	jmp	short queue_push_4
queue_push_2:
;we get here if the tail *was* before the head.
	add	di,2			;leave room for the count.
	add	di,cx
	cmp	di,queue_head		;is the tail now after the head?
	ja	queue_push_3		;yes, we don't have room.
queue_push_4:
	cmp	di,queue_end		;time to wrap?
	jbe	queue_push_1		;not yet.

	mov	di,queue_tail
	mov	word ptr code:[di],0	;make a zero-length event here.

	mov	queue_tail,offset queue_begin
	jmp	queue_push_0

queue_push_3:
	stc
	ret

queue_push_1:
	xchg	di,queue_tail		;update the tail and get new pointer.
	mov	code:[di],cx		;store the length of this entry here.
	add	di,2
	clc
	ret


queue_unpush:
;call with si -> same value returned by queue_push.
	sub	si,2
	mov	queue_tail,si		;throw this one back.
	ret


