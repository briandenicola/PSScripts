[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$startDate,

    [Parameter(Mandatory=$false)]
    [string]$endDate = [string]::Empty
)

function Get-OuraHeartRateData {
    [CmdletBinding()]
    param (
        [string]$startDate,
        [string]$endDate,
        [string]$continuationToken = $null
    )

    $utcOffset = "-06:00"
    $apiUrl = "https://api.ouraring.com/v2/usercollection/heartrate"

    $headers = @{
        "Authorization" = "Bearer $ENV:OURA_AUTH_TOKEN";
        "Accept" = "application/json"
    }

    $start_datetime = $(Get-Date -Date $startDate).ToString("yyyy-MM-ddT00:00:00${utcOffset}")
    Write-Verbose -Message "Setting Start Time to : $start_datetime"

    if( [string]::Empty -eq $endDate) {
        $endDate = (Get-Date).ToString("yyyy-MM-dd")
    }
    $end_datetime = $(Get-Date -Date $endDate).ToString("yyyy-MM-ddT23:59:59${utcOffset}")
    Write-Verbose -Message "Setting End Time to : $end_datetime"

    $nvCollection = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    $nvCollection["start_datetime"] = $start_datetime
    $nvCollection["end_datetime"] = $end_datetime   
    
    if ([string]::Empty -ne $continuationToken || $null -ne $continuationToken) {
        Write-Verbose -Message "Using continuation token: $continuationToken"
        $nvCollection["next_token"] = $continuationToken
    }
  
    $uriRequest = [System.UriBuilder]$apiUrl
    $uriRequest.Query = $nvCollection.ToString()

    Write-Verbose -Message ("Calling Oura Heart Rate API: {0}" -f $uriRequest.Uri.OriginalString)
    Write-Verbose -Message ("Calling Oura Heart Rate API with Headers: {0}" -f $headers.Authorization)
    $response = Invoke-RestMethod -Uri $uriRequest.Uri.OriginalString -Headers $headers -Method Get -ContentType "application/json"

    Write-Verbose -Message ("Received the following next token: {0}" -f $response)
    return $response
}

$allHeartRateData = @()
$next_token = $null

do {
    Write-Verbose -Message "Calling Oura Heart Rate API"
    $response = Get-OuraHeartRateData -startDate $startDate -endDate $endDate -continuationToken $continuationToken

    $allHeartRateData += $response.data
    $next_token = $response.next_token
} while ($null -ne $next_token)

$heartRateDataPSObject = [PSCustomObject]@{
    HeartRateData = $allHeartRateData
}

return $heartRateDataPSObject