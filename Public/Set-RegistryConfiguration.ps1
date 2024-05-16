<#
.SYNOPSIS
    Configures registry settings by loading an NTUSER.DAT file, modifying specified registry paths, and unloading the hive.

.DESCRIPTION
    This function loads a specified NTUSER.DAT file into a temporary registry hive, removes specific registry paths, and then unloads the hive.

.PARAMETER LogPath
    The path to the log file where messages will be recorded.

.PARAMETER NtuserDatPath
    The path to the NTUSER.DAT file to be loaded into the registry.

.PARAMETER RegistryPaths
    The registry paths to be removed from the loaded hive.

.EXAMPLE
    Set-RegistryConfiguration -LogPath "C:\path\to\logfile.log" -NtuserDatPath "C:\Users\Default\NTUSER.DAT"
    Remove registry paths using default paths

.EXAMPLE
    Set-RegistryConfiguration -LogPath "C:\Logs\RegistryUpdate.log" -NtuserDatPath "C:\Users\User\NTUSER.DAT" -RegistryPaths @("Software\Path1", "Software\Path2")
    Remove registry paths using specified paths
#>

function Set-RegistryConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Path to the log file where log messages will be written.")]
        [string] $LogPath,

        [Parameter(Mandatory = $true, HelpMessage = "Path to the NTUSER.DAT file.")]
        [string] $NtuserDatPath,

        [Parameter(Mandatory = $false, HelpMessage = "Array of registry paths to remove. If not specified, default paths will be used.")]
        [string[]] $RegistryPaths
    )

    function Write-Log {
        param (
            [string] $Message,
            [string] $LogPath
        )
        Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    }

    if (-not (Test-Path $NtuserDatPath)) {
        Write-Log -Message "NTUSER.DAT path does not exist: $NtuserDatPath" -LogPath $LogPath
        return
    }

    $hiveName = "TempHive_" + (Get-Date -Format "yyyyMMddHHmm")

    $loadSuccess = $false
    for ($i = 0; $i -lt 3; $i++) {
        $loadResult = Start-Process -FilePath "reg.exe" -ArgumentList "load HKLM\$hiveName $NtuserDatPath" -NoNewWindow -PassThru -Wait | Out-String
        if ($loadResult -match "ERROR") {
            Write-Log -Message "Attempt $($i+1) failed to load NTUSER.DAT: $loadResult" -LogPath $LogPath
            Start-Sleep -Seconds 5
        } else {
            Write-Log -Message "Successfully loaded NTUSER.DAT on attempt $($i+1)" -LogPath $LogPath
            $loadSuccess = $true
            break
        }
    }

    if (-not $loadSuccess) {
        Write-Log -Message "Failed to load NTUSER.DAT after multiple attempts" -LogPath $LogPath
        return
    }

    # Use default registry paths if none are specified
    if (-not $RegistryPaths) {
        $RegistryPaths = @(
            "Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders",
            "Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders",
            "Software\Policies\Microsoft\OneDrive",
            "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2",
            "Network\a",
            "SOFTWARE\Policies\Microsoft\office\16.0\outlook",
            "SOFTWARE\Microsoft\Office\16.0\Outlook\Profiles\Outlook",
            "SOFTWARE\Microsoft\Office\16.0\Outlook"
        )
    }

    foreach ($path in $RegistryPaths) {
        $fullPath = "HKLM:\$hiveName\$path"
        if (-not (Test-Path $fullPath)) {
            Write-Log -Message "Registry path does not exist: $fullPath" -LogPath $LogPath
            continue
        }

        try {
            Remove-Item $fullPath -Recurse -Force
            Write-Log -Message "Removed registry path: $fullPath" -LogPath $LogPath
        } catch {
            Write-Log -Message "Failed to remove registry path: $fullPath. Error: $_" -LogPath $LogPath
        }
    }

    $unloadSuccess = $false
    for ($i = 0; $i -lt 3; $i++) {
        $unloadResult = Start-Process -FilePath "reg.exe" -ArgumentList "unload HKLM\$hiveName" -NoNewWindow -PassThru -Wait | Out-String
        if ($unloadResult -match "ERROR") {
            Write-Log -Message "Attempt $($i+1) failed to unload $hiveName : $unloadResult" -LogPath $LogPath
            Start-Sleep -Seconds 5
        } else {
            Write-Log -Message "Successfully unloaded NTUSER.DAT from HKLM\$hiveName on attempt $($i+1)" -LogPath $LogPath
            $unloadSuccess = $true
            break
        }
    }

    if (-not $unloadSuccess) {
        Write-Log -Message "Failed to unload $hiveName after multiple attempts" -LogPath $LogPath
    }

    if (Test-Path "HKLM:\$hiveName") {
        try {
            Remove-Item "HKLM:\$hiveName" -Recurse -Force
            Write-Log -Message "Successfully removed the hive: HKLM\$hiveName" -LogPath $LogPath
        } catch {
            Write-Log -Message "Failed to remove the hive: HKLM\$hiveName. Error: $_" -LogPath $LogPath
        }
    }
}

