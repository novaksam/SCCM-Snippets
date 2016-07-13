#requires -Version 2
# http://www.laurierhodes.info/?q=node/91
function Get-32And64BitRequirementRule
{
  [CmdletBinding()]
  [OutputType([Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Rule])]
  param ()
	
  $oOperands = New-Object -TypeName "Microsoft.ConfigurationManagement.DesiredConfigurationManagement.CustomCollection``1[[Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.RuleExpression]]"
  $oOperands.Add('Windows/All_x86_Windows_7_Client')
  $oOperands.Add('Windows/All_x86_Windows_10_and_higher_Clients')
  $oOperands.Add('Windows/All_x64_Windows_7_Client')
  $oOperands.Add('Windows/All_x64_Windows_10_and_higher_Clients')
  $oOperator = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ExpressionOperators.ExpressionOperator]::OneOf
	
  $oOSExpression = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.OperatingSystemExpression `
  -ArgumentList $oOperator, $oOperands
	
  $oAnnotation = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Annotation
	
  $oAnnotation.DisplayName = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.LocalizableString `
  -ArgumentList 'DisplayName', 'Operating system One of {All Windows 7 (64-bit), All Windows 7 (32-bit), All Windows 10 (32-bit)}', $null
	
  $oNoncomplianceSeverity = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.NoncomplianceSeverity]::None
	
  $oDTRule = New-Object -TypeName 'Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Rule' -ArgumentList (
    ('Rule_' + [Guid]::NewGuid().ToString()), 
    $oNoncomplianceSeverity, 
    $oAnnotation, 
  $oOSExpression)
  return $oDTRule
}

function Get-32BitRequirementRule
{
  [CmdletBinding()]
  [OutputType([Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Rule])]
  param ()
	
  $oOperands = New-Object -TypeName "Microsoft.ConfigurationManagement.DesiredConfigurationManagement.CustomCollection``1[[Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.RuleExpression]]"	
  $oOperands.Add('Windows/All_x86_Windows_7_Client')
  $oOperands.Add('Windows/All_x86_Windows_10_and_higher_Clients')
  $oOperator = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ExpressionOperators.ExpressionOperator]::OneOf
	
  $oOSExpression = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.OperatingSystemExpression `
  -ArgumentList $oOperator, $oOperands
	
  $oAnnotation = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Annotation
	
  $oAnnotation.DisplayName = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.LocalizableString `
  -ArgumentList 'DisplayName', 'Operating system One of {All Windows 7 (32-bit), All Windows 10 (32-bit)}', $null
	
  $oNoncomplianceSeverity = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.NoncomplianceSeverity]::None
	
  $oDTRule = New-Object -TypeName 'Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Rule' -ArgumentList (
    ('Rule_' + [Guid]::NewGuid().ToString()), 
    $oNoncomplianceSeverity, 
    $oAnnotation, 
  $oOSExpression)
  return $oDTRule
}

function Get-64BitRequirementRule
{
  [CmdletBinding()]
  [OutputType([Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Rule])]
  param ()
	
  $oOperands = New-Object -TypeName "Microsoft.ConfigurationManagement.DesiredConfigurationManagement.CustomCollection``1[[Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.RuleExpression]]"
  $oOperands.Add('Windows/All_x64_Windows_7_Client')
  $oOperands.Add('Windows/All_x64_Windows_10_and_higher_Clients')
  $oOperator = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ExpressionOperators.ExpressionOperator]::OneOf
	
  $oOSExpression = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.OperatingSystemExpression `
  -ArgumentList $oOperator, $oOperands
	
  $oAnnotation = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Annotation
	
  $oAnnotation.DisplayName = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.LocalizableString `
  -ArgumentList 'DisplayName', 'Operating system One of {All Windows 7 (64-bit), All Windows 10 (64-bit)}', $null
	
  $oNoncomplianceSeverity = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.NoncomplianceSeverity]::None
	
  $oDTRule = New-Object -TypeName 'Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Rule' -ArgumentList (
    ('Rule_' + [Guid]::NewGuid().ToString()), 
    $oNoncomplianceSeverity, 
    $oAnnotation, 
  $oOSExpression)
  return $oDTRule
}
