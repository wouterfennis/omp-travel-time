#Requires -Version 5.1

<#
.SYNOPSIS
    Updates travel time data using Google Routes API for Oh My Posh prompt integration.

.DESCRIPTION
    This script fetches current travel time to home using Google Routes API and stores
    the result in a JSON file that can be read by Oh My Posh prompt configuration.
    
    The script only fetches data during configured active hours to optimize API usage.

.PARAMETER ConfigPath
    Path to the travel configuration JSON file.

.PARAMETER DataPath
    Path where travel time data will be stored.

.EXAMPLE
    .\TravelTimeUpdater.ps1
    
.EXAMPLE
    .\TravelTimeUpdater.ps1 -ConfigPath ".\config\travel-config.json" -DataPath ".\data\travel_time.json"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,
    
    [Parameter(Mandatory = $true)]
    [string]$DataPath
)

# Import the core travel time module
. "$PSScriptRoot\..\src\core\TravelTimeCore.ps1"

# Legacy function stubs for backward compatibility
# These functions are now implemented in the src/ modules but we keep
# references here to maintain compatibility with existing tests

# Note: The functions are already loaded from the core module import above,
# so we don't need to redefine them. The original functions from the modules
# are available directly.

# Main execution using the new modular implementation
try {
    $VerbosePreference = "Continue"
    Update-TravelTimeData -ConfigPath $ConfigPath -DataPath $DataPath
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
}