<#  WARNING -- WARNING -- WARNING -- WARNING -- WARNING -- WARNING -- WARNING -- WARNING -- WARNING -- WARNING -- WARNING -- WARNING --

												!!! DO NOT SIMPLY RUN THIS SCRIPT !!!

    It is a *UTILITY* meant to provide example(s) for executing cmdlets against the existing AppSuite VNet both to create and update Network Security Groups.
    While the original code used to create each NSG is contained within, running these again may cause serious injury or death.  :-)
#>


# Get the existing VNet 'AppSuite' and display the Address Space
$VNet = Get-AzureRmVirtualNetwork -Name "AppSuite" -ResourceGroupName "Subscription_Common"
$VNet.AddressSpace

<#
# Sample rules that could be added to the NSGs.

$RDPRule1 = New-AzureRmNetworkSecurityRuleConfig -Name "RDP-External" -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 200 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
$RDPRule2 = New-AzureRmNetworkSecurityRuleConfig -Name "RDP-Internal" -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix "VirtualNetwork" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389

#>



# 1
# Create Development_Common Network Security Group in preparation for associating it with the Development_Common Subnet.
$NSGDevelopment = New-AzureRmNetworkSecurityGroup -ResourceGroupName "Development_Common" -Name "Development_Common" -Location "East US 2" -Tag @{Name="Environment";Value="Development"}, @{Name="Tenant";Value="Common"} # -SecurityRules $RDPRule1,$RDPRule2

# Should be empty or null
# $NSGDevelopment.Subnets

# Retrieve the Development_Common Subnet.
$SubNet = $VNet.Subnets | where { $_.Name –eq "Development_Common" }

# Associate the Development_Common Network Security Group to the VNet Subnet!
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VNet -Name $SubNet.Name -AddressPrefix $SubNet.AddressPrefix -NetworkSecurityGroup $NSGDevelopment

# Commit the association.  If we don't our association will not exist.
Set-AzureRmVirtualNetwork -VirtualNetwork $VNet

# Retrieve the Development_Common Network Security Group previously created.
$NSGDevelopment = Get-AzureRmNetworkSecurityGroup -Name "Development_Common" -ResourceGroupName "Development_Common"

# Add a NSG Rule with priority that can range from 100-4096.
Add-AzureRmNetworkSecurityRuleConfig -Name "RDP-External" -NetworkSecurityGroup $NSGDevelopment -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 200 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.128.128/25" -DestinationPortRange 3389

# Add a NSG Rule with priority that can range from 100-4096 for SSMS / SSAS.
Add-AzureRmNetworkSecurityRuleConfig -Name "SQLServerSSMSPublic" -NetworkSecurityGroup $NSGDevelopment -Description "Allow SSMS for SSAS" -Access Allow -Protocol Tcp -Direction Inbound -Priority 1600 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.128.128/25" -DestinationPortRange 2383

# Add a NSG Rule with priority that can range from 100-4096 for SSH.
Add-AzureRmNetworkSecurityRuleConfig -Name "SSH-External" -NetworkSecurityGroup $NSGDevelopment -Description "Allow SSH" -Access Allow -Protocol Tcp -Direction Inbound -Priority 201 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.128.128/25" -DestinationPortRange 22

# Update the a NSG Rule with priority that can range from 100-4096 for RDP.
# Set-AzureRmNetworkSecurityRuleConfig -Name "RDP-External" -NetworkSecurityGroup $NSGDevelopment -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 200 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.128.128/25" -DestinationPortRange 3389

# Update a NSG Rule with priority that can range from 100-4096 for SSMS / SSAS.
# Set-AzureRmNetworkSecurityRuleConfig -Name "SQLServerSSMSPublic" -NetworkSecurityGroup $NSGDevelopment -Description "Allow SSMS for SSAS" -Access Allow -Protocol Tcp -Direction Inbound -Priority 1600 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.128.128/25" -DestinationPortRange 2383

# Commit our new rule.  If we don't our rule will not exist.
Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $NSGDevelopment



# 2
# Create Test_Common Network Security Group in preparation for associating it with the Test_Common Subnet.
$NSGTest = New-AzureRmNetworkSecurityGroup -ResourceGroupName "Test_Common" -Name "Test_Common" -Location "East US 2" -Tag @{Name="Environment";Value="Test"}, @{Name="Tenant";Value="Common"} #-SecurityRules $RDPRule1,$RDPRule2

# Should be empty or null
# $NSGTest.Subnets

# Retrieve the Test_Common Subnet.
$SubNet = $VNet.Subnets | where { $_.Name –eq "Test_Common" }

# Associate the Test_Common Network Security Group to the VNet Subnet!
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VNet -Name $SubNet.Name -AddressPrefix $SubNet.AddressPrefix -NetworkSecurityGroup $NSGTest

# Commit the association.  If we don't our association will not exist.
Set-AzureRmVirtualNetwork -VirtualNetwork $VNet

# Retrieve the Test_Common Network Security Group previously created.
$NSGTest = Get-AzureRmNetworkSecurityGroup -Name "Test_Common" -ResourceGroupName "Test_Common"

# Add a NSG Rule with priority that can range from 100-4096 for RDP.
Add-AzureRmNetworkSecurityRuleConfig -Name "RDP-External" -NetworkSecurityGroup $NSGTest -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 200 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.129.0/25" -DestinationPortRange 3389

# Add a NSG Rule with priority that can range from 100-4096 for SSMS / SSAS.
Add-AzureRmNetworkSecurityRuleConfig -Name "SQLServerSSMSPublic" -NetworkSecurityGroup $NSGTest -Description "Allow SSMS for SSAS" -Access Allow -Protocol Tcp -Direction Inbound -Priority 1600 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.129.0/25" -DestinationPortRange 2383

# Add a NSG Rule with priority that can range from 100-4096 for SSH.
Add-AzureRmNetworkSecurityRuleConfig -Name "SSH-External" -NetworkSecurityGroup $NSGTest -Description "Allow SSH" -Access Allow -Protocol Tcp -Direction Inbound -Priority 201 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.129.0/25" -DestinationPortRange 22

# Update the a NSG Rule with priority that can range from 100-4096 for RDP.
# Set-AzureRmNetworkSecurityRuleConfig -Name "RDP-External" -NetworkSecurityGroup $NSGTest -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 200 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.129.0/25" -DestinationPortRange 3389

# Update a NSG Rule with priority that can range from 100-4096 for SSMS / SSAS.
# Set-AzureRmNetworkSecurityRuleConfig -Name "SQLServerSSMSPublic" -NetworkSecurityGroup $NSGTest -Description "Allow SSMS for SSAS" -Access Allow -Protocol Tcp -Direction Inbound -Priority 1600 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.129.0/25" -DestinationPortRange 2383

# Commit our new rule.  If we don't our rule will not exist.
Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $NSGTest



# 3
# Create Stage_Common Network Security Group
$NSGStage = New-AzureRmNetworkSecurityGroup -ResourceGroupName "Stage_Common" -Name "Stage_Common" -Location "East US 2" -Tag @{Name="Environment";Value="Stage"}, @{Name="Tenant";Value="Common"} #-SecurityRules $RDPRule1,$RDPRule2

# Should be empty or null
# $NSGStage.Subnets

# Retrieve the Stage_Common Subnet.
$SubNet = $VNet.Subnets | where { $_.Name –eq "Stage_Common" }

# Associate the Stage_Common Network Security Group to the VNet Subnet!
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VNet -Name $SubNet.Name -AddressPrefix $SubNet.AddressPrefix -NetworkSecurityGroup $NSGStage

# Commit the association.  If we don't our association will not exist.
Set-AzureRmVirtualNetwork -VirtualNetwork $VNet

# Retrieve the Stage_Common Network Security Group previously created.
$NSGStage = Get-AzureRmNetworkSecurityGroup -Name "Stage_Common" -ResourceGroupName "Stage_Common"

# Add a NSG Rule with priority that can range from 100-4096.
Add-AzureRmNetworkSecurityRuleConfig -Name "RDP-External" -NetworkSecurityGroup $NSGStage -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 200 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.129.128/25" -DestinationPortRange 3389

# Add a NSG Rule with priority that can range from 100-4096 for SSMS / SSAS.
Add-AzureRmNetworkSecurityRuleConfig -Name "SQLServerSSMSPublic" -NetworkSecurityGroup $NSGStage -Description "Allow SSMS for SSAS" -Access Allow -Protocol Tcp -Direction Inbound -Priority 1600 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.129.128/25" -DestinationPortRange 2383

# Add a NSG Rule with priority that can range from 100-4096 for SSH.
Add-AzureRmNetworkSecurityRuleConfig -Name "SSH-External" -NetworkSecurityGroup $NSGStage -Description "Allow SSH" -Access Allow -Protocol Tcp -Direction Inbound -Priority 201 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.129.128/25" -DestinationPortRange 22

# Commit our new rule.  If we don't our rule will not exist.
Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $NSGStage



# 4
# Create Production_Common Network Security Group
$NSGProduction = New-AzureRmNetworkSecurityGroup -ResourceGroupName "Production_Common" -Name "Production_Common" -Location "East US 2" -Tag @{Name="Environment";Value="Production"}, @{Name="Tenant";Value="Common"} #-SecurityRules $RDPRule1,$RDPRule2

# Should be empty or null
# $NSGProduction.Subnets

# Retrieve the Production_Common Subnet.
$SubNet = $VNet.Subnets | where { $_.Name –eq "Production_Common" }

# Assign the Production_Common Network Security Group to the VNet Subnet!
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VNet -Name $SubNet.Name -AddressPrefix $SubNet.AddressPrefix -NetworkSecurityGroup $NSGProduction

# Commit all of our changes!
Set-AzureRmVirtualNetwork -VirtualNetwork $VNet

# Retrieve the Production_Common Network Security Group previously created.
$NSGProduction = Get-AzureRmNetworkSecurityGroup -Name "Production_Common" -ResourceGroupName "Production_Common"

# Add a NSG Rule with priority that can range from 100-4096.
Add-AzureRmNetworkSecurityRuleConfig -Name "RDP-External" -NetworkSecurityGroup $NSGProduction -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 200 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.130.0/23" -DestinationPortRange 3389

# Update the a NSG Rule with priority that can range from 100-4096 for RDP.
# Set-AzureRmNetworkSecurityRuleConfig -Name "RDP-External" -NetworkSecurityGroup $NSGProduction -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 200 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.130.0/23" -DestinationPortRange 3389

# Add a NSG Rule with priority that can range from 100-4096 for SSMS / SSAS.
Add-AzureRmNetworkSecurityRuleConfig -Name "SQLServerSSMSPublic" -NetworkSecurityGroup $NSGProduction -Description "Allow SSMS for SSAS" -Access Allow -Protocol Tcp -Direction Inbound -Priority 1600 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.130.0/23" -DestinationPortRange 2383

# Add a NSG Rule with priority that can range from 100-4096 for SSH.
Add-AzureRmNetworkSecurityRuleConfig -Name "SSH-External" -NetworkSecurityGroup $NSGProduction -Description "Allow SSH" -Access Allow -Protocol Tcp -Direction Inbound -Priority 201 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.130.0/23" -DestinationPortRange 22

# Commit our new rule.  If we don't our rule will not exist.
Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $NSGProduction



# 5
# Create Management Network Security Group
$NSGManagement = New-AzureRmNetworkSecurityGroup -ResourceGroupName "Subscription_Common" -Name "Management" -Location "East US 2" -Tag @{Name="Environment";Value="Subscription"}, @{Name="Tenant";Value="Common"} #-SecurityRules $RDPRule1,$RDPRule2

# Should be empty or null
# $NSGManagement.Subnets

# Retrieve the Management Subnet.
$SubNet = $VNet.Subnets | where { $_.Name –eq "Management" }

# Associate the Management Network Security Group to the VNet Subnet!
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VNet -Name $SubNet.Name -AddressPrefix $SubNet.AddressPrefix -NetworkSecurityGroup $NSGManagement

# Commit all of our changes!
Set-AzureRmVirtualNetwork -VirtualNetwork $VNet

# Retrieve the Management Network Security Group previously created.
$NSGManagement = Get-AzureRmNetworkSecurityGroup -Name "Management" -ResourceGroupName "Subscription_Common"

# Add a NSG Rule with priority that can range from 100-4096.
Add-AzureRmNetworkSecurityRuleConfig -Name "RDP-External" -NetworkSecurityGroup $NSGManagement -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 200 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389

# Add a NSG Rule with priority that can range from 100-4096 for SSH.
Add-AzureRmNetworkSecurityRuleConfig -Name "SSH-External" -NetworkSecurityGroup $NSGManagement -Description "Allow SSH" -Access Allow -Protocol Tcp -Direction Inbound -Priority 201 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.132.0/25" -DestinationPortRange 22

# Add a NSG Rule with priority that can range from 100-4096 for HTTPS.
Add-AzureRmNetworkSecurityRuleConfig -Name "HTTPS" -NetworkSecurityGroup $NSGManagement -Description "Allow HTTPS for DRBT-A-COM01" -Access Allow -Protocol Tcp -Direction Inbound -Priority 300 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.132.101/32" -DestinationPortRange 443

# Add a NSG Rule with priority that can range from 100-4096 for HTTP.
Add-AzureRmNetworkSecurityRuleConfig -Name "HTTP" -NetworkSecurityGroup $NSGManagement -Description "Allow HTTP for DRBT-A-COM01" -Access Allow -Protocol Tcp -Direction Inbound -Priority 4000 -SourceAddressPrefix "Internet" -SourcePortRange * -DestinationAddressPrefix "10.125.132.101/32" -DestinationPortRange 80

# Commit our new rule.  If we don't our rule will not exist.
Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $NSGManagement



# 6
# Create DMZ Network Security Group
$NSGDMZ = New-AzureRmNetworkSecurityGroup -ResourceGroupName "Subscription_Common" -Name "DMZ" -Location "East US 2" -Tag @{Name="Environment";Value="Subscription"}, @{Name="Tenant";Value="Common"}

# Should be empty or null
# $NSGDMZ.Subnets

# Retrieve the DMZ Subnet.
$SubNet = $VNet.Subnets | where { $_.Name –eq "DMZ" }

# Associate the DMZ Network Security Group to the VNet Subnet!
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VNet -Name $SubNet.Name -AddressPrefix $SubNet.AddressPrefix -NetworkSecurityGroup $NSGDMZ

# Commit all of our changes!
Set-AzureRmVirtualNetwork -VirtualNetwork $VNet


# 7
# Create Gateway Network Security Group
$NSGGateway = New-AzureRmNetworkSecurityGroup -ResourceGroupName "Subscription_Common" -Name "GatewaySubnet" -Location "East US 2" -Tag @{Name="Environment";Value="Subscription"}, @{Name="Tenant";Value="Common"}

# Retrieve the DMZ Subnet.
$SubNet = $VNet.Subnets | where { $_.Name –eq "GatewaySubnet" }

# Associate the GatewaySubnet Network Security Group to the VNet Subnet!
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VNet -Name $SubNet.Name -AddressPrefix $SubNet.AddressPrefix -NetworkSecurityGroup $NSGGateway

# Commit all of our changes!
Set-AzureRmVirtualNetwork -VirtualNetwork $VNet




<#
$VNet = Get-AzureRmVirtualNetwork -Name "AppSuite" -ResourceGroupName "Subscription_Common"

$NSGDevelopment = Get-AzureRmNetworkSecurityGroup -Name "Development_Common" -ResourceGroupName "Development_Common"
Remove-AzureRmNetworkSecurityGroup -Name $NSGDevelopment.Name -ResourceGroupName "Development_Common" -Force

$NSGTest = Get-AzureRmNetworkSecurityGroup -Name "Test_Common" -ResourceGroupName "Test_Common"
Remove-AzureRmNetworkSecurityGroup -Name $NSGTest.Name -ResourceGroupName "Test_Common" -Force

$NSGStage = Get-AzureRmNetworkSecurityGroup -Name "Stage_Common" -ResourceGroupName "Stage_Common"
Remove-AzureRmNetworkSecurityGroup -Name $NSGStage.Name -ResourceGroupName "Stage_Common" -Force

$NSGProduction = Get-AzureRmNetworkSecurityGroup -Name "Production_Common" -ResourceGroupName "Production_Common"
Remove-AzureRmNetworkSecurityGroup -Name $NSGProduction.Name -ResourceGroupName "Production_Common" -Force

$NSGManagement = Get-AzureRmNetworkSecurityGroup -Name "Management" -ResourceGroupName "Subscription_Common"
Remove-AzureRmNetworkSecurityGroup -Name $NSGManagement.Name -ResourceGroupName "Subscription_Common" -Force

$NSGDMZ = Get-AzureRmNetworkSecurityGroup -Name "DMZ" -ResourceGroupName "Subscription_Common"
Remove-AzureRmNetworkSecurityGroup -Name $NSGDMZ.Name -ResourceGroupName "Subscription_Common" -Force
#>