function Log-Event( [string] $txt, [switch] $toScreen ) 
{
	if( $toScreen ) { Write-Host "[" (Get-Date).ToString() "] - " $txt }
	"[" + (Get-Date).ToString() + "]," + $txt | Out-File $global:LogFile -Append -Encoding ASCII 
}

function Execute-ComponentCommand 
{
    param (
        [string] $url,
        [switch] $operation
    )

    $url = $url -replace ("http://|https://")
    $cfg = $cfgFile.configs.components.config | Where { $_.Url -eq $url }

	if( $cfg -eq $nul ) {
		throw "Could not find an entry for the URL in the XML configuration"
	}
	
	$deployment_map = Get-DeploymentMapCache -url $url 
	if( $deployment_map -eq $nul -or $force -eq $true )	{
		$deployment_map = Create-DeploymentMap -url $url -config $cfg
		Set-DeploymentMapCache -map $deployment_map -url $url
	}

	if( ($deployment_map | Select -First 1 Source).Source -eq $nul ) {	
		throw  "Could not find any deployment mappings for the url"
	}
		
	switch($operation)
	{
		backup 		{ Backup-Config $deployment_map }
		validate	{ Validate-Config $deployment_map }
		deploy		{ Deploy-Config $deployment_map }
	}
}

function Get-MostRecentFile([string] $src )
{
	return ( Get-ChildItem $src | Where { $_.name -notmatch "rolledback" } | Sort LastWriteTime -desc | Select -first 1 | Select -ExpandProperty Name )
}

function Backup-Config( [Object[]] $map )
{
    $sb_backup = {
	    param( 
		    [string] $source, 
		    [string] $destination
	    )
        . (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
	    Copy-Item -Verbose -Force $source $destination
    }

	foreach( $config in $map ) {
		$source_file = Join-Path $config.Destination $config.File
		$backup_file = Join-Path $config.Source ($config.File + "." + $(Get-Date).ToString("yyyyMMddhhmmss"))
		
		if( $config.Servers -is [string] ) {
			$backup_server = $config.Servers
		}
		else {
			$backup_server = $config.Servers[0]
		}
		
		Write-Verbose -Message ("Backup Server - $backup_server")
		
		if ($pscmdlet.shouldprocess($backup_server, "Copying $source_file to $backup_file" ) ) {
			Log-Event -txt ("Backing up " + $config.File + " to " + $backup_file) -toScreen	
            Invoke-Command -ComputerName $backup_server `
                -Authentication CredSSP `
                -Credential $global:Cred `
                -ScriptBlock $sb_backup `
                -ArgumentList $source_file, $backup_file
		}
	}
}

function Deploy-Config( [Object[]] $map )
{
    $sb_deploy = { 
	    param( 
		    [string] $source, 
		    [string] $destination
	    )

	    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
	    if( (Get-Hash1 $source) -ne (Get-Hash1 $destination) ) {
		    Copy-Item -Verbose -Force $source $destination
	    }
	    else {
		    Write-Host "Skipped copy on" $env:COMPUTERNAME ". File hashes match" -ForegroundColor Yellow
	    }
    }

	foreach( $config in $map ) {
		$most_recent_file = Join-Path $config.Source (Get-MostRecentFile $config.Source)
		
		if ($pscmdlet.shouldprocess($config.Servers, "Deploying $most_recent_file" ) ) {
			Log-Event -txt ("Deploying $most_recent_file to " + $config.Destination + " on " + $config.Servers) -toScreen	
			Invoke-Command -ComputerName $config.Servers `
                -Authentication CredSSP `
                -Credential $global:Cred `
                -ScriptBlock $sb_deploy `
                -ArgumentList $most_recent_file, (Join-Path $config.Destination $config.File)
		}
	}
}

function Validate-Config(  [Object[]] $map )
{ 
    $sb_validate ={ 
        param( [string] $file )
        . (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
        Write-Host ("[{0}] : {1}" -f $ENV:ComputerName, (Get-Hash1 $file))
    }

	foreach( $config in $map ) {
		$most_recent_file = $config.Source + "\" + ( Get-MostRecentFile $config.Source )
		Write-Host ("[Source File] : {0} = {1} " -f $most_recent_file,(Get-Hash1 $most_recent_file))
		
		Invoke-Command -ComputerName $config.Servers `
            -ScriptBlock $sb_validate `
            -ArgumentList (Join-Path $config.Destination $config.File)
	}
}
