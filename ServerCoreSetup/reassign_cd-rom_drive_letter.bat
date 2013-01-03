@echo off

set VOL=
set CDROM=
set CDROM-LETTER=Z

IF EXIST %TEMP%\diskpart.tmp (del %TEMP%\diskpart.tmp)

echo list volume > %TEMP%\diskpart.tmp

for /f "tokens=1-4,* delims= " %%a in ('diskpart /s %TEMP%\diskpart.tmp ^| findstr /i ROM') do (set VOL=%%b) && set CDROM=%%c
 
echo Will move CD-ROM to Letter %CDROM-LETTER%
IF NOT %CDROM% == %CDROM-LETTER% (
	
	IF EXIST %TEMP%\diskpart.tmp (del %TEMP%\diskpart.tmp)
	
	echo select volume %VOL% > %TEMP%\diskpart.tmp
	echo assign letter=%CDROM-LETTER% >> %TEMP%\diskpart.tmp
	
	diskpart /s %TEMP%\diskpart.tmp
) ELSE (
	echo CD-ROM is already assigned Letter %CDROM-LETTER%
)

IF EXIST %TEMP%\diskpart.tmp (del %TEMP%\diskpart.tmp)

:END
