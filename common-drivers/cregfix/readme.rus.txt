Исправление ошибки защиты VCACHE в Windows 9x. 
.VXD и .SYS версии исходного CREGFIX.COM:
https://github.com/mintsuki/cregfix
А так же DPMI версия сброса флажка CR0.WriteProtect
установка которого собственно и вызывает ошибку.

Предназначено для Windows ME и Safe Mode (CREGFIX.VXD),
и обычного режима (в том числе и Virtual 8086 Mode)
Windows 95&98 (CREGFIX.SYS).
Однако CREGFIX.VXD универсален, т.е. работает везде.

Содержание:
CREGFIX.VXD - Драйвер Windows, универсальная версия в том числе 
              для использования в Windows ME и Safe Mode
CREGFIX.SYS - Драйвер DOS для использования в Windows 95&98
WP_OFF.EXE  - DPMI версия, работает под DOS, требует Ring 0 32-bit DPMI сервера
CWSDPMI.EXE - CWSDPMI R5(fixed) Ring 0 Version of 32-bit DPMI Server
CWSDPMI\    - CWSDPMI R5(fixed) & R7 Ring 0 Versions of 32-bit DPMI Server
INSTALL\    - Примеры установки CREGFIX.VXD
UNINSTALL\  - Примеры удаления CREGFIX.VXD

Установка:
CREGFIX.VXD:
1. Скопируйте CREGFIX.VXD в %windir%\SYSTEM\.
2. Добавьте в %windir%\SYSTEM.INI и в %windir%\SYSTEM.CB в раздел [386Enh]
эту строку:

device=CREGFIX.VXD

CREGFIX.SYS:
Добавьте в CONFIG.SYS предпочтительно в самом начале и обязательно
ПЕРЕД драйвером Virtual 8086 Mode (например EMM386.EXE):
device=PathToCREGFIX\CREGFIX.SYS
...
device=HIMEM.SYS
device=EMM386.SYS

WP_OFF.EXE:
Просто запустите в любом удобном месте в DOS, однако программа НЕ БУДЕТ
работать с уже запущенным Ring 3 DPMI сервером поскольку не использует
хаки повышения привилегий. Если вы уже применили любой вариант
CREGFIX.*, то запуск WP_OFF.EXE уже НЕ нужен, разумеется.

Удаление:
CREGFIX.VXD:
1. Удалите (или закомментируйте) из %windir%\SYSTEM.INI и
из %windir%\SYSTEM.CB в разделе [386Enh] эту строку:

device=CREGFIX.VXD

2. Удалите CREGFIX.VXD из %windir%\SYSTEM\

CREGFIX.SYS:
Удалите илм закомментируйте в CONFIG.SYS строку:
device=PathToCREGFIX\CREGFIX.SYS
