#Constants
Set-Variable -Name app_home         -Value $PWD.Path
Set-Variable -Name log_home 		-Value (Join-Path -Path $app_home -ChildPath "Logs") -Option Constant
Set-Variable -Name global:log_file  -Value (Join-Path -Path $log_home -ChildPath ("Application-Deployment-{0}.log" -f $(Get-Date).ToString("yyyyMMddhhmmss")))

#SharePoint Document Repository Constants
Set-Variable -Name document_link  	-Value "http://example.com/sites/AppOps/Lists/Tracker/DispForm.aspx?ID={0}"
Set-Variable -Name team_site 		-Value "http://example.com/sites/AppOps/" -Option Constant
Set-Variable -Name team_list 		-Value "Deployment Tracker" -Option Constant
Set-Variable -Name team_view 		-Value '{}' -Option Constant

#Internal Dependent Scripts
Set-Variable -Name deploy_solutions -Value (Join-Path -Path $app_home -ChildPath "ScriptBlocks\Deploy-Sharepoint-Solutions.ps1") -Option Constant
Set-Variable -Name deploy_configs 	-Value (Join-Path -Path $app_home -ChildPath "ScriptBlocks\Deploy-AppConfigs.ps1") -Option Constant
Set-Variable -Name update_configs 	-Value (Join-Path -Path $app_home -ChildPath "ScriptBlocks\Update-WebConfigs.ps1") -Option Constant
Set-Variable -Name enable_features  -Value (Join-Path -Path $app_home -ChildPath "ScriptBlocks\Enable-Features.ps1") -Option Constant

#External Dependent Scripts
Set-Variable -Name validate_environment -Value (Join-Path $ENV:SCRIPTS_HOME "Validate-URLs\Validate-URLs.ps1") -Option Constant

#SSRS URLs
Set-Variable -Name ssrs             -Value @{ "Prod" = "http://{0}/ReportServer/ReportService2005.asmx?WSDL"; "UAT" = "http://{0}/ReportServer/ReportService2005.asmx?WSDL" }

