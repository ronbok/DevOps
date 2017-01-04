<# 
.SYNOPSIS 
    This PowerShell script is intended to be executed remotely to delete one or more existing Azure Resource Manager Groups using an
	Azure AD credential with proper RBAC permissions to delete such a group.  This PowerShell Script makes it easier
    to create an Azure Resource Manager Group instead of using the Management Portal interactively.
.DESCRIPTION 
    This deletes one or more Resource Group(s) in the form AzureRGEnvironmentName_AzureRGTenantName where valid values for
	AzureRGEnvironmentName = "Development", "Test", "Stage", "Production", "Subscription" and valid AzureRGTenantName values are
	"Development", "Test", "Stage", "Shared", "Common" or a specific tenant name like "StewardHealthcare" or "BlueMetal".

	Each of these string values, AzureRGEnvironmentName_AzureRGTenantName, must be paired equally or the script will fail and
	exit.
.NOTES 
    File Name  : Delete-AzureRMResourceGroup.ps1
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
			   : An example is included which demonstrates how to provide input for deleting multiple Resource Groups as
			   : a comma separated list.
               :
    Created    : 03/04/2016
	Updated	   : 03/18/2016 v1.0
	Updated    : MM/DD/2016 
	
    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help ./Delete-AzureRMResourceGroup.ps1 [Null], [-Full], [-Detailed], [-Examples]

.LINK
    Additional Information:
    
    https://msdn.microsoft.com/en-us/library/mt125356.aspx
    
    Connect with Me: 
    
    http://ronbokleman.wordpress.com
    http://www.linkedin.com/pub/ron-bokleman/1/14b/200

.PARAMETER Subscription
    Example:  Subcription Name i.e. "AppSuite"
.PARAMETER AzureRGName
    Example:  "Development_Development,Development_Shared"
.EXAMPLE
    ./Delete-AzureRMResourceGroup.ps1 -Subscription "AppSuite" -AzureRGName "Development_Development,Development_Common,Test_Test,Test_Common,Stage_Stage,Stage_Common,Production_Common,Production_StewardHealthcare,Production_BlueMetal,Subscription_Common" -Verbose
.EXAMPLE
    ./Delete-AzureRMResourceGroup.ps1 "AppSuite" "Development_Development,Development_Common,Test_Test,Test_Common,Stage_Stage,Stage_Common,Production_Common,Production_StewardHealthcare,Production_BlueMetal,Subscription_Common"
.EXAMPLE
    ./Delete-AzureRMResourceGroup.ps1 "AppSuite" "Development_Development,Development_Common,Test_Test,Test_Common"
.INPUTS
    The [Subscription] parameter is the name of the Azure subscription.

    The [AzureRGName] parameter is the name of the Azure Resource Group to delete.
.OUTPUTS
    Normal Verbose/Debug output included with -Verbose or -Debug parameters.
#>

#Requires -RunAsAdministrator
#Requires -Version 5.0

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The name of the Azure Subscription to which access has been granted.")]
    [string]$Subscription,
    [Parameter(Mandatory=$True, Position=1, HelpMessage="The name of Azure Resource Group to delete.")]
    [ValidatePattern({^[a-zA-Z0-9]})]
    [string]$AzureRGName
	)

#region Variables
<#

Sample variables for bypassing the script parameters for testing.

[string]$Subscription = "AppSuite"
[string]$AzureRGName = "Development_Development"

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



#region Delete-ResourceGroup()

Function Delete-ResourceGroup
{
    Param([String]$Name)

    Try
    {
		# Ensure that $Error is clear before we begin
        $Error.Clear()

  	    # Console output with -Verbose only
        Write-Verbose -Message "[Start] Attempting to delete Azure Resource Group: $Name."
        Write-Verbose -Message ""


        # Delete Resource Group by name
		Remove-AzureRMResourceGroup -Name $Name -ErrorAction Stop -Force
	
    }
    Catch
    {
		# Console output with -Verbose only
        Write-Verbose -Message $Error[0].Exception.Message
        Write-Verbose -Message "[Error] Exiting due to exception: Resource Group not deleted."

		# Ensure that $Error is clear after we quit
        $Error.Clear()

    } # End Try/Catch

	    # Console output with -Verbose only
        Write-Verbose -Message "[Finish] Deleted Azure Resource Group: $Name."
        Write-Verbose -Message ""


} # End Function Delete-ResourceGroup()

#endregion Delete-ResourceGroup()



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

[string[]]$ResourceGroups = $AzureRGName.Split(",")

# Because we accept an array of both Environments and Tenants as parameters, loop through them to create each specified.
$Count = 0

While ($Count -le $ResourceGroups.Count-1)
{    
    # Call Function
    Delete-ResourceGroup -Name $ResourceGroups[$Count]
    $Count++
}

# Mark the finish time.
$FinishTime = Get-Date
Write-Verbose -Message "Finish Time ($($FinishTime.ToLocalTime()))."

# Console output with -Verbose only
$TotalTime = $($FinishTime - $StartTime).Minutes
Write-Verbose -Message "Elapse Time (Minutes): $TotalTime"
Write-Verbose -Message ""


#endregion Main