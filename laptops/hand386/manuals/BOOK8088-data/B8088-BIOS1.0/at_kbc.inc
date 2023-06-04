;=========================================================================
; at_kbc.inc - AT style keyboard controller support
;-------------------------------------------------------------------------
;
; Compiles with NASM 2.11.08, might work with other versions
;
;=========================================================================
; i8042 有 4 个 8 bits 的寄存器
; 两个是8042输出给cpu读取的:	Status Register(状态寄存器)	=64h
;			Output Buffer(输出缓冲器)	=60h
; 两个是cpu输入到8042的      :	Control Register(控制寄存器)	=64h			
;			Input Buffer(输入缓冲器)	=60h
;------------------------------------------------------------------------------------------------------------------------------
; 驱动对键盘控制器发送命令是通过写端口 64h 实现的，共有 12 条命令，分别为：
; 20h 准备读取 8042 芯片的 Command Byte => 此时8042会将控制寄存器的内容送到60h中待cpu读取
; 60h 准备写入 8042 芯片的 Command Byte => 下一个通过 60h 写入的字节将会被放入 Command Byte
; A4h 测试一下键盘密码是否被设置；测试结果放置在 Output Register，然后可以通过 60h 读取出来。
;	测试结果可以有两种值：FAh=密码被设置；F1h=没有密码。
; A5h 设置键盘密码 其结果按照顺序通过 60h 端口一个一个被放置在 Input Register中,密码的最后是一个空字节(内容为 0)
; A6h 让密码生效。在发布这个命令之前，必须首先使用 A5h 命令设置密码。
; AAh 自检。诊断结果放置在 Output Register 中，可以通过 60h 读取。55h=OK。
; ADh 禁止键盘接口。Command Byte 的 bit-4 被设置。当此命令被发布后，Keyboard 被禁止发送数据到 Output Register。
; AEh 打开键盘接口。Command Byte 的 bit-4 被清除。当此命令被发布后，Keyboard 将被允许发送数据到 Output Register。
; C0h 准备读取 Input Port。Input Port 的内容被放置于 Output Register 中，随后可以通过 60h 端口读取。
; D0h 准备读取 Outport 端口。结果被放在 Output Register 中，随后通过 60h 端口读取出来。
; D1h 准备写 Output 端口。随后通过 60h 端口写入的字节，会被放置在 Output Port 中。
; D2h 准备写数据到 Output Register 中。随后通过 60h 写入到 Input Register 的字节会被放入到 Output Register 中，
; 	此功能被用来模拟来自于 Keyboard 发送的数据。如果中断被允许，则会触发一个中断。
;------------------------------------------------------------------------------------------------------------------------------
; 发给 8048 的命令共有 10 条命令，分别为:
; EDh -----设置 LED:	
;	Keyboard 收到此命令后，一个 LED 设置会话开始。
;	Keyboard 首先回复一个 ACK（FAh），然后等待从60h 端口写入的 LED 设 置字节，
;	如果等到一个，则再次回复一个 ACK，然后根据此字节设置 LED。然后接着等待。。。
;	直到等到一个非 LED 设置字节(高位被设置)，此时 LED 设 置会话结束。
; EEh -----	诊断 Echo:	
;	此命令纯粹为了检测 Keyboard 是否正常，如果正常，当 Keyboard 收到此命令后，将会回复一个 EEh字节
; F0h -----	选择 Scancode set: 
;	Keyboard 系统共可能有 3 个 Scan code set。
;	当 Keyboard 收到此命令后，将回复一个 ACK，然后等待一个来自于 60h 端口的 Scan code set 代码。
;	系统必须在此命令之后发送给 Keyboard 一个 Scan code set 代码。当Keyboard 收到此代码后，
;	将再次回复一个 ACK，然后将 Scan code set 设置为收到的 Scan code set 代码所要求的。
; F2h -----	读取 Keyboard ID: 
;	由于 8042 芯片后不仅仅能够接 Keyboard。此命令是为了读取 8042 后所接的设备 ID。
;	设备 ID 为 2个字节，Keyboard ID 为 83ABh。当键盘收到此命令后，会首先回复一个 ACK，
;	然后，将 2 字节的 Keyboard ID 一个一个回复回去。
; F3h -----	设置 Typematic Rate/Delay: 
;	当 Keyboard 收到此命令后，将回复一个 ACK。然后等待来自于 60h 的设置字节。
;	一旦收到，将回复一个 ACK，然后将 Keyboard Rate/Delay 设置为相应的值。
; F4h -----	清理键盘的 Output Buffer: 
;	一旦 Keyboard 收到此命令，将会将 Output buffer 清空，然后回复一个 ACK。然后继续接受Keyboard 的击键。
; F5h -----	设置默认状态(w/Disable):
;	 一旦 Keyboard 收到此命令，将会将 Keyboard 完全初始化成默认状态。
;	之前所有对它的设置都将失效—— Output buffer 被清空，Typematic Rate/Delay 被设置成默认值。
;	然后回复一个 ACK，接着等待下一个命令。需要注意的是，这个命令被执行后，键盘的击键接受是禁止的。
;	如果想让键盘 接受击键输入，必须 Enable Keyboard。
; F6h -----	设置默认状态。和 F5 命令唯一不同的是，当此命令被执行之后，键盘的击键接收是允许的。
; FEh -----	Resend。如果 Keyboard 收到此命令，则必须将刚才发送到 8042 Output Register 中的数据重新发送一遍。
;	当系统检测到一个来自于 Keyboard 的错误之后，可以使用自命令让 Keyboard 重新发送刚才发送的字节。
; FFh -----	Reset Keyboard。如果 Keyboard 收到此命令，则首先回复一个 ACK，然后启动自身的 Reset 程序，
; 	并进行自身基本正确性检测（BAT- Basic Assurance Test）。等这一切结束之后，
; 	将返回给系统一个单字节的结束码（AAh=Success,FCh=Failed），并将键盘的 Scan code set 设置为 2。
;------------------------------------------------------------------------------------------------------------------------------
; 读到的数据
; 00h/FFh 当击键或释放键时检测到错误时，则在 Output Bufer 后放入此字节，如果 Output Buffer 已满，
;	则会将 Output Buffer 的最后一个字节替代为此字节。
;	使用 Scan code set 1 时使用 00h，Scan code 2 和 Scan Code 3 使用 FFh。
; AAh	BAT 完成代码。如果键盘检测成功，则会将此字节发送到 8042 Output Register 中。
; EEh	Echo 响应。Keyboard 使用 EEh 响应从 60h 发来的 Echo 请求。
; F0h	在 Scan code set 2 和 Scan code set 3 中，被用作 Break Code 的前缀。
; FAh	ACK。当 Keyboard 任何时候收到一个来自于 60h 端口的合法命令或合法数据之后，都回复一个 FAh。
; FCh	BAT 失败代码。如果键盘检测失败，则会将此字节发送到 8042 Output Register 中。
; FEh	Resend。当 Keyboard 任何时候收到一个来自于 60h 端口的非法命令或非法数据之后，
;	或者数据的奇偶交验错误，都回复一个 FEh，要求系统重新发送相关命令或数据。
; 83ABh	当键盘收到一个来自于 60h 的 F2h 命令之后，会依次回复 83h，ABh。83AB 是键盘的 ID。
; Scan code 除了上述那些特殊字节以外，剩下的都是 Scan code。

; 当有数据需要被驱动读走的时候，数据被放入输出缓冲器，同时将状态寄存器的 bit0（OUTPUT_BUFFER_FULL）置1，
; 引发键盘中断（键盘中断 的 IRQ 为 1）。由于键盘中断，引起由键盘驱动提供的键盘中断服务例程被执行。
; 在键盘中断服务例程中，驱动会从 i8042 读走数据。一旦数据读取完成，状态寄存器的 bit0 会被清 0。
; 读数据的方法，首先，读取状态寄存器，判断 bit0，状态寄存器 bit0 为 1，说明输出缓冲器中有数据。
; 保证状态寄存器bit0 为 1，然后对 60h 端口进行读操作，读取数据。

; 向 i8042 发命令
; 当命令被发往 i8042 的时候，命令被放入输入缓冲器，同时引起状态寄存器的 Bit1 置 1，表示输入缓冲器满，
; 同时引起状态寄存器的 Bit2 置 1，表示写入输入缓冲器的是一个命令。

; 向 i8042 发命令的方法，
; 首先，读取状态寄存器，判断 bit1，状态寄存器 bit1 为 0，说明输入缓冲器为空，可以写入。
; 保证状态寄存器 bit1 为 0，然后对 64h 端口进行写操作，写入命令。

; 间接向 i8048 发命令
; 向 i8042 发这些命令，i8042 会转发 i8048，命令被放入输入缓冲器，同时引起状态寄存器的 Bit1 置 1，
; 表示输入缓冲器满，同时引起状态寄存器的 Bit2 置 1，表示写入输入缓冲器的是一个命令。
; 这里我们要注意，向 i8048 发命令，是通过写 60h 端口，而后面发命令的参数，也是写 60h 端口。
; i8042 如 何判断输入缓冲器中的内容是命令还是参数呢，我们在后面发命令的参数中一起讨论。

; 向 i8048 发命令的方法，
; 首先，读取状态寄存器，判断 bit1,状态寄存器 bit1 为 0，说明输入缓冲器为空，可以写入。
; 保证状态寄存器 bit1 为 0，然后对 60h 端口进行写操作，写入命令。

; 发命令的参数
; 某些命令需要参数，我们在发送命令之后，发送它的参数，参数被放入输入缓冲器，同时引起状态寄存器的 Bit1 置1，
; 表示输入缓冲器满。这里我们要注意，向 i8048 发命令，是通过写 60h 端口，发命令的参数，也是写 60h 端口。
; i8042 如何判断输入缓冲器中的 内容是命令还是参数呢。i8042 是这样判断的，如果当前状态寄存器的 Bit3 为 1，
; 表示之前已经写入了一个命令，那么现在通过写 60h 端口放入输入缓冲器中的内容，就被当做之前命令的参数，
; 并且引起状态寄存器的 Bit3 置 0。如果当前状态寄存器的 Bit3 为 0，表示之前没有写入命令，
; 那么现在通过写 60h 端口放入输入缓冲器中的内容，就被当做一个间接发往 i8048 的命令，并且引起状态寄存器的 Bit3 置 1。

; 向 i8048 发参数的方法，
; 首先，读取状态寄存器，判断 bit1,状态寄存器 bit1 为 0，说明输入缓冲器为空，可以写入。
; 保证状态寄存器 bit1 为 0，然后对 60h 端口进行写操作，写入参数。

;=========================================================================
; Status Register（状态寄存器64h）是一个 8 位只读寄存器，任何时刻均可被 cpu 读取。其各位定义如下

; Bit7: PARITY-EVEN(P_E): 		从键盘获得的数据奇偶校验错误
; Bit6: RCV-TMOUT(R_T): 		接收超时，置 1   
; Bit5: TRANS_TMOUT(T_T): 		发送超时，置 1		；在PS2模式时代表mouse obf
; Bit4: KYBD_INH(K_I): 为 1，		键盘没有被禁止。为 0，键盘被禁止。
; Bit3: CMD_DATA(C_D): 为 1，		输入缓冲器中的内容为命令，为 0，输入缓冲器中的内容为数据。
; Bit2: SYS_FLAG(S_F): 系统标志，	加电启动置 0，自检通过后置 1
; Bit1: INPUT_BUF_FULL(I_B_F): 		输入缓冲器满置 1，i8042 取走后置 0
; Bit0: OUT_BUF_FULL(O_B_F): 		输出缓冲器满置 1，CPU 读取后置 0
;------------------------------------------------------------------------------------------------------------------------------
; Control Register（控制寄存器）也被称作 Controller Command Byte （控制器命令字节）。其各位定义如下
; Bit7: 保留，应该为 0
; Bit6: 将第二套扫描码翻译为第一套
; Bit5: 置 1，禁止鼠标
; Bit4: 置 1，禁止键盘
; Bit3: 置 1，忽略状态寄存器中的 Bit4
; Bit2: 设置状态寄存器中的 Bit2
; Bit1: 置 1，enable 鼠标中断
; Bit0: 置 1，enable 键盘中断
;=========================================================================
; Keyboard controller defines - ports, commands, and flags 键盘控制器定义-端口、命令和标志
;-------------------------------------------------------------------------
kbc_data_reg	equ	60h
; keyboard controller return codes 键盘控制器返回代码
kbc_ret_test	equ	0AAh	; keyboard controller test passed
; keyboard controller status register and its bits
kbc_status_reg	equ	64h
kbc_stat_obf	equ	01h	; output buffer full flag			键盘输出缓冲区已满标志
kbc_stat_ibf	equ	02h	; input buffer full flag			键盘输入缓冲区已满标志
kbc_stat_aobf	equ	20h	; auxiliary output buffer full flag		鼠标输入缓冲区已满标志
kbc_stat_tout	equ	40h	; receive/transmit timeout			接收/传输超时
kbc_stat_perr	equ	80h	; parity error				奇偶校验错误
; keyboard contoller command register and commands				键盘控制器命令寄存器和命令
kbc_command_reg	equ	64h
kbc_cmd_rd_ctr	equ	20h	; read controller configuration byte command	读取控制寄存器命令
kbc_cmd_wr_ctr	equ	60h	; write controller configruation byte command	写入控制寄存器命令
kbc_cmd_aux_dis	equ	0A7h	; disable auxiliary interface command		禁用鼠标接口命令
kbc_cmd_aux_ena	equ	0A8h	; enable auxiliary interface command		启用鼠标接口命令
kbc_cmd_aux_tst	equ	0A9h	; test auxiliary interface command		测试鼠标接口命令
kbc_cmd_test	equ	0AAh	; keyboard controller self-test command		键盘控制器自检命令
kbc_cmd_kbd_tst	equ	0ABh	; test keyboard interface command		测试键盘接口命令
kbc_cmd_kbd_dis	equ	0ADh	; disable keyboard interface command		禁用键盘界面命令
kbc_cmd_kbd_ena	equ	0AEh	; enable keyboard interface command		启用键盘界面命令
kbc_cmd_rd_in	equ	0C0h	; read keyboard input port			读取键盘输入端口
kbc_cmd_aux_snd	equ	0D4h	; send command byte to auxiliary device command	向鼠标设备命令发送命令字节
; keyboard controller control register bits  键盘控制器控制寄存器位
kbc_ctr_kbd_int	equ	01h	; enable keyboard OBF interrupt		启用键盘OBF中断
kbc_ctr_aux_int	equ	02h	; enable auxiliary OBF interrupt			启用鼠标OBF中断
kbc_ctr_no_lock	equ	08h	; ignore keyboard inhibit (keyboard lock)		忽略键盘禁止（键盘锁定）
kbc_ctr_kbd_dis	equ	10h	; disable keyboard interface			禁用键盘接口
kbc_ctr_aux_dis 	equ	20h	; disable auxiliary interface			禁用鼠标接口
kbc_ctr_xlat	equ	40h	; enable keyboard scancode translation		启用键盘扫描代码转换
; keyboard controller input port bits	键盘控制器输入端口位
kbc_in_display	equ	40h	;0100 0000 input port bit 6: 0 = MDA, 1 = CGA
; keyboard controller response timeout in 60us units 键盘控制器响应超时（以60us为单位）
kbc_ctr_timeout	equ     20000	; 1.2 seconds
; keyboard and auxiliary device commands键盘和鼠标设备命令
aux_cmd_scale11	equ	0E6h	; auxiliary device set 1:1 scaling factor		鼠标设备设置1:1比例因子
aux_cmd_scale21	equ	0E7h	; auxiliary device set 2:1 scaling factor		鼠标设备设置2:1比例因子
aux_cmd_resol	equ	0E8h	; auxiliary device set resolution			鼠标设备设置分辨率
aux_cmd_status	equ	0E9h	; auxiliary device get status			鼠标设备获取状态
kbd_cmd_leds	equ	0EDh	; keyboard set LEDs				设置键盘led
dev_cmd_dev_id	equ	0F2h	; read device ID				读取设备ID
dev_cmd_rate	equ	0F3h	; keyboard set typematic rate/delay		键盘设置键入 速率/延迟
				; auxiliary device set sample rate		鼠标设备设定采样率
dev_cmd_enable	equ	0F4h	; device enable				设备允许
dev_cmd_disable	equ	0F5h	; device disable				设备禁止
dev_cmd_reset	equ	0FFh	; reset and self-test				设备复位和自检
; keyboard and auxiliary device responses 键盘和鼠标设备响应
dev_rsp_bat_ok	equ	0AAh	; basic assurance test is OK			基本保证测试正常
dev_rsp_ack	equ	0FAh	; acknowledge				回应
dev_rsp_error	equ	0FCh	; error (basic assurance test failed)		错误（基本保证测试失败）
dev_rsp_resend	equ	0FEh	; resend (invalid command or argument)		重新发送（无效命令或参数）

;=========================================================================
; kbc_kb_send - send command to keyboard, wait for acknowledge 向键盘发送命令，等待确认
; Input:
;	AL = command
; Output:
;	none
;-------------------------------------------------------------------------
kbc_kb_send:
	push	ax			; 这里要用到ax和cx所以先压入栈
	push	cx
	mov	ah,al			; save command to AH
	mov	cx,3			; try 3 times

.retry:
	push	cx
	cli				; 禁止中断，sti：开启中断
; clear the Error, Acknowledge received, and resend received flags 清除错误、确认接收和重新发送接收标志
	and	byte [kbd_flags_4],4Fh	; kbd_flags_4=97h ;[97h]表示内存地址97h中的值 ;  ？ and 01001111 ; ???待办
	xor	cx,cx			; 清除cx

.2:					; wait for KBC to empty input buffer 等待KBC清空输入缓冲区
	in	al,kbc_status_reg		; 读取键盘状态寄存器(64H)
	test	al,kbc_stat_ibf		; 判断输入缓冲区已满标志(02h), 8042取走数据后该位被置0
					; (解读)test指令是将两个操作数相与，结果为0，则ZF=1；结果为非0，则ZF=0
	loopnz	.2			; CX=CX-1,若(CX)!=0且ZF=0,则转移
					; (解读)此时ZF=0的话，说明8042输入缓冲取数据未被取走，则循环，直到3次以后，或者数据被取走
	mov	al,ah			; ah保存的是：最开始要发送给键盘的命令
	out	kbc_data_reg,al		; send command to the keyboard 向键盘60h发送命令
	sti				; 开启中断
	xor	cx,cx			; 清除cx
.wait_for_ack:				; wait for acknowledge (set by IRQ1 ISR)等待确认（由IRQ1 ISR设置）
	test	byte [kbd_flags_4], 10h	; acknowledge bit set?
	loopz	.wait_for_ack
	pop	cx
	jnz	.exit
	loop	.retry			; try again
; if the operation failed after 3 retries, set the error bit and quit 如果操作在3次重试后失败，请设置错误位并退出
	or	byte [kbd_flags_4], 80h
.exit:
	pop	cx
	pop	ax
	ret				; RET是子程序的返回指令

;=========================================================================
; kbc_send_cmd - send command + argument to keyboard controller 向键盘控制器发送 命令+参数
; Input:
;	AL - command byte
;	AH = argument
; Output:
;	CF == 0 - no error
;	CF == 1 - timeout
;-------------------------------------------------------------------------
kbc_send_cmd:
	call	kbc_write_command		; 若键盘空闲，则写入 ; 若超时，cf=1
	jc	.exit			; 若cf==1，则退出
	xchg	al,ah			; 将参数放入al中准备送入键盘
	call	kbc_write_data		; 将参数写入60h端口
	xchg	al,ah
.exit:
	ret

;=========================================================================
; kbc_write_command - send command byte to keyboard controller
; Input:
;	AL - command byte
; Output:
;	CF == 0 - no error
;	CF == 1 - timeout
;-------------------------------------------------------------------------
kbc_write_command:
	call	kbc_wait_write		; 等待键盘控制器输入缓冲区为空(返回CF值)
					; 总共读取20000次，每次间隔60us，共1.2秒
	jc	.timeout			; CF == 1 - timeout 转移
					; 若超时，直接退出，并且CF处于置1状态
	out	kbc_command_reg,al	; write command ;al值写入64h端口

.timeout:
	ret

;=========================================================================
; kbc_write_data - write byte to keyboard controller data register (0x60)
; Input:
;	AL - command byte
; Output:
;	CF == 0 - no error
;	CF == 1 - timeout
;-------------------------------------------------------------------------
kbc_write_data:
	call	kbc_wait_write
	jc	.timeout		; CF == 1 - timeout
	out	kbc_data_reg,al		; write data register ; al值写入60h端口

.timeout:
	ret

;=========================================================================
; kbc_wait_write - wait for keyboard controller input buffer to be empty 等待键盘控制器输入缓冲区为空
; Input:
;	none
; Output:
;	CF == 0 - no error, input buffer is empty 无错误，输入缓冲区为空
;	CF == 1 - timeout
;-------------------------------------------------------------------------
kbc_wait_write:
	push	ax
	push	cx
	mov	cx,kbc_ctr_timeout		; kbc_ctr_timeout=20000
					; wait for KBC to empty input buffer 等待KBC清空输入缓冲区
.wait:
	in	al,kbc_status_reg		; 读取键盘状态寄存器(64H)
	test	al,kbc_stat_ibf		; 判断输入缓冲区已满标志(02h), 8042取走数据后该位被置0
	jz	.exit			; note: test instruction sets CF=0 test指令会直接将CF置0
					; 结果为零(或相等)(ZF=1) 转移
					; (解读)若缓冲区数据已清空，则退出，并且CF标志也被置0
	push	cx			; 此时cx=20000 n次循环时cx=20000-n	
	mov	cx,4			; 此时cx=4，延时4x15us
	call	delay_15us		; 45-60us I/O delay
	pop	cx			; 此时cx=20000
	loop	.wait			; cx!=0 则循环
	stc				; CF=1 - timeout
					; 循环20000次(1.2秒)后，键盘超时，则将cf置1，并退出
.exit:
	pop	cx
	pop	ax
	ret

;=========================================================================
; kbc_data_read - wait for data in keyboard controller output buffer and read it
; 读取键盘数据   - 等待键盘控制器输出缓冲区中的数据并读取它                
; Input:
;	none
; Output:
;	AL = data from the keyboard controller	键盘数据
;	AH = keyboard controller status register	键盘状态寄存器值
;	CF == 0 - no error, data is available	无错误，数据可用
;	CF == 1 - KBC timeout
;-------------------------------------------------------------------------
kbc_data_read:
	push	cx
	mov	cx,kbc_ctr_timeout		; 20000次循环
					; wait for data
.wait:
	in	al,kbc_status_reg		; 读取键盘状态寄存器(64H)
	mov	ah,al			; 存储到ah中，因为待会儿al中要存储键盘数据
	test	ah,kbc_stat_obf		;  判断输出缓冲区已满标志(01h), 输出缓冲器满 则为 1，CPU 读取后会被置 0
					; (解读)test指令是将两个操作数相与，结果为0，则ZF=1；结果为非0，则ZF=0
	jnz	.read_data			; note: test instruction sets CF=0
					; 结果为非0(ZF=0),则转移 说明输出缓冲器满 可以读取 ，并且CF标志也被置0
	push	cx			; 此时cx=20000 循环n次时cx=20000-n
	mov	cx,4
	call	delay_15us		; 45-60us I/O delay
	pop	cx
	loop	.wait
	stc				; CF=1 - timeout
	jmp	.exit
.read_data:
	in	al,kbc_data_reg		  ; 读取60h端口中的数据
					
	test	ah,kbc_stat_tout | kbc_stat_perr  ; check for receive/transmit timeout and parity errors
					  ; 检查接收/传输超时 和奇偶校验错误
	jnz	.wait			  ; note: test instruction sets CF=0
.exit:
	pop	cx
	ret

%ifdef PS2_MOUSE
;=========================================================================
; kbc_aux_read - read data from auxiliary device
; Input:
;	none
; Output:
;	AL = data
;	AH = keyboard controller status register
;	CF == 0 - no error
;	CF == 1 - timeout
;-------------------------------------------------------------------------
kbc_aux_read:
	call	kbc_data_read
	jc	.exit			; CF==1 - timeout
	test	ah,kbc_stat_aobf	; data from auxiliary device?
	jnz	.exit			; note: test instruction sets CF=0
	stc				; no auxiliary data, set CF=1
.exit:
	ret

;=========================================================================
; kbc_aux_send - send command to auxiliary device, wait for acknowledge
; Input:
;	AL = command
; Output:
;	AH - status:
;		00h - success
;		03h - interface error (timeout)
;		04h - resend requested
;	CF == 0 - no error
;	CF == 1 - error
;-------------------------------------------------------------------------
kbc_aux_send:
	push	cx
	mov	ah,al			; store command to AH
	mov	al,kbc_cmd_aux_snd	; write byte to auxiliary device
	call	kbc_send_cmd
	jc	.timeout		; kbc_send_cmd timed out

					; wait for acknowledge
	mov	cx,10			; retry 10 times
.retry:
	call	kbc_aux_read
	jnc	.check_reply		; CF==0 - data is available
	loop	.retry
	jmp	.timeout		; no reply - timeout
.check_reply:
	cmp	al,dev_rsp_ack
	je	.ok
	cmp	al,dev_rsp_resend
	je	.resend
	cmp	al,dev_rsp_error
	je	.timeout		; treat as timeout/interface error
	loop	.retry
	jmp	.timeout

.ok:
	mov	al,00h			; success - ACK received
	clc
	jmp	.exit

.timeout:
	mov	al,03h			; interface error
	jmp	.error

.resend:
	mov	al,04h			; resend

.error:
	stc

.exit:
	xchg	ah,al			; status to AH, original command to AL
	pop	cx
	ret

;=========================================================================
; kbc_aux_enable - enable auxiliary device
; Input:
;	none
; Output:
;	CF = 0 - no error
;	CF = 1 - KBC timeout
;-------------------------------------------------------------------------
kbc_aux_enable:
	push	ax
	mov	al,kbc_cmd_wr_ctr	; send "write keyboard controller" cmd
	mov	ah,01001111b
;		   |||||||`-- 1 == enable OBF interrupt for keyboard (IRQ1)
;                  ||||||`-- 1 == enable OBF interrupt for aux port (IRQ12)
;		   |||||`-- 1 == POST complete
;                  ||||`-- 1 == disable the keyboard inhibit
;                  |||`-- 0 == enable keyboard interface
;		   ||`-- 0 == enable mouse interface
;		   |`-- 1 == enable scancode translation
;		   `-- 0 == reserved, must be 0
	call	kbc_send_cmd
	pop	ax
	ret

;=========================================================================
; kbc_aux_disable - disable auxiliary device
; Input:
;	none
; Output:
;	CF = 0 - no error
;	CF = 1 - KBC timeout
;-------------------------------------------------------------------------
kbc_aux_disable:
	push	ax
	mov	al,kbc_cmd_wr_ctr	; send "write keyboard controller" cmd
	mov	ah,01101101b
;		   |||||||`-- 1 == enable OBF interrupt for keyboard (IRQ1)
;                  ||||||`-- 0 == disable OBF interrupt for aux port (IRQ12)
;		   |||||`-- 1 == POST complete
;                  ||||`-- 1 == disable the keyboard inhibit
;                  |||`-- 0 == enable keyboard interface
;		   ||`-- 1 == disable mouse interface
;		   |`-- 1 == enable scancode translation
;		   `-- 0 == reserved, must be 0
	call	kbc_send_cmd
	pop	ax
	ret

%endif ; PS2_MOUSE

;=========================================================================
; kbc_flush - flush all input data from i8042 buffer 刷新i8042缓冲区中的所有输入数据
; Input:
;	none
; Output:
;	CF = 0 - flushed successfully				已成功刷新
;	CF = 1 - can't flush after 20 retries, probably no hardware	重试20次后无法刷新，可能没有硬件
;-------------------------------------------------------------------------
kbc_flush:
	push	ax
	push	cx
	mov	cx,20			; maximal KBC buffer size 最大KBC缓冲区大小
.flush_next_byte:
	in	al,kbc_status_reg		; 读取键盘状态寄存器(64H)
	test	al,kbc_stat_obf		; 判断输出缓冲区已满标志(01h), 输出缓冲器满 则为 1，CPU 读取后会被置0			
	jz	.flushed			; 结果为零(或相等)(ZF=1) 转移
	push	cx
	mov	cx,4
	call	delay_15us		; 45-60us I/O delay
	pop	cx
	in	al,kbc_data_reg
	loop	.flush_next_byte
	stc				; unable to flush KBC
	jmp	.exit
.flushed:
	clc				; cf置0
.exit:
	pop	cx
	pop	ax
	ret

;=========================================================================
; kbc_init - Initialize keyboard controller 初始化键盘控制器
;-------------------------------------------------------------------------
kbc_init:
	push	ax
	push	cx
	push	dx

;-------------------------------------------------------------------------
; Flush the data from keyboard controller output buffer 刷新键盘控制器输出缓冲区中的数据

	call	kbc_flush
	jc	kbc_flush_fail

;-------------------------------------------------------------------------
; Disable keyboard and mouse interfaces so that they don't interfere with tests 	禁用键盘和鼠标界面，以便它们不会干扰测试
; No error handling here. The controller and the keyboard are tested later	此处没有错误处理。稍后测试控制器和键盘

	mov	ah,01110000b
;		   |||||||`-- 0 == disable OBF interrupt for keyboard (IRQ1)
;		   ||||||`-- 0 == disable OBF interrupt for aux port (IRQ12)
;		   |||||`-- 0 == power on / POST in progress
;		   ||||`-- 0 == reserved, must be 0
;		   |||`-- 1 == disable keyboard interface
;		   ||`-- 1 == disable auxiliary interface
;		   |`-- 1 == enable scan code translation to IBM PC scan codes
;		   `-- 0 == reserved, must be 0

	mov	al,kbc_cmd_wr_ctr		; write controller configuration byte 写入控制器配置字节60h
	call	kbc_send_cmd		; al=命令 ah=参数

;-------------------------------------------------------------------------
; Run keyboard controller self-test 运行键盘控制器自检

	mov	dh,e_kbc_test_fail		; 在errno.inc中=62h ; Keyboard controller self test failed
	mov	dl,e_kbd_tout_fail		; 在errno.inc中=01h ; Keyboard timeout sending command
	mov	al,kbc_cmd_test		; =0AAh键盘控制器自检命令
	call 	kbc_write_command		; 写入到64h端口
	jc	.kbc_test_error		; 返回cf=1说明超时
					; DH	= 主要错误编号
					; DL	= 次要错误号
	mov	dl,e_kbd_resp_fail		; 在errno.inc中=02h ; 键盘无响应
	call	kbc_data_read		; wait and read the response
	jc	.kbc_test_error
	mov	dl,e_kbc_test_fail
	cmp	al,55h			; check for success
	je	.kbc_test_ok

.kbc_test_error:
	call	kbd_key_fail		; show the error on the POST display

.kbc_test_ok:

;-------------------------------------------------------------------------
; Run keyboard interface test	运行键盘接口测试

	mov	dh,e_kbc_int_fail
	mov	dl,e_kbd_tout_fail
	mov	al,kbc_cmd_kbd_tst		; =0ABh 测试键盘接口命令
	call	kbc_write_command		; 写入到64h端口
	jc	.keyboard_interface_error	; 返回cf=1说明失败

	mov	dl,e_kbd_resp_fail
	call	kbc_data_read		; wait and read test result
	jc	.keyboard_interface_error
	mov	dl,e_kbd_int_fail
	cmp	al,0			; check for success
	je	.keyboard_interface_ok

.keyboard_interface_error:
	call	kbd_key_fail		; show the error on the POST display

.keyboard_interface_ok:

;-------------------------------------------------------------------------
; Read display type and set equipment bits accordingly
; No error handling here. In the worst case the display settings will be wrong
; 读取显示类型并相应设置设备位
; 此处没有错误处理。在最坏的情况下，显示设置将出错

;	mov	al,kbc_cmd_rd_in		; send read input port command 读取键盘输入端口
;	call	kbc_write_command		; 发送到64h端口

;	call	kbc_data_read		; wait and read input port value 等待并读取输入端口值
;	test	al,kbc_in_display		; 40h=0100 0000 input port bit 6: 0 = MDA, 1 = CGA
;	jnz	.get_disp_color		; input port bit 6 set => CGA display
					; 结果为非0(ZF=0),则转移 说明读取到第6位=1
;	or	word [equipment_list],equip_mono
;	jmp	.get_disp_done
;.get_disp_color:
;	or	word [equipment_list],equip_color_80
;.get_disp_done:

;-------------------------------------------------------------------------
; Enable keyboard interface 启用键盘界面

	mov	al,kbc_cmd_kbd_ena		; send enable keyboard interface cmd
	call	kbc_write_command
	jc	kbc_cmd_fail

;-------------------------------------------------------------------------
; Check that BAT (Basic Assurance Test) is OK:
; 检查BAT（基本保证测试）是否正常：

; Someone at IBM thought that it is a really clever idea that the keyboard
; would send a BAT (Basic Assurance Test) OK code (0AAh) after the power on
; And yet, not all keyboards do, at least not always...
; Also keyboards do not reset themself on the system reset/reboot...
; Also some keyboard controllers (VIA VT82C42 particularly)
; seem to fake BAT OK code on the power on...
; IBM的一些人认为键盘通电后会发送BAT（基本保证测试）OK代码（0AAh）
; 然而，并非所有的键盘都能做到，至少不总是这样。。。
; 此外，键盘在系统重置/重新启动时不会自行重置。。。
; 还有一些键盘控制器（特别是VIA VT82C42）
; 似乎在开机时伪造BAT OK代码。。。

; check for BAT code in the buffer, and if it is not thereissue a keyboard reset command
; 检查缓冲区中的BAT代码，如果没有，则发出键盘重置命令

	call	kbc_data_read		; check for BAT code in the buffer
	jc	.keyboard_reset		; timeout - reset the keyboard
	cmp	al,dev_rsp_bat_ok
	je	.keyboard_bat_ok		; all good, do not reset the keyboard

.keyboard_reset:
	mov	dh,e_kbd_bat_fail		; major error numbre
	mov	dl,e_kbd_tout_fail		; minor error number
	mov	al,dev_cmd_reset
	call	kbc_write_data		; send reset command to the keyboard
	jc	.keyboard_reset_error

	mov	dl,e_kbd_resp_fail		; minor error number
	call	kbc_data_read		; wait for ACK
	jc	.keyboard_reset_error
	mov	dl,e_kbd_nack_fail		; minor error number
	cmp	al,dev_rsp_ack
	jne	.keyboard_reset_error

	mov	dl,e_kbd_rsp2_fail		; minor error number
	call	kbc_data_read
	jc	.keyboard_reset_error
	mov	dl,e_kbd_nbat_fail		; minor error number
	cmp	al,dev_rsp_bat_ok
	je	.keyboard_bat_ok		; BAT received, continue

.keyboard_reset_error:
	call	kbd_key_fail		; show the error on the POST display

.keyboard_bat_ok:

;-------------------------------------------------------------------------
; Disable keyboard

	mov	dh,e_kbd_dis_fail		; major error number
	mov	dl,e_kbd_tout_fail		; minor error number
	mov	al,dev_cmd_disable
	call	kbc_write_data		; send keyboard disable command
	jc	.keyboard_disable_error

	mov	dl,e_kbd_resp_fail		; minor error number
	call	kbc_data_read		; wait for ACK
	jc	.keyboard_disable_error
	mov	dl,e_kbd_nack_fail		; minor error number
	cmp	al,dev_rsp_ack
	je	.keyboard_disable_ok	; ACK received, continue

.keyboard_disable_error:
	call	kbd_key_fail		; show the error on the POST display

.keyboard_disable_ok:

%ifdef PS2_MOUSE
;-------------------------------------------------------------------------
; Enable auxiliary port and check for PS/2 mouse presence

	mov	al,kbc_cmd_aux_ena		; send enable auxiliary interface cmd
	call	kbc_write_command

	mov	al,dev_cmd_reset
	call	kbc_aux_send
	cmp	ah,00h			; was the command sent successfully?
	jne	.no_mouse

	call	kbc_aux_read
	jc	.no_mouse
	cmp	al,dev_rsp_bat_ok		; Basic Assurance Test successful?
	jne	.no_mouse
	call	kbc_aux_read		; read and throw away Mouse ID
	jc	.no_mouse
; mouse reset was successful, update equipment word accordingly
	or      word [equipment_list],equip_mouse
.no_mouse:
%endif ; PS2_MOUSE

;-------------------------------------------------------------------------
; Set keyboard controller configuration:
; Enable keyboard interface; Disable auxiliary interface; Set POST complete

	mov	al,kbc_cmd_wr_ctr		; send "write keyboard controller" cmd
	mov	ah,01100101b
;		   |||||||`-- 1 == enable OBF interrupt for keyboard (IRQ1)
;		   ||||||`-- 0 == disable OBF interrupt for aux port (IRQ12)
;		   |||||`-- 1 == POST complete
;		   ||||`-- 0 == reserved, must be 0
;		   |||`-- 0 == enable keyboard interface
;		   ||`-- 1 == disable auxiliary interface
;		   |`-- 1 == enable scan code translation to IBM PC scan codes
;		   `-- 0 == reserved, must be 0
	call	kbc_send_cmd
	jc	kbc_cmd_fail

;-------------------------------------------------------------------------
; Enable keyboard

	mov	dh,e_kbd_ena_fail		; major error number
	mov	dl,e_kbd_tout_fail		; minor error number
	mov	al,dev_cmd_enable
	call	kbc_write_data		; send keyboard enable command
	jc	.keyboard_enable_error

	mov	dl,e_kbd_resp_fail		; minor error number
	call	kbc_data_read		; wait for ACK
	jc	.keyboard_enable_error
	mov	dl,e_kbd_nack_fail		; minor error number
	cmp	al,dev_rsp_ack
	je	.keyboard_enable_ok	; ACK received, continue

.keyboard_enable_error:
	call	kbd_key_fail		; show the error on the POST display

.keyboard_enable_ok:
;-------------------------------------------------------------------------

	pop	dx
	pop	cx
	pop	ax
	ret

kbc_flush_fail:
	mov	al,e_kbc_flsh_fail
	out	post_reg,al
.1:
	hlt
	jmp	.1

kbc_cmd_fail:
	mov	al,e_kbc_cmd_fail
	out	post_reg,al
.1:
	hlt
	jmp	.1

;=========================================================================
; kbd_key_fail - show keyboard initializaiton error on the POST display
; Input:
;	DH = major error number
;	DL = minor error number
;	AL = data or status code (DEBUG mode only)
; Output:
;	none
;-------------------------------------------------------------------------
kbd_key_fail:
	mov	cx,5			; repeat 5 times
	mov	ah,al			; save AL in AH
.1:
	push	cx
	mov	al,dh			; show DH first (major error number)
	out	post_reg,al
	mov	cx,8000h			; wait approximately 0.5 seconds
	call	delay_15us
	mov	al,dl			; show DL next (minor error number)
	out	post_reg,al
	mov	cx,8000h			; wait approximately 0.5 seconds
	call	delay_15us
	mov	al,ah			; show saved value of AL (data/status)
	out	post_reg,al
	mov	cx,8000h			; wait approximately 0.5 seconds
	call	delay_15us
	pop	cx
	loop	.1
	ret
