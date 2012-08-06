param (
	[string] $file,
	[string] $dbs
)

$res = @()

import-csv $file | select -unique "Database Instance" | % {
 $inst = $_."Database Instance"
 $res += Query-DatabaseTable -server $dbs -dbs $inst -sql "Select * from versions" | Select Version, TimeStamp, UserName, @{Name="Database"; Expression={$inst}}
}

return $res