powershell.exe -ExecutionPolicy bypass -file Delete-Tenant.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGName "Subscription_Common" -AzureSAName "sassubcom1" -TableName "TMDevelopment" -KVName "sasdcs" -TenantDomain "steward.org.backup" -Verbose
