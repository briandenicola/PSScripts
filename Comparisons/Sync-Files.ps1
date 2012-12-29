<#
.SYNOPSIS
This PowerShell Script will synchronize two directories.  It can copy files from one directory or another.

.DESCRIPTION
Version - 1.0.0
The script will copy files from one directory to another based on different MD5 hash values

.EXAMPLE
.\Sync-Directories.ps1 -src c:\SourceFolder -dst d:\DestinationFolder 

.EXAMPLE
.\Sync-Directories.ps1 -src c:\SourceFolder -dst d:\DestinationFolder -ignore_files @("*.xml")

.EXAMPLE
.\Sync-Directories.ps1 -src c:\SourceFolder -dst d:\DestinationFolder -ignore_files @("*.xml", "*.log") -logging -log "D:\Logs\Rsync.log"

.PARAMETER Src
Specifies the main directory to copy files from. Mandatory parameter

.PARAMETER Dst
Specifies the main directory to copy files to. Mandatory parameter

.PARAMETER ignore_files
Specifies an array of extensions of files to ignore in the sync process

.PARAMETER logging
Switch to including logging of files copied. Parameter Set = Logging

.PARAMETER log
Full Path to Log file. Parameter Set = Logging

.NOTES
This current version is limited in that it only copies files from one directory to another. It does not completely sync to directories ie remove 
files from the destination. It will also overwrite any existing files in the destination. It does not do conflict detection.

#>


[CmdletBinding(SupportsShouldProcess=$true)]
param (
    
    [Parameter(Mandatory=$true)] 
	[string] $src,

    [Parameter(Mandatory=$true)] 
	[string] $dst,

    [string[]] $ignore_files = [string]::emtpy,

    [switch] $logging,
    [string] $log = [String]::empty
)	

function Get-MD5 
{
	param(
	    [string] $file = $(throw 'a filename is required')
	)

	$fileStream = [system.io.file]::openread($file)
	$hasher = [System.Security.Cryptography.HashAlgorithm]::create("md5")
	$hash = $hasher.ComputeHash($fileStream)
	$fileStream.Close()
	$md5 = ([system.bitconverter]::tostring($hash)).Replace("-","")

    Write-Verbose "File - $file - has a MD5 - $md5"

	return ( $md5 ) 
}

function Strip-RootDirectory
{
    param (
        [string] $FullDir,
        [string] $RootDir
    )

    $RootDir = $RootDir.Replace("\","\\")
    return ( $FullDir -ireplace $RootDir, [String]::Empty )
}

function Get-DirectoryHash
{
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [string] $root
    )

	begin {
		$ErrorActionPreference = "silentlycontinue"
        $hashes = @()
	}
	process {
        if( -not ( Test-Path $root ) ) {
            throw "Could not find the directory $($root)"
        }

        Write-Verbose "Getting Hashes for $($root) . . ."

		$hashes = @( Get-ChildItem -Recurse $root -Exclude $ignore_files | 
            Where { $_.PsIsContainer -eq $false } | 
            Select Name,@{Name="Directory"; Expression={Strip-RootDirectory -FullDir $_.DirectoryName -RootDir $root}},@{Name="Hash"; Expression={Get-MD5 $_.FullName}}
        )
	}
	end {
        return $hashes
	}
}

function main
{
    if( $logging -and $log -eq [string]::Empty ) {
        $log = Read-Host "Please enter the file path to the log file"
    }

    if( $logging ) { 
        "[ $(Get-Date) ] -Starting the comparison process . . ." | Out-File -Encoding ascii -Append -FilePath $log
    }

    $src_hashes = Get-DirectoryHash -root $src
    $dst_hashes = Get-DirectoryHash -root $dst 

    if(  $src_hashes -eq $null -and $dst_hashes -eq $null ) {
        Write-Host "Either $src is empty or both $src and $dst are empty . . ."
    }

    if( $dst_hashes -eq $null ) {
        $diffs = $src_hashes | Select Name, Directory
    }
    else {
        $diffs = Compare-Object -referenceobject $src_hashes -differenceobject  $dst_hashes  -property @("Name","Directory", "Hash") | Where { $_.SideIndicator -eq "<=" } | Select Name, Directory
    }

    foreach( $diff in $diffs ) {
        $new_file_dst_path = (Join-Path $dst $diff.Directory)
        $org_src_file_path = (Join-Path $src $diff.Directory)

        if( -not ( Test-Path $new_file_dst_path ) ) { 
            Write-Verbose "Creating $($new_file_dst_path) . . ."
            mkdir $new_file_dst_path | Out-Null 
        }

        if( $logging ) { 
            "[ $(Get-Date) ] - Copying $($diff.Name) from $($org_src_file_path) to $($new_file_dst_path) . . ." | Out-File -Encoding ascii -Append -FilePath $log
        }

        Write-Verbose "Copying $($diff.Name) from $($org_src_file_path) to $($new_file_dst_path) . . ."
        copy (Join-Path $org_src_file_path $diff.Name) (Join-Path $new_file_dst_path $diff.Name) -Force
    }

    if( $logging ) { 
        "[ $(Get-Date) ] - Finish. . ." | Out-File -Encoding ascii -Append -FilePath $log
    }
}
main