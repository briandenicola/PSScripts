[CmdletBinding(SupportsShouldProcess=$true)]
param( 
    [Parameter(Mandatory=$true)]
    [string[]] $servers
)

$sb = {
    . (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
    $ver = (Get-WmiObject -Class Win32_OperatingSystem).Version
    
    $sites_with_certs = @()
    if( $ver -lt 6.1 ) {
        $encoding_type = "System.Text.ASCIIEncoding"
        $encode = New-Object $encoding_type
        $WebServerQuery = "Select * from IIsWebServerSetting"

        $wmiWebServerSearcher = [WmiSearcher] $WebServerQuery
		$wmiWebServerSearcher.Scope.Path = "\\{0}\root\microsoftiisv2" -f $ENV:COMPUTERNAME
		$wmiWebServerSearcher.Scope.Options.Authentication = 6
		
        foreach( $site in $wmiWebServerSearcher.Get() ) {
            if( $site.SSLStoreName -eq "My" ) {    
                $certmgr = New-Object -ComObject IIS.CertObj
                $certmgr.ServerName = $ENV:COMPUTERNAME
                $certmgr.InstanceName = $site.Name 

                $cert_info_bytes = $certmgr.GetCertInfo()
                $certs_info_stripped = $cert_info_bytes | where { $_ -ne 0 }
                $cert_info = ($encode.GetString($certs_info_stripped)).Split("`n")

                $subject = $cert_info | where { $_ -imatch "2.5.4.3" } | % { $_.Split("=")[1] }
                $thumbprint = Get-ChildItem cert:\LocalMachine\My | where { $_.Subject -like $subject } | Select -ExpandProperty THumbprint

                $sites_with_certs += (New-Object PSObject -Property @{
                    Site = $site.ServerComment
                    Certficate = $subject
                    Thumbprint = $thumbprint
                    Server = $env:COMPUTERNAME
                })
            }
        }
    }
    else {
        . (Join-PATH $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")

        $certs = Get-ChildItem cert:\LocalMachine\My      
        $sites = Get-ChildItem IIS:\SslBindings | Where { $_.Store -eq "MY" } | Select Thumbprint, Sites

        $sites_with_certs = @()
        foreach( $site in ($sites | where { $_.Sites.Value -ne $null }) ) {
            
            $sites_with_certs += (New-Object PSObject -Property @{
                Site = $site.Sites.Value
                Certificate = ($certs | where { $_.Thumbprint -eq $site.Thumbprint } | Select -ExpandProperty Subject).Split(",")[0].Split("=")[1]
                Thumbprint = $site.Thumbprint
                Server = $env:COMPUTERNAME
            })
        }
    }
    return $sites_with_certs
}


function main
{
    Invoke-Command -ComputerName $servers -ScriptBlock $sb
}
main


