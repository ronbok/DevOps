<# 
.SYNOPSIS 
    This PowerShell script is intended to be executed remotely to create a new Azure Resource Manager Group using an
	Azure AD credential with proper RBAC permissions to create such a group.  This PowerShell Script makes it easier
    to create an Azure Resource Manager Group instead of using the Management Portal interactively.
.DESCRIPTION 
    This creates one or more Resource Group(s) in the form AzureRGEnvironmentName_AzureRGTenantName where valid values for
	AzureRGEnvironmentName = "Development", "Test", "Stage", "Production", "Subscription" and valid AzureRGTenantName values are
	"Development", "Test", "Stage", "Shared", "Common" or a specific tenant name like "StewardHealthcare" or "BlueMetal".

    Additionally, Resource Group tags are created/assigned for "Environment" and "Tenant" with the same values defined for
	AzureRGEnvironmentName and AzureRGTenantName for each Resource Group created.

    If a Development environment resource group for just development use is desired, specifiy "Development" for
	AzureRGEnvironmentName (Environment type) and "Development" for AzureRGTenantName (Tenant).

    If a real Production environment for a specific Saas tenant is desired, specify "Production" for the AzureRGEnvironmentName
	(Environment type) and "TenantName" for AzureRGTenantName (Tenant).

	Each of these string values, AzureRGEnvironmentName and AzureRGTenantName, must be paired equally or the script will fail and
	exit.
.NOTES 
    File Name  : Create-AzureRMResourceGroup.ps1
               :
    Author     : Ron Bokleman - ron.bokleman@bluemetal.com
               :
    Requires   : PowerShell V5 or above, PowerShell / ISE Elevated, Microsoft Azure PowerShell v1.2.1 February 2016
			   : from the Web Platform Installer.
               :
    Requires   : Azure Subscription needs to be setup in advance and you must know the name.
			   : The executor will be prompted for valid OrgID/MicrosoftID credentials.
               : User must have sufficient privledges to create a new Resource Group within the specified subscription.
               :
    Optional   : This can be called from a .bat file as desired to create one or more Azure Resource Groups.
			   : An example is included which demonstrates how to provide input for creating multiple Resource Groups with as
			   : a comma separated list.
               :
    Created    : 03/08/2016
	Updated	   : 03/11/2016 v1.0
	Updated    : 03/18/2016 v1.1 includes Resouce Group Tags.  Includes a new function for checking whether the executor is
			   : running PowerShell from the commandline or from the ISE.
			   : 03/23/2016 v1.2 Discovered a variable name spelling issue.
	
    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help ./Create-AzureRMResourceGroup.ps1 [Null], [-Full], [-Detailed], [-Examples]

.LINK
    Additional Information:
    
    https://msdn.microsoft.com/en-us/library/mt125356.aspx
    
    Connect with Me: 
    
    http://ronbokleman.wordpress.com
    http://www.linkedin.com/pub/ron-bokleman/1/14b/200

.PARAMETER Subscription
    Example:  Subcription Name i.e. "AppSuite"
.PARAMETER AzureLocation
    Example:  "East US 2"
.PARAMETER AzureRGEnvironmentName
    Example: "Development,Development,Test,Test,Stage,Stage,Production,Production,Production,Subscription"
.PARAMETER AzureRGTenantName
    Example: "Development,Common,Test,Common,Stage,Common,StewardHealthcare,BlueMetal,Common,Common"
.EXAMPLE
    ./Create-AzureRMResourceGroup.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGEnvironmentName "Development,Development,Test,Test,Stage,Stage,Production,Production,Production,Subscription" -AzureRGTenantName "Development,Common,Test,Common,Stage,Common,StewardHealthcare,BlueMetal,Common,Common" -Verbose
.EXAMPLE
    ./Create-AzureRMResourceGroup.ps1 "AppSuite" "East US 2" -AzureRGEnvironmentName "Development,Development,Test,Test,Stage,Stage,Production,Production,Production,Subscription" "Development,Common,Test,Common,Stage,Common,StewardHealthcare,BlueMetal,Common,Common" -Verbose
.EXAMPLE
    ./Create-AzureRMResourceGroup.ps1 "AppSuite" "East US 2" "Development,Development" "Development,Common"
.INPUTS
    The [Subscription] parameter is the name of the Azure subscription.

    The [AzureRegion] parameter is the name of the Azure Region/Location to host the Resource Group(s) for this subscription.

    The [AzureRGEnvironmentName] parameter is the name of the Environment type of the Azure Resource Group to create/update.

    The [AzureRGTenantName] parameter is the name of the Tenant name of the Azure Resource Group to create/update.
.OUTPUTS
    Normal Verbose/Debug output included with -Verbose or -Debug parameters.
#>

#Requires -RunAsAdministrator
#Requires -Version 5.0

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The name of the Azure Subscription to which access has been granted.")]
    [string]$Subscription,
    [Parameter(Mandatory=$True, Position=1, HelpMessage="The name of destination Azure Region.")]
    [ValidatePattern({^[a-zA-Z0-9]})]
    [string]$AzureRegion,
    [Parameter(Mandatory=$True, Position=2, HelpMessage='The Environment type of the Azure Resource Group to create/update.')]
    [string]$AzureRGEnvironmentName,
    [Parameter(Mandatory=$True, Position=3, HelpMessage='The Tenant name of the Azure Resource Group to create/update.')]
    [string]$AzureRGTenantName
	)

#region Variables
<#

Sample variables for bypassing the script parameters for testing.

[string]$Subscription = "AppSuite"
[string]$AzureRegion = "East US 2"
[string]$AzureRGEnvironmentName = "Development,Development"
[string]$AzureRGTenantName = "Development,Common"

#>
#endregion Variables


#region Functions



#region CheckPowerShell()

Function CheckPowerShell()
{

    # Check if we're running in the PowerShell ISE or PowerShell Console.
    If ($Host.Name -like "*ISE*")
    {
        [bool]$ISE = $True
        # Console output with -Verbose only
        Write-Verbose -Message "[Information] Running in PowerShell ISE."
        Write-Verbose -Message ""

        # Get the executing PowerShell script name for inclusion in Write-Verbose messages.
        [string]$PSScriptName = $psISE.CurrentFile.DisplayName.Trim(".ps1*")
        
    }

    Else # Executing from the PowerShell Console instead of the PowerShell ISE.
    
    {
        [bool]$ISE = $False
        # Console output with -Verbose only
        Write-Verbose -Message "[Information] Running in PowerShell Console."
        Write-Verbose -Message ""

        # Get the executing PowerShell script name for inclusion in Write-Verbose messages.
        [string]$PSScriptName = Split-Path $MyInvocation.PSCommandPath -Leaf
        
    }

    Return [bool]$ISE, [string]$PSScriptName

} # End CheckPowerShell()

#endregion CheckPowerShell()



#region Login-AzureRMInteractive()

Function Login-AzureRMInteractive()
{
    Param ([String]$Subscription)

    Try
    {
        # Console output with -Verbose only
        Write-Verbose -Message "[Start] Login required to retrieve Azure AD user context."
        Write-Verbose -Message ""

        $AzureRMContext = Login-AzureRmAccount

        # Console output with -Verbose only
        Write-Verbose -Message "[Finish] Azure AD user context $($AzureRMContext.Context.Account.Id) retrieved."
        Write-Verbose -Message ""

    } # End Try

    Catch
    
    {
        # Console output with -Verbose only
        Write-Verbose -Message $Error[0].Exception.Message
        Write-Verbose -Message ""

	    Write-Verbose -Message "[Error] Attempt to get ARM Context for subscription: $Subscription failed."
        Write-Verbose -Message ""

	    # Console output with -Debug only
	    Write-Debug -Message $Error[0].Exception.Message
        Write-Debug -Message ""

	    # Clear $Error, if one occured
        $Error.Clear()

    } # End Catch

    Return $AzureRMContext

} # End Function Login-AzureRMInteractive()

#endregion Login-AzureRMInteractive()



#region Select-Subscription()

Function Select-Subscription()
{

    Param ([String]$Subscription)

    Try
    {
        # Ensure that $Error is clear before we begin
        $Error.Clear()

	    # Console output with -Verbose only
        Write-Verbose -Message "[Start] Attempting to select Azure subscription: $Subscription."
        Write-Verbose -Message ""

        # Select the Azure Subscription...
        $SubcriptionContext = Set-AzureRmContext -SubscriptionName $Subscription -ErrorAction Stop

        # Console output with -Verbose only
        Write-Verbose -Message "[Finish] Currently selected Azure subscription is: $Subscription."
        Write-Verbose -Message ""

        Return $SubcriptionContext

    } # End Try

    Catch
    
    {
        # Console output with -Verbose only
        Write-Verbose -Message $Error[0].Exception.Message
        Write-Verbose -Message ""

		Write-Verbose -Message "[Error:$PSScriptName] Attempt to select Azure subscription: $Subscription failed."
        Write-Verbose -Message ""

		# Console output with -Debug only
		Write-Debug -Message $Error[0].Exception.Message
        Write-Debug -Message ""

		# Clear $Error, if one occured
        $Error.Clear()

        # This is such a catastrophic error we have to abandon further execution.
        Exit

    } # End Catch

} # End Select-Subscription()

#endregion Select-Subscription()



#region Create-ResourceGroup()

Function Create-ResourceGroup
{
    Param([String]$Name, [String]$Region, [string]$Environment, [string]$Tenant)

	# Console output with -Verbose only
    Write-Verbose -Message "[Start] Attempting to create new Resource Group $Name."
    Write-Verbose -Message ""

    Try
    {
		# Ensure that $Error is clear before we begin
        $Error.Clear()

		# https://github.com/Azure/azure-powershell/issues/906
		# https://social.msdn.microsoft.com/Forums/en-US/cf5f7777-e5f2-4423-bdcd-db4b611e1be6/different-behavior-on-getazureresource-it-started-to-throw-resourcenotfound-exception-from-v091?forum=azurescripting
		# If (!(Test-AzureResourceGroup -ResourceGroupName $Name))
		#{
			# Azure Resource Group does not exist, so let's attempt to create it.
			$ResourceGroupName = New-AzureRMResourceGroup -Name $Name -Location $Region -Tag @{Name="Environment";Value=$Environment}, @{Name="Tenant";Value=$Tenant} -ErrorAction Stop -Force
	
		#}
		#Else
		#{
			# Azure Resource Group already exists, so lets just return it.
			# $ResourceGroupName = Get-AzureRMResourceGroup -Name $Name
		#}
    }
    Catch
    {
		# Console output with -Verbose only
        Write-Verbose -Message $Error[0].Exception.Message
        Write-Verbose -Message "[Error] Exiting due to exception: Resource Group not created."

		# Ensure that $Error is clear after we quit
        $Error.Clear()

    } # End Try/Catch

	# Console output with -Verbose only
    Write-Verbose -Message "[Finish] Created new Resource Group $Name."
    Write-Verbose -Message ""

	# Return $ResourceGroupName.ResourceGroupName
    Return $ResourceGroupName

} # End Function Create-ResourceGroup()

#endregion Create-ResourceGroup()



#endregion Functions



#region Main

# Mark the start time.
$StartTime = Get-Date
Write-Verbose -Message "Start Time ($($StartTime.ToLocalTime()))."

# What version of Microsoft Azure PowerShell are we running?
# Console output with -Debug only
Write-Debug -Message (Get-Module azure -ListAvailable).Version
Write-Debug -Message ""

Clear-Host

# Provide credentials to sign into Azure and retrieve authorized subscriptions.
$LoginContext = Login-AzureRMInteractive -Subscription $Subscription

# Set default values for PowerShell script...
[string]$PSScriptName = $null
$SubscriptionContext = $null

# Call Function
$Return = CheckPowerShell
$ISE = $Return[0]
$PSScriptName = $Return[1]

# Console output with -Verbose only
Write-Verbose -Message $ISE
Write-Verbose -Message $PSScriptName.Trim(".ps1*")
Write-Verbose -Message ""

# Call Function
$SubscriptionContext = Select-Subscription -Subscription $Subscription

If ($SubscriptionContext -ne $null)

{
    # Check to see if our $Subscription was found and selected.
    Get-AzureRmContext

    # Console output with -Verbose only
    Write-Verbose -Message $SubscriptionContext.Subscription.SubscriptionName
    Write-Verbose -Message ""

}

[string[]]$Environments = $AzureRGEnvironmentName.Split(",")
[string[]]$Tenants = $AzureRGTenantName.Split(",")

# Because we accept an array of both Environments and Tenants as parameters, loop through them to create each specified.
$Count = 0

If ($Environments.Count -eq $Tenants.Count)
{
    While ($Count -le $Environments.Count-1)
    {    
        # Call Function
        $RG = Create-ResourceGroup -Name ($Environments[$Count] + '_' + $Tenants[$Count]) -Region $AzureRegion -Environment $Environments[$Count] -Tenant $Tenants[$Count]
        $Count++
    }
}
Else
{
		# Console output with -Verbose only
		Write-Verbose -Message "[Error:$PSScriptName] Attempt to validate Environmnet/Tenant 1:1 pairing of parameters failed."
        Write-Verbose -Message ""

        # This is such a catastrophic error we have to abandon further execution.
        Exit
}

# Mark the finish time.
$FinishTime = Get-Date
Write-Verbose -Message "Finish Time ($($FinishTime.ToLocalTime()))."

# Console output with -Verbose only
$TotalTime = $($FinishTime - $StartTime).Seconds
Write-Verbose -Message "Elapse Time (Seconds): $TotalTime"
Write-Verbose -Message ""


#endregion Main