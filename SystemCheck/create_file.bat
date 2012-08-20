@echo off

set FILENAME=%1
set SIZE=%2

fsutil file createnew %FILENAME% %SIZE%000000