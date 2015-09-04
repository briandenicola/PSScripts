#
# Cookbook Name:: chef_with_dsc
# Recipe:: default
#
# Copyright 2015, Brian Denicola
#
# All rights reserved - Do Not Redistribute
#
#knife upload .\cookbooks\

dsc_cmd_script = <<-EOH
Configuration SystemSetup
{
	param(
		[string] $Path
	)
	
	Environment SCRIPTS_HOME {
		Ensure = "Present"
		Name   = "SCRIPTS_HOME"
		Value  = $Path
	}
}
EOH

cfg_dir = ::Dir.mktmpdir("chef-dsc-cmd-script")
dsc_cmd_script_file = "#{cfg_dir}/dsc_cmd_script_file.ps1"
File.write(dsc_cmd_script_file, dsc_cmd_script)

dsc_script 'SystemSetup' do
	command dsc_cmd_script_file
	flags ( { :Path => 'D:\Scripts' })
end