	include	defs.asm
	include	cache.inc

code	SEGMENT	word public
	assume	cs:code, ds:code
	extrn	cache_head : word
compare_address PROC NEAR
; Compare the address pointed to by si to the address in the cache entry pointed
; to by di.
	push	cx
	push	si
	push	di
	add		di, E_ADDRESS	; Point to the address part of the cache structue
	mov		cx, EADDR_LEN/2	; Number of words to compare
	repe	cmpsw
	pop		di
	pop		si
	pop		cx
	ret
compare_address	ENDP

locate_in_cache	PROC NEAR
; Scans through the cache list looking for match with the Address pointed to
; by si.  Return carry set if a match found with di holling the address of the
; matching entry.  If no match is found di points to the last (i.e. the oldest)
; entry in the cache.
	mov		di, cache_head				; Start the search at the begining
locate_1:
	call	compare_address				; Is this cache entry a match
	jne		no_address_match			; Jump if not
	stc									; Flag match found
	ret									; Match found, return address in di
no_address_match:
	cmp		WORD PTR [di+older], 0000h	; Are we at the end of the list
	jne		move_to_next				; No - continue search
	ret									; Yes - return without a match
move_to_next:
	mov		di, [di]					; Advance to the next location in cache
	jmp		locate_1					; Continue the search
locate_in_cache	ENDP

	public	locate_and_prioritize
locate_and_prioritize	PROC	NEAR
; Looks through the cache for a matching Ethernet address. If not found returns
; with carry clear.  If found, places the entry at the head of the cache and
; returns with carry set.
	call	locate_in_cache		; Find the Ethernet address in the cache
	jnc		dont_prioritize
	call	prioritize_cache_entry
	stc
dont_prioritize:
	ret
locate_and_prioritize	ENDP

prioritize_cache_entry	PROC	NEAR
	cmp		di, cache_head 		; Check if already at the head of the list
	je		already_at_head
	push	di					; Save pointer to entry in the cache
	; Remove the entry by modifying its neighbour's pointers
	mov		si, [di+younger]
	mov		di, [di+older]
	mov		[si+older], di
	or		di, di				; Zero if at the end of the list
	je		at_cache_last
	mov		[di+younger], si
at_cache_last:
	pop		di					; Recover pointer to entry in the cache
	mov		ax, cache_head
	mov		[di+older], ax
	mov		[di+younger], 0000h
	mov		si, cache_head
	mov		[si+younger], di
	mov		cache_head, di
already_at_head:
	ret
prioritize_cache_entry	ENDP

	public	add_to_cache
add_to_cache	PROC	NEAR
; cx and si are corrupted but there is no neeed to save
	push	es					; Save seg pointer to ULP buffer
	push	di					; Save offset pointer to ULP buffer
	push	si					; si is corrupted in prioritize_cache_entry
	mov		ax, cs				; Get es to the correct segment
	mov		es, ax
	call	locate_in_cache		; Find the Ethernet address in the cache
	call	prioritize_cache_entry
	pop		si
; Even if found there may be a change in the route so always update the cache
; The ethernet address is also copied - quicker than a check to see if it is
; necsssary to copy the copy for a new entry
	mov		cx, [si+EADDR_LEN]	; Get the routing information size
	and		cx, ROUTE_SIZE_MASK	; Leave only the size bits
	add		cx, EADDR_LEN
	shr		cx, 1				; Convert into a word count
	add		di, e_address		; di -> Ethernet address field in cache entry
	rep		movsw				; Copy the routing information words
	pop		di					; Recover offset pointer to ULP buffer
	pop		es					; Recover seg pointer to ULP buffer
	ret
add_to_cache	ENDP

code	ENDS
	END
