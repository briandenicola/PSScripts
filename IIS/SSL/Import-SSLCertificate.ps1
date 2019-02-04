param (
    [string[]] $servers,
    [string] $pass = "abc123",
    [string] $SetCertToSite,
    [string] $CertSubject,
	
    [Parameter(ParameterSetName = 'Export')]
    [string] $source,
		
    [Parameter(ParameterSetName = 'FromBackup')]
    [string] $PfxPath
)

$export_pfx_sb = {
    param(
        [string] $cert,
        [string] $pass = "abc123",
        [string] $url
    )
	
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
    $secure_pass = ConvertTo-SecureString $pass -AsPlainText -Force 
    Export-Certificate -subject $url -file $cert -pfxPass $secure_pass
	
}

$deploy_cert_sb = {
    param(
        [string] $cert,
        [string] $pass = "abc123",
        [string] $site,
        [string] $url
    )

    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")
	
    $secure_pass = ConvertTo-SecureString $pass -AsPlainText -Force 	
	
    Import-PfxCertificate -certpath $cert -pfxPass $secure_pass
	
    if ( $site ) {
        if ( $url ) {
            Set-SSLforWebApplication -name $site -common_name $url
        }
        else {
            throw ("The Certificate Subject was not provided so certificate was not set for IIS Site Named - " + $site + ". The Cert was imported to the keystore")
        }
    } 

}	

function main() {
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")

    switch ($PsCmdlet.ParameterSetName) { 
        "Export" {
            if ( !$CertSubject ) {
                throw ( "CertSubject must be passed when using the Source parameter set" )
            }
            $PfxPath = "\\" + $source + "\c$\Windows\Temp\cert-export-" + $CertSubject.Replace("*", "") + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".pfx"
            Write-Host "Backed up Certficate file to $PfxPath"
            Invoke-Command -ComputerName $source -ScriptBlock $export_pfx_sb -ArgumentList $PfxPath, $pass, $CertSubject
            break
        }
        "FromBackup" {
            if ( -not (Test-Path $PfxPath) ) {
                throw ("Could not find " + $PfxPath )
            }
            break
        }
    }
	
    $creds = Get-Credential ( $ENV:USERDOMAIN + "\" + $ENV:USERNAME ) 
    Invoke-Command -ComputerName $servers -Credential $creds -Authentication CredSSP -ScriptBlock $deploy_cert_sb -ArgumentList $PfxPath, $pass, $SetCertToSite, $CertSubject
    .\query_ssl_certificates.ps1 -computers $servers -application sharepoint -upload -parallel

}
main