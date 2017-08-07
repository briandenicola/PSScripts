param (
 [Parameter(Mandatory=$true)]
 [string] $computer_name,

 [Parameter(Mandatory=$true)]
 [string] $ip,

 [Parameter(Mandatory=$true)]
 [string] $gw = "10.2.1.1",

 [Parameter(Mandatory=$true)]
 [string] $dns = "10.2.1.2",

 [Parameter(Mandatory=$true)]
 [string] $domain = "sharepoint.test"
)

ImportSystemModules 

$cred = Get-Credential 

Write-Host "[ $(Get-Date) ] - Changing $ENV:COMPUTERNAME to $computer_name  . . ."
Rename-Computer -ComputerName $ENV:COMPUTERNAME -NewName $computer_name

Write-Host "[ $(Get-Date) ] - Setting IP Address to $ip  . . ."
New-NetIPAddress -IPAddress $ip -InterfaceAlias "Ethernet" -DefaultGateway $gw -AddressFamily IPv4 -PrefixLength 24 
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses $dns

Write-Host "[ $(Get-Date) ] - Joining Domain - $domain  . . ."
Add-Computer -DomainName $domain -Cred $cred

Write-Host "[ $(Get-Date) ] - Enabling Powershell Remoting . . ."
Enable-PSRemoting -force 
Enable-WSManCredSSP –Role Server -Force 

Write-Host "[ $(Get-Date) ] - Enabling Terminal Services  . . ."
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0 -Force -ErrorAction Stop  
Set-NetFirewallRule -DisplayGroup "Remote Desktop" -Enabled:True -ErrorAction Stop

Write-Host "[ $(Get-Date) ] - Setting Time Zone to Central Standard Time . . ."
tzutil.exe /s "Central Standard Time" 

Write-Host "[ $(Get-Date) ] - Setting Automatic Updates . . ."
Stop-Service wuauserv -Force -Verbose
cscript c:\windows\system32\scregedit.wsf /AU 4 
Start-Service wuauserv -Verbose

Write-Host "[ $(Get-Date) ] - Setting CD-Rom Drive to Z: . . ."
.\reassign_cd-rom_drive_letter.bat

Write-Host "[ $(Get-Date) ] - Creating Additional Partitions . . ."
Get-Disk | Where{ $_.PartitionStyle -eq "RAW" } | Initialize-Disk -PartitionStyle MBR 
Get-Disk | Where{ $_.NumberOfPartitions -eq 0 } |   
    New-Partition -AssignDriveLetter -UseMaximumSize |
    Format-Volume -FileSystem NTFS    

Write-Host "[ $(Get-Date) ] - Disabling Shutdown Tracker . . ."
New-Item -Path "HKLM:SOFTWARE\Policies\Microsoft\Windows NT\" -Name "Reliability" 
New-ItemProperty -Path "HKLM:SOFTWARE\Policies\Microsoft\Windows NT\Reliability" -Name "ShutdownReasonOn" -Value "0" -PropertyType dword

Write-Host "[ $(Get-Date) ] - Disabling Error Reporting . . ."
.\config_error_reporting.vbs

Write-Host "[ $(Get-Date) ] - Disabling Firewall (I know. I know.) . . ."
Set-NetFirewallProfile -Enabled false

Write-Host "[ $(Get-Date) ] - Disabling UAC . . ."
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000

Write-Host "[ $(Get-Date) ] - Complete. So Rebooting . . ."
Restart-Computer -Confirm