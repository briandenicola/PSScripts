strKey = "HKLM\Software\Microsoft\PCHealth\ErrorReporting\DoReport"
strType = "REG_DWORD" 
strValue = "0"

Set WSHShell = WScript.CreateObject("WScript.Shell")
WSHShell.RegWrite strKey, strValue, strType

MsgBox "Error Reporting Is Disabled"

