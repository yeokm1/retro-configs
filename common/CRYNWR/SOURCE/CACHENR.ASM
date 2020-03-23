	include	defs.asm
	include	cache.inc

code	SEGMENT	word public
	assume	cs:code, ds:code
	extrn	cache_memory : byte, cache_head : word

	public	initialize_cache
initialize_cache	PROC NEAR
	mov		di, offset cache_memory
	mov		cache_head, di
	mov		cx, NO_CACHE_ENTRIES
init_cache_1:
	mov		[di+older], di
	add		[di+older], SIZE cache_entry
	mov		[di+younger], di
	sub		[di+younger], SIZE cache_entry
	add		di, SIZE cache_entry
	loop	init_cache_1
	sub		di, SIZE cache_entry		; Modify the older pointer of the last
	mov		[di+older], 0000h			; entry to be NULL
	mov		di,	cache_head
	mov		[di+younger], 0000h	; Modify younger pointer of 1'st entry
	ret
initialize_cache	ENDP

code	ENDS
	END
