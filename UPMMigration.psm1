# Import public functions
Get-ChildItem -Path $PSScriptRoot/Public/*.ps1 -ErrorAction SilentlyContinue | ForEach-Object {
    . $_.FullName
}

# Import private functions
Get-ChildItem -Path $PSScriptRoot/Private/*.ps1 -ErrorAction SilentlyContinue | ForEach-Object {
    . $_.FullName
}

Export-ModuleMember -Function (Get-ChildItem -Path $PSScriptRoot/Public/*.ps1 | ForEach-Object { $_.BaseName })

Export-ModuleMember -Function (Get-ChildItem -Path $PSScriptRoot/Private/*.ps1 | ForEach-Object { $_.BaseName })