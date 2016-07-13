#requires -Version 3
<#
    .SYNOPSIS
    Set the supersedence for the application
	
    .DESCRIPTION
    A detailed description of the Set-Supersedence function.
	
    .PARAMETER DeploymentTypeName
    The name of the deployment type for this particular piece of software. Defaults to "Install$SoftwareName.cmd"
	
    .PARAMETER SoftwareTitle
    The title of the software that'll show up in SCCM and in software center.
	
    .PARAMETER SoftwareVersion
    The version of the software
	
    .PARAMETER SoftwareName
    The short name of the software, used for spaceless names, so directories don't contain spaces
	
    .PARAMETER IsX64
    If the software is X64 bit only
	
    .PARAMETER SCCMConfig
    The SCCMConfig parameter
	
    .PARAMETER SoftwareAltName
    An alternate name for the software, to be used in a SELECT LIKE query
	
    .PARAMETER UninstallSuperseded
    Whether or not to uninstall the superseded software.
	
    .NOTES
    ===========================================================================
    Created on:   	7/13/2016 12:18 PM
    Created by:   	Sam Novak
    Organization: 	
    Filename: Set-Supersedence.ps1
    ===========================================================================
#>
function Set-Supersedence
{
  [CmdletBinding()]
  param
  (
    [string]$DeploymentTypeName,
    [String]$SoftwareTitle = '',
    [String]$SoftwareVersion = '',
    [String]$SoftwareName = '',
    [boolean]$IsX64 = $false,
    [PSObject]$SCCMConfig,
    [String]$SoftwareAltName,
    [boolean]$UninstallSuperseded = $true
  )
	
  Write-Host 'Setting supersedence'
  #if ($IsX64 -ne $true) { $IsX64 = $false }
	
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
	
  # Enumerate previous applications
  if (($SoftwareAltName -ne '') -and ($SoftwareAltName -ne $null))
  {
    $WMIObjs = (Get-WmiObject -Query "SELECT * FROM SMS_Application WHERE LocalizedDisplayName LIKE '$SoftwareAltName%' AND SoftwareVersion!='$SoftwareVersion' AND IsLatest = 'TRUE' AND NumberOfDeployments >= 1") 
  }
	
	
  if (($WMIObjs.count -eq 0) -or ($WMIObjs -eq $null))
  {
    $WMIObjs = (Get-WmiObject -Query "SELECT * FROM SMS_Application WHERE LocalizedDisplayName LIKE '$SoftwareTitle%' AND SoftwareVersion!='$SoftwareVersion' AND IsLatest = 'TRUE' AND NumberOfDeployments >= 1") 
  }
	
  if (($WMIObjs -ne $null) -and (($WMIObjs.count -ge 1) -or ($WMIObjs.__PROPERTY_COUNT -gt 1)))
  {
    [wmi]$supersededapplication
		
    ForEach ($item in $WMIObjs)
    {
      $temp = [wmi]$item.__PATH
      if (($temp.IsSuperseded -eq $false) -and ($temp.IsSuperseding -eq $true))
      {
        $supersededapplication = $temp
      }
    }
		
    if (($supersededapplication -eq $null) -and ($temp.IsSuperseded -eq $true) -and ($temp.IsSuperseding -eq $true))
    {
      $supersededapplication = $temp
    }
    elseif (($supersededapplication -eq $null) -and ($temp -ne $null))
    {
      $supersededapplication = $temp
    }
		
    #deserialize the XML
    $supersededDeserializedstuff = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::DeserializeFromString($supersededapplication.SDMPackageXML)
		
    # Because we do multiple deployments per application, we need to do the supersedence for a specific deploymenttype
    # if we didn't do a specific one, then it'd try to run against an object[] which would fail
    if ($supersededDeserializedstuff.DeploymentTypes.Count -gt 1)
    {
      for ($i = 0; $i -lt $supersededDeserializedstuff.DeploymentTypes.Count; $i++)
      {
        if (($supersededDeserializedstuff.DeploymentTypes.Item($i).Requirements.Name -like '*64-bit*') -and ($IsX64))
        {
          $deployTypes = $supersededDeserializedstuff.DeploymentTypes.Item($i)
          $i = $supersededDeserializedstuff.DeploymentTypes.Count
        }
        elseif (($supersededDeserializedstuff.DeploymentTypes.Item($i).Requirements.Name -like '*32-bit*') -and ($IsX64 -eq $false))
        {
          $deployTypes = $supersededDeserializedstuff.DeploymentTypes.Item($i)
          $i = $supersededDeserializedstuff.DeploymentTypes.Count
        }
        elseif (($supersededDeserializedstuff.DeploymentTypes.Item($i).Title -like '*Debug*') -and ($SoftwareName -like '*Debug*'))
        {
          $deployTypes = $supersededDeserializedstuff.DeploymentTypes.Item($i)
          $i = $supersededDeserializedstuff.DeploymentTypes.Count
        }
        elseif ($supersededDeserializedstuff.DeploymentTypes.Item($i).Title -eq $DeploymentTypeName)
        {
          $deployTypes = $supersededDeserializedstuff.DeploymentTypes.Item($i)
          $i = $supersededDeserializedstuff.DeploymentTypes.Count
        }
        elseif ($supersededDeserializedstuff.DeploymentTypes.Item($i).Title -eq $SoftwareName)
        {
          $deployTypes = $supersededDeserializedstuff.DeploymentTypes.Item($i)
          $i = $supersededDeserializedstuff.DeploymentTypes.Count
        }
      }
      # For those applications with goofy deployment names
      # Here's lookin' at you Flash
      if ($deployTypes -eq $null)
      {
        for ($i = 0; $i -lt $supersededDeserializedstuff.DeploymentTypes.Count; $i++)
        {
          if ($supersededDeserializedstuff.DeploymentTypes.Item($i).Title -notlike '*Debug*')
          {
            $deployTypes = $supersededDeserializedstuff.DeploymentTypes.Item($i)
            $i = $supersededDeserializedstuff.DeploymentTypes.Count
          }
        }
      }
    }
    else
    {
      $deployTypes = $supersededDeserializedstuff.DeploymentTypes.Item(0)
    }
		
    # set the Desired State for the Superseded Application's Deployment type to "prohibit" from running
    $DTDesiredState = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DeploymentTypeDesiredState]::Prohibited
		
    #Store the arguments before hand
    [System.String]$ApplicationAuthoringScopeId = ($supersededapplication.CI_UniqueID -split '/')[0]
    [System.String]$ApplicationLogicalName = ($supersededapplication.CI_UniqueID -split '/')[1]
    [System.Int32]$ApplicationVersion = $supersededapplication.SourceCIVersion
    [System.String]$DeploymentTypeAuthoringScopeId = $deployTypes.scope
    [System.String]$DeploymentTypeLogicalName = $deployTypes.name
    [System.Int32]$DeploymentTypeVersion = $deployTypes.Version
    #$DeploymentTypeAuthoringScopeId = $supersededDeserializedstuff.DeploymentTypes.scope
    #$DeploymentTypeLogicalName = $supersededDeserializedstuff.DeploymentTypes.name
    #$DeploymentTypeVersion = $supersededDeserializedstuff.DeploymentTypes.Version
    [System.Boolean]$uninstall = $UninstallSuperseded #this determines if the superseded Application needs to be uninstalled when the new Application is pushed
		
    #create the intent expression
    $intentExpression = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DeploymentTypeIntentExpression -ArgumentList $ApplicationAuthoringScopeId, $ApplicationLogicalName, $ApplicationVersion, $DeploymentTypeAuthoringScopeId, $DeploymentTypeLogicalName, $DeploymentTypeVersion, $DTDesiredState, $uninstall
		
    # Create the Severity None
    $severity = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.NoncomplianceSeverity]::None
		
    # Create the Empty Rule Context
    $RuleContext = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.RuleScope
		
		
    #Create the new DeploymentType Rule
    $DTRUle = New-Object -TypeName Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.DeploymentTypeRule -ArgumentList $severity, $null, $intentExpression
		
    $application = [wmi](Get-WmiObject -Query "select * from sms_application where LocalizedDisplayName LIKE '$SoftwareTitle%' AND SoftwareVersion='$SoftwareVersion' AND IsLatest = 'TRUE'").__PATH
		
    #$DTRUle.Name = "$($supersededapplication.LocalizedDisplayName) superseded by $($application.LocalizedDisplayName)"
		
    #Deserialize the SDMPackageXML
    $Deserializedstuff = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::DeserializeFromString($application.SDMPackageXML)
		
    #add the supersedence to the deployment type
		
    if ($Deserializedstuff.DeploymentTypes.Count -gt 1)
    {
      for ($i = 0; $i -lt $Deserializedstuff.DeploymentTypes.Count; $i++)
      {
        if (($Deserializedstuff.DeploymentTypes.Item($i).Requirements.Name -like '*64-bit*') -and ($IsX64))
        {
          $Deserializedstuff.DeploymentTypes[$i].Supersedes.Add($DTRUle)
          $i = $Deserializedstuff.DeploymentTypes.Count
        }
        elseif (($Deserializedstuff.DeploymentTypes.Item($i).Requirements.Name -like '*32-bit*') -and ($IsX64 -eq $false))
        {
          $Deserializedstuff.DeploymentTypes[$i].Supersedes.Add($DTRUle)
          $i = $Deserializedstuff.DeploymentTypes.Count
        }
        elseif (($Deserializedstuff.DeploymentTypes.Item($i).Title -like '*Debug*') -and ($SoftwareName -like '*Debug*'))
        {
          $Deserializedstuff.DeploymentTypes[$i].Supersedes.Add($DTRUle)
          $i = $Deserializedstuff.DeploymentTypes.Count
        }
        elseif ($Deserializedstuff.DeploymentTypes.Item($i).Title -eq $DeploymentTypeName)
        {
          $Deserializedstuff.DeploymentTypes[$i].Supersedes.Add($DTRUle)
          $i = $Deserializedstuff.DeploymentTypes.Count
        }
        elseif ($Deserializedstuff.DeploymentTypes.Item($i).Title -eq $SoftwareName)
        {
          $Deserializedstuff.DeploymentTypes[$i].Supersedes.Add($DTRUle)
          $i = $Deserializedstuff.DeploymentTypes.Count
        }
      }
    }
    else
    {
      $Deserializedstuff.DeploymentTypes[0].Supersedes.Add($DTRUle)
    }
    #$Deserializedstuff.DeploymentTypes[0].Supersedes.Add($DTRUle)
		
    # Serialize the XML
    $newappxml = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::Serialize($Deserializedstuff, $false)
		
    #set the property back on the local copy of the Object
    $application.SDMPackageXML = $newappxml
		
    #Now time to set the changes back to the ConfigMgr
    $application.Put() > $null
  }
}
