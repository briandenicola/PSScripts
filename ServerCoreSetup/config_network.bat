@echo off

REM Author: Brian Denicola
REM Version: 1.70
REM Purpose: This script setups up a network interface 
REM	It will set the IP, Subnet mask. It will also 
REM	set the Gateway and Domain Name if supplied
REM	The script will check to see where is the IP
REM	address. If it is in the 10.138 subnet, then
REM	it will set the DNS/WINS to the L3. 
REM Requirements: Must be running Win2k

REM Flush out all variables
set IP=
set MASK=
set TMP1=
set TMP2=
set GATEWAY=
set DOMAIN=
set DNS1=
set VERSION=

:MAIN
set IP=%1
set MASK=%2
set GATEWAY=%3
set DNS1=%4

if NOT DEFINED IP (goto ERROR)
if NOT DEFINED MASK (goto ERROR)
If NOT DEFINED GATEWAY ( goto ERROR )
If NOT DEFINED DNS1 ( goto ERROR )

GOTO SETIP

:SETIP
echo These are the interfaces that are currently configured on your system
echo -----------------------------------------
netsh interface show interface 

echo -----------------------------------------
set /P INTERFACE=Please enter an interfaces to configure:
echo Using Interface:%INTERFACE%

set INTERFACE="%INTERFACE%"
netsh interface ip set address name=%INTERFACE% static %IP% %MASK% %GATEWAY% 1
goto SETDNS

:SETDNS
netsh interface ip set dns name=%INTERFACE% source = static addr = %DNS1%
netsh interface ip add dns %INTERFACE% %DNS2% index=2

goto END

:ERROR
echo.
echo This script requires Windows 2000 or Greater
echo Syntaxt: network.bat 
echo	Require: [IP Address] [Subnet mask] [Gateway] [DNS]
echo	Note - Order of options is important.
goto SKIP

:END
netsh interface ip show config

:SKIP
