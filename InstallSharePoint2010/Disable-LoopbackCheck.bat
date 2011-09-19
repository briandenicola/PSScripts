@echo off

reg add HKLM\System\CurrentControlSet\Control\Lsa /t REG_DWORD /v DisableLoopbackCheck /d 1
