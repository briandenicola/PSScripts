param(
    [string] $url,
    [string] $list 
)

$service = New-WebServiceProxy (Get-WebServiceURL -url $url) -Namespace List -UseDefaultCredential		
$FieldsWS = $service.GetList($list)
$Fields = $FieldsWS.Fields.Field | where { $_.Hidden -ne "TRUE"} | Select DisplayName, StaticName -Unique
    
return $Fields