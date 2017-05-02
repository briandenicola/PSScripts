[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]    $ResourceGroup
)

try { 
    Get-AzureRmContext | Out-Null
}
catch { 
    Write-Verbose -Message ("[{0}] - Logging into Azure" -f $(Get-Date))
    Login-AzureRmAccount 
}

$insight = Get-AzureRmResource -ResourceGroupName $ResourceGroup -ResourceType Microsoft.Insights/components
$slots = Get-AzureRmResource -ResourceGroupName $ResourceGroup -ResourceType Microsoft.web/sites/slots
$apps = Get-AzureRmResource -ResourceGroupName $ResourceGroup -ResourceType Microsoft.web/sites

foreach( $app in $apps ) {
    Write-Verbose -Message ("[{0}] - Linking {1} App Service to {2}  . . ." -f $(Get-Date), $app.Name, $insight.Name)
    $insight.tags.Add(('hidden-link:{0}' -f $app.ResourceId), 'Resource')
}

foreach( $slot in $slots ) {
    Write-Verbose -Message ("[{0}] - Linking {1} App Service Slot to {2} . . ." -f $(Get-Date), $slot.Name, $insight.Name)
    $insight.tags.Add(('hidden-link:{0}' -f $slot.ResourceId), 'Resource')
}

foreach( $tag in $insight.tags.Keys ) {
    Write-Verbose -Message ("`t{0}  . . ." -f $tag)
}
Set-AzureRmResource -ResourceId $insight.ResourceId -Tag $insight.tags -Confirm:$true
