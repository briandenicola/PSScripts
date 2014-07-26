$dst = "D:\Web\Monitoring"
$src = Join-Path $PWD.Path "Site"

New-Item -Path $dst -ItemType Directory
Copy-Item "$src\*.*" -Destination $dst -Verbose -Recurse
..\WebFarm\Create-IIS-WebApplication.ps1 -config .\monitor.xml 