#Global Variables
$global:deploy_steps = @()

#Helper Functions
function Log-Step
{
    param( 
        [string] $step,
        [switch] $nobullet
    )

    if( $nobullet ) { 
        $global:deploy_steps += "<p>" + $step + "</p>"
    }
    else {
        $global:deploy_steps += "<li>" + $step + "</li>"
    }
}

function Get-SSRSWebServiceUrl
{
    Set-Variable -Name prod -Value ""
    Set-Variable -Name uat -Value ""

    if( $environment -imatch "prod" ) { 
        $url = "http://{0}/ReportServer/ReportService2005.asmx?WSDL" -f $prod
    } 
    else { 
        $url = "http://{0}/ReportServer/ReportService2005.asmx?WSDL" -f $uat
    }

    return $url
}

function Get-SPServers 
{
    param( [string] $type = "Microsoft SharePoint Foundation Workflow Timer Service" )
   
	$servers = Get-SPServiceInstance | 
	    Where { $_.TypeName -eq $type -and $_.Status -eq "Online" } | 
		Select -Expand Server | 
		Select -Expand Address 

    return $servers
}

function Get-SPUserViaWS
{
    param ( [string] $url, [string] $name )
	$service = New-WebServiceProxy ($url + "_vti_bin/UserGroup.asmx?WSDL") -Namespace User -UseDefaultCredential
	$user = $service.GetUserInfo("i:0#.w|$name") 
    return $user.user.id + ";#" + $user.user.Name
}

function Get-SPDeploy
{
    param( [string] $version, [string] $build ) 
	$deploys = Get-SPListViaWebService -url $team_site -list $team_list -View $team_view 
    return $deploys | where { $_.CodeVersion -eq $version -and $_.VersionNumber -eq $build } | Select -First 1
}

function Record-Deployment
{ 	
    param(
        [string] $code_version,
        [string] $code_number,
        [string] $environment
    )

	Write-Host "============================"
	$global:deploy_steps 
	Write-Host "============================"
	
    $existing_deploy = Get-SPDeploy -version $code_version -build $code_number

	$date = $(Get-Date).ToString("yyyy-MM-ddThh:mm:ssZ")
	$user = Get-SPUserViaWS -url $team_site -name ($ENV:USERDOMAIN + "\" + $ENV:USERNAME)

	if( ! $existing_deploy ) {
		$deploy = @{
			Title = "Automated $app Deployment"
            Application = ";#$app;#"
			CodeLocation = $src
			DeploymentSteps = $global:deploy_steps 
			CodeVersion = $code_version
			VersionNumber = $code_number
			Notes = "Deployed on $ENV:COMPUTERNAME from $src . . .<BR/>"
		}
			
		if( $environment -imatch "uat" ) {
			$deploy.Add( 'UAT_x0020_Deployment', $date )
			$deploy.Add( 'UAT_x0020_Deployer', $user )
		} 
		else {
			$deploy.Add( 'PROD_x0020_Deployment', $date )
			$deploy.Add( 'PROD_x0020_Deployer', $user ) 
		}
	
		WriteTo-SPListViaWebService -url $team_site -list $team_list -Item $deploy
        $existing_deploy = Get-SPDeploy -version $code_version -build $code_number
	}
	else { 
        if( $url -imatch "-uat" ) {
        	$existing_deploy | Add-Member -Type NoteProperty -Name UAT_x0020_Deployment -Value $date 
			$existing_deploy | Add-Member -Type NoteProperty -Name UAT_x0020_Deployer $user 
        }
        else {
			$existing_deploy | Add-Member -Type NoteProperty -Name PROD_x0020_Deployment -Value $date 
			$existing_deploy | Add-Member -Type NoteProperty -Name PROD_x0020_Deployer $user 
        }
 
		$existing_deploy.Notes += "Deployed on $ENV:COMPUTERNAME from $src . . .<BR/>"
		$existing_deploy.DeploymentSteps += $global:deploy_steps  
		Update-SPListViaWebService -url $team_site -list $team_list -Item (Convert-ObjectToHash $existing_deploy) -Id  $existing_deploy.Id	
	}

    $document_link = $document_link -f $existing_deploy.Id
    Write-Host "Documentation Created/Updated at - $document_link"
}


