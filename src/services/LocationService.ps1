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
    
    $watcher = $null
    function _Cleanup { param($w)
        if ($null -ne $w) {
            try { $w.Stop() | Out-Null } catch {}
            try { $w.Dispose() } catch {}
        }
    }
    try {
        $watcher = New-Object System.Device.Location.GeoCoordinateWatcher
        # TryStart arguments: suppressPermissionPrompt=$true (do not pop UI), timeout=10s
        $started = $watcher.TryStart($true, [TimeSpan]::FromSeconds(10))
        if (-not $started) {
            if ($watcher.Permission -eq 'Denied') {
                return @{ Success = $false; Error = 'Location permission denied'; Method = 'GeoCoordinateWatcher'; Provider = 'GeoCoordinateWatcher' }
            }
            return @{ Success = $false; Error = 'Location start timeout'; Method = 'GeoCoordinateWatcher'; Provider = 'GeoCoordinateWatcher' }
        }

        # Poll for a valid coordinate. If Windows supplies stale/empty initial values, wait briefly.
        # Timeout & interval kept modest to avoid blocking scheduled task runs.
        $timeoutMs = 10000   # total max wait after successful start
        $intervalMs = 100    # poll interval
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
            return @{ Success = $false; Error = 'Location permission denied'; Method = 'GeoCoordinateWatcher'; Provider = 'GeoCoordinateWatcher' }
        }

        if (Test-LatLon -Location $location) {
            $result = @{ Success = $true; Latitude = [math]::Round($location.Latitude,6); Longitude = [math]::Round($location.Longitude,6); Method = 'GeoCoordinateWatcher'; Provider = 'GeoCoordinateWatcher'; Timestamp = Get-Date }
            if ($UseCache) { $script:LocationCache['current'] = @{ Location = $result; Timestamp = $result.Timestamp } }
            return $result
        }

        return @{ Success = $false; Error = 'Empty or unavailable coordinates'; Method = 'GeoCoordinateWatcher'; Provider = 'GeoCoordinateWatcher' }
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message; Method = 'GeoCoordinateWatcher'; Provider = 'GeoCoordinateWatcher' }
    }
    finally {
        _Cleanup -w $watcher
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
        Validates a latitude/longitude pair from a GeoCoordinate.
    .DESCRIPTION
        Returns $true only when both coordinates are doubles, non-NaN, within
        valid ranges. Accepts objects exposing .Latitude/.Longitude (GeoCoordinate).
    .PARAMETER Location
        Object with Latitude/Longitude properties.
    .OUTPUTS
        [bool] indicating validity.
    .EXAMPLE
        if (Test-LatLon -Location $watcher.Position.Location) { 'ready' }
    #>
    param(
        [Parameter(Mandatory=$true)]$Location
    )
    if (-not $Location) { return $false }
    try {
        $lat = $Location.Latitude
        $lon = $Location.Longitude
    } catch { return $false }
    if ($lat -isnot [double] -or $lon -isnot [double]) { return $false }
    if ([double]::IsNaN($lat) -or [double]::IsNaN($lon)) { return $false }
    if ($lat -lt -90 -or $lat -gt 90) { return $false }
    if ($lon -lt -180 -or $lon -gt 180) { return $false }
    return $true
}
