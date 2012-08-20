Option Explicit

Dim strComputer
Dim arrayIPs(10), numOfIpAddresses

const IIS5="IIS5 Web Server"
Const wbemFlagReturnImmediately = &h10
Const wbemFlagForwardOnly = &h20

'+--------------------------------------------------------------------------------------------------------------------------------
'| CALL MAIN FUNCTION
'+--------------------------------------------------------------------------------------------------------------------------------
Main 
WScript.Quit(0)

Function Main 
	
	'On Error Resume Next
	
	Dim IIsObject,obj, IIsObjectPath, BindingPath, IISObjectIP, IISObjectRoot
	Dim ValueIndex,ValueList, ValueString, value, Values, IP, TCP, HostHeader
	Dim oWMIService,objNetCard, colNetCards, IpAddress

	Dim xml,i

	'+--------------------------------------------------------------------------------------------------------------------------------
	'| GATHER COMMAND LINE VARIABLES 
	'+--------------------------------------------------------------------------------------------------------------------------------
	ParseCmdLine strComputer

	'+--------------------------------------------------------------------------------------------------------------------------------
	'| QUERY WMI FOR NETWORKING INFORMATION ( IP ADDRESS AND MAC ADDRESS ) 
	'+--------------------------------------------------------------------------------------------------------------------------------
	Set oWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" + strComputer + "\root\cimv2")
	Set colNetCards = oWMIService.ExecQuery("Select * From Win32_NetworkAdapterConfiguration Where IPEnabled = True")

	For Each objNetCard in colNetCards
		If Not IsNull(objNetCard.IPAddress) Then 
	       	For i=LBound(objNetCard.IPAddress) to UBound(objNetCard.IPAddress)
				If InStr( objNetCard.IPAddress(i), "0.0.0.0"  ) Then
				Else
					AssignIp( objNetCard.IPAddress(i) )
				End If
	       	Next
		End If	
	Next
	
	For i = 0 To numOfIpAddresses-1
		IpAddress = IpAddress & chr(9) & "<IpAddress>" & arrayIps(i) & "</IpAddress>" & VBCrLf
	Next 

	'Set oWMIService = GetObject ("winmgmts:\\"  & strComputer & "\root\microsoftiisv2")
	Set oWMIService = GetObject ("winmgmts:{authenticationLevel=pktPrivacy}\\" & strComputer & "\root\microsoftiisv2")
	If Err.Number <> 0 Then
		WScript.StdOut.Write( "<Server name=" & chr(34) & strComputer & chr(34) & ">" & VBCrLf )
		WScript.StdOut.Write( chr(9) & "<IpAddresses/>" & VBCrLf )
		WScript.StdOut.Write( chr(9) & "<site name=" & chr(34) & IIS5 & chr(34) & "/>" & VBCrLf )
		WScript.StdOut.Write( "</Server>" )
		WScript.Quit(0)
		Err.Clear
	End If

	IIsObjectPath = "IIS://" & strComputer & "/W3SVC"
	
	Set IIsObject = GetObject("IIS://" & strComputer & "/W3SVC")

	WScript.StdOut.Write( "<Server name=" & chr(34) & strComputer & chr(34) & ">" & VBCrLf )
	
	Dim colItems,objItem
	Set colItems = oWMIService.ExecQuery  ("Select * from IIsWebServiceSetting")
	For Each objItem in colItems
		Wscript.Echo chr(9) & "<Authentication>"
		Wscript.Echo chr(9) & chr(9) & "<Anonymous>" & objItem.AuthAnonymous & "</Anonymous>"
		Wscript.Echo chr(9) & chr(9) & "<Basic>" & objItem.AuthBasic & "</Basic>"
		Wscript.Echo chr(9) & chr(9) & "<MD5>" & objItem.AuthMD5 & "</MD5>"
		Wscript.Echo chr(9) & chr(9) & "<NTLM>" & objItem.AuthNTLM & "</NTLM>"
		Wscript.Echo chr(9) & "</Authentication>" 
	Next

	
	WScript.StdOut.Write( "<IpAddresses>" & VBcrLf  & Trim(IpAddress) &  VBCrLf & "</IpAddresses>" & VBCrLf )
	WScript.StdOut.Write( "<Sites>" & VBCrLf )

	for each obj in IISObject
		If (Obj.Class = "IIsWebServer") then

			BindingPath = IIsObjectPath & "/" & Obj.Name

			Set IIsObjectIP = GetObject(BindingPath)
			Set IIsObjectRoot = GetObject(BindingPath & "/root" )

			xml = chr(9) & "<site name=" & chr(34) & IISObjectIP.ServerComment & chr(34) & "  id=" & chr(34) & obj.Name & chr(34) & ">" & VBCrLf &_
				chr(9) & chr(9) & "<logs_dir>" & IIsObjectIP.LogFileDirectory & "\W3SVC" & obj.Name & "</logs_dir>" & VBCrLf &_
				chr(9) & chr(9) & "<anonymous_user>" & IIsObjectRoot.AnonymousUserName & "</anonymous_user>" & VBCrLf &_
				chr(9) & chr(9) & "<HomeDirectory>" &  IIsObjectRoot.Path & "</HomeDirectory>" & VBCrLf &_
				chr(9) & chr(9) & "<hostheaders>" & VBCrLf 
		
			ValueList = IISObjectIP.Get("ServerBindings")
			ValueString = ""
			
			For ValueIndex = 0 To UBound(ValueList)
				value = ValueList(ValueIndex)
				Values = split(value, ":")
				IP = values(0)
				if (IP = "") then
					IP = "(All Unassigned)"
				end if
				TCP = values(1)
				if (TCP = "") then
					TCP = "80"
				end if
				HostHeader = values(2)

				if (HostHeader <> "") then
					xml = xml & chr(9) & chr(9) & chr(9) & "<header name=" & chr(34) & HostHeader & chr(34) & " ip=" & chr(34) & IP & chr(34) & " port=" & chr(34) & TCP & chr(34) & "/>" & VbCrLf
				else
					xml = xml & chr(9) & chr(9) & chr(9) &  "<header name=" & chr(34) &  chr(34) & " ip=" & chr(34) & IP & chr(34) & " port=" & chr(34) & TCP & chr(34) & "/>" & VbCrLf 
				end if
				
			Next
			xml = xml & chr(9) & chr(9) & "</hostheaders>" & VBCrLf
			xml = xml & chr(9) & "</site>" & VBCrLf

			WScript.StdOut.Write( xml )
			
			set IISObjectIP = Nothing

		end if
	next
	WScript.StdOut.Write( "</Sites>" & VBCrLf )

	CallVirtualDirectories strComputer

	WScript.StdOut.Write( "</Server>" & VBCrLf )

	set IISObject = Nothing
End Function

Function CallVirtualDirectories(strComputer)
	Dim oShell, vbsScript
	Set oShell = CreateObject("Wscript.Shell")
	Set vbsScript = oShell.Exec("cscript //NoLogo .\query_virtual_dir.vbs " & strComputer)
	WScript.Echo vbsScript.stdOut.ReadAll()
End Function


'+--------------------------------------------------------------------------------------------------------------------------------
'| FUNCTION	: AssignIp
'| PURPOSE	: Because WMI returns a result set that may contain the same IP mutliple times, this functions eliminates the redundancies
'| RETURNS	: N/A
'+--------------------------------------------------------------------------------------------------------------------------------
Function AssignIp( ip ) 

	Dim i
	For i = 0 to numOfIpAddresses 
		If Cstr(ip) = Cstr(arrayIPs(i)) Then
			Exit Function
		End If
	Next

	arrayIPs(numOfIpAddresses) = ip
	numOfIpAddresses = numOfIpAddresses + 1

End Function

'+--------------------------------------------------------------------------------------------------------------------------------
'| FUNCTION	: ParseCmdLine
'| PURPOSE	: To gather command line options passed with this script
'| RETURNS	: Nothing but assigns the strComputer, strUsr, strPassword, strFile variables
'+--------------------------------------------------------------------------------------------------------------------------------
Function ParseCmdLine(strComputer)
	
	Dim objArgs

	set objArgs = WScript.Arguments
	If objArgs.Count <> 1 Then
		Usage()
	Else
		strComputer = objArgs(0)
	End IF

End Function


'+--------------------------------------------------------------------------------------------------------------------------------
'| FUNCTION	: Usage
'| PURPOSE	: Echos the usage to the user and exits 
'| RETURNS	: Nothing 
'+--------------------------------------------------------------------------------------------------------------------------------
Sub Usage( )
	virtual_dir
    WScript.StdOut.Write( "cscript iis_websites.vbs <server name>" ) 
	WScript.Quit(1)
	
End Sub

