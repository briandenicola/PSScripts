#requires -Version 2.0
[CmdletBinding()]
param ( 
    [ValidateScript( {Test-Path $_})]
    [parameter(Mandatory = $true)][string] $config_filepath,

    [ValidateScript( {Test-Path $_})]
    [parameter(Mandatory = $true)][string] $config_updates
)

. (Join-Path -Path $app_home -ChildPath "Modules\ConfigFile-Functions.ps1")

$cfg = [xml] (Get-Content -Path $config_updates)

Log -Text ("========= Starting Update WebConfigs =========")

$last_config_file_backup = Join-Path -Path $config_filepath -ChildPath (Get-MostRecentFile -src $config_filepath) -Resolve
$new_backup_file = Get-NewFileName -src $last_config_file_backup

Log -Text ("Creating a copy of {0} to {1}" -f $last_config_file_backup, $new_backup_file)
Copy-Item -Path $last_config_file_backup -Destination $new_backup_file

foreach ( $update in $cfg.ConfigUpdates.Operation ) {

    switch ($update.Ops) {
        "Add" {
            $node = $update.xpath_node
            $parent = $update.xpath_parent
            $xml_update = [xml] ( $update.NewText.'#cdata-section' )

            Log -Text ("Adding new element - {0} - to {1} in {2}" -f $update.NewText.'#cdata-section', $parent, $new_backup_file)
            AddTo-ConfigFile -config_file $new_backup_file -node $node -parent $parent -xml_update $xml_update
        }
        
        "Update" {
            $old_text = $update.OldText.'#cdata-section'
            $new_text = $update.NewText.'#cdata-section'

            Log -Text ("Replacing line - {0} - with - {1} - in {2}" -f $old_text, $new_text, $new_backup_file)
            Update-ConfigFile -config_file $new_backup_file -line_to_update $old_text -new_line $new_text
        }

        "Delete" {
            $to_delete_text = $update.Text.'#cdata-section'

            Log -Text ("Deleting line - {0} - from - {1}" -f $to_delete_text, $new_backup_file)
            DeleteFrom-ConfigFile -config_file $new_backup_file -line_to_delete $to_delete_text
        }
    }
}

Log -Text ("========= End Update WebConfigs =========")
