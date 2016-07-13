#requires -Version 2
<#
    .SYNOPSIS
    Returns a PSObject with variables used by other scripts.
	
    .DESCRIPTION
    A detailed description of the New-SCCMDeploymentConfig function.
	
    .PARAMETER SiteCode
    The particular site code of the SCCM instance.
	
    .PARAMETER Namespace
    The namespace for the SCCM instance
	
    .PARAMETER SCCMServer
    The computer name of the SCCM server.
	
    .NOTES
    ===========================================================================
    Created on:   	7/13/2016 12:18 PM
    Created by:   	Sam Novak
    Organization: 	
    Filename: New-SCCMDeploymentConfig.ps1
    ===========================================================================
#>
function New-SCCMDeploymentConfig
{
  [CmdletBinding()]
  [OutputType([psobject])]
  param
  (
    [Parameter(Mandatory = $false)]
    [String]$SiteCode,
    [String]$Namespace,
    [Parameter(Mandatory = $true)]
    [String]$SCCMServer
  )
	
  if (!($SiteCode)) 
  {
    $SiteCode = @(Get-WmiObject -ComputerName $SCCMServer -Namespace 'root\SMS' -Class 'SMS_ProviderLocation' |
      Where-Object -FilterScript {
        $_.ProviderForLocalSite 
      } |
      ForEach-Object -Process {
        $_.SiteCode 
    })[-1] 
  }
  if (!($Namespace)) 
  {
    $Namespace = "root\SMS\site_$SiteCode" 
  }
  $NewSCCMDeploymentConfig = New-Object -TypeName PSObject -Property @{
    SiteCode   = $SiteCode
    Namespace  = $Namespace
    SCCMServer = $SCCMServer
  }

  return $NewSCCMDeploymentConfig
}
