
#https://github.com/BornToBeRoot/PowerShell
$key = [string]::Null 
$chars = "BCDFGHJKMPQRTVWXY2346789" 

$ProductKeyValue = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").digitalproductid[0x34..0x42]
$Wmi_Win32 = Get-WmiObject -Class Win32_OperatingSystem
    
for ($i = 24; $i -ge 0; $i--) { 
    $r = 0 

    for ($j = 14; $j -ge 0; $j--) { 
        $r = ($r * 256) -bxor $ProductKeyValue[$j] 
        $ProductKeyValue[$j] = [math]::Floor([double]($r / 24)) 
        $r = $r % 24 
    }

    $key = $Chars[$r] + $key  
    if (($i % 5) -eq 0 -and $i -ne 0) { 
        $key = "-" + $key 
    } 
} 

return (New-Object -TypeName PSObject -Property @{
    ComputerName   = $ENV:COMPUTERNAME
    Caption        = $Wmi_Win32.Caption
    WindowsVersion = $Wmi_Win32.Version
    OSArchitecture = $Wmi_Win32.OSArchitecture
    BuildNumber    = $Wmi_Win32.BuildNumber
    ProductKey     = $key
})