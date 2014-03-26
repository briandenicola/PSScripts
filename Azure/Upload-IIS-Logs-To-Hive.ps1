#requires -version 3
[CmdletBinding(SupportsShouldProcess=$true)]
Param (
    [ValidateScript({Test-Path $_})]
    [Parameter(Mandatory=$true)]
    [string] $config_file 
)

. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Azure_Functions.ps1")
. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")

Set-Variable -Name log_parser -Value "d:\Utils\logparser.exe" -Option Constant
Set-Variable -Name query -Value "select * into {0} from {1}"
Set-Variable -Name load_query -Value "load data inpath {0} into table {1} partition(date = '{2}');"
Set-Variable -Name cfg -Value ([xml]( Get-Content $config_file ))

function Copy-LogsLocally
{
    param (
        [string[]] $servers,
        [string] $url,
        [string] $log_path,
        [string] $destination
    )

    $sb = {
       param(
        [string] $url,
        [string] $path,
        [string] $destination
       )

       Set-Variable -Name yesterday -Value ($(Get-Date).AddDays(-1))
       Set-Variable -Name log_file_name -Value ("u_ex{0}.log" -f $yesterday.ToString("yyMMdd"))
   
       $log_file = Join-Path -Path $path -ChildPath $log_file_name
       $destination_log_file = Join-Path -Path $destination -ChildPath ("{0}-{1}.log" -f $url, $env:COMPUTERNAME)
       Copy-Item $log_file $destination_log_file  
    }

    $job = Invoke-Command -ComputerName $servers -ScriptBlock $sb -ArgumentList $url, $log_path, $destination -AsJob
    $job | Wait-Job

    $result = Receive-Job $job

    Write-Verbose -Message ("Remote Job Id - " + $job.Id)
    Write-Verbose -Message ("Remote Job Command - " + $job.Command)
    Write-Verbose -Message ("Remote Job State - " + $job.State)
    Write-Verbose -Message ("Remote Job Output - " + $result)
}

function Combine-LogFiles 
{
    param(
        [string] $log_path,
        [string] $url
    )

    $combined_log_file = Join-Path -Path $log_path -ChildPath ("{0}-{1}.log" -f $url, $(Get-Date -Format "yyMMdd"))
    $tmp_file = Join-Path -Path $PWD.Path -ChildPath ([IO.Path]::GetRandomFileName())
    $log_files = Join-Path -Path $log_path -ChildPath ($url + "*.log")

    Write-Verbose -Message ("Using Logparse to execute query - " + $query)

    &$log_parser -i:W3C -o:W3C ($query -f $tmp_file, $log_files) -q
    
    Write-Verbose -Message ("Stripping out lines starting with # from - " + $tmp_file + " into " + $combined_log_file)

    $reader = [IO.File]::OpenText($tmp_file)    $writer = New-Object System.IO.StreamWriter($combined_log_file)
    for( $i=0; $i -lt 4; $i++ ) {
        $reader.ReadLine() | Out-Null    }    $writer.write($reader.ReadToEnd())
    $reader.Close()    $writer.Close()

    return $combined_log_file 
}

function Upload-BlobToAzure 
{
    param( 
        [string] $storage,
        [string] $container,
        [string] $file
    )

    $keys = Get-AzureStorageKey $storage | Select -ExpandProperty Primary 
    $storage_context = New-AzureStorageContext -StorageAccountName $storage -StorageAccountKey $keys

    if( $blob -eq [string]::Empty ) { 
        $blob = Get-Item $file | Select -ExpandProperty Name
    }
    
    Write-Verbose -Message ("Blob - " + $blob)
    Write-Verbose -Message ("Context - " + $storage_context)

    Set-AzureStorageBlobContent -File $file -Container $container -Blob $blob -context $storage_context
}

function Import-DataToHive
{
    param(
        [string] $cluster,
        [string] $storage,
        [string] $container,
        [string] $table,
        [string] $file
    )
    
    $file_name = Get-Item $file | Select -ExpandProperty Name

    $azure_location = "wasb://{0}@{1}.blob.core.windows.net/{2}" -f $container, $storage, $file_name
    $query = $load_query -f $azure_location, $table, $(Get-Date -Format "yyyy-MM-dd")

    Write-Verbose -Message ("Load Query - " + $query)

    $job_def = New-AzureHDInsightHiveJobDefinition -Query $query
    $job = Start-AzureHDInsightJob -Cluster $cluster -JobDefinition $job_def
    $job | Wait-AzureHDInsightJob
}

Select-AzureSubscription $cfg.logparse.hdinsight.subscription
Use-AzureHDInsightCluster $cfg.logparse.hdinsight.cluster

foreach( $site in $cfg.logparse.sites.site ) {
    log -txt "Removing files from $($cfg.logparse.log_copy_location.local)" -log $cfg.parse.log_file
    Remove-Item -Path ($cfg.logparse.log_copy_location.local + "*") -Force -Recurse -ErrorAction SilentlyContinue

    log -txt "Copy log files for $($site.Url) from $($site.log_path) to $($cfg.logparse.log_copy_location.remote)" -log $cfg.parse.log_file
    Copy-LogsLocally -url $site.url -servers $site.servers.server -log_path $site.log_path -destination $cfg.logparse.log_copy_location.remote

    log -txt "Merge log files" -log $cfg.parse.log_file 
    $combined_file = Combine-LogFiles -log_path $cfg.logparse.log_copy_location.local -url $site.url

    log -txt "Upload $combined_file to $($cfg.logparse.hdinsight.storage) in the container $( $cfg.logparse.hdinsight.container)" -log $cfg.parse.log_file
    Upload-BlobToAzure -storage $cfg.logparse.hdinsight.storage -container $cfg.logparse.hdinsight.container -file $combined_file

    log -txt "Importing Data from $combined_file into table $($site.hive_table_name) in HDInsight cluster - $($cfg.logparse.hdinsight.cluster)"  -log $cfg.parse.log_file
    Import-DataToHive -cluster $cfg.logparse.hdinsight.cluster -storage $cfg.logparse.hdinsight.storage -container $cfg.logparse.hdinsight.container -table $site.hive_table_name -file $combined_file
}
Remove-Item -Path ($cfg.logparse.log_copy_location.local + "*") -Force -Recurse -ErrorAction SilentlyContinue