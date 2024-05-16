<#
.SYNOPSIS
    Copies user profile data to a specified drive.

.DESCRIPTION
    This function uses Robocopy to copy user profile data to a specified drive. It supports detailed logging, exclusion of certain directories and files, and use of existing targets.

.PARAMETER Drive
    The destination drive for the profile data.

.PARAMETER ProfilePath
    The source path of the profile data.

.PARAMETER LogPath
    The path to the existing log file where messages will be recorded.

.PARAMETER IncludeRobocopyDetail
    Switch to include detailed Robocopy output.

.PARAMETER UseExistingTarget
    Switch to use the existing target and exclude older files.

.EXAMPLE
    Invoke-CopyProfileData -Drive "D:" -ProfilePath "C:\Users\Profile1" -LogPath "C:\Logs\ProfileCopy.log"

.EXAMPLE
    Invoke-CopyProfileData -Drive "D:" -ProfilePath "C:\Users\Profile1" -LogPath "C:\Logs\ProfileCopy.log" -IncludeRobocopyDetail

.EXAMPLE
    Invoke-CopyProfileData -Drive "D:" -ProfilePath "C:\Users\Profile1" -LogPath "C:\Logs\ProfileCopy.log" -UseExistingTarget
#>

function Invoke-CopyProfileData {
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param (
        [Parameter(Mandatory = $True)]
        [string]$Drive,
        
        [Parameter(Mandatory = $True)]
        [string]$ProfilePath,

        [Parameter(Mandatory = $True)]
        [string]$LogPath,

        [Parameter()]
        [switch]$IncludeRobocopyDetail,
        
        [Parameter()]
        [switch]$UseExistingTarget
    )

    function Write-Log {
        param (
            [string]$Message,
            [string]$LogPath
        )
        Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    }

    function Get-FolderSize {
        param (
            [string]$FolderPath
        )
        $folderSize = (Get-ChildItem -Path $FolderPath -Recurse | Measure-Object -Property Length -Sum).Sum
        switch ($folderSize) {
            { $_ -ge 1TB } { return "{0:N2} TB" -f ($folderSize / 1TB) }
            { $_ -ge 1GB } { return "{0:N2} GB" -f ($folderSize / 1GB) }
            { $_ -ge 1MB } { return "{0:N2} MB" -f ($folderSize / 1MB) }
            default { return "{0:N2} KB" -f ($folderSize / 1KB) }
        }
    }

    # Setup Robocopy parameters for detailed or minimal output
    $robocopyParams = '/E /Z /COPYALL /R:2 /W:1'
    if ($UseExistingTarget) {
        $robocopyParams += ' /XO'
    }
    if ($IncludeRobocopyDetail) {
        $robocopyParams += ' /V'  # Verbose output
    } else {
        $robocopyParams += ' /NP'  # No progress - number of files copied
    }
    $robocopyParams += ' /MT:16'  # Multithreading for faster copy

    # Define exclusions
    $excludeDirs = @('/XD "System Volume Information"', '/XD "Start Menu"')
    $excludeFiles = @('/XF *.ost', '/XF "*-Autodiscover.xml"')
    $excludeParams = $excludeDirs + $excludeFiles

    if (-not (Test-Path -Path $LogPath)) {
        New-Item -ItemType File -Path $LogPath | Out-Null
    }

    # Calculate the size of the source folder
    $sourceSize = Get-FolderSize -FolderPath $ProfilePath

    if ($PSCmdlet.ShouldProcess("$ProfilePath", "Copying to $Drive")) {
        $destination = Join-Path -Path $Drive -ChildPath "Profile"

        # Log the start of the copying process
        Write-Log -Message "Starting the copy process using Robocopy." -LogPath $LogPath
        Write-Log -Message "Size of source folder: $sourceSize" -LogPath $LogPath

        # Execute Robocopy and capture output to a temporary file
        $tempLogPath = [System.IO.Path]::GetTempFileName()
        $robocopyCommand = "robocopy.exe `"$ProfilePath`" `"$destination`" *.* $robocopyParams $excludeParams /LOG:`"$tempLogPath`""
        Invoke-Expression $robocopyCommand

        # Read and parse the Robocopy log file for summary information
        $logContent = Get-Content -Path $tempLogPath

        # Extract the required summary details
        $dirLine = $logContent | Select-String -Pattern "Dirs\s+:\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+"
        $fileLine = $logContent | Select-String -Pattern "Files\s+:\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+"

        $dirValues = ($dirLine -replace 'Dirs\s+:\s+', '').Trim() -split '\s+'
        $fileValues = ($fileLine -replace 'Files\s+:\s+', '').Trim() -split '\s+'

        $totalDirs = $dirValues[0]
        $copiedDirs = $dirValues[1]
        $totalFiles = $fileValues[0]
        $copiedFiles = $fileValues[1]

        # Calculate the size of the copied folder
        $copiedSize = Get-FolderSize -FolderPath $destination

        # Log the summary information
        Write-Log -Message "Total Directories: $totalDirs" -LogPath $LogPath
        Write-Log -Message "Copied Directories: $copiedDirs" -LogPath $LogPath
        Write-Log -Message "Total Files: $totalFiles" -LogPath $LogPath
        Write-Log -Message "Copied Files: $copiedFiles" -LogPath $LogPath
        Write-Log -Message "Size of copied folder: $copiedSize" -LogPath $LogPath

        # Check for completion based on Robocopy's exit code
        if ($LASTEXITCODE -le 7) {
            Write-Log -Message "Copy completed successfully." -LogPath $LogPath
            Write-Host "Copy completed successfully. Detailed log available at: $LogPath"
        } else {
            Write-Log -Message "Copy encountered issues." -LogPath $LogPath
            Write-Host "Copy encountered issues. Please check the log at: $LogPath"
        }

        # Append the temporary log file to the specified log path if detailed log is included
        if ($IncludeRobocopyDetail) {
            Get-Content -Path $tempLogPath | Add-Content -Path $LogPath
        }

        # Remove the temporary log file
        Remove-Item -Path $tempLogPath -Force
    }

    Write-Host "Operation completed."
}

