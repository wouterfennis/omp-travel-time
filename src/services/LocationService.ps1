#Requires -Version 5.1

<#
.SYNOPSIS
    Windows location services module using .NET GeoCoordinateWatcher.

.DESCRIPTION
    Provides Get-CurrentLocation which retrieves coordinates via
    System.Device.Location.GeoCoordinateWatcher (Windows Location Services).
    All former multi-provider / WinRT helper logic removed. A small cache
    avoids repeated calls within a short interval.
    NOTE: Requires Windows Location Services enabled and desktop app access.
#>

. "$PSScriptRoot\..\config\ConfigManager.ps1"
. "$PSScriptRoot\..\models\TravelTimeModels.ps1"
Add-Type -AssemblyName System.Device

# Global location service configuration
## Configuration retained only for minimal caching semantics.
$script:LocationConfig = @{
    CacheResults = $true
    CacheExpiryMinutes = 5
}

$script:LocationCache = @{}

function Get-CurrentLocation {
    <#
    .SYNOPSIS
        Gets current location using .NET GeoCoordinateWatcher.

    .DESCRIPTION
        Uses System.Device.Location.GeoCoordinateWatcher to obtain latitude and
        longitude from Windows Location Services. Provides simple caching.
        Returns a hashtable with Success, Latitude, Longitude, Method, Provider,
        Timestamp or Error. Timeouts / denied permission handled gracefully.

    .PARAMETER UseCache
        Use cached result if still fresh (default: true).

    .PARAMETER ForceRefresh
        Force a fresh lookup ignoring cache.

    .OUTPUTS
        Hashtable with keys: Success, Latitude, Longitude, Method, Provider, Timestamp, Error.

    .EXAMPLE
        $loc = Get-CurrentLocation
        if ($loc.Success) { "${loc.Latitude},${loc.Longitude}" }
    #>
    param(
        [bool]$UseCache = $true,
        [switch]$ForceRefresh
    )
    
    # Check cache first
    if ($UseCache -and -not $ForceRefresh -and $script:LocationCache.ContainsKey("current")) {
        $cached = $script:LocationCache["current"]
        $age = (Get-Date) - $cached.Timestamp
        if ($age.TotalMinutes -lt $script:LocationConfig.CacheExpiryMinutes) {
            Write-Verbose "Using cached location (age: $($age.TotalMinutes.ToString('F1')) minutes)"
            return $cached.Location
        }
    }
    
    try {
        $watcher = New-Object System.Device.Location.GeoCoordinateWatcher
        $started = $watcher.TryStart($true, [TimeSpan]::FromSeconds(10))
        if (-not $started) {
            if ($watcher.Permission -eq 'Denied') {
                try { $watcher.Dispose() } catch {}
                return @{ Success = $false; Error = 'Location permission denied'; Method = 'GeoCoordinateWatcher'; Provider = 'GeoCoordinateWatcher' }
            }
            try { $watcher.Dispose() } catch {}
            return @{ Success = $false; Error = 'Location start timeout'; Method = 'GeoCoordinateWatcher'; Provider = 'GeoCoordinateWatcher' }
        }

        $timeoutMs = 10000
        $intervalMs = 100
        $elapsed = 0
        $location = $watcher.Position.Location

        while (
            (-not (Test-LatLon -Location $location)) -and
            $elapsed -lt $timeoutMs -and
            $watcher.Permission -ne 'Denied'
        ) {
            Start-Sleep -Milliseconds $intervalMs
            $elapsed += $intervalMs
            $location = $watcher.Position.Location
        }

        if ($watcher.Permission -eq 'Denied') {
            try { $watcher.Stop() | Out-Null } catch {}
            try { $watcher.Dispose() } catch {}
            return @{ Success = $false; Error = 'Location permission denied'; Method = 'GeoCoordinateWatcher'; Provider = 'GeoCoordinateWatcher' }
        }

        if (Test-LatLon -Location $location) {
            $result = @{ Success = $true; Latitude = [math]::Round($location.Latitude,6); Longitude = [math]::Round($location.Longitude,6); Method = 'GeoCoordinateWatcher'; Provider = 'GeoCoordinateWatcher'; Timestamp = Get-Date }
            if ($UseCache) { $script:LocationCache['current'] = @{ Location = $result; Timestamp = $result.Timestamp } }
            try { $watcher.Stop() | Out-Null } catch {}
            try { $watcher.Dispose() } catch {}
            return $result
        }

        try { $watcher.Stop() | Out-Null } catch {}
        try { $watcher.Dispose() } catch {}
        return @{ Success = $false; Error = 'Empty or unavailable coordinates'; Method = 'GeoCoordinateWatcher'; Provider = 'GeoCoordinateWatcher' }
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message; Method = 'GeoCoordinateWatcher'; Provider = 'GeoCoordinateWatcher' }
    }
}

function Clear-LocationCache {
    <#
    .SYNOPSIS
        Clears the location result cache.
    #>
    $script:LocationCache.Clear()
    Write-Verbose "Location cache cleared"
}

function Test-LatLon {
    <#
    .SYNOPSIS
        Validates a latitude/longitude pair.
    .OUTPUTS
        [bool]
    #>
    param(
        [Parameter(Mandatory=$true)]$Location
    )
    if (-not $Location) { return $false }
    $lat = $Location.Latitude
    $lon = $Location.Longitude
    # Must be doubles and not NaN
    if ($lat -isnot [double] -or $lon -isnot [double]) { return $false }
    if ([double]::IsNaN($lat) -or [double]::IsNaN($lon)) { return $false }
    if ($lat -lt -90 -or $lat -gt 90) { return $false }
    if ($lon -lt -180 -or $lon -gt 180) { return $false }
    return $true
}

function Get-TravelTimeRoutes {
    <#
    .SYNOPSIS
        Gets travel time information using Google Routes API.
    
    .DESCRIPTION
        Calls the Google Routes API to calculate travel time between origin coordinates
        and a destination address, taking traffic conditions into account.
    
    .PARAMETER ApiKey
        The Google Routes API key.
    
    .PARAMETER OriginLat
        The origin latitude coordinate.
    
    .PARAMETER OriginLng
        The origin longitude coordinate.
    
    .PARAMETER Destination
        The destination address string.
    
    .PARAMETER TravelMode
        The travel mode (DRIVE, WALK, BICYCLE, TRANSIT). Default is DRIVE.
    
    .PARAMETER RoutingPreference
        The routing preference (TRAFFIC_AWARE, TRAFFIC_UNAWARE). Default is TRAFFIC_AWARE.
    
    .OUTPUTS
        Hashtable containing travel information with keys:
        - Success: Boolean indicating if the request was successful
        - TravelTimeMinutes: Travel time in minutes
        - DistanceKm: Distance in kilometers
        - TrafficStatus: Traffic status (light, moderate, heavy)
        - DurationText: Formatted duration string
        - Error: Error message if unsuccessful
    
    .EXAMPLE
        $travel = Get-TravelTimeRoutes -ApiKey $apiKey -OriginLat 40.7128 -OriginLng -74.0060 -Destination "123 Main St, City, State"
    #>
    param(
        [string]$ApiKey,
        [double]$OriginLat,
        [double]$OriginLng,
        [string]$Destination,
        [string]$TravelMode = "DRIVE",
        [string]$RoutingPreference = "TRAFFIC_AWARE"
    )
    
    try {
        $url = "https://routes.googleapis.com/directions/v2:computeRoutes"
        
        $requestBody = @{
            origin = @{
                location = @{
                    latLng = @{
                        latitude = $OriginLat
                        longitude = $OriginLng
                    }
                }
            }
            destination = @{
                address = $Destination
            }
            travelMode = $TravelMode
            routingPreference = $RoutingPreference
            computeAlternativeRoutes = $false
            routeModifiers = @{
                avoidTolls = $false
                avoidHighways = $false
                avoidFerries = $false
            }
            languageCode = "en-US"
            units = "METRIC"
        } | ConvertTo-Json -Depth 10
        
        $headers = @{
            'Content-Type' = 'application/json'
            'X-Goog-Api-Key' = $ApiKey
            'X-Goog-FieldMask' = 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline'
        }
        
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $requestBody -Headers $headers -TimeoutSec 30
        
        if ($response.routes -and $response.routes.Count -gt 0) {
            $route = $response.routes[0]
            $durationSeconds = [int]($route.duration -replace 's$', '')
            $durationMinutes = [math]::Round($durationSeconds / 60)
            $distanceKm = [math]::Round($route.distanceMeters / 1000, 1)
            
            # Calculate traffic status and format duration inline to avoid circular dependencies
            $trafficStatus = if ($durationMinutes -gt 45) { "heavy" } 
                           elseif ($durationMinutes -gt 30) { "moderate" } 
                           else { "light" }
            
            $durationText = if ($durationMinutes -lt 60) { "${durationMinutes}m" }
                          else { 
                              $hours = [math]::Floor($durationMinutes / 60)
                              $remainingMinutes = $durationMinutes % 60
                              if ($remainingMinutes -eq 0) { "${hours}h" }
                              else { "${hours}h ${remainingMinutes}m" }
                          }
            
            return @{
                Success = $true
                TravelTimeMinutes = $durationMinutes
                DistanceKm = $distanceKm
                TrafficStatus = $trafficStatus
                DurationText = $durationText
            }
        }
        else {
            return @{
                Success = $false
                Error = "No routes found"
            }
        }
    }
    catch {
        $errorMessage = if ($_.Exception.Response) {
            try {
                $errorStream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorStream)
                $errorBody = $reader.ReadToEnd()
                $errorObj = $errorBody | ConvertFrom-Json
                "API Error: $($errorObj.error.message)"
            }
            catch {
                "HTTP Error: $($_.Exception.Response.StatusCode)"
            }
        }
        else {
            $_.Exception.Message
        }
        
        return @{
            Success = $false
            Error = $errorMessage
        }
    }
}

Get-CurrentLocation