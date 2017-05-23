<#
.SYNOPSIS 
    This script will query an Azure subscription and report back the resources with particular focus on Public IP Addresses 

.DESCRIPTION

.EXAMPLE
    Audit-CreatedResources.ps1 -DaysToAudit 5 -ResourceGroups *

.EXAMPLE
    Audit-CreatedResources.ps1 -DaysToAudit 5 -CSV c:\temp\azure.csv -ResourceGroups Testing,Testing001
    
.NOTES
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,   

    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,45)]
    [int]    $DaysToAudit = 1,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string[]] $ResourceGroups,

    [string] $CSVPath
)

Set-StrictMode -Version 5
Import-Module -Name Azure_Functions -Force

$params = @{
    StartTime  = $(Get-Date).AddDays(-$DaysToAudit)
    Status     = "Succeeded"
    DetailedOutput = $true
}

try { 
    Get-AzureRmContext | Out-Null
}
catch { 
    Write-Verbose -Message ("[{0}] - Logging into Azure" -f $(Get-Date))
    Login-AzureRmAccount 
}

$logs = $()
if( $ResourceGroups -eq "*" ) {
    $ResourceGroups = Get-AzureRmResourceGroup | Select-Object -ExpandProperty ResourceGroupName
}

foreach( $group in $ResourceGroups )  {
    $logs += Get-AzureRmLog @params -ResourceGroup $group
}

$selectOpts = @(
     @{N="EventTimestamp"; E={$_.EventTimestamp.ToLocalTime()}},
     @{N="EventTimestampUtc"; E={$_.EventTimestamp}},
    'ResourceGroupName',
    @{N="Resource"; E={($_.ResourceId.Split("/") | Select-Object -Last 1)}}
    'ResourceId',
    'ResourceProviderName',
    'Caller'
    'CorrelationId'
)
$createdResources = $logs | 
                Where-Object { $_.OperationName -imatch 'write' -and $_.EventChannels -eq 'Operation' } |
                Select-Object $selectOpts


if( !([string]::IsNullOrEmpty($CSVPath)) ) {
     $createdResources | Export-Csv -Encoding ASCII -NoTypeInformation -Path $CSVPath
}
else {
    return $createdResources
}