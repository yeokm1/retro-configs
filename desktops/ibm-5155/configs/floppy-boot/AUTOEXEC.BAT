PATH A:\DOS
PATH=%PATH%;A:\DRIVERS\MTCP2020
SET BLASTER=A220 I5 D1 T3
SET TEMP=A:\TEMP
SET TMP=A:\TMP
SET MTCPCFG=A:\MTCP.CFG
SET TZ=UTC-8
A:\DRIVERS\RTC\RTC.EXE GET
A:\DRIVERS\DOSKEY28\DOSKEY.COM
A:\DRIVERS\NE2000.COM 0x60 2 0x260
rem A:\DRIVERS\CTMS21B4\BIN\CTMOUSE.EXE
rem dhcp
rem sntp -set sg.pool.ntp.org
PROMPT $V$_$D$_$T$_$p$g
