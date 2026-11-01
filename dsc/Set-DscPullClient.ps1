#Requires -Version 5.1
<#
.SYNOPSIS
    Configures the Local Configuration Manager on this node to pull its configuration
    from a DSC pull server.

.PARAMETER ServerUrl
    Pull server endpoint, for example http://10.10.10.30:8080/PSDSCPullServer.svc

.PARAMETER RegistrationKey
    The key listed in RegistrationKeys.txt on the pull server.

.PARAMETER ConfigurationNames
    Configurations to apply, as published by Publish-DscConfigurations.ps1.

.EXAMPLE
    .\Set-DscPullClient.ps1 -ServerUrl http://10.10.10.30:8080/PSDSCPullServer.svc -RegistrationKey <key>
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ServerUrl,
    [Parameter(Mandatory)] [string] $RegistrationKey,
    [string[]] $ConfigurationNames = @('WindowsBase'),
    [ValidateSet('ApplyOnly', 'ApplyAndMonitor', 'ApplyAndAutoCorrect')]
    [string] $ConfigurationMode = 'ApplyAndAutoCorrect',
    [int] $RefreshFrequencyMins = 30
)

$ErrorActionPreference = 'Stop'

[DSCLocalConfigurationManager()]
Configuration PullClient {
    Node localhost {
        Settings {
            RefreshMode                    = 'Pull'
            ConfigurationMode              = $ConfigurationMode
            RefreshFrequencyMins           = $RefreshFrequencyMins
            ConfigurationModeFrequencyMins = [Math]::Max(15, $RefreshFrequencyMins)
            RebootNodeIfNeeded             = $false
        }
        ConfigurationRepositoryWeb PullServer {
            ServerURL               = $ServerUrl
            RegistrationKey         = $RegistrationKey
            ConfigurationNames      = $ConfigurationNames
            AllowUnsecureConnection = $ServerUrl.StartsWith('http://')
        }
        ResourceRepositoryWeb PullServerModules {
            ServerURL               = $ServerUrl
            RegistrationKey         = $RegistrationKey
            AllowUnsecureConnection = $ServerUrl.StartsWith('http://')
        }
        ReportServerWeb PullServerReports {
            ServerURL               = $ServerUrl
            RegistrationKey         = $RegistrationKey
            AllowUnsecureConnection = $ServerUrl.StartsWith('http://')
        }
    }
}

$out = Join-Path $env:TEMP 'dsc-pull-client'
PullClient -OutputPath $out | Out-Null
Set-DscLocalConfigurationManager -Path $out -Force
Update-DscConfiguration -Wait
Get-DscLocalConfigurationManager | Select-Object RefreshMode, ConfigurationMode, LCMState
