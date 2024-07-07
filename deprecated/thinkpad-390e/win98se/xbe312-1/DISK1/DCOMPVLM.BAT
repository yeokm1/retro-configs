@echo off
if ?==%1 goto help
if /?==%1 goto help
if %1x==x goto error
mkdir %1
if not exist xircom.dsk goto error2
expand ODI\LSL.CO_ %1\LSL.COM
if not exist %1\LSL.COM goto error2
copy ODI\CBEODI.COM %1\CBEODI.COM
copy ODI\NET.CFG %1\NET.CFG
expand ODI\IPXODI.CO_ %1\IPXODI.COM
expand ODI\VLM.EX_ %1\VLM.EXE
expand ODI\CONN.VL_ %1\CONN.VLM
expand ODI\FIO.VL_ %1\FIO.VLM
expand ODI\GENERAL.VL_ %1\GENERAL.VLM
expand ODI\IPXNCP.VL_  %1\IPXNCP.VLM
expand ODI\NDS.VL_ %1\NDS.VLM
expand ODI\BIND.VL_ %1\BIND.VLM
expand ODI\NETX.VL_ %1\NETX.VLM
expand ODI\NWP.VL_ %1\NWP.VLM
expand ODI\PRINT.VL_ %1\PRINT.VLM
expand ODI\REDIR.VL_ %1\REDIR.VLM
expand ODI\SECURITY.VL_ %1\SECURITY.VLM
expand ODI\TRAN.VL_ %1\TRAN.VLM
expand ODI\AUTO.VL_ %1\AUTO.VLM
goto end

:error3
echo An invalid directory path has been specified. Please
echo specify a legal path in the command line parameter.
echo Example: DCOMPVLM C:\NWCLIENT
goto end

:error2
echo An error occured while copying and expanding files please change
echo directory and execute DCOMPVLM from original location on Xircom
echo floppy diskette.
goto end

:error
echo The file destination path must be given in the command line
echo in the form DCOMPVLM DESTINATION_PATH.
echo Example: DCOMPVLM C:\NWCLIENT

goto end

:help
echo A file destination path must be given in the command line
echo in the form DCOMPVLM DESTINATION_PATH.
echo Example: DCOMPVLM C:\NWCLIENT

:end
