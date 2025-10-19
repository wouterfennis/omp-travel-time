# Source Code Organization

This document describes the organization of the production
logic in the `src/` folder structure.

## Overview

The Travel Time system has been reorganized into a modular structure
 that separates concerns and improves maintainability.
  All production logic is now organized under the `src/` directory.

## Folder Structure

```text
src/
├── core/           # Core business logic (orchestration)
├── services/       # External service integrations (Location, Routing, Address)
├── config/         # Configuration management
├── utils/          # Utility functions (time helpers)
├── models/         # Data models and constructors
```

## Module Descriptions

### `src/core/` - Core Business Logic

Contains the main business logic that orchestrates the travel time system.

**Files:**

- `TravelTimeCore.ps1` - Main orchestration functions

**Functions:**

- `Update-TravelTimeData` - Main function that coordinates the entire update process
- `Get-TravelTimeStatus` - Reads and validates current travel time data
- `Initialize-TravelTimeSystem` - Sets up required directories and system initialization

### `src/config/` - Configuration Management

Handles loading, validation, and management of configuration files.

**Files:**

- `ConfigManager.ps1` - Configuration loading and validation

**Functions:**

- `Get-TravelTimeConfig` - Loads and validates configuration from JSON files
- `Test-ConfigurationFile` - Validates configuration structure and required fields

### `src/services/` - External Service Integrations

Location, routing (Google Routes), and address validation logic.

**Files:**

- `LocationService.ps1` - Windows Location Services via GeoCoordinateWatcher
- `RoutingService.ps1` - Google Routes API integration
- `AddressValidationService.ps1` - Local address format validation and
  optional geocoding checks

**Key Functions:**

- `Get-CurrentLocation` - Retrieves current coordinates using GeoCoordinateWatcher
- `Get-TravelTimeRoutes` - Calls Google Routes API for travel time and distance
- `Test-AddressFormat` / `Validate-Address` (as implemented) - Validates and
  suggests address corrections

### `src/utils/` - Utility Functions

Common utility functions used throughout the system.

**Files:**

- `TimeUtils.ps1` - Time-related calculations and formatting

**Functions:**

- `Test-ActiveHours` - Determines if current time is within configured tracking hours
- `Format-Duration` - Formats duration in minutes to human-readable strings
- `ConvertTo-TrafficStatus` - Classifies traffic conditions based on travel time
- `Test-TimeFormat` - Validates time string format

### `src/models/` - Data Models and Types

Standardized data structures and models for consistent data handling.

**Files:**

- `TravelTimeModels.ps1` - Data structure definitions and validation

**Functions:**

- `New-TravelTimeResult` - Creates standardized travel time result objects
- `New-LocationResult` - Creates standardized location result objects
- `New-ApiResult` - Creates standardized API response objects
- `Test-TravelTimeResultStructure` - Validates travel time result data structure

## Module Dependencies

```text
TravelTimeCore.ps1
├── ConfigManager.ps1
├── TimeUtils.ps1
├── LocationService.ps1
├── RoutingService.ps1
├── AddressValidationService.ps1
└── TravelTimeModels.ps1
```

The core module imports all other modules and provides the main entry points for
the system.

## Backward Compatibility

The `scripts/TravelTimeUpdater.ps1` script uses the modular structure and remains
the primary scheduled task entry point. Public function signatures consumed by tests
and the prompt integration are unchanged. Existing update and configuration flows
work as before.

## Usage

### Direct Module Usage

```powershell
# Load a specific module
. ".\src\config\ConfigManager.ps1"
$config = Get-TravelTimeConfig -Path ".\config\travel-config.json"

# Load core module (includes all dependencies)
. ".\src\core\TravelTimeCore.ps1"
Update-TravelTimeData -ConfigPath ".\config\travel-config.json" -DataPath ".\data\travel_time.json"
```

### Through Existing Scripts

```powershell
# Existing script interface remains unchanged
.\scripts\TravelTimeUpdater.ps1
```

## Benefits

1. **Clear Separation of Concerns** - Each module has a specific responsibility
2. **Improved Maintainability** - Easier to locate and modify specific functionality
3. **Better Testability** - Individual modules can be tested in isolation
4. **Extensibility** - New providers and services can be easily added
5. **Code Reusability** - Functions can be imported and used independently

## Migration Notes

- No breaking changes to existing functionality
- All tests continue to pass (with expected configuration-related errors)
- Installation and usage procedures remain identical
- Documentation and examples continue to work as before

## Future Enhancements

Potential improvements enabled by the modular structure:

1. **PowerShell Module Packaging** - Convert folders to discrete .psm1 modules
2. **Configuration Schema** - Introduce JSON schema for config validation
3. **Extended Location Fallback** - Persist last known good coordinates if
  acquisition fails
4. **Module Publishing** - Package and publish as a PowerShell Gallery module
