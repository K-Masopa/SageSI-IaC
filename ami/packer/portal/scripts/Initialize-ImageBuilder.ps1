#Install Prerequites 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Install-PackageProvider -Name NuGet -Force
Install-Module -Name xPSDesiredStateConfiguration -Force
Install-Module -Name xWebAdministration -Force

Install-Module -Name ComputerManagementDsc -force
Install-Module -Name PSWindowsUpdate -force
Install-Module -Name LanguageDsc -Force

WinRM quickconfig -Force
WinRM set "winrm/config/client" '@{TrustedHosts="localhost"}'

#Apply the DSC Config
& "C:\DeployTemp\Set-ImageConfigDSC.ps1" 

