function New-SharePointServices
{
    <#
    .Synopsis
        Provisions a list of services 
    .Description
        Provisions multiple service applications using the provided parameters
    .Example
        New-SharePointServices -DatabaseAccessAccount (Get-Credential DOMAIN\username) -DatabaseServer SQL01\instancename -ServiceDatabaseName NonGUIDDBName
    .Parameter DatabaseAccessAccount
        The farm account.  This needs to be in the form of a PSCredential object.
	.Parameter DatabaseServer
        The SQL server name
	.Parameter ServiceDatabaseName
        The database name to use when provisioning x service
    .Link
        Install-SharePoint
        New-SharePointFarm
        Join-SharePointFarm
	#>
    [CmdletBinding()]
    param 
    (    
        [Parameter(Mandatory=$false)][ValidateNotNull()]
        [System.Management.Automation.PSCredential]$DatabaseAccessAccount,
        
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]
        [String]$DatabaseServer,
        
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]
        [String]$ServiceDatabaseName = ("{0}_DB" -f $env:COMPUTERNAME
)
    )
    
    Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction "SilentlyContinue" | Out-Null
        
    Write-Warning "This command is currently being implemented and will be released in a future version of SPModule."
}
    
