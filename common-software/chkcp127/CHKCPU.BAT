@echo off
if exist chkcpu.exe goto run
goto error

:run
chkcpu.exe /v
goto done

:error
@echo  =================================================
@echo  = ERROR: The Chkcpu.exe program was not found.  =
@echo  = Please copy Chkcpu.exe to the same folder as  =
@echo  = the Chkcpu.bat file and run Chkcpu.bat again. =
@echo  =================================================

:done
@echo.
pause
