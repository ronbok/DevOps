<# 
.SYNOPSIS 
    This PowerShell script is intended to be executed remotely to delete one or more Cloud Service(s) using an
	Azure AD credential.  This PowerShell Script makes it easier to delete one or more Cloud Service(s) instead
    of using the Management Portal interactively.  At this time Service Bus provisions ONLY in Azure Classic (ASM) mode,
    not Azure Resource Manager (ARM) mode.
.DESCRIPTION 
    This PowerShell Script makes it easier establish one or more Azure Cloud Service(s) than using the Azure
    Management Console.
 
.NOTES 
    File Name  : Delete-AzureCloudService.ps1
    Author     : Ron Bokleman - ron.bokleman@bluemetal.com
               :
    Requires   : PowerShell V5 or above, PowerShell / ISE Elevated, Microsoft Azure PowerShell v1.2.2 March 2016
			   : from the Web Platform Installer.
               :
    Requires   : Azure Subscription needs to be setup in advance and you must know the name.
			   : The executor will be prompted for valid OrgID/MicrosoftID credentials.
               : User must have sufficient privledges to delete a new Service Bus Namespace within the specified subscription.
               :
    Optional   : This can be called from a .bat file as desired to delete one or more Cloud Service(s).
			   : An example is included which demonstrates how to provide input to delete one or more Cloud Service(s).
               :
    Created    : 03/31/2016
	Updated	   : 04/04/2016 v1.0
	Updated    : MM/DD/YYYY

    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help ./Delete-CloudService.ps1 [Null], [-Full], [-Detailed], [-Examples]

.LINK
    Additional Information:
    
    Cloud Services Documentation
    https://azure.microsoft.com/en-us/documentation/services/cloud-services/
    
    Connect with Me: 
    
    http://ronbokleman.wordpress.com
    http://www.linkedin.com/pub/ron-bokleman/1/14b/200

.PARAMETER Subscription
    Example:  Subcription Name i.e. "AppSuite"
.PARAMETER AzureRegion
    Example:  "East US 2"
.PARAMETER AzureCSName
    Example: "sascsdc,sascstc,sascssc,sascspc" or simply "sascsdc"
.EXAMPLE
    ./Delete-AzureCloudService.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureCSName "sascsdc,sascstc,sascssc,sascspc"
.EXAMPLE
    ./Delete-AzureCloudService.ps1 "AppSuite" "East US 2" "sascsdc,sascstc,sascssc,sascspc"
.INPUTS
    The [Subscription] parameter is the name of the Azure subscription.

    The [AzureLocation] parameter is the name of the Azure Region/Location.

    The [AzureCSName] paramter is the name of the Azure Cloud Service(s).
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
    [Parameter(Mandatory=$True, Position=2, HelpMessage='The Cloud Service name.')]
    [String]$AzureCSName
    )

#region Variables
<#

Sample variables for bypassing the script parameters for testing.

[string]$Subscription = "AppSuite"
[string]$AzureRegion = "East US 2"
[string]$AzureCSName = "sascsdc,sascstc,sascssc,sascspc"

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


[string[]]$AzureCSNames = $AzureCSName.Split(",")

$Count = 0

While ($Count -le $AzureCSNames.Count-1)
    {
        If ((Test-AzureName -Service $AzureCSNames[$Count]))
        {
            #region Dreate Cloud Service in $AzureRegion if it exists.
            Try
            {
                $Error.Clear()
                  
                Write-Verbose -Message "[Start] Trying to delete Azure Cloud Service $($AzureCSNames[$Count]) in $Subscription."
     
                $AzureService = Remove-AzureService -ServiceName $($AzureCSNames[$Count]) # -Force -Confirm:$False

                Write-Verbose -Message "[Finish] Successfully deleted Azure Cloud Service $($AzureCSNames[$Count]) in $Subscription."
            }
            Catch 
            {
                # Console output
                Write-Verbose -Message $Error[0].Exception.Message -Verbose
             
            }
            #endregion Create new Cloud Service in $AzureLocation Region if it doesn't exist.
        }
        Else
        {
            # Console output
            Throw "Azure Cloud Service Name, $($AzureCSNames[$Count]) in $AzureRegion is not found! Aborting..."
        }

    
        $Count++
        

    } # End While

# Mark the finish time.
$FinishTime = Get-Date
Write-Verbose -Message "Finish Time ($($FinishTime.ToLocalTime()))."

# Console output with -Verbose only
$TotalTime = ($FinishTime - $StartTime).Minutes
Write-Verbose -Message "Elapse Time (Minutes): $TotalTime"
Write-Verbose -Message ""


#endregion Main
