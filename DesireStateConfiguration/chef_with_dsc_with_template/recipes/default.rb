#
# Cookbook Name:: chef_with_dsc
# Recipe:: default
#
# Copyright 2015, Brian Denicola
#
# All rights reserved - Do Not Redistribute
#
#knife upload .\cookbooks\

directory "chef-dsc-cmd-script" do
	action :create 
end

template "dsc_cmd_script_file.ps1" do
	path "chef-dsc-cmd-script/dsc_cmd_script_file.ps1"
	source "dsc_cmd_script_file.ps1.erb"
end

dsc_script 'SystemSetup' do
	command "chef-dsc-cmd-script/dsc_cmd_script_file.ps1"
	flags ( { :Path => node['chef_with_dsc']['base_path'] } )
end