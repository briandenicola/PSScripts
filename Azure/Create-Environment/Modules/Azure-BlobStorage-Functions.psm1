#require -module Azure

. (Join-Path -Path $env:SCRIPTS_HOME -ChildPath "Libraries\Standard_Functions.ps1")
Load-AzureModules

function New-AzureStorage
{
    param (
        [Parameter(Mandatory=$true)][string] $Name,
        [Parameter(Mandatory=$true)][string] $AffinityGroup
    )

    Get-AzureStorageAccount -StorageAccountName $Name -ErrorAction SilentlyContinue | Out-Null
    if( $? ) {
         Write-Verbose -Message ("[{0}] - StorageAccount - {1} - in the {2} AffinityGroup already exists. Skipping Creation." -f $(Get-Date), $Name, $AffinityGroup)
    }
    else {
        Write-Verbose -Message ("[{0}] - Creating StorageAccount - {1} - in the {2} AffinityGroup" -f $(Get-Date), $Name, $AffinityGroup) 
        New-AzureStorageAccount -StorageAccountName $Name -AffinityGroup $AffinityGroup | Out-Null
    }

    $key = Get-AzureStorageKey -StorageAccountName $Name | Select -ExpandProperty Primary
    $end_point = "http://{0}.blob.core.windows.net/" -f $Name

    return (New-Object PSObject -Property @{AccountName = $Name; AccessKey = $key; EndPoint = $end_point} )
}

function Publish-AzureExtensionScriptstoStorage 
{
    param (
        [Parameter(Mandatory=$true)][string] $StorageName,
        [Parameter(Mandatory=$true)][string] $ContainerName,
        [Parameter(Mandatory=$true)][string[]] $FilePaths,
        [Parameter(Mandatory=$false)][string] $Subscription = $global:subscription
    )

    $ContainerName = $ContainerName.ToLower()

    Set-AzureSubscription -SubscriptionName $Subscription
    $key = Get-AzureStorageKey $StorageName | Select -ExpandProperty Primary 
    $storage_context = New-AzureStorageContext -StorageAccountName $StorageName -StorageAccountKey $key

    Get-AzureStorageContainer -Name $ContainerName -Context $storage_context -ErrorAction SilentlyContinue | Out-Null
    if( $? ) {
        Write-Verbose -Message ("[{0}] - Container - {1} - in the {2} Blob Storage already exists. Skipping Creation." -f $(Get-Date), $ContainerName, $StorageName)
    }
    else {
        Write-Verbose -Message ("[{0}] - Creating Container - {1} - in the {2} Blob Storage" -f $(Get-Date), $ContainerName, $StorageName) 
        New-AzureStorageContainer -Name $ContainerName -Context $storage_context
    }

    foreach( $file in $FilePaths ) {
        if( (Test-Path -Path $file) ) {
            Write-Verbose -Message ("[{0}] - Uploading - {1} - to {2} " -f $(Get-Date), $file, $ContainerName) 
            Upload-FileToAzure -file $file -Container $ContainerName -Storage $StorageName 
        }
        else {
           Write-Error -Message ("[{0}] - File {1} does not exist" -f $(Get-Date), $file)  
        }
    }
}


Export-ModuleMember -Function New-AzureStorage,  Publish-AzureExtensionScriptstoStorage 