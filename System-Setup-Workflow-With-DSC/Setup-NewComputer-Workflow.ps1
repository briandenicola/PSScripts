param (
 [Parameter(Mandatory=$true)]
 [string] $computer_name,
 [string] $new_name,
 [string] $domain = "sharepoint.test"
)

function Set-MOFHash {
    param (
        [string] $guid,
        [string] $module
    )

    Set-Variable -Name mof -Value ( Join-Path $PWD.Path ("{0}\{1}.mof" -f $module, $guid) )
    Set-Variable -Name checksum -Value ( Join-Path $PWD.Path ("{0}\{1}.mof.checksum" -f $module, $guid) )
    
    if( !(Test-path $mof) ) {
        throw "Coudl not find $mof . . "
    }
       
    $hash = Get-FileHash $mof
    [System.IO.File]::AppendAllText( $checksum, $hash.Hash )
}

Set-Variable -Name password     -Value (ConvertTo-SecureString "01000000d08c9ddf0115d1118c7a00c04fc297eb01000000c4a0897a6f52d14a992239db193c3b5800000000020000000000106600000001000020000000f898c9f7e2ebeb05b2ede10d45f236451b25361ef92b68b9281f48349d10ea8e000000000e8000000002000020000000aa728a19476afc227e471924f69e057bf8c29e27c65d13de39146cdda658098f2000000071e06b802e24b41dbd4cdb53372b7602da678571ed1fba8a079854a14fb8320940000000cc64479cfe2a4549382212f10c21ccc01dfa9de3b91b861fd0d40038f3d08b403d3b9d95cde94976beb9718778787f8af514a5d9d9373af1be46e1436505d014") -Option Constant
Set-Variable -Name pull_server  -Value ("dsc." + $domain) -Option Constant
Set-Variable -Name domain_creds -value (New-Object System.Management.Automation.PSCredential (($domain + "\brian-a"), $password))
Set-Variable -Name local_creds  -value (New-Object System.Management.Automation.PSCredential ("administrator", $password))
Set-Variable -Name node         -Value (([guid]::NewGuid().Guid).ToString())

. (Join-Path $PWD.Path "Modules\Setup-Workflow.ps1")
. (Join-Path $PWD.Path "Modules\IIS-Server-DSC-Template.ps1") -Nodeid $node 

Write-Host ("Using Guid - {0} for {1}. Please save. Value will also be saved on the root of the C: parition on {1}." -f $node, $computer_name)

#Workflow to Setup Machine
$options = @{ 
    new_name = $new_name
    domain = $domain
    pull_server = $pull_server
    guid = $node
    cred = $domain_creds
    PSPersist = $true 
    PSComputerName = $computer_name
    PSCredential = $local_creds
}
Setup-NewComputer @options -Verbose

#DSC To Configure
IISServerSetup
Set-MOFHash -guid $node -Module "IISServerSetup"