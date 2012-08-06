@echo off

SET SERVER=%1

IF NOT DEFINED SERVER ( for /f %%a in ('hostname') do SET SERVER=%%a)

reg query \\%SERVER%\HKLM\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo\


:END
