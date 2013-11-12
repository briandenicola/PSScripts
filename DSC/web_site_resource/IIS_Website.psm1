$LocalizedData = ConvertFrom-StringData @'    
    AnErrorOccurred=An error occurred while creating IIS Site: {1}.
    InnerException=Nested error trying to create IIS Site: {1}.
'@

function Get-TargetResource 
{
    [OutputType([Hashtable])]
    param 
    (       
        [ValidateSet("Present", "Absent")]
        [string]$Ensure = "Present",
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PhysicalPath,
        [ValidateSet("Started", "Stopped")]
        [string]$State = "Started"
    )

    try {
        $site = Get-WebSite | Where { $_.Name -eq $Name }

        Write-Verbose "Getting Data"
        if( $site -eq $null ) {
            $Configuration = @{
                Name = $Name
                Ensure = 'Absent'
            }
        }
        else {
            Write-Verbose "Found site. Returning Data"
            $Configuration = @{
                Name = $site.Name
                PhysicalPath = $site.PhysicalPath
                State = $site.State 
                Ensure = 'Present'
            }
        }

        return $Configuration
    }
    catch {
        $exception = $_    
        while ($exception.InnerException -ne $null)  {
            $exception = $exception.InnerException
            Write-Error ($LocalizedData.InnerException -f $name, $exception.message)
        }
    }        
} 

function Set-TargetResource 
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param 
    (       
        [ValidateSet("Present", "Absent")]
        [string]$Ensure = "Present",
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PhysicalPath,
        [ValidateSet("Started", "Stopped")]
        [string]$State = "Started"
    )
 
    try {
        Write-Verbose "Getting Site"
        $site = Get-WebSite | Where { $_.Name -eq $Name }
        
        if ($Ensure -eq "Present" -and $site -ne $null) {
            Write-Verbose "Setting Existing Site values"
            Set-ItemProperty ("IIS:\Sites\" + $Name ) -name physicalPath -value $PhysicalPath
            if( $State -eq "Started" ) { 
                Start-WebSite -name $Name
            }
            else {
                Stop-WebSite -name $Name
            }
        } 
        elseif( $Ensure -eq "Present" -and $site -eq $null ) {
            Write-Verbose "Creating Site"
            Create-IISWebSite -site $Name -path $PhysicalPath -port 80
            if( $State -eq "Started" ) { 
                Start-WebSite -name $Name
            }
            else {
                Stop-WebSite -name $Name
            }
        }
        elseif( $Ensure -eq "Absent" -and $site -ne $null ) {
            Write-Verbose "Removing Site"
            Remove-Website -Name $Name
        }
    }
    catch {
        $exception = $_    
        while ($exception.InnerException -ne $null)  {
            $exception = $exception.InnerException
            Write-Error ($LocalizedData.InnerException -f $name, $exception.message)
        }
    } 
}

function Test-TargetResource 
{
    [OutputType([boolean])]
    param (
        [ValidateSet("Present", "Absent")]
        [string]$Ensure = "Present",
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PhysicalPath,
        [ValidateSet("Started", "Stopped")]
        [string]$State = "Started"
    )  


    try {
        $site = Get-WebSite | Where { $_.Name -eq $Name }
        
        if ($Ensure -eq "Present" -and $site -ne $null) {
            Write-Verbose "Ensure -eq 'Present'"
            if( $site.State -eq $State -and $site.PhysicalPath -eq $PhysicalPath ) {
                Write-Verbose "All Values are equal. Good"
                return $true
            }
            else {
                Write-Verbose "All Values aren't equal. Boo"
                Write-Verbose ("State = " + $site.State)
                Write-Verbose ("PhysicalPath = " + $site.PhysicalPath)
                return $false 
            }
        } 
        elseif( $Ensure -eq "Present" -and $site -eq $null ) {
            Write-Verbose "Missing site"
            return $false 
        }
        elseif( $Ensure -eq "Absent" -and $site -ne $null ) {
            Write-Verbose "Found a site but shouldn't"
            return $false 
        }
        else {
            Write-Verbose "No site found and Ensure -eq 'Absent'"
            return $true
        }
    }
    catch {
        $exception = $_    
        while ($exception.InnerException -ne $null)  {
            $exception = $exception.InnerException
            Write-Error ($LocalizedData.InnerException -f $name, $exception.message)
        }
    } 
}
