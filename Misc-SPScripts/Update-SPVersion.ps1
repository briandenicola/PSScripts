[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [Parameter(Mandatory=$true)]
    [string[]] $computers
)

. (Join-Path $env:SCRIPTS_HOME "Libraries\SharePoint_functions.ps1" )
. (Join-Path $env:SCRIPTS_HOME "Libraries\Standard_functions.ps1" )
. (Join-Path $env:SCRIPTS_HOME "Libraries\Standard_Variables.ps1" )

$sb = {
    . (Join-Path $env:SCRIPTS_HOME "Libraries\SharePoint2010_functions.ps1" )
    
    return ( Get-SPVersion  )
}

$creds = Get-Credential ( $env:USERDOMAIN + "\" + $env:USERNAME )

foreach ( $computer in $computers ) { 

    Write-Verbose "Getting SPVersion on $computer . . ."
    $ver = Invoke-Command -ComputerName $computer -Credential $creds -Authentication Credssp -ScriptBlock $sb    
    $ht = @{ "Version" = $ver }

    Write-Verbose "Getting ID of $computer from $global:SharePoint_server_list in $global:SharePoint_url . . ."
    $id = Get-SPListViaWebService -url $global:SharePoint_url -list $global:SharePoint_server_list | Where { $_.SystemName -eq $computer } | Select -ExpandProperty ID

    if( $id -ne $null ) {
        Write-Verbose "Updating $computer record from $global:SharePoint_server_list in $global:SharePoint_url to version $ver . . ."
        Update-SPListViaWebService -url $global:SharePoint_url -list $global:SharePoint_server_list -id $id -Item $ht
    }
    else { 
        Write-Error "Could not find $computer in the site $global:SharePoint_url for the $global:SharePoint_server_list list"
    }
}