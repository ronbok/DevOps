powershell.exe -ExecutionPolicy bypass -file Add-Tenant.ps1 -Subscription "AppSuite" -AzureRegion "East US 2" -AzureRGName "Subscription_Common" -AzureSAName "sassubcom1" -TableName "TMDevelopment" -KVName "sasdcs" -TenantName "BlueMetalHealthcare" -TenantDomain "bluemetal.com" -DBServer "sasdevelopment2" -SSASServer1 "ssas-dev01.eastus2.cloudapp.azure.com" -SSASServer2 "ssas-dev02.eastus2.cloudapp.azure.com" -Active "Y" -Verbose