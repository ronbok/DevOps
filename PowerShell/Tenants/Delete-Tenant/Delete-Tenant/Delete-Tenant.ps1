<# 
.SYNOPSIS 
    This PowerShell script is intended to be executed remotely to delete an existing Steward AppSuite Tenant using an
	Azure AD credential with proper RBAC permissions to create such a group.  This PowerShell Script makes it easier
    to delete an existing Steward AppSuite Tenant instead of using the Management Portal interactively.
.DESCRIPTION 
    This deletes one Steward AppSuite Tenant from the Tenant Manifest.  It also deletes the Resource Group for the Tenant
    and all related resources that exist in _Common Resource Groups.

.NOTES 
    File Name  : Delete-Tenant.ps1
               :
    Author     : Ron Bokleman - ron.bokleman@bluemetal.com
               :
    Requires   : PowerShell V5 or above, PowerShell / ISE Elevated, Microsoft Azure PowerShell v1.4.0 May 2016
			   : from the Web Platform Installer.
               :
    Requires   : Azure Subscription needs to be setup in advance and you must know the name.
			   : The executor will be prompted for valid OrgID/MicrosoftID credentials.
               : User must have sufficient privledges to create a new Resource Group within the specified subscription.
               :
    Optional   : This can be called from a .bat file as desired to delete an existing Steward AppSuite Tenant.
			   : An example is included which demonstrates how to provide input for deleting an existing Steward AppSuite Tenant.
               :
    Created    : 03/08/2016
	Updated	   : 03/16/2016 v1.0
	Updated    : 03/23/2016 v1.1 Bug fix for truncating the tenant manifest table name incorreclty.
    Updated    : 04/14/2016 v1.2 Updated to support changes in the tenant manifest table schema.
    Updated    : 05/13/2016 v1.3 Crtical update to fix PowerShell v1.4.0 breaking changes to Get-AzureRmStorageAccountKey.
	Updated    : 06/14/2016 v1.4 Fixed critical error with database names being case sensitive in Azure.
	Updated    : 06/15/2016 v1.5 Added the removal of the Key Vault tenant encryption key.
	Updated    : 06/20/2016 v1.5 Changed the method to create and store the tenant specific encryption key in the Key Vault.
    Updated    : 06/24/2016 v1.6 Added Service Bus .dll in order to delete existing tenant queues.
	Updated    : 07/12/2016 v1.7 Added the removal of the Key Vault tenant storage account access key.
	
    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help ./Delete-Tenant.ps1 [Null], [-Full], [-Detailed], [-Examples]

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
.PARAMETER KVName
    Example: "ssasdcs"
.PARAMETER TenantName
    Example: "StewardHealthcare"
.PARAMETER TenantDomain
    Example: "steward.org"
.EXAMPLE
    ./Delete-Tenant.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGName "Subscription_Common" -AzureSAName "sassubcom1" -TableName "TMDevelopment" -KVName "sasdcs" -TenantDomain "steward.org" -Verbose
.EXAMPLE
    ./Delete-Tenant.ps1 "AppSuite" "East US 2" "Subscription_Common" "sassubcom1" "TMDevelopment" "sasdcs" "steward.org" -Verbose
.INPUTS
    The [Subscription] parameter is the name of the Azure subscription.

    The [AzureRegion] parameter is the name of the Azure Region/Location.

    The [AzureRGName] parameter is the name of the Azure Resource Group where the Tenant Manifest Table is stored.

    The [AzureSAName] parameter is the name of the Storage Account where the Tenant Manifest Table is stored.

    The [TableName] parameter is the name of Tenant Manifest Table to delete the row for this tenant.

	The [KVName] parameter is the name of Key Vault to remove the encypriton key used to encrypt the tenant specific data files ingested by the AppSuiteIngestionAPI[Environment].

    The [TenantDomain] parameter is the name of the FQDN of the Tenant.
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
    [Parameter(Mandatory=$True, Position=2, HelpMessage='The name of the Azure Resource Group to update.')]
    [string]$AzureRGName,
    [Parameter(Mandatory=$True, Position=3, HelpMessage='The Storage Account name in which the the Tenant Manifest Table to exists.')]
    [string]$AzureSAName,
    [Parameter(Mandatory=$True, Position=4, HelpMessage='The Azure Table to work with.')]
    [string]$TableName,
	[Parameter(Mandatory=$True, Position=5, HelpMessage='The Azure Key Vault where the Tenant Encryption Key was stored.')]
    [string]$KVName,
    [Parameter(Mandatory=$True, Position=6, HelpMessage='The Steward AppSuite Tenant (FQDN) Domain Name.')]
    [string]$TenantDomain
    )

#region Variables
<#

Sample variables for bypassing the script parameters for testing.

[string]$Subscription = "AppSuite"
[string]$AzureRegion = "East US 2"
[string]$AzureRGName = "Subscription_Common"
[string]$AzureSAName = "sassubcom1"

[string]$TableName = "TMDevelopment"
[string]$TableName = "TMTest"
[string]$TableName = "TMStage"
[string]$TableName = "TMProduction"

[string]$KVName = "sasdcs"
[string]$KVName = "sastcs"
[string]$KVName = "sasscs"
[string]$KVName = "saspcs"

[string]$TenantDomain = "steward.org"

[string]$TenantDomain = "bluemetal.com"

[string]$TenantDomain = "capecod.org"

[string]$TenantDomain = "southshore.org"

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



#region Delete-Entity()

Function Delete-Entity()
{

    param($Entity)

    If ($Entity -ne $null)
    {
        
        $TenantName = $Entity.Properties.Name.StringValue

        # Console output with -Verbose only
        Write-Verbose -Message ""
        Write-Verbose -Message "[Start] Attempting to delete tenant: $TenantName."
        Write-Verbose -Message ""

        #Delete the entity.
        $Result = $Table.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Delete($Entity))

        # Console output with -Verbose only
        Write-Verbose -Message ""
        Write-Verbose -Message "[Finish] Deleted tenant: $TenantName."
        Write-Verbose -Message ""

    } # End If

    Return $Result

} # End Function

#endregion Delete-Entity()



#region Get-Entity()

Function Get-Entity()
{
    param([string]$TenantDomain)

    # Get table row
    $TableResult = $Table.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Retrieve(“0”, $TenantDomain))
    $Entity = $TableResult.Result

    Return $Entity

} # End Function

#endregion Get-Entity()



#region Import-ServiceBusDLL()

Function Import-ServiceBussDLL
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
        
} #End Function Import-ServiceBussDLL

#endregion Import-ServiceBusDLL()



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

#Define the storage account and context.
$KeyTM = (Get-AzureRmStorageAccountKey -Name $AzureSAName -ResourceGroupName $AzureRGName)[0]
$SaCTM = New-AzureStorageContext -StorageAccountName $AzureSAName -StorageAccountKey $KeyTM.Value

# Console output with -Verbose only
Write-Verbose -Message "[Start] Attempting to retrieve Tenant Manifest table $TableName."
Write-Verbose -Message ""

#Retrieve the table if it already exists.
$Table = Get-AzureStorageTable –Name $TableName -Context $SaCTM -ErrorAction Stop

# If we don't already have a $TenantDomain row in our $TableName, then we will proceed to Delete-Entity, otherwise we fail.
If ($Table -ne $null)
{

    # Console output with -Verbose only
    Write-Verbose -Message "[Finish] Retrieved Tenant Manifest table $TableName."
    Write-Verbose -Message ""

    # Console output with -Verbose only
    Write-Verbose -Message "[Start] Attempting to retrieve Tenant $TenantDomain Tenant Manifest $TableName."
    Write-Verbose -Message ""

    # Check to see if we have a $TenantDomain row in our Table.
    $Entity = Get-Entity -TenantDomain $TenantDomain

    # If we already have a $TenantDomain row in our $TableName, then we will proceed to Delete-Entity, otherwise we issue a warning.
    If ($Entity -ne $null)
    {

        # Console output with -Verbose only
        Write-Verbose -Message "[Start] Tenant $TenantDomain in Tenant Manifest $TableName exists. Deleting..."
        Write-Verbose -Message ""

        # Since ALL of the Tenant Manifest dabases are name TM(Environemnt) we will trim off the TM to figure out into which Environment we need to place this tenant.
        $AzureRGEnvironmentName = $TableName.Replace("TM","")

        # Deleteing the tenants main Resource Group
        Remove-AzureRmResourceGroup -Name $($AzureRGEnvironmentName + "_" + $($Entity.Properties.Name.StringValue)) -Force
        
        # Get the storage account context for the database audit logs are located, so we can clean up the mess left behind by Azure.
        $KeyLog = (Get-AzureRmStorageAccountKey -Name "sassubcom2" -ResourceGroupName $AzureRGName)[0]
        $SaCLog = New-AzureStorageContext -StorageAccountName "sassubcom2" -StorageAccountKey $KeyLog.Value

		# Because of the changes on 05/13/2016 getting the $DBServer became more complex... as this code was intended to account for
        # moving of the tenants databases to another Azure Sql Server instance in the future.  This code simplies the input required
        # to execute that change by just specifying the actual server name.
		$DBServer = ($($Entity.Properties.MDSConnectionString.StringValue).Split(";")[0]).ToLower().Replace("server=","")
        $DBServer = $DBServer.Split(".")[0].Replace("tcp:","")

        # Microsoft messed up the database names and for some reason they are CASE SENSITIVE.  So we now have to parse the crap out of this to get the proper case.
        $DatabaseName = $($Entity.Properties.MDSConnectionString.StringValue).Split(";")[1].Replace("database=","")
        $DatabasePrefix = $DatabaseName.Split("_")[0].ToLower()
        $DatabaseSuffix = $DatabaseName.Split("_")[1].ToUpper()

        # Delete the MasterDataStore Database and Audit Logs
        Remove-AzureRmSqlDatabase -ServerName $DBServer -DatabaseName $($DatabasePrefix + "_" + $DatabaseSuffix) -ResourceGroupName $($AzureRGEnvironmentName + "_Common") -Force
        
        # Delete the Audit Log
        Get-AzureStorageTable -Context $SaCLog | Where {$_.Name -like "SQLDBAuditLogs" + $($Entity.Properties.Key.StringValue) +"*"} | Remove-AzureStorageTable -Force

        # $FullAuditLogsTableName = (Get-AzureRmSqlDatabaseAuditingPolicy -ServerName $Entity.Properties.DBServer.StringValue -DatabaseName $($Entity.Properties.Key.StringValue + "_MDS") -ResourceGroupName $($AzureRGEnvironmentName + "_Common")).TableIdentifier
        # Remove-AzureStorageTable -Name $FullAuditLogsTableName -Context -Force

		# Because of the changes on 05/13/2016 getting the $DBServer became more complex... as this code was intended to account for
        # moving of the tenants databases to another Azure Sql Server instance in the future.  This code simplies the input required
        # to execute that change by just specifying the actual server name.
		$DBServer = ($($Entity.Properties.DMConnectionString.StringValue).Split(";")[0]).ToLower().Replace("server=","")
        $DBServer = $DBServer.Split(".")[0].Replace("tcp:","")

        # Microsoft messed up the database names and for some reason they are CASE SENSITIVE.  So we now have to parse the crap out of this to get the proper case.
        $DatabaseName = $($Entity.Properties.DMConnectionString.StringValue).Split(";")[1].Replace("database=","")
        $DatabasePrefix = $DatabaseName.Split("_")[0].ToLower()
        $DatabaseSuffix = $DatabaseName.Split("_")[1].ToUpper()

        # Delete the DigestedModel Database and Audit Logs
        Remove-AzureRmSqlDatabase -ServerName $DBServer -DatabaseName $($DatabasePrefix + "_" + $DatabaseSuffix) -ResourceGroupName $($AzureRGEnvironmentName + "_Common") -Force
        
        # Delete the Audit Log
        Get-AzureStorageTable -Context $SaCLog | Where {$_.Name -like "SQLDBAuditLogs" + $($Entity.Properties.Key.StringValue) +"*"} | Remove-AzureStorageTable -Force
        
        # $FullAuditLogsTableName = (Get-AzureRmSqlDatabaseAuditingPolicy -ServerName $Entity.Properties.DBServer.StringValue -DatabaseName $($Entity.Properties.Key.StringValue + "_DigestedModel") -ResourceGroupName $($AzureRGEnvironmentName + "_Common")).TableIdentifier
        # Remove-AzureStorageTable -Name $FullAuditLogsTableName -Context -Force

		# Because of the changes on 05/13/2016 getting the $DBServer became more complex... as this code was intended to account for
        # moving of the tenants databases to another Azure Sql Server instance in the future.  This code simplies the input required
        # to execute that change by just specifying the actual server name.
		$DBServer = ($($Entity.Properties.RMConnectionString.StringValue).Split(";")[0]).ToLower().Replace("server=","")
        $DBServer = $DBServer.Split(".")[0].Replace("tcp:","")

        # Microsoft messed up the database names and for some reason they are CASE SENSITIVE.  So we now have to parse the crap out of this to get the proper case.
        $DatabaseName = $($Entity.Properties.RMConnectionString.StringValue).Split(";")[1].Replace("database=","")
        $DatabasePrefix = $DatabaseName.Split("_")[0].ToLower()
        $DatabaseSuffix = $DatabaseName.Split("_")[1].ToUpper()


        # Delete the RecordModel Database and Audit Logs
        Remove-AzureRmSqlDatabase -ServerName $DBServer -DatabaseName $($DatabasePrefix + "_" + $DatabaseSuffix) -ResourceGroupName $($AzureRGEnvironmentName + "_Common") -Force
        
        # Delete the Audit Log
        Get-AzureStorageTable -Context $SaCLog | Where {$_.Name -like "SQLDBAuditLogs" + $($Entity.Properties.Key.StringValue) +"*"} | Remove-AzureStorageTable -Force

        # $FullAuditLogsTableName = (Get-AzureRmSqlDatabaseAuditingPolicy -ServerName $Entity.Properties.DBServer.StringValue -DatabaseName $($Entity.Properties.Key.StringValue + "_RecordModel") -ResourceGroupName $($AzureRGEnvironmentName + "_Common")).TableIdentifier
        # Remove-AzureStorageTable -Name $FullAuditLogsTableName -Context -Force

        # Console output with -Verbose only
    	Write-Verbose -Message ""
		Write-Verbose -Message "[Start] Removing file encryption secret [$("IngestionEncryptionKey-"+$Entity.Properties.Key.StringValue)] from Key Vault [$KVName]."
		Write-Verbose -Message ""

		# Remove-AzureKeyVaultKey -VaultName $KVName -Name $($Entity.Properties.Key.StringValue) -Force -Confirm:$False
        Remove-AzureKeyVaultSecret -VaultName $KVName -Name $("IngestionEncryptionKey-"+$Entity.Properties.Key.StringValue) -Force -Confirm:$False

        # Console output with -Verbose only
    	Write-Verbose -Message ""
		Write-Verbose -Message "[Finish] Removed file encryption secret [$("IngestionEncryptionKey-"+$Entity.Properties.Key.StringValue)] from Key Vault [$KVName]."
		Write-Verbose -Message ""

		# Console output with -Verbose only
    	Write-Verbose -Message ""
		Write-Verbose -Message "[Start] Removing Storage Account Key1 secret [$("IngestionStorageAccountKey-"+$Entity.Properties.Key.StringValue)] from Key Vault [$KVName]."
		Write-Verbose -Message ""

		# Remove-AzureKeyVaultKey -VaultName $KVName -Name $($Entity.Properties.Key.StringValue) -Force -Confirm:$False
        Remove-AzureKeyVaultSecret -VaultName $KVName -Name $("IngestionStorageAccountKey-"+$Entity.Properties.Key.StringValue) -Force -Confirm:$False

        # Console output with -Verbose only
    	Write-Verbose -Message ""
		Write-Verbose -Message "[Finish] Removed Storage Account Key1 secret [$("IngestionStorageAccountKey-"+$Entity.Properties.Key.StringValue)] from Key Vault [$KVName]."
		Write-Verbose -Message ""

        $Status = Delete-Entity $Entity

    } # End If ($Entity -eq $null)
    Else
    {

        # Console output with -Verbose only
        Write-Verbose -Message ""
        Write-Verbose -Message "[Warning] Tenant: $TenantName does not exist!"
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

# Mark the finish time.
$FinishTime = Get-Date
Write-Verbose -Message "Finish Time ($($FinishTime.ToLocalTime()))."

# Console output with -Verbose only
$TotalTime = ($FinishTime - $StartTime).Minutes
Write-Verbose -Message "Elapse Time (Minutes): $TotalTime"
Write-Verbose -Message ""


#endregion Main