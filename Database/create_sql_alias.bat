@echo off

SET NAME=%1
SET CONSTR=%2
SET PORT=%3
SET SERVER=%4


IF NOT DEFINED NAME ( GOTO USAGE )
IF NOT DEFINED CONSTR ( GOTO USAGE )
IF NOT DEFINED NAME ( GOTO USAGE )
IF NOT DEFINED PORT ( SET PORT=1433 )
IF NOT DEFINED SERVER ( for /f %%a in ('hostname') do SET SERVER=%%a)

echo Updating registry - { reg add \\%SERVER%\HKLM\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo\ /v %NAME% /t REG_SZ /d DBMSSOCN,%CONSTR%,%PORT% }
reg add \\%SERVER%\HKLM\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo\ /v %NAME% /t REG_SZ /d DBMSSOCN,%CONSTR%,%PORT%

GOTO END

:USAGE
echo create_sql_alias.bat NAME CONNECTION_STRING [PORT] [SERVER]

:END
