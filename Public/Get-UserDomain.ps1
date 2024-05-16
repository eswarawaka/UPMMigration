<#
.SYNOPSIS
    Retrieves the domain name for a given SAM account name.

.DESCRIPTION
    The `Get-UserDomain` function searches for a user in Active Directory by SAM account name and retrieves the domain name. It accepts an array of search root paths and logs the search process.

.PARAMETER SamAccountName
    The SAM account name of the user.

.PARAMETER SearchRoots
    An array of search root paths to search in.

.PARAMETER LogPath
    (Optional) Path to the log file where log messages will be written.

.EXAMPLE
    PS C:\> $domain = Get-UserDomain -SamAccountName "jdoe" -SearchRoots @("GC://dc=test,dc=LOCAL", "GC://dc=testing,dc=LOCAL")

.EXAMPLE
    PS C:\> $domain = Get-UserDomain -SamAccountName "jdoe" -SearchRoots @("GC://dc=test,dc=LOCAL") -LogPath "C:\path\to\logfile.log"

.NOTES
    Author: Sundeep Eswarawaka
    Date: 2024-05-16
#>

function Get-UserDomain {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "The SAM account name of the user.")]
        [string]$SamAccountName,

        [Parameter(Mandatory = $true, HelpMessage = "An array of search root paths to search in.")]
        [string[]]$SearchRoots,

        [Parameter(Mandatory = $false, HelpMessage = "Path to the log file where log messages will be written.")]
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

    # Define the search filter
    $strFilter = "(&(objectCategory=User)(sAMAccountName=$SamAccountName))"

    # Function to perform search
    function Search-AD {
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
                $searchResult = $results[0].GetDirectoryEntry()
                $distinguishedName = $searchResult.Properties["distinguishedName"][0]
                $domainName = [regex]::Match($distinguishedName, 'DC=([^,]+)').Groups[1].Value
                return $domainName
            } else {
                return $false
            }
        } catch {
            Write-Log -Message "Error searching in $SearchRoot : $_" -LogPath $LogPath
            return $false
        }
    }

    $domain = $false
    foreach ($searchRoot in $SearchRoots) {
        $domain = Search-AD -SearchRoot $searchRoot -Filter $strFilter -LogPath $LogPath
        if ($domain) {
            Write-Log -Message "Found SAM account name $SamAccountName in domain: $domain" -LogPath $LogPath
            break
        }
    }

    if (-not $domain) {
        Write-Log -Message "SAM account name $SamAccountName not found in any domain" -LogPath $LogPath
    }

    return $domain
}