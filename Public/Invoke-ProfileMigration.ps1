<#
.SYNOPSIS
    Migrates a user profile to a target location, optionally creating a VHD.

.DESCRIPTION
    The `Invoke-ProfileMigration` function migrates a user profile to a specified target location.
    It supports creating a VHD, copying profile data, setting NTFS permissions, and updating registry configurations.

.PARAMETER ProfilePath
    Path to the profile to be migrated.

.PARAMETER HomePath
    Path to the home directory.

.PARAMETER Target
    Target path for the migrated profile.

.PARAMETER VHDMaxSizeGB
    Maximum size of the VHD in GB.

.PARAMETER VHDLogicalSectorSize
    Logical sector size of the VHD. Valid values are '4K' and '512'.

.PARAMETER SearchRoots
    Array of search root paths to search in.

.PARAMETER LogPath
    (Optional) Path to the log file where log messages will be written.

.PARAMETER RegistryPaths
    (Optional) Array of registry paths to remove.

.PARAMETER FilestoRemove
    (Optional) Array of files to remove.

.PARAMETER VHD
    (Optional) Switch to create a VHD.

.PARAMETER IncludeRobocopyDetail
    (Optional) Switch to include detailed Robocopy logs.

.EXAMPLE
    PS C:\> Invoke-ProfileMigration -ProfilePath "C:\Users\jdoe" -HomePath "H:\jdoe" -Target "E:\MigratedProfiles" -VHDMaxSizeGB 100 -VHDLogicalSectorSize "4K" -SearchRoots @("GC://dc=test,dc=LOCAL", "GC://dc=testing,dc=LOCAL") -LogPath "C:\Logs\migration.log"

.EXAMPLE
    PS C:\> Invoke-ProfileMigration -ProfilePath "C:\Users\jdoe" -HomePath "H:\jdoe" -Target "E:\MigratedProfiles" -VHDMaxSizeGB 100 -VHDLogicalSectorSize "512" -SearchRoots @("GC://dc=test,dc=LOCAL") -RegistryPaths @("Software\MyApp\Settings", "Software\MyApp\Data") -FilestoRemove @("*.tmp", "*.log") -VHD -IncludeRobocopyDetail -LogPath "C:\Logs\migration.log"

.NOTES
    Author: Sundeep Eswarawaka
    Date: 2024-05-16
#>

function Invoke-ProfileMigration {
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param (
        [Parameter(Mandatory = $True, HelpMessage = "Path to the profile to be migrated.")]
        [string]$ProfilePath,

        [Parameter(Mandatory = $false, HelpMessage = "Path to the home directory.")]
        [string]$HomePath,
    
        [Parameter(Mandatory = $True, HelpMessage = "Target path for the migrated profile.")]
        [string]$Target,

        [Parameter(Mandatory = $True, HelpMessage = "Maximum size of the VHD in GB.")]
        [uint64]$VHDMaxSizeGB,

        [Parameter(Mandatory = $True, HelpMessage = "Logical sector size of the VHD.")]
        [ValidateSet('4K', '512')]
        [string]$VHDLogicalSectorSize,

        [Parameter(Mandatory = $true, HelpMessage = "Array of search root paths to search in.")]
        [string[]]$SearchRoots,

        [Parameter(HelpMessage = "Path to the log file where log messages will be written.")]
        [string]$LogPath,

        [Parameter(Mandatory = $false, HelpMessage = "Array of registry paths to remove.")]
        [string[]] $RegistryPaths,

        [Parameter(Mandatory = $false, HelpMessage = "Array of files to remove.")]
        [string[]] $FilestoRemove,

        [Parameter(HelpMessage = "Switch to create a VHD.")]
        [switch]$VHD,

        [Parameter(HelpMessage = "Switch to include detailed Robocopy logs.")]
        [switch]$IncludeRobocopyDetail
    )
    
        # Check prerequisites
        try {
            Check-NeededFeatures -LogPath $LogPath
        } catch {
            Write-Host $_
            return
        }

        $SuccessProfileList = @()
        $FailedProfileList = @()
        $SkippedProfileList = @()
        $CopyParams = @{ }
        $Success = 0
        $Skipped = 0

        function Write-Log {
            param (
                [string]$Message,
                [string]$LogPath
            )
            Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
        }
    
    
        if ($VHD) {
            $Params = @{ 'VHD' = $true }
        } else {
            $Params = @{ }
        }
        
        try {
            $BatchObject = Get-ProfileSource -ProfilePath $ProfilePath -ErrorAction Stop | New-MigrationObject -Target $Target @Params -ErrorAction Stop
        }
        catch {
            Write-Log -Message "Cannot create batch object" -LogPath $LogPath
            Write-Log -Message $_ -LogPath $LogPath
            return
        }
        
        $BatchStartTime = Get-Date
        foreach ($P in $BatchObject) {
            Write-Log -Message "-----------------------------------------------------------------------------" -LogPath $LogPath
            Write-Log -Message "Beginning Migration of $($P.ProfilePath)" -LogPath $LogPath
            Write-Log -Message "-----------------------------------------------------------------------------" -LogPath $LogPath
            
            if ($P.Target -ne "Cannot Copy") {
                $ProfileStartTime = Get-Date
                if (-not (Test-Path ($P.Target.Substring(0, $P.Target.LastIndexOf('.')) + "*"))) {
                    try {
                        $Drive = (New-UserProfileDisk -ProfilePath $P.ProfilePath -Target $P.Target -Username $P.Username -Size $VHDMaxSizeGB -SectorSize $VHDLogicalSectorSize -LogPath $LogPath -ErrorAction Stop).Drive
                    }
                    catch {
                        Write-Log -Message "Could not create or mount Profile Disk" -LogPath $LogPath
                        Write-Log -Message $_ -LogPath $LogPath
                        continue
                    }
                    
                    if ($Drive) {
                        $CopyParams = @{ }
                        if ($IncludeRobocopyDetail) {
                            $CopyParams["IncludeRobocopyDetail"] = $True
                        }
                        
                        try {
                            $changeinpath = Join-Path -Path $P.ProfilePath -ChildPath "UPM_Profile"
                            Invoke-CopyProfileData -Drive $Drive -ProfilePath $changeinpath -LogPath $LogPath @CopyParams

                            if ($null -ne $HomePath) {
                                Invoke-CopyProfileData -Drive $Drive -ProfilePath $HomePath -LogPath $LogPath @CopyParams
                            } else {
                                Write-Log -Message "Skipping HomePath,Since it is null" -LogPath $LogPath
                            }

                        }
                        catch {
                            Write-Log -Message "Could not copy" -LogPath $LogPath
                            Write-Log -Message $_ -LogPath $LogPath
                            continue
                        }

                        $Destination = "$Drive`Profile"
                        
                        $samAccountName = $P.Username
                        
                        # First attempt to find the SID in the primary domain
                        $Domain = Get-UserDomain -SamAccountName $samAccountName -SearchRoots $SearchRoots -LogPath $LogPath -ErrorAction SilentlyContinue
                        
                        try {
                            icacls $Destination /setowner "$Domain\$samAccountName" /T /C | Out-Null
                            icacls $Destination /reset /T | Out-Null
                            $sidvalue = (New-Object System.Security.Principal.NTAccount($samAccountName)).Translate([System.Security.Principal.SecurityIdentifier]).Value

                            # First attempt to find the SID in the primary domain
                            New-UserProfileRegistry -UserSID $sidvalue -Drive $Drive -SearchRoots $SearchRoots -LogPath $LogPath -ErrorAction SilentlyContinue                            

                            Write-Log -Message "Adding User and System NTFS Permissions" -LogPath $LogPath
                        }
                        catch {
                            Write-Log -Message "Cannot create Registry File" -LogPath $LogPath
                            Write-Log -Message $_ -LogPath $LogPath
                            continue
                        }

                        try {
                            icacls $Destination /grant "Administrators:(OI)(CI)F" /T | Out-Null
                            icacls $Destination /grant "$domain\$samAccountName`:(OI)(CI)F" /T | Out-Null
                            icacls $Destination /grant "SYSTEM:(OI)(CI)F" /T | Out-Null
    
                            icacls ($P.Target | Split-Path) /setowner "$Domain\$($P.Username)" /T /C | Out-Null
                            icacls (($P).Target | Split-Path) /grant $domain\$(($P).Username)`:`(OI`)`(CI`)F /T | Out-Null
                        }
                        catch {
                            Write-Log -Message "Could not Add Permissions to Disk" -LogPath $LogPath
                            Write-Log -Message $_ -LogPath $LogPath
                            continue
                        }

                        Remove-UnwantedFiles  -UserProfilePath $Destination -LogPath $LogPath 
                        # Example usage
                        $params1 = @{
                            LogPath = $LogPath
                            ProfileDesktopPath = "$Destination\Desktop"
                            AppDataRoamingPath = "$Destination\AppData\Roaming\Microsoft\Windows\SendTo"
                            LocalStatePath = "$Destination\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
                            StartMenuProgramsPath = "$Destination\AppData\Roaming\Microsoft\windows\Start Menu\Programs\Windows PowerShell"
                            FilesToRemove = $FilestoRemove
                            StartBinPath = "C:\Temp\start2.bin"
                            DesktopShortcutPath = "C:\Temp\Desktop (create shortcut).DeskLink"
                        }
                        Update-UserProfile -Parameters $params1

                        Set-RegistryConfiguration -LogPath $LogPath -NtuserDatPath "$Destination\NTUSER.DAT"

                        Write-Log -Message "Dismounting $($P.Target)" -LogPath $LogPath

                        try {
                            Dismount-VHD $P.Target -ErrorAction Stop
                        }
                        catch {
                            Write-Log -Message "Could not dismount drive" -LogPath $LogPath
                            Write-Log -Message $_ -LogPath $LogPath
                            continue
                        }

                        $ProfileEndTime = Get-Date
                        $ProfileDuration = "{0:hh\:mm\:ss}" -f ($ProfileEndTime - $ProfileStartTime)
                        Write-Log -Message "$($P.ProfilePath) Migrated. Duration: $ProfileDuration" -LogPath $LogPath
                        Write-Output "$($P.ProfilePath) Migrated. Duration: $ProfileDuration"

                        if (Test-Path $P.Target) {
                            $Success++
                            $SuccessProfileList += $P.ProfilePath
                        }
                    }
                    else { 
                        Write-Log -Message "Could not create or mount target drive." -LogPath $LogPath
                        Write-Error "Could not create or mount target drive."
                    }
                }
                else {
                    Write-Log -Message "Profile $($P.Target.Substring(0, $P.Target.LastIndexOf('.'))) already exists. Skipping." -LogPath $LogPath
                    Write-Warning "Profile $($P.Target.Substring(0, $P.Target.LastIndexOf('.'))) already exists. Skipping."
                    $Skipped++
                    $SkippedProfileList += $P.ProfilePath
                }
            }
            elseif ($P.Target -eq "Cannot Copy") {
                Write-Log -Message "Profile $($P.ProfilePath) Could not resolve to AD User. Cannot copy." -LogPath $LogPath
                Write-Warning "Profile $($P.ProfilePath) Could not resolve to AD User. Cannot copy."
                $FailedProfileList += $P.ProfilePath
            }
        }
    
    

        $BatchEndTime = Get-Date
        $duration = $BatchEndTime - $BatchStartTime
        $BatchDuration = "{0:hh\:mm\:ss}" -f $duration
       
        Write-Log -Message "Total duration: $BatchDuration" -LogPath $LogPath
        Write-Output "
-----------------------------------------------------
Profile Migration Completed. 

Source: $ProfilePath
Target: $Target

Start time: $BatchStartTime
End time: $BatchEndTime
Duration: $BatchDuration
    
Total Profiles: $(($batchObject | Measure-Object).count)
Eligible Profiles: $(($batchObject | Where-Object Target -NE "Cannot Copy" | Measure-Object).count)
Successful Migrations: $Success
Skipped Migrations: $Skipped
Failed Migrations: $($(($batchobject | Measure-Object).count) - $($Success) - $($Skipped))"

        if (($SuccessProfileList | Measure-Object).count -gt 0) {
            Write-Output "
Successful Migration List:"
            $SuccessProfileList
        }

        if (($SkippedProfileList | Measure-Object).count -gt 0) {
            Write-Output "
Skipped Migration List:"
            $SkippedProfileList
        }

        if (($FailedProfileList | Measure-Object).count -gt 0) {
            Write-Output "
Failed Migration List:"
            $FailedProfileList
        }

        Write-Output "-----------------------------------------------------"

        if ($LogPath) {
            Add-Content -Path $LogPath -Value "`n"
            Add-Content -Path $LogPath -Value "***************************************************************************************************"
            Add-Content -Path $LogPath -Value "$([DateTime]::Now) - Finished processing"
            Add-Content -Path $LogPath -Value "***************************************************************************************************"
        }
    
}
