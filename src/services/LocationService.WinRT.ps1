#Requires -Version 5.1

<#
.SYNOPSIS
    Windows Location Service helper using WinRT Geolocator.

.DESCRIPTION
    Provides a single function `Get-WindowsLocation` that attempts to retrieve
    the current latitude/longitude via the Windows Location Service. Returns
    a typed hashtable compatible with existing location result expectations.

    If location is disabled or permission denied, returns an object with
    Success = $false and an appropriate Error message.

.NOTES
        Requires user to enable:
            Settings > Privacy & Security > Location > Location services (On)
            And "Let desktop apps access your location" (On)
#>

function Get-WindowsLocation {
    <#
    .SYNOPSIS
        Retrieves current coordinates using Windows Location Services (WinRT Geolocator).

    .OUTPUTS
        Hashtable with keys:
            Success (bool)
            Latitude / Longitude (double, when Success)
            Error (string, when !Success)
            Method ("Windows")
            Provider ("Windows")
            Timestamp (DateTime, when Success)

    .NOTES
        Includes preflight checks for service state and permission hints. Avoids GetAwaiter() for PS 5.1.
    #>
    try {
        # Preflight: ensure Geolocation Service (lfsvc) exists and is running
        $geoService = Get-Service -Name 'lfsvc' -ErrorAction SilentlyContinue
        if (-not $geoService) {
            return @{ Success = $false; Error = 'Geolocation service (lfsvc) not found on this system'; Method = 'Windows' }
        }
        if ($geoService.Status -ne 'Running') {
            return @{ Success = $false; Error = 'Geolocation service not running (lfsvc). Enable Location Services in Windows Settings.'; Method = 'Windows' }
        }

        # Attempt to access WinRT type using direct reference first (more reliable than [Type]::GetType in PS 5.1)
        $typeAvailable = $true
        try { $null = [Windows.Devices.Geolocation.Geolocator] } catch { $typeAvailable = $false }
        if (-not $typeAvailable) {
            # Fallback attempt: load Windows.winmd metadata if present
            $winmd = Join-Path $env:windir 'System32\WinMetadata\Windows.winmd'
            if (Test-Path $winmd) {
                try { Add-Type -Path $winmd -ErrorAction Stop } catch {}
                try { $null = [Windows.Devices.Geolocation.Geolocator] } catch { $typeAvailable = $false }
            } else { $typeAvailable = $false }
        }
        if (-not $typeAvailable) {
            return @{ Success = $false; Error = 'WinRT Geolocator type not available'; Method = 'Windows' }
        }

        $geolocator = [Windows.Devices.Geolocation.Geolocator]::new()

        # Optional: request higher accuracy (will fallback automatically if unavailable)
        if ($geolocator -and ($geolocator | Get-Member -Name DesiredAccuracy -ErrorAction SilentlyContinue)) {
            try { $geolocator.DesiredAccuracy = 2 } catch {}
        }

        $asyncOp = $geolocator.GetGeopositionAsync()

        # Poll the async operation status (IAsyncOperationStatus: Started=0, Completed=1, Error=2, Canceled=3)
        $maxWaitMs = 6000
        $intervalMs = 150
        $elapsed = 0
        while ($asyncOp.Status -eq 0 -and $elapsed -lt $maxWaitMs) {
            Start-Sleep -Milliseconds $intervalMs
            $elapsed += $intervalMs
        }

        switch ($asyncOp.Status) {
            1 { # Completed
                try {
                    $pos = $asyncOp.GetResults()
                    $lat = $pos.Coordinate.Point.Position.Latitude
                    $lon = $pos.Coordinate.Point.Position.Longitude
                    if ($lat -and $lon) {
                        return @{ Success = $true; Latitude = [math]::Round($lat,6); Longitude = [math]::Round($lon,6); Method = 'Windows'; Provider = 'Windows'; Timestamp = Get-Date }
                    } else {
                        return @{ Success = $false; Error = 'Empty coordinates returned'; Method = 'Windows' }
                    }
                } catch {
                    return @{ Success = $false; Error = 'Failed to read position results: ' + $_.Exception.Message; Method = 'Windows' }
                }
            }
            2 { return @{ Success = $false; Error = 'Location request error (access denied or disabled)'; Method = 'Windows' } }
            3 { return @{ Success = $false; Error = 'Location request canceled'; Method = 'Windows' } }
            default { return @{ Success = $false; Error = 'Location request timed out'; Method = 'Windows' } }
        }
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message; Method = 'Windows' }
    }
}
