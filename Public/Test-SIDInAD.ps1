 <#
.SYNOPSIS
    Searches for a user SAM account name by SID in Active Directory.

.DESCRIPTION
    The `Test-SIDInAD` function searches for a user SAM account name using a provided SID value. 
    It accepts an array of search root paths and logs the search process.

.PARAMETER SIDValue
    The SID value to search for.

.PARAMETER SearchRoots
    An array of search root paths to search in.

.PARAMETER LogPath
    (Optional) Path to the log file where log messages will be written.

.EXAMPLE
    PS C:\> $samaccountname = Test-SIDInAD -SIDValue "S-1-5-21-..." -SearchRoots @("GC://dc=test,dc=LOCAL", "GC://dc=testing,dc=LOCAL")

.EXAMPLE
    PS C:\> $samaccountname = Test-SIDInAD -SIDValue "S-1-5-21-..." -SearchRoots @("GC://dc=test,dc=LOCAL") -LogPath "C:\path\to\logfile.log"

.NOTES
    Author: Sundeep Eswarawaka
    Date: 2024-05-16
#>

function Test-SIDInAD {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SIDValue,

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

    # Define the search filter
    $strFilter = "(&(objectCategory=User)(objectSid=$SIDValue))"

    # Function to perform search
    function Search-ADForSID {
        Param(
            [string]$SearchRoot,
            [string]$Filter,
            [string]$LogPath
        )

        try {
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher
            $objSearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry($SearchRoot)
            $objSearcher.PageSize = 1000
            $objSearcher.Filter = $Filter
            $objSearcher.SearchScope = "Subtree"

            $results = $objSearcher.FindAll()

            if ($results.Count -gt 0) {
                $User = $results[0].GetDirectoryEntry()
                return $User.samaccountname
            } else {
                return $false
            }
        } catch {
            Write-Log -Message "Error searching in $SearchRoot : $_" -LogPath $LogPath
            return $false
        }
    }

    $samaccountname = $false
    foreach ($searchRoot in $SearchRoots) {
        $samaccountname = Search-ADForSID -SearchRoot $searchRoot -Filter $strFilter -LogPath $LogPath
        if ($samaccountname) {
            Write-Log -Message "Found SID $SIDValue in Active Directory with SAM account name: $samaccountname" -LogPath $LogPath
            break
        }
    }

    if (-not $samaccountname) {
        Write-Log -Message "SID $SIDValue not found in Active Directory" -LogPath $LogPath
    }

    return $samaccountname
}