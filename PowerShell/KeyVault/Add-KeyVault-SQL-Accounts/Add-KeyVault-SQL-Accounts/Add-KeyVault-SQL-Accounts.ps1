<#
	This is a utility script to allow the setting of Passwords in Key Vault for specific Active Directory User Accounts for Steward AppSuite:  stewardappsuite.com.

	It's not meant to be pretty, just functional.
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

[string]$Subscription = "AppSuite"

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


# Set a password we want to store as a secret in KVDevelopment
$SecretValue = ConvertTo-SecureString -String "sqladmin;0N6sK2DGrN1TSBNB42Rd" -AsPlainText -Force
# Set the password as a secret in the vault
Set-AzureKeyVaultSecret -VaultName "sasdcs" -Name "SQLDevelopment" -SecretValue $SecretValue

# Let's go get the secret from the vault now...
$Secret = Get-AzureKeyVaultSecret -VaultName "sasdcs" -Name "SQLDevelopment"
$Secret.SecretValue
$Secret.SecretValueText

# Set a password we want to store as a secret in KVTest
$SecretValue = ConvertTo-SecureString -String "sqladmin;dNsx4ZPnDdoJNQDewNKU" -AsPlainText -Force
# Set the password as a secret in the vault
Set-AzureKeyVaultSecret -VaultName "sastcs" -Name "SQLTest" -SecretValue $SecretValue

# Let's go get the secret from the vault now...
$Secret = Get-AzureKeyVaultSecret -VaultName "sastcs" -Name "SQLTest"
$Secret.SecretValue
$Secret.SecretValueText

# Set a password we want to store as a secret in KVStage
$SecretValue = ConvertTo-SecureString -String "sqladmin;zdmYbfiC3LAAvE4gYCbC" -AsPlainText -Force
# Set the password as a secret in the vault
Set-AzureKeyVaultSecret -VaultName "sasscs" -Name "SQLStage" -SecretValue $SecretValue

# Let's go get the secret from the vault now...
$Secret = Get-AzureKeyVaultSecret -VaultName "sasscs" -Name "SQLStage"
$Secret.SecretValue
$Secret.SecretValueText

# Set a password we want to store as a secret in KVProduction
$SecretValue = ConvertTo-SecureString -String "sqladmin;vR84P2Oola2xtDT9y69F" -AsPlainText -Force
# Set the password as a secret in the vault
Set-AzureKeyVaultSecret -VaultName "saspcs" -Name "SQLProduction" -SecretValue $SecretValue

# Let's go get the secret from the vault now...
$Secret = Get-AzureKeyVaultSecret -VaultName "saspcs" -Name "SQLProduction"
$Secret.SecretValue
$Secret.SecretValueText

# Mark the finish time.
$FinishTime = Get-Date0N6sK2DGrN1TSBNB42Rd
Write-Verbose -Message "Finish Time ($($FinishTime.ToLocalTime()))."

# Console output with -Verbose only
$TotalTime = ($FinishTime - $StartTime).Seconds
Write-Verbose -Message "Elapse Time (Seconds): $TotalTime"
Write-Verbose -Message ""


#endregion Main