<# 
.SYNOPSIS 
    This PowerShell script is intended to be executed remotely to create a new pair of Domain Controllers VMs using an
	Azure AD credential with proper RBAC permissions to create such a resource.
.DESCRIPTION 
    This creates two new Domain Controllers VMs from the command line arguments passed into it.

    Key values that need to be known or determined prior to excution are the Environment (Subscription, Development, Test, Stage, Production),
    which determines the Subnet to be used, along with the Private TCP/IP address to be assigned.

    Additionally, the Storage Account type must match that of the VM size. For example, DS/GS Series VMs require Premium Storage.
.NOTES 
    File Name  : Create-AzureRmVM-DC.ps1
               :
    Author     : Ron Bokleman - ron.bokleman@bluemetal.com
               :
    Requires   : PowerShell V5 or above, PowerShell / ISE Elevated, Microsoft Azure PowerShell v2.0.1 August 2016
			   : from the Web Platform Installer.
               :
    Requires   : Azure Subscription needs to be setup in advance and you must know the name.
			   : The executor will be prompted for valid OrgID/MicrosoftID credentials.
               : User must have sufficient privledges to create a new VMs within the
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
	Requires   : MUST have already established an instance of Key Vault (Stardard) in which to store the required self-signed X.509 Certificate
	           : for use by WinRM.
               :
    Optional   : This can be called from a .bat file as desired to create one or more Azure Resource Groups.
			   : An example is included which demonstrates how to provide input for the VMs
			   : within a Resource Group.
               :
    Created    : 08/31/2016
	Updated	   : 08/31/2016 v1.0
    Updated    : 09/02/2016 v1.1 Support added for second domain controller.
 	
    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help ./Create-AzureRmVM-DC.ps1 [Null], [-Full], [-Detailed], [-Examples]

.LINK
    Additional Information:
    
    https://msdn.microsoft.com/en-us/library/mt125356.aspx
    
    Connect with Me: 
    
    http://ronbokleman.wordpress.com
    http://www.linkedin.com/pub/ron-bokleman/1/14b/200

.PARAMETER Subscription
    Example:  Subcription Name i.e. "Ron Bokleman"
.PARAMETER AzureRegion
    Example:  "East US 2"
.PARAMETER AzureRGEnvironmentName
    Example: "Subscription"
.PARAMETER AzureRGTenantName
    Example: "Common"
.PARAMETER VNetName
    Example: "RONBOK"
.PARAMETER VMName
    Example: "RonBok-DC01,RonBok-DC02"
.PARAMETER PrivateIPAddress
    Example: "10.125.132.4,10.125.132.5"
.PARAMETER VMSize
    Example: "Standard_A2"
.PARAMETER AzureSAName
    Example: "ronboksubcom1"
.PARAMETER AzureSAType
    Example: "Standard_GRS"
.PARAMETER KeyVaultRGName
    Example: "Subscription_Common"
.PARAMETER KeyVaultName
    Example: "ronboksubcoms"
.PARAMETER DomainName
    Example: "ronbok.us"
.PARAMETER UserName
    Example: "ronbokadmin"
.EXAMPLE
    ./Create-AzureRmVM-DC.ps1 -Subscription "Ron Bokleman" -AzureRegion "East US 2" -AzureRGEnvironmentName "Subscription" -AzureRGTenantName "Common" -VNetName "RONBOK" -VMName "RonBok-DC01" -PrivateIPAddress "10.125.132.4" -VMSize "Standard_A2" -AzureSAName "ronboksubcom1" -AzureSAType "Standard_GRS" -KeyVaultRGName "Subscription_Common" -KeyVaultName "ronboksubcoms" -DomainName "ronbok.us" -UserName "ronbokadmin" -Verbose
.EXAMPLE
    ./Create-AzureRmVM-DC.ps1 "Ron Bokleman" "East US 2""Subscription" "Common" "RONBOK" "RonBok-DC01" "10.125.132.4" "Standard_A2" "ronboksubcom1" "Standard_GRS" "Subscription_Common" "ronboksubcoms" "ronbok.us" "ronbokadmin" -Verbose
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

    The [KeyVaultRGName] parameter is the name of the Resource Group containing the Key Vault name in which to store the X.509 Certificate for WinRM.

    The [KeyVaultName] parameter is the name of the Azure Key Vault name in which to store the X.509 Certificate for WinRM.

    The [DomainName] parameter is the name of the Domain Name for the new AD Forest.
    
    The [UserName] parameter is the name of the inital local Administrator account.
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
    [String]$AzureSAType,
    [Parameter(Mandatory=$True, Position=10, HelpMessage='The Resource Group containing the Key Vault name in which to store the X.509 Certificate for WinRM.')]
    [String]$KeyVaultRGName,
    [Parameter(Mandatory=$True, Position=11, HelpMessage='The Azure Key Vault name in which to store the X.509 Certificate for WinRM.')]
    [String]$KeyVaultName,
    [Parameter(Mandatory=$True, Position=12, HelpMessage='The Domain Name for the new AD Forest.')]
    [String]$DomainName,
    [Parameter(Mandatory=$True, Position=13, HelpMessage='The inital local Administrator account.')]
    [String]$UserName
    )

#region Variables
<#

Sample variables for bypassing the script parameters for testing.

[string]$Subscription = "Ron Bokleman"
[string]$AzureRegion = "East US 2"
[string]$AzureRGEnvironmentName = "Subscription"
[string]$AzureRGTenantName = "Common"
[string]$VNetName = "RONBOK"
[string]$VMName = "RonBok-DC01,RonBok-DC02"
[string]$PrivateIPAddress = "10.125.132.4,10.125.132.5"
[string]$VMSize = "Standard_A2"
[string]$AzureSAName = "ronboksubcom1"
[string]$AzureSAType = "Standard_GRS"
[string]$KeyVaultRGName = "Subscription_Common"
[string]$KeyVaultName = "ronboksubcoms"
[string]$DomainName = "ronbok.us"
[string]$UserName = "ronbokadmin"

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



#region Create-Certificate()

Function Create-Certificate()
{

Param  ([string]$VMName, [bool]$ISE, [string]$CertPassword)

    # Console output
    Write-Verbose -Message "[Start] Creating new X.509 Self-Signed Certificate for $VMName."

    $CertificateName = $VMName.ToLower()
	$Thumbprint = (New-SelfSignedCertificate -DnsName $CertificateName -CertStoreLocation Cert:\CurrentUser\My -KeySpec KeyExchange).Thumbprint
	$Certificate = (Get-ChildItem -Path cert:\CurrentUser\My\$Thumbprint)

	# $CertPassword = Read-Host -Prompt "Please enter the private key certificate password."
	$CertSecurePassword = ConvertTo-SecureString -String $CertPassword -AsPlainText -Force

	If ($ISE) # Executing from the PowerShell ISE instead of the PowerShell Console.
    {

		# Get the current folder that the PowerShell script is executing from.
        $CurrentFolder = (Split-Path -Parent $psISE.CurrentFile.FullPath)
	
	}
	Else
	{
		# If we're executing in the Console, then we have to use $PSCommandPath to get the executing scripts file location.
        $CurrentFolder = $PSCommandPath | Split-Path -Parent

	}

    Export-PfxCertificate -Cert $Certificate -FilePath "$CurrentFolder\$CertificateName.pfx" -Password $CertSecurePassword

    # Console output
    Write-Verbose -Message "[Finish] Created new X.509 Self-Signed Certificate for $VMName."

    Return [string]$CertPassword

} # End Create-Certificate

#endregion Create-Certificate()



#region Add-CertificateToKeyVault()

Function Add-CertificateToKeyVault()
{

Param  ([string]$VMName, [bool]$ISE, [string]$KeyVaultName, [string]$Password)

    # Console output
    Write-Verbose -Message "[Start] Adding X.509 Self-Signed Certificate for $VMName to Key Vault."


    If ($ISE) # Executing from the PowerShell ISE instead of the PowerShell Console.
    {

   		# Get the current folder that the PowerShell script is executing from.
        $CurrentFolder = (Split-Path -Parent $psISE.CurrentFile.FullPath)
        
    }
    Else
    {
        # If we're executing in the Console, then we have to use $PSCommandPath to get the executing scripts file location.
        $CurrentFolder = $PSCommandPath | Split-Path -Parent

    }

    $FileName = $CurrentFolder + "\" + $VMName + ".pfx"
    
    $FileContentBytes = Get-Content $FileName -Encoding Byte
    $FileContentEncoded = [System.Convert]::ToBase64String($FileContentBytes)

    $JSONObject = @"
{
  "data": "$FileContentEncoded",
  "dataType" :"pfx",
  "password": "$Password"
}
"@

    $JSONObjectBytes = [System.Text.Encoding]::UTF8.GetBytes($JSONObject)
    $JSONEncoded = [System.Convert]::ToBase64String($JSONObjectBytes)

    $Secret = ConvertTo-SecureString -String $JSONEncoded -AsPlainText –Force
    Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $VMName -SecretValue $Secret

    # Console output
    Write-Verbose -Message "[Finish] Added X.509 Self-Signed Certificate for $VMName to Key Vault."


}

#endregion Add-CertificateToKeyVault()


#region Create-WinRMSession()

Function Create-WinRMSession()
{

Param  ([string]$VMName, [string]$WinRMUri, $Credentials)

#region Establish a remote PS session object to the VM

# Console output
Write-Verbose -Message "[Start] Creating Remote PowerShell Session to $VMName." -Verbose

# Create the session object
$WRSession = New-PSSession -ConnectionUri $WinRMUri -Credential $Credentials -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck) -Authentication Negotiate

# Console output
Write-Verbose -Message "[Finish] Created Remote PowerShell Session to $VMName." -Verbose

Return $WRSession

#endregion Establish a remote PS session object to the VM

} #End Create-WinRMSession

#endregion Create-WinRMSession()



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

[string[]]$VMNames = $VMName.Split(",")
[string[]]$PrivateIPAddresses = $PrivateIPAddress.Split(",")

$VMNames.Count
[string[]]$VMNames
$PrivateIPAddresses.Count
[string[]]$PrivateIPAddresses

# Because we accept an array of both VMName, PrivateIPAddress as parameters, loop through them to create each specified.
$Count = 0
$CheckDNS = $null

If ($VMNames.Count -eq $PrivateIPAddresses.Count)
{
    # Establish the Private Key Password for the Certificates
    $CertPassword = Read-Host -Prompt "Please enter the private key certificate password."

    # Establish the VMs Local Administrator Account
    $Credentials = Get-Credential -Message "Type the name and password of the local administrator account."

    While ($Count -le $VMNames.Count-1)
        {

        # Ensure that the VMName is available.
        $CheckDNS = Test-AzureRmDnsAvailability -DomainNameLabel $VMNames[$Count].ToLower() -Location $AzureRegion

        If ($CheckDNS)
        {

            # Call Function
            $Return = Create-Certificate -VMName $VMNames[$Count] -ISE $ISE -CertPassword $CertPassword
            $CertificatePassword = $Return[1]

            #Call Function
            Add-CertificateToKeyVault -VMName $VMNames[$Count] -ISE $ISE -KeyVaultName $KeyVaultName -Password $CertificatePassword

            # Get the VNet
            $VNet = Get-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName "Subscription_Common"

            # Get the Subnet 
            $SubNet = $VNet.Subnets | where { $_.Name –eq $("Management") }

            # Create the Static/Dynamic Public IP Address for the VM
            $NICName = $VMNames[$Count]
            $PIP = New-AzureRmPublicIpAddress -Name $NICName -ResourceGroupName $($AzureRGEnvironmentName + "_" + $AzureRGTenantName) -Location $AzureRegion -AllocationMethod Dynamic -DomainNameLabel $VMNames[$Count].ToLower() -Tag @{Environment="Subscription"; Tenant="Common"}

            # Create the network interface
            $NIC = New-AzureRmNetworkInterface -Name $NICName -ResourceGroupName $($AzureRGEnvironmentName + "_" + $AzureRGTenantName) -Location $AzureRegion -SubnetId $SubNet.Id -PublicIpAddressId $PIP.Id -PrivateIpAddress $PrivateIPAddresses[$Count] -Tag @{Environment="Subscription"; Tenant="Common"}

            # Create Availablity Set Object
            $AVSet = New-AzureRmAvailabilitySet -Location $AzureRegion –Name "Domain_Controllers" –ResourceGroupName $($AzureRGEnvironmentName + "_" + $AzureRGTenantName) -ErrorAction SilentlyContinue

            # Get WinRM Secret (X.509 Certificate), previously stored, from the Key Vault.
            $WinRMSecretId = (Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $VMNames[$Count]).Id

            # Create VM Configuration
            New-AzureRmVMConfig -VMName $VMNames[$Count] -VMSize $VMSize -AvailabilitySetId $AVSet.Id | Tee-Object -Variable NewVM

            Set-AzureRmVMOperatingSystem -VM $NewVM -Windows -ComputerName $VMNames[$Count] -Credential $Credentials -ProvisionVMAgent -EnableAutoUpdate -WinRMHttp -WinRMHttps -WinRMCertificateUrl $WinRMSecretId
            Set-AzureRmVMSourceImage -VM $NewVM -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2012-R2-Datacenter -Version "latest"
            Add-AzureRmVMNetworkInterface -VM $NewVM -Id $NIC.Id

            $OSDiskName = $($VMNames[$Count] + "_OSDisk")
            $SA = Get-AzureRmStorageAccount -ResourceGroupName $($AzureRGEnvironmentName + "_" + $AzureRGTenantName) -Name $AzureSAName

            $OSDiskUri = $SA.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName  + ".vhd"
            Set-AzureRmVMOSDisk -VM $NewVM -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption fromImage

            # Install the WinRM X.509 Certificate into the VMs Certificate store.
            $SourceVaultId = (Get-AzureRmKeyVault -ResourceGroupName $KeyVaultRGName -VaultName $KeyVaultName).ResourceId
            $CertificateStore = "My"
            Add-AzureRmVMSecret -VM $NewVM -SourceVaultId $SourceVaultId -CertificateStore $CertificateStore -CertificateUrl $WinRMSecretId

            # Console output
            Write-Verbose -Message "[Start] VM creation $($VMNames[$Count])." -Verbose

            # Create VM based upon VM Configuration
            New-AzureRmVM -ResourceGroupName $($AzureRGEnvironmentName + "_" + $AzureRGTenantName) -Location $AzureRegion -VM $NewVM -Tags @{Environment=$AzureRGEnvironmentName; Tenant=$AzureRGTenantName}

            # Console output
            Write-Verbose -Message "[Finish] VM creation $($VMNames[$Count])." -Verbose

            $WinRMUri = "https://" + $VMNames[$Count].ToLower() + ".eastus2.cloudapp.azure.com:5986"

            # Call Function
            $WRSession = Create-WinRMSession $VMNames[$Count] $WinRMUri $Credentials

            #region Create and promote the first domain controller in the domain.

            If ($Count -eq 0)
            {

                # Debug
                # Enter-PSSession -ConnectionUri https://ronbok-dc01.eastus2.cloudapp.azure.com:5986 -Credential $Credentials -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck) -Authentication Negotiate
                # Exit-PSSession

                # Console output
                Write-Verbose -Message "[Start] Starting remote PowerShell session. Promoting $($VMNames[$Count]) to first Domain Controller in $DomainName." -Verbose

                # Promote the domain controller using the remote PowerShell session
                Invoke-Command -Session $WRSession -ArgumentList @($Credentials, $DomainName) -ScriptBlock {
                        Param ($Credentials, $DomainName)
                        # Set AD installation paths
                        $Drive = Get-Volume | Where { $_.DriveLetter -eq “C” }
                        $NTDSpath = $Drive.driveletter + ":\Windows\NTDS"
                        $SYSVOLpath = $Drive.driveletter + ":\Windows\SYSVOL"

                        Write-Verbose "Installing the first Domain Controller in the $DomainName domain." -Verbose
                        Install-WindowsFeature –Name AD-Domain-Services -includemanagementtools
                        Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath $NTDSpath -LogPath $NTDSpath -SysvolPath $SYSVOLpath -DomainName $DomainName -InstallDns -Force -Confirm:$false -SafeModeAdministratorPassword $Credentials.Password
                    }

                # Console output
                Write-Verbose -Message "[Finish] Ending remote PowerShell session. Promoted $($VMNames[$Count]) to first Domain Controller in $DomainName." -Verbose

                #endregion Create and promote the first domain controller in the domain.
            }
            Else
            {

                #region Create and promote the additional domain controller in the domain.

                # Placeholder for a Split-Domain Funciton later on...
                $Domain = $DomainName.Split('.')[0]

                # Sets the RonBok-DC02 NIC to the Prior DC's DNS / Private Address
                $NIC.DnsSettings.DnsServers += $PrivateIPAddresses[$Count-1]
                Set-AzureRmNetworkInterface -NetworkInterface $NIC


                # Debug
                # Enter-PSSession -ConnectionUri https://ronbok-dc02.eastus2.cloudapp.azure.com:5986 -Credential $Credentials -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck) -Authentication Negotiate
                # Exit-PSSession


                # Console output
                Write-Verbose -Message "[Start] Starting remote PowerShell session. Promoting $($VMNames[$Count]) as an additional Domain Controller in $DomainName." -Verbose

                # Promote the domain controller using the remote PowerShell session.
                Invoke-Command -Session $WRSession -ArgumentList @($Credentials, $Domain, $DomainName, $UserName) -ScriptBlock {
                        Param ($Credentials, $Domain, $DomainName, $UserName)
                        # Set AD installation paths
                        $Drive = Get-Volume | Where { $_.DriveLetter -eq “C” }
                        $NTDSpath = $Drive.driveletter + ":\Windows\NTDS"
                        $SYSVOLpath = $Drive.driveletter + ":\Windows\SYSVOL"
     
                        Write-Verbose "Installing the next Domain Controller in $DomainName domain." -Verbose

                        $Credential = New-Object System.Management.Automation.PSCredential("$Domain\$UserName", $Credentials.Password)

                        Install-WindowsFeature –Name AD-Domain-Services -includemanagementtools
                        Install-ADDSDomainController -CreateDnsDelegation:$false -DatabasePath $NTDSpath -DomainName $DomainName -InstallDns:$true -LogPath $NTDSpath -NoGlobalCatalog:$false -SiteName 'Default-First-Site-Name' -SysvolPath $SYSVOLpath -Force:$true -Credential $Credential -SafeModeAdministratorPassword $Credentials.Password

                    }

                # Console output
                Write-Verbose -Message "[Finish] Ending remote PowerShell session. Promoted $($VMNames[$Count]) as an additional Domain Controller in $DomainName." -Verbose


                #endregion Create and promote the additional domain controller in the domain.
                
            }


        }
        Else
        {
            # Console output with -Verbose only
	        Write-Verbose -Message "[Error:$PSScriptName] $VMName already exists."
            Write-Verbose -Message ""

            # This is such a catastrophic error we have to abandon further execution.
            Exit
        }

        # Update the VNet with the newly added DC / DNS IP.
        $VNet.DhcpOptions.DnsServers += $PrivateIPAddresses[$Count]
        Set-AzureRmVirtualNetwork -VirtualNetwork $VNet

        $Count++
        $CheckDNS = $null

    } # End While

}
Else
{
		# Console output with -Verbose only
		Write-Verbose -Message "[Error:$PSScriptName] Attempt to validate VMName/PrivateIPAddress 1:1 pairing of parameters failed."
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