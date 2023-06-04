@echo off
rem NM2070 errorlevel = 1
rem NM2090 errorlevel = 2
rem NM2093 errorlevel = 3
nmid1
if errorlevel == 3 goto prog3
if errorlevel == 2 goto prog2
if errorlevel == 1 goto prog1
goto eoj
:prog1
for %%a in (30G0???A.*) do PHLASH %%a
goto eoj
:prog3
for %%a in (30G0???B.*) do PHLASH %%a
goto eoj
:prog2
:eoj
