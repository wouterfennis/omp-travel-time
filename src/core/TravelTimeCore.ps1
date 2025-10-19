#Requires -Version 5.1

<#
.SYNOPSIS
    Core business logic for the Travel Time system.

.DESCRIPTION
    This module contains the main business logic for updating travel time data,
    orchestrating the various components of the system.
#>

# Import required modules
. "$PSScriptRoot\..\config\ConfigManager.ps1"
. "$PSScriptRoot\..\utils\TimeUtils.ps1"
. "$PSScriptRoot\..\services\LocationService.ps1"
. "$PSScriptRoot\..\services\RoutingService.ps1"
. "$PSScriptRoot\..\models\TravelTimeModels.ps1"

function Update-TravelTimeData {
    <#
    .SYNOPSIS
        Main function to update travel time data.
    
    .DESCRIPTION
        Orchestrates the entire travel time update process including configuration loading,
        active hours checking, location retrieval, API calls, and data file writing.
    
    .PARAMETER ConfigPath
        Path to the configuration file.
    
    .PARAMETER DataPath
        Path where the travel time data should be written.
    
    .EXAMPLE
        Update-TravelTimeData -ConfigPath ".\config\travel-config.json" -DataPath ".\data\travel_time.json"
    #>
    param(
        [string]$ConfigPath,
        [string]$DataPath
    )
    
    # Load configuration
    $config = Get-TravelTimeConfig -Path $ConfigPath
    if (-not $config) { 
        return 
    }
    
    # Check if we're in active hours
    $isActiveHours = Test-ActiveHours -StartTime $config.start_time -EndTime $config.end_time
    
    # Ensure data directory exists
    $dataDir = Split-Path $DataPath -Parent
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
    
    # Create base result structure
    $result = New-TravelTimeResult -Config $config -IsActiveHours $isActiveHours
    
    if ($isActiveHours) {
        Write-Host "Active hours detected, fetching travel time..." -ForegroundColor Yellow
        
        # Get current location
        $location = Get-CurrentLocation
        
        if ($location.Success) {
            Write-Host "Current location: $($location.City), $($location.Region) ($($location.Latitude), $($location.Longitude))" -ForegroundColor Cyan
            $result.location_status = "available"
            
            # Get travel time data
            $travelData = Get-TravelTimeRoutes -ApiKey $config.google_routes_api_key -OriginLat $location.Latitude -OriginLng $location.Longitude -Destination $config.home_address -TravelMode $config.travel_mode -RoutingPreference $config.routing_preference
            
            if ($travelData.Success) {
                $result.travel_time_minutes = $travelData.TravelTimeMinutes
                $result.distance_km = $travelData.DistanceKm
                $result.traffic_status = $travelData.TrafficStatus
                Write-Host "Travel time updated: $($travelData.TravelTimeMinutes) minutes ($($travelData.DistanceKm) km, $($travelData.TrafficStatus) traffic)" -ForegroundColor Green
            }
            else {
                $result.error_message = $travelData.Error
                Write-Warning "Travel time fetch failed: $($travelData.Error)"
            }
        }
        else {
            $result.location_status = "unavailable"
            $result.error_message = "Could not get location: $($location.ErrorMessage)"
            Write-Warning $result.error_message
        }
    }
    else {
        $result.location_status = "inactive"
        Write-Host "Outside active hours ($($config.start_time) - $($config.end_time)). Skipping update." -ForegroundColor Gray
    }
    
    # Write result to file
    try {
        $result | ConvertTo-Json -Depth 2 | Set-Content -Path $DataPath -Encoding UTF8
        Write-Verbose "Data written to: $DataPath"
    }
    catch {
        Write-Error "Failed to write data file: $_"
    }
}

function Get-TravelTimeStatus {
    <#
    .SYNOPSIS
        Gets the current travel time status from the data file.
    
    .DESCRIPTION
        Reads and validates the current travel time data file,
        returning a structured status object.
    
    .PARAMETER DataPath
        Path to the travel time data file.
    
    .OUTPUTS
        Hashtable containing the current travel time status.
    
    .EXAMPLE
        $status = Get-TravelTimeStatus -DataPath ".\data\travel_time.json"
    #>
    param([string]$DataPath)
    
    if (-not (Test-Path $DataPath)) {
        return New-ApiResult -Success $false -Error "Data file not found: $DataPath"
    }
    
    try {
        $data = Get-Content $DataPath | ConvertFrom-Json -AsHashtable
        
        if (Test-TravelTimeResultStructure -Result $data) {
            return New-ApiResult -Success $true -Data $data
        }
        else {
            return New-ApiResult -Success $false -Error "Invalid data structure in file"
        }
    }
    catch {
        return New-ApiResult -Success $false -Error "Failed to read data file: $_"
    }
}

function Initialize-TravelTimeSystem {
    <#
    .SYNOPSIS
        Initializes the travel time system with required directories and files.
    
    .DESCRIPTION
        Creates necessary directories and validates the system setup
        for proper operation.
    
    .PARAMETER ProjectRoot
        The root directory of the project.
    
    .OUTPUTS
        Boolean indicating if initialization was successful.
    
    .EXAMPLE
        $success = Initialize-TravelTimeSystem -ProjectRoot "C:\Projects\TravelTime"
    #>
    param([string]$ProjectRoot)
    
    try {
        # Create data directory if it doesn't exist
        $dataDir = Join-Path $ProjectRoot "data"
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
            Write-Host "Created data directory: $dataDir" -ForegroundColor Green
        }
        
        # Create config directory if it doesn't exist
        $configDir = Join-Path $ProjectRoot "scripts\config"
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            Write-Host "Created config directory: $configDir" -ForegroundColor Green
        }
        
        return $true
    }
    catch {
        Write-Error "Failed to initialize travel time system: $_"
        return $false
    }
}