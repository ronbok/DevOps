#
# WARNING:  Before executing this script make sure that the disk volume F: is attached to the VM and formatted!!
# The VMName_ConfigurationFile.ini contains references to F:.
#
# Also ensure that you've created a duplicate VMName_ConfigurationFile.ini for your new VMName if this is in fact
# a new VM.  Each of these .ini files contains a unique VMName\sasadmin account reference that needs to be updated for
# each new VM created.
#

# Mark the start time.
$StartTime = Get-Date
Write-Verbose -Message "Start Time ($($StartTime.ToLocalTime()))." -Verbose
Write-Verbose -Message "" -Verbose

# Enable .NET Framework 3.5
# NOTE:  This fileshare needs to be located on a virtual machine in the child domain.
DISM.exe /Online /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:"Z:\os\WS 2012 R2\sources\sxs"

# Install SQL Server Analsysis Services according to the unattended ConfigurationFile.ini settings.
CD 'Z:\servers\SQL Server 2014'
.\Setup.exe /q /ConfigurationFile=.\SSAS-Prd02_ConfigurationFile.INI /Action=Install /IAcceptSQLServerLicenseTerms

# Firewall for SQL Server
New-NetFirewallRule -DisplayName “SQL Server (TCP-in)” -Direction Inbound –Protocol TCP –LocalPort 2383 -Action allow -profile Domain -RemoteAddress Any -description "Allows inbound Microsoft SQL connections.”
New-NetFirewallRule -DisplayName “SQL Server (TCP-in)” -Direction Inbound –Protocol TCP –LocalPort 2383 -Action allow -profile Private -RemoteAddress Any -description "Allows inbound Microsoft SQL connections.”
New-NetFirewallRule -DisplayName “SQL Server (TCP-in)” -Direction Inbound –Protocol TCP –LocalPort 2383 -Action allow -profile Public -RemoteAddress Any -description "Allows inbound Microsoft SQL connections.”

# Mark the finish time.
$FinishTime = Get-Date
Write-Verbose -Message "Finish Time ($($FinishTime.ToLocalTime()))." -Verbose
Write-Verbose -Message "" -Verbose

# Console output with -Verbose only
$TotalTime = ($FinishTime - $StartTime).Minutes
Write-Verbose -Message "Elapse Time (Minutes): $TotalTime" -Verbose
Write-Verbose -Message "" -Verbose

