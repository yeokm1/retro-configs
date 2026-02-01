Windows 9x VCACHE Protection Error Fix.
.VXD and .SYS versions of the original CREGFIX.COM:
https://github.com/mintsuki/cregfix
And also DPMI version for resetting the CR0.WriteProtect bit
setting of which actually causes the error.

For Windows ME and Safe Mode (CREGFIX.VXD),
and for normal mode (including Virtual 8086 Mode)
of Windows 95&98 (CREGFIX.SYS).
However, CREGFIX.VXD is universal, meaning it works everywhere.

Contents:
CREGFIX.VXD - Windows driver, universal version, including use 
              in Windows ME and Safe Mode
CREGFIX.SYS - DOS driver for use with Windows 95&98
WP_OFF.EXE  - DPMI version, runs under DOS, requires Ring 0 32-bit DPMI server
CWSDPMI.EXE - CWSDPMI R5(fixed) Ring 0 Version of 32-bit DPMI Server
CWSDPMI\    - CWSDPMI R5(fixed) & R7 Ring 0 Versions of 32-bit DPMI Server
INSTALL\    - Install of CREGFIX.VXD examples 
UNINSTALL\  - Uninstall of CREGFIX.VXD examples

Installation:

CREGFIX.VXD:
1. Copy CREGFIX.VXD to %windir%\SYSTEM\
2. Add to %windir%\SYSTEM.INI and to %windir%\SYSTEM.CB in [386Enh] section
this line:

device=CREGFIX.VXD

CREGFIX.SYS:
Add to CONFIG.SYS preferably at the very beginning and definitely
BEFORE the Virtual 8086 Mode driver (e.g. EMM386.EXE):
device=PathToCREGFIX\CREGFIX.SYS
...
device=HIMEM.SYS
device=EMM386.SYS

WP_OFF.EXE:
Simply run anywhere convenient in DOS, however the program WILL NOT
work with an already running Ring 3 DPMI server because it does not use the
privilege escalation hacks. If you have already applied any variant of
CREGFIX.*, then WP_OFF.EXE does NOT need to be run, of course.

Uninstall:

CREGFIX.VXD:
1. Delete (or comment) from %windir%\SYSTEM.INI and
from %windir%\SYSTEM.CB in [386Enh] section this line:

device=CREGFIX.VXD

2. Delete CREGFIX.VXD from %windir%\SYSTEM\

CREGFIX.SYS:
Delete (or comment) from CONFIG.SYS this line:
device=PathToCREGFIX\CREGFIX.SYS
