Option Explicit

Dim strComputer

'+--------------------------------------------------------------------------------------------------------------------------------
'| CALL MAIN FUNCTION
'+--------------------------------------------------------------------------------------------------------------------------------
Main 
WScript.Quit(0)

Function Main 
	
	'On Error Resume Next
	Dim IIsObject,obj

	'+--------------------------------------------------------------------------------------------------------------------------------
	'| GATHER COMMAND LINE VARIABLES 
	'+--------------------------------------------------------------------------------------------------------------------------------
	ParseCmdLine strComputer

	Wscript.Echo "<VirtualDirectories>"
	QueryIisVirtualDirectory(strComputer)
	Wscript.Echo "</VirtualDirectories>"

End Function

'+--------------------------------------------------------------------------------------------------------------------------------
'| FUNCTION	> ParseCmdLine
'| PURPOSE	> To gather command line options passed with this script
'| RETURNS	> Nothing but assigns the strComputer, strUsr, strPassword, strFile variables
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
'| FUNCTION	> Usage
'| PURPOSE	> Echos the usage to the user and exits 
'| RETURNS	> Nothing 
'+--------------------------------------------------------------------------------------------------------------------------------
Sub Usage( )
	
    	WScript.StdOut.Write( "cscript query_virtual_dirs.vbs <server name>" ) 
	WScript.Quit(1)
	
End Sub

Function QueryIisVirtualDirectory(strComputer)

	Dim objWMIService, colItems, objItem

	Set objWMIService = GetObject ("winmgmts:{authenticationLevel=pktPrivacy}\\" & strComputer & "\root\microsoftiisv2")
	
	Set colItems = objWMIService.ExecQuery  ("Select * from IIsWebVirtualDirSetting")
 
	For Each objItem in colItems
		WScript.Echo "<VirtualDirectory>"
			Wscript.Echo chr(9) & "<Name>" & objItem.Name & "</Name>"
			Wscript.Echo chr(9) & "<Description>" & objItem.Description & "</Description>"
			Wscript.Echo chr(9) & "<FriendlyName>" & objItem.AppFriendlyName & "</FriendlyName>"
			Wscript.Echo chr(9) & "<Path>" & objItem.Path & "</Path>"
			Wscript.Echo chr(9) & "<SiteName>" & QuerySiteName(objItem.Name) & "</SiteName>"
			Wscript.Echo chr(9) & "<AppPoolId>" & objItem.AppPoolId & "</AppPoolId>"
			Wscript.Echo chr(9) & "<AppPoolAccount>" & QueryAppPool(objItem.AppPoolId) & "</AppPoolAccount>"
			Wscript.Echo chr(9) & "<AccessSSL>" & objItem.AccessSSL & "</AccessSSL>"
			Wscript.Echo chr(9) & "<AccessSSL128>" & objItem.AccessSSL128 & "</AccessSSL128>"
			Wscript.Echo chr(9) & "<AccessSSLFlags>" & objItem.AccessSSLFlags & "</AccessSSLFlags>"
			Wscript.Echo chr(9) & "<RequireSSLCertificate>" &  objItem.AccessSSLRequireCert & "</RequireSSLCertificate>"
			Wscript.Echo chr(9) & "<AnonymousUserName>" & objItem.AnonymousUserName & "</AnonymousUserName>"
			Wscript.Echo chr(9) & "<AnonymousPasswordSync>" & objItem.AnonymousPasswordSync & "</AnonymousPasswordSync>"
			Wscript.Echo chr(9) & "<AllowSessionState>" & objItem.AspAllowSessionState & "</AllowSessionState>"
			Wscript.Echo chr(9) & "<NTAuthenticationProviders>" &  objItem.NTAuthenticationProviders & "</NTAuthenticationProviders>"
			Wscript.Echo chr(9) & "<Authentication>"
			Wscript.Echo chr(9) & chr(9) & "<Anonymous>" & objItem.AuthAnonymous & "</Anonymous>"
			Wscript.Echo chr(9) & chr(9) & "<Basic>" & objItem.AuthBasic & "</Basic>"
			Wscript.Echo chr(9) & chr(9) & "<MD5>" & objItem.AuthMD5 & "</MD5>"
			Wscript.Echo chr(9) & chr(9) & "<NTLM>" & objItem.AuthNTLM & "</NTLM>"
			Wscript.Echo chr(9) & "</Authentication>" 
			Wscript.Echo chr(9) & "<CGITimeout>" & objItem.CGITimeout & "</CGITimeout>"
			Wscript.Echo chr(9) & "<CreateProcessAsUser>" & objItem.CreateProcessAsUser & "</CreateProcessAsUser>"
			Wscript.Echo chr(9) & "<EnableDirectoryBrowsing>" & objItem.EnableDirBrowsing & "</EnableDirectoryBrowsing>"
			Wscript.Echo chr(9) & "<EnableDefaultDoc>" & objItem.EnableDefaultDoc & "</EnableDefaultDoc>"
			Wscript.Echo chr(9) & "<DefaultDoc>" & objItem.DefaultDoc & "</DefaultDoc>"
			Wscript.Echo chr(9) & "<EnableDocFooter>" & objItem.EnableDocFooter & "</EnableDocFooter>"
			Wscript.Echo chr(9) & "<DefaultDocFooter>" & objItem.DefaultDocFooter & "</DefaultDocFooter>"
			Wscript.Echo chr(9) & "<DefaultLogonDomain>" & objItem.DefaultLogonDomain & "</DefaultLogonDomain>"
			Wscript.Echo chr(9) & "<DirectoryBrowse>" & objItem.DirBrowseFlags & "</DirectoryBrowse>"
			Wscript.Echo chr(9) & "<DynamicCompression>" & objItem.DoDynamicCompression & "</DynamicCompression>"
			Wscript.Echo chr(9) & "<StaticCompression>" & objItem.DoStaticCompression & "</StaticCompression>"
			Wscript.Echo chr(9) & "<EnableReverseDns>" & objItem.EnableReverseDns & "</EnableReverseDns>"
		WScript.Echo "</VirtualDirectory>"
	Next
End Function

Function QueryAppPool(strAppPool)

	On Error Resume Next
	Dim objAppPool
	Set objAppPool = GetObject("IIS://" & strComputer & "/W3SVC/AppPools/" & strAppPool )

	QueryAppPool = objAppPool.WAMUserName 

	'WScript.Echo objAppPool.WAMUserPass
End Function

Function QuerySitename(strSitename)

	On Error Resume Next
	Dim objSite,SiteLength,LastOccurence,diff

	SiteLength = Len("W3SVC") + 2
	LastOccurence = Instr(SiteLength,strSiteName,"/")
	diff = LastOccurence - SiteLength
	
	Set objSite = GetObject("IIS://" & strComputer & "/W3SVC/" & Mid(strSitename,Sitelength,diff))

	QuerySitename = objSite.ServerComment

End Function
