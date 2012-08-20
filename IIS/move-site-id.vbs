'See http://support.microsoft.com/?id=325056 for more reasons why you need this.

Dim WebService
Dim oldstr
Dim newstr
Dim args

Set args = WScript.Arguments

If args.Count < 1 Then
    Wscript.Echo "Must have original instance id and new instance id" &     chr(10) & chr(13) & _
    "usage:  moveinstance.vbs 1 5"  & chr(10) & chr(13) & _
"Moves instance 1 to instance 5"
    WScript.Quit()
End If

Set WebService = GetObject("IIS://LocalHost/W3SVC")

oldstr = args(0) 'old instance
newstr = args(1) 'new instance

WebService.MoveHere oldstr,newstr
WebService.SetInfo

Set WebService = nothing
Set args=nothing

WScript.echo "DONE"
