<# 
.SYNOPSIS 
    This PowerShell script is intended to be executed remotely to retrieve and display a list of existing tenants
    stored in the Tenant Manifest Tables for a given environment using an Azure AD credential with proper RBAC permissions.
    This PowerShell Script makes it easier list and view existing Steward AppSuite Tenants as there is currently no way to
    do this in the Management Portal interactively.
.DESCRIPTION 
    This lists all the Steward AppSuite Tenants from the Tenant Manifest.

.NOTES 
    File Name  : List-AllTenants.ps1
               :
    Author     : Ron Bokleman - ron.bokleman@bluemetal.com
               :
    Requires   : PowerShell V5 or above, PowerShell / ISE Elevated, Microsoft Azure PowerShell v1.4.0 May 2016.
			   : from the Web Platform Installer.
               :
    Requires   : Azure Subscription needs to be setup in advance and you must know the name.
			   : The executor will be prompted for valid OrgID/MicrosoftID credentials.
               : User must have sufficient privledges to create a new Resource Group within the specified subscription.
               :
    Optional   : This can be called from a .bat file as desired.
			   : An example is included which demonstrates how to provide input.
               :
    Created    : 03/08/2016
	Updated	   : 03/16/2016 v1.0
	Updated    : 04/15/2016 v1.1 Update to support tenant manifest schema changes.
    Updated    : 05/13/2016 v1.2 Crtical update to fix PowerShell v1.4.0 breaking changes to Get-AzureRmStorageAccountKey.
	
    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help ./List-AllTenants.ps1 [Null], [-Full], [-Detailed], [-Examples]

.LINK
    Additional Information:
    
    https://msdn.microsoft.com/en-us/library/mt125356.aspx
    
    Connect with Me: 
    
    http://ronbokleman.wordpress.com
    http://www.linkedin.com/pub/ron-bokleman/1/14b/200

.PARAMETER Subscription
    Example:  Subcription Name i.e. "AppSuite"
.PARAMETER AzureRegion
    Example:  "East US 2"
.PARAMETER AzureRGName
    Example: "Subscription_Common"
.PARAMETER AzureSAName
    Example: "sassubcom1"
.PARAMETER TableName
    Example: "TMDevelopment"
.EXAMPLE
    ./List-AllTenants.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGName "Subscription_Common" -AzureSAName "sassubcom1" -TableName "TMDevelopment" -Verbose
.EXAMPLE
    ./List-AllTenants.ps1 "AppSuite" "East US 2" "Subscription_Common" "sassubcom1" "TMDevelopment" -Verbose
.INPUTS
    The [Subscription] parameter is the name of the Azure subscription.

    The [AzureRegion] parameter is the name of the Azure Region/Location.

    The [AzureRGName] parameter is the name of the Azure Resource Group where the Tenant Manifest Table is stored.

    The [AzureSAName] parameter is the name of the Storage Account where the Tenant Manifest Table is stored.

    The [TableName] parameter is the name of Tenant Manifest Table from which to list all tenants.
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
    [Parameter(Mandatory=$True, Position=2, HelpMessage='The name of the Azure Resource Group containing the Tenant Manifest.')]
    [string]$AzureRGName,
    [Parameter(Mandatory=$True, Position=3, HelpMessage='The Storage Account name in which the the Azure Table to exists.')]
    [string]$AzureSAName,
    [Parameter(Mandatory=$True, Position=4, HelpMessage='The Azure Table to work with.')]
    [string]$TableName
    )

#region Variables
<#

Sample variables for bypassing the script parameters for testing.

[string]$Subscription = "AppSuite"
[string]$AzureRegion = "East US 2"
[string]$AzureRGName = "Subscription_Common"
[string]$AzureSAName = "sassubcom1"
[string]$TableName = "TMDevelopment", "TMTest", "TMStage", "TMProduction"

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


#Define the storage account and context.
$Key = (Get-AzureRmStorageAccountKey -Name $AzureSAName -ResourceGroupName $AzureRGName)[0]
$SaC = New-AzureStorageContext -StorageAccountName $AzureSAName -StorageAccountKey $Key.Value

#Retrieve the table if it already exists.
$Table = Get-AzureStorageTable –Name $TableName -Context $SaC -ErrorAction Stop

# If we don't already have a $TableName, then we will proceed to fail with a warning.
If ($Table -ne $null)
{
    $Query = New-Object Microsoft.WindowsAzure.Storage.Table.TableQuery

    $List = New-Object System.Collections.Generic.List[string]
    $List.Add("RowKey")
    $List.Add("Name")
    $List.Add("Key")
    $List.Add("StorageAccountRoot")
    $List.Add("MDSConnectionString")
    $List.Add("RMConnectionString")
    $List.Add("DMConnectionString")
    $List.Add("TM1ConnectionString")
    $List.Add("TM2ConnectionString")
    $List.Add("Active")

    $Query.SelectColumns = $List

    # Execute the query.
    $Entities = $Table.CloudTable.ExecuteQuery($Query)

    If ($Entities -ne $null)
    {

        # Display entity properties with the table format.
        $Entities | Format-Table @{Expression={$_.Properties["Name"].StringValue};Label="TenantName";Width=10},`
            @{Expression={$_.RowKey};Label="Tenant Domain";Width=13},`
            @{Expression={$_.Properties[“Key”].StringValue};Label="Tenant Key";Width=8},`
            @{Expression={$_.Properties["StorageAccountRoot"].StringValue};Label="Storage Account";Width=15},`
            @{Expression={$_.Properties["MDSConnectionString"].StringValue};Label="MDSConnectionString";Width=30},`
            @{Expression={$_.Properties["RMConnectionString"].StringValue};Label="RMConnectionString";Width=30},`
            @{Expression={$_.Properties["DMConnectionString"].StringValue};Label="DMConnectionString";Width=30},`
			@{Expression={$_.Properties["TM1ConnectionString"].StringValue};Label="TM1ConnectionString";Width=30},`
            @{Expression={$_.Properties["TM2ConnectionString"].StringValue};Label="TM2ConnectionString";Width=30},`
            @{Expression={$_.Properties["Active"].StringValue};Label="Active?";Width=7}`
            -Wrap

    } # End If ($Entity -eq $null)
    Else
    { 

        # Console output with -Verbose only
        Write-Verbose -Message ""
        Write-Verbose -Message "[Warning] Tenant Manifest Table [$TableName] Currently Empty!"
        Write-Verbose -Message ""

    } # End Else ($Entity -eq $null)

} # End If ($Table -ne $null)
Else
{

    # Console output with -Verbose only
    Write-Verbose -Message ""
    Write-Verbose -Message "[Warning] Tenant Manifest [$TableName] Table not found!"
    Write-Verbose -Message ""

} # End Else ($Table -ne $null)

<#

* Alternative approach to getting to the table values.

# Get a single Tenant / Table Row
$TableResult = $Table.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Retrieve(“0”, $TenantDomain))
$TableResult = $Table.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Retrieve(“0”, $Entities.Current.RowKey))
$Entity = $TableResult.Result

$TenantName = $Entity.Properties.Name.StringValue
$TenantKey =  $Entity.Properties.Key.StringValue
$StorageAccountRoot = $Entity.Properties.StorageAccountRoot.StringValue
$DBServer = $Entity.Properties.DBServer.StringValue
$SSASServer1 = $Entity.Properties.SSASServer1.StringValue
$SSASServer2 = $Entity.Properties.SSASServer2.StringValue
$TenantActive = $Entity.Properties.Active.StringValue
$RowKey = $Entities.Current.RowKey

#>

# Mark the finish time.
$FinishTime = Get-Date
Write-Verbose -Message "Finish Time ($($FinishTime.ToLocalTime()))."

# Console output with -Verbose only
$TotalTime = ($FinishTime - $StartTime).Seconds
Write-Verbose -Message "Elapse Time (Seconds): $TotalTime"
Write-Verbose -Message ""


#endregion Main