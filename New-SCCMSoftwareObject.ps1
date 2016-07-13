#requires -Version 2
<#
    .SYNOPSIS
    A brief description of the Create-SCCMSoftwareObject function.
	
    .DESCRIPTION
    A detailed description of the Create-SCCMSoftwareObject function.
	
    .PARAMETER B32BitOn64Bit
    True if the software installs to x86 on 64 bit operating systems.
	
    .PARAMETER B32BitOnly
    True if the software is only for 32 bit operating systems, or if this is the 32 bit version of software that also has a 64 bit installer.
	
    .PARAMETER B64BitOnly
    True if the software is only for 64 bit operating systems, or if this is the 64 bit version of software that also has a 32 bit installer.
	
    .PARAMETER DependencyTitle
    The title of the application that the current piece of software depends on.
	
    .PARAMETER DependencyDeploymentTypeName
    The title of the deployment type that the current piece of software depends on.
	
    .PARAMETER FilePath
    The path to the file used in the file detection method
	
    .PARAMETER RegistryKeyLocation
    The full path to the registry key used in the registry detection method
	
    .PARAMETER SoftwareAltName
    An alternate name for the software, used for detecting software for supersedence
	
    .PARAMETER SoftwareName
    The short name of the software, used for spaceless names, so directories don't contain spaces
	
    .PARAMETER SoftwareTitle
    The title of the software that'll show up in SCCM and in software center
	
    .PARAMETER SoftwareVersion
    The version of the software
	
    .PARAMETER UninstallSuperseded
    Whether or not to uninstall the superseded applications
	
    .PARAMETER DeploymentTypeName
    The name of the deployment type for this particular piece of software. Defaults to "Install$SoftwareName.cmd"
	
    .PARAMETER CollectionSplit
    An array of values that correlate with collections from the collections.ini file.
	
    .PARAMETER CreateDeployments
    Whether or not to create deployments
	
    .PARAMETER DeadlineTime
    The time to set the installation deadline to.
	
    .PARAMETER Description
    The description to be shown in software center
	
    .PARAMETER DetectionMethod
    The detection method to be used for the software
	
    .PARAMETER SkipAppCenter
    A description of the SkipAppCenter parameter.
	
    .PARAMETER SkipeVersionProcessing
    A description of the SkipeVersionProcessing parameter.
	
    .OUTPUTS
    psobject, psobject, psobject, psobject
	
    .NOTES
    ===========================================================================
    Created on:   	7/13/2016 12:18 PM
    Created by:   	Sam Novak
    Organization: 	
    Filename: New-SCCMSoftwareObject.ps1
    ===========================================================================
#>
function Create-SCCMSoftwareObject
{
  [CmdletBinding()]
  [OutputType([psobject])]
  param
  (
    [boolean]$B32BitOn64Bit = $false,
    [boolean]$B32BitOnly = $false,
    [boolean]$B64BitOnly = $false,
    [string]$DependencyTitle,
    [string]$DependencyDeploymentTypeName,
    [string]$FilePath,
    [string]$RegistryKeyLocation,
    [string]$SoftwareAltName,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [Alias('Name')]
    [string]$SoftwareName,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [Alias('Title')]
    [String]$SoftwareTitle,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [Alias('Version')]
    [string]$SoftwareVersion,
    [boolean]$UninstallSuperseded = $true,
    [String]$DeploymentTypeName
  )
	
  $NewSCCMSoftwareObject = New-Object -TypeName PSObject -Property @{
    DeploymentTypeName           = $DeploymentTypeName
    DependencyTitle              = $DependencyTitle
    DependencyDeploymentTypeName = $DependencyDeploymentTypeName
    B32BitOn64Bit                = $B32BitOn64Bit
    B32BitOnly                   = $B32BitOnly
    B64BitOnly                   = $B64BitOnly
    FilePath                     = $FilePath
    RegistryKeyLocation          = $RegistryKeyLocation
    SoftwareAltName              = $SoftwareAltName
    SoftwareName                 = $SoftwareName
    SoftwareTitle                = $SoftwareTitle
    SoftwareVersion              = $SoftwareVersion
    UninstallSuperseded          = $UninstallSuperseded
  }
	
  return $NewSCCMSoftwareObject
  #TODO: Place script here
}
