function Start-CentralAdministration
{
    <#
    .Synopsis
        Starts the Central Administration site from within Windows PowerShell
    .Description
        Starts the Central Administration site from within Windows PowerShell
    .Example
        Start-CentralAdministration
    .Link
        Install-SharePoint
        New-SharePointFarm
        Join-SharePointFarm
        #>
    if(Test-ElevatedProcess)
    {
    	$caURL = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\14.0\WSS\').CentralAdministrationURL
        if(![String]::IsNullOrEmpty($caURL))
        {
            [System.Diagnostics.Process]::Start($caURL)
        }
        else
        {
            Write-Error "Central Administration is not installed.  Have you created (Get-Help New-SharePointFarm) or joined (Get-Help Join-SharePointFarm) a farm?"
        }
    }
    else
    {
        Write-Error "This Windows PowerShell session is not elevated.  Close this window and open Windows PowerShell again by right clicking and selecting 'Run as administrator'."
    }
}