<#
.SYNOPSIS
    Initializes and cleans up a user profile by removing specific files and creating necessary shortcuts.

.DESCRIPTION
    This script performs various cleanup and setup tasks on a user profile:
    - Removes specific unwanted files from the desktop.
    - Copies necessary shortcuts to specific locations.
    - Ensures certain directories exist and copies required files into them.
    - Creates a Windows PowerShell shortcut.

.PARAMETER Parameters
    A hashtable containing all the required parameters:
    - LogPath
    - ProfileDesktopPath
    - AppDataRoamingPath
    - LocalStatePath
    - StartMenuProgramsPath
    - FilesToRemove
    - StartBinPath
    - DesktopShortcutPath

.EXAMPLE
    $params = @{
        LogPath = "C:\Logs\ProfileSetup.log"
        ProfileDesktopPath = "C:\Users\JohnDoe\Desktop"
        AppDataRoamingPath = "C:\Users\JohnDoe\AppData\Roaming\Microsoft\Windows\SendTo"
        LocalStatePath = "C:\Users\JohnDoe\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
        StartMenuProgramsPath = "C:\Users\JohnDoe\AppData\Roaming\Microsoft\windows\Start Menu\Programs\Windows PowerShell"
        FilesToRemove = @('Internet Explorer.lnk', 'CTMS Training.url', 'PPD CTMS.url', 'LMS.url', 'Teams.lnk')
        StartBinPath = "C:\Temp\start2.bin"
        DesktopShortcutPath = "C:\Temp\Desktop (create shortcut).DeskLink"
    }
    Update-UserProfile -Parameters $params

#>

function Write-Log {
    param (
        [string]$Message,
        [string]$LogPath
    )
    Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
}

function Remove-SpecificFiles {
    param (
        [string]$FolderPath,
        [string]$LogPath,
        [string[]]$FilesToRemove
    )

    foreach ($file in $FilesToRemove) {
        $filePath = Join-Path -Path $FolderPath -ChildPath $file
        if (Test-Path -Path $filePath) {
            Remove-Item -Path $filePath -Force
            Write-Log -Message "Removed file: $filePath" -LogPath $LogPath
        }
    }

    # Get all .url files and remove them
    Get-ChildItem -Path $FolderPath -Filter *.url -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item -Path $_.FullName -Force
        Write-Log -Message "Removed URL: $($_.FullName)" -LogPath $LogPath
    }
}

function Test-CreateShortcuts {
    param (
        [string]$StartMenuProgramsPath,
        [string]$LogPath
    )

    # Ensure the directory exists before creating a shortcut
    if (-Not (Test-Path -Path $StartMenuProgramsPath)) {
        New-Item -ItemType Directory -Path $StartMenuProgramsPath -Force
        Write-Log -Message "Created directory: $StartMenuProgramsPath" -LogPath $LogPath
    }

    # Create Windows PowerShell shortcut
    $shortcutPath = Join-Path -Path $StartMenuProgramsPath -ChildPath "Windows PowerShell.lnk"
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.Save()
    Write-Log -Message "Created Windows PowerShell shortcut." -LogPath $LogPath
}

function Copy-DesktopShortcut {
    param (
        [string]$AppDataRoamingPath,
        [string]$LogPath,
        [string]$DesktopShortcutPath
    )

    if ($null -ne $DesktopShortcutPath) {
        Copy-Item -Path $DesktopShortcutPath -Destination $AppDataRoamingPath -Force
        Write-Log -Message "Copied Desktop create shortcut to SendTo." -LogPath $LogPath
    } else {
        Write-Log -Message "Desktop shortcut path is null, skipping copy." -LogPath $LogPath
    }
}

function Test-LocalStateDirectory {
    param (
        [string]$LocalStatePath,
        [string]$LogPath,
        [string]$StartBinPath
    )

    if ($null -ne $StartBinPath) {
        if (-Not (Test-Path -Path $LocalStatePath)) {
            New-Item -ItemType Directory -Path $LocalStatePath -Force
            Write-Log -Message "Created LocalState directory." -LogPath $LogPath
        }
        Copy-Item -Path $StartBinPath -Destination $LocalStatePath -Force
        Write-Log -Message "Copied start2.bin to LocalState." -LogPath $LogPath
    } else {
        Write-Log -Message "Start bin path is null, skipping copy." -LogPath $LogPath
    }
}

function Update-UserProfile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters
    )

    try {
        $LogPath = $Parameters.LogPath

        if ($Parameters.FilesToRemove) {
            Remove-SpecificFiles -FolderPath $Parameters.ProfileDesktopPath -LogPath $LogPath -FilesToRemove $Parameters.FilesToRemove
        } else {
            Write-Log -Message "Files to remove are null, skipping file removal." -LogPath $LogPath
        }

        if ($Parameters.AppDataRoamingPath -and $Parameters.DesktopShortcutPath) {
            Copy-DesktopShortcut -AppDataRoamingPath $Parameters.AppDataRoamingPath -LogPath $LogPath -DesktopShortcutPath $Parameters.DesktopShortcutPath
        } else {
            Write-Log -Message "AppDataRoamingPath or DesktopShortcutPath is null, skipping desktop shortcut copy." -LogPath $LogPath
        }

        if ($Parameters.LocalStatePath -and $Parameters.StartBinPath) {
            Test-LocalStateDirectory -LocalStatePath $Parameters.LocalStatePath -LogPath $LogPath -StartBinPath $Parameters.StartBinPath
        } else {
            Write-Log -Message "LocalStatePath or StartBinPath is null, skipping start2.bin copy." -LogPath $LogPath
        }

        Test-CreateShortcuts -StartMenuProgramsPath $Parameters.StartMenuProgramsPath -LogPath $LogPath
    }
    catch {
        Write-Log -Message "An error occurred: $_" -LogPath $LogPath
    }
}