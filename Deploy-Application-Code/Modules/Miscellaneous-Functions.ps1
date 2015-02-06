#ScriptBlocks
Set-Variable -Name sptimer_script_block  -Value { Restart-Service -Name sptimerv4 -Verbose }
Set-Variable -Name iisreset_script_block -Value { iisreset }

Set-Variable -Name sync_file_script_block -Value {
    param ( [string] $src, [string] $dst, [string] $log_file  )
    Write-Host "[ $(Get-Date) ] - Copying files on $ENV:COMPUTER from $src to $dst . . ."
	$sync_script = (Join-Path $ENV:SCRIPTS_HOME "Sync\Sync-Files.ps1")
	&$sync_script -src $src -dst $dst -verbose -logging -log $log_file
}

Set-Variable -Name gac_script_block -Value {
	param( [string] $src ) 
	Write-Host "[ $(Get-Date) ] - Deploying to the GAC on $ENV:COMPUTER from $src . . ."
    
    $published_files = @()
    [System.Reflection.Assembly]::Load("System.EnterpriseServices, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a") | Out-Null
	$publish = New-Object System.EnterpriseServices.Internal.Publish

	foreach( $file in (Get-ChildItem $src -include *.dll -recurse) ) 
	{
		$assembly = $file.FullName
		$fileHash = get-hash1 $assembly
				  
		$publish.GacInstall( $assembly )

        $published_files += (New-Object PSObject -Property @{
            Name = $file.Name
            LastWriteTime = $file.LastWriteTime
            ProductVersion = $file.VersionInfo.ProductVersion
            FileHash = $fileHash
            ComputerName = $ENV:COMPUTERNAME 
        })
    }

    return $published_files
}

#Functions
function Get-SPServers 
{
    param( [string] $type = "Microsoft SharePoint Foundation Workflow Timer Service" )
   
	$servers = Get-SPServiceInstance | 
	    Where { $_.TypeName -eq $type -and $_.Status -eq "Online" } | 
		Select -Expand Server | 
		Select -Expand Address 

    return $servers
}

function Log
{
    param( [string] $text )

    $logged_text = "[{0}] - {1} ... " -f $(Get-Date), $text
    Add-Content -Encoding Ascii -Value $logged_text -Path $global:log_file 
    Write-Verbose -Message $logged_text
}

#File Name: Install-SSRSRDL.ps1
#Author: Randy Aldrich Paulo
#Prerequisite: SSRS 2008, Powershell 2.0
function Install-SSRSRDL
{
    param (
	    [Parameter(Position=0,Mandatory=$true)]
	    [Alias("url")]
	    [string]$webServiceUrl,

	    [ValidateScript({Test-Path $_})]
	    [Parameter(Position=1,Mandatory=$true)]
	    [Alias("rdl")]
	    [string]$rdlFile,
	
	    [Parameter(Position=2)]
	    [Alias("folder")]
	    [string]$reportFolder="",

	    [Parameter(Position=3)]
	    [Alias("name")]
	    [string]$reportName="",
	
	    [switch]$force
    )

	$ErrorActionPreference="Stop"
	
	#Create Proxy
	Write-Host "[Install-SSRSRDL()] Creating Proxy, connecting to : $webServiceUrl"
	$ssrsProxy = New-WebServiceProxy -Uri $webServiceUrl -UseDefaultCredential
	$reportPath = "/"
	
	if($force)
	{
		#Check if folder is existing, create if not found
		try
		{
			$ssrsProxy.CreateFolder($reportFolder, $reportPath, $null)
			Write-Host "[Install-SSRSRDL()] Created new folder: $reportFolder"
		}
		catch [System.Web.Services.Protocols.SoapException]
		{
			if ($_.Exception.Detail.InnerText -match "[^rsItemAlreadyExists400]")
			{
				Write-Host "[Install-SSRSRDL()] Folder: $reportFolder already exists."
			}
			else
			{
				$msg = "[Install-SSRSRDL()] Error creating folder: $reportFolder. Msg: '{0}'" -f $_.Exception.Detail.InnerText
				Write-Error $msg
			}
		}
		
	}
	
	#Set reportname if blank, default will be the filename without extension
	if($reportName -eq "") { $reportName = [System.IO.Path]::GetFileNameWithoutExtension($rdlFile);}
	Write-Host "[Install-SSRSRDL()] Report name set to: $reportName"
	
	try
	{
		#Get Report content in bytes
		Write-Host "[Install-SSRSRDL()] Getting file content (byte) of : $rdlFile"			
		$byteArray = gc $rdlFile -encoding byte
		$msg = "[Install-SSRSRDL()] Total length: {0}" -f $byteArray.Length			
		Write-Host $msg

		$reportFolder = $reportPath + $reportFolder
		Write-Host "[Install-SSRSRDL()] Uploading to: $reportFolder"			
		
		#Call Proxy to upload report
		$warnings = $ssrsProxy.CreateReport($reportName,$reportFolder,$force,$byteArray,$null)
		if($warnings.Length -eq $null) { Write-Host "[Install-SSRSRDL()] Upload Success." }
		else { $warnings | % { Write-Warning "[Install-SSRSRDL()] Warning: $_" }}
	}
	catch [System.IO.IOException]
	{
		$msg = "[Install-SSRSRDL()] Error while reading rdl file : '{0}', Message: '{1}'" -f $rdlFile, $_.Exception.Message
		Write-Error msg
	}
	catch [System.Web.Services.Protocols.SoapException]
	{
		$msg = "[Install-SSRSRDL()] Error while uploading rdl file : '{0}', Message: '{1}'" -f $rdlFile, $_.Exception.Detail.InnerText
		Write-Error $msg
	}
	
}

function Backup-SPSolutions 
{
    param (
        [Parameter(Mandatory=$true)][string] $Path,
	    [Parameter(Mandatory=$false)][string] $SolutionName
    )

    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")

    $solutions = Get-SPFarm | Select -Expand Solutions
    if( -not( [string]::IsNullOrEmpty($SolutionName) ) ) { 
        $solutions = @( $solutions | Where { $_.Name -eq $SolutionName } )
    }

    foreach( $solution in $solutions ) {
        $full_name = Join-Path -Path $path -ChildPath $solution.Name
        $solution.SolutionFile.SaveAs( $full_name )
    }
}