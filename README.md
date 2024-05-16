# Citrix UPM to FSLogix Profile Migration

This PowerShell module facilitates the migration of user profiles from Citrix User Profile Manager (UPM) to FSLogix profile solutions. The module is designed to automate the process of migrating entire user profiles, including data and registry modifications, by creating Virtual Hard Disks (VHDs) and copying data from UPM profiles. This script has been tested for Windows 10 to Windows 11 migrations.

## Features

- Checks and ensures required Hyper-V features and services are installed and running.
- Creates VHDs for each user profile to be migrated.
- Copies user data from UPM profiles to FSLogix VHDs.
- Modifies registry entries to match FSLogix requirements.
- Adds or removes shortcuts as needed.
- Logs all operations for troubleshooting and auditing purposes.

## Prerequisites

1. **Windows Server Operating System**: The script must be run on a Windows Server operating system.
2. **Hyper-V Features**: Ensure the following features are installed and enabled:
   - `Hyper-V`
   - `Microsoft-Hyper-V-Management-PowerShell`
   - `RSAT-Hyper-V-Tools`
3. **Hyper-V Virtual Machine Management Service**: The `vmms` service must be running.
4. **UPMMigration Module**: Ensure the `UPMMigration` module is installed. You can install it using the following command:

   ```powershell
   Install-Module -Name UPMMigration


## Installation and Usage

1. Download the module files and place them in a directory.
2. Open PowerShell as an administrator and navigate to the directory containing the module files.

Before starting the migration, ensure that all required features and services are installed and running.

```powershell
Check-HyperVFeatures -LogPath "C:\path\to\logfile.log"
```

To start the profile migration process, run the `Invoke-ProfileMigration` function with the necessary parameters.

```powershell
Invoke-ProfileMigration -ProfilePath "C:\Users\jdoe" -HomePath "H:\jdoe" -Target "E:\MigratedProfiles\jdoe.vhd" -VHDMaxSizeGB 100 -VHDLogicalSectorSize "4K" -SearchRoots @("GC://dc=test,dc=LOCAL", "GC://dc=testing,dc=LOCAL") -LogPath "C:\Logs\migration.log"
```

### Parameters

- `ProfilePath` (string, mandatory): Path to the profile to be migrated.
- `HomePath` (string, mandatory): Path to the home directory.
- `Target` (string, mandatory): Target path for the migrated profile.
- `VHDMaxSizeGB` (uint64, mandatory): Maximum size of the VHD in GB.
- `VHDLogicalSectorSize` (string, mandatory): Logical sector size of the VHD. Valid values are '4K' and '512'.
- `SearchRoots` (string[], mandatory): Array of search root paths to search in.
- `LogPath` (string, optional): Path to the log file where log messages will be written.
- `RegistryPaths` (string[], optional): Array of registry paths to remove.
- `FilestoRemove` (string[], optional): Array of files to remove.
- `VHD` (switch, optional): Switch to create a VHD.
- `IncludeRobocopyDetail` (switch, optional): Switch to include detailed Robocopy logs.

## Function Descriptions

### Check-HyperVFeatures

Checks if the required Hyper-V features and services are installed and running.

### Invoke-ProfileMigration

Migrates a user profile from Citrix UPM to FSLogix by creating a VHD, copying data, modifying registries, and adding/removing shortcuts.

## Logging

All operations are logged for troubleshooting and auditing purposes. Specify the path to the log file using the `LogPath` parameter.

## Notes

- Ensure you have adequate permissions to run the scripts and perform the migration.
- Backup profiles and important data before starting the migration process.

Author
Sundeep Eswarawaka
