param ( 
	[string] $webApp
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

$features = @(
	"GT.US.ECM.R3.Core.Package_R3AdministrationStore",
	"GT.US.ECM.R3.UI.Package_GTR3ApplicationPagesMapping",
	"GT.US.ECM.R3.Forms.Package_R3RequestCESiteForm",
	"GT.US.ECM.R3.UI.Package_GTR3CollaborationSitesMapping",
	"GT.US.ECM.R3.Core.Package_R3ConfigurationStore",
	"GT.US.ECM.R3.UI.Package_GTR3CurrentEngagementsDataSourceMapping",
	"GT.US.ECM.R3.Core.Package_R3EmailTemplatesStore",
	"GT.US.ECM.R3.UI.Package_GTR3ExternalUsersDataSourceMapping",
	"GT.US.ECM.R3.Forms.Package_R3ExpiryApprovalForm",
	"GT.US.ECM.R3.Forms.Package_R3ExpiryEvaluationForm",
	"GT.US.ECM.R3.Forms.Package_R3RequestApprovalForm",
	"GT.US.ECM.R3.Forms.Package_R3RequestIESiteForm",
	"GT.US.ECM.R3.Forms.Package_R3RequestMESiteForm",
	"GT.US.ECM.R3.MultiUpload.Package_GTR3MultiUploadMapping",
	"GT.US.ECM.R3.Core.Package_R3NavigationStore",
	"GT.US.ECM.R3.Forms.Package_R3RequestNESiteForm",
	"GT.US.ECM.R3.UI.Package_GTR3PendingApprovalsDataSourceMapping",
	"GT.US.ECM.R3.UI.Package_GTR3ProvisioningDataSourceMapping",
	"GT.US.ECM.R3.UI.Package_GTR3RecordHistoryMapping",
	"GT.US.ECM.R3.UI.Package_GTR3RRLADataSourceMapping",
	"GT.US.ECM.R3.Core.Package_R3ServiceLinesStore",
	"GT.US.ECM.R3.Core.Package_R3SiteTemplatesStore",
	"GT.US.ECM.R3.UI.Package_GTR3SLADataSourceMapping",
	"GT.US.ECM.R3.Forms.Package_R3StatusForm",
	"GT.US.ECM.R3.Forms.Package_R3StatusNEForm",
	"GT.US.ECM.R3.UI.Package_GTR3TPQDataSourceMapping",
	"GT.US.ECM.R3.UI.Package_GTR3PendingItemsDataSourceMapping",
	"GT.US.SharePoint.V14.Package_V14ExceptionHandling",
	"GT.US.SharePoint.V14.Package_V14SharePointFoundation",
	"GT.US.SharePoint.V14.Package_V14SharePointUtility"
)


function Enable-WGCFeature
{
	param ( 
		[string] $featureName
	)
   
	Disable-SPFeature -Identity $featureName -Url $webApp -Confirm:$false -Verbose
	Sleep 1 
	Enable-SPFeature -Identity $featureName -Url $webApp -Verbose      
}

function main
{
	$log= $PWD.Path  + "\WGC_Features-" + $(get-date).tostring("mm_dd_yyyy-hh_mm_s") + ".txt"

	Start-Transcript -Path $log -Append
	foreach ( $feature in $features ) 
	{
		Write-Host "Enabling feature - " $feature 
		Enable-WGCFeature -featureName $feature 
	}

	$servers = Get-SPServer | where { $_.Role -ne "Invalid" } | Select -Expand Address 

	Invoke-Command -computer $servers -ScriptBlock {
		Write-Host "Restarting IIS on $ENV:COMPUTERNAME"
		iisreset 
		Restart-Service sptimerv4 -verbose
	}
	
	Stop-Transcript
}
main