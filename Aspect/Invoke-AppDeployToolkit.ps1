
<#

.SYNOPSIS
PSAppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION
- The script is provided as a template to perform an install, uninstall, or repair of an application(s).
- The script either performs an "Install", "Uninstall", or "Repair" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script imports the PSAppDeployToolkit module which contains the logic and functions required to install or uninstall an application.

.PARAMETER DeploymentType
The type of deployment to perform.

.PARAMETER DeployMode
Specifies whether the installation should be run in Interactive (shows dialogs), Silent (no dialogs), NonInteractive (dialogs without prompts) mode, or Auto (shows dialogs if a user is logged on, device is not in the OOBE, and there's no running apps to close).

Silent mode is automatically set if it is detected that the process is not user interactive, no users are logged on, the device is in Autopilot mode, or there's specified processes to close that are currently running.

.PARAMETER SuppressRebootPassThru
Suppresses the 3010 return code (requires restart) from being passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode
Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging
Disables logging to file for the script.

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeployMode Silent

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeploymentType Uninstall

.EXAMPLE
Invoke-AppDeployToolkit.exe -DeploymentType Install -DeployMode Silent

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Invoke-AppDeployToolkit.ps1, and Invoke-AppDeployToolkit.exe
- 69000 - 69999: Recommended for user customized exit codes in Invoke-AppDeployToolkit.ps1
- 70000 - 79999: Recommended for user customized exit codes in PSAppDeployToolkit.Extensions module.

.LINK
https://psappdeploytoolkit.com

#>

[CmdletBinding()]
param
(
    # Default is 'Install'.
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [System.String]$DeploymentType,

    # Default is 'Auto'. Don't hard-code this unless required.
    [Parameter(Mandatory = $false)]
    [ValidateSet('Auto', 'Interactive', 'NonInteractive', 'Silent')]
    [System.String]$DeployMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$SuppressRebootPassThru,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$TerminalServerMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$DisableLogging
)


##================================================
## MARK: Variables
##================================================

$adtSession = @{
    # App variables.
    AppVendor            = 'Softix'
    AppName              = 'Aspect'
    AppVersion           = 'ClickOnce'
    AppArch              = 'AnyCPU'
    AppLang              = 'EN'
    AppRevision          = '01'
    AppSuccessExitCodes  = @(0)
    AppRebootExitCodes   = @(1641, 3010)
    AppProcessesToClose  = @()
    AppScriptVersion     = '1.5.0'
    AppScriptDate        = '2026-05-10'
    AppScriptAuthor      = 'Oscar Lupton - Ticketek Event IT'
    RequireAdmin         = $true

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName          = ''
    InstallTitle         = ''

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptParameters   = $PSBoundParameters
    DeployAppScriptVersion      = '4.1.8'
}

function Install-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Install
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    # NOTE (legacy): The old SOE used .NET 2.0 CAS policy to grant FullTrust to the deployment URL:
    #
    #   C:\Windows\Microsoft.NET\Framework64\v2.0.50727\caspol -m -ag All_Code `
    #       -url "http://aspect.ticketek.com.au/*" FullTrust -n Aspect_Zone -d "Aspect Security Zone"
    #   C:\Windows\Microsoft.NET\Framework\v2.0.50727\caspol -m -ag All_Code `
    #       -url "http://aspect.ticketek.com.au/*" FullTrust -n Aspect_Zone -d "Aspect Security Zone"
    #
    # This is NOT used here. CAS policy is disabled by default in .NET 4.x, and the
    # .NET 2.0 Framework paths do not exist on Windows 11 IoT.

    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Deploy config and icons to Program Files (app is AnyCPU / .NET 4.8, not x86).
    New-ADTFolder -LiteralPath "$envProgramFiles\Softix\Aspect"
    Copy-ADTFile -Path "$($adtSession.DirSupportFiles)\LocalConfig.xml" -Destination "$envProgramFiles\Softix\Aspect\LocalConfig.xml"
    Copy-ADTFile -Path "$($adtSession.DirSupportFiles)\aspect.ico"      -Destination "$envProgramFiles\Softix\Aspect\aspect.ico"
    Copy-ADTFile -Path "$($adtSession.DirSupportFiles)\report.ico"      -Destination "$envProgramFiles\Softix\Aspect\report.ico"

    ## Configure ZoneMap\ProtocolDefaults to map file:// URLs to the Internet zone (zone 3).
    ##
    ## In production, Aspect is activated via the URL shortcuts below, which open Edge.
    ## Edge has native ClickOnce support and passes the original HTTPS URL directly to dfshim,
    ## so zone settings are not relevant to the normal thin-client workflow.
    ##
    ## This setting is present in both NTUSER-Admin.reg and NTUSER-User.reg in the SOE image
    ## and is retained here to match the SOE baseline. It provides a partial benefit if a user
    ## ever activates a .application file downloaded via Edge from the local filesystem, because
    ## Edge embeds the source HTTPS URL in the file's Zone.Identifier and dfshim can resolve
    ## back to the HTTPS origin — but the zone mapping must match for that check to pass.
    ##
    ## Note: this setting does NOT fix activation via Firefox or File Explorer for files that
    ## lack an embedded HostUrl in their Zone.Identifier, as dfshim cannot resolve the HTTPS
    ## origin and the zone comparison fails regardless of ProtocolDefaults.

    Invoke-ADTAllUsersRegistryAction -ScriptBlock {
        Set-ADTRegistryKey -SID $_.SID `
            -LiteralPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\ProtocolDefaults' `
            -Name 'file' -Value 3 -Type DWord
    }

    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## Create shortcuts on Public Desktop, then copy to Start Menu.
    New-ADTShortcut `
        -LiteralPath "$envCommonDesktop\Aspect.url" `
        -TargetPath "https://aspect.ticketek.com.au" `
        -IconLocation "$envProgramFiles\Softix\Aspect\aspect.ico"
    New-ADTShortcut `
        -LiteralPath "$envCommonDesktop\Insight.url" `
        -TargetPath "https://insight.ticketek.com.au" `
        -IconLocation "$envProgramFiles\Softix\Aspect\report.ico"
    New-ADTShortcut `
        -LiteralPath "$envCommonDesktop\InsightPlus.url" `
        -TargetPath "https://reports.ticketek.com.au/reports" `
        -IconLocation "$envProgramFiles\Softix\Aspect\report.ico"

    New-ADTFolder -LiteralPath "$envCommonStartMenuPrograms\Softix"
    Copy-ADTFile `
        -Path "$envCommonDesktop\Aspect.url" `
        -Destination "$envCommonStartMenuPrograms\Softix\Aspect.url"
    Copy-ADTFile `
        -Path "$envCommonDesktop\Insight.url" `
        -Destination "$envCommonStartMenuPrograms\Softix\Insight.url"
    Copy-ADTFile `
        -Path "$envCommonDesktop\InsightPlus.url" `
        -Destination "$envCommonStartMenuPrograms\Softix\InsightPlus.url"
}

function Uninstall-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ##================================================
    ## MARK: Uninstall
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ##================================================
    ## MARK: Post-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"
}

function Repair-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Repair
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ##================================================
    ## MARK: Repair
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"
}

##================================================
## MARK: Initialization
##================================================

# Set strict error handling across entire operation.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

# Import the module and instantiate a new session.
try
{
    # Import the module locally if available, otherwise try to find it from PSModulePath.
    if (Test-Path -LiteralPath "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -PathType Leaf)
    {
        Get-ChildItem -LiteralPath "$PSScriptRoot\PSAppDeployToolkit" -Recurse -File | Unblock-File -ErrorAction Ignore
        Import-Module -FullyQualifiedName @{ ModuleName = "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.8' } -Force
    }
    else
    {
        Import-Module -FullyQualifiedName @{ ModuleName = 'PSAppDeployToolkit'; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.8' } -Force
    }

    # Open a new deployment session, replacing $adtSession with a DeploymentSession.
    $iadtParams = Get-ADTBoundParametersAndDefaultValues -Invocation $MyInvocation
    $adtSession = Remove-ADTHashtableNullOrEmptyValues -Hashtable $adtSession
    $adtSession = Open-ADTSession @adtSession @iadtParams -PassThru
}
catch
{
    $Host.UI.WriteErrorLine((Out-String -InputObject $_ -Width ([System.Int32]::MaxValue)))
    exit 60008
}


##================================================
## MARK: Invocation
##================================================

try
{
    # Import any found extensions before proceeding with the deployment.
    Get-ChildItem -LiteralPath $PSScriptRoot -Directory | & {
        process
        {
            if ($_.Name -match 'PSAppDeployToolkit\..+$')
            {
                Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Unblock-File -ErrorAction Ignore
                Import-Module -Name $_.FullName -Force
            }
        }
    }

    # Invoke the deployment and close out the session.
    & "$($adtSession.DeploymentType)-ADTDeployment"
    Close-ADTSession
}
catch
{
    $mainErrorMessage = "An unhandled error within [$($MyInvocation.MyCommand.Name)] has occurred.`n$(Resolve-ADTErrorRecord -ErrorRecord $_)"
    Write-ADTLogEntry -Message $mainErrorMessage -Severity 3
    Close-ADTSession -ExitCode 60001
}
