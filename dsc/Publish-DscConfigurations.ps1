#Requires -Version 5.1
<#
.SYNOPSIS
    Compiles the DSC configurations in this folder and publishes them, with the DSC
    resource modules they need, to a DSC pull server.

.DESCRIPTION
    Run on the pull server. For each configuration the script writes
    <ConfigurationName>.mof plus a checksum to the pull server's configuration folder,
    so nodes registered with ConfigurationNames = <ConfigurationName> can pull it.
    It also installs the resource modules from the PowerShell Gallery and publishes
    them as <Module>_<Version>.zip with checksums to the module folder.

.PARAMETER Environment
    Dev, Test or Prod; passed to each configuration.

.EXAMPLE
    .\Publish-DscConfigurations.ps1 -Environment Dev
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Dev', 'Test', 'Prod')]
    [string] $Environment,

    [string] $SourcePath = (Join-Path $PSScriptRoot 'configurations'),
    [string] $ConfigurationPath = "$env:ProgramFiles\WindowsPowerShell\DscService\Configuration",
    [string] $ModulePath = "$env:ProgramFiles\WindowsPowerShell\DscService\Modules",
    [string[]] $Configurations = @('WindowsBase', 'WebServer'),
    [string[]] $ResourceModules = @('ComputerManagementDsc', 'NetworkingDsc', 'SecurityPolicyDsc', 'xWebAdministration', 'CertificateDsc')
)

$ErrorActionPreference = 'Stop'

# 1. Resource modules: install locally (needed to compile) and publish for the nodes
foreach ($name in $ResourceModules) {
    if (-not (Get-Module -ListAvailable -Name $name)) {
        Install-Module -Name $name -Scope AllUsers -Force
    }
    $module = Get-Module -ListAvailable -Name $name | Sort-Object Version -Descending | Select-Object -First 1
    $zip = Join-Path $ModulePath ("{0}_{1}.zip" -f $module.Name, $module.Version)
    if (-not (Test-Path $zip)) {
        Compress-Archive -Path (Join-Path $module.ModuleBase '*') -DestinationPath $zip -Force
        New-DscChecksum -Path $zip -Force
    }
    Write-Output "Module published: $zip"
}

# 2. Configurations: compile for a generic node, then name the MOF after the configuration
$configData = @{
    AllNodes = @(
        @{
            NodeName                    = 'localhost'
            PSDscAllowPlainTextPassword = $false
            PSDscAllowDomainUser        = $true
        }
    )
}
$buildPath = Join-Path $env:TEMP 'dsc-build'

foreach ($name in $Configurations) {
    . (Join-Path $SourcePath "$name.ps1")
    $out = Join-Path $buildPath $name
    & $name -Environment $Environment -ConfigurationData $configData -OutputPath $out | Out-Null

    $mof = Join-Path $ConfigurationPath "$name.mof"
    Copy-Item -Path (Join-Path $out 'localhost.mof') -Destination $mof -Force
    New-DscChecksum -Path $mof -Force
    Write-Output "Configuration published: $mof"
}
