<# 
.SYNOPSIS 
    This PowerShell script is intended to be executed remotely to create one or more Service Bus Namespace(s) using an
	Azure AD credential.  This PowerShell Script makes it easier to create one or more Service Bus Namespace(s) instead
    of using the Management Portal interactively.  At this time Service Bus provisions ONLY in Azure Classic (ASM) mode,
    not Azure Resource Manager (ARM) mode.
.DESCRIPTION 
    This PowerShell Script makes it easier establish one or more Azure Service Bus Namespace(s) than using the Azure
    Management Console.
 
.NOTES 
    File Name  : Create-AzureSBNamespace.ps1
    Author     : Ron Bokleman - ron.bokleman@bluemetal.com
               :
    Requires   : PowerShell V5 or above, PowerShell / ISE Elevated, Microsoft Azure PowerShell v1.2.2 March 2016
			   : from the Web Platform Installer.
               :
    Requires   : Azure Subscription needs to be setup in advance and you must know the name.
			   : The executor will be prompted for valid OrgID/MicrosoftID credentials.
               : User must have sufficient privledges to create a new Service Bus Namespace within the specified subscription.
               :
    Optional   : This can be called from a .bat file as desired to create one or more Service Bus Namespace(s).
			   : An example is included which demonstrates how to provide input to create one or more Service Bus Namespace(s).
               :
    Created    : 03/30/2016
	Updated	   : 03/30/2016 v1.0
	Updated    : 03/31/2016 v1.1 Minor comment/help update.

    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help ./Create-AzureSBNamespace.ps1 [Null], [-Full], [-Detailed], [-Examples]

.LINK
    Additional Information:
    
    Manage Service Bus with PowerShell
    http://azure.microsoft.com/en-us/documentation/articles/service-bus-powershell-how-to-provision/
    
    Connect with Me: 
    
    http://ronbokleman.wordpress.com
    http://www.linkedin.com/pub/ron-bokleman/1/14b/200

.PARAMETER Subscription
    Example:  Subcription Name i.e. "AppSuite"
.PARAMETER AzureRegion
    Example:  "East US 2"
.PARAMETER AzureSBNameSpace
    Example: aspen1devsb
.EXAMPLE
    ./Create-AzureSBNamespace.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureSBNameSpace "sassbdcm,sassbtcm,sassbscm,sassbpcm" -Verbose
.EXAMPLE
    ./Create-AzureSBNamespace.ps1 "AppSuite" "East US 2" "sassbdcm,sassbtcm,sassbscm,sassbpcm" -Verbose
.INPUTS
    The [Subscription] parameter is the name of the Azure subscription.

    The [AzureLocation] parameter is the name of the Azure Region/Location.

    The [AzureSBNameSpace] paramter is the name of the Azure Service Bus Namespace(s).
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
    [Parameter(Mandatory=$True, Position=2, HelpMessage='The Service Bus Namespace.')]
    [String]$AzureSBNameSpace
    )

#region Variables
<#

Sample variables for bypassing the script parameters for testing.

[string]$Subscription = "AppSuite"
[string]$AzureRegion = "East US 2"
[string]$AzureSBNameSpace = "sassbdcm,sassbtcm,sassbscm,sassbpcm"

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

        # Because Service Bus is in Azure Classic mode we cannot use Login-AzureRmAccount here and must fall
        # back to an ASM mode login.
        # $AzureRMContext = Login-AzureRmAccount
        $AzureContext = Add-AzureAccount

        # Console output with -Verbose only
        Write-Verbose -Message "[Finish] Azure AD user context $($AzureContext.Id) retrieved."
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

    Return $AzureContext

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
        # $SubcriptionContext = Set-AzureRmContext -SubscriptionName $Subscription -ErrorAction Stop
        Select-AzureSubscription -SubscriptionName $Subscription -ErrorAction Stop -Verbose

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


#region Import-ServiceBusDLL()

Function Import-ServiceBussDLL()
{
    # Depends upon CheckPowerShell() Function

    # Console output
    Write-Verbose -Message "[Start] Adding the [Microsoft.ServiceBus.dll] assembly to the script..."
    
    If ($ISE) # Executing from the PowerShell ISE instead of the PowerShell Console.
    {
        # If we're executing in the ISE, then we can use $PSISE to get the executing scripts file location.
        
        # WARNING: Make sure to reference the latest version of Microsoft.ServiceBus.dll and place it into the scripts \Packages folder!
        
        Try
        {

            # Get the current folder that the PowerShell script is executing from.
            $CurrentFolder = (Split-Path -Parent $psISE.CurrentFile.FullPath)
            # Move up one level since this should be being executed from GitHub
            $PackagesFolder = (Split-Path -Parent $CurrentFolder) + "\Packages"

            $Assembly = Get-ChildItem $PackagesFolder -Include "Microsoft.ServiceBus.dll" -Recurse
            Add-Type -Path $Assembly.FullName

        }

        Catch [System.Exception]
        {

            # Console output
            Write-Verbose -Message "Could not add the Microsoft.ServiceBus.dll assembly to the script."
            # Console output
            # $Exception = $error[0].Exception.GetType().FullName
            Throw "Microsoft Azure Service Bus DLL is required! [http://www.nuget.org/packages/WindowsAzure.ServiceBus] Aborting..."

        } # End Try / Catch

    } # End If
    Else # Executing from the PowerShell Console instead of the PowerShell ISE.
    {

        Try
        {

        # If we're executing in the Console, then we have to use $PSCommandPath to get the executing scripts file location.
        $PSScript = $PSCommandPath | Split-Path -Parent
        # Move up one level since this should be being executed from GitHub
        $PSScript = $PSScript | Split-Path -Parent
        $PackagesFolder = $PSScript + "\Packages"
        $Assembly = Get-ChildItem $PackagesFolder -Include "Microsoft.ServiceBus.dll" -Recurse
        Add-Type -Path $Assembly.FullName

        }

        Catch [System.Exception]
        {

            # Console output
            Write-Verbose -Message "Could not add the Microsoft.ServiceBus.dll assembly to the script."
            # Console output
            # $Exception = $error[0].Exception.GetType().FullName
            Throw "Microsoft Azure Service Bus DLL is required! [http://www.nuget.org/packages/WindowsAzure.ServiceBus] Aborting..."

        } # End Try / Catch
        
    } # End Else

    # Console output
    Write-Verbose -Message "[Finish] Added the [Microsoft.ServiceBus.dll] assembly to the script..."
        
} #End Function Import-ServiceBussDLL()

#endregion Import-ServiceBusDLL()



#region Create-SBNamespace()

Function Create-SBNamespace()
{

    Param  ([string]$Subscription, [string]$AzureLocation, [string]$SBNameSpace)

    # Console output
    Write-Verbose -Message "[Information] Azure Service Bus Namespace $SBNameSpace appears available in $Subscription."
    Write-Verbose -Message " "

    Try
    {

        # Console output
        Write-Verbose -Message "[Start] Creating new Azure Service Bus Namepsace: $SBNameSpace in $Subscription."
        Write-Verbose -Message " "

        # Create Azure Service Bus NameSpace.
        $AzureSBNS = New-AzureSBNamespace -Name $SBNameSpace -NamespaceType Messaging -Location $AzureLocation -CreateACSNamespace $True -ErrorAction Stop

        # Console output
        Write-Verbose -Message "[Finish] Created new Azure Service Bus Namepsace: $SBNameSpace, in $AzureLocation."
        Write-Verbose -Message " "

    }
    Catch # Catching this exception implies that another Azure subscription worldwide, has already claimed this Azure Service Bus Namespace.
    {
        # Console output
        # $Exception = $error[0].Exception.GetType().FullName
        Throw "Azure Service Bus Namespace, $SBNameSpace in $AzureLocation, is not available! Azure Service Bus Namespace must be UNIQUE worldwide. Aborting..."

    } #End Try/Catch

    Return $AzureSBNS


} # End Function

#endregion Create-SBNamespace()



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


#Call Function
Import-ServiceBussDLL

[string[]]$AzureSBNameSpaces = $AzureSBNameSpace.Split(",")

$Count = 0
$CheckSB = $null

While ($Count -le $AzureSBNameSpaces.Count-1)
    {

    # Check to see if we have an Azure Service Bus Namespace by that name, if available, create it.
    $CheckSB = Get-AzureSBNamespace $AzureSBNameSpaces[$Count] -ErrorAction SilentlyContinue


    If ([string]::IsNullOrEmpty($CheckSB))
        {

        # Call Function
        $AzureSBNS = Create-SBNamespace $Subscription $AzureRegion $($AzureSBNameSpaces[$Count])

        }

        $Count++
        $CheckSB = $null

    } # End While

# Mark the finish time.
$FinishTime = Get-Date
Write-Verbose -Message "Finish Time ($($FinishTime.ToLocalTime()))."

# Console output with -Verbose only
$TotalTime = ($FinishTime - $StartTime).Minutes
Write-Verbose -Message "Elapse Time (Minutes): $TotalTime"
Write-Verbose -Message ""


#endregion Main