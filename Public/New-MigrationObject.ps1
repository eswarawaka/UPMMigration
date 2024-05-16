<#
.SYNOPSIS
    Parses user profile paths and generates migration objects for each profile.

.DESCRIPTION
    This function parses user profile paths, extracts relevant information such as username, version, and SID, and generates migration objects for each profile. It supports options for generating VHDs and swapping directory name components.

.PARAMETER ProfilePath
    The path to the user profile that needs to be migrated.

.PARAMETER Target
    The target path where the migrated profile will be stored.

.PARAMETER VHD
    A switch to indicate whether the target should be a VHD file.

.PARAMETER SwapDirectoryNameComponents
    A switch to indicate whether to swap the directory name components in the target path.

.EXAMPLE
    $params = @{
        ProfilePath = "C:\Users\JohnDoe"
        Target = "D:\Profiles"
    }
    New-MigrationObject @params

.EXAMPLE
    New-MigrationObject -ProfilePath "C:\Users\JohnDoe" -Target "D:\Profiles" -VHD

.EXAMPLE
    New-MigrationObject -ProfilePath "C:\Users\JohnDoe" -Target "D:\Profiles" -SwapDirectoryNameComponents
#>

function New-MigrationObject {
    [CmdletBinding(SupportsShouldProcess = $True)]
    param (
        [Parameter(ValueFromPipelineByPropertyName, Mandatory = $True)]
        [string]$ProfilePath,

        [Parameter(ValueFromPipelineByPropertyName, Mandatory = $True)]
        [string]$Target,

        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]$VHD,

        [Parameter()]
        [switch]$SwapDirectoryNameComponents
    )

    Begin {
        $SIDRegex = "S-\d-\d+-(\d+-){1,14}\d+"
        $VersionRegex = "(?i)(\.V\d)"
        $OutputObject = @()
    }

    Process {
        if ($PSCmdlet.ShouldProcess($ProfilePath, 'Parsing')) {

            $Split = (Split-Path $ProfilePath -Leaf)
            if ($ProfilePath) {
                if ($Split -match $VersionRegex) {
                    $Username = ($Split -split $VersionRegex)[0]
                    $Version = $Split.Replace("$Username.", "")
                } else {
                    $Version = "none"
                }

                if ($Split -match $SIDRegex) {
                    $UserSID = ($Split | Select-String -Pattern $SIDRegex).Matches.Groups.Value[0]
                    try {
                        $Username = (Get-ADUser -Identity $UserSID).SamAccountName
                    } catch {
                        $Username = "Not Found"
                    }
                } else {
                    $Username = ($Split -split $VersionRegex)[0]
                }

                try {
                    $UserSID = (New-Object System.Security.Principal.NTAccount($Username)).Translate([System.Security.Principal.SecurityIdentifier]).Value
                } catch {
                    $UserSID = "SID Not Found"
                }

                $Extension = if ($VHD) { ".vhdx" } else { ".vhdx" }

                if (($Target.ToString().ToCharArray() | Select-Object -Last 1) -ne "\") {
                    $Target += "\"
                }

                if ($UserSID -ne "SID Not Found") {
                    if ($SwapDirectoryNameComponents) {
                        $NewTarget = $Target+$Username+"_"+$UserSID+"\Profile_"+$Username+$Extension
                    } else {
                        $NewTarget = $Target+$UserSID+"_"+$Username+"\Profile_"+$Username+$Extension
                    }
                } else {
                    $NewTarget = "Cannot Copy"
                }

                $Item = New-Object PSObject -Property @{
                    ProfilePath = $ProfilePath
                    Username = $Username
                    Version = $Version
                    UserSID = $UserSID
                    Target = $NewTarget
                }
                $OutputObject += $Item
            }
        }
    }

    End {
        $OutputObject
    }
}
