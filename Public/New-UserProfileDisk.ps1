<#
.SYNOPSIS
    Creates and manages a VHD for a user profile.

.DESCRIPTION
    This function creates a new VHD for a user profile, formats it, assigns a drive letter, and manages the permissions for the specified user. It can also mount an existing VHD.

.PARAMETER Target
    The target path for the VHD.

.PARAMETER ProfilePath
    The profile path for the VHD (optional).

.PARAMETER Username
    The username for which the VHD will be created or managed.

.PARAMETER Size
    The size of the VHD in GB.

.PARAMETER SectorSize
    The sector size for the VHD (optional). Valid values are '4K' or '512'.

.PARAMETER PrimarySearchRoot
    The primary Active Directory search root.

.PARAMETER SecondarySearchRoot
    The secondary Active Directory search root.

.PARAMETER LogPath
    The path to the log file where messages will be recorded.

.EXAMPLE
    New-UserProfileDisk -Target "C:\VHDs\UserProfile.vhdx" -Username "jdoe" -Size 50 -SectorSize '4K' -PrimarySearchRoot "GC://dc=test,dc=LOCAL" -SecondarySearchRoot "GC://dc=corp,dc=test,dc=com" -LogPath "C:\Logs\ProfileDisk.log"
#>

function New-UserProfileDisk {
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param (
        [Parameter(ValueFromPipelineByPropertyName, Mandatory = $True)]
        [string]$Target,

        [Parameter(ValueFromPipelineByPropertyName, Mandatory = $False)]
        [string]$ProfilePath,

        [Parameter(ValueFromPipelineByPropertyName, Mandatory = $True)]
        [string]$Username,

        [Parameter(ValueFromPipelineByPropertyName, Mandatory = $True)]
        [uint64]$Size,

        [Parameter(ValueFromPipelineByPropertyName, Mandatory = $False)]
        [ValidateSet('4K', '512')]
        [string]$SectorSize,

        [Parameter(Mandatory = $False)]
        [string]$LogPath
    )
    
    function Write-Log {
        param (
            [string] $Message,
            [string] $LogPath
        )
        Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    }


        $OutputObject = @()
        if ($SectorSize -eq '4K'){
            $SectorSizeBytes = 4096
        }
        if ($SectorSize -eq '512'){
            $SectorSizeBytes = 512
        }
        
        function New-FSLogixVHD ($Target,$Size,$SectorSizeBytes){
            Write-Output "Creating, formatting, and mounting VHD."
            Write-Log -Message "Creating, formatting, and mounting VHD." -LogPath $LogPath
            $Size = ($Size * 1GB)
            New-VHD -path $Target -SizeBytes $Size -Dynamic -LogicalSectorSizeBytes $SectorSizeBytes |
            Mount-VHD -Passthru |  `
            get-disk -number {$_.DiskNumber} | `
            Initialize-Disk -PartitionStyle GPT -PassThru | `
            New-Partition -UseMaximumSize -AssignDriveLetter:$False | `
            Format-Volume -Confirm:$false -FileSystem NTFS -NewFileSystemLabel "Profile-$($Username)" -force | `
            get-partition | `
            Add-PartitionAccessPath -AssignDriveLetter -PassThru | `
            Dismount-VHD $Target -ErrorAction SilentlyContinue
        }

        function Mount-FSLogixVHD ($Target){
            Write-Output "Mounting VHD."
            Write-Log -Message "Mounting VHD." -LogPath $LogPath
            Mount-VHD $Target
            (Get-DiskImage -ImagePath $Target | `
                Get-Disk | `
                Get-Partition).DriveLetter
            Get-PSDrive | Out-Null
        }
      
    
        if ($pscmdlet.ShouldProcess($Name, 'Action')){
            if ($Target -ne "Cannot Copy"){
                if (!(Test-Path ($Target.Substring(0, $Target.LastIndexOf('.')) + "*"))) {

                    New-FSLogixVHD -Target $Target -Size $Size -SectorSizeBytes $SectorSizeBytes
                    icacls "$Target" /grant $Username`:f /t
                    Write-Output "Mounting VHD $Target"
                    Write-Log -Message "Mounting VHD $Target" -LogPath $LogPath
                    Mount-VHD $Target -ErrorAction SilentlyContinue
                    $drive = (Get-DiskImage -ImagePath $Target | Get-Disk | Get-Partition).DriveLetter
                    Start-Sleep 6
                    if (($Drive | Measure-Object).count -gt 1){
                        $Drive = $drive[1]}
                    $Item = New-Object system.object
                    $Item | Add-Member -Type NoteProperty -Name Drive -Value "$drive`:\"
                    $Item | Add-Member -Type NoteProperty -Name Target -Value $Target
                    $OutputObject += $Item
                }
                else {
                    Write-Output "$($Target.Substring(0, $Target.LastIndexOf('.'))) already exists- Updating."
                    Write-Log -Message "$($Target.Substring(0, $Target.LastIndexOf('.'))) already exists- Updating."
                    icacls "$Target" /grant $Username`:f /t
                    Write-Output "Mounting VHD $Target"
                    Write-Log -Message "Mounting VHD $Target" -LogPath $LogPath
                    Mount-VHD $Target -ErrorAction SilentlyContinue
                    $drive = (Get-DiskImage -ImagePath $Target | Get-Disk | Get-Partition).DriveLetter
                    Start-Sleep 6
                    if (($Drive | Measure-Object).count -gt 1){
                        $Drive = $drive[1]}
                    $Item = New-Object system.object
                    $Item | Add-Member -Type NoteProperty -Name Drive -Value "$drive`:\"
                    $Item | Add-Member -Type NoteProperty -Name Target -Value $Target
                    $OutputObject += $Item
                }
            }
        }
    
    $OutputObject
    
}
