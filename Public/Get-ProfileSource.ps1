<#
.SYNOPSIS
    Retrieves profile paths from a parent directory, a specific path, or a CSV file.

.DESCRIPTION
    This function retrieves profile paths from either a parent directory, a specific profile path, or a CSV file containing paths. It supports importing these paths and returning them as output objects.

.PARAMETER ParentPath
    The parent directory containing profile paths.

.PARAMETER ProfilePath
    A specific profile path.

.PARAMETER CSV
    A CSV file containing profile paths.

.EXAMPLE
    Get-ProfileSource -ParentPath "C:\Profiles"
    
.EXAMPLE
    Get-ProfileSource -ProfilePath "C:\Profiles\Profile1"

.EXAMPLE
    Get-ProfileSource -CSV "C:\Profiles\ProfilePaths.csv"
#>

function Get-ProfileSource {
    [CmdletBinding(SupportsShouldProcess = $True, DefaultParameterSetName = 'ParentPath')]
    Param (
        [Parameter(ValueFromPipelineByPropertyName, Mandatory = $True, ParameterSetName = 'ParentPath')]
        [string]$ParentPath,
        
        [Parameter(ValueFromPipelineByPropertyName, Mandatory = $True, ParameterSetName = 'ProfilePath')]
        [string]$ProfilePath,

        [Parameter(ValueFromPipelineByPropertyName, Mandatory = $True, ParameterSetName = 'CSV')]
        [string]$CSV
    )
    
    Begin {
        $OutputObject = @()
    }
    
    Process {
        if ($PSCmdlet.ParameterSetName -eq 'ParentPath') {
            if ($PSCmdlet.ShouldProcess($ParentPath, 'Import')) {
                $PathList = Get-ChildItem -Path $ParentPath -Directory | Select-Object -ExpandProperty FullName
                foreach ($Path in $PathList) {
                    $Item = [PSCustomObject]@{
                        ProfilePath = $Path
                    }
                    $OutputObject += $Item
                }
            }
        }

        if ($PSCmdlet.ParameterSetName -eq 'ProfilePath') {
            if ($PSCmdlet.ShouldProcess($ProfilePath, 'Import')) {
                $Item = [PSCustomObject]@{
                    ProfilePath = (Get-Item -Path $ProfilePath).FullName
                }
                $OutputObject += $Item
            }
        }

        if ($PSCmdlet.ParameterSetName -eq 'CSV') {
            if ($PSCmdlet.ShouldProcess($CSV, 'Import')) {
                $csvData = Import-Csv -Path $CSV
                if (!$csvData.Path) {
                    Write-Host "No Path header found in the CSV file."
                } else {
                    foreach ($Path in $csvData.Path) {
                        $Item = [PSCustomObject]@{
                            ProfilePath = $Path
                        }
                        $OutputObject += $Item
                    }
                }
            }
        }
    }
    
    End {
        $OutputObject
    }
}
