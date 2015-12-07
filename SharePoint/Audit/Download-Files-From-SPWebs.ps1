[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [parameter(mandatory=$true)]
	[string[]] $Urls,
    
    [parameter(mandatory=$true)]
    [string] $OutPutPath,

    [parameter(mandatory=$false)]
    [string] $Library = "Document Library",

    [parameter(mandatory=$false)]
    [string] $AuditLog = (Join-Path -Path $PWD.Path -ChildPath ("download_files-{0}.log" -f $(Get-Date).ToString("yyyyMMddhhmmss")))

)

. (Join-Path $ENV:SCRIPTS_HOME "\Libraries\Standard_functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "\Libraries\SharePoint2010_functions.ps1")

function Get-SPFileFromFolder
{
    param(
        [string] $FolderName 
    )

    $folder = $web.GetFolder($FolderName)
    foreach ($file in $folder.Files) {
        $destination_folder = Join-Path -Path $OutPutPath -ChildPath $folder.Url 
        if (!(Test-Path -Path $destination_folder)) {
            New-Item -Path $destination_folder -Type Directory | Out-Null
        }
    
        $binary = $file.OpenBinary()
        $destination_file = Join-Path -Path $destination_folder -ChildPath $file.Name

        Out-File -FilePath $AuditLog -Encoding ascii -Append -InputObject ("[{0} - Downloading File: {1} to {2}" -f $(Get-Date), $file.Name, $destination_file)

        $stream = New-Object System.IO.FileStream($destination_file), Create
        $writer = New-Object System.IO.BinaryWriter($stream)
        $writer.write($binary)
        $writer.Close()
    }
}

foreach( $url in $urls ) 
{
    $web = Get-SPWeb -Identity $url
    $list = $web.Lists[$Library]

    Write-Verbose -Message ("[{0}] - Processing Root Folder - {1}" -f $(Get-Date), $list.RootFolder.Url)
    Get-SPFileFromFolder -FolderName $list.RootFolder.Url

    foreach ($folder in $list.Folders) {
        Write-Verbose -Message ("[{0}] - Processing Folder - {1}" -f $(Get-Date), $folder.Url)
        Get-SPFileFromFolder -FolderName $folder.Url
    }
}