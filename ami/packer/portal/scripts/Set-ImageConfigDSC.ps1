[DSCLocalConfigurationManager()]
configuration LCMConfig {
    Node localhost
    {
        Settings {
            ActionAfterReboot  = 'ContinueConfiguration'
            ConfigurationMode  = 'ApplyOnly'
            RebootNodeIfNeeded = $false
            RefreshMode        = 'Push'
        }
    }
}

configuration ImageConfiguration {
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xWebAdministration -ModuleVersion 3.2.0

    Registry "DisableSMBv1" {
        Key       = "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\LanManServer\Parameters"
        ValueName = "SMB1"
        ValueType = "Dword"
        ValueData = "0"
        Ensure    = "Present"
        Force     = $true
    }

    Registry "EnableStrongEncryptionRDP" {
        Key       = "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Terminal Services"
        ValueName = "MinEncryptionLevel"
        ValueType = "Dword"
        ValueData = "3"
        Ensure    = "Present"
        Force     = $true
    }

    Registry "EnableAlwaysPromptPasswordRDP" {
        Key       = "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Terminal Services"
        ValueName = "fPromptForPassword"
        ValueType = "Dword"
        ValueData = "1"
        Ensure    = "Present"
        Force     = $true
    }

    Registry "EnablePowershellScriptLogging" {
        Key       = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'"
        ValueName = "EnableScriptBlockLogging"
        ValueType = "Dword"
        ValueData = "0"
        Ensure    = "Present"
        Force     = $true
    }

    Registry "EnablePowershellTranscription" {
        Key       = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription'"
        ValueName = "EnableTranscripting"
        ValueType = "Dword"
        ValueData = "0"
        Ensure    = "Present"
        Force     = $true
    }

    File ScriptDirTest {
        Type            = "Directory"
        Ensure          = "Present"
        DestinationPath = "C:\TestDSC"
    }

    WindowsFeatureSet IIS {
        Name                 = @("web-server", "Web-Mgmt-Console", "Web-Net-Ext45", "Web-Asp-Net45", "Web-ISAPI-Ext", "Web-ISAPI-Filter", "NET-Framework-45-ASPNET")
        Ensure               = "Present"
        IncludeAllSubFeature = $True
    }

    xWebAppPool RemoveDotNet2Pool { Name = ".NET v2.0"; Ensure = "Absent"; DependsOn = '[WindowsFeatureSet]IIS' }
    xWebAppPool RemoveDotNet2ClassicPool { Name = ".NET v2.0 Classic"; Ensure = "Absent"; DependsOn = '[WindowsFeatureSet]IIS' }
    xWebAppPool RemoveDotNet45Pool { Name = ".NET v4.5"; Ensure = "Absent"; DependsOn = '[WindowsFeatureSet]IIS' }
    xWebAppPool RemoveDotNet45ClassicPool { Name = ".NET v4.5 Classic"; Ensure = "Absent"; DependsOn = '[WindowsFeatureSet]IIS' }
    xWebAppPool RemoveClassicDotNetPool { Name = "Classic .NET AppPool"; Ensure = "Absent"; DependsOn = '[WindowsFeatureSet]IIS' }
    xWebAppPool RemoveDefaultAppPool { Name = "DefaultAppPool"; Ensure = "Absent"; DependsOn = '[WindowsFeatureSet]IIS' }
    xWebSite    RemoveDefaultWebSite { Name = "Default Web Site"; Ensure = "Absent"; DependsOn = '[WindowsFeatureSet]IIS' }
    
    Service W3SVC {
        Name        = "W3SVC"
        StartupType = "Automatic"
        State       = "Running"
        DependsOn   = '[WindowsFeatureSet]IIS'
    }
    
    Script Install_NetCore_215 {
        SetScript  = {
            $SourceURI = "https://download.visualstudio.microsoft.com/download/pr/86df96bb-384c-4d7a-82ce-2e4c2c871189/045870c1ab4004219cb312039c5a64d5/dotnet-hosting-2.1.5-win.exe"
            $FileName = $SourceURI.Split('/')[-1]
            $BinPath = Join-Path $env:SystemRoot -ChildPath "Temp\$FileName"

            if (!(Test-Path $BinPath)) {
                $ProgressPreference = 'SilentlyContinue' # Hide progress bar to speed up download
                Write-Output "Downloading .net core 2.1.5"
                Invoke-Webrequest -Uri $SourceURI -OutFile $BinPath
                $ProgressPreference = 'Continue'
            }

            write-verbose "Installing .net core 2.1.5 from $BinPath"
            write-verbose "Executing $binpath /q /install"
            Start-Sleep 2
            Start-Process -FilePath $BinPath -ArgumentList "/q /install" -Wait -NoNewWindow            
            Start-Sleep 2
        }

        TestScript = {
            $testInstall = Get-WmiObject -Class Win32_Product | Where-Object name -eq "Microsoft .NET Core Host - 2.1.5 (x64)"
            if ([string]::IsNullOrEmpty($testInstall) -eq $true) {
                Write-Verbose "TEST: .netcore 2.1.5 install failed" 
                return $false
            }
            else {
                Write-Verbose "TEST: .netcore 2.1.5 install success" 
                return $true
            }
        }

        GetScript  = {
            $testInstall = Get-WmiObject -Class Win32_Product | Where-Object name -eq "Microsoft .NET Core Host - 2.1.5 (x64)"
            if ([string]::IsNullOrEmpty($testInstall) -eq $true) {
                return $false
            }
            else {
                return $True
            }
        }
    }
}

Install-PackageProvider -Name NuGet -Force
Install-Module -Name xPSDesiredStateConfiguration -Force
Install-Module -Name xWebAdministration -Force

$FilePath = Join-Path (Get-Location -PSProvider FileSystem).Path "ImageConfiguration"
ImageConfiguration
LCMConfig -OutputPath $filepath

Set-DscLocalConfigurationManager -Path $FilePath -Verbose -force
Start-DscConfiguration -Path $FilePath -wait -Verbose -force