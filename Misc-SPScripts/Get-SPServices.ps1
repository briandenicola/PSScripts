param(
    [Parameter(Mandatory=$true)][string[]] $computers,
    [string] $file
)

$check_service_instance_status = {
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
	Get-SPStartedServices
}
	
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

$result = Invoke-Command -ComputerName $computers -Authentication Credssp -Credential (Get-Creds) -ScriptBlock $check_service_instance_status |
	Select Service, Server |
	Sort -Property Service 

if( $file -eq [string]::Empty ) {
    $result 
} else {
    $result | Export-Csv -Encoding ASCII -NoTypeInformation $file
}