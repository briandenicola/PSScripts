
﻿#http://mosshater.blogspot.com/2010/11/check-replication-directory-changes.html


param(
    [Parameter(Mandatory=$true)]
    [string] $userName
)

function Check-ADUserPermission {

    param( 
        [System.DirectoryServices.DirectoryEntry]$entry, 
        [string]$user, 
        [string]$permission
    )

    $dse = [ADSI]"LDAP://Rootdse"
    $ext = [ADSI]("LDAP://CN=Extended-Rights," + $dse.ConfigurationNamingContext)

    $right = $ext.psbase.Children | Where { $_.DisplayName -eq $permission }
    
    if($right -ne $null) {
        $perms = $entry.psbase.ObjectSecurity.Access |
            Where { $_.IdentityReference -eq $user } |
            Where { $_.ObjectType -eq [GUID]$right.RightsGuid.Value }

        return ($perms -ne $null)
    }
    else {
        Write-Warning "Permission '$permission' not found."
        return $false
    }
}

Set-Variable -Name replicationPermissionName -Value "Replicating Directory Changes"
$dse = [ADSI]"LDAP://Rootdse"

$entries = @(
    [ADSI]("LDAP://" + $dse.defaultNamingContext),
    [ADSI]("LDAP://" + $dse.configurationNamingContext));

Write-Host "User '$userName': "
foreach($entry in $entries)
{
    $result = Check-ADUserPermission $entry $userName $replicationPermissionName
    
    if($result) {
        Write-Host "`thas a '$replicationPermissionName' permission on $($entry.distinguishedName)'" ` -ForegroundColor Green
    }
    else {
        Write-Host "`thas no a '$replicationPermissionName' permission on '$($entry.distinguishedName)'"  -ForegroundColor Red
    }
}