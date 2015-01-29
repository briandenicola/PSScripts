#Requirements
#Params

#Import Modules

#Start Transcript...

#Setup Affinity Group
#Setup Storage
#Setup Virtual Network

#Upload Script Extensions

#Create Azure VM for AD
#Get WinRM Cert and Establish Connection 
#Create AD via Remoting Script 
#Create Cert Authority via Remoting Script 

#Create Azure VM for DSC
#Create DNS Record for DSC Example - Add-DnsServerResourceRecord -ZoneName "Contoso.com" -A -Name "Host34" -AllowUpdateAny -IPv4Address "10.17.1.34" -TimeToLive 01:00:00 -AgeRecord
#Install and Configure DSC via Extensions
    #Copy DSC\Modules\xPSDesiredStateConfiguration to $env:ProgramFiles\WindowsPowerShell\Modules
    #Publish-AzureVMDscConfiguration -ConfigurationPath .\Config_xDscWebService.ps1
    #$vm | Set-AzureVMDSCExtension -ConfigurationArchive "IISInstall.ps1.zip" -ConfigurationName "IISInstall"  | Update-AzureVM

#Loop and Create Azure VMs
    #Save Guid in Map file for storage
    #DSC Extension 

#Stop Transcript...

#$uri = "{0}/{1}/{2}" -f "https://bjdtest003.blob.core.windows.net", $xml.Azure.ScriptExtension.ContainerName, $xml.Azure.Domain.VM.ScriptExtension
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
#    ScriptExtensionUri = $uri
#    ScriptExtensionUriArguments = "this is a test for the sample script"
#}