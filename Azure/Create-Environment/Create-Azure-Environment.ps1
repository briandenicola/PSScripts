#Requirements
#Params

#Import Modules

#Start Transcript...
#Setup Affinity Group
#Setup Storage
#Setup Virtual Network
#Upload Script Extensions
#Create Azure VM for AD
#Get WinRM Scripts
#Update AD via Remoting Script
#Update Cert Authority via Remoting Script
#Create Azure VM for DSC with Script Extension
#Add-DnsServerResourceRecord -ZoneName "Contoso.com" -A -Name "Host34" -AllowUpdateAny -IPv4Address "10.17.1.34" -TimeToLive 01:00:00 -AgeRecord
#Upload and Compile DSC Resources via Remoting (?)
#Loop and Create Azure VMs
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