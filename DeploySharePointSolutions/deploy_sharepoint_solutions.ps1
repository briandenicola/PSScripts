[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
	[string] $deploy_directory,
	[string] $web_application,
	[switch] $noupgrade
)

. ..\Libraries\Standard_functions.ps1
. ..\Libraries\SharePoint2010_functions.ps1

$global:logFile = ".\sharepoint2010_solution_deployment-" +  $(Get-Date).ToString("yyyyMMdd") + ".log"

Start-SPAssignment -Global

function HashTable_Output( [HashTable] $ht )
{
	$ht.Keys | % { $output += $_ + ":" + $ht[$_] + "," }
	return $output.TrimEnd(",")
}

function log_deployment ( [string] $txt )
{
	Write-Verbose $txt
	log -log $global:logFile -txt $txt
}

function Wait-Job ( [string] $solution )   
{
   	$job_name = "solution-deployment-$solution*"   
	$job = Get-SPTimerJob | where { $_.Name -like $job_name }  -ErrorAction:SilentlyContinue  
	
    if ($job)    
	{
        Write-Host -NoNewLine "Waiting to deployment job - $job.Name - to finish . . ."           

		while ((Get-SPTimerJob $job.Name) -ne $null)        
        {
            Write-Host -NoNewLine .
            Start-Sleep -Seconds 5       
	    }
        Write-Host -NoNewline "...Complete"
    }
}

function Deploy-SPSolution( [Object] $package )
{
	log_deployment "Solution - $package.Name - was not found in SharePoint. Will attempt to add and deploy the solution"
	$solution = Add-SPSolution -LiteralPath $package.FullName
	
	$options = @{
		Identity = $solution.Name
		Confirm = $false
	}
	
	if( $solution.ContainsWebapplicationResource )	
	{
	    if( [String]::IsNullOrEmpty($web_application) )
		{
			$options.Add( "allwebapplications", $true )
		} 
		else
		{	if ( -not $web_application.EndsWith("/") ) { $web_application += "/" }
			$sp_web_app = Get-SPWebApplication | where { $_.url -eq $web_application }
			$options.Add( "WebApplication", $sp_web_app )
		}
	}
	
	if( $solution.ContainsGlobalAssembly )
	{
		$options.Add( "GacDeployment", $true )
	}
	
	if( $solution.ContainsCasPolicy )
	{
		$options.Add( "CASPolicies", $true )
	}
	
	log_deployment ("Solution - " + $solution.name + " - was added. Attempting to install with the following options - " + (HashTable_Output $options))

	Install-SPSolution @options -Force
	
	log_deployment ("Solution  - " + $solution.name + " - installation is complete.")
}

function Retract-SPSolution( [Object] $solution )
{
  	Uninstall-SPSolution -Identity $solution.Name -Confirm:$false -ErrorAction:SilentlyContinue
	
	Wait-Job $solution.Name
	
    Remove-SPSolution -Identity $solution.Name -Force -Confirm:$false 
	log_deployment ("Solution - " +  $solution.Name + " - uninstall and removal is complete")
}

if( -not ( Test-Path $deploy_directory ) )
{
	Write-Error $deploy_directory " does not exist"
	return
}

cd $deploy_directory
$packages = dir $deploy_directory -Recurse -Include "*.wsp" 

foreach ($package in $packages) 
{ 
	log_deployment ("Working on deploying $package.Name . Hash code - " + (get-hash1 $package.FullName))
    
	$solution = Get-SPSolution -identity $package.Name -ErrorAction:SilentlyContinue

    if ($solution)
    { 	
		log_deployment ("Solution - " +  $solution.Name + " - was found in SharePoint. Will attempt to upgrade the solution")
        if ($solution.Deployed -eq $true) 
        { 
			$options = @{
				Identity = $solution.FullName
				Confirm = $false
			}
			
			if( $solution.ContainsGlobalAssembly )
			{
				$options.Add( "GacDeployment", $true )
			}
			
			if( $solution.ContainsCasPolicy )
			{
				$options.Add( "CASPolicies", $true )
			}
			
            try
            {
				if( $noupgrade )
				{
					log_deployment ("No upgrade was passed. Solution - " + $solution.Name + " - will be uninstall and reprovisioned")
					Retract-SPSolution $solution
					Deploy-SPSolution $package
				} 
				else 
				{
					log_deployment ("Solution - " + $solution.Name + " - will be upgraded with the following options - " + (HashTable_Output $options))
					Update-SPSolution @options
					log_deployment ("Solution - " + $solution.Name + "- upgrade is complete. Success")
				}
            }
			catch
            {	
				log_deployment ("Solution - " + $solution.Name + " - upgrade failed. Going to attempt an uninstall")
				Retract-SPSolution $solution
				Deploy-SPSolution $package
              	
            }
        } 
		else 
		{
			Retract-SPSolution $solution
			Deploy-SPSolution $package
		}
    } 
	else
	{
		Deploy-SPSolution $package
    } 
}
Stop-SPAssignment -Global 
