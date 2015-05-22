 #require -module Azure

. (Join-Path -Path $env:SCRIPTS_HOME -ChildPath "Libraries\Standard_Functions.ps1")
Load-AzureModules

Set-Variable -Name Modules -Value "$ENV:ProgramFiles\WindowsPowerShell\Modules" -Option Constant
Set-Variable -Name DSCMap  -Value (Join-Path -Path $PWD.Path -ChildPath ("DSC\Computer-To-Guid-Map.csv"))

function Invoke-AzurePSRemoting
{
    param(
        [string] $ComputerName,
        [string] $CloudService,
        [string] $User,
        [string] $Password,
        [string] $ScriptPath,
        [Object[]] $Arguments
    )
    
    $retries = 5
    $script_block = Get-ScriptBlock -file $ScriptPath

    Install-WinRmCertificate -service $CloudService -vm_name $ComputerName
    $uri = Get-AzureWinRMUri -ServiceName $CloudService -Name $ComputerName
    $secpasswd = ConvertTo-SecureString -String $password -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential ( $user, $secpasswd )
   
    for($retry = 0; $retry -le $retries; $retry++) {
        try {
            Write-Verbose -Message ("[{0}] - Attempt {1} Creating PowerShell Session to {2} in {3}" -f $(Get-Date), $retry, $ComputerName, $CloudService) 
            $session = New-PSSession -ConnectionUri $uri -Credential $creds 
            if ($session -ne $null){
                break
            }
        }
        catch {
            Write-Verbose -Message ("[{0}] - Attempt {1} failed creating PowerShell Session to {2} in {3}. Sleeping for 30 seconds." -f $(Get-Date), $retry, $ComputerName, $CloudService)
            Start-Sleep -Seconds 30
        }
    }

    if($session -eq $null) {
        throw ("Could not establish PowerShell Remote Sessiong to {0} in {1}" -f $ComputerName, $CloudService)
    }

    Invoke-Command -Session $session -ScriptBlock $script_block -ArgumentList $Arguments
    Wait-ForVMReadyState -CloudService $CloudService -VMName $ComputerName
}

function Install-DSCDomainClient 
{
    param(
        [string] $ComputerName,
        [string] $CloudService,
        [string] $DSCServer,
        [string] $user,
        [string] $Password,
        [String] $ScriptPath = (Join-Path -Path $PWD.Path -ChilPath "ScriptBlocks\Setup-DSC-Client.ps1"),
        [string] $Guid = [string]::empty 
    )

    if( [string]::IsNullOrEmpty($Guid) ) {
        $Guid = [GUID]::NewGuid() | Select -Expand Guid
    } 
    
    Write-Verbose -Message ("[{0}] - Configuring DSC for {1} using GUID - {2}" -f $(Get-Date), $ComputerName, $Guid)  
    Add-Content -Encoding Ascii -Path $DSCMap -Value ( "{0},{1}" -f $ComputerName, $Guid )

    $remoting_opts = @{
        User = $user
        Password = $Password
        ComputerName = $ComputerName
        CloudService = $CloudService
        Arguments = @($DSCServer, $Guid)
        ScriptPath = $ScriptPath
    }

    Invoke-AzurePSRemoting @remoting_opts

}

function Publish-AzureDSCScript
{
    param(
        [string] $ComputerName,
        [string] $CloudService,
        [string] $ModulePath,
        [string] $ScriptPath
    )

    $configuration_name = Get-Item $ScriptPath | Select -ExpandProperty BaseName
    $script_name = Get-Item $ScriptPath | Select -ExpandProperty Name 

    Write-Verbose -Message ("[{0}] - Publishing DSC Configuration {1} for {2}" -f $(Get-Date), $configuration_name, $ComputerName)
    Get-ChildItem -Path $ModulePath | 
        Foreach { Copy-Item -Path $_.FullName -Destination $Modules -Recurse -ErrorAction SilentlyContinue }
    
    Publish-AzureVMDscConfiguration -ConfigurationPath $ScriptPath

    $vm = Get-AzureVM -ServiceName $CloudService -Name $ComputerName
    $vm | Set-AzureVMDscExtension -ConfigurationArchive ("{0}.zip" -f $script_name ) -ConfigurationName $configuration_name | 
        Update-AzureVM

    Wait-ForVMReadyState -CloudService $CloudService -VMName $ComputerName
}


Export-ModuleMember -Function Publish-AzureDSCScript, Invoke-AzurePSRemoting, Install-DSCDomainClient