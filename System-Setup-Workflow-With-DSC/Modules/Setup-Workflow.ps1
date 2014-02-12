workflow Setup-NewComputer { 
    param (
        [string] $new_name,
        [string] $domain,
        [string] $pull_server,
        [string] $guid, 
        [System.Management.Automation.PSCredential] $cred
    )

    sequence {
        Set-ExecutionPolicy -ExecutionPolicy Unrestricted
        Set-NetFirewallProfile -Enabled false

        Rename-Computer -NewName $new_name
        Restart-Computer -Wait -For PowerShell -Timeout 90 -Force
        
        inlinescript {
            Set-Variable -Name interface -Value "Ethernet0" -Option Constant
            Set-Variable -Name dns -Value "10.2.1.5" -Option Constant
            Set-DnsClientServerAddress -InterfaceAlias $using:interface -ServerAddresses $using:dns
            Add-Computer -DomainName $using:domain -Credential $using:cred -Force 
        }
        Restart-Computer -Wait -For PowerShell -Timeout 90 -Force

        parallel {
            inlinescript {
                Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0 -Force -ErrorAction Stop  
                Set-NetFirewallRule -DisplayGroup "Remote Desktop" -Enabled:True -ErrorAction Stop
            }

           inlinescript {
                tzutil.exe /s "Central Standard Time" 
            }
 
            inlinescript {
                Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000
            }
        }

        inlinescript {
            function Get-NextDriveLetter {
                param ([string] $current_drive )
                return ( [char][byte]([byte][char]$current_drive - 1) )
            }

            Set-Variable -Name new_drive_letter -Value "Z"
            Set-Variable -Name cdrom_drives -Value @(Get-Volume | Where DriveType -eq "CD-ROM")

            foreach( $drive in $cdrom_drives ) {
                $cd_drive = Get-WmiObject Win32_Volume | Where DriveLetter -imatch $drive.DriveLetter
                $cd_drive.DriveLetter = "$new_drive_letter`:"
                $cd_drive.put()
                $new_drive_letter = Get-NextDriveLetter -current_drive $new_drive_letter
            }

            Get-Disk | Where { $_.PartitionStyle -eq "RAW" } | Initialize-Disk -PartitionStyle MBR 
            Get-Disk | Where { $_.NumberOfPartitions -eq 0 } |   
                New-Partition -AssignDriveLetter -UseMaximumSize |
                Format-Volume -FileSystem NTFS -Force -Confirm:$false
        }

        inlinescript {
            configuration Configure_DSCPullServer {                param ($NodeId, $PullServer)    
                LocalConfigurationManager                {                    AllowModuleOverwrite = 'True'                    ConfigurationID = $NodeId                    ConfigurationModeFrequencyMins = 60                     ConfigurationMode = 'ApplyAndAutoCorrect'                    RebootNodeIfNeeded = 'True'                    RefreshMode = 'PULL'                     DownloadManagerName = 'WebDownloadManager'                    DownloadManagerCustomData = (@{ServerUrl = "http://$PullServer/psdscpullserver.svc"})                }            }

            Configure_DSCPullServer -NodeId $using:guid -PullServer $using:pull_server            Set-DscLocalConfigurationManager -path Configure_DSCPullServer
            $using:guid | Add-Content -Encoding Ascii ( Join-Path "C:" $using:guid )
        }

        Restart-Computer -Wait -For PowerShell -Timeout 90 -Force
        Set-NetFirewallProfile -Enabled true 
    }

}