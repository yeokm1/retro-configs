@echo %1%4
if not exist %1%2 goto l1
if exist %1%3 goto l2
if not exist %1%4 goto l2
copy %1%4 %1%3 >nul
:l2
if not exist %1%4 goto l3
del %1%4
:l3
ren %1%2 %4
if not exist %1%2 goto l1
if not exist %1%4 goto l5
echo on
attrib -r %1%4
del %1%4
ren %1%2 %4
@echo off
if not exist %1%2 goto l1
:l5
echo.
echo Cannot rename %1%2 to %4
echo NetWare Mobile file installation will be incomplete.
pause
:l1
