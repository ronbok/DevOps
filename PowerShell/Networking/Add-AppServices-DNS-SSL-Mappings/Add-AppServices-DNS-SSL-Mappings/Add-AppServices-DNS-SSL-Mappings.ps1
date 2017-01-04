<# 
.SYNOPSIS 
    This PowerShell script is intended to be executed remotely to add both the DNS and SSL mappings for all AppSuite App Services.
	An Azure AD credential with proper RBAC permissions is required.  This PowerShell Script makes it easier
    to the DNS and SSL mappings instead of using the Management Portal interactively.
.DESCRIPTION 
    Each App Service API or WebApp requires both public DNS entries and a Root CA Trusted SSL/TLS Certificate to be applied.
	
.NOTES 
    File Name  : Add-AppServices-DNS-SSL-Mappings.ps1
               :
    Author     : Ron Bokleman - ron.bokleman@bluemetal.com
               :
    Requires   : PowerShell V5 or above, PowerShell / ISE Elevated, Microsoft Azure PowerShell v1.5.0 June 2016
			   : from the Web Platform Installer.
               :
    Requires   : Azure Subscription needs to be setup in advance and you must know the name.
			   : The executor will be prompted for valid OrgID/MicrosoftID credentials.
               : User must have sufficient privledges within the specified subscription.
               :
    Optional   : This can be called from a .bat file as desired. An example is provided.
               :
    Created    : 06/20/2016
	Updated	   : 06/20/2016 v1.0
	Updated    : MM/DD/YYYY
	
    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help ./Create-AzureRMResourceGroup.ps1 [Null], [-Full], [-Detailed], [-Examples]

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
    Example: "Development_Common"
.EXAMPLE
    ./Add-AppServices-DNS-SSL-Mappings.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGName "Development_Common" -Verbose
.EXAMPLE
    ./Add-AppServices-DNS-SSL-Mappings.ps1 -Subscription "AppSuite" "East US 2" "Development_Common" -Verbose
.INPUTS
    The [Subscription] parameter is the name of the Azure subscription.

    The [AzureRegion] parameter is the name of the Azure Region/Location to host the Resource Group(s) for this subscription.

    The [AzureRGName] parameter is the name of the Environment type of the Azure Resource Group to update.
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
    [String]$AzureRGName
    )

#region Variables
<#

Sample variables for bypassing the script parameters for testing.

[string]$Subscription = "AppSuite"
[string]$AzureRegion = "East US"
[string]$AzureRGName = "Development_Common"
[string]$AzureRGName = "Test_Common"


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



#region Set-HostName()

Function Set-HostName()
{

    param ([string]$AppName, [string]$AzureRGName, [string]$Environment)

    $App = Get-AzureRmWebApp -ResourceGroupName $AzureRGName -Name $AppName

    $App.HostNames

    If ($App.HostNames.Count -eq 1)
    {

        $HostNames = $App.HostNames

        $AppShortName = $AppName.Replace("AppSuite","").ToLower()

        # Because we were inconsistent with the API/Web naming...
        If ($AppShortName -eq $("web" + $Environment))
        {
            $AppShortName = $AppShortName.Replace("web","").ToLower()
        }

        $HostNames.Add($AppShortName + ".stewardappsuite.com")
        Set-AzureRmWebApp -ResourceGroupName $AzureRGName -Name $AppName -HostNames $HostNames

        $App = Get-AzureRmWebApp -ResourceGroupName $AzureRGName -Name $AppName

        # Console output with -Verbose only
        Write-Verbose -Message "$AppName now configured for:" -Verbose
        $App.HostNames
        Write-Verbose -Message ""
    
    }
    Else
    {
        # Most likely cause is that the hostname has already been added.
        
        # Console output with -Verbose only
        Write-Verbose -Message "$AppName already configured." -Verbose
        Write-Verbose -Message ""

    }

} # End Set-HostName()

#endregion Set-HostName()



#region Set-SSLBinding()

Function Set-SSLBinding()
{

param ([string]$AppName, [string]$AzureRGName)

    $App = Get-AzureRmWebApp -ResourceGroupName $AzureRGName -Name $AppName
    $Count = 0

    While ($Count -le $App.HostNameSslStates.Count-1)
    {
    
        If ($App.HostNameSslStates[$Count].Name -eq $($AppName.Replace("AppSuite","").ToLower() + ".stewardappsuite.com"))
        {

            If ( !$App.HostNameSslStates[$Count].SslState -eq "SniEnabled" )
            {
                # Create the SSL Binding
                New-AzureRmWebAppSSLBinding -ResourceGroupName $AzureRGName -WebAppName $AppName -Thumbprint "B03A4A896B5BF94570701297DB26829DF3136B5F" -Name $($AppName.Replace("AppSuite","").ToLower() + ".stewardappsuite.com")

                # Console output with -Verbose only
                Write-Verbose -Message "$AppName now configured for SSL." -Verbose
                Write-Verbose -Message ""
            }
            Else
            {
                # Console output with -Verbose only
                Write-Verbose -Message "$AppName already configured for SSL." -Verbose
                Write-Verbose -Message ""

            }

        }
 
    $Count++

    }  
    
}

#endregion Set-SSLBinding()



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

# Since our naming standards got off the rails a bit we need to shorten them to match the App Services / APIs/WebApps.
Switch ($AzureRGName.Split("_")[0])
{

    Development {$Environment = "Dev"}
    Test {$Environment = "Test"}
    Stage {$Environment = "Stage"}
    Production {$Environment = "Prod"}

}

$Environment

# NOTE: NO DNS Records Created for this!
# Environment_Internal
# $WebAppName = "AppSuiteInternalApiDev"
# Set-HostName -AppName $WebAppName

# Environment_External
$WebAppName = "AppSuiteHomeApi" + $Environment
Set-HostName -AppName $WebAppName -AzureRGName $AzureRGName -Environment $Environment
Set-SSLBinding -AppName $WebAppName -AzureRGName $AzureRGName

$WebAppName = "AppSuiteIngestionApi" + $Environment
Set-HostName -AppName $WebAppName -AzureRGName $AzureRGName -Environment $Environment
Set-SSLBinding -AppName $WebAppName -AzureRGName $AzureRGName

$WebAppName = "AppSuiteLaborApi" + $Environment
Set-HostName -AppName $WebAppName -AzureRGName $AzureRGName -Environment $Environment
Set-SSLBinding -AppName $WebAppName -AzureRGName $AzureRGName

$WebAppName = "AppSuiteLosApi" + $Environment
Set-HostName -AppName $WebAppName -AzureRGName $AzureRGName -Environment $Environment
Set-SSLBinding -AppName $WebAppName -AzureRGName $AzureRGName

$WebAppName = "AppSuiteNotificationsApi" + $Environment
Set-HostName -AppName $WebAppName -AzureRGName $AzureRGName -Environment $Environment
Set-SSLBinding -AppName $WebAppName -AzureRGName $AzureRGName

$WebAppName = "AppSuiteOpportunitiesApi" + $Environment
Set-HostName -AppName $WebAppName -AzureRGName $AzureRGName -Environment $Environment
Set-SSLBinding -AppName $WebAppName -AzureRGName $AzureRGName

$WebAppName = "AppSuitePatientAccessApi" + $Environment
Set-HostName -AppName $WebAppName -AzureRGName $AzureRGName -Environment $Environment
Set-SSLBinding -AppName $WebAppName -AzureRGName $AzureRGName

$WebAppName = "AppSuitePatientPlacementApi" + $Environment
Set-HostName -AppName $WebAppName -AzureRGName $AzureRGName -Environment $Environment
Set-SSLBinding -AppName $WebAppName -AzureRGName $AzureRGName

$WebAppName = "AppSuiteUserAccessControlApi" + $Environment
Set-HostName -AppName $WebAppName -AzureRGName $AzureRGName -Environment $Environment
Set-SSLBinding -AppName $WebAppName -AzureRGName $AzureRGName

$WebAppName = "AppSuiteWeb" + $Environment
Set-HostName -AppName $WebAppName -AzureRGName $AzureRGName -Environment $Environment
Set-SSLBinding -AppName $WebAppName -AzureRGName $AzureRGName

$WebAppName = "AppSuiteWorklistsApi" + $Environment
Set-HostName -AppName $WebAppName -AzureRGName $AzureRGName -Environment $Environment
Set-SSLBinding -AppName $WebAppName -AzureRGName $AzureRGName

$WebAppName = "AppSuiteAdminConsent" + $Environment
Set-HostName -AppName $WebAppName -AzureRGName $AzureRGName -Environment $Environment
Set-SSLBinding -AppName $WebAppName -AzureRGName $AzureRGName

# Mark the finish time.
$FinishTime = Get-Date
Write-Verbose -Message "Finish Time ($($FinishTime.ToLocalTime()))."

# Console output with -Verbose only
$TotalTime = ($FinishTime - $StartTime).Seconds
Write-Verbose -Message "Elapse Time (Seconds): $TotalTime"
Write-Verbose -Message ""


#endregion Main