<# 
.SYNOPSIS 
    This PowerShell script is intended to be executed remotely to update an existing Steward AppSuite Tenant using an
	Azure AD credential with proper RBAC permissions.  This PowerShell Script makes it easier to update an Steward
    AppSuite Tenant instead of using the Management Portal interactively.
.DESCRIPTION 
    This updates limited Tenant Manifest values per tenant.  Currently it does not support changing the Tenants $DBServer, or
    $StorageAccountRoot, or unique $TenantKey.  However a future version could support updating $DBServer provided that any existing
    databases could be moved to another Azure Sql Database Server.  Given the design of a Storage Account being prefixed with the
    $TenantKey, it is doubtful that any changes to the tenant Storage Account would be desirable or necessary.

    It is *STRONGLY* recommended that List-Tenant.ps1 or List-AllTenants.ps1 be executed prior to running Update-Tenant.ps1.  Doing
    so will ensure the current values are available should they be required again.
.NOTES 
    File Name  : Update-Tenant.ps1
               :
    Author     : Ron Bokleman - ron.bokleman@bluemetal.com
               :
    Requires   : PowerShell V5 or above, PowerShell / ISE Elevated, Microsoft Azure PowerShell v1.4.0 May 2016
			   : from the Web Platform Installer.
               :
    Requires   : Azure Subscription needs to be setup in advance and you must know the name.
			   : The executor will be prompted for valid OrgID/MicrosoftID credentials.
               : User must have sufficient privledges to update the Tenant Manifest Table.
               :
    Optional   : This can be called from a .bat file as desired to update an existing Steward AppSuite Tenant.
			   : An example is included which demonstrates how to provide input for updating a Steward AppSuite Tenant.
               :
    Created    : 03/11/2016
	Updated	   : 03/16/2016 v1.0
	Updated    : 04/15/2016 v1.1 Updated to support tenant manifest schema changes.
    Updated    : 05/10/2016 v1.2 Updated to support tenant manifest sql database (MDS, RM, DM) connection string changes.
    Updated    : 05/13/2016 v1.3 Crtical update to fix PowerShell v1.4.0 breaking changes to Get-AzureRmStorageAccountKey.
    Updated    : 05/13/2016 v1.3 Updated to support tenant manifest sql database (MDS, RM, DM, SSAS) connection string changes.
	Updated    : 05/27/2016 v1.4 Updated to now allow the switching of SSAS VMs both Primary and Secondary and back as needed.
	Updated    : 06/15/2016 v1.5 Updated to remove Azure SQL Database passwords from Tenant Manifest.
	
    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help ./Update-Tenant.ps1 [Null], [-Full], [-Detailed], [-Examples]

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
.PARAMETER TenantName
    Example: "StewardHealthcare"
.PARAMETER TenantDomain
    Example: "steward.org"
.PARAMETER DBServer
    Example: "sasdevelopment1"
.PARAMETER SSASServer1
    Example "sass-dev01"
.PARAMETER SSASServer2
    Example:"sassdev02"
.PARAMETER Active
    Example: "Y" or "N"
.EXAMPLE
    ./Update-Tenant.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGName "Subscription_Common" -AzureSAName "sassubcom1" -TableName "TMDevelopment" -TenantName "StewardHealthcare" -TenantDomain "steward.org" -DBServer "sasdevelopment1" -SSASServer1 "ssas-dev01" -SSASServer2 "ssas-dev02" -Active "Y" -Verbose
.EXAMPLE
    ./Update-Tenant.ps1 "AppSuite" "East US 2" "Subscription_Common" "sassubcom1" "TMDevelopment" "StewardHealthcare" "steward.org" "sasdevelopment1" "ssas-dev01" "ssas-dev02" "Y" -Verbose
.INPUTS
    The [Subscription] parameter is the name of the Azure subscription.

    The [AzureRegion] parameter is the name of the Azure Region/Location to host the Virtual Machines for this subscription.

    The [AzureRGName] parameter is the name of the Azure Resource Group where the Tenant Manifest Table is stored.

    The [AzureSAName] parameter is the name of the Storage Account where the Tenant Manifest Table is stored.

    The [TableName] parameter is the name of Tenant Manifest Table to insert a new row for this tenant.

    The [TenantName] parameter is the name of the display name for this Tenant.

    The [TenantDomain] parameter is the name of the FQDN of the Tenant.

    The [DBServer] parameter is the name of Azure Sql Database Server to create the Tenant specific databases.

    The [SSASServer1] parameter is the name of SSAS Primary VM.

    The [SSASServer2] parameter is the name of of the SSAS Secondary VM.

    The [Active] parameter is the value for whether the Tenant is Active (Y or N) (or disable due to billing issue).
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
    [Parameter(Mandatory=$True, Position=3, HelpMessage='The Storage Account name in which the the Azure Table to exists.')]
    [string]$AzureSAName,
    [Parameter(Mandatory=$True, Position=4, HelpMessage='The Azure Table to work with.')]
    [string]$TableName,
    [Parameter(Mandatory=$True, Position=5, HelpMessage='The Steward AppSuite Tenant Name.')]
    [string]$TenantName,
    [Parameter(Mandatory=$True, Position=6, HelpMessage='The Steward AppSuite Tenant (FQDN) Domain Name.')]
    [string]$TenantDomain,
    [Parameter(Mandatory=$True, Position=7, HelpMessage='The desired Steward AppSuite Shared SQL Azure Database Server Name.')]
    [string]$DBServer,
    [Parameter(Mandatory=$True, Position=8, HelpMessage='The desired Primary Steward AppSuite Shared SSAS Server Name.')]
    [string]$SSASServer1,
    [Parameter(Mandatory=$True, Position=9, HelpMessage='The desired Secondary Steward AppSuite Shared SSAS Server Name.')]
    [string]$SSASServer2,
    [Parameter(Mandatory=$True, Position=10, HelpMessage='The Steward AppSuite Active Tenant Flag.')]
    [string]$Active
    )

#region Variables
<#

Sample variables for bypassing the script parameters for testing.

[string]$Subscription = "AppSuite"
[string]$AzureRegion = "East US 2"
[string]$AzureRGName = "Subscription_Common"
[string]$AzureSAName = "sassubcom1"
[string]$TableName = "TMDevelopment"

[string]$TenantName = "StewardHealthcare"
[string]$TenantDomain = "steward.org"
[string]$DBServer = "sasdevelopment1"
[string]$SSASServer1 = "ssas-dev01"
[string]$SSASServer2 = "ssas-dev02"
[string]$Active = "Y"

[string]$TenantName = "BlueMetalHealthcare"
[string]$TenantDomain = "bluemetal.com"
[string]$DBServer = "sasdevelopment2"
[string]$SSASServer1 = "ssas-dev01"
[string]$SSASServer2 = "ssas-dev02"
[string]$Active = "Y"


[string]$TenantName = "CapeCodHospital"
[string]$TenantDomain = "capecod.org"
[string]$DBServer = "sasdevelopment2"
[string]$SSASServer1 = "ssas-dev01"
[string]$SSASServer2 = "ssas-dev02"
[string]$Active = "Y"

[string]$TenantName = "SouthShoreHospital"
[string]$TenantDomain = "southshore.org"
[string]$DBServer = "sasdevelopment1"
[string]$SSASServer1 = "ssas-dev01"
[string]$SSASServer2 = "ssas-dev02"
[string]$Active = "Y"

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



#region Update-Entity()

Function Update-Entity()
{
    [CmdletBinding()]
    param(
       $table,
       [string]$PartitionKey,
       [string]$RowKey,
       [string]$TenantName,
       [string]$TenantKey,
       [string]$StorageAccountRoot,
       [string]$DBServer,
       [string]$MDSdbName,
       [string]$RMdbName,
       [string]$DMdbName,
       [string]$SSASServer1,
       [string]$SSASServer2,
       [string]$CubeName,
       [string]$Active
    )

  $Entity = New-Object -TypeName Microsoft.WindowsAzure.Storage.Table.DynamicTableEntity -ArgumentList $PartitionKey, $RowKey
  $Entity.Properties.Add("Name", $TenantName)
  $Entity.Properties.Add("Key", $TenantKey)
  $Entity.Properties.Add("StorageAccountRoot", $StorageAccountRoot)
  $Entity.Properties.Add("MDSConnectionString", "server=tcp:" + $DBServer + ".database.windows.net,1433;database=" + $MDSdbName + ";user id={0};password={1};encrypt=true;trustservercertificate=false")
  $Entity.Properties.Add("RMConnectionString", "server=tcp:" + $DBServer + ".database.windows.net,1433;database=" + $RMdbName + ";user id={0};password={1};encrypt=true;trustservercertificate=false")
  $Entity.Properties.Add("DMConnectionString", "server=tcp:" + $DBServer + ".database.windows.net,1433;database=" + $DMdbName + ";user id={0};password={1};encrypt=true;trustservercertificate=false")
  $Entity.Properties.Add("TM1ConnectionString", "datasource=" + $SSASServer1 + ";catalog=" + $CubeName)
  $Entity.Properties.Add("TM2ConnectionString", "datasource=" + $SSASServer2 + ";catalog=" + $CubeName)
  $Entity.Properties.Add("Active", $Active)

  # ETag is required or the Replace will indeed fail.
  $Entity.ETag = "*"

  # Console output with -Verbose only
  Write-Verbose -Message "[Start] Attempting to update existing tenant: $Tenantname."
  Write-Verbose -Message ""

  $Result = $Table.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Replace($Entity))

  # Console output with -Verbose only
  Write-Verbose -Message "[Finish] Updated existing tenant: $Tenantname."
  Write-Verbose -Message ""

  
} # End Function Update-Entity()

#endregion Update-Entity()



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
    # Check to see if we have a $TenantDomain row in our Table.
    $Entity = Get-Entity -TenantDomain $TenantDomain

    # If we don't already have a $TenantDomain row in our $TableName, then we will proceed to Update-Entity, otherwise we fail.
    If ($Entity -ne $null)
    {
        <#
        $oTenantName = $Entity.Properties.Name.StringValue
        $oDBServer = $Entity.Properties.DBServer.StringValue
        $oSSASServer1 = $Entity.Properties.SSASServer1.StringValue
        $oSSASServer2 = $Entity.Properties.SSASServer2.StringValue
        $oActive = $Entity.Properties.Active.StringValue
        #>

        
        # WARNING:  Do NOT EVER remove these value assignments, if the TenantKey or the Storage Account is changed the entire system for
        # this tenant will fail!!
        $TenantKey =  $Entity.Properties.Key.StringValue
        $StorageAccountRoot = $Entity.Properties.StorageAccountRoot.StringValue
        
        # Because of the changes on 05/13/2016 getting the $DBServer became more complex... as this code was intended to account for
        # moving of the tenants databases to another Azure Sql Server instance in the future.  This code simplies the input required
        # to execute that change by just specifying the actual server name.
        $DBServer = ($($Entity.Properties.MDSConnectionString.StringValue).Split(";")[0]).ToLower().Replace("server=","")
        $DBServer = $DBServer.Split(".")[0].Replace("tcp:","")
        
        $MDSdb = ($($Entity.Properties.MDSConnectionString.StringValue).Split(";")[1]).ToLower().Replace("database=","")
        $RMdb = ($($Entity.Properties.RMConnectionString.StringValue).Split(";")[1]).ToLower().Replace("database=","")
        $DMdb = ($($Entity.Properties.DMConnectionString.StringValue).Split(";")[1]).ToLower().Replace("database=","")
        
        # $SSASServer1 = $($Entity.Properties.TM1ConnectionString.StringValue).Split(";")[0].Replace("datasource=","")
        # $SSASServer2 = $($Entity.Properties.TM2ConnectionString.StringValue).Split(";")[0].Replace("datasource=","")
        $Catalog = ($($Entity.Properties.TM1ConnectionString.StringValue).Split(";")[1].Replace("catalog=","")).ToLower()
        # WARNING:  Do NOT EVER remove these value assignments, if the TenantKey or the Storage Account is changed the entire system for
        # this tenant will fail!!

        # Update
        Update-Entity -Table $Table -PartitionKey 0 -RowKey $TenantDomain -TenantName $TenantName -TenantKey $TenantKey -StorageAccountRoot $StorageAccountRoot -DBServer $DBServer -MDSdbName $MDSdb -RMdbName $RMdb -DMdbName $DMdb -SSASServer1 $SSASServer1 -SSASServer2 $SSASServer2 -CubeName $Catalog -Active $Active

        # Create a table query.
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

        $Query.FilterString = "RowKey eq '$($TenantDomain)'"
        $Query.SelectColumns = $List

        # Execute the query.
        $Entities = $Table.CloudTable.ExecuteQuery($Query)

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
        Write-Verbose -Message "[Warning] Tenant Manifest Table [$TableName] does not contain an entry for $TenantDomain!"
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
$TotalTime = ($FinishTime - $StartTime).Seconds
Write-Verbose -Message "Elapse Time (Seconds): $TotalTime"
Write-Verbose -Message ""


#endregion Main