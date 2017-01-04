<# 
.SYNOPSIS 
    This PowerShell script is intended to be executed remotely to create a new Azure Resource Manager Network using an
	Azure AD credential with proper RBAC permissions to create such a group.  This PowerShell Script makes it easier
    to create an Azure Resource Manager Network instead of using the Management Portal interactively.
.DESCRIPTION 
    This creates one network with one or more subnets.  The network is tagged based upon the values entered for the
    Resource Group and based upon the PowerShell script Create-AzureRmResourceGroup.ps1, where tags are created/assigned for
    "Environment" and "Tenant" with the same values defined for	AzureRGEnvironmentName and AzureRGTenantName for each Resource Group created.

	Each of the string values, VNetSubnetNames and VNetSubnetIPs, must be paired equally or the script will fail and
	exit.
.NOTES 
    File Name  : Create-AzureRMNetwork.ps1
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
    Optional   : This can be called from a .bat file as desired to create one Azure Network with one or more subnets.
			   : An example is included which demonstrates how to provide input for creating multiple subnets as
			   : a comma separated list.
               :
    Created    : 03/04/2016
	Updated	   : 03/04/2016 v1.0
	Updated    : MM/DD/2016:
	
    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help ./Create-AzureRMNetwork.ps1 [Null], [-Full], [-Detailed], [-Examples]

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
.PARAMETER AzureRGName
    Example: "Development_Development", "Test_Test", "Subscription_Common"
.PARAMETER AzureVNetName
    Example: "Network1"
.PARAMETER VNetIPRange
    Example: "10.125.128.0/21"
.PARAMETER VNetSubnetNames
    Example: "GatewaySubnet,Management,Production_Shared,Stage_Shared,Test_Shared,Development_Shared,DMZ"
.PARAMETER VNetSubnetIPs
    Example: "10.125.132.128/25,10.125.132.0/25,10.125.130.0/23,10.125.129.128/25,10.125.129.0/25,10.125.128.128/25,10.125.128.0/25"
.EXAMPLE
    ./Create-AzureRMResourceGroup.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGName "Subscription_Common" -AzureVNetName "AppSuite" -VNetIPRange "10.125.128.0/21" -VNetSubnetNames "GatewaySubnet,Management,Production_Common,Stage_Common,Test_Common,Development_Common,DMZ" -VNetSubnetIPs "10.125.132.128/25,10.125.132.0/25,10.125.130.0/23,10.125.129.128/25,10.125.129.0/25,10.125.128.128/25,10.125.128.0/25" -Verbose
.EXAMPLE
    ./Create-AzureRMResourceGroup.ps1 "AppSuite" "East US 2" "Subscription_Common" "AppSuite" "10.125.128.0/21" "GatewaySubnet,Management,Production_Common,Stage_Common,Test_Common,Development_Common,DMZ" "10.125.132.128/25,10.125.132.0/25,10.125.130.0/23,10.125.129.128/25,10.125.129.0/25,10.125.128.128/25,10.125.128.0/25"
.INPUTS
    The [Subscription] parameter is the name of the Azure subscription.

    The [AzureRegion] parameter is the name of the Azure Region/Location in which to place the VNet.

    The [AzureRGName] parameter is the name of the Environment type of the Azure Resource Group in which to place the VNet.

    The [AzureVNetName] parameter is the name of the Azure VNet to create.

    The [VNetIPRange] parameter is the entire network address range desired.

    The [VNetSubnetNames] parameter is one or more subnets names, comma separated, to create.
    
    The [VNetSubnetIPs] parameter is the one or more subnet IP address ranges contained within the VNetIPRange, comma seaparated, to create.
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
    [string]$AzureRGName,
    [Parameter(Mandatory=$True, Position=3, HelpMessage='The Azure Virtual Network to create/update.')]
    [string]$AzureVNetName,
    [Parameter(Mandatory=$True, Position=4, HelpMessage='The range of IP addresses for a virtual network.')]
    [string]$VNetIPRange,
    [Parameter(Mandatory=$True, Position=5, HelpMessage='One or more VNet Subnet Names to create.')]
    [string]$VNetSubnetNames,
    [Parameter(Mandatory=$True, Position=6, HelpMessage='One or more VNet IP Subnets to create.')]
    [string]$VNetSubnetIPs
	)

#region Variables
<#

Sample variables for bypassing the script parameters for testing.

[string]$Subscription = "AppSuite"
[string]$AzureRegion = "East US 2"
[string]$AzureRGName = "Subscription_Common"
[string]$AzureVNetName = "Network1"
[string]$VNetIPRange = "10.125.128.0/21"
[string]$VNetSubnetNames = "GatewaySubnet,Management,Production_Shared"
[string]$VNetSubnetIPs = "10.125.132.128/25,10.125.132.0/25,10.125.130.0/23"

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

[string[]]$SubnetNames = $VNetSubnetNames.Split(",")
[string[]]$SubnetIPs = $VNetSubnetIPs.Split(",")

# Because we accept an array of both Environments and Tenants as parameters, loop through them to create each specified.
$Count = 0

# Create the VNet
$VNet = New-AzureRmVirtualNetwork -Name $AzureVNetName -ResourceGroupName $AzureRGName -Location $AzureRegion -AddressPrefix $VNetIPRange -Tag @{Name="Environment";Value=$($AzureRGName.Split('_')[0])}, @{Name="Tenant";Value=$($AzureRGName.Split('_')[1])}

# Start-Sleep -Seconds 60

If ($SubnetNames.Count -eq $SubnetIPs.Count)
{
    While ($Count -le $SubnetNames.Count-1)
    {    
        # Add each subnet specified on the command line...
        Add-AzureRmVirtualNetworkSubnetConfig -Name $SubnetNames[$Count] -AddressPrefix $SubnetIPs[$Count] -VirtualNetwork $VNet
        $Count++
    }

    # ...then update our VNet.
    Set-AzureRmVirtualNetwork -VirtualNetwork $VNet
}
Else
{
		# Console output with -Verbose only
		Write-Verbose -Message "[Error:$PSScriptName] Attempt to validate AzureVNetName/VNetSubnetIPs 1:1 pairing of parameters failed."
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