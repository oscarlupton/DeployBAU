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

using namespace System.Xml.Linq #for config file creation

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

# Zero-Config MSI support is provided when "AppName" is null or empty.
# By setting the "AppName" property, Zero-Config MSI will be disabled.
$adtSession = @{
    # App variables.
    AppVendor = ''
    AppName = ''
    AppVersion = ''
    AppArch = ''
    AppLang = 'EN'
    AppRevision = '01'
    AppSuccessExitCodes = @(0)
    AppRebootExitCodes = @(1641, 3010)
    AppProcessesToClose = @()  # Example: @('excel', @{ Name = 'winword'; Description = 'Microsoft Word' })
    AppScriptVersion = '1.0.0'
    AppScriptDate = '2026-05-26'
    AppScriptAuthor = '<author name>'
    RequireAdmin = $true

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName = ''
    InstallTitle = ''

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptParameters = $PSBoundParameters
    DeployAppScriptVersion = '4.1.8'
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

    ## Show Welcome Message, close processes if specified, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt.
    $saiwParams = @{
        AllowDefer = $true
        DeferTimes = 3
        CheckDiskSpace = $true
        PersistPrompt = $true
    }
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        $saiwParams.Add('CloseProcesses', $adtSession.AppProcessesToClose)
    }
    Show-ADTInstallationWelcome @saiwParams

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Installation tasks here>


    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI installations.
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
            $ExecuteDefaultMSISplat.Add('Transforms', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
        if ($adtSession.DefaultMspFiles)
        {
            $adtSession.DefaultMspFiles | Start-ADTMsiProcess -Action Patch
        }
    }

    ## <Perform Installation tasks here>
    #Write-Host "Run `DCTopsSetupV1.0.0.4.exe` here" or recreate installer natively
    # this would look like:
    Copy-ADTFile -Path "$($adtSession.DirFiles)\README.txt" -Destination "$($envProgramFiles)\Softix\DCTops\README.txt"

    #Replace `regedit vb6controls.reg`
    $VB6Licenses = @{
        "BC96F860-9928-11cf-8AFA-00AA00C00905" = "mmimfflflmqmlfffrlnmofhfkgrlmmfmqkqj" #Masked Edit Control 6.0
        "12B142A4-BD51-11d1-8C08-0000F8754DA1" = "aadhgafabafajhchnbchehfambfbbachmfmb" #Chart Control 6.0 (OLEDB)
        "4D553650-6ABE-11cf-8ADB-00AA00C00905" = "gfjmrfkfifkmkfffrlmmgmhmnlulkmfmqkqj" #Common Dialog Control 6.0
        "C4145310-469C-11d1-B182-00A0C922E820" = "konhqhioohihphkouimonhqhvnwiqhhhnjti" #ADO Data Control 6.0 (OLEDB)
        "38911DA0-E448-11D0-84A3-00DD01104159" = "mcpckchcdchjcjcclidcgcgchdqdcjhcojpd" #Common Controls-3 6.0
        "9E799BF1-8817-11cf-958F-0020AFC28C3B" = "uqpqnqkjujkjjjjqwktjrjkjtkupsjnjtoun" #Windows Common Controls-2 5.0 (SP2)
        "57CBF9E0-6AA7-11cf-8ADB-00AA00C00905" = "aahakhchghkhfhaamghhbhbhkbpgfhahlfle" #Windows Common Controls
        "556C75F1-EFBC-11CF-B9F3-00A0247033C4" = "xybiedobrqsprbijaegcbislrsiucfjdhisl" #Data Bound Grid Control 5.0(SP3)
        "096EFC40-6ABF-11cf-850C-08002B30345D" = "knsgigmnmngnmnigthmgpninrmumhgkgrlrk" #Data Bound List Controls 6.0
        "78E1BDD1-9941-11cf-9756-00AA00C00908" = "yjrjvqkjlqqjnqkjvprqsjnjvkuknjpjtoun" #Internet Transfer Control 6.0
        "B1EFCCF0-6AC1-11cf-8ADB-00AA00C00905" = "qqkjvqpqmqjjpqjjvpqqkqmqvkypoqjquoun" #Multimedia Control 6.0
        "7C35CA30-D112-11cf-8E72-00A0C90F26F8" = "whmhmhohmhiorhkouimhihihwiwinhlosmsl" #Chart Control 6.0
        "4F86BADF-9F77-11d1-B1B7-0000F8753F5D" = "iplpwpnippopupiivjrioppisjsjlpiiokuj" #Windows Common Control-2 6.0
        "ED4B87C4-9F76-11d1-8BF7-0000F8754DA1" = "knlggnmntgggrninthpgmnngrhqhnnjnslsh" #Windows Common Controls 6.0
        "4250E830-6AC2-11cf-8ADB-00AA00C00905" = "kjljvjjjoquqmjjjvpqqkqmqykypoqjquoun" #Comm Control 6.0
        "CDE57A55-8B86-11D0-b3C6-00A0C90AEA82" = "ekpkhddkjkekpdjkqemkfkldoeoefkfdjfqe" #DataGrid Control 6.0 (OLEDB)
        "A133F000-CCB0-11d0-A316-00AA00688B10" = "cibbcimbpihbbbbbnhdbeidiocmcbbdbgdoc" #DataList Control 6.0 (OLEDB)
        "D015B071-D2ED-11d0-A31A-00AA00688B10" = "gjdcfjpcmjicjcdcoihcechjlioiccechepd" #DBWin
        "9DF1A470-BA8E-11D0-849C-00A0C90DC8A9" = "cchcqjejhcgcqcfjpdfcdjkckiqikchcojpd" #MSDBRPT
        "1F3D5522-3F42-11d1-B2FA-00A0C908FB55" = "gcfjdjecpchcncdjpdejijgcrdoijjfcieod" #FlexGrid Control 6.0
        "899B3E80-6AC6-11cf-8ADB-00AA00C00905" = "wjsjjjlqmjpjrjjjvpqqkqmqukypoqjquoun" #MAPI Controls 6.0
        "B1692F60-23B0-11D0-8E95-00A0C90F26F8" = "mjjjccncgjijrcfjpdfjfcejpdkdkcgjojpd" #MSRDO 2.0
        "43478d75-78e0-11cf-8e78-00a0d100038e" = "imshohohphlmnhimuinmphmmuiminhlmsmsl" #RemoteData Control 6.0
        "80E80EF0-DBBE-11D0-BCE2-00A0C90DCA10" = "qijimitpmpnpxplpvjnikpkpqoxjmpkpoivj" #Windowless Controls 6.0
        "6FB38640-6AC7-11cf-8ADB-00AA00C00905" = "gdjkokgdldikhdddpjkkekgknesjikdkoioh" #PictureClip Control 6.0
        "DC4D7920-6AC8-11cf-8ADB-00AA00C00905" = "iokouhloohrojhhhtnooiokomiwnmohosmsl" #Rich TextBox Control 6.0
        "190B7910-992A-11cf-8AFA-00AA00C00905" = "gclclcejjcmjdcccoikjlcecoioijjcjnhng" #Sheridan Tab Control
        "E32E2733-1BC5-11d0-B8C3-00A0C90DCA10" = "kmhfimlflmmfpffmsgfmhmimngtghmoflhsg" #SysInfo Control 6.0
        "2c49f800-c2dd-11cf-9ad6-0080c7e7b78d" = "mlrljgrlhltlngjlthrligklpkrhllglqlrk" #Winsock Control 6.0
    }
    foreach ( $Guid in $VB6Licenses.Keys ) {
        $LicenseKey     = $VB6Licenses[$Guid]
        $RegistryPath   = "HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Licenses\$Guid"
        Set-ADTRegistryKey -LiteralPath $RegistryPath -Name "(Default)" -Value $LicenseKey -Type 'String' -Wow6432Node
    }

    #Several DLLs are already part of `DCTOPService.exe`, confirmed by decompiling. Copying anyway to be sure.
    Copy-ADTFile -Path "$($adtSession.DirFiles)\DCTopsRemoteInterface.dll" -Destination "$($envProgramFiles)\Softix\DCTops\DCTopsRemoteInterface.dll"
    Copy-ADTFile -Path "$($adtSession.DirFiles)\Interop.MSCommLib.dll" -Destination "$($envProgramFiles)\Softix\DCTops\Interop.MSCommLib.dll"
    Copy-ADTFile -Path "$($adtSession.DirFiles)\Microsoft.ApplicationBlocks.ExceptionManagement.dll" -Destination "$($envProgramFiles)\Softix\DCTops\Microsoft.ApplicationBlocks.ExceptionManagement.dll"
    Copy-ADTFile -Path "$($adtSession.DirFiles)\Microsoft.ApplicationBlocks.ExceptionManagement.Interfaces.dll" -Destination "$($envProgramFiles)\Softix\DCTops\Microsoft.ApplicationBlocks.ExceptionManagement.Interfaces.dll"

    #Replace `regsvr32 mscomm32.ocx`
    Copy-ADTFile -Path "$($adtSession.DirFiles)\MSCOMM32.OCX" -Destination "$($envWinDir)\SysWOW64\MSCOMM32.OCX"
    Copy-ADTFile -Path "$($adtSession.DirFiles)\MSCOMM32.DEP" -Destination "$($envWinDir)\SysWOW64\MSCOMM32.DEP"
    Invoke-ADTRegSvr32 -FilePath "$($envWinDir)\SysWOW64\MSCOMM32.OCX" -Action 'Register'
    
    #Replace `installutil DCTOPService.exe` and `subinacl /service dctopsservice /grant=users=STOP` (fixdctops.bat)
    #Checked against DCTOPService.exe\DCTOPS\ProjectInstaller.cs and Acronis HKLM\SYSTEM\ControlSet001\Services\DCTopsService
    #https://serverfault.com/questions/187302/how-do-i-grant-start-stop-restart-permissions-on-a-service-to-an-arbitrary-user
    #https://stackoverflow.com/questions/4436558
    Copy-ADTFile -Path "$($adtSession.DirFiles)\DCTOPService.exe" -Destination "$($envProgramFiles)\Softix\DCTops\DCTOPService.exe"
    Copy-ADTFile -Path "$($adtSession.DirFiles)\DCTOPService.exe.config" -Destination "$($envProgramFiles)\Softix\DCTOPService.exe.config"
    $SDDL = "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOSDRCWDWO;;;BA)(A;;CCLCSWRPWPDTLOCRRC;;;AU)"
    New-Service -Name "DCTopsService" -BinaryPathName '"C:\Program Files\Softix\DCTops\DCTOPService.exe"' `
        -DisplayName "DCTops Printer Wrapper" -StartupType "Automatic" -SecurityDescriptorSddl $SDDL
    
    # Dynamically create DCTopsConfigs.xml
    $printerNumber = [Environment]::GetEnvironmentVariable('TEG_TOPS_NUM')
    $siteCode = [Environment]::GetEnvironmentVariable('TEG_SITE_CODE')
    $topsConfig = [System.Xml.Linq.XDocument]::new(
        [System.Xml.Linq.XDeclaration]::new("1.0", "utf-8", $null),
        [System.Xml.Linq.XElement]::new("dctops.config",
            [System.Xml.Linq.XElement]::new("global",
                [System.Xml.Linq.XElement]::new("timetoreconnect", "2"),
                [System.Xml.Linq.XElement]::new("maxbuffersize", "2097152")
            ),
            [System.Xml.Linq.XElement]::new("settings",
                [System.Xml.Linq.XElement]::new("printernumber", $printerNumber),
                [System.Xml.Linq.XElement]::new("tixsyssitecode", $siteCode),
                [System.Xml.Linq.XElement]::new("tixsysaddress", "active-1.ticketek.com.au"),
                [System.Xml.Linq.XElement]::new("topsdcportnumber", "11152"),
                [System.Xml.Linq.XElement]::new("tops2portnumber", "11150"),
                [System.Xml.Linq.XElement]::new("printercomportnumber", "1"),
                [System.Xml.Linq.XElement]::new("printercomsettings", "9600,n,8,1"),
                [System.Xml.Linq.XElement]::new("printerhandshaking", "XOnXOff")
            )
        )
    )
    $topsConfig.ToString | Out-File "$($envProgramFiles)\Softix\DCTops\DCTopsConfigs.xml"

    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Installation tasks here>

    #Replace `startservice.bat` and `stopservice.bat`
    New-ADTShortcut -LiteralPath "$envCommonDesktop\TopsRestart.lnk" -Description "Restart Tops" -TargetPath "$PSHOME\powershell.exe" `
        -Arguments "-Command `"Stop-Service -Name `"DCTopsService`"; Start-Service -Name `"DCTopsService`"`""

    ## Display a message at the end of the install.
    if (!$adtSession.UseDefaultMsi)
    {
        Show-ADTInstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -NoWait
    }
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

    ## If there are processes to close, show Welcome Message with a 60 second countdown before automatically closing.
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        Show-ADTInstallationWelcome -CloseProcesses $adtSession.AppProcessesToClose -CloseProcessesCountdown 60
    }

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Uninstallation tasks here>


    ##================================================
    ## MARK: Uninstall
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI uninstallations.
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
            $ExecuteDefaultMSISplat.Add('Transforms', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
    }

    ## <Perform Uninstallation tasks here>


    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Uninstallation tasks here>
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

    ## If there are processes to close, show Welcome Message with a 60 second countdown before automatically closing.
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        Show-ADTInstallationWelcome -CloseProcesses $adtSession.AppProcessesToClose -CloseProcessesCountdown 60
    }

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Repair tasks here>


    ##================================================
    ## MARK: Repair
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI repairs.
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
            $ExecuteDefaultMSISplat.Add('Transforms', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
    }

    ## <Perform Repair tasks here>


    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Repair tasks here>
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

# Commence the actual deployment operation.
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
    # An unhandled error has been caught.
    $mainErrorMessage = "An unhandled error within [$($MyInvocation.MyCommand.Name)] has occurred.`n$(Resolve-ADTErrorRecord -ErrorRecord $_)"
    Write-ADTLogEntry -Message $mainErrorMessage -Severity 3

    ## Error details hidden from the user by default. Show a simple dialog with full stack trace:
    # Show-ADTDialogBox -Text $mainErrorMessage -Icon Stop -NoWait

    ## Or, a themed dialog with basic error message:
    # Show-ADTInstallationPrompt -Message "$($adtSession.DeploymentType) failed at line $($_.InvocationInfo.ScriptLineNumber), char $($_.InvocationInfo.OffsetInLine):`n$($_.InvocationInfo.Line.Trim())`n`nMessage:`n$($_.Exception.Message)" -ButtonRightText OK -Icon Error -NoWait

    Close-ADTSession -ExitCode 60001
}

