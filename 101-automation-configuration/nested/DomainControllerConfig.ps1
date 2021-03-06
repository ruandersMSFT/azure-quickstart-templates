﻿
<#PSScriptInfo

.VERSION 0.3.1

.GUID edd05043-2acc-48fa-b5b3-dab574621ba1

.AUTHOR Michael Greene

.COMPANYNAME Microsoft Corporation

.COPYRIGHT 

.TAGS DSCConfiguration

.LICENSEURI https://github.com/Microsoft/DomainControllerConfig/blob/master/LICENSE

.PROJECTURI https://github.com/Microsoft/DomainControllerConfig

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
https://github.com/Microsoft/DomainControllerConfig/blob/master/README.md#versions

.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core

#>

#Requires -module @{ModuleName = 'ActiveDirectoryDsc';ModuleVersion = '6.0.1'}
#Requires -module @{ModuleName = 'xStorage'; ModuleVersion = '3.4.0.0'}
#Requires -module @{ModuleName = 'ComputerManagementDsc'; ModuleVersion = '8.4.0'}

<#

.DESCRIPTION 
Demonstrates a minimally viable domain controller configuration script
compatible with Azure Automation Desired State Configuration service.
 
 Required variables in Automation service:
  - Credential to use for AD domain admin
  - Credential to use for Safe Mode recovery

Create these credential assets in Azure Automation,
and set their names in lines 11 and 12 of the configuration script.

Required modules in Automation service:
  - ActiveDirectoryDsc
  - xStorage
  - ComputerManagementDsc

#>

configuration DomainControllerConfig
{

Import-DscResource -ModuleName @{ModuleName = 'ActiveDirectoryDsc'; ModuleVersion = '6.0.1'}
Import-DscResource -ModuleName @{ModuleName = 'xStorage'; ModuleVersion = '3.4.0.0'}
Import-DscResource -ModuleName @{ModuleName = 'ComputerManagementDsc'; ModuleVersion = '8.4.0'}
Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

# When using with Azure Automation, modify these values to match your stored credential names
$domainCredential = Get-AutomationPSCredential 'Credential'
$safeModeCredential = Get-AutomationPSCredential 'Credential'

  node localhost
  {
    WindowsFeature ADDSInstall
    {
        Ensure = 'Present'
        Name = 'AD-Domain-Services'
    }
    
    xWaitforDisk Disk2
    {
        DiskId = 2
        RetryIntervalSec = 10
        RetryCount = 30
    }
    
    xDisk DiskF
    {
        DiskId = 2
        DriveLetter = 'F'
        DependsOn = '[xWaitforDisk]Disk2'
    }
    
    PendingReboot BeforeDC
    {
        Name = 'BeforeDC'
        SkipCcmClientSDK = $true
        DependsOn = '[WindowsFeature]ADDSInstall','[xDisk]DiskF'
    }
    
    # Configure domain values here
    ADDomain Domain
    {
        DomainName = 'contoso.local'
        Credential = $domainCredential
        SafeModeAdministratorPassword = $safeModeCredential
        DatabasePath = 'F:\NTDS'
        LogPath = 'F:\NTDS'
        SysvolPath = 'F:\SYSVOL'
        DependsOn = '[WindowsFeature]ADDSInstall','[xDisk]DiskF','[PendingReboot]BeforeDC'
    }
    
    Registry DisableRDPNLA
    {
        Key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
        ValueName = 'UserAuthentication'
        ValueData = 0
        ValueType = 'Dword'
        Ensure = 'Present'
        DependsOn = '[ADDomain]Domain'
    }
  }
}