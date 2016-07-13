#requires -Version 3
<#
    .SYNOPSIS
    A brief description of the Set-RegistryDetection function.
	
    .DESCRIPTION
    A detailed description of the Set-RegistryDetection function.
	
    .PARAMETER DeploymentTypeName
    The name of the deployment type for this particular piece of software. Defaults to "Install$SoftwareName.cmd"
	
    .PARAMETER SoftwareName
    The short name of the software, used for spaceless names, so directories don't contain spaces
	
    .PARAMETER SoftwareTitle
    The title of the software that'll show up in SCCM and in software center.
	
    .PARAMETER SoftwareVersion
    The version of the software
	
    .PARAMETER RegistryKeyLocation
    A description of the RegistryKeyLocation parameter.
	
    .PARAMETER IsX64
    A description of the IsX64 parameter.
	
    .PARAMETER B32BitOn64Bit
    A description of the B32BitOn64Bit parameter.
	
    .PARAMETER SCCMConfig
    A description of the SCCMConfig parameter.
	
    .NOTES
    ===========================================================================
    Created on:   	7/13/2016 12:18 PM
    Created by:   	Sam Novak
    Organization: 	
    Filename: Set-RegistryDetection.ps1
    ===========================================================================
#>
function Set-RegistryDetection
{
  [CmdletBinding()]
  param
  (
    [string]$DeploymentTypeName,
    [string]$SoftwareName,
    [Parameter(Mandatory = $true)]
    [string]$SoftwareTitle,
    [Parameter(Mandatory = $true)]
    [string]$SoftwareVersion,
    [Parameter(Mandatory = $true)]
    [string]$RegistryKeyLocation,
    [boolean]$IsX64 = $false,
    [boolean]$B32BitOn64Bit = $false,
    [PSObject]$SCCMConfig
  )
	
  if (!($DeploymentTypeName)) 
  {
    $DeploymentTypeName = "Install$SoftwareName.cmd" 
  }
	
  #Load the Default Parameter Values for Get-WMIObject cmdlet
  $PSDefaultParameterValues = @{
    'Get-wmiobject:namespace'  = "Root\SMS\site_$($SCCMConfig.SiteCode)"
    'Get-WMIObject:computername' = "$($SCCMConfig.SCCMServer)"
  }
	
  #load the Application Management DLL
  Add-Type -Path "$(Split-Path $Env:SMS_ADMIN_UI_PATH)\Microsoft.ConfigurationManagement.ApplicationManagement.dll"
  # https://social.technet.microsoft.com/Forums/en-US/93bddee4-6aee-4641-b104-170968ad1549/automating-application-creation?forum=configmanagersdk
	
  ### TODO: revise these queries to be more accurate in their selections
  $Application = (Get-WmiObject -Query "select * from sms_application  WHERE LocalizedDisplayName LIKE '$SoftwareTitle%' AND SoftwareVersion='$SoftwareVersion' AND IsLatest = 'TRUE'")
  # Referencing the bottom ModelName is okay here since the GUID doesn't change with revisions
	
  $App1Deserializedstuff = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::DeserializeFromString(([wmi]$Application.__PATH).SDMPackageXML)
  # This is unlikely to happen, because the array is listing all of the existing revisions, which we have yet to deal with
  if ($Application.ModelName.GetType().Name -eq 'String')
  {
    $DeploymentType = (Get-WmiObject -Query "select * from SMS_deploymentType WHERE APPModelName = '$($Application.ModelName)' AND LocalizedDisplayName='$DeploymentTypeName'  AND IsLatest = 'TRUE'") 
  }
  else
  {
    $DeploymentType = (Get-WmiObject -Query "select * from SMS_deploymentType WHERE APPModelName = '$($Application.ModelName[0])' AND LocalizedDisplayName='$DeploymentTypeName'  AND IsLatest = 'TRUE'") 
  }
  $DeserialDeploymentType = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::DeserializeFromString(([wmi]$DeploymentType.__PATH).SDMPackageXML)
  #$TEMP2.DeploymentTypes[0].Installer.EnhancedDetectionMethod
  #$TEMP3 = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Rule]$DeserialDeploymentType.DeploymentTypes[0].Installer.EnhancedDetectionMethod.Rule
	
	
  # We need to create the file entry up here, since the file logicalname is used in the detection settings
  # ([type]"Microsoft.ConfigurationManagement.DesiredConfigurationManagement.SimpleSetting").GetConstructors() | ForEach {($_.GetParameters() | ForEach {$_.ToString()}) -Join ", "}
	
  $DcmObjectModelPath = 'C:\Program Files (x86)\Microsoft Configuration Manager\bin\DcmObjectModel.dll'
  # http://powershelldistrict.com/powershell-configmgr-enhanced-detection-method/
  $sourceFix = @"
using Microsoft.ConfigurationManagement.DesiredConfigurationManagement;
using System;
namespace RegistrySettingNamespace
{
	public class RegistrySettingFix
	{
		private RegistrySetting _registrysetting;
		public RegistrySettingFix(string str)
		{
			this._registrysetting = new RegistrySetting(null);
		}
		public RegistrySetting GetRegistrySetting()
		{
			return this._registrysetting;
		}
	}
}
"@
	
	
	
	
	
  #Hack to bypass bug in Microsoft.ConfigurationManagement.DesiredConfigurationManagement.registrySetting which doesn't allow us to create a enhanced detection method.
  Add-Type -ReferencedAssemblies $DcmObjectModelPath -TypeDefinition $sourceFix -Language CSharp
  $temp = New-Object -TypeName RegistrySettingNamespace.RegistrySettingFix -ArgumentList ''
	
  $oRegistrySetting = $temp.GetRegistrySetting()
  $oEnhancedDetection = New-Object -TypeName Microsoft.ConfigurationManagement.ApplicationManagement.EnhancedDetectionMethod
	
  $oDetectionType = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ConfigurationItemPartType]::RegistryKey
	
  $RegistryHyve = $RegistryKeyLocation -ireplace '([A-Z]*)\\.*', '$1'
  if ($oRegistrySetting -ne $null) 
  {
    Write-Verbose -Message ' oRegistrySetting object Created' 
  }
  else 
  {
    Write-Warning -Message ' oRegistrySetting object Creation failed'
    Break
  }
	
  switch ($RegistryHyve)
  {
    'HKEY_CLASSES_ROOT'
    {
      $oRegistrySetting.RootKey = 'ClassesRoot'
      Break
    }
    'HKEY_CURRENT_CONFIG'
    {
      $oRegistrySetting.RootKey = 'CurrentConfig'
      Break
    }
    'HKEY_CURRENT_USER'
    {
      $oRegistrySetting.RootKey = 'CurrentUser'
      Break
    }
    'HKLM'
    {
      $oRegistrySetting.RootKey = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.RegistryRootKey]::LocalMachine
      #Break
    }
    'HKEY_USERS'
    {
      $oRegistrySetting.RootKey = 'Users'
      Break
    }
  }
	
	
  $oRegistrySetting.Key = $RegistryKeyLocation -ireplace '[A-Z]+?\\(.*)\\[A-Za-z\ ]*', '$1'
  $oRegistrySetting.ValueName = $RegistryKeyLocation -ireplace '.*\\(A-Za-z\ )*', '$1'
  if ($IsX64) 
  {
    $Is64bits = 1 
  }
  elseif (!($B32BitOn64Bit)) 
  {
    $Is64bits = 1 
  }
  else 
  {
    $Is64bits = 0 
  }
  $oRegistrySetting.Is64Bit = $Is64bits #$Is64bits
  $oRegistrySetting.SettingDataType = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DataType]::String #$RegistryKeyValueDataType
  #$oRegistrySetting.ChangeLogicalName()
	
  $oEnhancedDetection.Settings.Add($oRegistrySetting)
  #$oFileSetting
  Write-Verbose  -Message 'Settings Reference'
  $oSettingRef = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.SettingReference -ArgumentList (
    $App1Deserializedstuff.Scope, 
    $App1Deserializedstuff.Name, 
    $App1Deserializedstuff.Version, 
    $oRegistrySetting.LogicalName, 
    $oRegistrySetting.SettingDataType, 
    $oRegistrySetting.SourceType, 
  [boolean]0)
  # setting bool 0 as false
  if ($oSettingRef -ne $null) 
  {
    Write-Verbose -Message ' oSettingRef object Created' 
  }
  else 
  {
    Write-Warning -Message ' oSettingRef object Creation failed'
    break
  }
	
  #Registry Setting must satisfy the following rule
  $oSettingRef.MethodType = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ConfigurationItemSettingMethodType]::Value
  #$oSettingRef.PropertyPath = "RegistryValueEquals"
  #$oSettingRef
  <#
      if (!($CheckForConstant)){
      $ConstantValue = $true
      $ConstantDataType = "boolean"
      }
  #>
  #$ConstantValue = $true
  #$ConstantDataType = "boolean"
  $oConstValue = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.ConstantValue -ArgumentList ("$SoftwareVersion", 
  [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DataType]::String)
  if ($oConstValue -ne $null) 
  {
    Write-Verbose -Message ' oConstValue object Created' 
  }
  else 
  {
    Write-Warning -Message ' oConstValue object Creation failed'
    break
  }
	
	
  $oRegistrySettingOperands = New-Object -TypeName Microsoft.ConfigurationManagement.DesiredConfigurationManagement.CustomCollection``1[[Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.ExpressionBase]]
  $oRegistrySettingOperands.Add($oSettingRef)
  $oRegistrySettingOperands.Add($oConstValue)
	
  $oExpressionOperator = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ExpressionOperators.ExpressionOperator]::IsEquals
	
  $oExpression = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.Expression -ArgumentList $oExpressionOperator, $oRegistrySettingOperands
	
  $oNoncomplianceSeverity = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.NoncomplianceSeverity]::Informational
	
  # ([type]"Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Annotatio").GetConstructors() | ForEach {($_.GetParameters() | ForEach {$_.ToString()}) -Join ", "} 
  $oAnnotation = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Annotation
	
  $oRuleID = $DeploymentType.ModelName
	
  # ([type]"Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Rule").GetConstructors() | ForEach {($_.GetParameters() | ForEach {$_.ToString()}) -Join ", "} 
  # System.String id,
  # Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.NoncomplianceSeverity severity,
  # Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Annotation annotation,
  # Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.ExpressionBase ruleExpression
  $oRule = New-Object -TypeName 'Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Rule' -ArgumentList (
    $oRuleID, 
    $oNoncomplianceSeverity, 
    $oAnnotation, 
  $oExpression)
	
  #$oEnhancedDetection.ChangeId()
  $oEnhancedDetection.Rule = $oRule
	
	
  # TODO Actually set the rule to the deployment
  if ($DeserialDeploymentType.DeploymentTypes.Count -gt 1)
  {
    for ($i = 0; $i -lt $DeserialDeploymentType.DeploymentTypes.Count; $i++)
    {
      if (($DeserialDeploymentType.DeploymentTypes.Item($i).Requirements.Name -like '*64-bit*') -and ($IsX64))
      {
        $DeserialDeploymentType.DeploymentTypes[$i].Installer.DetectionMethod = [Microsoft.ConfigurationManagement.ApplicationManagement.DetectionMethod]::Enhanced
        $DeserialDeploymentType.DeploymentTypes[$i].Installer.EnhancedDetectionMethod = $oEnhancedDetection
        $i = $DeserialDeploymentType.DeploymentTypes.Count
      }
      elseif (($DeserialDeploymentType.DeploymentTypes.Item($i).Requirements.Name -like '*32-bit*') -and ($IsX64 -eq $false))
      {
        $DeserialDeploymentType.DeploymentTypes[$i].Installer.DetectionMethod = [Microsoft.ConfigurationManagement.ApplicationManagement.DetectionMethod]::Enhanced
        $DeserialDeploymentType.DeploymentTypes[$i].Installer.EnhancedDetectionMethod = $oEnhancedDetection
        $i = $DeserialDeploymentType.DeploymentTypes.Count
      }
    }
  }
  else
  {
    $DeserialDeploymentType.DeploymentTypes[0].Installer.DetectionMethod = [Microsoft.ConfigurationManagement.ApplicationManagement.DetectionMethod]::Enhanced
    $DeserialDeploymentType.DeploymentTypes[0].Installer.EnhancedDetectionMethod = $oEnhancedDetection
  }
  #$DeserialDeploymentType.DeploymentTypes[0].Installer.DetectionMethod =""
	
	
  # Serialize the XML
  $newappxml = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::Serialize($DeserialDeploymentType, $false)
  $ApplicationWMI = [wmi](Get-WmiObject -Query "select * from sms_application where LocalizedDisplayName LIKE '$SoftwareTitle%' AND SoftwareVersion='$SoftwareVersion' AND IsLatest = 'TRUE'").__PATH
  #$ApplicationWMI = (Get-WmiObject -Query "select * from sms_application  WHERE LocalizedDisplayName LIKE '$SoftwareTitle%' AND SoftwareVersion='$SoftwareVersion'")
  #set the property back on the local copy of the Object
  $ApplicationWMI.SDMPackageXML = $newappxml
	
  $ApplicationWMI.Put() > $null
}
