#Requires -Version 5.1

<#
.SYNOPSIS
    Enhanced location services module for the Travel Time system.

.DESCRIPTION
    This module provides advanced location detection capabilities with multiple
    providers, fallback strategies, and configurable preferences for optimal
    accuracy and reliability.
#>

# Import location providers
. "$PSScriptRoot\..\providers\LocationProviders.ps1"
. "$PSScriptRoot\..\config\ConfigManager.ps1"
. "$PSScriptRoot\..\models\TravelTimeModels.ps1"

# Global location service configuration
$script:LocationConfig = @{
    PreferredProviders = @("Windows", "GPS", "IP", "Address")
    EnableHybrid = $true
    CacheResults = $true
    CacheExpiryMinutes = 10
}

$script:LocationCache = @{}

function Get-CurrentLocation {
    <#
    .SYNOPSIS
        Gets current location using enhanced multi-provider location detection.
    
    .DESCRIPTION
        Uses configurable location providers with fallback strategy to determine 
        current location. Supports IP geolocation, Windows location services,
        GPS coordinates, address geocoding, and hybrid methods.
    
    .PARAMETER ProviderType
        Specific provider to use. If not specified, uses configured preference order.
        
    .PARAMETER UseCache
        Whether to use cached location results. Default is true.
        
    .PARAMETER ForceRefresh
        Forces a fresh location lookup, ignoring cache.
    
    .OUTPUTS
        Hashtable containing location information with keys:
        - Latitude: The latitude coordinate
        - Longitude: The longitude coordinate  
        - Success: Boolean indicating if the request was successful
        - City: The city name
        - Region: The region/state name
        - Country: The country name
        - Method: The method used to obtain location
        - Provider: The specific provider that succeeded
        - Accuracy: Location accuracy in meters (if available)
        - Timestamp: When the location was obtained
    
    .EXAMPLE
        $location = Get-CurrentLocation
        if ($location.Success) {
            Write-Host "Current location: $($location.City), $($location.Region) (via $($location.Method))"
        }
        
    .EXAMPLE
        $location = Get-CurrentLocation -ProviderType "Windows" -ForceRefresh
    #>
    param(
        [ValidateSet("IP", "Windows", "GPS", "Address", "Hybrid", "Auto")]
        [string]$ProviderType = "Auto",
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
        # Get travel configuration for provider settings
        $travelConfig = Get-TravelTimeConfig -ErrorAction SilentlyContinue
        
        # Update provider preferences from config
        if ($travelConfig -and $travelConfig.location_providers) {
            $script:LocationConfig.PreferredProviders = $travelConfig.location_providers.preferred_order
            $script:LocationConfig.EnableHybrid = $travelConfig.location_providers.enable_hybrid
        }
        
        # Determine which providers to try
        $providersToTry = if ($ProviderType -eq "Auto") {
            if ($script:LocationConfig.EnableHybrid) { @("Hybrid") }
            else { $script:LocationConfig.PreferredProviders }
        } else {
            @($ProviderType)
        }
        
        # Try each provider in order
        foreach ($providerName in $providersToTry) {
            try {
                Write-Verbose "Attempting location detection with provider: $providerName"
                
                $provider = Get-ConfiguredLocationProvider -ProviderType $providerName -Config $travelConfig
                if ($provider -and $provider.IsAvailable()) {
                    $result = $provider.GetLocation()
                    
                    if ($result.Success) {
                        # Add timestamp and cache result
                        $result.Timestamp = Get-Date
                        
                        if ($UseCache) {
                            $script:LocationCache["current"] = @{
                                Location = $result
                                Timestamp = $result.Timestamp
                            }
                        }
                        
                        Write-Verbose "Location obtained successfully via $providerName"
                        return $result
                    }
                    else {
                        Write-Verbose "Provider $providerName failed: $($result.Error)"
                    }
                }
                else {
                    Write-Verbose "Provider $providerName not available"
                }
            }
            catch {
                Write-Verbose "Provider $providerName threw exception: $($_.Exception.Message)"
                continue
            }
        }
        
        # All providers failed - return legacy IP lookup as final fallback
        Write-Warning "All enhanced providers failed, falling back to legacy IP lookup"
        return Get-LegacyIPLocation
    }
    catch {
        Write-Warning "Location detection failed: $($_.Exception.Message)"
        return New-LocationResult -Success $false -Error $_.Exception.Message
    }
}

function Get-ConfiguredLocationProvider {
    <#
    .SYNOPSIS
        Creates a configured location provider instance.
    
    .PARAMETER ProviderType
        The type of provider to create.
        
    .PARAMETER Config
        Travel configuration containing provider settings.
    #>
    param(
        [string]$ProviderType,
        $Config
    )
    
    try {
        $providerConfig = @{}
        
        # Extract provider-specific configuration
        if ($Config -and $Config.location_providers -and $Config.location_providers.providers) {
            $providerSettings = $Config.location_providers.providers.$ProviderType
            if ($providerSettings) {
                $providerConfig = $providerSettings
            }
        }
        
        # Add global settings that providers might need
        if ($Config -and $Config.google_maps_api_key) {
            $providerConfig.ApiKey = $Config.google_maps_api_key
        }
        
        # Create provider based on type
        switch ($ProviderType) {
            "Hybrid" {
                $provider = New-LocationProvider -Type "Hybrid" -Config $providerConfig
                
                # Add all available sub-providers to hybrid
                foreach ($subProviderType in @("Windows", "GPS", "IP", "Address")) {
                    try {
                        $subProvider = New-LocationProvider -Type $subProviderType -Config $providerConfig
                        $provider.AddProvider($subProvider)
                    }
                    catch {
                        Write-Verbose "Could not add $subProviderType to hybrid provider: $($_.Exception.Message)"
                    }
                }
                
                return $provider
            }
            default {
                return New-LocationProvider -Type $ProviderType -Config $providerConfig
            }
        }
    }
    catch {
        Write-Verbose "Failed to create provider $ProviderType`: $($_.Exception.Message)"
        return $null
    }
}

function Get-LegacyIPLocation {
    <#
    .SYNOPSIS
        Legacy IP-based location lookup (original implementation as fallback).
    #>
    try {
        # Using ip-api.com free service (1000 requests/month)
        $response = Invoke-RestMethod -Uri "https://ip-api.com/json/" -TimeoutSec 10
        if ($response.status -eq "success") {
            return New-LocationResult -Latitude $response.lat -Longitude $response.lon -City $response.city -Region $response.regionName -Country $response.country -Success $true -Method "IP-Legacy"
        }
        else {
            throw "Geolocation service returned: $($response.status)"
        }
    }
    catch {
        # Return location unavailable status instead of fallback location
        Write-Warning "Could not get current location: $_"
        return New-LocationResult -Success $false -Error $_.Exception.Message
    }
}

function Set-LocationProviderPreferences {
    <#
    .SYNOPSIS
        Configures location provider preferences.
    
    .PARAMETER PreferredProviders
        Array of provider names in preference order.
        
    .PARAMETER EnableHybrid
        Whether to enable hybrid provider mode.
        
    .PARAMETER CacheExpiryMinutes
        How long to cache location results in minutes.
    #>
    param(
        [string[]]$PreferredProviders,
        [bool]$EnableHybrid,
        [int]$CacheExpiryMinutes
    )
    
    if ($PreferredProviders) {
        $script:LocationConfig.PreferredProviders = $PreferredProviders
    }
    
    if ($PSBoundParameters.ContainsKey('EnableHybrid')) {
        $script:LocationConfig.EnableHybrid = $EnableHybrid
    }
    
    if ($CacheExpiryMinutes -gt 0) {
        $script:LocationConfig.CacheExpiryMinutes = $CacheExpiryMinutes
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

function Test-LocationProviders {
    <#
    .SYNOPSIS
        Tests all available location providers and returns their status.
    
    .OUTPUTS
        Array of hashtables with provider test results.
    #>
    $results = @()
    
    foreach ($providerType in @("IP", "Windows", "GPS", "Address")) {
        $result = @{
            Provider = $providerType
            Available = $false
            Success = $false
            Error = $null
            ResponseTime = $null
        }
        
        try {
            $start = Get-Date
            $provider = New-LocationProvider -Type $providerType -Config @{}
            
            $result.Available = $provider.IsAvailable()
            
            if ($result.Available) {
                $location = $provider.GetLocation()
                $result.Success = $location.Success
                $result.Error = $location.Error
                $result.ResponseTime = ((Get-Date) - $start).TotalMilliseconds
            }
        }
        catch {
            $result.Error = $_.Exception.Message
        }
        
        $results += $result
    }
    
    return $results
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