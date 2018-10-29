[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [ValidateScript( {Test-Path $_})]
    [Parameter(Mandatory = $true)]
    [string] $deploy_directory,
    [string] $web_application,
    [switch] $noupgrade
)

Start-SPAssignment -Global

function HashTable_Output( [HashTable] $ht ) {
    $ht.Keys | Foreach { $output += $_ + ":" + $ht[$_] + "," }
    return $output.TrimEnd(",")
}

function log_deployment ( [string] $txt ) {
    log -text "[Deploy-SharePoint-Solutions.ps1] - {0}" -f $txt
}

function Wait-Job ( [string] $solution ) {
   	$job_name = "solution-deployment-{0}*" -f $solution
    $job = Get-SPTimerJob | where { $_.Name -like $job_name }  -ErrorAction:SilentlyContinue  
	
    if ($job) {
        Write-Host -NoNewLine "Waiting to deployment job - $job.Name - to finish . . ."           

        while ((Get-SPTimerJob $job.Name) -ne $null) {
            Write-Host -NoNewLine .
            Start-Sleep -Seconds 5       
        }
        Write-Host -NoNewline "...Complete`n"
    }
}

function Deploy-SPSolution( [Object] $package ) {
    log_deployment ("Solution - {0} - was not found in SharePoint. Will attempt to add and deploy the solution" -f $package.Name)
    $solution = Add-SPSolution -LiteralPath $package.FullName
	
    $options = @{
        Identity = $solution.Name
        Confirm  = $false
    }
	
    if ( $solution.ContainsWebapplicationResource ) {
        if ( [String]::IsNullOrEmpty($web_application) )	{
            $options.Add( "allwebapplications", $true )
        } 
        else {	
            if ( -not $web_application.EndsWith("/") ) { $web_application += "/" }
            $sp_web_app = Get-SPWebApplication | Where { $_.url -eq $web_application }
            $options.Add( "WebApplication", $sp_web_app )
        }
    }
	
    if ( $solution.ContainsGlobalAssembly ) { $options.Add( "GacDeployment", $true )	}
    if ( $solution.ContainsCasPolicy ) {	$options.Add( "CASPolicies", $true ) }
	
    log_deployment ("Solution - {0} - was added. Attempting to install with the following options - {1} " -f $solution.name, (HashTable_Output $options))

    Install-SPSolution @options -Force
    Wait-Job $solution.Name
	
    $result = Get-SPSolution  $solution.Name| Select LastOperationResult, LastOperationEndTime, LastOperationDetails
    if ( $result.LastOperationResult -eq "DeploymentSucceeded" ) {
        log_deployment ("Solution - {0} - installation completed successfully." -f $solution.name)
    }
    else { 
        Write-Error ("Solution - {0} - failed with - {1}" -f $solution.Name, $result.LastOperationDetails )
        log_deployment ("Solution - {0} - installation did notcompleted successfully." -f $solution.Name)
        log_deployment ("Result @ {0} completed with  - {1}. Details - {2}" -f $solution.Name, $result.LastOperationResult, $result.LastOperationDetails )
    }
}

function Retract-SPSolution( [Object] $solution ) {
    Uninstall-SPSolution -Identity $solution.Name -Confirm:$false -ErrorAction:SilentlyContinue
    Wait-Job $solution.Name
    Remove-SPSolution -Identity $solution.Name -Force -Confirm:$false 
    log_deployment ("Solution - {0} - uninstall and removal is complete" -f $solution.Name)
}

$packages = Get-ChildItem -Path $deploy_directory -Recurse -Include "*.wsp" 
foreach ( $package in $packages ) { 
    log_deployment ("Working on deploying {0} . Hash code - {1}" -f $package.Name, (Get-Hash1 $package.FullName))
    
    $solution = Get-SPSolution -identity $package.Name -ErrorAction:SilentlyContinue

    if ($solution) { 	
        log_deployment ("Solution - {0} - was found in SharePoint. Will attempt to upgrade the solution" -f $solution.Name)
        
        if ( $solution.Deployed -eq $true ) { 
            $options = @{
                Identity = $solution.FullName
                Confirm  = $false
            }
			
            if ( $solution.ContainsGlobalAssembly ) { $options.Add( "GacDeployment", $true )	}
            if ( $solution.ContainsCasPolicy ) {	$options.Add( "CASPolicies", $true ) }
			
            try {
                if ($noupgrade) {
                    log_deployment ("No upgrade was passed. Solution - {0} - will be uninstall and reprovisioned" -f $solution.Name)
                    Retract-SPSolution $solution
                    Deploy-SPSolution $package
                } 
                else {
                    log_deployment ("Solution - {0} - will be upgraded with the following options - {1}" -f $solution.Name, (HashTable_Output $options))
                    Update-SPSolution @options
                    log_deployment ("Solution - {0} - upgrade is complete. Success" -f $solution.Name)
                }
            }
            catch {	
                log_deployment ("Solution - {0} - upgrade failed. Going to attempt an uninstall" -f $solution.Name)
                Retract-SPSolution $solution
                Deploy-SPSolution $package
            }
        } 
        else {
            Retract-SPSolution $solution
            Deploy-SPSolution $package
        }
    } 
    else {
        Deploy-SPSolution $package
    } 
}
Stop-SPAssignment -Global 