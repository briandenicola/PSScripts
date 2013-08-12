Option Explicit

Dim strComputer,strAppPool,strUserName,strPassword

Main 
WScript.Quit(0)

Function Main 

	ParseCmdLine strComputer,strAppPool, strUserName, strPassword

	WScript.Echo "Before . . . "
	Query(strAppPool)
	
	SetAppPool strComputer, strAppPool, strUserName, strPassword
	
	WScript.Echo "After . . . "
	Query(strAppPool)

End Function

Function ParseCmdLine(strComputer,strAppPool,strUserName,strPassword)
	
	Dim objArgs

	set objArgs = WScript.Arguments
	If objArgs.Count <> 4 Then
		Usage()
	Else
		strComputer = objArgs(0)
		strAppPool = objArgs(1)
		strUserName = objArgs(2)
		strPassword = objArgs(3)
	End IF

End Function

Function SetAppPool(strComputer,strAppPool,strUserName,strPassword)

	Dim objAppPool
	Set objAppPool = GetObject("IIS://" & strComputer & "/w3svc/AppPools/" & strAppPool )
	
	objAppPool.AppPoolIdentityType = 3
	objAppPool.WAMUserName = strUserName
	objAppPool.WAMUserPass = strPassword
	objAppPool.SetInfo()

End Function

Function Query(strAppPool)

	Dim objAppPool
	Set objAppPool = GetObject("IIS://" & strComputer & "/W3SVC/AppPools/" & strAppPool )

	WScript.Echo vbTab & vbTab & "<account>" & objAppPool.WAMUserName & "</account>"
	WScript.Echo vbTab & vbTab & "<processes>" & objAppPool.MaxProcesses  & "</processes>"
	IF objAppPool.apppoolstate = 4 Then
		WScript.Echo vbTab & vbTab & "<state>Stopped</state>"
	ELSEIF objAppPool.apppoolstate = 2 Then
		WScript.Echo vbTab & vbTab & "<state>Running</state>"
	ELSEIF objAppPool.apppoolstate = 1 Then
		WScript.Echo vbTab & vbTab & "<state>starting</state>"
	ELSE 
		WScript.Echo vbTab & vbTab & "<state>unknown</state> "
	End IF

End Function

Function Usage( )
	
    	WScript.StdOut.Write( "cscript set_apppool_account.vbs <server name> <app pool> <user name> <password>" ) 
	WScript.Quit(1)
	
End Function
