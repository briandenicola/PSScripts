[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string[]] $servernames,
    [ValidateSet("internal", "external")]
    [string] $network = "internal",
    [string] $os,
    [switch] $load,
    [switch] $diff,
    [string] $parent,
    [int] $size = 30,
    [int] $ram = 2,
    [string] $path = "D:\VMS"
)

$win2008_iso = "C:\ISOs\Win7-2008R2-SP1.ISO"
$win2012_iso = "C:\ISOs\Win_Svr_Std_and_DataCtr_2012_64Bit.ISO"

foreach ($servername in $servernames) {

    $c_drive = Join-Path $path ( $servername + "-C-Drive.vhd" )
    $d_drive = Join-Path $path ( $servername + "-D-Drive.vhd" )

    Write-Host "[ $(Get-Date).ToString() ] - Creating the Server: $servername . . ."
    if ($diff -and [string]::IsNullOrEmpty($parent)) {
        Write-Host "If using Differencing Disk you must supply a parent Disk using -parent <path to disk>"
        return -1
    }

    try {
        New-VM -Name $servername -SwitchName $network -MemoryStartupBytes ($ram * 1GB) -Path (Join-Path $path "Virtual Machines")

        if ($diff) {
            Write-Verbose "Joining C: partition to $parent drive :"
            New-VHD -Differencing -ParentPath $parent -Path $c_drive
        }
        else {
            Write-Verbose "Creating C: partition"
            New-VHD -Dynamic -Path $c_drive  -SizeBytes ($size * 1GB)    
        }
        Write-Verbose "Adding $c_drive to $servername"
        Add-VMHardDiskDrive -VMName $servername -Path $c_drive
        
        Write-Verbose "Creating D: partition"
        New-VHD -Dynamic -Path $d_drive -SizeBytes ($size * 1GB)

        Write-Verbose "Adding $d_drive to $servername"
        Add-VMHardDiskDrive -VMName $servername -Path $d_drive
        
        if ($load -and $oper -eq "2012") {
            Write-Verbose "Attaching ISO for 2012 to VM"
            Set-VMDvdDrive -ControllerNumber 1 -VMName $servername -Path $win2012_iso
        }
        if ($load -and $oper -eq "2008") {
            Write-Host "Attaching ISO for 2008 R2 to VM"
            Set-VMDvdDrive -ControllerNumber 1 -VMName $servername -Path $win2008_iso
        }

        $start = Read-Host "Would you like to start the newly created machine? (Y|N) [Default = Y]"
        if( $start -imatch "y" -or [string]::IsNullOrEmpty($start) ) {
            Start-VM -Name $servername
        }

        Write-Host "[ $(Get-Date).ToString() ] - Complete . . ."
    }
    catch {
        throw ("Error creating the VM - " + $_)
    }
}
