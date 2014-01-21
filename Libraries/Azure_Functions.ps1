Write-Host $(Get-Date) " - Importing Azure Module " -foreground green

Push-Location $PWD.Path
Get-ChildItem 'C:\Program Files (x86)\Microsoft SDKs\Windows Azure\PowerShell\Azure\*.psd1' | ForEach-Object {Import-Module $_}

Write-Host $(Get-Date) " - Importing Office 365 Modules" -foreground green
Import-Module MSOnline -DisableNameChecking
Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking
Pop-Location 