@echo off
rem run vsbhda without jhdpmi
jload -q qpiemu.dll
jload -q -u jhdpmi.dll
lh hdpmi32i -x2
rem set blaster=A220 I5 D1 T3
rem set blaster=A220 I5 D1 T4
set blaster=A220 I5 D1 H5 T6 P330
vsbhda.exe
