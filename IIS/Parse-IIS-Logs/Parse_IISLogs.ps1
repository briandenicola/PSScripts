#############################
#Script - Parse_IISLogs.ps1
#Author - Brian Denicola
#############################
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $true)]
    [string] $ConfigFile,
    [switch] $upload
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

$sb = {
    param( 
        [Object] $sites,
        [Object] $queries,
        [string] $output_path,
        [string] $log_path,
        [string] $log_file
    )
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")
    $LOGPARSE = "d:\Utils\logparser.exe"
	
    foreach ( $site in $sites ) {
        $id = "W3SVC" + (Get-Website | where { $_.Name -imatch $site.Name } | Select -Expand id).ToString()
        $log = $log_path + "\" + $id + "\" + $log_file
		
        Write-Host ("Log file - " + $log)		
				
        if ( Test-Path $log ) {	
            foreach ( $query in $queries ) {
                Write-Host ("Query - " + $query)
		
                $path = Join-Path $output_path $query.output_file 
                $out_file = $path -f $site.name, $log_file.TrimStart("ex").TrimEnd(".log").Replace("*", ""), $Env:COMPUTERNAME
                $sql = $query.sql -f $out_file, $log
			
                Write-Host ("LogParse query - " + $sql)
                &$LOGPARSE $sql -o:CSV
            }
        }
    }
}

function Get-IISFileName {			
    param(
        [string] $logformat,
        [string] $range = "daily"
    )
	
    if ( $range -eq "monthly" ) {
        return $(Get-Date).AddMonths(-1).ToString($logformat) + "*.log"
    }
    else {
        return $(Get-Date).AddDays(-1).ToString($logformat) + ".log"
    }
}

function main() {
    $sharepoint_library = $config.logparse.sharepoint

    $log_name = Get-IISFileName -logformat $config.logparse.fileformat -range $config.logparse.logging_range

    Write-Verbose ("Log Name - " + $log_name)
	
    $sites += @($config.logparse.sites.site)
    $queries += @( $config.logparse.queries.query | ? { -not [String]::IsNullOrEmpty($_.sql) } )
	
    Write-Verbose ("Going to Enter PSSession with script block - " + $sb )
    $session = New-PSSession -ComputerName $config.logparse.servers.server
    $job = Invoke-Command -AsJob -Session $session -ScriptBlock $sb -ArgumentList $sites, $queries, $config.logparse.out_path, $config.logparse.in_path, $log_name
    Get-Job -id $job.id | Wait-Job | Out-Null
    Write-Verbose ("End PSSession")
		
    foreach ( $server in $config.logparse.servers.server ) {
        $output_path = "\\" + $server + "\" + $config.logparse.out_path.Replace( ":", "$" )
        $split_on = "-" + $server.SubString(0, 3)
	
        Write-Verbose ("Working on " + $server + " - " + $output_path)
	
        Get-ChildItem $output_path -recurse -Include "*.csv" | % {
            $merged_file_name = $ENV:TEMP + "\" + [regex]::Split($_.Name, $split_on)[0] + ".csv"
			
            Write-Verbose ("Writing " + $_.FullName + " to merged file - " + $merged_file_name)
		
            Get-Content $_.FullName | Out-File -Append -Encoding ascii $merged_file_name
            Remove-Item $_.FullName
        }
    }

    foreach ( $file in (Get-ChildItem $ENV:TEMP -Include "*.csv" -recurse) ) {
        if ($upload)	{
            UploadTo-Sharepoint -file $file.FullName -lib ($sharepoint_library + $file.Name.Split("_")[0] + "/")
            Remove-item $file.FullName
        } 
        else {
            Move-Item $file.FullName .
        }
    } 

    Get-PSSession | Remove-PSSession
}
$config = [xml] ( gc $ConfigFile )
main