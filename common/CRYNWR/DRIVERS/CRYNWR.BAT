@echo off
rem EtherExpress PRO/100B [T[4|X]], PRO/10 - 8086:0002, 1668:1100, 8086:0003, 8086:0001
rem NE2000 compatible - 1266:1910, 1050:0000, 1050:0940, 1050:5a5a, 10b8:2011, 10ec:8029, 1113:1208, 1186:0300, 1259:2400, 8e2e:3000, 4a14:5000, 1106:0926, 12C3:0058, 12C3:5598, 11F6:1401, 10BD:0E34
rem SMC 9232 (9332 - 10b8:2001, 10b8:2002)(9334 -10b8:2003)
rem IBM Token Ring - 1014:003e, 1014:00cd, 1014:00ce, 1014:00cf, 1014:00e4, 1014:00e5, 1014:016d
rem Broadcom 570x - 14e4:165d
rem SiS900 LAN - 1039:0900
rem SURECOM EP-320X-S - 1516:0803, 1320:10bd
rem RealTek 8139 - 10ec:8139 - DONE, but should get source
rem Davicom DM9102 - 1282:9102, 1282:9100 - DONE
rem Davicom 9009/9132 - 1282:9009, 1282:9132
rem ThunderLAN (Compaq) - 0e11:ae32 - 0e11:ae34 - 0e11:ae35 - 0e11:ae40 - 0e11:ae43 - 0e11:ae43 - 0e11:b011 - 0e11:b012 - 0e11:b030 - 0e11:f130 - 0e11:f150 - 108d:0012 - 108d:0013 - 108d:0014

:menu
pushd
cdd %dosdir%\drivers\net\crynwr
ctty con
cls
echo 1) Attempt to detect PCI-based adapters (recommended)
echo 2) Select an ISA-based packet driver and specify parameters
echo 3) Use a driver disk and load a vendor-provided driver
echo 4) Load a QEMU compatible driver
echo 5) Load a VMWare compatible driver
echo 6) Shell to DOS to load a driver
echo 7) Dial via a modem
echo 8) Do not load a packet driver
echo.
choice /t1,10 /n /c:12345678
if "%errorlevel%"=="1" goto detect
if "%errorlevel%"=="2" goto specify
if "%errorlevel%"=="3" goto disk
if "%errorlevel%"=="4" goto qemu
if "%errorlevel%"=="5" goto vmware
if "%errorlevel%"=="6" goto shelldos
if "%errorlevel%"=="7" goto modem
if "%errorlevel%"=="8" goto end
goto menu
:detect
echo Attempting to detect PCI-based adapters...
pcisleep /q02 > %tmp%\nic.txt
if "%errorlevel%"=="0" echo You have no PCI-based adapters
if "%errorlevel%"=="0" pause
if "%errorlevel%"=="0" goto menu
ctty nul
REM VMWare compatible
find /I "1022:2000" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=pcntpk int=0x60
if not "%pktcmd%"=="" goto detect1
rem Surecom EP-320X-S and compatibles
find /I "1516:0803" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=feapkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1320:10bd" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=feapkt 0x60
if not "%pktcmd%"=="" goto detect1
rem SMC 9232, 9332, 9334 and compatibles
find /I "10b8:2001" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=pktpwr 0x60
if not "%pktcmd%"=="" goto detect1
find /I "10b8:2002" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=pktpwr 0x60
if not "%pktcmd%"=="" goto detect1
find /I "10b8:2003" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=pktpwr 0x60
if not "%pktcmd%"=="" goto detect1
find /I "10b8:a011" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=pktpwr 0x60
if not "%pktcmd%"=="" goto detect1
find /I "10b8:a014" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=pktpwr 0x60
if not "%pktcmd%"=="" goto detect1
find /I "10b8:a015" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=pktpwr 0x60
if not "%pktcmd%"=="" goto detect1
find /I "10b8:a016" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=pktpwr 0x60
if not "%pktcmd%"=="" goto detect1
find /I "10b8:a017" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=pktpwr 0x60
if not "%pktcmd%"=="" goto detect1
rem Davicom DM9102 and compatibles
find /I "1282:9102" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=dm9pcipd 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1282:9100" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=dm9pcipd 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1282:9009" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=dm9pcipd 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1282:9132" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=dm9pcipd 0x60
if not "%pktcmd%"=="" goto detect1
rem RealTek 8139 and compatibles
find /I "10ec:8139" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "10ec:8138" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "0357:000a" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1025:005a" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1025:8920" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1025:8921" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1071:8160" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "10bd:0320" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1113:ec01" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1186:1300" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1186:1320" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1186:8139" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "11f6:8139" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1259:2500" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1259:2503" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1429:d010" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1432:9130" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1436:8139" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1458:e000" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "146c:1439" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1489:6001" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1489:6002" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "149c:139a" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "149c:8139" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "14cb:0200" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1799:5000" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "2646:0001" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "8e2e:7000" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "8e2e:7100" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "a0a0:0007" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=rtspkt 0x60
if not "%pktcmd%"=="" goto detect1
rem EtherExpress Pro/10, Pro/100B
find /I "8086:0003" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=e100bpkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "8086:1229" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=e100bpkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "8086:0001" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=e100bpkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "8086:0002" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=e100bpkt 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1668:1100" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=e100bpkt 0x60
if not "%pktcmd%"=="" goto detect1
rem NE2000 and compatible
find /I "1266:1910" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ne2 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1050:0000" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ne2 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1050:0940" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ne2 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1050:5a5a" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ne2 0x60
if not "%pktcmd%"=="" goto detect1
find /I "10b8:2011" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ne2 0x60
if not "%pktcmd%"=="" goto detect1
find /I "10ec:8029" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ne2 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1113:1208" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ne2 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1186:0300" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ne2 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1259:2400" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ne2 0x60
if not "%pktcmd%"=="" goto detect1
find /I "8e2e:3000" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ne2 0x60
if not "%pktcmd%"=="" goto detect1
find /I "4a14:5000" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ne2 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1106:0926" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ne2 0x60
if not "%pktcmd%"=="" goto detect1
find /I "12c3:0058" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ne2 0x60
if not "%pktcmd%"=="" goto detect1
find /I "12c3:5598" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ne2 0x60
if not "%pktcmd%"=="" goto detect1
find /I "11f6:1401" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ne2 0x60
if not "%pktcmd%"=="" goto detect1
find /I "10bd:0e34" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ne2 0x60
if not "%pktcmd%"=="" goto detect1
rem IBM Token Ring Compatible
find /I "1014:003e" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ibmtoken 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1014:00cd" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ibmtoken 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1014:00ce" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ibmtoken 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1014:00cf" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ibmtoken 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1014:00e4" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ibmtoken 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1014:00e5" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ibmtoken 0x60
if not "%pktcmd%"=="" goto detect1
find /I "1014:016d" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=ibmtoken 0x60
if not "%pktcmd%"=="" goto detect1
rem Fujitsu EtherCoupler (86965)
find /I "10b7:9050" %tmp%\nic.txt
if "%errorlevel%"=="0" set pktcmd=dk86965 0x60
if not "%pktcmd%"=="" goto detect1
ctty con
echo Your PCI chipset is not yet supported.  If you are sure that the driver is
echo distributable, e-mail me at Blairdude@gmail.com with the output of:
echo PCISLEEP /Q02.
choice /t2,10 /c:yn Continue with experimental autodetection (possibly may reset your computer)
if "%errorlevel%"=="2" goto menu
ctty nul
rem ARLAN 450
set pktcmd=ar450 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem c83815 nortel
set pktcmd=c83815 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem dc21x4x
set pktcmd=dc 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem D-Link DE600 Parallel Port Adapter
set pktcmd=de600 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem Fujitsu EtherCoupler (86965)
set pktcmd=dk86965 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem EtherExpress PRO/10 PRO/100B
set pktcmd=e100bpkt 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem EtherExpress PRO LAN
set pktcmd=eep10pkt 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem IBM Token Ring
set pktcmd=ibmtoken 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem NE2000 compatible
set pktcmd=ne2 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem Kodiak noteport
set pktcmd=noteport 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem IBM PC LAN or SYTEK 6120
set pktcmd=pclana 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem SMC 8016/PC Adapters
set pktcmd=pkt8016 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem SMC 82M32C
set pktcmd=pkt8232 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem SMC 9232
set pktcmd=pkt9232 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem SMC 9332
set pktcmd=pktpwr 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem Parallel port
set pktcmd=plip 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem ZDS Z-Note
set pktcmd=znote 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
rem Xircom CE3
set pktcmd=cd3pd SINT 60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
ctty con
echo Detection failed...
pause
goto menu
:detect1
ctty nul
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
ctty con
echo Your card was detected incorrectly.  E-mail Blairdude@gmail.com with the output of:
echo PCISLEEP /Q02
echo and the name of your Ethernet card to get your card better supported.
pause
goto menu
:specify
ctty con
cls
echo 0) 3com 3C501
echo 1) 3com 3C503
echo 2) 3com 3C505
echo 3) 3com 3C507
echo 4) 3com 3C509
echo 5) 3com 3C523
echo 6) Intel EtherExpress(TM) PRO/10+
echo 7) Intel EtherExpress 16
echo 8) NE2000
echo 9) NE2100
echo 10) I need to be dropped to a shell as I have carved my network card out of raw
echo     silicium and need to look at %dosdir%\crynwr.txt to find a suitable driver.
echo X) Return to previous menu
echo.
choice /s /n /c:123456789x
if "%errorlevel%"=="0" set pktcmd=3c501
if "%errorlevel%"=="1" set pktcmd=3c503
if "%errorlevel%"=="2" set pktcmd=3c505
if "%errorlevel%"=="3" set pktcmd=3c507
if "%errorlevel%"=="4" set pktcmd=3c509
if "%errorlevel%"=="5" set pktcmd=3c523
if "%errorlevel%"=="6" set pktcmd=epropkkt
if "%errorlevel%"=="7" set pktcmd=exp16
if "%errorlevel%"=="8" set pktcmd=ne2000
if "%errorlevel%"=="9" set pktcmd=ne2100
if "%errorlevel%"=="10" goto shelldos
if "%errorlevel%"=="11" goto menu
cls
set /P usrinput=[(irq) + ENTER] :
set irq=%usrinput%
set /P usrinput=[(io address) + ENTER] :
set io=%usrinput%
set /P usrinput=[(mem address) + ENTER] (optional) :
set mem=%usrinput%
set /P usrinput=[(base address) + ENTER] (optional) :
set base=%usrinput%
set pktcmd=%pktcmd% 0x60 %irq% %io% %mem% %base%
ctty nul
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
ctty con
choice /c:yn Command failed.  Try again
if "%errorlevel%"=="2" goto end
goto menu
:disk
ctty con
echo Enter the full path to the driver (no arguments).
echo Example: A:\DRIVER.COM
set /P usrinput=[(driver name-and-path) + ENTER] :
if not exist %usrinput% goto enterfail
copy %usrinput% %dosdir%\drivers\net\crynwr\custom.com
echo Enter the arguments to be given to the driver
echo Example: 0x60 irq io_addr mem_addr base_addr (not all options may be required)
echo 0x60 5 0x210
set /P usrinput=[(driver_command) + ENTER] :
set pktcmd=custom.com %usrinput%
ctty nul
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto success
:enterfail
ctty con
choice /c:yn Command failed.  Try again
if "%errorlevel%"=="2" goto end
goto menu
:qemu
ctty nul
set pktcmd=ne2 0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
set pktcmd=ne2000 0x60 9 0x300
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
ctty con
echo Loading the packet driver failed.  Be sure to load QEMU with the right options.
pause
goto menu
:vmware
ctty nul
set pktcmd=pcntpk int=0x60
lh %pktcmd%
pktchk 0x60
if not errorlevel 1 goto sucess
ctty con
echo Loading the packet driver failed.  Be sure to load VMWare with the right options.
pause
goto menu
:shelldos
ctty con
echo The packet driver will not get installed in %autofile% if you load the driver this way.
echo Type 'exit' to leave the shell and return to the menu.  If a packet driver is found loaded
echo after you leave the shell, it will be detected and the menu will be exited.
call command.com
ctty nul
pktchk 0x60 0x80
if "%pktcmd%"=="" if not errorlevel 1 goto end
if not errorlevel 1 goto sucess
ctty con
echo The packet driver failed to load properly.  Please try again.
pause
goto menu
:modem
ctty con
cls
echo.
echo 1) Select a COM port (default is 1)
echo 2) Select a baud rate (default is 57600)
echo 3) Specify other command line options
echo 4) Load the driver
echo 5) Return to previous menu
echo 6) I'm totally confused.  I will type "%dosdir%\crynwr.bat" when I am ready.
echo.
choice /n /c:123456
if "%errorlevel%"=="1" goto comport
if "%errorlevel%"=="2" goto baud
if "%errorlevel%"=="3" goto othercmd
if "%errorlevel%"=="4" goto loadmodem
if "%errorlevel%"=="5" goto menu
if "%errorlevel%"=="6" goto end
:comport
echo Type the number of the COM Port (1 - 4)
set /p com=
goto modem
:baud
cls
echo.
echo 1) 14400
echo 2) 19200
echo 3) 28800
echo 4) 38400
echo 5) 57600
echo 6) 115200
echo 7) I have a really old modem and need to set my own value
echo 8) Return to previous menu
echo.
choice /n /c:12345678
if "%errorlevel%"=="1" set baud=14400
if "%errorlevel%"=="2" set baud=19200
if "%errorlevel%"=="3" set baud=28800
if "%errorlevel%"=="4" set baud=38400
if "%errorlevel%"=="5" set baud=57600
if "%errorlevel%"=="6" set baud=115200
if "%errorlevel%"=="7" set /p baud=
if "%errorlevel%"=="8" goto modem
goto modem
:othercmd
echo Type the other commands below
set /p cmds=
goto modem
:loadmodem
cls
if "%com%"=="" set com=1
if "%baud%"=="" set baud=57600
echo Type your username below
set /p usname=
if "%usname%"=="" set usname=username
echo Type your password below (Warning! - the password WILL be echoed on the screen,
echo but the screen will be cleared when you press enter)
set /p pass=
cls
if "%pass%"=="" set pass=password
echo Type the phone number to dial below
set /p num=
if "%num%"=="" set num=1234567
ctty nul
set pktcmd=lsppp /n:%com% /d:P%num% /B:%baud% /P:%pass% /U:%usname% %cmds%
lh %pktcmd%
pktchk 0x60 0x80
if not errorlevel 1 goto sucess
ctty con
echo Dialing the modem failed.  Please try again.
pause
goto modem
:sucess
ctty con
choice /c:yn Install packet driver in %autofile%
if "%errorlevel%"=="1" echo %dosdir%\drivers\net\crynwr\%pktcmd% >> %autofile%
goto end
:end
popd
