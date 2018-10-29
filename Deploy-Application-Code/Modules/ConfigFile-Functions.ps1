function Get-MostRecentFile([string] $src ) {
    return ( Get-ChildItem $src | Where { $_.name -notmatch "rolledback" } | Sort LastWriteTime -desc | Select -first 1 | Select -ExpandProperty Name )
}

function Get-NewFileName( [string] $src ) {
    $now = $(Get-Date).ToString("yyyyMMddHHmmss")
    $file = Get-Item $src | Select BaseName, DirectoryName
    return ( Join-Path -Path $file.DirectoryName -ChildPath ("{0}.{1}" -f $file.BaseName, $now) ) 
}

function Update-ConfigFile { 
    param(
        [string] $config_file,
        [string] $line_to_update,
        [string] $new_line
    )

    $file = Get-Content -Path $config_file
    $file | Foreach { $_.Replace($line_to_update, $new_line) } | Set-Content -Encoding Ascii -Path $config_file

}

function DeleteFrom-ConfigFile {
    param(
        [string] $config_file,
        [string] $line_to_delete
    )

    $file = Get-Content -Path $config_file 
    $file | Where { $_ -ne $line_to_delete } | Set-Content -Encoding Ascii -Path $config_file
}

function AddTo-ConfigFile {
    param(
        [string] $config_file,
        [string] $node,
        [string] $parent,
        [System.Xml.XmlDocument] $xml_update
    )

    $config = [xml] ( Get-Content -Path $config_file )
    $update = $config.ImportNode($xml_update.SelectSingleNode($node), $true)
    $config.SelectSingleNode($parent).AppendChild($update) | Out-Null
    $config.Save($config_file)
}

function Execute-ComponentCommand {
    param (
        [string] $url,
        [string] $operation
    )

    $url = $url -replace ("http://|https://")
    $cfg = $cfgFile.configs.components.config | Where { $_.Url -eq $url }

    Write-Verbose -Message ("Executing {0} for {1}" -f $operation, $url)

    if ( $cfg -eq $nul ) {
        throw "Could not find an entry for the URL in the XML configuration"
    }
	
    $deployment_map = Get-DeploymentMapCache -url $url 
    if ( $deployment_map -eq $nul -or $force -eq $true )	{
        $deployment_map = New-DeploymentMap -url $url -config $cfg
        Set-DeploymentMapCache -map $deployment_map -url $url
    }

    if ( ($deployment_map | Select -First 1 Source).Source -eq $nul ) {	
        throw  "Could not find any deployment mappings for the url"
    }

    Write-Verbose ("Deployment Map for {0} ..." -f $url)
    foreach ( $map in $deployment_map ) {
        Write-Verbose ("Source - {0}" -f $map.Source)
        Write-Verbose ("Destination - {0}" -f $map.Destination)
        Write-Verbose ("Servers - {0}" -f $map.Servers)
        Write-Verbose ("File - {0}" -f $map.File)

    } 

    switch ($operation) {
        backup { Backup-Config $deployment_map }
        validate	{ Validate-Config $deployment_map }
        deploy { Deploy-Config $deployment_map }
    }
}

function Backup-Config( [Object[]] $map ) {
    $sb_backup = {
        param( [string] $source, [string] $destination )
        Copy-Item -Verbose -Force $source $destination
    }

    foreach ( $config in $map ) {
        $source_file = Join-Path -Path $config.Destination -ChildPath $config.File
        $backup_file = Join-Path -Path $config.Source      -ChildPath ("{0}.{1}" -f $config.File, $(Get-Date).ToString("yyyyMMddhhmmss"))
		
        if ( $config.Servers -is [string] ) {
            $backup_server = $config.Servers
        }
        else {
            $backup_server = $config.Servers[0]
        }
		
        Write-Verbose -Message ("Backup Server - $backup_server")
		
        if ($pscmdlet.shouldprocess($backup_server, "Copying $source_file to $backup_file" ) ) {
            Log -text ("Backing up {0} to {1}" -f $config.File, $backup_file)	
            Invoke-Command -ComputerName $backup_server `
                -Authentication CredSSP `
                -Credential (Get-Creds) `
                -ScriptBlock $sb_backup `
                -ArgumentList $source_file, $backup_file
        }
    }
}

function Deploy-Config( [Object[]] $map ) {
    $sb_deploy = { 
        param( [string] $source, [string] $destination  )

        . (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
        if ( (Get-Hash1 $source) -ne (Get-Hash1 $destination) ) {
            Copy-Item -Verbose -Force $source $destination
        }
        else {
            Write-Host ("Skipped copy on {0}. File hashes match" -f $env:COMPUTERNAME) -ForegroundColor Yellow
        }
    }

    foreach ( $config in $map ) {
        $most_recent_file = Join-Path $config.Source (Get-MostRecentFile $config.Source)

        if ($pscmdlet.shouldprocess($config.Servers, "Deploying $most_recent_file" ) ) {
            Log -text ("Deploying {0} to {1} on {2}" -f $most_recent_file, $config.Destination, $config.Servers)
            Invoke-Command -ComputerName $config.Servers `
                -Authentication CredSSP `
                -Credential (Get-Creds) `
                -ScriptBlock $sb_deploy `
                -ArgumentList $most_recent_file, (Join-Path $config.Destination $config.File)
        }
    }
}

function Validate-Config(  [Object[]] $map ) { 
    $sb_validate = { 
        param( [string] $file )
        . (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
        return ( New-Object PSObject -Property @{ Computer = $ENV:ComputerName; File = $file; Hash = (Get-Hash1 $file) })
    }

    $results = @()
    foreach ( $config in $map ) {
        $most_recent_file = Join-Path -Path $config.Source -ChildPath ( Get-MostRecentFile $config.Source )
        $results += New-Object PSObject -Property @{ Computer = "[SOURCE FILE]"; File = $most_recent_file; Hash = (Get-Hash1 $most_recent_file) }
        $results += Invoke-Command -ComputerName $config.Servers `
            -ScriptBlock $sb_validate `
            -ArgumentList (Join-Path $config.Destination $config.File)
    }

    $results | Select Computer, File, Hash | Format-Table 
}