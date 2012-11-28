$hostfile = "c:\Windows\System32\drivers\etc\hosts"

function RemoveFrom-HostFile([string[]] $url)
{

	$url | % {
		((gc $hostfile) -notmatch "^$") -notmatch $_ | out-file -Encoding Ascii $hostfile
	} 


	Write-Host "Complete . . "
	
}

function AddTo-HostFile([string[]] $url, [string] $ip)
{
	$url | % { 
		"`n{0}`t{1}" -f $ip, $_ | Out-File -Encoding Ascii -Append $hostfile
	}
	
	Write-Host "Complete . . "
}

function Show-HostFile()
{
	gc $hostfile	
}

do
{
	$more = $false

	Write-Host "This script will update a system to  . . ."
	Write-Host "1) Add custom URL"
	Write-Host "2) Remove custom URL"
	Write-Host "3) Show Host File"
	$ans = Read-Host "Select 1-3"
	
	switch($ans)
	{
		1 {	
			$ip = Read-Host "Please enter ip in the form of x.y.w.z >"
			if( $ip -notmatch "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}" ) { Write-Host "Invalid IP Address"; break }
			$url = Read-Host "Please enter hostname >"
			AddTo-HostFile -url $url -ip $ip
			break
		}
		2 {	
			$url = Read-Host "Please enter IP or host that you want to remove >"
			RemoveFrom-HostFile -url $url 
			break
		}
		3 { 
            Show-HostFile
            break 
        }
		default { 
			Write-Host "Invalid selection"
			break;
		}
	}
	
	$ans = Read-Host "Do you wish to perform another action (y/n) ?"
	if( $ans.ToLower() -eq "y" -or $ans.ToLower() -eq "yes" ) { $more = $true }
	
} while ( $more -eq $true )
