powershell.exe -ExecutionPolicy bypass -file Create-AzureRMStorageAccount.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGName "Stage_Common,Stage_Common" -AzureSAName "sasscs,sasscp" -AzureSAType "Standard_GRS,Premium_LRS" -Verbose