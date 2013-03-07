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
		&$log_parse $sql -q -o:CSV -i:IISW3C
	}

	if( Test-Path $tmp_output ) {
	    return (Import-Csv $tmp_output)
	}

	return @()
	
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
        foreach( $site in $config.logparse.sites.site  ) {
            $name = $query.output_file -f $site.Name, $(Get-Date).ToString("yyyyMMdd")
            $file = Join-Path (Join-Path $ENV:SystemRoot "TEMP") $name

            Write-Verbose ("File - " + $file )
            Invoke-Command -Session $session -ScriptBlock $map_scriptblock -ArgumentList $site.Name, $site.Id, $query.sql, $config.logparse.settings.log_folder, $log |
                Export-Csv -Encoding ASCII -NoTypeInformation $file

		    if($upload) {
                $path = (Get-Item $file | Select -Expand BaseName).Split("_") | Select -First 1
			    UploadTo-Sharepoint -file $file -lib ($sharepoint_library + $path + "/")
			    Remove-item $file
		    } 
            else  {
                if( Test-Path $file ) {
			        Move-Item $file $PWD.Path -ErrorAction SilentlyContinue
			    }
		    }
        }
	} 

	Get-PSSession | Remove-PSSession
}
$config = [xml] ( gc $ConfigFile )
main