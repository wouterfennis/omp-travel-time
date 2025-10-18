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
function Invoke-IPLocationProvider {
    param(
        [hashtable]$Config = @{}
    )
    
    $providers = @(
        "https://ip-api.com/json/",
        "https://ipapi.co/json/"
    )
    
    if ($Config.providers) {
        $providers = $Config.providers
    }
    
    $timeout = if ($Config.timeout_seconds) { $Config.timeout_seconds } else { 10 }
    
    foreach ($providerUrl in $providers) {
        try {
            Write-Verbose "Trying IP geolocation provider: $providerUrl"
            
            $response = Invoke-RestMethod -Uri $providerUrl -TimeoutSec $timeout
            
            if ($providerUrl.Contains("ip-api.com")) {
                if ($response.status -eq "success") {
                    return New-LocationResult -Latitude $response.lat -Longitude $response.lon -City $response.city -Region $response.regionName -Country $response.country -Success $true -Method "IP" -Provider $providerUrl
                }
            }
            elseif ($providerUrl.Contains("ipapi.co")) {
                if ($response.ip) {
                    return New-LocationResult -Latitude $response.latitude -Longitude $response.longitude -City $response.city -Region $response.region -Country $response.country_name -Success $true -Method "IP" -Provider $providerUrl
                }
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