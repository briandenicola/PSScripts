@echo off

powershell.exe -NoExit -NoProfile -Command "&{ Set-ExecutionPolicy unrestricted; Start-Process Powershell.exe -Verb RunAs}"