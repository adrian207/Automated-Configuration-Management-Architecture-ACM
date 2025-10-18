# Web Server Configuration - PowerShell DSC
# Author: Adrian Johnson <adrian207@gmail.com>
# Description: IIS web server configuration with security hardening

Configuration WebServer
{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Dev", "Test", "Prod")]
        [string]$Environment,
        
        [Parameter(Mandatory=$false)]
        [string]$WebSiteName = "DefaultWebSite",
        
        [Parameter(Mandatory=$false)]
        [string]$WebSitePath = "C:\inetpub\wwwroot",
        
        [Parameter(Mandatory=$false)]
        [int]$Port = 443
    )
    
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName CertificateDsc
    
    Node $AllNodes.NodeName
    {
        # Install IIS Windows Features
        WindowsFeature IIS
        {
            Ensure = "Present"
            Name   = "Web-Server"
        }
        
        WindowsFeature IISManagementTools
        {
            Ensure    = "Present"
            Name      = "Web-Mgmt-Tools"
            DependsOn = "[WindowsFeature]IIS"
        }
        
        WindowsFeature ASPNet45
        {
            Ensure    = "Present"
            Name      = "Web-Asp-Net45"
            DependsOn = "[WindowsFeature]IIS"
        }
        
        WindowsFeature IISDefaultDoc
        {
            Ensure    = "Present"
            Name      = "Web-Default-Doc"
            DependsOn = "[WindowsFeature]IIS"
        }
        
        WindowsFeature IISStaticCompression
        {
            Ensure    = "Present"
            Name      = "Web-Stat-Compression"
            DependsOn = "[WindowsFeature]IIS"
        }
        
        WindowsFeature IISDynamicCompression
        {
            Ensure    = "Present"
            Name      = "Web-Dyn-Compression"
            DependsOn = "[WindowsFeature]IIS"
        }
        
        # Remove Default Website
        xWebsite RemoveDefaultWebsite
        {
            Ensure       = "Absent"
            Name         = "Default Web Site"
            PhysicalPath = "C:\inetpub\wwwroot"
            DependsOn    = "[WindowsFeature]IIS"
        }
        
        # Create Website Directory
        File WebSiteFolder
        {
            Ensure          = "Present"
            Type            = "Directory"
            DestinationPath = $WebSitePath
        }
        
        # Create Application Pool
        xWebAppPool WebAppPool
        {
            Name                  = "$WebSiteName-AppPool"
            Ensure                = "Present"
            State                 = "Started"
            managedRuntimeVersion = "v4.0"
            managedPipelineMode   = "Integrated"
            identityType          = "ApplicationPoolIdentity"
            DependsOn             = "[WindowsFeature]IIS"
        }
        
        # Create Website
        xWebsite Website
        {
            Ensure          = "Present"
            Name            = $WebSiteName
            State           = "Started"
            PhysicalPath    = $WebSitePath
            ApplicationPool = "$WebSiteName-AppPool"
            BindingInfo     = @(
                MSFT_xWebBindingInformation
                {
                    Protocol              = "https"
                    Port                  = $Port
                    CertificateThumbprint = $Node.CertificateThumbprint
                    CertificateStoreName  = "My"
                    IPAddress             = "*"
                }
                MSFT_xWebBindingInformation
                {
                    Protocol  = "http"
                    Port      = 80
                    IPAddress = "*"
                }
            )
            DependsOn       = @("[xWebAppPool]WebAppPool", "[File]WebSiteFolder")
        }
        
        # Configure IIS Security Headers
        Script ConfigureSecurityHeaders
        {
            SetScript = {
                Import-Module WebAdministration
                
                # Add security headers
                Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/httpProtocol/customHeaders" -name "." -value @{name='X-Content-Type-Options';value='nosniff'}
                Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/httpProtocol/customHeaders" -name "." -value @{name='X-Frame-Options';value='SAMEORIGIN'}
                Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/httpProtocol/customHeaders" -name "." -value @{name='X-XSS-Protection';value='1; mode=block'}
                Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/httpProtocol/customHeaders" -name "." -value @{name='Strict-Transport-Security';value='max-age=31536000'}
                
                # Remove server header
                Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/security/requestFiltering" -name "removeServerHeader" -value "True"
            }
            
            TestScript = {
                Import-Module WebAdministration
                $headers = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/httpProtocol/customHeaders" -name "."
                return ($headers.Collection | Where-Object { $_.name -eq 'X-Content-Type-Options' }) -ne $null
            }
            
            GetScript = {
                Import-Module WebAdministration
                $headers = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/httpProtocol/customHeaders" -name "."
                return @{ Result = $headers.Collection.Count }
            }
            
            DependsOn = "[xWebsite]Website"
        }
        
        # Disable weak SSL/TLS protocols
        Registry DisableSSL2Server
        {
            Ensure    = "Present"
            Key       = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server"
            ValueName = "Enabled"
            ValueData = "0"
            ValueType = "Dword"
        }
        
        Registry DisableSSL3Server
        {
            Ensure    = "Present"
            Key       = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server"
            ValueName = "Enabled"
            ValueData = "0"
            ValueType = "Dword"
        }
        
        Registry DisableTLS10Server
        {
            Ensure    = "Present"
            Key       = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server"
            ValueName = "Enabled"
            ValueData = "0"
            ValueType = "Dword"
        }
        
        Registry EnableTLS12Server
        {
            Ensure    = "Present"
            Key       = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"
            ValueName = "Enabled"
            ValueData = "1"
            ValueType = "Dword"
        }
        
        Registry EnableTLS13Server
        {
            Ensure    = "Present"
            Key       = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server"
            ValueName = "Enabled"
            ValueData = "1"
            ValueType = "Dword"
        }
        
        # Configure IIS Logging
        xWebSiteDefaults IISLogging
        {
            LogFormat        = "W3C"
            LogDirectory     = "C:\inetpub\logs\LogFiles"
            DependsOn        = "[WindowsFeature]IIS"
        }
    }
}


