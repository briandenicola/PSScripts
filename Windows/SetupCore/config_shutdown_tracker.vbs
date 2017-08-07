strComputer = "."  

intEnable = 0      ' 0 = disable; 1 = enable screen

const HKLM = &H80000002
strKeyPath = "SOFTWARE\Policies\Microsoft\Windows NT\Reliability"

set objReg = GetObject("winmgmts:\\" & strComputer &  "\root\default:StdRegProv")

intRC1 = objReg.CreateKey(HKLM,strKeyPath)
intRC2 = objReg.SetDwordValue(HKLM, strKeyPath, "ShutdownReasonOn", intEnable)

if intRC1 <> 0 or intRC2 <> 0 then
   WScript.Echo "Error setting registry value: " & intRC
else
   WScript.Echo "Successfully disabled shutdown tracker"
end if
