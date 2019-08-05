
function Connect-SPOnlineServices {

    param(
        [string] $site,
        [System.Management.Automation.PSCredential] $creds
    )

    if (!$creds) {
        $creds = Get-Credential
    }

    $online_creds = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($creds.UserName, $creds.Password)
    $ctx = New-Object Microsoft.SharePoint.Client.ClientContext($site)
    $ctx.Credentials = $online_creds

    return $ctx

}

function Convert-DictionaryToObject {
    param (
        [object] $dictionary
    )
    
    $objects = @()

    foreach ( $item in $dictionary ) {
        $object = New-Object PSObject
        foreach ( $key in $item.keys ) {
            $object | Add-Member -MemberType NoteProperty -Name $key -Value $item[$key]
        }
        $objects += $object
    }

    return $objects
}

function Update-SPListItemViaCSOM {

    param (
        [Parameter(Mandatory = $true)][string] $site,
        [Parameter(Mandatory = $true)][string] $list,
        [Parameter(Mandatory = $true)][int] $id,
        [Parameter(Mandatory = $true)][Hashtable] $values,
        [string] $TitleField,
        [System.Management.Automation.PSCredential] $creds

    )

    $ctx = Connect-SPOnlineServices -site $site -creds $creds

    $sp_list = $ctx.Web.Lists.GetByTitle($list)
    $item = $sp_list.getItemById($id)

    foreach ( $key in $values.keys ) {
        if ( $key -eq $TitleField ) {
            $item.set_item('Title', $values[$key] )
        }
        else {
            $item.set_item($key, $values[$key] )
        }
    }
    $item.Update()
    $ctx.Load($item)
    $ctx.ExecuteQuery()
}

function New-SPListItemViaCSOM {

    param (
        [Parameter(Mandatory = $true)][string] $site,
        [Parameter(Mandatory = $true)][string] $list,
        [Parameter(Mandatory = $true)][Hashtable] $values,
        [string] $TitleField,
        [System.Management.Automation.PSCredential] $creds
    )

    $ctx = Connect-SPOnlineServices -site $site -creds $creds
    $sp_list = $ctx.Web.Lists.GetByTitle($list)
    $item_info = New-Object Microsoft.SharePoint.Client.ListItemCreationInformation

    $new_item = $sp_list.addItem($item_info)
    foreach ( $key in $values.keys ) {
        if ( $key -eq $TitleField ) {
            $new_item.set_item('Title', $values[$key] )
        }
        else {
            $new_item.set_item($key, $values[$key] )
        }
    }

    $new_item.update()
    $ctx.Load($new_item)
    $ctx.ExecuteQuery()
}

function Get-SPListViaCSOM {
    
    param (
        [Parameter(Mandatory = $true)][string] $site,
        [Parameter(Mandatory = $true)][string] $list,
        [string] $query,
        [System.Management.Automation.PSCredential] $creds
    )

    $camlQuery = New-Object Microsoft.SharePoint.Client.CamlQuery

    $ctx = Connect-SPOnlineServices -site $site -creds $creds
    $sp_list = $ctx.Web.Lists.GetByTitle($list)

    if ( [String]::IsNullOrEmpty($query) ) {
        $camlQuery.ViewXml = '<View/>'
    } 
    else {
        $camlQuery.ViewXML = $query
    }

    $items = $sp_list.GetItems($camlQuery)
    $ctx.Load($items)
    $ctx.ExecuteQuery()

    return ( Convert-DictionaryToObject $items.FieldValues )
}


function Push-ToSharePointOnline {
    param (
        [Parameter(Mandatory = $true)][string] $site,
        
        [Parameter(Mandatory = $true)][string] $library,

        [ValidateScript( {Test-Path $_ -PathType leaf})] 
        [Parameter(Mandatory = $true)][string] $file,

        [System.Management.Automation.PSCredential] $credentials
    )

    $ctx = Connect-SPOnlineServices -site $site -creds $credentials
    $sp_list = $ctx.Web.Lists.GetByTitle($library)
    $ctx.Load($sp_list.RootFolder)
    $ctx.ExecuteQuery()

    $item = Get-Item $file

    $file_byte_array = Get-Content -Encoding Byte $file    
    $content = New-Object Microsoft.SharePoint.Client.FileCreationInformation
    $content.Content = $file_byte_array
    $content.Url = $sp_list.RootFolder.ServerRelativeUrl + "/" + $item.Name 
    $content.Overwrite = $true

    $uploaded_file = $sp_list.RootFolder.Files.Add($content)

    $ctx.Load($uploaded_file)
    $ctx.ExecuteQuery()
}