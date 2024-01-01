@echo off
@del logo.mod
@chkbmp logo.bmp
@if ERRORLEVEL 1 GOTO ERROR
@prepare logo.scr
@goto END
:Error
@echo LOGO.BMP file is not found or is not correct.
:END
