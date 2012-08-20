set objArgs = WScript.Arguments
strComputer = objArgs(0)

Set oWMIService = GetObject ("winmgmts:{authenticationLevel=pktPrivacy}\\" & strComputer & "\root\microsoftiisv2")
	
WScript.Echo "IIS Server Level Setting"
Set colItems = oWMIService.ExecQuery  ("Select * from IIsWebServiceSetting")

For Each objItem in colItems
	WScript.Echo objItem.Name
	Wscript.Echo chr(9) & chr(9) & "<Anonymous>" & objItem.AuthAnonymous & "</Anonymous>"
	Wscript.Echo chr(9) & chr(9) & "<Basic>" & objItem.AuthBasic & "</Basic>"
	Wscript.Echo chr(9) & chr(9) & "<MD5>" & objItem.AuthMD5 & "</MD5>"
	Wscript.Echo chr(9) & chr(9) & "<NTLM>" & objItem.AuthNTLM & "</NTLM>"
Next

WScript.Echo "IIS Site Level Setting"
Set colItems = oWMIService.ExecQuery  ("Select * from IIsWebServerSetting")
WScript.Echo "Executed Query"

For Each objItem in colItems
	WScript.Echo objItem.Name
	Wscript.Echo chr(9) & chr(9) & "<Anonymous>" & objItem.AuthAnonymous & "</Anonymous>"
	Wscript.Echo chr(9) & chr(9) & "<Basic>" & objItem.AuthBasic & "</Basic>"
	Wscript.Echo chr(9) & chr(9) & "<MD5>" & objItem.AuthMD5 & "</MD5>"
	Wscript.Echo chr(9) & chr(9) & "<NTLM>" & objItem.AuthNTLM & "</NTLM>"
Next

WScript.Echo "IIS Virtual Directory Level Setting"
Set colItems = oWMIService.ExecQuery  ("Select * from IIsWebVirtualDirSetting")
For Each objItem in colItems
	Wscript.Echo objItem.Name
	Wscript.Echo chr(9) & chr(9) & "<Anonymous>" & objItem.AuthAnonymous & "</Anonymous>"
	Wscript.Echo chr(9) & chr(9) & "<Basic>" & objItem.AuthBasic & "</Basic>"
	Wscript.Echo chr(9) & chr(9) & "<MD5>" & objItem.AuthMD5 & "</MD5>"
	Wscript.Echo chr(9) & chr(9) & "<NTLM>" & objItem.AuthNTLM & "</NTLM>"
Next

