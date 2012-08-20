strComputer = WScript.Arguments.Item(0)

Set objSession = CreateObject("Microsoft.Update.Session", strComputer)
Set objSearcher = objSession.CreateUpdateSearcher
intHistoryCount = objSearcher.GetTotalHistoryCount

Set colHistory = objSearcher.QueryHistory(1, intHistoryCount)
For Each objEntry in colHistory
    Wscript.Echo objEntry.Date & "," & strComputer & "," & objEntry.Title
Next


