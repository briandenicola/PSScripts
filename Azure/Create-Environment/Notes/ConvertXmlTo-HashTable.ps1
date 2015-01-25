function ConvertXmlTo-HashTable
{
    param(
        [System.Xml.XmlElement] $xml
    )

    function __Get-Properties
    {
        return ($xml | Get-Member -MemberType Property | Select -ExpandProperty Name)
    }

    $ht = @{}
    
    foreach( $node in (__Get-Properties $xml.ChildNodes) ) {
        if( $xml.$node -is [string] ) {
            $ht[$node] = $xml.$node
        }
        elseif (  $xml.$node -is [System.Xml.XmlElement] ) {
            $ht[$node] = ConvertXmlTo-HashTable -xml $xml.$node
        }
        elseif (  $xml.$node -is [System.Object[]] ) {
            foreach( $sub_node in $xml.$node ) {
                $ht[$node] += @(ConvertXmlTo-HashTable -xml $sub_node)
            }
        }
    }
    
    return $ht
}