#Requires -Version 5.1

<#
.SYNOPSIS
    Location provider implementations for enhanced location detection.

.DESCRIPTION
    This module provides multiple location detection methods including
    IP-based geolocation, Windows location services, GPS coordinates,
    and address geocoding with configurable fallback strategies.
#>

# Import required modules  
. "$PSScriptRoot\..\models\TravelTimeModels.ps1"

# IP-based geolocation provider functions

function Parse-IPLocationResponse {
    param(
        $Response,
        [string]$ProviderUrl
    )
    
    try {
        if ($ProviderUrl.Contains("ip-api.com")) {
            if ($Response.status -eq "success") {
                return New-LocationResult -Latitude $Response.lat -Longitude $Response.lon -City $Response.city -Region $Response.regionName -Country $Response.country -Success $true -Method "IP" -Provider $ProviderUrl
            }
        }
        elseif ($ProviderUrl.Contains("ipapi.co")) {
            if ($Response.ip) {
                return New-LocationResult -Latitude $Response.latitude -Longitude $Response.longitude -City $Response.city -Region $Response.region -Country $Response.country_name -Success $true -Method "IP" -Provider $ProviderUrl
            }
        }
        elseif ($ProviderUrl.Contains("ipinfo.io")) {
            if ($Response.loc) {
                $coords = $Response.loc -split ','
                $lat = [double]$coords[0]
                $lng = [double]$coords[1]
                return New-LocationResult -Latitude $lat -Longitude $lng -City $Response.city -Region $Response.region -Country $Response.country -Success $true -Method "IP" -Provider $ProviderUrl
            }
        }
        elseif ($ProviderUrl.Contains("freegeoip.app")) {
            if ($Response.latitude -and $Response.longitude) {
                return New-LocationResult -Latitude $Response.latitude -Longitude $Response.longitude -City $Response.city -Region $Response.region_name -Country $Response.country_name -Success $true -Method "IP" -Provider $ProviderUrl
            }
        }
        elseif ($ProviderUrl.Contains("db-ip.com")) {
            if ($Response.latitude -and $Response.longitude) {
                return New-LocationResult -Latitude $Response.latitude -Longitude $Response.longitude -City $Response.city -Region $Response.stateProv -Country $Response.countryName -Success $true -Method "IP" -Provider $ProviderUrl
            }
        }
        
        return New-LocationResult -Success $false -Error "Unknown provider response format"
    }
    catch {
        return New-LocationResult -Success $false -Error "Failed to parse response: $($_.Exception.Message)"
    }
}

function Test-IPProviderReliability {
    <#
    .SYNOPSIS
        Tests and scores IP geolocation providers for reliability and accuracy.
    
    .DESCRIPTION
        Evaluates multiple IP geolocation providers by testing response time,
        success rate, and consistency of results to provide reliability scores.
    
    .OUTPUTS
        Array of provider assessment results with reliability scores.
    #>
    param(
        [string[]]$Providers = @(
            "https://ip-api.com/json/",
            "https://ipapi.co/json/",
            "https://ipinfo.io/json",
            "https://freegeoip.app/json/",
            "https://api.db-ip.com/v2/free/self"
        ),
        [int]$TestIterations = 3
    )
    
    $results = @()
    
    foreach ($provider in $Providers) {
        $assessment = @{
            Provider = $provider
            ResponseTimes = @()
            SuccessCount = 0
            TotalAttempts = 0
            Locations = @()
            ReliabilityScore = 0
            AverageResponseTime = 0
            SuccessRate = 0
        }
        
        for ($i = 1; $i -le $TestIterations; $i++) {
            try {
                $start = Get-Date
                $response = Invoke-RestMethod -Uri $provider -TimeoutSec 10
                $elapsed = ((Get-Date) - $start).TotalMilliseconds
                
                $parsed = Parse-IPLocationResponse -Response $response -ProviderUrl $provider
                
                $assessment.TotalAttempts++
                $assessment.ResponseTimes += $elapsed
                
                if ($parsed.Success) {
                    $assessment.SuccessCount++
                    $assessment.Locations += $parsed
                }
            }
            catch {
                $assessment.TotalAttempts++
                Write-Verbose "Provider $provider test $i failed: $($_.Exception.Message)"
            }
        }
        
        # Calculate metrics
        if ($assessment.ResponseTimes.Count -gt 0) {
            $assessment.AverageResponseTime = ($assessment.ResponseTimes | Measure-Object -Average).Average
        }
        
        if ($assessment.TotalAttempts -gt 0) {
            $assessment.SuccessRate = $assessment.SuccessCount / $assessment.TotalAttempts
        }
        
        # Calculate reliability score (0-100)
        $timeScore = if ($assessment.AverageResponseTime -gt 0) {
            [math]::Max(0, 100 - ($assessment.AverageResponseTime / 50)) # 50ms = 99 points, 5000ms = 0 points
        } else { 0 }
        
        $successScore = $assessment.SuccessRate * 100
        
        # Check location consistency (if multiple successful calls)
        $consistencyScore = 100
        if ($assessment.Locations.Count -gt 1) {
            $firstLoc = $assessment.Locations[0]
            $maxDistance = 0
            
            foreach ($loc in $assessment.Locations[1..($assessment.Locations.Count-1)]) {
                $distance = Get-LocationDistance -Lat1 $firstLoc.Latitude -Lng1 $firstLoc.Longitude -Lat2 $loc.Latitude -Lng2 $loc.Longitude
                if ($distance -gt $maxDistance) {
                    $maxDistance = $distance
                }
            }
            
            # Penalize inconsistent results (>10km difference = lower score)
            if ($maxDistance -gt 10) {
                $consistencyScore = [math]::Max(0, 100 - ($maxDistance - 10))
            }
        }
        
        # Overall reliability score (weighted average)
        $assessment.ReliabilityScore = [math]::Round(($successScore * 0.5) + ($timeScore * 0.3) + ($consistencyScore * 0.2), 1)
        
        $results += $assessment
    }
    
    return $results | Sort-Object ReliabilityScore -Descending
}

function Get-LocationDistance {
    <#
    .SYNOPSIS
        Calculates distance between two GPS coordinates using Haversine formula.
    #>
    param(
        [double]$Lat1,
        [double]$Lng1,
        [double]$Lat2,
        [double]$Lng2
    )
    
    $R = 6371 # Earth's radius in kilometers
    $dLat = [math]::PI * ($Lat2 - $Lat1) / 180
    $dLng = [math]::PI * ($Lng2 - $Lng1) / 180
    
    $a = [math]::Sin($dLat/2) * [math]::Sin($dLat/2) + 
         [math]::Cos([math]::PI * $Lat1 / 180) * [math]::Cos([math]::PI * $Lat2 / 180) *
         [math]::Sin($dLng/2) * [math]::Sin($dLng/2)
    
    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1-$a))
    
    return $R * $c
}

function Test-VPNDetection {
    <#
    .SYNOPSIS
        Attempts to detect if the current connection is using a VPN.
    
    .DESCRIPTION
        Uses various techniques to detect VPN usage which can affect 
        IP geolocation accuracy.
    #>
    
    $indicators = @{
        VPNDetected = $false
        Confidence = 0
        Reasons = @()
    }
    
    try {
        # Test 1: Check for common VPN IP ranges and providers
        $ipInfo = Invoke-RestMethod -Uri "https://ipapi.co/json/" -TimeoutSec 10 -ErrorAction SilentlyContinue
        
        if ($ipInfo) {
            # Check for VPN-related organization names
            $vpnKeywords = @("VPN", "Virtual Private", "Proxy", "Hosting", "Data Center", "Cloud", "Amazon", "Google Cloud", "Microsoft Azure")
            foreach ($keyword in $vpnKeywords) {
                if ($ipInfo.org -and $ipInfo.org -like "*$keyword*") {
                    $indicators.VPNDetected = $true
                    $indicators.Confidence += 20
                    $indicators.Reasons += "Organization contains VPN-related keyword: $keyword"
                }
            }
            
            # Check for unusual ISP names
            if ($ipInfo.org -and ($ipInfo.org -like "*Hosting*" -or $ipInfo.org -like "*Server*" -or $ipInfo.org -like "*Datacenter*")) {
                $indicators.VPNDetected = $true
                $indicators.Confidence += 15
                $indicators.Reasons += "ISP appears to be hosting provider"
            }
        }
        
        # Test 2: Compare results from multiple IP services for consistency
        $locations = @()
        $providers = @("https://ip-api.com/json/", "https://ipapi.co/json/")
        
        foreach ($provider in $providers) {
            try {
                $response = Invoke-RestMethod -Uri $provider -TimeoutSec 5
                $parsed = Parse-IPLocationResponse -Response $response -ProviderUrl $provider
                if ($parsed.Success) {
                    $locations += $parsed
                }
            }
            catch {
                # Ignore failures for VPN detection
            }
        }
        
        if ($locations.Count -gt 1) {
            $maxDistance = 0
            for ($i = 0; $i -lt $locations.Count - 1; $i++) {
                for ($j = $i + 1; $j -lt $locations.Count; $j++) {
                    $distance = Get-LocationDistance -Lat1 $locations[$i].Latitude -Lng1 $locations[$i].Longitude -Lat2 $locations[$j].Latitude -Lng2 $locations[$j].Longitude
                    if ($distance -gt $maxDistance) {
                        $maxDistance = $distance
                    }
                }
            }
            
            # Large discrepancies might indicate VPN
            if ($maxDistance -gt 100) {
                $indicators.VPNDetected = $true
                $indicators.Confidence += 25
                $indicators.Reasons += "Location providers show inconsistent results (${maxDistance}km apart)"
            }
        }
        
        # Cap confidence at 100
        $indicators.Confidence = [math]::Min(100, $indicators.Confidence)
        
    }
    catch {
        Write-Verbose "VPN detection failed: $($_.Exception.Message)"
    }
    
    return $indicators
}

function Invoke-IPLocationProvider {
    param(
        [hashtable]$Config = @{}
    )
    
    $providers = @(
        "https://ip-api.com/json/",
        "https://ipapi.co/json/",
        "https://ipinfo.io/json",
        "https://freegeoip.app/json/",
        "https://api.db-ip.com/v2/free/self"
    )
    
    if ($Config.providers) {
        $providers = $Config.providers
    }
    
    $timeout = if ($Config.timeout_seconds) { $Config.timeout_seconds } else { 10 }
    
    foreach ($providerUrl in $providers) {
        try {
            Write-Verbose "Trying IP geolocation provider: $providerUrl"
            
            $response = Invoke-RestMethod -Uri $providerUrl -TimeoutSec $timeout
            
            $parsed = Parse-IPLocationResponse -Response $response -ProviderUrl $providerUrl
            if ($parsed.Success) {
                return $parsed
            }
        }
        catch {
            Write-Verbose "Provider $providerUrl failed: $($_.Exception.Message)"
            continue
        }
    }
    
    return New-LocationResult -Success $false -Error "All IP geolocation providers failed"
}

function Test-IPLocationProvider {
    param([hashtable]$Config = @{})
    
    # IP provider is available if we have internet connectivity
    try {
        $null = Invoke-RestMethod -Uri "https://ip-api.com/json/" -TimeoutSec 5 -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Windows Location Services provider functions
function Invoke-WindowsLocationProvider {
    param(
        [hashtable]$Config = @{}
    )
    
    if (-not (Test-WindowsLocationProvider -Config $Config)) {
        return New-LocationResult -Success $false -Error "Windows Location Services not available or disabled"
    }
    
    try {
        # Check if .NET Framework location services are available
        Add-Type -AssemblyName System.Device -ErrorAction Stop
        
        $watcher = New-Object System.Device.Location.GeoCoordinateWatcher
        $watcher.Start()
        
        $timeout = if ($Config.timeout_seconds) { $Config.timeout_seconds } else { 30 }
        $start = Get-Date
        
        while ($watcher.Status -eq "Initializing" -and ((Get-Date) - $start).TotalSeconds -lt $timeout) {
            Start-Sleep -Milliseconds 500
        }
        
        if ($watcher.Status -eq "Ready" -and -not $watcher.Position.Location.IsUnknown) {
            $location = $watcher.Position.Location
            $watcher.Stop()
            
            return New-LocationResult -Latitude $location.Latitude -Longitude $location.Longitude -Accuracy $location.HorizontalAccuracy -Success $true -Method "Windows" -Provider "System.Device.Location"
        }
        else {
            $watcher.Stop()
            return New-LocationResult -Success $false -Error "Windows location services could not determine location (Status: $($watcher.Status))"
        }
    }
    catch {
        return New-LocationResult -Success $false -Error "Windows location services error: $($_.Exception.Message)"
    }
}

function Test-WindowsLocationProvider {
    param([hashtable]$Config = @{})
    
    try {
        # Check if location service is running
        $locationService = Get-Service -Name "lfsvc" -ErrorAction SilentlyContinue
        return ($null -ne $locationService -and $locationService.Status -eq "Running")
    }
    catch {
        return $false
    }
}

# GPS coordinates provider functions
function Invoke-GPSLocationProvider {
    param(
        [hashtable]$Config = @{}
    )
    
    if (-not $Config.ContainsKey("Latitude") -or -not $Config.ContainsKey("Longitude")) {
        return New-LocationResult -Success $false -Error "GPS coordinates not configured"
    }
    
    $lat = [double]$Config.Latitude
    $lng = [double]$Config.Longitude
    
    # Validate coordinate ranges
    if ($lat -lt -90 -or $lat -gt 90) {
        return New-LocationResult -Success $false -Error "Invalid latitude: must be between -90 and 90"
    }
    
    if ($lng -lt -180 -or $lng -gt 180) {
        return New-LocationResult -Success $false -Error "Invalid longitude: must be between -180 and 180"
    }
    
    return New-LocationResult -Latitude $lat -Longitude $lng -Success $true -Method "GPS" -Provider "Direct"
}

function Test-GPSLocationProvider {
    param([hashtable]$Config = @{})
    
    return ($Config.ContainsKey("Latitude") -and $Config.ContainsKey("Longitude"))
}

# Address geocoding provider functions
function Invoke-AddressLocationProvider {
    param(
        [hashtable]$Config = @{}
    )
    
    if (-not $Config.ContainsKey("Address") -or [string]::IsNullOrWhiteSpace($Config.Address)) {
        return New-LocationResult -Success $false -Error "Address not configured"
    }
    
    if (-not $Config.ContainsKey("ApiKey") -or [string]::IsNullOrWhiteSpace($Config.ApiKey)) {
        return New-LocationResult -Success $false -Error "API key required for address geocoding"
    }
    
    try {
        $encodedAddress = [System.Web.HttpUtility]::UrlEncode($Config.Address)
        $url = "https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$($Config.ApiKey)"
        
        $response = Invoke-RestMethod -Uri $url -TimeoutSec 15
        
        if ($response.status -eq "OK" -and $response.results.Count -gt 0) {
            $result = $response.results[0]
            $location = $result.geometry.location
            
            # Extract city, region, country from address components
            $city = ($result.address_components | Where-Object { $_.types -contains "locality" }).long_name
            $region = ($result.address_components | Where-Object { $_.types -contains "administrative_area_level_1" }).long_name
            $country = ($result.address_components | Where-Object { $_.types -contains "country" }).long_name
            
            return New-LocationResult -Latitude $location.lat -Longitude $location.lng -City $city -Region $region -Country $country -Success $true -Method "Address" -Provider "Google"
        }
        else {
            return New-LocationResult -Success $false -Error "Geocoding failed: $($response.status)"
        }
    }
    catch {
        return New-LocationResult -Success $false -Error "Geocoding failed: $($_.Exception.Message)"
    }
}

function Test-AddressLocationProvider {
    param([hashtable]$Config = @{})
    
    return ($Config.ContainsKey("Address") -and -not [string]::IsNullOrWhiteSpace($Config.Address))
}

# Hybrid provider function
function Invoke-HybridLocationProvider {
    param(
        [hashtable]$Config = @{}
    )
    
    $providerOrder = @("Windows", "GPS", "IP", "Address")
    if ($Config.preferred_order) {
        $providerOrder = $Config.preferred_order
    }
    
    $weights = @{
        "Windows" = 1.0
        "GPS" = 0.9
        "IP" = 0.6
        "Address" = 0.8
    }
    
    $results = @()
    
    foreach ($providerName in $providerOrder) {
        $providerConfig = @{}
        if ($Config.providers -and $Config.providers.$providerName) {
            $providerConfig = $Config.providers.$providerName
        }
        
        # Add global API key if needed
        if ($Config.ApiKey -and -not $providerConfig.ApiKey) {
            $providerConfig.ApiKey = $Config.ApiKey
        }
        
        try {
            $isAvailable = $false
            $result = $null
            
            switch ($providerName) {
                "Windows" {
                    $isAvailable = Test-WindowsLocationProvider -Config $providerConfig
                    if ($isAvailable) {
                        $result = Invoke-WindowsLocationProvider -Config $providerConfig
                    }
                }
                "GPS" {
                    $isAvailable = Test-GPSLocationProvider -Config $providerConfig
                    if ($isAvailable) {
                        $result = Invoke-GPSLocationProvider -Config $providerConfig
                    }
                }
                "IP" {
                    $isAvailable = Test-IPLocationProvider -Config $providerConfig
                    if ($isAvailable) {
                        $result = Invoke-IPLocationProvider -Config $providerConfig
                    }
                }
                "Address" {
                    $isAvailable = Test-AddressLocationProvider -Config $providerConfig
                    if ($isAvailable) {
                        $result = Invoke-AddressLocationProvider -Config $providerConfig
                    }
                }
            }
            
            if ($isAvailable -and $result -and $result.Success) {
                $result.Weight = $weights[$providerName]
                $result.ProviderName = $providerName
                $results += $result
            }
        }
        catch {
            Write-Verbose "Provider $providerName failed: $($_.Exception.Message)"
        }
    }
    
    if ($results.Count -eq 0) {
        return New-LocationResult -Success $false -Error "All location providers failed"
    }
    
    # Return the result with highest weight
    $bestResult = $results | Sort-Object Weight -Descending | Select-Object -First 1
    $bestResult.Method = "Hybrid"
    $bestResult.ProvidersUsed = ($results | ForEach-Object { $_.ProviderName }) -join ", "
    
    return $bestResult
}

# Factory function to create and invoke location providers
function New-LocationProvider {
    <#
    .SYNOPSIS
        Creates and invokes a location provider.
    
    .PARAMETER Type
        The type of location provider to create.
    
    .PARAMETER Config
        Configuration hashtable for the provider.
    #>
    param(
        [ValidateSet("IP", "Windows", "GPS", "Address", "Hybrid")]
        [string]$Type,
        [hashtable]$Config = @{}
    )
    
    $provider = @{
        Name = $Type
        Config = $Config
        RequiresConsent = $false
    }
    
    # Set provider-specific properties
    switch ($Type) {
        "Windows" {
            $provider.RequiresConsent = $true
            $provider.Description = "Uses native Windows location services for high accuracy positioning"
        }
        "IP" {
            $provider.Description = "Determines location using IP geolocation services with multiple provider fallback"
        }
        "GPS" {
            $provider.Description = "Uses directly provided GPS coordinates"
        }
        "Address" {
            $provider.Description = "Converts an address to GPS coordinates using geocoding services"
        }
        "Hybrid" {
            $provider.RequiresConsent = $true
            $provider.Description = "Combines multiple location detection methods for best accuracy"
        }
    }
    
    # Add methods to provider object
    $provider | Add-Member -MemberType ScriptMethod -Name "GetLocation" -Value {
        switch ($this.Name) {
            "IP" { return Invoke-IPLocationProvider -Config $this.Config }
            "Windows" { return Invoke-WindowsLocationProvider -Config $this.Config }
            "GPS" { return Invoke-GPSLocationProvider -Config $this.Config }
            "Address" { return Invoke-AddressLocationProvider -Config $this.Config }
            "Hybrid" { return Invoke-HybridLocationProvider -Config $this.Config }
        }
    }
    
    $provider | Add-Member -MemberType ScriptMethod -Name "IsAvailable" -Value {
        switch ($this.Name) {
            "IP" { return Test-IPLocationProvider -Config $this.Config }
            "Windows" { return Test-WindowsLocationProvider -Config $this.Config }
            "GPS" { return Test-GPSLocationProvider -Config $this.Config }
            "Address" { return Test-AddressLocationProvider -Config $this.Config }
            "Hybrid" { return $true } # Hybrid is always "available" - will use whatever works
        }
    }
    
    $provider | Add-Member -MemberType ScriptMethod -Name "ValidateConfig" -Value {
        $result = @{
            IsValid = $true
            Errors = @()
            Warnings = @()
        }
        
        switch ($this.Name) {
            "GPS" {
                if (-not $this.Config.ContainsKey("Latitude") -or -not $this.Config.ContainsKey("Longitude")) {
                    $result.Errors += "GPS provider requires Latitude and Longitude configuration"
                    $result.IsValid = $false
                }
            }
            "Address" {
                if (-not $this.Config.ContainsKey("Address") -or [string]::IsNullOrWhiteSpace($this.Config.Address)) {
                    $result.Errors += "Address provider requires Address configuration"
                    $result.IsValid = $false
                }
                if (-not $this.Config.ContainsKey("ApiKey")) {
                    $result.Warnings += "No API key provided for address geocoding"
                }
            }
            "Windows" {
                if (-not (Test-WindowsLocationProvider -Config $this.Config)) {
                    $result.Warnings += "Windows Location Services not available or disabled"
                }
            }
        }
        
        return $result
    }
    
    # Add provider to hybrid if it's a hybrid provider
    if ($Type -eq "Hybrid") {
        $provider | Add-Member -MemberType ScriptMethod -Name "AddProvider" -Value {
            param($subProvider)
            # For simplicity, we'll manage sub-providers through configuration
            if (-not $this.Config.providers) {
                $this.Config.providers = @{}
            }
            $this.Config.providers[$subProvider.Name] = $subProvider.Config
        }
    }
    
    # Validate configuration
    $validation = $provider.ValidateConfig()
    
    if (-not $validation.IsValid) {
        throw "Provider validation failed: $($validation.Errors -join ', ')"
    }
    
    if ($validation.Warnings.Count -gt 0) {
        foreach ($warning in $validation.Warnings) {
            Write-Warning "Provider ${Type}: $warning"
        }
    }
    
    return $provider
}

# Functions are available when script is dot-sourced