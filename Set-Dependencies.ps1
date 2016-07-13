#requires -Version 3

<#
    .SYNOPSIS
    A brief description of the Set-Dependencies function.
	
    .DESCRIPTION
    A detailed description of the Set-Dependencies function.
	
    .PARAMETER DeploymentTypeName
    The name of the deployment type for this particular piece of software. Defaults to "Install$SoftwareName.cmd"
	
    .PARAMETER SoftwareTitle
    The title of the software that'll show up in SCCM and in software center
	
    .PARAMETER SoftwareVersion
    The version of the software
	
    .PARAMETER SoftwareName
    The short name of the software, used for spaceless names, so directories don't contain spaces
	
    .PARAMETER DependencyTitle
    A description of the DependencyTitle parameter.
	
    .PARAMETER DependencyDeploymentTypeName
    A description of the DependencyDeploymentTypeName parameter.
	
    .PARAMETER IsX64
    A description of the IsX64 parameter.
	
    .PARAMETER SCCMConfig
    A description of the SCCMConfig parameter.
	
    .NOTES
    ===========================================================================
    Created on:   	7/13/2016 12:18 PM
    Created by:   	Sam Novak
    Organization: 	
    Filename: Set-Dependencies.ps1
    ===========================================================================
#>
function Set-Dependencies
{
  [CmdletBinding()]
  param
  (
    [string]$DeploymentTypeName,
    [Parameter(Mandatory = $true)]
    [String]$SoftwareTitle = '',
    [Parameter(Mandatory = $true)]
    [String]$SoftwareVersion = '',
    [Parameter(Mandatory = $true)]
    [String]$SoftwareName = '',
    [Parameter(Mandatory = $true)]
    [String]$DependencyTitle = '',
    [Parameter(Mandatory = $true)]
    [String]$DependencyDeploymentTypeName = '',
    [Parameter(Mandatory = $true)]
    [boolean]$IsX64 = $false,
    [Parameter(Mandatory = $true)]
    [PSObject]$SCCMConfig
  )
	
  if (!($DeploymentTypeName)) 
  {
    $DeploymentTypeName = "Install$SoftwareName.cmd" 
  }
  # This entire function is specially designed for dealing with Flash player, so it's not re-useable as is
  $PSDefaultParameterValues = @{
    'Get-wmiobject:namespace'  = "Root\SMS\site_$($SCCMConfig.SiteCode)"
    'Get-WMIObject:computername' = "$($SCCMConfig.SCCMServer)"
  }
	
  #load the Application Management DLL
  Add-Type -Path "$(Split-Path $Env:SMS_ADMIN_UI_PATH)\Microsoft.ConfigurationManagement.ApplicationManagement.dll"
	
  $dependencyApplication = [wmi](Get-WmiObject -Query "select * from sms_application where LocalizedDisplayName = '$DependencyTitle'").__PATH
  $deserializedDependencyApplication = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::DeserializeFromString($dependencyApplication.SDMPackageXML)
	
  $application = [wmi](Get-WmiObject -Query "select * from sms_application where LocalizedDisplayName LIKE '$SoftwareTitle%' AND SoftwareVersion='$SoftwareVersion' AND IsLatest = 'TRUE'").__PATH
  $deserializedApplication = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::DeserializeFromString($application.SDMPackageXML)
	
  #region Create Expression	
  $oOperands = New-Object -TypeName "Microsoft.ConfigurationManagement.DesiredConfigurationManagement.CustomCollection``1[[Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DeploymentTypeIntentExpression]]"
  #([type]"Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DeploymentTypeIntentExpression").GetConstructors() | ForEach {($_.GetParameters() | ForEach {$_.ToString()}) -Join ", "}
  # System.String appAuthoringScopeId, 
  # System.String appLogicalName, < This is the logical name of the Dependent Application
  # Int32 appVersion, 
  # System.String dtAuthoringScopeId, 
  # System.String dtLogicalName, < This is the logical name of the Dependent deployment type
  # Int32 dtVersion,
  # Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DeploymentTypeDesiredState desiredState,
  # Boolean enforceDesiredState
  $appAuthoringScopeId = $deserializedApplication.Scope
  $appLogicalName = $deserializedDependencyApplication.Name
  $appVersion = 0
  $dtAuthoringScopeId = $deserializedApplication.Scope
  if ($deserializedDependencyApplication.DeploymentTypes.Count -gt 1)
  {
    for ($i = 0; $i -lt $deserializedDependencyApplication.DeploymentTypes.Count; $i++)
    {
      if ($deserializedDependencyApplication.DeploymentTypes.Item($i).Title -eq "$DependencyDeploymentTypeName")
      {
        $dtLogicalName = $deserializedDependencyApplication.DeploymentTypes[$i].Name
        $i = $deserializedDependencyApplication.DeploymentTypes.Count
      }
    }
  }
  else
  {
    $dtLogicalName = $deserializedDependencyApplication.DeploymentTypes[0].Name
  }
	
  if (!($dtLogicalName))
  {
    # Throw an exception here
  }
  $dtVersion = 0
  $desiredState = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DeploymentTypeDesiredState]::Required
  $enforceDesiredState = $true
	
  $DeploymentTypeIntent = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DeploymentTypeIntentExpression -ArgumentList $appAuthoringScopeId, $appLogicalName, $appVersion, $dtAuthoringScopeId, $dtLogicalName, $dtVersion, $desiredState, $enforceDesiredState
	
  $oOperands.Add($DeploymentTypeIntent)
  $oOperator = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ExpressionOperators.ExpressionOperator]::Or
	
  $oDTExpression = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DeploymentTypeExpression `
  -ArgumentList $oOperator, $oOperands
  #endregion
  $oAnnotation = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Annotation
	
  $oAnnotation.DisplayName = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.LocalizableString `
  -ArgumentList 'DisplayName', "$DependencyTitle", $null
	
  $oNoncomplianceSeverity = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.NoncomplianceSeverity]::Critical
  #([type]"Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.DeploymentTypeRule").GetConstructors() | ForEach {($_.GetParameters() | ForEach {$_.ToString()}) -Join ", "}
  # System.String id,
  # Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.NoncomplianceSeverity severity,
  # Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Annotation annotation,
  # Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DeploymentTypeExpression expression
  $oDTRule = New-Object -TypeName 'Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.DeploymentTypeRule' -ArgumentList (
    ('DTRule_' + [Guid]::NewGuid().ToString()), 
    $oNoncomplianceSeverity, 
    $oAnnotation, 
  $oDTExpression)
	
	
  #add the supersedence to the deployment type
	
  if ($deserializedApplication.DeploymentTypes.Count -gt 1)
  {
    for ($i = 0; $i -lt $deserializedApplication.DeploymentTypes.Count; $i++)
    {
      if (($deserializedApplication.DeploymentTypes.Item($i).Requirements.Name -like '*64-bit*') -and ($IsX64))
      {
        $deserializedApplication.DeploymentTypes[$i].Dependencies.Add($oDTRule)
        $i = $deserializedApplication.DeploymentTypes.Count
      }
      elseif (($deserializedApplication.DeploymentTypes.Item($i).Requirements.Name -like '*32-bit*') -and ($IsX64 -eq $false))
      {
        $deserializedApplication.DeploymentTypes[$i].Dependencies.Add($oDTRule)
        $i = $deserializedApplication.DeploymentTypes.Count
      }
      elseif (($deserializedApplication.DeploymentTypes.Item($i).Title -like '*Debug*') -and ($SoftwareName -like '*Debug*'))
      {
        $deserializedApplication.DeploymentTypes[$i].Dependencies.Add($oDTRule)
        $i = $deserializedApplication.DeploymentTypes.Count
      }
      elseif ($deserializedApplication.DeploymentTypes.Item($i).Title -eq $DeploymentTypeName)
      {
        $deserializedApplication.DeploymentTypes[$i].Dependencies.Add($oDTRule)
        $i = $deserializedApplication.DeploymentTypes.Count
      }
      elseif ($deserializedApplication.DeploymentTypes.Item($i).Title -eq $SoftwareName)
      {
        $deserializedApplication.DeploymentTypes[$i].Dependencies.Add($oDTRule)
        $i = $deserializedApplication.DeploymentTypes.Count
      }
    }
  }
  else
  {
    $deserializedApplication.DeploymentTypes[0].Dependencies.Add($oDTRule)
  }
  # Serialize the XML
  $newappxml = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::Serialize($deserializedApplication, $false)
	
  #set the property back on the local copy of the Object
  $application.SDMPackageXML = $newappxml
	
  #Now time to set the changes back to the ConfigMgr
  $application.Put() > $null
}
