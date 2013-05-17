param (
    [string] $url,
    [string] $account
)

. (Join-Path $ENV:SCRIPTS_HOME "\Libraries\Standard_functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "\Libraries\SharePoint2010_functions.ps1")

try {
    $user = Get-SPuser -web $url -Limit ALL| where UserLogin -like $account 
    
    Write-Host "[ $(Get-Date) ] - $account setting before in $url site collection . . ."
    $user | Format-List

    Set-SPUser -identity $user.ID -web $url -syncfromad

    Write-Host "[ $(Get-Date) ] - $account setting after in $url site collection . . ."
    Get-SPUser -identity $user.ID -web $url | Format-List
} 
catch {
    Write-Error "Failed with the following error - " + $_.Exception.ToString()
}