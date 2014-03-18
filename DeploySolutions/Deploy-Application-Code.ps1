param ( 
	[Parameter(Mandatory=$true)][string] $src,
	[Parameter(Mandatory=$true)][string] $url,
	[Parameter(Mandatory=$true)][string] $app,
	[switch] $record
)

#Load Libraries
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
. (Join-Path $PWD.Path "Modules\Deploy-Functions.ps1")
. (Join-Path $PWD.Path "Modules\Log-Functions.ps1")

Import-Module (Join-Path $ENV:SCRIPTS_HOME "\Libraries\Credentials.psm1")

#Constants
Set-Variable -Name log_home -Value "D:\Logs" -Option Constant
Set-Variable -Name document_link  -Value "http://example.com/sites/AppOps/Lists/Tracker/DispForm.aspx?ID={0}"
Set-Variable -Name team_site -Value "http://example.com/sites/AppOps/" -Option Constant
Set-Variable -Name team_list -Value "Deployment Tracker" -Option Constant
Set-Variable -Name team_view -Value '{}' -Option Constant

function main 
{
	if( $url -notmatch "http://" ) { $url = $url.Insert( 0, "http://" )  }
 
	$log = Join-Path $log_home ("Deploy-For-" + ( $url -replace "http://") + "-From-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log")
	&{Trap{continue};Start-Transcript -Append -Path $log}

	Write-Host "============================"
	Write-Host "Deployment Source Directory - $src"
	Write-Host "Deployment URL - $url"
	Write-Host "============================"
	
    Log-Step -step "Automated with $($MyInvocation.InvocationName) from $ENV:COMPUTERNAME . . ." -nobullet
    Log-Step -step "<strong> $app Steps Taken include - <ol>" -nobullet

	do
	{
	    $i=1
    	foreach( $item in $menu ) { Write-Host "$i) - $($item.Text) ..."; $i++ }
        $ans = [int]( Read-Host "Please Enter the Number  " )	    
        Invoke-Expression $menu[$ans-1].ScriptBlock
	} while ( $true )

    Log-Step -step "</ol><hr/>" -nobullet

    if($record) { Record-Deployment }

	Stop-Transcript
}
main