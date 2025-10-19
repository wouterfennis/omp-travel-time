#Requires -Version 5.1

<#
.SYNOPSIS
    Google Routes API integration service for travel time calculations.

.DESCRIPTION
    This module provides travel time calculation services using Google Routes API
    with traffic-aware routing and multiple travel mode support.
#>

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
                ErrorMessage = "No routes found"
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
            ErrorMessage = $errorMessage
        }
    }
}