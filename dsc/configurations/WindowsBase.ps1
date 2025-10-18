# Windows Base Configuration - PowerShell DSC
# Author: Adrian Johnson <adrian207@gmail.com>
# Description: Base configuration for all Windows managed nodes

Configuration WindowsBase
{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Dev", "Test", "Prod")]
        [string]$Environment,
        
        [Parameter(Mandatory=$false)]
        [string]$TimeZone = "Eastern Standard Time",
        
        [Parameter(Mandatory=$false)]
        [string[]]$NTPServers = @("time.windows.com", "time.nist.gov")
    )
    
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName NetworkingDsc
    Import-DscResource -ModuleName SecurityPolicyDsc
    
    Node $AllNodes.NodeName
    {
        # Set timezone
        TimeZone SetTimeZone
        {
            IsSingleInstance = 'Yes'
            TimeZone         = $TimeZone
        }
        
        # Configure Windows Firewall
        Firewall EnableFirewall
        {
            Name    = 'Firewall-EnabledState'
            Ensure  = 'Present'
            Enabled = 'True'
        }
        
        # Disable SMBv1
        WindowsFeature DisableSMB1
        {
            Name   = 'FS-SMB1'
            Ensure = 'Absent'
        }
        
        # Install required Windows features
        WindowsFeature InstallNETFramework
        {
            Name   = 'NET-Framework-45-Core'
            Ensure = 'Present'
        }
        
        WindowsFeature InstallPowerShellISE
        {
            Name   = 'PowerShell-ISE'
            Ensure = 'Present'
        }
        
        # Configure Windows Update settings
        Registry DisableAutoUpdate
        {
            Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
            ValueName = 'NoAutoUpdate'
            ValueData = '1'
            ValueType = 'Dword'
            Ensure    = 'Present'
        }
        
        # Set DNS servers
        DnsServerAddress SetDNS
        {
            Address        = $Node.DNSServers
            InterfaceAlias = 'Ethernet'
            AddressFamily  = 'IPv4'
        }
        
        # Configure Windows Defender
        Registry EnableRealTimeProtection
        {
            Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'
            ValueName = 'DisableRealtimeMonitoring'
            ValueData = '0'
            ValueType = 'Dword'
            Ensure    = 'Present'
        }
        
        # Audit Policy Settings
        AuditPolicySubcategory 'Audit Credential Validation (Success)'
        {
            Name      = 'Credential Validation'
            AuditFlag = 'Success'
            Ensure    = 'Present'
        }
        
        AuditPolicySubcategory 'Audit Credential Validation (Failure)'
        {
            Name      = 'Credential Validation'
            AuditFlag = 'Failure'
            Ensure    = 'Present'
        }
        
        AuditPolicySubcategory 'Audit Logon (Success)'
        {
            Name      = 'Logon'
            AuditFlag = 'Success'
            Ensure    = 'Present'
        }
        
        AuditPolicySubcategory 'Audit Logon (Failure)'
        {
            Name      = 'Logon'
            AuditFlag = 'Failure'
            Ensure    = 'Present'
        }
        
        # User Rights Assignment
        UserRightsAssignment 'Allow log on locally'
        {
            Policy   = 'Allow_log_on_locally'
            Identity = @('BUILTIN\Administrators', 'BUILTIN\Users')
        }
        
        UserRightsAssignment 'Deny log on locally'
        {
            Policy   = 'Deny_log_on_locally'
            Identity = @('Guest')
        }
        
        # Security Options
        SecurityOption AccountPolicies
        {
            Name                                   = 'AccountPolicies'
            Enforce_password_history               = 24
            Maximum_Password_Age                   = 90
            Minimum_Password_Age                   = 1
            Minimum_Password_Length                = 14
            Password_must_meet_complexity_requirements = 'Enabled'
            Store_passwords_using_reversible_encryption = 'Disabled'
            Account_lockout_duration               = 30
            Account_lockout_threshold              = 5
            Reset_account_lockout_counter_after    = 30
        }
        
        # Local Administrator Password Management
        Group LocalAdminGroup
        {
            GroupName        = 'Administrators'
            Ensure           = 'Present'
            MembersToInclude = @('Domain\ConfigMgmt_Admins')
        }
        
        # Install Windows Exporter for Prometheus monitoring
        Script InstallWindowsExporter
        {
            SetScript = {
                $exporterUrl = "https://github.com/prometheus-community/windows_exporter/releases/download/v0.25.1/windows_exporter-0.25.1-amd64.msi"
                $exporterPath = "$env:TEMP\windows_exporter.msi"
                
                Invoke-WebRequest -Uri $exporterUrl -OutFile $exporterPath
                Start-Process msiexec.exe -ArgumentList "/i $exporterPath /quiet /norestart ENABLED_COLLECTORS=cpu,cs,logical_disk,net,os,service,system,process" -Wait
                Remove-Item $exporterPath -Force
            }
            
            TestScript = {
                $service = Get-Service -Name "windows_exporter" -ErrorAction SilentlyContinue
                return ($null -ne $service)
            }
            
            GetScript = {
                $service = Get-Service -Name "windows_exporter" -ErrorAction SilentlyContinue
                return @{
                    Result = if ($service) { "Installed" } else { "Not Installed" }
                }
            }
        }
        
        # Configure Windows Firewall rule for monitoring
        Firewall AllowPrometheusExporter
        {
            Name        = 'Prometheus-Windows-Exporter'
            DisplayName = 'Prometheus Windows Exporter'
            Ensure      = 'Present'
            Enabled     = 'True'
            Direction   = 'Inbound'
            Protocol    = 'TCP'
            LocalPort   = '9182'
            Action      = 'Allow'
            Profile     = ('Domain', 'Private')
        }
    }
}

# Configuration Data
$ConfigData = @{
    AllNodes = @(
        @{
            NodeName    = '*'
            PSDscAllowPlainTextPassword = $false
            PSDscAllowDomainUser = $true
        }
    )
}


