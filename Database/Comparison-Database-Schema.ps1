[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[string] $reference_server,
	[string] $difference_server,
	[string] $dbs
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")

$global:logFile = Join-Path $PWD.PATH ("database-schema-comparison-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log" ) 

function log( [string] $txt ) 
{
	begin {
	
	}
	process {
		if ( $_ -ne $null ) { $txt = $_ }
		$entry = "[" + (Get-Date).ToString() + "] - " + $txt  + " . . ."
		$entry | out-file -Encoding ascii -Append $global:logFile
		Write-Host $entry
	}
	end {
	}
}

$query_table = @"
	 SELECT [t].[name] AS [TableName],
 		[c].[name] AS [ColumnName],
		CASE WHEN [c].[max_length] >= 0 AND [types].[name] IN (N'nchar', N'nvarchar') THEN ([c].[max_length] / 2) ELSE [c].[max_length] END AS [Length],	
 		[types].[name] AS [TypeName]
	 FROM    [sys].[columns] [c]
	 INNER   JOIN [sys].[objects] [t] WITH (NOLOCK) ON [c].[object_id] = [t].[object_id]
 	 LEFT    JOIN [sys].[types] [types] WITH (NOLOCK) ON [c].[user_type_id] = [types].[user_type_id]
 	 WHERE   [t].[type] IN ('U', 'FT')
 	 ORDER   BY [t].[name]
"@
	
$query_stored_procedure = @"
	 SELECT  
		[sp].[name] AS [ProcedureName], 
    	[ssm].[definition] AS [Text]
	 FROM   
	 	[sys].[sql_modules] [ssm] WITH (NOLOCK),
		[sys].[procedures] [sp] WITH (NOLOCK)
	 WHERE  
		[sp].[object_id] = [ssm].[object_id] AND
		[sp].[object_id] NOT IN (SELECT [major_id] FROM [sys].[extended_properties] WHERE [minor_id] = 0 AND [class] = 1 AND [name] = N'microsoft_database_tools_support')
"@

$query_views = @"
	SELECT  [sv].[name] AS [ViewName], 
        [sc].[name] AS [ColumnName], 
        SCHEMA_NAME([sv].[schema_id]) AS [ViewOwner]
	FROM    [sys].[views] [sv] WITH (NOLOCK) 
	INNER   JOIN [sys].[columns] [sc] WITH (NOLOCK) ON [sc].[object_id] = [sv].[object_id]
	WHERE   [sv].[is_ms_shipped] = 0
	ORDER   BY SCHEMA_NAME([sv].[schema_id]), [sv].[name], [sc].[column_id]
"@

$comparisons = New-Object PSObject -Property @{
	TableComparison = @{ "Name" = "Tables"; "GroupByProperty" = "TableName"; "SQL" = $query_table  }
	ViewComparison = @{ "Name" = "Views"; "GroupByProperty" = "ViewName"; "SQL" = $query_views }
	SPComparison = @{ "Name" = "Stored Procedures"; "GroupByProperty" = "ProcedureName"; "SQL" =  $query_stored_procedure }
}
$comparisons | Add-Member -MemberType ScriptProperty -Name GetProperties -Value { $this | Get-Member | Where { $_.MemberType -eq "NoteProperty" } | Select -Expand Name } 

function main()
{
	foreach( $compare in $comparisons.GetProperties )
	{	
		log -txt ("Comparing " + $comparisons.$compare.Name  + " on $difference_server and $reference_server for the $dbs database")
		$ref_objects = Query-DatabaseTable -server $reference_server -db $dbs -sql $comparisons.$compare.SQL 
		$dif_objects = Query-DatabaseTable -server $difference_server -db $dbs -sql $comparisons.$compare.SQL 
	
		if( $ref_objects -ne $null -and $dif_objects -ne $null )
		{	
			$columns = @()
			$ref_objects | Get-Member | Where { $_.MemberType -eq "NoteProperty" } | Select -Expand Name | % { $columns += $_.ToString() }
			
			$ref_hash = $ref_objects | Group-Object -Property $comparisons.$compare.GroupByProperty -AsHashTable
			$dif_hash = $dif_objects | Group-Object -Property $comparisons.$compare.GroupByProperty -AsHashTable
					
			foreach( $key in $ref_hash.Keys )
			{
				log -txt "`tComparing $key"
				
				try
				{
					Compare-Object -referenceObject $ref_hash[$key] -differenceObject $dif_hash[$key] -Property $columns | Log 
				}
				catch
				{
					log -txt ("`t`t" + $_.Exception.ToString() )
				}
			}
			
		} elseif( $ref_objects -eq $null -and $dif_objects -ne $null )	{
			log -txt ("`t" + $comparisons.$compare.Name + " on $reference_server is null but $difference_server has the following " + $dif_objects ) 
		} elseif( $ref_objects -ne $null -and $dif_objects -eq $null )	{
			log -txt ("`t" + $comparisons.$compare.Name + " on $difference_server is null but $reference_server has the following " + $ref_objects ) 
		} else {
			log -txt ("`t" + $comparisons.$compare.Name + " are empty on both $reference_server and $difference_server")
		}
		
	}
}
main



