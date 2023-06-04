;=========================================================================
; delay.inc - Delay functions
;-------------------------------------------------------------------------
;
; Compiles with NASM 2.11.08, might work with other versions
;
;=========================================================================
; SHAN修改备注:
; 1，AT_DELAY编译条件在config.inc文件中设置，目前已屏蔽，则由cpu时钟提供非精确延时
;=========================================================================

%ifdef PIT_DELAY

;=========================================================================
; delay_15us - delay for multiplies of 15 microseconds 15微秒倍数的延迟
; Input:
;	CX = time to delay (in 15 microsecond units)
; Notes:
;	1.  Actual delay will be between (CX - 1) * 15us and CX * 15us 实际延迟介于（CX-1）*15us和CX*15us之间
;	2.  This relies on the "refresh" bit of port 61h and therefore on
;	    timer channel 1. Will not function properly if timer gets
;	    reprogrammed by an application or if it was not initialized yet
;	这依赖于端口61h的“刷新”位，因此依赖于计时器通道1。如果计时器被应用程序重新编程或尚未初始化，将无法正常工作
;  注意！！！！硬件已经取消此通道，仅仅保留程序做参考，不要开启此宏定义！！！！！！！
;-------------------------------------------------------------------------
delay_15us:
	push	ax
	push	cx
.zero:
	in	al,ppi_pb_reg
	test	al,refresh_flag
	jz	.zero
	dec	cx
	jz	.exit
.one:
	in	al,ppi_pb_reg
	test	al,refresh_flag
	jnz	.one
	dec	cx
	jnz	.zero
.exit:
	pop	cx
	pop	ax
	ret

%else ; PIT_DELAY

;=========================================================================
; delay_15us - delay for multiplies of approximately 15 microseconds 大约15微秒的倍数延迟
; Input:
;	CX = time to delay (in 15 microsecond units)
; Notes:
;	This implementation does not provide precise timing
;	The actual delay depends on the CPU clock frequency
;	此实现不提供精确定时实际延迟取决于CPU时钟频率
;-------------------------------------------------------------------------
delay_15us:
	push	ax
	push	cx
.1:
	mov	al,4
.2:
	dec	al
	jnz	.2
	loop	.1
	pop	cx
	pop	ax
	ret

%endif ; AT_DELAY


%if 0
;=========================================================================
; divide_32 - divide 64-bit argument by 32-bit, return 64-bit result 将64位参数除以32位，返回64位结果
; Input:
;	DX:AX	- dividend		被除数
;	CX	- divisor		除数
; Output:
;	DX:AX	- quotient		商，结果
;-------------------------------------------------------------------------
divide_32:
	or	dx,dx
	jnz	.1
	div	cx
	xor	dx,dx
	ret
.1:
	push	bx
	mov	bx,ax
	mov	ax,dx
	xor	dx,dx
	div	cx
	xchg	bx,ax
	div	cx
	mov	dx,bx
	pop	bx
	ret
%endif ; 0
