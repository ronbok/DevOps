powershell.exe -ExecutionPolicy bypass -file Update-Tenant.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGName "Subscription_Common" -AzureSAName "sassubcom1" -TableName "TMStage" -TenantName "StewardHealthcare" -TenantDomain "steward.org" -DBServer "sasstage1 " -SSASServer1 "ssas-stg02.eastus2.cloudapp.azure.com" -SSASServer2 "ssas-stg01.eastus2.cloudapp.azure.com" -Active "Y" -Verbose