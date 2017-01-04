<# 
.SYNOPSIS 
    This PowerShell script is intended to be executed remotely to create one or more Azure Application Service Plans using an
	Azure AD credential with proper RBAC permissions to create such a group.  This PowerShell Script makes it easier
    to create one or more Azure Application Service Plans instead of using the Management Portal interactively.
.DESCRIPTION 
    This creates one or more Azure Application Service Plans in the form AzureRGEnvironmentName_Web AzureRGEnvironmentName_API
    where valid values for AzureRGEnvironmentName = "Development", "Test", "Stage", "Production", "Subscription" and valid AzureRGTenantName values are
	"Common" or a unique cases a specific tenant name like "StewardHealthcare" or "BlueMetal".

	Each of these string values, AzureRGEnvironmentName and AzureRGTenantName, must be paired equally or the script will fail and
	exit.
.NOTES 
    File Name  : Create-AzureRMAppServicePlan.ps1
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
    Optional   : This can be called from a .bat file as desired to create one or more App Service Plans.
			   : An example is included which demonstrates how to provide input for creating multiple App Service Plans with as
			   : a comma separated list.
               :
    Created    : 03/22/2016
	Updated	   : 03/23/2016 v1.0
	Updated    : 05/11/2016 v1.1 Changes to rename App Service Plans from _API / _Web to _Internal / _External respectively.
	
    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help ./Create-AzureRMAppServicePlan.ps1 [Null], [-Full], [-Detailed], [-Examples]

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
    Example: "Development,Test,Stage,Production"
.PARAMETER AzureRGTenantName
    Example: "Common,Common,Common,Common"
.EXAMPLE
    ./Create-AzureRmAppServicePlan.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGEnvironmentName "Development,Test,Stage,Production" -AzureRGTenantName "Common,Common,Common,Common" -Verbose
.EXAMPLE
    ./Create-AzureRmAppServicePlan.ps1 "AppSuite" "East US 2" "Development,Test,Stage,Production" "Common,Common,Common,Common" -Verbose
.EXAMPLE
    ./Create-AzureRmAppServicePlan.ps1 "AppSuite" "East US 2" "Development" "Common"
.INPUTS
    The [Subscription] parameter is the name of the Azure subscription.

    The [AzureRegion] parameter is the name of the Azure Region/Location.

    The [AzureRGEnvironmentName] parameter is the name of the Environment type of the Azure Resource Group to place the App Service Plan.

    The [AzureRGTenantName] parameter is the name of the Tenant name of the Azure Resource Group to place the App Service Plan.
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
    [Parameter(Mandatory=$True, Position=2, HelpMessage='The Environment type of the Azure Resource Group to place the App Service Plan.')]
    [String]$AzureRGEnvironmentName,
    [Parameter(Mandatory=$True, Position=3, HelpMessage='The Tenant name of the Azure Resource Group to place the App Service Plan.')]
    [String]$AzureRGTenantName
    )

#region Variables
<#

Sample variables for bypassing the script parameters for testing.

[string]$Subscription = "AppSuite"
[string]$AzureRegion = "East US 2"
[string]$AzureRGEnvironmentName = "Development,Test,Stage,Production"
[string]$AzureRGTenantName = "Common,Common,Common,Common"

[string]$AzureRGEnvironmentName = "Development"
[string]$AzureRGTenantName = "Common"


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
        $CheckASPWeb = Get-AzureRmAppServicePlan -ResourceGroupName $($Environments[$Count] + "_" + $Tenants[$Count]) -Name $($Environments[$Count] + "_" + "External") -ErrorAction SilentlyContinue
        $CheckASPApi = Get-AzureRmAppServicePlan -ResourceGroupName $($Environments[$Count] + "_" + $Tenants[$Count]) -Name $($Environments[$Count] + "_" + "Internal") -ErrorAction SilentlyContinue

        If ([string]::IsNullOrEmpty($CheckASPWeb))
        {

            # Console output with -Verbose only
            Write-Verbose -Message "[Start] Attempting to create Azure App Service Plan: $($Environments[$Count] + "_" + "External")."
            Write-Verbose -Message ""

    
            New-AzureRmAppServicePlan -ResourceGroupName ($Environments[$Count] + '_' + $Tenants[$Count]) -Name $($Environments[$Count] + "_" + "External") -Location $AzureRegion -Tier Basic -NumberofWorkers 2 -WorkerSize "Medium"

            # Set the App Service Plan Tags as best we can since Microsoft doesn't have proper support in PowerShell currently.
            $ResourceProperties = (Get-AzureRMResource -ResourceName $($Environments[$Count] + "_" + "External") -ResourceType Microsoft.Web/serverfarms -ResourceGroupName ($Environments[$Count] + '_' + $Tenants[$Count])).Properties
            $ResourceProperties.Tags

            # Hashtable Method
            # $P.Tags += @{Name="Environment";Value="Development"},@{Name="Tenant";Value="Common"}

            # Dictionary Method
            $ResourceProperties.Tags += @{Environment="$($Environments[$Count])";Tenant="$($Tenants[$Count])"}

            Set-AzureRMResource -ResourceName $($Environments[$Count] + "_" + "External") -ResourceType Microsoft.Web/serverfarms -ResourceGroupName ($Environments[$Count] + '_' + $Tenants[$Count]) -Properties $ResourceProperties -Force

            (Get-AzureRMResource -ResourceName $($Environments[$Count] + "_" + "External") -ResourceType Microsoft.Web/serverfarms -ResourceGroupName ($Environments[$Count] + '_' + $Tenants[$Count])).Properties.Tags

            # Console output with -Verbose only
            Write-Verbose -Message "[Finish] Created Azure App Service Plan: $($Environments[$Count] + "_" + "External")."
            Write-Verbose -Message ""

        }
        Else
        {

            # Console output with -Verbose only
            Write-Verbose -Message "[Error:$PSScriptName] Attempt to create Azure App Service Plan: $($Environments[$Count] + "_" + "External") failed.  Duplicate name."
            Write-Verbose -Message ""

        } # Else



        If ([string]::IsNullOrEmpty($CheckASPApi))
        {

            # Console output with -Verbose only
            Write-Verbose -Message "[Start] Attempting to create Azure App Service Plan: $($Environments[$Count] + "_" + "Internal")."
            Write-Verbose -Message ""

            New-AzureRmAppServicePlan -ResourceGroupName $($Environments[$Count] + '_' + $Tenants[$Count]) -Name $($Environments[$Count] + "_" + "Internal") -Location $AzureRegion -Tier Basic -NumberofWorkers 2 -WorkerSize "Medium"

            # Set the App Service Plan Tags as best we can since Microsoft doesn't have proper support in PowerShell currently.
            $ResourceProperties = (Get-AzureRMResource -ResourceName $($Environments[$Count] + "_" + "Internal") -ResourceType Microsoft.Web/serverfarms -ResourceGroupName ($Environments[$Count] + '_' + $Tenants[$Count])).Properties
            $ResourceProperties.Tags

            # Hashtable Method
            # $P.Tags += @{Name="Environment";Value="Development"},@{Name="Tenant";Value="Common"}

            # Dictionary Method
            $ResourceProperties.Tags += @{Environment="$($Environments[$Count])";Tenant="$($Tenants[$Count])"}

            Set-AzureRMResource -ResourceName $($Environments[$Count] + "_" + "Internal") -ResourceType Microsoft.Web/serverfarms -ResourceGroupName ($Environments[$Count] + '_' + $Tenants[$Count]) -Properties $ResourceProperties -Force

            (Get-AzureRMResource -ResourceName $($Environments[$Count] + "_" + "Internal") -ResourceType Microsoft.Web/serverfarms -ResourceGroupName ($Environments[$Count] + '_' + $Tenants[$Count])).Properties.Tags

            # Console output with -Verbose only
            Write-Verbose -Message "[Finish] Created Azure App Service Plan: $($Environments[$Count] + "_" + "Internal")."
            Write-Verbose -Message ""

        }
        Else
        {

            # Console output with -Verbose only
            Write-Verbose -Message "[Error:$PSScriptName] Attempt to create Azure App Service Plan: $($Environments[$Count] + "_" + "Internal") failed.  Duplicate name."
            Write-Verbose -Message ""

        } # Else

        $Count++
        $CheckASPWeb = $null
        $CheckASPApi = $null

    } # End While
}
Else
{
		# Console output with -Verbose only
		Write-Verbose -Message "[Error:$PSScriptName] Attempt to validate AzureRGEnvironmentName/AzureRGTenantName 1:1 pairing of parameters failed."
        Write-Verbose -Message ""

        # This is such a catastrophic error we have to abandon further execution.
        Exit
}


# Mark the finish time.
$FinishTime = Get-Date
Write-Verbose -Message "Finish Time ($($FinishTime.ToLocalTime()))."

# Console output with -Verbose only
$TotalTime = ($FinishTime - $StartTime).Seconds
Write-Verbose -Message "Elapse Time (Seconds): $TotalTime"
Write-Verbose -Message ""


#endregion Main