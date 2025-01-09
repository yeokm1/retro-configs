echo off
echo 
echo mTCP Services by M Brutman (mbbrutman@gmail.com) (C)opyright 2024
echo   Version: Oct 20 2024
echo 
if "%1"=="version" goto version
if "%1"=="quote" goto quote
if "%1"=="fortune" goto fortune
if "%1"=="time" goto time
if "%1"=="help" goto help
if "%1"=="" goto help
echo Trying off-menu "%1" command to see if it works ...
echo If it does not work use the help command to see what is available.
echo %1 %2 %3 %4 %5 > services.$$$
goto nc
:version
echo Checking to see if your version is up to date.
echo Connecting to brutman.com on port 8088 ...
echo Version > services.$$$
goto nc
:quote
echo Getting quote ...
echo Quote > services.$$$
goto nc
:fortune
echo Getting fortune cookie ...
echo Fortune > services.$$$
goto nc
:time
echo Getting the time (Universal Coordinated Time) ...
echo Time > services.$$$
goto nc
:help
echo Usage: services command
echo 
echo Commands are:
echo 
echo   help:    This help text
echo   version: See if there is a new version of mTCP.
echo   quote:   Get a random quote.
echo   fortune: Fortune cookie server!
echo   time     Get the time (Universal Coordinated Time)
echo 
echo mTCP must be ready to run for this to work.  (Your packet
echo driver must be loaded, the MTCPCFG environment variable
echo must be set, and your networking parameters must be setup.)
echo 
echo (Note for floppy users: this slow because it uses a temp file)
goto end
:nc
echo Protocol_Version 1 >> services.$$$
echo Client_Date 2024-10-20 >> services.$$$
echo Done >> services.$$$
echo 
echo Server response:
echo 
set NC_SILENT=1
nc -target brutman.com 8088 -w 8 -timeout 5 < services.$$$
set NC_SILENT=
if errorlevel 4 goto server
if errorlevel 3 goto neterror
if errorlevel 1 goto setuperr
goto end
:server
echo We connected but the server timed out!  Please try again later.
goto end
:neterror
echo Connectivity error!  services.bat could not connect to brutman.com
echo on port 8088.  Is your networking setup and DNS working?  (Try pinging
echo google.com to ensure everything is working.)
goto end
:setuperr
echo Setup error; could not start nc - Is mTCP configured, your packet
echo driver loaded, and your IP address already set?
goto end
:end
echo 

