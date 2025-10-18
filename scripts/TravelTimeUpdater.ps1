#Requires -Version 5.1

<#
.SYNOPSIS
    Updates travel time data using Google Routes API for Oh My Posh prompt integration.

.DESCRIPTION
    This script fetches current travel time to home using Google Routes API and stores
    the result in a JSON file that can be read by Oh My Posh prompt configuration.
    
    The script only fetches data during configured active hours to optimize API usage.
    
    This script now uses the modular src/ structure for better code organization.

.PARAMETER ConfigPath
    Path to the travel configuration JSON file. Defaults to config\travel-config.json.

.PARAMETER DataPath
    Path where travel time data will be stored. Defaults to ..\data\travel_time.json.

.EXAMPLE
    .\TravelTimeUpdater.ps1
    
.EXAMPLE
    .\TravelTimeUpdater.ps1 -ConfigPath ".\config\travel-config.json" -DataPath ".\data\travel_time.json"
#>

param(
    [string]$ConfigPath = "$PSScriptRoot\config\travel-config.json",
    [string]$DataPath = "$PSScriptRoot\..\data\travel_time.json"
)

# Import the core travel time module
. "$PSScriptRoot\..\src\core\TravelTimeCore.ps1"

# Legacy function stubs for backward compatibility
# These functions are now implemented in the src/ modules but we keep
# references here to maintain compatibility with existing tests

function Get-TravelTimeConfig {
    param([string]$Path)
    # Delegate to the new modular implementation
    return Get-TravelTimeConfig -Path $Path
}

function Test-ActiveHours {
    param([string]$StartTime, [string]$EndTime)
    # Delegate to the new modular implementation
    return Test-ActiveHours -StartTime $StartTime -EndTime $EndTime
}

function Get-CurrentLocation {
    # Delegate to the new modular implementation
    return Get-CurrentLocation
}

function Get-TravelTimeRoutes {
    param(
        [string]$ApiKey,
        [double]$OriginLat,
        [double]$OriginLng,
        [string]$Destination,
        [string]$TravelMode = "DRIVE",
        [string]$RoutingPreference = "TRAFFIC_AWARE"
    )
    # Delegate to the new modular implementation
    return Get-TravelTimeRoutes -ApiKey $ApiKey -OriginLat $OriginLat -OriginLng $OriginLng -Destination $Destination -TravelMode $TravelMode -RoutingPreference $RoutingPreference
}

# Main execution using the new modular implementation
try {
    $VerbosePreference = "Continue"
    Update-TravelTimeData -ConfigPath $ConfigPath -DataPath $DataPath
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
}