powershell.exe -ExecutionPolicy bypass -file Create-AzureRmVM-DRBT.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGEnvironmentName "Development" -AzureRGTenantName "Common" -VNetName "AppSuite" -VMName "DRBT-P-DEV01" -PrivateIPAddress "10.125.128.201" -VMSize "Standard_D12" -AzureSAName "sasdcs" -AzureSAType "Standard_GRS" -Verbose
