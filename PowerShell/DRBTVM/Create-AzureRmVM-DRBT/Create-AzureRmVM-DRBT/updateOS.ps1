
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="Env - ie, Production_Common" )]
    [string]$env,
    [Parameter(Mandatory=$True, Position=1, HelpMessage="VM, ie DRBT-P-PRD02" )]
    [string]$VMName
    )
#Login-AzureRmAccount
# Get the VM
$vm = Get-AzureRMVM -ResourceGroupName $env -Name $VMName
# Set the extension information
$ExtensionName="OSPatchingForLinux"
$version="1.0"
$Publisher="Microsoft.OSTCExtensions"
switch ($env) 
    { 
        "Production_Common" { $stoname = "saspcs1" } 
        "Stage_Common" { $stoname = "sasscs" } 
        "Development_Common" { $stoname = "sasdcs" } 
        "Test_Common" { $stoname = "sastcs" } 
        "Subscription_Common" { $stoname = "sassubcom1" }
        default { Exit-PSHostProcess }
    }
    if ( $VMName -eq "DRBT-P-PRD02" ) { $stoname = "saspcs2" }
$stokey = Get-AzureRmStorageAccountKey -ResourceGroupName $env -Name $stoname
$ProtectedSettingsString = '{"storageAccountName":"' + $stoname + '","storageAccountKey":"' + $stokey[0].Value + '"}'
$SettingsString = '{"fileUris":[],"commandToExecute":""}'
# Set the parameter value
# Here we set the “startTime” to empty string for one-off mode

$PrivateConfig = '{
    "disabled" : "False",
    "stop" : "False",
    "rebootAfterPatch" : "Auto",
    "startTime" : "",
    "category" : "ImportantAndRecommended",
    "installDuration" : "00:30" }'

$TimeStamp = (Get-Date).Ticks
$PublicConfig = '{"timestamp" : "' + $TimeStamp + '"}'

# Apply the configuration to the extension
Set-AzureRmVMExtension -ResourceGroupName $env -Location "East US 2" -VMName $vm.Name -Name "OSPatchingForLinux" -Publisher "Microsoft.OSTCExtensions" -Type "OSPatchingForLinux" -TypeHandlerVersion "1.0" -SettingString $SettingsString -ProtectedSettingString $ProtectedSettingsString

#Sample PowerShell Script to run a Linux Shell script stored in Azure blob
#Enter the VM name, Service name, Azure storage account name and key
$storagekey = Get-AzureRmStorageAccountKey -ResourceGroupName $env -Name $stoname
$PrivateConfiguration = '{"storageAccountName": $Stoname,"storageAccountKey":$storageky[0].Value}' 
#Specify the Location of the script from Azure blob, and command to execute

$PublicConfiguration = '{"fileUris":["http://"+$Stoname+".blob.core.windows.net/vhds/postinstall.steward.sh"], "commandToExecute": "sh postinstall.steward.sh" }' 
	
#Deploy the extension to the VM, always use the latest version by specify version “1.*”
$ExtensionName = 'CustomScriptForLinux'  
$Publisher = 'Microsoft.OSTCExtensions'  
$Version = '1.*' 
Set-AzureVMExtension -ExtensionName $ExtensionName -VM  $vm -Publisher $Publisher -Version $Version -PrivateConfiguration $PrivateConfiguration -PublicConfiguration $PublicConfiguration  | Update-AzureVM