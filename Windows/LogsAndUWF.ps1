# Logging Setup
New-EventLog -LogName "Ticketek" -Source "TicketekScripts"
#EntryTypes should be Error/Information/FailureAudit/SuccessAudit/Warning with corresponding EventIDs 1-5

# UWF Setup

function Set-OverlaySize([UInt32] $size) {
	$overlay = Get-WMIObject `
		-Namespace "root\standardcimv2\embedded" `
		-Class UWF_OverlayConfig `
		-Filter "CurrentSession = False"
	try {
		$overlay.SetMaximumSize($size)
		Write-EventLog -LogName "Ticketek" -Source "TicketekScripts" -EventId 4 -EntryType SuccessAudit -Message "UWF overlay set to $size"
	} catch {
		Write-EventLog -LogName "Ticketek" -Source "TicketekScripts" -EventId 3 -EntryType FailureAudit -Message "UWF overlay failed to resize to $size"
	}
}
function Set-OverlayThresholds([UInt32] $warning, [UInt32] $critical) {
	$overlay = Get-WMIObject `
		-Namespace "root\standardcimv2\embedded" `
		-Class UWF_Overlay
	$overlay.SetWarningThreshold($warning)
	Write-EventLog -LogName "Ticketek" -Source "TicketekScripts" -EventId 4 -EntryType SuccessAudit -Message "UWF overlay warning threshold set to $warning"
	$overlay.SetCriticalThreshold($critical)
	Write-EventLog -LogName "Ticketek" -Source "TicketekScripts" -EventId 4 -EntryType SuccessAudit -Message "UWF overlay critical threshold set to $critical"
}
function Set-ExcludedFile($driveLetter, $exclusion) {
	$exclusions = Get-WmiObject `
		-Namespace "root\standardcimv2\embedded" -Class UWF_Volume | where { $_.DriveLetter -eq $driveLetter -and  $_.CurrentSession -eq $false }
	$exclusions.AddExclusion($exclusion)
	Write-EventLog -LogName "Ticketek" -Source "TicketekScripts" -EventId 4 -EntryType SuccessAudit -Message "$exclusion added to UWF exclusions on drive $driveLetter"
}

Set-OverlayThresholds(2048, 1024) #reduce false alarms
Set-OverlaySize(8192) #up from 2GB for 16GB endpoints
Set-ExcludedFile("C:", "C:\PC_EFT") #for log retention
Set-ExcludedFile("C:", "C:\Program Files (x86)\PC_EFT") #for log retention