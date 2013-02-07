@echo off

set DST=D:\Scripts\Install-SharePoint2013\
set SRC=\\ent-nas-fs01\app-ops\Installs\SharePoint\Install-SharePoint2013

xcopy /e/v/f/s %SRC% %DST%

echo Next Steps . . .
echo 1) Edit .\configs\master_setup.xml appropriate for the environment
echo 2) Run .\1_SPFarm-Master_Install.ps1

powershell.exe -NoExit -NoProfile -Command "&{ param ( [string] $directory ); Set-ExecutionPolicy unrestricted; Start-Process Powershell.exe -Verb RunAs -WorkingDirectory $directory;}" %DST%