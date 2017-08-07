param(
    [string] $NewComputerName
)

Configuration Setup-NewComputer 
{

    Import-DscResource -Module xComputerManagement 
    Import-DscResource -Module xWindowsUpdate
    Import-DscResource -Module xCredSSP
    Import-DscResource -Module xTimeZone
    Import-DscResource -Module xRemoteDesktopAdmin
    Import-DscResource -Module xNetworking
    Import-DscResource -Module xSystemSecurity

    Node localhost
    {
        xComputer NewName
        {
            Name = $NewComputerName
        }

        xVirtualMemory pagingSettings
        {
            Type        = 'CustomSize'
            Drive       = 'C'
            InitialSize = '2048'
            MaximumSize = '2048'
        }

        xIEEsc DisableIEEsc
        { 
            IsEnabled = $false 
            UserRole = "Users" 
        }

        xUAC NeverNotifyAndDisableAll 
        { 
            Setting = "NeverNotifyAndDisableAll" 
        } 

        xCredSSP Server
        {
            Ensure = "Present"
            Role = "Server"
        }

        xCredSSP Client
        {
            Ensure = "Present"
            Role = "Client"
            DelegateComputers = "*"
        }

        xWindowsUpdateAgent MuSecurityImportant
        {
            IsSingleInstance = 'Yes'
            UpdateNow        = $false
            Source           = 'WindowsUpdate'
            Notifications    = 'ScheduledInstallation'
        }
        
        xTimeZone TimeZone
        {
            TimeZone = "Central Standard Time"
        }
                
        xRemoteDesktopAdmin RemoteDesktopSettings
        {
           Ensure = 'Present'
           UserAuthentication = 'Secure'
        }

        xFirewall AllowRDP
        {
            Name = 'DSC - Remote Desktop Admin Connections'
            DisplayName = "Remote Desktop"
            Ensure = 'Present'
            Enabled = 'true'
            Action = 'Allow'
            Profile = 'Any'
        }

        Script SetConsentBehavior
        {
            SetScript = {
                Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000
            }
            TestScript = {
                $consent = (Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin")
                return $consent -eq 00000000
            }
            GetScript = {
                return @{
                    Result = (Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin")
                }
            }
        }
    }
}