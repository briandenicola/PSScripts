#Requirements
#Params

#Import Modules

#Start Transcript...

#Setup Affinity Group
#Setup Storage
#Setup Virtual Network
#Upload Script Extensions

#Create Azure VM for AD

    #$drives = @(@{DriveSize=$xml.Azure.Domain.VM.DriveSize;DriveLabel=$xml.Azure.Domain.VM.DriveLabel})

    #$opts = @{
    #    Name = $xml.Azure.Domain.VM.ComputerName
    #    Subscription = $xml.Azure.SubScription
    #    StorageAccount = $xml.Azure.BlobStorage
    #    CloudService = $xml.Azure.CloudService
    #    Size = $xml.Azure.Domain.VM.VMSize
    #    OperatingSystem = $xml.Azure.Domain.VM.OS 
    #    AdminPassword = $xml.Azure.Domain.DomainAdminPassword 
    #    AffinityGroup = $xml.Azure.AffinityGroup 
    #    IpAddress = $xml.Azure.Domain.VM.IpAddress 
    #    DataDrives = $drives
    #    VNetName = $xml.Azure.VNet.Name
    #}

#Get WinRM Cert and Establish Connection 
    #Install-WinRmCertificate -service $xml.Azure.CloudService -vm_name $xml.Azure.Domain.VM.ComputerName
    #$uri = Get-AzureWinRMUri  -ServiceName $xml.Azure.CloudService -Name $xml.Azure.Domain.VM.ComputerName
    #$secpasswd = ConvertTo-SecureString -String $xml.Azure.Domain.DomainAdminPassword -AsPlainText -Force
    #$mycreds = New-Object System.Management.Automation.PSCredential ( $xml.Azure.Domain.DomainAdminUser, $secpasswd )

#Create AD via Remoting Script 
    #Invoke-Command -ConfigurationName $uri -Credential $mycreds -ScriptBlock { }
#Create Cert Authority via Remoting Script    
    #Invoke-Command -ConfigurationName $uri -Credential $mycreds -ScriptBlock { }

#Create Azure VM for DSC
    #$drives = @(@{DriveSize=$xml.Azure.DesireStateConfiguration.VM.DriveSize;DriveLabel=$xml.Azure.DesireStateConfiguration.VM.DriveLabel})

    #$opts = @{
    #    Name = $xml.Azure.DesireStateConfiguration.VM.ComputerName
    #    Subscription = $xml.Azure.SubScription
    #    StorageAccount = $xml.Azure.BlobStorage
    #    CloudService = $xml.Azure.CloudService
    #    Size = $xml.Azure.DesireStateConfiguration.VM.VMSize
    #    OperatingSystem = $xml.Azure.DesireStateConfiguration.VM.OS 
    #    AdminUser = $xml.Azure.DesireStateConfiguration.LocalAdminUser 
	#	 AdminPassword = $xml.Azure.DesireStateConfiguration.LocalAdminPassword
    #    AffinityGroup = $xml.Azure.AffinityGroup 
    #    DataDrives = $drives
	#	 DomainUser = $xml.Azure.Domain.DomainAdminUser
	#	 DomainPassword = $xml.Azure.Domain.DomainAdminPassword
	#	 Domain = $xml.Azure.Domain.DomainName
    #    VNetName = $xml.Azure.VNet.Name
    #}
    #New-AzureVirtualMachine @opts
#Create DNS Record for DSC Example - 
    #Invoke-Command -ConfigurationName $uri -Credential $mycreds -Authentication Credssp -ScriptBlock {
    #    Add-DnsServerResourceRecordCName -Name "dsc" -HostNameAlias "bjd-ad.sharepoint.test" -ZoneName "sharepoint.test"
    #}

#Install and Configure DSC via Extensions
    #Copy DSC\Modules\xPSDesiredStateConfiguration to $env:ProgramFiles\WindowsPowerShell\Modules
    #Publish-AzureVMDscConfiguration -ConfigurationPath .\Config_xDscWebService.ps1
    #$vm | Set-AzureVMDscExtension -ConfigurationArchive ("{0}.ps1.zip" -f $xml.Azure.DesireStateConfiguration.DSC.ConfigurationName ) -ConfigurationName $xml.Azure.DesireStateConfiguration.DSC.ConfigurationName | Update-AzureVM

#Loop and Create Azure VMs
    #Save Guid in Map file for storage
    #DSC Extension 

#Stop Transcript...

