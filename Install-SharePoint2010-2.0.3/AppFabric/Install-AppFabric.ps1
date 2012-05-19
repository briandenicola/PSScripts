copy \\ent-nas-fs01.us.gt.com\app-ops\Installs\WindowsServerAppFabricSetup_x64_6.1.exe D:\Deploy\
powershell.exe -ImportSystemModules -command { Add-WindowsFeature  AS-Web-Support;  Add-WindowsFeature  AS-HTTP-Activation }

D:\Deploy\WindowsServerAppFabricSetup_x64_6.1.exe /install HostingServices

while( (Get-Process | where { $_.ProcessName -eq "WindowsServerAppFabricSetup_x64_6.1" }) -ne $nul)
{ 
	Write-Host -NoNewline "."
	Sleep 5
}