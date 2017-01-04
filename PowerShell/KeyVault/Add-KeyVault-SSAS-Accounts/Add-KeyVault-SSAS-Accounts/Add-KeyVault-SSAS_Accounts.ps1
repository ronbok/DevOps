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



#region Create-ResourceGroup()

Function Create-ResourceGroup
{
    Param([String]$Name, [String]$Region), [string]$Environment, [string]$Tenant

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

# Set a password we want to store as a secret
$Password = ConvertTo-SecureString -String "sTdVu2gyd9aPIF18AL8j" -AsPlainText -Force
# Set the password as a secret in the vault
Set-AzureKeyVaultSecret -VaultName "sasdcs" -Name "ssasdevelopment" -SecretValue $Password

# Set a password we want to store as a secret
$Password = ConvertTo-SecureString -String "luW8k0e6ZyMn8WAfvvH8" -AsPlainText -Force
# Set the password as a secret in the vault
Set-AzureKeyVaultSecret -VaultName "sastcs" -Name "ssastest" -SecretValue $Password

# Set a password we want to store as a secret
$Password = ConvertTo-SecureString -String "y8yR3otH6wLVhqz2zdgW" -AsPlainText -Force
# Set the password as a secret in the vault
Set-AzureKeyVaultSecret -VaultName "sasscs" -Name "ssasstage" -SecretValue $Password

# Set a password we want to store as a secret
$Password = ConvertTo-SecureString -String "WCPJuZXyDSc46UTc9Xhr" -AsPlainText -Force
# Set the password as a secret in the vault
Set-AzureKeyVaultSecret -VaultName "saspcs" -Name "ssasproduction" -SecretValue $Password

# Let's go get the secret from the vault now...
$Secret = Get-AzureKeyVaultSecret -VaultName "sasdcs" -Name "ssasdevelopment"
$Secret.SecretValue
$Secret.SecretValueText

# Let's go get the secret from the vault now...
$Secret = Get-AzureKeyVaultSecret -VaultName "sastcs" -Name "ssastest"
$Secret.SecretValue
$Secret.SecretValueText

# Let's go get the secret from the vault now...
$Secret = Get-AzureKeyVaultSecret -VaultName "sasscs" -Name "ssasstage"
$Secret.SecretValue
$Secret.SecretValueText

# Let's go get the secret from the vault now...
$Secret = Get-AzureKeyVaultSecret -VaultName "saspcs" -Name "ssasproduction"
$Secret.SecretValue
$Secret.SecretValueText

# Mark the finish time.
$FinishTime = Get-Date
Write-Verbose -Message "Finish Time ($($FinishTime.ToLocalTime()))."

# Console output with -Verbose only
$TotalTime = ($FinishTime - $StartTime).Seconds
Write-Verbose -Message "Elapse Time (Seconds): $TotalTime"
Write-Verbose -Message ""


#endregion Main