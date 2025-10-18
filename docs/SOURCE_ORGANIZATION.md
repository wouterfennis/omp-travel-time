# Source Code Organization

This document describes the organization of the production logic in the `src/` folder structure.

## Overview

The Travel Time system has been reorganized into a modular structure that separates concerns and improves maintainability. All production logic is now organized under the `src/` directory.

## Folder Structure

```
src/
├── core/           # Core business logic
├── services/       # External service integrations
├── config/         # Configuration management
├── utils/          # Utility functions
├── models/         # Data models and types
└── providers/      # Different provider implementations
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

Provides integration with external APIs and services.

**Files:**
- `LocationService.ps1` - Geolocation and travel time API integrations

**Functions:**
- `Get-CurrentLocation` - IP-based geolocation using external services
- `Get-TravelTimeRoutes` - Google Routes API integration for travel time calculations

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

### `src/providers/` - Provider Implementations

Alternative implementations for different service providers and testing scenarios.

**Files:**
- `ServiceProviders.ps1` - Alternative and mock service providers

**Functions:**
- `Get-MockLocationProvider` - Mock location provider for testing
- `Get-MockTravelTimeProvider` - Mock travel time provider for testing
- `New-AlternativeLocationProvider` - Alternative geolocation service implementation
- `Test-ProviderConnectivity` - Tests connectivity to various service providers

## Module Dependencies

```
TravelTimeCore.ps1
├── ConfigManager.ps1
├── TimeUtils.ps1
├── LocationService.ps1
└── TravelTimeModels.ps1
```

The core module imports all other modules and provides the main entry points for the system.

## Backward Compatibility

The existing `scripts/TravelTimeUpdater.ps1` script has been updated to use the new modular structure while maintaining full backward compatibility:

- All original function signatures are preserved
- All existing scripts and tests continue to work unchanged
- The module system is transparent to existing users

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

The modular structure enables several future improvements:

1. **PowerShell Module Packaging** - Convert to proper PowerShell modules (.psm1)
2. **Provider Plugins** - Dynamic loading of alternative service providers
3. **Configuration Validation** - Enhanced validation with schema support
4. **Dependency Injection** - Configurable service implementations
5. **Unit Testing** - Comprehensive test coverage for individual modules