powershell.exe -ExecutionPolicy bypass -file Create-AzureRMStorageAccount.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGName "Subscription_Common,Subscription_Common" -AzureSAName "sassubcom1,sassubcom2" -AzureSAType "Standard_GRS,Standard_GRS" -Verbose
