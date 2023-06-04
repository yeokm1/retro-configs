;put into the public domain by Russell Nelson, nelson@clutx.clarkson.edu

	public	to_lower
to_lower:
	cmp	al,'A'
	jb	to_lower_1
	cmp	al,'Z'
	ja	to_lower_1
	add	al,20h
to_lower_1:
	ret
