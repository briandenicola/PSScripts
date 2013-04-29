param( 
    [string[]] $computers,
    [int] $timeout = 10,
    [string] $url
)

foreach( $computer in $computers ) {
    $request = [System.Net.WebRequest]::Create($url)
    $request.Method = "HEAD"
    $request.Timeout = $timeout * 1000
    $request.AllowAutoRedirect = $false
    $request.ContentType = "application/x-www-form-urlencoded"
    $request.UserAgent = "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0; .NET CLR 1.1.4322)"
    $request.Credentials =  [System.Net.CredentialCache]::DefaultCredentials
	$request.Proxy = new-object -typename System.Net.WebProxy -argumentlist $Server
   
    #Wrap this with a measure-command to determine type
    "[{0}][REQUEST] Getting $url from $computer ..." -f $(Get-Date)
	try {
		$timing_request = Measure-Command { $response = $request.GetResponse() }
		$stream = $response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($stream)

		"[{0}][REPLY] Server = {1} " -f $(Get-Date), $response.Server
		"[{0}][REPLY] Status Code = {1} {2} . . ." -f $(Get-Date), $response.StatusCode, $response.StatusDescription
		"[{0}][REPLY] Content Type = {1} . . ." -f $(Get-Date), $response.ContentType
		"[{0}][REPLY] Content Length = {1} . . ." -f $(Get-Date), $response.ContentLength
        "[{0}][REPLY] Guid = {1} . . ." -f $(Get-Date),  $response.Headers['SPRequestGuid']
        "[{0}][REPLY] X-SharePointHealthScore = {1} . . ." -f $(Get-Date), $response.Headers['X-SharePointHealthScore']
		"[{0}][REPLY] Total Time = {1} . . ." -f $(Get-Date), $timing_request.TotalSeconds
	}
	catch [System.Net.WebException]	{
		Write-Error ("The request failed with the following WebException - " + $_.Exception.ToString() )
	}
}
