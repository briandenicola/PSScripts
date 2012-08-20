Set us = CreateObject("Microsoft.Update.Session")
Set updates = CreateObject("Microsoft.Update.UpdateColl")
Set download = us.CreateUpdateDownloader()
Set usearch = us.CreateupdateSearcher()
'Set usresult = usearch.Search("IsInstalled=0 and Type='High Priority'")
Set usresult = usearch.Search("IsInstalled=0 and Type='Software'")
'Set usresult = usearch.Search("IsInstalled=0 and Type='Hardware'")

For a = 0 to usresult.Updates.Count - 1
   Set patch = usresult.Updates.Item(a)
   updates.Add(patch)
   WScript.Echo "Patch Title: " & updates.Item(a).Title
Next 
