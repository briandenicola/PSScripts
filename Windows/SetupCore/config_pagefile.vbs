strComputer = "."
WScript.Echo "This script will setup the Windows Page File to be 2xRAM size"

Set objWMIService = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

Set wmiSystem = objWMIService.ExecQuery("Select * from WIN32_ComputerSystem")

For Each oSystem In wmiSystem
	iRAM = CInt(Round(oSystem.TotalPhysicalMemory/1048576))
Next 
iPageFile = iRAM*1.5

WScript.Echo "There is " & iRAM & "MB  in this system"

Set colPageFiles = objWMIService.ExecQuery ("Select * from Win32_PageFileSetting")
For Each objPageFile in colPageFiles
    WScript.Echo "Current Page File initial size is " & objPageFile.InitialSize & "MB"
    WScript.Echo "Current Page File maximum size is " & objPageFile.MaximumSize & "MB"
Next

WScript.Echo "Initial and Maxium Page File size will be set to " & iPageFile & "MB"

Set colPageFiles = objWMIService.ExecQuery ("Select * from Win32_PageFileSetting")
For Each objPageFile in colPageFiles
    objPageFile.InitialSize = iPageFile
    objPageFile.MaximumSize = iPageFile
    objPageFile.Put_
Next

