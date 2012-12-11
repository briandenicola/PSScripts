#Requires -version 2.0

function Get-ThreadOptions
{	
	[Runspace]::DefaultRunspace.ThreadOptions
}

function Set-ThreadOptions
{
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    param
    (
        [Parameter(Mandatory=$true)][ValidateNotNull()]
        [System.Management.Automation.Runspaces.PSThreadOptions]$ThreadOption
    )
    if ($PSCmdlet.ShouldProcess([Runspace]::DefaultRunspace.ThreadOptions, "Changing ThreadOptions to $ThreadOption"))
    {
        [Runspace]::DefaultRunspace.ThreadOptions = $ThreadOption
    }
}