powershell.exe -ExecutionPolicy bypass -file Remove-AzureRmSqlDatabase.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGEnvironmentName "Development" -AzureRGTenantName "Common" -AzureSQLServerName "sasdevelopment1,sasdevelopment2" -AzureDBName "Sample1,Sample2" -Verbose
