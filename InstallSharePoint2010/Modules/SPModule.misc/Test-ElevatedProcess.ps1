#Requires -Version 2.0

function Test-ElevatedProcess
{
    $CurrentWindowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $CurrentWindowsPrincipal = new-object System.Security.Principal.WindowsPrincipal($CurrentWindowsIdentity)
    
    [bool] $IsProcessElevated = $CurrentWindowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

    return $IsProcessElevated;
}