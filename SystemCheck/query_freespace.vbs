' Script to remotely determine the amount of free space on all drives
' on a system

set objArgs = WScript.Arguments
noHeader = 0 

IF objArgs.count = 1 Then
	strComputer = objArgs(0)	
ElseIf objArgs.count = 2 Then
	strComputer = objArgs(0)	
	noHeader = 1	
Else	
	Usage()
    	WScript.Quit(1)
End IF

set oWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" + strComputer + "\root\cimv2")

'Set colDisks = oWMIService.ExecQuery("Select * from WIN32_LogicalDisk")
Set colDisks = oWMIService.ExecQuery("Select * from WIN32_Volume")

IF noHeader = 0 Then
	WScript.StdOut.Write( "Computer Name, Volume Name,Total Space,Free Space" & VbCrLf )
End IF

For Each oDisk In colDisks
	If oDisk.DriveType = 3 Then
		'WScript.StdOut.Write( strComputer & "," & oDisk.Name & "," & Int(oDisk.Size/1048576) & "," & Int(oDisk.FreeSpace/1048576) &  VbCrLf )
		WScript.StdOut.Write( strComputer & "," & oDisk.Name & "," & Int(oDisk.Capacity/1048576) & "," & Int(oDisk.FreeSpace/1048576) &  VbCrLf )
 	End If
Next

Set colVolume = oWMIService.ExecQuery("Select * from Win32_Volume WHERE DriveLetter IS NULL")

For Each oVol In colVolume 
	WScript.StdOut.Write( strComputer & "," & oVol.Name & "," & Int(oVol.Capacity/1048576) & "," & Int(oVol.FreeSpace/1048576) &  VbCrLf )
Next


Sub Usage( )
    WScript.StdOut.Write( "cscript query_freespace.vbs <server name>" & VbCrLf ) 
End Sub

