<# 
.SYNOPSIS 
    This PowerShell script is intended to be executed remotely to create a new Azure Site-To-Site (S2S) VPN using an
	Azure AD credential with proper RBAC permissions to create such a group.  This PowerShell Script makes it easier
    to create a new Azure Site-To-Site (S2S) VPN instead of using the Management Portal interactively.
.DESCRIPTION 
    This script should be executed one step at a time and one line at a time veryifying that each cmdlet functions properly.

    DO NOT RUN THIS AGAIN UNLESS THE S2S NETWORK NEEDS TO BE RE-ESTABLISHED!  THIS IS A ONE TIME OPERATION UNDER NORMAL CIRCUMSTANCES.
    
    For detailed instructions please carefully review the article provided by Microsoft:
    https://azure.microsoft.com/en-us/documentation/articles/vpn-gateway-create-site-to-site-rm-powershell/

    The script is broken into the exact same 9-Step sequence detailed in the above article.
.NOTES 
    File Name  : Add-AzureRmS2SVPN.ps1
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
               :
    Created    : 03/08/2016
	Updated	   : 03/15/2016 v1.0
	
    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help ./Add-AzureRmS2SVPN.ps1 [Null], [-Full], [-Detailed], [-Examples]

.LINK
    Additional Information:
    
    https://azure.microsoft.com/en-us/documentation/articles/vpn-gateway-create-site-to-site-rm-powershell/
    
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
    ./Add-AzureRmS2SVPN.ps1
.INPUTS
    The [Subscription] parameter is the name of the Azure subscription.
.OUTPUTS
    Normal Verbose/Debug output included with -Verbose or -Debug parameters.
#>

#Requires -RunAsAdministrator
#Requires -Version 5.0

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The name of the Azure Subscription to which access has been granted.")]
    [string]$Subscription
    )

#region Variables
<#

Sample variables for bypassing the script parameters for testing.

None

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

#0.  Get the existing VNet
$SASVNet = Get-AzureRmVirtualNetwork -ResourceGroupName "Subscription_Common" -Name "AppSuite"

#3. Add your local site
$SASGateway = New-AzureRmLocalNetworkGateway -Name "StewardDorchester" -ResourceGroupName "Subscription_Common" -Location 'East US 2' -GatewayIpAddress "198.89.79.22" -AddressPrefix @("172.31.0.0/16","172.17.185.0/24","192.168.168.0/21","10.122.118.0/24","192.168.176.0/24","198.89.76.207/32","198.89.76.210/32","198.89.76.189/32","172.18.100.238/32","198.89.76.206/32","198.89.76.106/32","198.89.82.254/32","198.89.82.177/32","172.24.100.255/32","172.24.100.244/32","172.18.100.255/32","172.20.100.255/32","172.16.100.255/32","172.22.100.255/32","172.18.248.0/24","10.122.126.62/32","10.122.126.63/32")

#4. Request a public IP address for the gateway
$SASGWIP = New-AzureRmPublicIpAddress -Name GWIP -ResourceGroupName "Subscription_Common" -Location 'East US 2' -AllocationMethod Dynamic

#5. Create the gateway IP addressing configuration
$SASVNet = Get-AzureRmVirtualNetwork -ResourceGroupName "Subscription_Common" -Name "AppSuite"

$GWSubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $SASVNet
$GWIPConfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name gwipconfig1 -SubnetId $GWSubnet.Id -PublicIpAddressId $SASGWIP.Id 


#6. Create the gateway.  Note that that creating a gateway can take a long time to complete. Often 20 minutes or more.
New-AzureRmVirtualNetworkGateway -Name "SASGateway" -ResourceGroupName "Subscription_Common" -Location "East US 2" -IpConfigurations $GWIPConfig -GatewayType "VPN" -VpnType "PolicyBased"

#7. Configure your VPN device
Get-AzureRmPublicIpAddress -Name GWIP -ResourceGroupName "Subscription_Common"

#8. Create the VPN connection
$Gateway = Get-AzureRmVirtualNetworkGateway -Name "SASGateway" -ResourceGroupName "Subscription_Common"
$LocalNetwork = Get-AzureRmLocalNetworkGateway -Name "StewardDorchester" -ResourceGroupName "Subscription_Common"

New-AzureRmVirtualNetworkGatewayConnection -Name localtovpn -ResourceGroupName "Subscription_Common" -Location "East US 2" -VirtualNetworkGateway1 $Gateway -LocalNetworkGateway2 $LocalNetwork -ConnectionType "IPsec" -RoutingWeight 10 -SharedKey "5W0L4DpirM"

#9. Verify a VPN connection
Get-AzureRmVirtualNetworkGatewayConnection -Name localtovpn -ResourceGroupName "Subscription_Common"

# Mark the finish time.
$FinishTime = Get-Date
Write-Verbose -Message "Finish Time ($($FinishTime.ToLocalTime()))."

# Console output with -Verbose only
$TotalTime = ($FinishTime - $StartTime).Minutes
Write-Verbose -Message "Elapse Time (Minutes): $TotalTime"
Write-Verbose -Message ""


#endregion Main