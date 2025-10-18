#Requires -Version 5.1

<#
.SYNOPSIS
    Updates travel time data using Google Routes API for Oh My Posh prompt integration.

.DESCRIPTION
    This script fetches current travel time to home using Google Routes API and stores
    the result in a JSON file that can be read by Oh My Posh prompt configuration.
    
    The script only fetches data during configured active hours to optimize API usage.

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

function Get-TravelTimeConfig {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Error "Config file not found: $Path. Run Install-TravelTimeService.ps1 first."
        return $null
    }
    
    try {
        return Get-Content $Path | ConvertFrom-Json
    }
    catch {
        Write-Error "Invalid JSON in config file: $_"
        return $null
    }
}

function Test-ActiveHours {
    param(
        [string]$StartTime,
        [string]$EndTime
    )
    
    $current = Get-Date
    $start = [DateTime]::Parse($StartTime)
    $end = [DateTime]::Parse($EndTime)
    
    $currentTime = [DateTime]::Parse($current.ToString("HH:mm"))
    
    return ($currentTime -ge $start -and $currentTime -le $end)
}

function Get-CurrentLocation {
    <#
    .SYNOPSIS
        Gets current location using IP geolocation service.
    
    .DESCRIPTION
        Uses a free IP geolocation service to determine current location.
        Falls back to a default location if the service is unavailable.
    #>
    try {
        # Using ip-api.com free service (1000 requests/month)
        $response = Invoke-RestMethod -Uri "http://ip-api.com/json/" -TimeoutSec 10
        if ($response.status -eq "success") {
            return @{
                Latitude = $response.lat
                Longitude = $response.lon
                Success = $true
                City = $response.city
                Region = $response.regionName
            }
        }
        else {
            throw "Geolocation service returned: $($response.status)"
        }
    }
    catch {
        # Fallback to a default location if geolocation fails
        Write-Warning "Could not get current location: $_. Using fallback location."
        return @{
            Latitude = 40.7128
            Longitude = -74.0060
            Success = $true
            City = "Unknown"
            Region = "Unknown"
        }
    }
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
            
            # Estimate traffic conditions based on duration
            # This is a simplified approach since Routes API doesn't directly provide traffic status
            $trafficStatus = if ($durationMinutes -gt 45) { "heavy" } 
                           elseif ($durationMinutes -gt 30) { "moderate" } 
                           else { "light" }
            
            return @{
                Success = $true
                TravelTimeMinutes = $durationMinutes
                DistanceKm = $distanceKm
                TrafficStatus = $trafficStatus
                DurationText = "{0}h {1}m" -f [math]::Floor($durationMinutes / 60), ($durationMinutes % 60)
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

function Update-TravelTimeData {
    param(
        [string]$ConfigPath,
        [string]$DataPath
    )
    
    $config = Get-TravelTimeConfig -Path $ConfigPath
    if (-not $config) { 
        return 
    }
    
    $isActiveHours = Test-ActiveHours -StartTime $config.start_time -EndTime $config.end_time
    
    # Ensure data directory exists
    $dataDir = Split-Path $DataPath -Parent
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
    
    $result = @{
        last_updated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        travel_time_minutes = $null
        distance_km = $null
        traffic_status = $null
        travel_mode = $config.travel_mode
        error = $null
        is_active_hours = $isActiveHours
        active_period = "$($config.start_time) - $($config.end_time)"
    }
    
    if ($isActiveHours) {
        Write-Host "Active hours detected, fetching travel time..." -ForegroundColor Yellow
        
        $location = Get-CurrentLocation
        
        if ($location.Success) {
            Write-Host "Current location: $($location.City), $($location.Region) ($($location.Latitude), $($location.Longitude))" -ForegroundColor Cyan
            
            $travelData = Get-TravelTimeRoutes -ApiKey $config.google_routes_api_key -OriginLat $location.Latitude -OriginLng $location.Longitude -Destination $config.home_address -TravelMode $config.travel_mode -RoutingPreference $config.routing_preference
            
            if ($travelData.Success) {
                $result.travel_time_minutes = $travelData.TravelTimeMinutes
                $result.distance_km = $travelData.DistanceKm
                $result.traffic_status = $travelData.TrafficStatus
                Write-Host "Travel time updated: $($travelData.TravelTimeMinutes) minutes ($($travelData.DistanceKm) km, $($travelData.TrafficStatus) traffic)" -ForegroundColor Green
            }
            else {
                $result.error = $travelData.Error
                Write-Warning "Travel time fetch failed: $($travelData.Error)"
            }
        }
        else {
            $result.error = "Could not get location: $($location.Error)"
            Write-Warning $result.error
        }
    }
    else {
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

# Main execution
try {
    $VerbosePreference = "Continue"
    Update-TravelTimeData -ConfigPath $ConfigPath -DataPath $DataPath
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
}