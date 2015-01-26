#require -module Azure

function New-AzureStorage
{
    param (
        [Parameter(Mandatory=$true)][string] $Name,
        [Parameter(Mandatory=$true)][string] $AffinityGroup
    )

    Get-AzureStorageAccount -StorageAccountName $Name -ErrorAction SilentlyContinue
    if( $? ) {
         Write-Verbose -Message ("[{0}] - StorageAccount - {1} - in the {2} AffinityGroup already exists. Skipping Creation." -f $(Get-Date), $Name, $AffinityGroup)
    }
    else {
        Write-Verbose -Message ("[{0}] - Creating StorageAccount - {1} - in the {2} AffinityGroup" -f $(Get-Date), $Name, $AffinityGroup)
        New-AzureStorageAccount -StorageAccountName $Name -AffinityGroup $AffinityGroup
    }

    $key = Get-AzureStorageKey -StorageAccountName $Name
    $end_point = "http://{0}.blob.core.windows.net/" -f $Name

    return @{AccountName = $Name; AccessKey = $key.Primary; EndPoint = $end_point}
}

Export-ModuleMember -Function New-AzureStorage