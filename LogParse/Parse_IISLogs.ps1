#############################
#Script - Parse_IISLogs.ps1
#Author - Brian Denicola
#############################
[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
	[string] $ConfigFile,
	[switch] $upload
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

$map_scriptblock = {
	param( 
		[string] $site,
        [string] $id = [string]::empty,
		[string] $query,
        [string] $log_path = "D:\Logs",
		[string] $log_file
	)
	
	$log_parse = "D:\Utils\logparser.exe"
	$tmp_output = Join-Path $env:TEMP "results.csv"

    if( !(Test-Path $log_parse) ) {
        throw "Could not find $log_parse. Must exit"
    }

    if( $id -eq [string]::Empty ) {
        . (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")
        $id = (Get-WebSite | Where { $_.Name -imatch $site } | Select -First 1 -ExpandProperty Id).ToString()
    }

	$log =  Join-Path $log_path (Join-Path $id $log_file) 
    if( Test-Path $log )  {	
        $sql = $query -f $log, $tmp_output
		Invoke-Expression $log_parse $query -o:CSV
	}

    return (Import-Csv $tmp_output)
}

$reduce_scriptblock = {

}

function Get-IIS-FileName 
{			
	param(
		[string] $format,
		[string] $type = "daily"
	)
	
	if( $type -eq "monthly" ) {
		return $(Get-Date).AddMonths(-1).ToString($format) + "*.log"
	}
	else {
		return $(Get-Date).AddDays(-1).ToString($format) + ".log"
	}
}

function main()
{
	$sharepoint_library = $config.logparse.settings.sharepoint
	$log = Get-IIS-FileName -format $config.logparse.settings.fileformat -type $config.logparse.settings.type

	$session = New-PSSession -ComputerName $config.logparse.servers.server
	
    foreach( $query in $config.logparse.queries.query ) {
        foreach( $site in $config.logparse.sites.site ) {
            $file = Join-Path $ENV:TEMP ( $query.output_file -f $site.Name, $(Get-Date).ToString("yyyyMMdd") )

            Invoke-Command -Session $session -ScriptBlock $map_scriptblock -ArgumentList $site.Name, $site.Id, $query.sql, $config.logparse.settings.log_folder, $log |
                Export-Csv -Encoding ASCII $file

		    if($upload) {
			    UploadTo-Sharepoint -file $file -lib ($sharepoint_library + $file + "/")
			    Remove-item $file
		    } 
		    else  {
			    Move-Item $file $PWD.Path
		    }
        }
	} 

	Get-PSSession | Remove-PSSession
}
$config = [xml] ( gc $ConfigFile )
main