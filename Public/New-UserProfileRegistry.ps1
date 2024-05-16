<#
.SYNOPSIS
    Converts a user SID to a SAM account name and creates a registry file.

.DESCRIPTION
    The `New-UserProfileRegistry` function converts a user SID to a SAM account name using specified search roots and creates a registry file for FSLogix profile data.

.PARAMETER UserSID
    The SID of the user.

.PARAMETER Drive
    The drive where the registry file will be created.

.PARAMETER SearchRoots
    An array of search root paths to search in.

.PARAMETER LogPath
    (Optional) Path to the log file where log messages will be written.

.EXAMPLE
    PS C:\> New-UserProfileRegistry -UserSID "S-1-5-21-..." -Drive "D:" -SearchRoots @("GC://dc=test,dc=LOCAL", "GC://dc=testing,dc=LOCAL")

.EXAMPLE
    PS C:\> New-UserProfileRegistry -UserSID "S-1-5-21-..." -Drive "D:" -SearchRoots @("GC://dc=test,dc=LOCAL") -LogPath "C:\path\to\logfile.log"

.NOTES
    Author: Sundeep Eswarawaka
    Date: 2024-05-16
#>
function New-UserProfileRegistry {
    [CmdletBinding(SupportsShouldProcess = $True)]
    param (
        [Parameter(ValueFromPipelineByPropertyName, Mandatory = $True)]
        [string]$UserSID,

        [Parameter(ValueFromPipelineByPropertyName, Mandatory = $True)]
        [string]$Drive,

        [Parameter(Mandatory = $true)]
        [string[]]$SearchRoots,

        [Parameter(Mandatory = $false)]
        [string]$LogPath
    )
    
    function Write-Log {
        param (
            [string] $Message,
            [string] $LogPath
        )
        if ($LogPath) {
            Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
        } else {
            Write-Host $Message
        }
    }

    if (-not $SearchRoots -or $SearchRoots.Count -eq 0) {
        Write-Log -Message "No search roots provided." -LogPath $LogPath
        Write-Error "No search roots provided."
        return
    }

    if ($PSCmdlet.ShouldProcess($UserSID, "Convert SID to SAM and create reg file")) {
        try {
            $UserSAM = Test-SIDInAD -SIDValue $UserSID -SearchRoots $SearchRoots -LogPath $LogPath
            if (-not $UserSAM) {
                Write-Log -Message "User SAM for SID $UserSID could not be found." -LogPath $LogPath
                Write-Error "User SAM for SID $UserSID could not be found."
                return
            }

            $RegFilePath = Join-Path -Path $Drive -ChildPath "Profile\AppData\local\FSLogix\ProfileData.reg"
            
            $RegText = @"
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$UserSID]
"ProfileImagePath"="C:\\Users\\$UserSAM"
"Flags"=dword:00000000
"State"=dword:00000000
"ProfileLoadTimeLow"=dword:00000000
"ProfileLoadTimeHigh"=dword:00000000
"RefCount"=dword:00000000
"RunLogonScriptSync"=dword:00000000
"@

            if (Test-Path -Path $RegFilePath) {
                Write-Log -Message "Reg file path already exists: $RegFilePath" -LogPath $LogPath
                Write-Warning "Reg file path already exists: $RegFilePath"
            } else {
                New-Item -Path $RegFilePath -ItemType File -Force | Out-Null
                Write-Log -Message "Created new reg file path: $RegFilePath" -LogPath $LogPath
            }

            $RegText | Out-File -FilePath $RegFilePath -Encoding ASCII -Force
            Write-Log -Message "Reg file created/updated at: $RegFilePath" -LogPath $LogPath
            Write-Host "Reg file created/updated at: $RegFilePath"
        } catch {
            Write-Log -Message "An error occurred: $_" -LogPath $LogPath
            Write-Error "An error occurred: $_"
        }
    }
}