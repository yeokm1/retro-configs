@echo off
rem run vsbhda16
jload -q qpiemu.dll
jload -q jhdpmi.dll
lh hdpmi16i -x2
rem set blaster=A220 I5 D1 T3
rem set blaster=A220 I5 D1 T4
set blaster=A220 I5 D1 H5 T6 P330
vsbhda16.exe
