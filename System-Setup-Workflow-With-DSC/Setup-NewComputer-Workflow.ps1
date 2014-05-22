param (
 [Parameter(Mandatory=$true)]
 [string] $computer_name,

 [Parameter(Mandatory=$true)]
 [string] $new_name,

 [Parameter(Mandatory=$true)]
 [string] $domain = "sharepoint.test",

 [Parameter(Mandatory=$true)]
 [string] $node,

 [Parameter(Mandatory=$true)]
 [string] $pull_server = "dsc.sharepoint.test",

 [Parameter(Mandatory=$true)]
 [string] $local_user,

 [Parameter(Mandatory=$true)]
 [string] $local_password,

 [Parameter(Mandatory=$true)]
 [string] $domain_user,

 [Parameter(Mandatory=$true)]
 [string] $domain_password
)

function Set-MOFHash {
    param (
        [string] $guid,
        [string] $module
    )

    Set-Variable -Name dsc_path -Value "C:\Program Files\WindowsPowerShell\DscService\Configuration\" -Option Constant
    Set-Variable -Name mof -Value ( Join-Path $PWD.Path ("{0}\{1}.mof" -f $module,$guid) )
    Set-Variable -Name checksum -Value ( Join-Path $PWD.Path ("{0}\{1}.mof.checksum" -f $module, $guid) )
    
    if( !(Test-path $mof) ) {
        throw "Could not find $mof . . "
    }
       
    $hash = Get-FileHash $mof
    [System.IO.File]::AppendAllText( $checksum, $hash.Hash )

    Copy-Item $mof $dsc_path -Verbose -Force
    Copy-Item $checksum $dsc_path -Verbose -Force
}

Set-Variable -Name domain_creds -value (New-Object System.Management.Automation.PSCredential ($domain_user, (ConvertTo-SecureString $domain_password -AsPlainText -Force)))
Set-Variable -Name local_creds  -value (New-Object System.Management.Automation.PSCredential ($local_user, (ConvertTo-SecureString $local_password -AsPlainText -Force)))

if( [string]::IsNullOrEmpty($node) ) { 
    Set-Variable -Name node -Value ([guid]::NewGuid() | Select -Expand Guid)
}

. (Join-Path $PWD.Path "Modules\Setup-Workflow.ps1")
. (Join-Path $PWD.Path "Modules\Server-DSC-Template.ps1") -Nodeid $node 

Write-Host ("Using Guid - {0} for {1}. Please save. Value will also be saved on the root of the C: parition on {1}." -f $node, $computer_name)

winrm s winrm/config/client ('@{TrustedHosts="' + $computer_name + '"}')

#Workflow to Setup Machine
$options = @{ 
    new_name = $new_name
    domain = $domain
    pull_server = $pull_server
    guid = $node
    cred = $domain_creds
}
Setup-NewComputer @options -PSPersist $true -PSComputerName $computer_name -PSCredential $local_creds -Verbose

#DSC To Configure
ServerSetup
Set-MOFHash -guid $node -Module "ServerSetup"