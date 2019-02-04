param(
    [Parameter(Mandatory = $true)]
    [string] $url,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Dev", "QA", "UAT", "Prod")]
    [string] $environment

)

$arr_environment_map = @(
    @{Name = "Dev"; Servers = @("server-1"); RuleName = "ArrDev_Inbound_rules"},
    @{Name = "QA"; Servers = @("server-1"); RuleName = "ArrQA_Inbound_rules"},
    @{Name = "UAT"; Servers = @("server-1"); RuleName = "ArrUAT_Inbound_rules"},
    @{Name = "Prod"; Servers = @("server-2", "server-3"); RuleName = "ArrProd_Inbound_rules"}
)

$sb = {
    param(
        [Parameter(Mandatory = $true)]
        [string] $pattern,
        [Parameter(Mandatory = $true)]
        [string] $rule
    )

    Import-Module WebAdministration
    
    Set-Variable -Name filter -Value ("/system.webServer/rewrite/globalRules/rule[@name='{0}']/conditions" -f $rule)
    Set-Variable -Name path   -Value "MACHINE/WEBROOT/APPHOST"  -Option constant
    Set-Variable -Name input  -Value "{HTTP_HOST}"              -Option Constant

    $condition = @{
        pspath = $path
        filter = $filter
        value  = @{
            input   = $input
            pattern = $pattern
        }
    }

    Add-WebConfiguration @condition
}

$arr = $arr_environment_map | Where { $_.Name -imatch $environment }
Invoke-Command -ComputerName $arr.Servers -ScriptBlock $sb -ArgumentList $url, $arr.RuleName