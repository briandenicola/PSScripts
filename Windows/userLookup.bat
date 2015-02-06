@echo off

set USER=%1
set DOMAIN=%2

IF NOT DEFINED USER (GOTO END)
IF DEFINED DOMAIN (GOTO FOREST)

echo **** Looking up %USER% ****
echo.
echo Fully Qualified Name - 
dsquery user -name %USER%*
echo.
echo Account Parameters - 
dsquery user -name %USER%* | dsget user -empid -sid -display -email -mustchpwd -disabled -pwdneverexpires -L -q
echo.
echo Group Membership - 
dsquery user -name %USER%* | dsget user -memberof -L -q
GOTO END

:FOREST
echo **** Looking up %USER% in %DOMAIN% ****
echo.
echo Fully Qualified Name - 
dsquery user forestroot -name %USER% -d %DOMAIN%
echo.
echo Account Parameters - 
dsquery user forestroot -name %USER% -d %DOMAIN% | dsget user -sid -display -email -mustchpwd -disabled -pwdneverexpires -L -q
echo.
echo Group Membership - 
dsquery user forestroot -name %USER% -d %DOMAIN% | dsget user -memberof -L -q


:END
