w3xac97.dll is a windows 3.1 sound driver.

Remove emm386 from config.sys


Add  to system.ini 

[drivers]
wave=w3xac97.dll



Then add (activate.exe) to the startup group.

Tested on a 800mhz computer.

2017 update:
./TSR/ICHAC97.EXE
For computers with less than 512mb of RAM install ICHAC97.EXE in AUTOEXEC.BAT
The TSR will allocate XMS before windows starts and pass its location to w3xac97.dll.

If you do not use the TSR, you must specify a XMS memory address outside the reach of windows in
../windows/ichcfg.ini.

