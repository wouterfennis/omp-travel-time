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
    try {
        $geolocatorType = [Type]::GetType('Windows.Devices.Geolocation.Geolocator, Windows, ContentType=WindowsRuntime')
        if (-not $geolocatorType) {
            return @{ Success = $false; Error = 'WinRT Geolocator type not available'; Method = 'Windows' }
        }
        $geolocator = [Windows.Devices.Geolocation.Geolocator]::new()
        $asyncOp = $geolocator.GetGeopositionAsync()

        # PowerShell 5.1 cannot call GetAwaiter on WinRT directly; poll Status.
        $maxWaitMs = 5000
        $intervalMs = 100
        $elapsed = 0
        while ($asyncOp.Status -eq 0 -and $elapsed -lt $maxWaitMs) { # 0 = Started
            Start-Sleep -Milliseconds $intervalMs
            $elapsed += $intervalMs
        }

        if ($asyncOp.Status -ne 1) { # 1 = Completed
            return @{ Success = $false; Error = 'Location request timed out or failed'; Method = 'Windows' }
        }

        $pos = $asyncOp.GetResults()
        $lat = $pos.Coordinate.Point.Position.Latitude
        $lon = $pos.Coordinate.Point.Position.Longitude
        if ($lat -and $lon) {
            return @{ Success = $true; Latitude = [math]::Round($lat,6); Longitude = [math]::Round($lon,6); Method = 'Windows'; Provider = 'Windows'; Timestamp = Get-Date }
        }
        return @{ Success = $false; Error = 'Empty coordinates returned'; Method = 'Windows' }
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message; Method = 'Windows' }
    }
}
