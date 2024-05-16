<#
.SYNOPSIS
    Optimizes user profile folders by removing unnecessary files and folders, and renaming certain folders.

.DESCRIPTION
    This function performs several optimizations on a user profile folder:
    - Removes .ost and Autodiscover.xml files.
    - Removes the Start Menu folder.
    - Renames specific folders by removing the "My " prefix.

.PARAMETER UserProfilePath
    The path to the user profile folder. Default is "E:\Profile".

.PARAMETER LogPath
    The path to the log file where messages will be recorded.

.EXAMPLE
    Remove-UnwantedFiles -UserProfilePath "E:\Profile" -LogPath "C:\Logs\ProfileOptimization.log"

.EXAMPLE
    Remove-UnwantedFiles -UserProfilePath "C:\Users\JohnDoe" -LogPath "C:\Logs\ProfileOptimization.log"

.EXAMPLE
    Remove-UnwantedFiles -LogPath "C:\Logs\ProfileOptimization.log"
#>

function Remove-UnwantedFiles {
    [CmdletBinding()]
    param (
        [string] $UserProfilePath,
        [string] $LogPath
    )

    function Write-Log {
        param (
            [string] $Message,
            [string] $LogPath
        )
        Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    }

    # Define source folder path
    $sourceFolderPath = [System.IO.Path]::Combine($UserProfilePath, 'AppData\Roaming\Microsoft')

    # Remove .ost and .xml files
    if (Test-Path -Path $sourceFolderPath) {
        # Removing .ost files
        Get-ChildItem -Path $sourceFolderPath -Filter *.ost -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item -Path $_.FullName -Force
            Write-Log -Message "Removing File : $($_.FullName)" -LogPath $LogPath
        }

        # Removing .xml files, including hidden ones
        Get-ChildItem -Path $sourceFolderPath -Filter *Autodiscover.xml -Hidden -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item -Path $_.FullName -Force
            Write-Log -Message "Removing File : $($_.FullName)" -LogPath $LogPath
        }
    }

    # Remove the Start Menu folder
    $startMenuPath = Join-Path -Path $UserProfilePath -ChildPath "Start Menu"
    if (Test-Path -Path $startMenuPath) {
        Remove-Item -Path $startMenuPath -Recurse -Force
        Write-Log -Message "Removing Folder : $startMenuPath" -LogPath $LogPath
    }

    # Move and rename specific folders without the "My " prefix
    $foldersToMove = @("Documents\My Videos", "Documents\My Music", "Documents\My Pictures")
    foreach ($folder in $foldersToMove) {
        $fullFolderPath = Join-Path -Path $UserProfilePath -ChildPath $folder
        if (Test-Path -Path $fullFolderPath) {
            $destinationFolder = Join-Path -Path $UserProfilePath -ChildPath (Get-Item $fullFolderPath).Name.Replace("My ", "")
            Move-Item -Path $fullFolderPath -Destination $destinationFolder -Force
            Write-Log -Message "Moving Folder from $fullFolderPath to $destinationFolder" -LogPath $LogPath
        }
    }
}
