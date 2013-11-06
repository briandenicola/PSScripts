New-Item -Path D:\Web\Monitoring -ItemType Directory
Copy .\monitor.aspx D:\Web\Monitoring\.
Copy .\monitor.html D:\Web\Monitoring\.

$current = $PWD.Path
..\..\Install-DotNet-WebFarm\Create-IIS-WebApplication.ps1 -config .\monitor.xml -nofarm 