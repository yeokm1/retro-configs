@echo off
sntp -set sg.pool.ntp.org
if errorlevel 0 D:\DRIVERS\RTCM8088\SET_RTC.EXE 576