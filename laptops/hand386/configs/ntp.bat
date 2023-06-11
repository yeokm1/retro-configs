@echo off
sntp -set sg.pool.ntp.org
if errorlevel 0 d:\drivers\rtcm8088\set_rtc.exe 576