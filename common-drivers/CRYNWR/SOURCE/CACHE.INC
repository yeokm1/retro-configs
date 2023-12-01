ROUTE_SIZE_MASK		EQU	001FH
ROUTE_DIR_BIT		EQU	80h

NO_CACHE_ENTRIES	EQU	 MAX_HANDLE	; Set = to maximum number of handles.
ROUTE_INFO_SIZE		EQU	30

cache_entry	struc
older		dw		?
younger		dw		?
e_address	db	EADDR_LEN	dup (?)
route		dw		?
			db	(ROUTE_INFO_SIZE - 2) dup (?)
cache_entry	ends
