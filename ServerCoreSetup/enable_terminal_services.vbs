Const ENABLE_CONNECTIONS = 1
 
strComputer = "."
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}\\" & strComputer & "\root\cimv2")

Set colItems = objWMIService.ExecQuery _
    ("Select * from Win32_TerminalServiceSetting")

For Each objItem in colItems
    errResult = objItem.SetAllowTSConnections(ENABLE_CONNECTIONS)
Next
