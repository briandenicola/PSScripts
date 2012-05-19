function Set-RegistryKey
{
    [CmdletBinding(DefaultParameterSetName="Key+Value")]
    param
    (
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
        [String]$Node,
        
        [Parameter(Mandatory=$false)]
        [String]$Key,
        
        #The value parameter must be untyped.
        [Parameter(Mandatory=$true, ParameterSetName="Key+Value")]
        [String]$Value,
        
        [Parameter(Mandatory=$true, ParameterSetName="OnlyKey")]
        [switch]$OnlyKey,
        
        [Parameter(Mandatory=$false)]
        [switch]$PassThru,
        
        [Parameter(Mandatory=$false)][ValidateSet("String", "ExpandString", "MultiString", "Binary", "DWord", "QWord")]
        [String]$ValueType = "String"
    )
	
	if ($Node.StartsWith("HKEY_LOCAL_MACHINE"))
	{
		$Node = $Node.Replace("HKEY_LOCAL_MACHINE","HKLM:")
	}

    if ($PsCmdlet.ParameterSetName -eq "Key+Value")
    {
		Write-Verbose ("Setting Node; {0}, Key: {1}, Value: {2}, Type: {3}" -f $Node, $Key, $Value, $ValueType)
        if (-not (Test-Path $Node))
        {
            Write-Verbose ("Registry Node does not currently exist, so we must create it: {0}" -f $Node)
            $NewNode = New-Item -Path $Node -Force -Confirm:$false
            Write-Verbose ("Created Path {0}" -f $NewNode)
        }
        
        $Result = New-ItemProperty -Path $Node -Name $Key -Value $Value -Type $ValueType -Force
    }
    else
    {
		Write-Verbose ("Creating Node: {0}" -f $Node)
        $Result = New-Item -Path $Node -Force
    }
	
	if ($PassThru)
	{
		$Result
	}
}

function Get-RegistryKey
{
	[CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)][ValidateNotNull()]
        $Node,
        
        [Parameter(Mandatory=$true)][ValidateNotNull()]
        $Key
    )
	
	if ($Node.StartsWith("HKEY_LOCAL_MACHINE"))
	{
		$Node = $Node.Replace("HKEY_LOCAL_MACHINE","HKLM:")
	}
    
	Write-Verbose ("Getting Node:{0}" -f $Node)
	Write-Verbose ("Getting Key :{0}" -f $Key)
	
    return (Get-ItemProperty $Node).$Key
}

function Remove-RegistryKey
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true)][ValidateNotNull()]
		$Node,
		
		[Parameter(Mandatory=$false)]
		[switch]$NoWarning, 
		
		[Parameter(Mandatory=$false)]
		[switch]$NoConfirm
	)
	
	Write-Warning ("Deleting key and all sub-keys: {0}" -f $Node)
	
	Remove-Item -Path $Node.PSPath -Force -Confirm:$NoConfirm
}
