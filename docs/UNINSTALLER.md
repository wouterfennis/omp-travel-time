# Travel Time Service Uninstaller

## Overview

The `Uninstall-TravelTimeService.ps1` script provides comprehensive removal of the Oh My Posh Travel Time service with multiple options for user preferences and safety.

## Features

### Complete Component Removal
- ✅ Scheduled tasks (`OhMyPosh-TravelTime`)
- ✅ Configuration files (`scripts/config/travel-config.json`)
- ✅ Data files (`data/travel_time.json` and directories)
- ✅ Git ignore entries (travel time related)
- ✅ Cleanup verification and reporting

### Flexible Options
- **Interactive Mode**: User prompts for each component
- **Silent Mode**: Automated removal with defaults
- **Preview Mode**: Shows what would be removed without changes
- **Preservation Options**: Keep configuration and/or data files
- **Force Mode**: Bypass confirmations for automation

### Safety Features
- ✅ Administrator privilege detection (cross-platform)
- ✅ User confirmation for destructive operations
- ✅ Comprehensive error handling and logging
- ✅ Component tracking (removed/preserved/failed)
- ✅ Oh My Posh configuration guidance (no corruption)

## Usage Examples

### Basic Interactive Uninstallation
```powershell
.\scripts\Uninstall-TravelTimeService.ps1
```

### Silent Uninstallation
```powershell
.\scripts\Uninstall-TravelTimeService.ps1 -Silent
```

### Preview Mode (What-If)
```powershell
.\scripts\Uninstall-TravelTimeService.ps1 -WhatIf
```

### Preserve User Data
```powershell
.\scripts\Uninstall-TravelTimeService.ps1 -PreserveConfig -PreserveData
```

### Force Mode (No Confirmations)
```powershell
.\scripts\Uninstall-TravelTimeService.ps1 -Force
```

### Combined Options
```powershell
# Silent uninstallation preserving configurations
.\scripts\Uninstall-TravelTimeService.ps1 -Silent -PreserveConfig

# Force removal in preview mode
.\scripts\Uninstall-TravelTimeService.ps1 -Force -WhatIf
```

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Silent` | Switch | Run without user prompts |
| `-PreserveConfig` | Switch | Keep configuration files |
| `-PreserveData` | Switch | Keep data files and logs |
| `-Force` | Switch | Skip confirmation prompts |
| `-WhatIf` | Switch | Preview mode without changes |

## Output and Logging

### Console Output
- ✅ Color-coded status messages
- ✅ Component-by-component progress
- ✅ Summary of removed/preserved/failed items
- ✅ Oh My Posh configuration guidance

### Log File
- **Location**: `data/uninstall.log`
- **Content**: Timestamped operation log
- **Format**: `[YYYY-MM-DD HH:MM:SS] [LEVEL] Message`

### Exit Codes
- `0`: Successful uninstallation
- `1`: Uninstallation failed with errors

## Oh My Posh Configuration

The uninstaller provides guidance for manually cleaning up your Oh My Posh configuration:

1. Open your Oh My Posh configuration file
2. Find the travel time segment (references `data/travel_time.json`)
3. Remove or comment out the segment
4. Reload PowerShell profile: `. $PROFILE`

## Testing

The uninstaller includes comprehensive tests in `tests/Test-Uninstaller.ps1`:

```powershell
# Run uninstaller tests
.\tests\Test-Uninstaller.ps1

# Run all tests including uninstaller
.\tests\Run-AllTests.ps1
```

### Test Coverage
- ✅ Script syntax validation
- ✅ Component identification
- ✅ Preservation options
- ✅ Error handling and logging
- ✅ Safety measures and confirmations
- ✅ Oh My Posh guidance
- ✅ Silent operation mode
- ✅ Parameter validation
- ✅ WhatIf functionality

## Error Handling

### Common Scenarios
- **Missing components**: Gracefully handles already removed items
- **Permission issues**: Provides clear error messages
- **Partial installation**: Removes available components, reports missing ones
- **Cross-platform**: Adapts to Windows/Linux PowerShell differences

### Recovery
- Failed operations are logged and reported
- Partial uninstallation still removes successfully processed components
- Manual cleanup instructions provided for edge cases

## Compatibility

- ✅ PowerShell 5.1+ (Windows PowerShell)
- ✅ PowerShell 7+ (PowerShell Core)
- ✅ Windows 10/11
- ✅ Linux (with PowerShell Core)
- ✅ Cross-platform privilege detection

## Manual Cleanup (Fallback)

If the automated uninstaller fails:

```powershell
# Remove scheduled task
Unregister-ScheduledTask -TaskName "OhMyPosh-TravelTime" -Confirm:$false

# Remove files
Remove-Item "scripts\config\travel-config.json" -Force
Remove-Item "data\travel_time.json" -Force
Remove-Item "data\" -Force  # If empty

# Edit .gitignore manually to remove:
# data/travel_time.json
# scripts/config/travel-config.json
```