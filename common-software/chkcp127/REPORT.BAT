@echo off
@echo  ==============================================================================
@echo  =                          Chkcpu Report generator                           =
@echo  ==============================================================================
@echo.

if exist chkcpu.exe goto doschk
goto error

:doschk
chkcpu.exe /s
@echo  CPU Found!
chkcpu.exe >> mycpu.txt
chkcpu.exe /i >> mycpu.txt
chkcpu.exe /v >> mycpu.txt
chkcpu.exe /d >> mycpu.txt
@echo. >> mycpu.txt
chkcpu.exe /s >> mycpu.txt
@echo. >> mycpu.txt

@echo.
@echo  ==============================================================================
@echo  = A report log of this CPU has been made and stored in the file mycpu.txt.   =
@echo  = In case of problems with Chkcpu, please send this report to the author.    =
@echo  = The e-mail address is:  J.Steunebrink@net.hcc.nl                           =
@echo  = Thanks for your cooperation! Your report will be used to improve Chkcpu.   =
@echo  = Regards, Jan Steunebrink.                                                  =
@echo  ==============================================================================
goto done

:error
@echo  ==============================================================================
@echo  = ERROR: The Chkcpu.exe program was not found. No report was generated.      =
@echo  = Please copy Chkcpu.exe to the same folder as the Report.bat file and       =
@echo  = run Report.bat again.                                                      =
@echo  ==============================================================================

:done
@echo.
pause
