'=========================================================================
' VBScript Source File
'
' AUTHOR:  Stewart Brown 
' COMPANY: Jamzar Web Design
' WEBSITE: blog.jamzarwebdesign.com.au
' DATE:    4/11/2011
' COMMENT: Will display the SharePoint 2010 License Key.
'
'		   Found original code on internet but can't remember where I 
'          found it so I'm not sure who to thank.
'		   If you own this code and can prove it, then please leave a 
'          message on blog and once confirmed I will update this code.
'=========================================================================
const HKEY_LOCAL_MACHINE = &H80000002  
 strKeyPath = "SOFTWARE\Microsoft\Office\14.0\Registration\{90140000-110D-0000-1000-0000000FF1CE}"
 strValueName = "DigitalProductId" 
 strComputer = "." 
 dim iValues() 
 Set oReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & _  
       strComputer & "\root\default:StdRegProv") 
 oReg.GetBinaryValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,iValues 
 Dim arrDPID 
 arrDPID = Array() 
 For i = 808 to 822
 ReDim Preserve arrDPID( UBound(arrDPID) + 1 ) 
 arrDPID( UBound(arrDPID) ) = iValues(i) 
 Next 

 Dim arrChars 
 arrChars = Array("B","C","D","F","G","H","J","K","M","P","Q","R","T","V","W","X","Y","2","3","4","6","7","8","9") 
  
 For i = 24 To 0 Step -1 
 k = 0 
 For j = 14 To 0 Step -1 
  k = k * 256 Xor arrDPID(j) 
  arrDPID(j) = Int(k / 24) 
  k = k Mod 24 
 Next 
 strProductKey = arrChars(k) & strProductKey 
 If i Mod 5 = 0 And i <> 0 Then strProductKey = "-" & strProductKey 
 Next 
 strFinalKey = strProductKey 

 Set wshShell=CreateObject("wscript.shell") 
 strPopupMsg = "Your Microsoft SharePoint 2010 Product Key is:" & vbNewLine & vbNewLine & strFinalKey 
 wscript.echo strPopupMsg
 WScript.Quit