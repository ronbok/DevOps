powershell.exe -ExecutionPolicy bypass -file Create-AzureRmVM-DRBT.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGEnvironmentName "Subscription" -AzureRGTenantName "Common" -VNetName "AppSuite" -VMName "DRBT-S-COM02" -PrivateIPAddress "10.125.132.112" -VMSize "Standard_D3_v2" -AzureSAName "sassubcom1" -AzureSAType "Standard_GRS" -Verbose
