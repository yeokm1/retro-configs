;=========================================================================
; messages.inc - Messages printed by BIOS POST (Power On Self Test)
;-------------------------------------------------------------------------
;
;=========================================================================

msg_copyright	db	0Dh, 0Ah
		db	"CYCLE Computer BIOS"
		db	" V "
		db	VERSION
		db	". "
		db	"Copyright (C) 2022 CYCLE Logic", 0Dh, 0Ah
		db	"WWW."
		db	"8086CPU.COM", 0Dh, 0Ah

msg_crlf		db     	0Dh, 0Ah, 00h
msg_none		db	'none', 00h
msg_colon	db	': ', 00h
msg_semicolon	db	'; ', 00h

%ifdef TURBO_MODE
msg_cpu_clk	db	'CPU clock frequency:        ', 00h
msg_at		db	' @ ', 00h
msg_clk_4_77mhz	db	'4.77 MHz ', 00h
%endif ; TURBO_MODE

msg_cpu		db      'CPU:                        ', 00h	;28个字符
msg_fpu		db      'FPU:                        ', 00h
msg_cpu_8088_78	db      "Intel 8088 '78", 00h
msg_cpu_bug	db      'WARNING: This CPU does not disable interrupts '
		db      'after loading segment registers!', 0Dh, 0Ah, 00h
msg_cpu_8088_81	db      "Intel 8088 '81 "
		db      '/ OKI 80C88', 00h
msg_cpu_harris  	db      'Harris 80C88', 00h
msg_cpu_nec_v20 	db      'NEC 8088(V20)', 00h
msg_fpu_present 	db      'Intel 8087', 0Dh, 0Ah, 00h
msg_disp		db	'Display Type:               ', 00h
msg_disp_ega	db	'EGA/VGA (Video BIOS Present)', 0Dh, 0Ah, 00h
msg_disp_cga_80	db	'CGA (80x25)', 0Dh, 0Ah, 00h
msg_disp_cga_40	db	'CGA (40x25)', 0Dh, 0Ah, 00h
msg_disp_mda	db     	'MDA or Hercules', 0Dh, 0Ah, 00h
msg_rtc		db	'RTC (Real Time Clock):      ', 00h
msg_floppy	db	'Floppy disk drives:         Drive 0: ', 00h
msg_floppy_2	db	'; Drive 1: ', 00h
msg_floppy_360	db	'360 KB, 5.25"', 00h
msg_floppy_1200	db	'1.2 MB, 5.25"', 00h
msg_floppy_720	db	'720 KB, 3.5"', 00h
msg_floppy_1440	db	'1.44 MB, 3.5"', 00h
msg_floppy_2880	db	'2.88 MB, 3.5"', 00h
msg_present	db     	'Present', 0Dh, 0Ah, 00h
msg_absent	db     	'Absent', 0Dh, 0Ah, 00h
msg_serial		db	'Serial Ports:               ', 00h
msg_serial_com	db	'COM', 00h
msg_parallel	db	'Parallel Ports:             ', 00h
msg_parallel_lpt 	db	'LPT', 00h
msg_ram_testing	db	'Detecting RAM (ESC to exit):  ', 00h
msg_ram_error	db	0Dh, 0Ah, 'ERROR: Faulty memory detected at ', 00h
msg_ram_total	db      0Dh, 'RAM:                        ', 00h
msg_kib		db      ' KB', 0Dh, 0Ah, 00h
msg_boot_failed	db      'Boot failed, press any key to try again...', 0Dh, 0Ah, 0
msg_no_basic    	db      'No ROM BASIC', 0Dh, 0Ah, 0
msg_rom_found   	db      'Found BIOS extension ROM at ', 0
msg_rom_init	db	'0, initializing...', 0Dh, 0Ah, 0
msg_boot		db      'Booting OS...', 0Dh, 0Ah, 0

tbl_floppy	dw	msg_none
		dw	msg_floppy_360
		dw	msg_floppy_1200
		dw	msg_floppy_720
		dw	msg_floppy_1440
		dw	msg_none
		dw	msg_floppy_2880
		dw	msg_none
