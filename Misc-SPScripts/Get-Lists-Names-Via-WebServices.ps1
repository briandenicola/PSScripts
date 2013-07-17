param (
    [string] $url
)

$service = New-WebServiceProxy (Get-WebServiceURL -url $url) -Namespace List -UseDefaultCredential

return ( 
    $service.GetListCollection() | Select -ExpandProperty List | Select Title, Id, ItemCount, Created, Modified
)