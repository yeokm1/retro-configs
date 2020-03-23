;put into the public domain by Russell Nelson, nelson@clutx.clarkson.edu

	public	to_upper
to_upper:
	cmp	al,'a'
	jb	to_upper_1
	cmp	al,'z'
	ja	to_upper_1
	sub	al,20h
to_upper_1:
	ret

