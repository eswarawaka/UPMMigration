<#
.SYNOPSIS
    Checks if the required Hyper-V features and services are installed and running.

.DESCRIPTION
    The `Check-NeededFeatures` function checks if the specified Hyper-V features (`Hyper-V`, `Microsoft-Hyper-V-Management-PowerShell`, and `RSAT-Hyper-V-Tools`) are installed and enabled. 
    It also checks if the `vmms` (Hyper-V Virtual Machine Management) service is running.

.PARAMETER FeatureName1
    The name of the first feature to check. Defaults to `Hyper-V`.

.PARAMETER FeatureName2
    The name of the second optional feature to check. Defaults to `Microsoft-Hyper-V-Management-PowerShell`.

.PARAMETER FeatureName3
    The name of the third feature to check. Defaults to `RSAT-Hyper-V-Tools`.

.PARAMETER LogPath
    Optional path to a log file for logging messages.

.EXAMPLE
    PS C:\> Check-NeededFeatures

.EXAMPLE
    PS C:\> Check-NeededFeatures -LogPath "C:\path\to\logfile.log"

.EXAMPLE
    PS C:\> Check-NeededFeatures -FeatureName1 "Hyper-V" -FeatureName2 "Microsoft-Hyper-V-Management-PowerShell" -FeatureName3 "RSAT-Hyper-V-Tools" -LogPath "C:\path\to\logfile.log"

.NOTES
    Author: Your Name
    Date: 2024-05-16
#>
function Check-NeededFeatures {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, HelpMessage = "The name of the first feature to check.")]
        [string]$FeatureName1 = "Hyper-V",

        [Parameter(Mandatory = $false, HelpMessage = "The name of the second optional feature to check.")]
        [string]$FeatureName2 = "Microsoft-Hyper-V-Management-PowerShell",

        [Parameter(Mandatory = $false, HelpMessage = "The name of the third feature to check.")]
        [string]$FeatureName3 = "RSAT-Hyper-V-Tools",

        [Parameter(Mandatory = $false, HelpMessage = "Optional path to a log file for logging messages.")]
        [string]$LogPath
    )

    function Write-Log {
        param (
            [string]$Message,
            [string]$LogPath
        )
        if ($LogPath) {
            Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
        } else {
            Write-Host $Message
        }
    }


    # Check if the OS is Windows Server
    $os = Get-WmiObject Win32_OperatingSystem
    if ($os.Caption -notmatch "Windows Server") {
        $errorMsg = "This script needs to be run on a Windows Server operating system."
        Write-Log -Message $errorMsg -LogPath $LogPath
        throw $errorMsg
    }

    Write-Log -Message "Checking if the prerequisites are installed before starting the migration." -LogPath $LogPath
    Write-Log -Message "Checking if the $FeatureName1, $FeatureName2, and $FeatureName3 features are installed or enabled." -LogPath $LogPath

    $feature1 = Get-WindowsFeature -Name $FeatureName1
    if (-not $feature1.Installed) {
        $errorMsg1 = "The $FeatureName1 feature is not installed. Please install it using the following command before running the migration: `Install-WindowsFeature -Name $FeatureName1`."
        Write-Log -Message $errorMsg1 -LogPath $LogPath
        throw $errorMsg1
    } else {
        Write-Log -Message "The $FeatureName1 feature is installed." -LogPath $LogPath
    }

    $feature2 = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName2
    if ($feature2.State -ne 'Enabled') {
        $errorMsg2 = "The $FeatureName2 optional feature is not enabled. Please enable it using the following command before running the migration: `Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName2`."
        Write-Log -Message $errorMsg2 -LogPath $LogPath
        throw $errorMsg2
    } else {
        Write-Log -Message "The $FeatureName2 optional feature is enabled." -LogPath $LogPath
    }

    $feature3 = Get-WindowsFeature -Name $FeatureName3
    if (-not $feature3.Installed) {
        $errorMsg3 = "The $FeatureName3 feature is not installed. Please install it using the following command before running the migration: `Install-WindowsFeature -Name $FeatureName3`."
        Write-Log -Message $errorMsg3 -LogPath $LogPath
        throw $errorMsg3
    } else {
        Write-Log -Message "The $FeatureName3 feature is installed." -LogPath $LogPath
    }

    $service = Get-Service -Name "vmms"
    if ($service.Status -ne 'Running') {
        $errorMsg4 = "The Hyper-V Virtual Machine Management service (vmms) is not running. Please ensure it is installed and running before running the migration."
        Write-Log -Message $errorMsg4 -LogPath $LogPath
        throw $errorMsg4
    } else {
        Write-Log -Message "The Hyper-V Virtual Machine Management service (vmms) is running." -LogPath $LogPath
    }

    Write-Log -Message "All prerequisites are installed for the migration." -LogPath $LogPath
}