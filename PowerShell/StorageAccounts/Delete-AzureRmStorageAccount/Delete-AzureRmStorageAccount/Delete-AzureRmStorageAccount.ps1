﻿<# 
.SYNOPSIS 
    This PowerShell script is intended to be executed remotely to delete a new Azure Resource Manager StorageAccount using an
	Azure AD credential with proper RBAC permissions to create such a group.  This PowerShell Script makes it easier
    to delete an Azure Resource Manager StorageAccount instead of using the Management Portal interactively.
.DESCRIPTION 
    This deletes one or more Storage Accounts.  The StorageAccount is tagged based upon the values entered for the
    Resource Group and based upon the PowerShell script Create-AzureRmResourceGroup.ps1, where tags are created/assigned for
    "Environment" and "Tenant" with the same values defined for	AzureRGEnvironmentName and AzureRGTenantName for each Resource Group created.

	Each of the string values, AzureRGName and AzureSAName must be paired equally or the script will fail and
	exit.
.NOTES 
    File Name  : Delete-AzureRMStorageAccount.ps1
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
    Optional   : This can be called from a .bat file as desired to delete one or more Azure StorageAccount(s).
			   : An example is included which demonstrates how to provide input for deleting multiple Storage Accounts as
			   : a comma separated list including various Storage Account Types.
               :
    Created    : 03/15/2016
	Updated	   : 03/18/2016 v1.0
	Updated    : MM/DD/2016:
	
    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help ./Delete-AzureRMStorageAccount.ps1 [Null], [-Full], [-Detailed], [-Examples]

.LINK
    Additional Information:
    
    https://azure.microsoft.com/en-us/documentation/articles/storage-create-storage-account/
    
    Connect with Me: 
    
    http://ronbokleman.wordpress.com
    http://www.linkedin.com/pub/ron-bokleman/1/14b/200

.PARAMETER Subscription
    Example:  Subcription Name i.e. "AppSuite"
.PARAMETER AzureLocation
    Example:  "East US 2"
.PARAMETER AzureRGName
    Example: "Development_Development,Development_Common,Development_Common"
.PARAMETER AzureSAName
    Example: "sasdds,sasdcs,sasdcp"
.EXAMPLE
    ./Delete-AzureRMResourceGroup.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGName "Development_Development,Development_Common,Development_Common,Test_Test,Test_Common,Test_Common,Stage_Stage,Stage_Common,Stage_Common,Production_Common,Production_Common,Production_Common,Production_Common,Subscription_Common,Subscription_Common" -AzureSAName "sasdds,sasdcs,sasdcp,sastts,sastcs,sastcp,sassss,sasscs,sasscp,saspcs1,saspcs2,saspcp1,saspcp2,sassubcom1,sassubcom2" -Verbose
.EXAMPLE
    ./Delete-AzureRMResourceGroup.ps1 "AppSuite" "East US 2" "Development_Development,Development_Common,Development_Common,Test_Test,Test_Common,Test_Common,Stage_Stage,Stage_Common,Stage_Common,Production_Common,Production_Common,Production_Common,Production_Common,Subscription_Common,Subscription_Common" "sasdds,sasdcs,sasdcp,sastts,sastcs,sastcp,sassss,sasscs,sasscp,saspcs1,saspcs2,saspcp1,saspcp2,sassubcom1,sassubcom2" -Verbose
.INPUTS
    The [Subscription] parameter is the name of the Azure subscription.

    The [AzureRegion] parameter is the name of the Azure Region/Location.

    The [AzureRGName] parameter is the name of the Azure Resource Group to place the Storage Account(s).

    The [AzureSAName] parameter is the name of the Azure Storage Account to delete.
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
    [Parameter(Mandatory=$True, Position=2, HelpMessage='The Azure Resource Group where the Azure Storage Account to delete exists.')]
    [string]$AzureRGName,
    [Parameter(Mandatory=$True, Position=3, HelpMessage='The Azure Storage Account name.')]
    [string]$AzureSAName
    )

#region Variables
<#

Sample variables for bypassing the script parameters for testing.

[string]$Subscription = "AppSuite"
[string]$AzureRegion = "East US 2"
[string]$AzureRGName = "Development_Development,Development_Common,Development_Common,Test_Test,Test_Common,Test_Common,Stage_Stage,Stage_Common,Stage_Common,Production_Common,Production_Common,Production_Common,Production_Common,Subscription_Common,Subscription_Common"
[string]$AzureSAName = "sasdds,sasdcs,sasdcp,sastts,sastcs,sastcp,sassss,sasscs,sasscp,saspcs1,saspcs2,saspcp1,saspcp2,sassubcom1,sassubcom2"

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

Clear-Host

# Mark the start time.
$StartTime = Get-Date
Write-Verbose -Message "Start Time ($($StartTime.ToLocalTime()))."

# What version of Microsoft Azure PowerShell are we running?
# Console output with -Debug only
Write-Debug -Message (Get-Module azure -ListAvailable).Version
Write-Debug -Message ""

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

[string[]]$AzureRGNames = $AzureRGName.Split(",")
[string[]]$AzureSANames = $AzureSAName.Split(",")


# Because we accept an array of both AzureRGName, AzureSAName, AzureSAType as parameters, loop through them to create each specified.
$Count = 0

If (($AzureRGNames.Count -eq $AzureSANames.Count))
{
    While ($Count -le $AzureRGNames.Count-1)
    {
    
        $CheckSA = Get-AzureRmStorageAccountNameAvailability -Name $AzureSANames[$Count]

        If (![bool]$CheckSA.NameAvailable)
        {

            Try
            {

                # Ensure that $Error is clear before we begin
                $Error.Clear()

	            # Console output with -Verbose only
                Write-Verbose -Message "[Start] Attempting to delete Azure Storage Account: $($AzureSANames[$Count])."
                Write-Verbose -Message ""

                # Delete the Storage Account
                $SA = Remove-AzureRmStorageAccount -ResourceGroupName $AzureRGNames[$Count] -AccountName $AzureSANames[$Count]

                # Console output with -Verbose only
                Write-Verbose -Message "[Finish] Deleted Azure Storage Account: $($AzureSANames[$Count])."
                Write-Verbose -Message ""

            } # End Try
            Catch
            {

                # Console output with -Verbose only
                Write-Verbose -Message $Error[0].Exception.Message
                Write-Verbose -Message ""

	            Write-Verbose -Message "[Error:$PSScriptName] Attempt to delete Azure Storage Account: $($AzureSANames[$Count]) failed."
                Write-Verbose -Message ""

	            # Console output with -Debug only
	            Write-Debug -Message $Error[0].Exception.Message
                Write-Debug -Message ""

	            # Clear $Error, if one occured
                $Error.Clear()

                # This is such a catastrophic error we have to abandon further execution.
                Exit

            } # End Catch

        } # If
        Else
        {

            # Console output with -Verbose only
            Write-Verbose -Message "[Error:$PSScriptName] Attempt to delete Azure Storage Account: $($AzureSANames[$Count]) failed. Name not found."
            Write-Verbose -Message ""

        } # Else

        $Count++

    } # End While

}
Else
{
		# Console output with -Verbose only
		Write-Verbose -Message "[Error:$PSScriptName] Attempt to validate AzureRGName/AzureSAName/AzureSAType 1:1 pairing of parameters failed."
        Write-Verbose -Message ""

        # This is such a catastrophic error we have to abandon further execution.
        Exit
}

# Mark the finish time.
$FinishTime = Get-Date
Write-Verbose -Message "Finish Time ($($FinishTime.ToLocalTime()))."

# Console output with -Verbose only
$TotalTime = ($FinishTime - $StartTime).Minutes
Write-Verbose -Message "Elapse Time (Minutes): $TotalTime"
Write-Verbose -Message ""


#endregion Main