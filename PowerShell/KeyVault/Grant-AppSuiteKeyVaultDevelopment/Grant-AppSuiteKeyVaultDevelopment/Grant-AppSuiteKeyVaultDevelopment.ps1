<# 
.SYNOPSIS 
    This PowerShell script is intended to be executed remotely to grant access to an Azure AD registered application
    to a Key Vault for reading various secrets for AppSuite.  An Azure AD credential with proper RBAC permissions to
    alter such permissions in an existing vault is required.  The Azure AD application must be registerd in Azure AD,
    it's ClientID and Key values must be known in advance.  An existing Azure AD application
    already exists by the name AppSuiteKeyVaultTest and the following code uses these values of ClientID/Key from that
    specific application instance.
.DESCRIPTION 
    This grants Azure Key Vault permissions to an Azure AD Application previously registered.

.NOTES 
    File Name  : Grant-AppSuiteKeyVaultDevelopment.ps1
               :
    Author     : Ron Bokleman - ron.bokleman@bluemetal.com
               :
    Requires   : PowerShell V5 or above, PowerShell / ISE Elevated, Microsoft Azure PowerShell v1.5 June 2016
			   : from the Web Platform Installer.
               :
    Requires   : Azure Subscription needs to be setup in advance and you must know the name.
			   : The executor will be prompted for valid OrgID/MicrosoftID credentials.
               : User must have sufficient privledges to access the Key Vault within the specified subscription.
               :
    Optional   : This can be called from a .bat file as desired.  An example is included.
               :
    Created    : 06/10/2016
	Updated	   : 06/10/2016 v1.0
	Updated    : MM/DD/YYYY
	
    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help ./Grant-AppSuiteKeyVaultDevelopment.ps1 [Null], [-Full], [-Detailed], [-Examples]

.LINK
    Additional Information:
    
    https://azure.microsoft.com/en-us/documentation/articles/key-vault-get-started/
    
    Connect with Me: 
    
    http://ronbokleman.wordpress.com
    http://www.linkedin.com/pub/ron-bokleman/1/14b/200

.PARAMETER Subscription
    Example:  Subcription Name i.e. "AppSuite"
.PARAMETER AzureRegion
    Example:  "East US 2"
.PARAMETER AzureRGName
    Example: "Development_Common"
.PARAMETER AzureKeyVaultName
    Example: "sasdcs"
.EXAMPLE
    ./Grant-AppSuiteKeyVaultDevelopment.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGName "Development_Common" -AzureKeyVaultName "sasdcs" -Verbose
.EXAMPLE
    ./Grant-AppSuiteKeyVaultDevelopment.ps1 "AppSuite" "East US 2" "Development_Common" "sasdcs" -Verbose
.INPUTS
    The [Subscription] parameter is the name of the Azure subscription.

    The [AzureRegion] parameter is the name of the Azure Region/Location.

    The [AzureRGName] parameter is the name of the Azure Resource Group where Azure Key Vault will be updated.

    The [AzureKeyVaultName] parameter is the name of the Azure Key Vault to updated.
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
    [Parameter(Mandatory=$True, Position=2, HelpMessage='The Environment type of the Azure Resource Group to update.')]
    [string]$AzureRGName,
    [Parameter(Mandatory=$True, Position=3, HelpMessage='The Azure Key Vault to update.')]
    [string]$AzureKeyVaultName
    )

#region Variables
<#

Sample variables for bypassing the script parameters for testing.

[string]$Subscription = "AppSuite"
[string]$AzureRegion = "East US 2"
[string]$AzureRGName = "Development_Common"
[string]$AzureKeyVaultName = "sasdcs"

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


# Azure AD AppSuiteKeyVaultDevelopment ClientID/Key as stored in KeePass.  These values should probably end up in Key Vault itself instead.  Backlog task.
$AADClientID = "fef3950c-e9c4-41ff-b2e7-fd1fca461754"
$AADKey = "RResmIWT+N7+kjCpOoE2DThYuOxD8a5LKnpIdAX1xRY="

$KV = Get-AzureRmKeyVault -VaultName $AzureKeyVaultName -ResourceGroupName $AzureRGName


# Does this application aleady have access to Key Vault?  NOTE: No PowerShell cmdlets yet to grab the existing policy directly.
$Count = 0

While ($Count -le $KV.AccessPolicies.Count-1)

{
    $Found = $KV.AccessPolicies[$Count].DisplayName -like "AppSuiteKeyVaultDev*"
    If ($Found)
    {

        # Console output with -Verbose only
		Write-Verbose -Message "[Error:$PSScriptName] Specified Key Vault has permissions already granted for this application."
        Write-Verbose -Message ""

        Write-Verbose -Message "$($KV.AccessPolicies[$Count].DisplayName)"
        Write-Verbose -Message ""
        Write-Verbose -Message "Secrets: $($KV.AccessPolicies[$Count].PermissionsToSecrets)"
        Write-Verbose -Message "Keys: $($KV.AccessPolicies[$Count].PermissionsToKeys)"
        Write-Verbose -Message ""

        # This is such a catastrophic error we have to abandon further execution.
        Exit
        
    }
    $Count++
}

# Ensure that this Key Vault is enabled 'True' for Disk Encryption!
If ($KV.EnabledForDiskEncryption)
{
    $KeyVaultUrl = $KV.VaultUri
    $KeyVaultResourceId = $KV.ResourceId

    # Grant AppSuiteKeyVaultDevelopment access with full control to manage Key Vault.
    Set-AzureRmKeyVaultAccessPolicy -VaultName $KV.VaultName -ServicePrincipalName $AADClientID -PermissionsToKeys "Get" -PermissionsToSecrets "Get"

    # Fix the tags since changing the permissions removes them...
    Set-AzureRmResource -Tag @(@{Name="Environment";Value=$($AzureRGName.Split("_")[0])}, @{Name="Tenant";Value=$($AzureRGName.Split("_")[1])}) -ResourceId $KeyVaultResourceId -Force

    # Check Key Vault to ensure our changes took place and the tags still exist.
    $KV = Get-AzureRmKeyVault -VaultName $AzureKeyVaultName -ResourceGroupName $AzureRGName
    $KV
}
Else
{

    # Console output with -Verbose only
	Write-Verbose -Message "[Error:$PSScriptName] Specified Key Vault does not support disk encryption."
    Write-Verbose -Message ""

    # This is such a catastrophic error we have to abandon further execution.
    Break
}


# Mark the finish time.
$FinishTime = Get-Date
Write-Verbose -Message "Finish Time ($($FinishTime.ToLocalTime()))."

# Console output with -Verbose only
$TotalTime = ($FinishTime - $StartTime).Seconds
Write-Verbose -Message "Elapse Time (Seconds): $TotalTime"
Write-Verbose -Message ""


#endregion Main
