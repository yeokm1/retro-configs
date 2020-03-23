;put into the public domain by Russell Nelson, nelson@clutx.clarkson.edu

lookup_string:
;enter with ds:si -> string (space or newline terminated), ds:di ->
;  list of string/word combinations.  Strings are null terminated, list
;  is terminated by null string.
;when we find a match, return with bx=word,nc, otherwise cy

lookup_string_0:
	cmp	[di],byte ptr 0		;null string?
	je	lookup_string_5		;yes, give up.
	push	si
lookup_string_1:
	lodsb				;get a single-string char.
	cmp	al,' '			;if it terminates check for null.
	je	lookup_string_2
	cmp	al,CR
	je	lookup_string_2
	cmp	al,[di]			;if it matches, continue.
	jne	lookup_string_3
	inc	di
	jmp	lookup_string_1
lookup_string_2:
	dec	si			;leave si -> terminator.
	cmp	[di],byte ptr 0		;end of this string?
	jne	lookup_string_3		;no, give up.
	add	sp,2			;yes, matches.  Return their value.
	mov	bx,[di+1]
	clc
	ret
lookup_string_3:
	cmp	[di],byte ptr 0		;end of this string?
	je	lookup_string_4		;go if so; skip forward if not.
	inc	di
	jmp	lookup_string_3
lookup_string_4:
	pop	si
	add	di,1+2			;skip past the null and the word
	jmp	lookup_string_0
lookup_string_5:
	stc
	ret