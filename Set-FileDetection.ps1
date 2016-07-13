#requires -Version 3

<#
    .SYNOPSIS
    A brief description of the Set-FileDetection function.
	
    .DESCRIPTION
    A detailed description of the Set-FileDetection function.
	
    .PARAMETER DeploymentTypeName
    The name of the deployment type for this particular piece of software. Defaults to "Install$SoftwareName.cmd"
	
    .PARAMETER SoftwareName
    The short name of the software, used for spaceless names, so directories don't contain spaces
	
    .PARAMETER SoftwareTitle
    The title of the software that'll show up in SCCM and in software center
	
    .PARAMETER SoftwareVersion
    The version of the software
	
    .PARAMETER FilePath
    A description of the FilePath parameter.
	
    .PARAMETER FullVersionDetection
    A description of the FullVersionDetection parameter.
	
    .PARAMETER MinVersionDetection
    A description of the MinVersionDetection parameter.
	
    .PARAMETER IsX64
    A description of the IsX64 parameter.
	
    .PARAMETER SCCMConfig
    A description of the SCCMConfig parameter.
	
    .NOTES
    ===========================================================================
    Created on:   	7/13/2016 12:18 PM
    Created by:   	Sam Novak
    Organization: 	
    Filename: Set-FileDetection.ps1
    ===========================================================================
#>
function Set-FileDetection
{
  [CmdletBinding()]
  param
  (
    [string]$DeploymentTypeName,
    [string]$SoftwareName,
    [string]$SoftwareTitle,
    [string]$SoftwareVersion,
    [string]$FilePath,
    [boolean]$FullVersionDetection = $false,
    [boolean]$MinVersionDetection = $false,
    [boolean]$IsX64 = $false,
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
  $Application = (Get-WmiObject -Query "select * from sms_application  WHERE LocalizedDisplayName LIKE '$SoftwareTitle%' AND SoftwareVersion='$SoftwareVersion'")
  # Referencing the bottom ModelName is okay here since the GUID doesn't change with revisions
  if ($Application.ModelName.GetType().Name -eq 'String')
  {
    $DeploymentType = (Get-WmiObject -Query "select * from SMS_deploymentType WHERE APPModelName = '$($Application.ModelName)' AND LocalizedDisplayName='$DeploymentTypeName'") 
  }
  else
  {
    $DeploymentType = (Get-WmiObject -Query "select * from SMS_deploymentType WHERE APPModelName = '$($Application.ModelName[0])' AND LocalizedDisplayName='$DeploymentTypeName'") 
  }
  $DeserialDeploymentType = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::DeserializeFromString(([wmi]$DeploymentType.__PATH).SDMPackageXML)
  #$TEMP2.DeploymentTypes[0].Installer.EnhancedDetectionMethod
  #$TEMP3 = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Rule]$DeserialDeploymentType.DeploymentTypes[0].Installer.EnhancedDetectionMethod.Rule
	
  # We need to create the file entry up here, since the file logicalname is used in the detection settings
  # ([type]"Microsoft.ConfigurationManagement.DesiredConfigurationManagement.SimpleSetting").GetConstructors() | ForEach {($_.GetParameters() | ForEach {$_.ToString()}) -Join ", "}
	
  $file = New-Object -TypeName Microsoft.ConfigurationManagement.DesiredConfigurationManagement.FileOrFolder -ArgumentList ([Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ConfigurationItemPartType]::File, $null)
  $ExeDirPath = $FilePath -replace 'C:\\Program Files \(x86\)\\', '%ProgramFiles(x86)%\' -replace 'C:\\Program Files\\', '%ProgramFiles%\'
  if ($ExeDirPath -like '*ProgramFiles(x86)*')
  {
    $ExeDirPath = $ExeDirPath -replace 'ProgramFiles\(x86\)', 'ProgramFiles'
    $file.Is64Bit = $false
  }
  else
  {
    $file.Is64Bit = $IsX64 
  }
  $ExeDirPath = [System.IO.Path]::GetDirectoryName($ExeDirPath)
  $ExeName = [System.IO.Path]::GetFileName($FilePath)
  $file.Path = $ExeDirPath
  $file.FileOrFolderName = $ExeName
  $file.SearchDepth = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.SearchScope]::Base
	
	
  #$DeploymentType.Installer.EnhancedDetectionMethod = new-object Microsoft.ConfigurationManagement.ApplicationManagement.EnhancedDetectionMethod
	
  $settingScopeid = $DeserialDeploymentType.Scope
  $settingLogicalName = $DeserialDeploymentType.Name
  $settingRefName = $file.LogicalName
  #"File_" + [Guid]::NewGuid().ToString()
  $settingDataType = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DataType]::Version
  $settingSourceType = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ConfigurationItemSettingSourceType]::File
  $settingMethodType = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ConfigurationItemSettingMethodType]::Value
  $settingPropertyPath = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ConfigurationItemSettingDataType]::Version
	
  # ([type]"Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.SettingReference").GetConstructors() | ForEach {($_.GetParameters() | ForEach {$_.ToString()}) -Join ", "} 
  # System.String ciAuthoringScope, 
  # System.String ciLogicalName, 
  # Int32 ciVersion, 
  # System.String settingLogicalName,
  # Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DataType settingDataType,
  # Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ConfigurationItemSettingSourceType settingSourceType,
  # Boolean isChangeable,
  # Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ConfigurationItemSettingMethodType methodType,
  # System.String propertyPath
  $settingReference = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.SettingReference -ArgumentList $settingScopeid, $settingLogicalName, 1, $settingRefName, $settingDataType, $settingSourceType, $false, $settingMethodType, $settingPropertyPath
	
	
	
  $valueListDataType = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DataType]::VersionArray
  $valueDataType = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DataType]::Version
  $valueVersioning = [Version]"$SoftwareVersion"
  if ($valueVersioning.Build -eq -1) 
  {
    $valueVersioning = [version]('{0}.{1}.{2}.{3}' -f $valueVersioning.Major, $valueVersioning.Minor, '0', '0') 
  }
  if ($valueVersioning.Minor -eq -1) 
  {
    $valueVersioning = [version]('{0}.{1}.{2}.{3}' -f $valueVersioning.Major, '0', '0', '0') 
  }
  if ($valueVersioning.Major -eq -1) 
  {
    throw [System.Exception] "$SoftwareVersion isn't parsing correctly! Can't retrieve Major revision when $SoftwareVersion is cast to [version]`$SoftwareVersion! EXITING!" 
  }
  #([type]"Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.ConstantValue").GetConstructors() | ForEach {($_.GetParameters() | ForEach {$_.ToString()}) -Join ", "} 
	
	
  if ($FullVersionDetection)
  {
    $valueList = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.ConstantValue -ArgumentList ('{0}.{1}.{2}.{3}' -f $valueVersioning.Major, $valueVersioning.Minor, $valueVersioning.Build, $valueVersioning.Revision), $valueDataType
  }
	
  else
  {
    if ($MinVersionDetection)
    {
      $valueConstantHigh = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.ConstantValue -ArgumentList ('{0}.{1}.{2}.{3}' -f $valueVersioning.Major, $valueVersioning.Minor, '99999', '999999'), $valueDataType
      $valueConstantLow = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.ConstantValue -ArgumentList ('{0}.{1}.{2}.{3}' -f $valueVersioning.Major, $valueVersioning.Minor, '0', '0'), $valueDataType
    }
    else
    {
      $valueConstantHigh = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.ConstantValue -ArgumentList ('{0}.{1}.{2}.{3}' -f $valueVersioning.Major, $valueVersioning.Minor, $valueVersioning.Build, '999999'), $valueDataType
      $valueConstantLow = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.ConstantValue -ArgumentList ('{0}.{1}.{2}.{3}' -f $valueVersioning.Major, $valueVersioning.Minor, $valueVersioning.Build, '0'), $valueDataType
    }
    $valueConstantList = New-Object -TypeName "Microsoft.ConfigurationManagement.DesiredConfigurationManagement.CustomCollection``1[[Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.ConstantValue]]"
    $valueConstantList.Add($valueConstantLow)
    $valueConstantList.Add($valueConstantHigh)
		
    # ([type]"Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.ConstantValueList").GetConstructors() | ForEach {($_.GetParameters() | ForEach {$_.ToString()}) -Join ", "} 
    $valueList = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.ConstantValueList -ArgumentList $valueConstantList, $valueListDataType
  }
	
	
  # Create the expression and add in the settings and values created above
  $operands = New-Object -TypeName "Microsoft.ConfigurationManagement.DesiredConfigurationManagement.CustomCollection``1[Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.ExpressionBase]"
  $operands.Add($settingReference)
  $operands.Add($valueList)
	
  if ($FullVersionDetection)
  {
    $expressionOperator = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ExpressionOperators.ExpressionOperator]::IsEquals
  }
  else
  {
    $expressionOperator = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ExpressionOperators.ExpressionOperator]::Between
  }
  # ([type]"Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.Expression").GetConstructors() | ForEach {($_.GetParameters() | ForEach {$_.ToString()}) -Join ", "} 
  $expression = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.Expression -ArgumentList $expressionOperator, $operands
	
  $noncomplianceSeverity = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.NoncomplianceSeverity]::Informational
	
  # ([type]"Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Annotatio").GetConstructors() | ForEach {($_.GetParameters() | ForEach {$_.ToString()}) -Join ", "} 
  $annotation = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Annotation
	
  $ruleID = $DeploymentType.ModelName
	
  # ([type]"Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Rule").GetConstructors() | ForEach {($_.GetParameters() | ForEach {$_.ToString()}) -Join ", "} 
  # System.String id,
  # Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.NoncomplianceSeverity severity,
  # Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Annotation annotation,
  # Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.ExpressionBase ruleExpression
  $rule = New-Object -TypeName 'Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Rule' -ArgumentList (
    $ruleID, 
    $noncomplianceSeverity, 
    $annotation, 
  $expression)
	
  $enhancedDetectionMethod = New-Object -TypeName Microsoft.ConfigurationManagement.ApplicationManagement.EnhancedDetectionMethod
  $enhancedDetectionMethod.Settings.Add($file)
  $enhancedDetectionMethod.Rule = $rule
	
  # TODO Actually set the rule to the deployment
  if ($DeserialDeploymentType.DeploymentTypes.Count -gt 1)
  {
    for ($i = 0; $i -lt $DeserialDeploymentType.DeploymentTypes.Count; $i++)
    {
      if (($DeserialDeploymentType.DeploymentTypes.Item($i).Requirements.Name -like '*64-bit*') -and ($IsX64))
      {
        $DeserialDeploymentType.DeploymentTypes[$i].Installer.DetectionMethod = [Microsoft.ConfigurationManagement.ApplicationManagement.DetectionMethod]::Enhanced
        $DeserialDeploymentType.DeploymentTypes[$i].Installer.EnhancedDetectionMethod = $enhancedDetectionMethod
        $i = $DeserialDeploymentType.DeploymentTypes.Count
      }
      elseif (($DeserialDeploymentType.DeploymentTypes.Item($i).Requirements.Name -like '*32-bit*') -and ($IsX64 -eq $false))
      {
        $DeserialDeploymentType.DeploymentTypes[$i].Installer.DetectionMethod = [Microsoft.ConfigurationManagement.ApplicationManagement.DetectionMethod]::Enhanced
        $DeserialDeploymentType.DeploymentTypes[$i].Installer.EnhancedDetectionMethod = $enhancedDetectionMethod
        $i = $DeserialDeploymentType.DeploymentTypes.Count
      }
    }
  }
  else
  {
    $DeserialDeploymentType.DeploymentTypes[0].Installer.DetectionMethod = [Microsoft.ConfigurationManagement.ApplicationManagement.DetectionMethod]::Enhanced
    $DeserialDeploymentType.DeploymentTypes[0].Installer.EnhancedDetectionMethod = $enhancedDetectionMethod
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
