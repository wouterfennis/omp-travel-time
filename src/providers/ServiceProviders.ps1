#Requires -Version 5.1

<#
.SYNOPSIS
    Provider implementations for different travel time and location services.

.DESCRIPTION
    This module contains different provider implementations that can be used
    as alternatives to the default Google Routes API integration.
#>

function Get-MockLocationProvider {
    <#
    .SYNOPSIS
        Mock location provider for testing purposes.
    
    .DESCRIPTION
        Returns mock location data for testing without making external API calls.
        Useful for development and testing scenarios.
    
    .PARAMETER MockCity
        The mock city name to return.
    
    .PARAMETER MockRegion
        The mock region name to return.
    
    .OUTPUTS
        Hashtable containing mock location information.
    
    .EXAMPLE
        $location = Get-MockLocationProvider -MockCity "Seattle" -MockRegion "WA"
    #>
    param(
        [string]$MockCity = "Test City",
        [string]$MockRegion = "Test Region"
    )
    
    return @{
        Latitude = 47.6062
        Longitude = -122.3321
        Success = $true
        City = $MockCity
        Region = $MockRegion
    }
}

function Get-MockTravelTimeProvider {
    <#
    .SYNOPSIS
        Mock travel time provider for testing purposes.
    
    .DESCRIPTION
        Returns mock travel time data for testing without making external API calls.
        Allows simulation of different traffic conditions and scenarios.
    
    .PARAMETER MockDurationMinutes
        The mock travel time in minutes.
    
    .PARAMETER MockDistanceKm
        The mock distance in kilometers.
    
    .PARAMETER SimulateError
        If true, simulates an API error condition.
    
    .OUTPUTS
        Hashtable containing mock travel time information.
    
    .EXAMPLE
        $travel = Get-MockTravelTimeProvider -MockDurationMinutes 25 -MockDistanceKm 15.5
    #>
    param(
        [int]$MockDurationMinutes = 25,
        [double]$MockDistanceKm = 15.5,
        [switch]$SimulateError
    )
    
    if ($SimulateError) {
        return @{
            Success = $false
            Error = "Mock API error for testing"
        }
    }
    
    # Calculate traffic status and format duration inline to avoid circular dependencies
    $trafficStatus = if ($MockDurationMinutes -gt 45) { "heavy" } 
                   elseif ($MockDurationMinutes -gt 30) { "moderate" } 
                   else { "light" }
    
    $durationText = if ($MockDurationMinutes -lt 60) { "${MockDurationMinutes}m" }
                  else { 
                      $hours = [math]::Floor($MockDurationMinutes / 60)
                      $remainingMinutes = $MockDurationMinutes % 60
                      if ($remainingMinutes -eq 0) { "${hours}h" }
                      else { "${hours}h ${remainingMinutes}m" }
                  }
    
    return @{
        Success = $true
        TravelTimeMinutes = $MockDurationMinutes
        DistanceKm = $MockDistanceKm
        TrafficStatus = $trafficStatus
        DurationText = $durationText
    }
}

function Test-ProviderConnectivity {
    <#
    .SYNOPSIS
        Tests connectivity to various service providers.
    
    .DESCRIPTION
        Checks if different location and mapping service providers are accessible
        and returns a report of their availability.
    
    .OUTPUTS
        Hashtable containing connectivity status for different providers.
    
    .EXAMPLE
        $connectivity = Test-ProviderConnectivity
        Write-Host "Google Routes API accessible: $($connectivity.GoogleRoutes)"
    #>
    $results = @{
        IpApi = $false
        IpInfo = $false
        GoogleRoutes = $false
        TestTimestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    
    # Test Google Routes API endpoint (without API key, just connectivity)
    try {
        # This will return an authentication error, but confirms the endpoint is reachable
        Invoke-RestMethod -Uri "https://routes.googleapis.com/directions/v2:computeRoutes" -Method Post -TimeoutSec 5 -ErrorAction SilentlyContinue
        $results.GoogleRoutes = $true
    }
    catch {
        # Check if it's an authentication error (means endpoint is reachable)
        if ($_.Exception.Message -like "*401*" -or $_.Exception.Message -like "*403*") {
            $results.GoogleRoutes = $true
        }
        else {
            $results.GoogleRoutes = $false
        }
    }
    
    return $results
}