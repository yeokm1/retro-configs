PATH C:\DOS;D:\DRIVERS\MTCP2023
rem SET BLASTER=A220 I5 D1 T3
SET TEMP=C:\TEMP
SET TMP=C:\TMP
SET MTCPCFG=D:\CONFIGS\MTCP.CFG
SET TZ=UTC-8
D:\DRIVERS\RTC\RTC.EXE GET
D:\DRIVERS\DOSKEY28\DOSKEY.COM
D:\DRIVERS\NE2000\NE2000.COM 0x60 2 0x260
rem D:\DRIVERS\3C503.COM 0x60 3 0x310
rem D:\DRIVERS\SBPNPXT\SBPNPXT.EXE
rem D:\DRIVERS\UNISOUND\UNISOUND.COM /V85
rem D:\DRIVERS\CTMS21B4\BIN\CTMOUSE.EXE
rem dhcp
rem sntp -set sg.pool.ntp.org
SET DIRCMD=/O:GEN/P/A
PROMPT $V$_$D$_$T$_$p$g
