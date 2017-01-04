<# 
.SYNOPSIS 
    This PowerShell script is intended to be executed remotely to create a new Sql Server 2014 Analysis Server VM using an
	Azure AD credential with proper RBAC permissions to create such a group.  This PowerShell Script makes it easier
    to create a Sql Server 2014 Analysis Server VM instead of using the Management Portal interactively.
.DESCRIPTION 
    This creates one Sql Server 2014 Analysis Server VM from the command line arguments passed into it.

    Key values that need to be known or determined prior to excution are the Environment (Development, Test, Stage, Production),
    which determines the Subnet to be used, along with the Private TCP/IP address to be assigned.

    Additionally, the Storage Account type must match that of the VM size. For example, DS/GS Series VMs require Premium Storage.
.NOTES 
    File Name  : Create-AzureRmVM-SSAS.ps1
               :
    Author     : Ron Bokleman - ron.bokleman@bluemetal.com
               :
    Requires   : PowerShell V5 or above, PowerShell / ISE Elevated, Microsoft Azure PowerShell v1.4.0 May 2016
			   : from the Web Platform Installer.
               :
    Requires   : Azure Subscription needs to be setup in advance and you must know the name.
			   : The executor will be prompted for valid OrgID/MicrosoftID credentials.
               : User must have sufficient privledges to create a new Sql Server 2014 Analysis Server VM within the
               : Resource Group within the specified subscription.
               :
    Requires   : MUST understand the existing Azure VNet and Subnet design as well as the available TCP/IP Addresses available
               : to be assigned to the VM.
               :
    Requires   : MUST understand the use the pre-exsting Standard / Premium Azure storage accounts as the $AzureSAName chosen must match the
               : $AzureSAType chosen.
               :
    Requires   : MUST select a username/password for the initial local administrator account to be created.
               :
    Optional   : This can be called from a .bat file as desired to create one or more Azure Resource Groups.
			   : An example is included which demonstrates how to provide input for a Sql Server 2014 Analysis Server VM
			   : within a Resource Group.
               :
    Created    : 04/17/2016
	Updated	   : 04/21/2016 v1.0
	Updated    : 05/23/2016 v1.1 Tested with PowerShell v1.4.0 and revised help.  Added SQL ConfigurationFile.ini's for Dev/Tst.
    Updated    : 06/09/2016 v1.2 Updated missing -Tag option for the $PIP (Public IP).
 	
    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help ./Create-AzureRmVM-SSAS.ps1 [Null], [-Full], [-Detailed], [-Examples]

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
.PARAMETER AzureRGEnvironmentName
    Example: "Development"
.PARAMETER AzureRGTenantName
    Example: "Common"
.PARAMETER VNetName
    Example: "AppSuite"
.PARAMETER VMName
    Example: "SSAS-DEV01"
.PARAMETER PrivateIPAddress
    Example: "10.125.128.134"
.PARAMETER VMSize
    Example: "Standard_A3"
.PARAMETER AzureSAName
    Example: "sasdcs"
.PARAMETER AzureSAType
    Example: "Standard_GRS"
.EXAMPLE
    ./Create-AzureRmVM-SSAS.ps1 Create-AzureRmVM-SSAS.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGEnvironmentName "Development" -AzureRGTenantName "Common" -VNetName "AppSuite" -VMName "SSAS-DEV01" -PrivateIPAddress "10.125.128.132" -VMSize "Standard_A3" -AzureSAName "sasdcs" -AzureSAType "Standard_GRS" -Verbose
.EXAMPLE
    ./Create-AzureRmVM-SSAS.ps1 "AppSuite" "East US 2" "Development" "Common" "AppSuite" "SSAS-DEV01" "10.125.128.132" "Standard_A3" "sasdcs" "Standard_GRS" -Verbose
.INPUTS
    The [Subscription] parameter is the name of the Azure subscription.

    The [AzureRegion] parameter is the name of the Azure Region/Location to host the Resource Group(s) for this subscription.

    The [AzureRGEnvironmentName] parameter is the name of the Environment (Development, Test, Stage, Production) where the VM will be created.

    The [AzureRGTenantName] parameter is the name of the Tenant (Common, StewardHealthcare) where the VM will be created.

    The [VNetName] parameter is the name of the Azure VNet established to host the VM.

    The [VMName] parameter is the name of the VM to be created.

    The [PrivateIPAddress] parameter is the name of the private TCP/IP address to assign to this VM and MUST be within the range of the Subnet chosen.

    The [VMSize] parameter is the name of the initial Azure VM size to be applied to this VM.

    The [AzureSAName] parameter is the name of the EXISTING Azure Storage Account to host the disks assigned to this VM.

    The [AzureSAType] parameter is the name of the Azure Storage Account type (Standard, Premium).
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
    [String]$AzureRGEnvironmentName,
    [Parameter(Mandatory=$True, Position=3, HelpMessage='The Tenant name of the Azure Resource Group to update.')]
    [String]$AzureRGTenantName,
    [Parameter(Mandatory=$True, Position=4, HelpMessage='The name of the VNet to place the VM.')]
    [String]$VNetName,
    [Parameter(Mandatory=$True, Position=5, HelpMessage='The name of the VM.')]
    [String]$VMName,
    [Parameter(Mandatory=$True, Position=6, HelpMessage='The private TCP/IP address to assign the VM within the range of the VNet/Subnet chosen.')]
    [String]$PrivateIPAddress,
    [Parameter(Mandatory=$True, Position=7, HelpMessage='The Azure VM Role Size.')]
    [String]$VMSize,
    [Parameter(Mandatory=$True, Position=8, HelpMessage='The Azure Storage Account in which to store the virtual disks of the VM.')]
    [String]$AzureSAName,
    [Parameter(Mandatory=$True, Position=9, HelpMessage='The Azure Storage Account type.')]
    [String]$AzureSAType
    )

#region Variables
<#

Sample variables for bypassing the script parameters for testing.

[string]$Subscription = "AppSuite"
[string]$AzureRegion = "East US 2"
[string]$AzureRGEnvironmentName = "Development"
[string]$AzureRGTenantName = "Common"
[string]$VNetName = "AppSuite"
[string]$VMName = "SSAS-DEV03"
[string]$PrivateIPAddress = "10.125.128.134"
[string]$VMSize = "Standard_A3"
[string]$AzureSAName = "sasdcs"
[string]$AzureSAType = "Standard_GRS"

[string]$VMPassword = "Password.1"

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



#region Add-DataDisk()

Function Add-DataDisk()
{

Param  ([string]$ResourceGroup, [string]$VMName, [string]$LUN, [string]$DiskSize, [string]$DiskLabel, [string]$Uri)

#region Add a new data disk and attach it to the virtual machine.

    # Console output
    Write-Verbose -Message "[Start] Adding new Azure data disk to $VMName."

    # Create the disk and add it to the virtual machine.
    $VM = Get-AzureRmVM -ResourceGroupName $ResourceGroup -Name $VMName
    Add-AzureRmVMDataDisk -VM $VM -CreateOption Empty -DiskSizeInGB $DiskSize -Name $DiskLabel -LUN $LUN -Caching ReadWrite -VhdUri $($Uri + "vhds/" + $VMName + "_" + $DiskLabel + ".vhd")
    Update-AzureRmVM -ResourceGroupName $ResourceGroup -VM $VM

    # Console output
    Write-Verbose -Message "[Finish] Added new Azure data disk to $VMName."

#endregion Add a new data disk and attach it to the virtual machine.

} # End Add-DataDisk()

#endregion Add-DataDisk()



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


# Ensure that the VMName is available.
$CheckDNS = Test-AzureRmDnsAvailability -DomainNameLabel $VMName.ToLower() -Location $AzureRegion

If ($CheckDNS)
{
    # Get the AppSuite VNet
    $VNet = Get-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName "Subscription_Common"

    # Get the AppSuite Subnet 
    $SubNet = $VNet.Subnets | where { $_.Name –eq $($AzureRGEnvironmentName + "_" + $AzureRGTenantName) }

    # Create the Static Public IP Address for the VM
    $NICName = $VMName
    $PIP = New-AzureRmPublicIpAddress -Name $NICName -ResourceGroupName $($AzureRGEnvironmentName + "_" + $AzureRGTenantName) -Location $AzureRegion -AllocationMethod Static -DomainNameLabel $VMName.ToLower() -Tag @{Name="Environment";Value=$AzureRGEnvironmentName}, @{Name="Tenant";Value=$AzureRGTenantName}

    # Create the network interface
    $NIC = New-AzureRmNetworkInterface -Name $NICName -ResourceGroupName $($AzureRGEnvironmentName + "_" + $AzureRGTenantName) -Location $AzureRegion -SubnetId $SubNet.Id -PublicIpAddressId $PIP.Id -PrivateIpAddress $PrivateIPAddress -Tag @{Name="Environment";Value=$AzureRGEnvironmentName}, @{Name="Tenant";Value=$AzureRGTenantName}

    # Create Availablity Set Object
    $AVSet = New-AzureRmAvailabilitySet -Location $AzureRegion –Name $($AzureRGEnvironmentName + "_" + $AzureRGTenantName) –ResourceGroupName $($AzureRGEnvironmentName + "_" + $AzureRGTenantName) -ErrorAction SilentlyContinue

    # Create VM Configuration
    New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize -AvailabilitySetId $AVSet.Id | Tee-Object -Variable NewVM

    # Setup VM Parameters
    $Credentials = Get-Credential -Message "Type the name and password of the local administrator account."

    Set-AzureRmVMOperatingSystem -VM $NewVM -Windows -ComputerName $VMName -Credential $Credentials -ProvisionVMAgent -EnableAutoUpdate
    Set-AzureRmVMSourceImage -VM $NewVM -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2012-R2-Datacenter -Version "latest"
    Add-AzureRmVMNetworkInterface -VM $NewVM -Id $NIC.Id

    $OSDiskName = $($VMName + "_OSDisk")
    $SA = Get-AzureRmStorageAccount -ResourceGroupName $($AzureRGEnvironmentName + "_" + $AzureRGTenantName) -Name $AzureSAName

    $OSDiskUri = $SA.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName  + ".vhd"
    Set-AzureRmVMOSDisk -VM $NewVM -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption fromImage

    # Create VM based upon VM Configuration
    New-AzureRmVM -ResourceGroupName $($AzureRGEnvironmentName + "_" + $AzureRGTenantName) -Location $AzureRegion -VM $NewVM -Tags @{Name="Environment";Value=$AzureRGEnvironmentName}, @{Name="Tenant";Value=$AzureRGTenantName}

    Add-DataDisk -ResourceGroup $($AzureRGEnvironmentName + "_" + $AzureRGTenantName) -VMName $VMName -DiskSize 512 -LUN 0 -DiskLabel "Data" -Uri $SA.PrimaryEndpoints.Blob.ToString()

}
Else
{
    # Console output with -Verbose only
	Write-Verbose -Message "[Error:$PSScriptName] $VMName already exists."
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