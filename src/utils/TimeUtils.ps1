#Requires -Version 5.1

<#
.SYNOPSIS
    Utility functions for the Travel Time system.

.DESCRIPTION
    This module provides utility functions for time calculations, data formatting,
    and other common operations used throughout the Travel Time system.
#>

function Test-ActiveHours {
    <#
    .SYNOPSIS
        Determines if a reference time is within configured active hours.

    .DESCRIPTION
        Compares a (possibly injected) reference time against start and end times.
        Supports normal same-day ranges (Start <= End) and overnight ranges
        (when Start > End, e.g., 22:00 - 06:00 wraps past midnight).

    .PARAMETER StartTime
        The start time in HH:mm format (e.g. "15:00").

    .PARAMETER EndTime
        The end time in HH:mm format (e.g. "23:00").

    .PARAMETER ReferenceTime
        Optional date/time used for evaluation (defaults to current time). Enables
        unit tests to supply a deterministic time without relying on real clock.

    .OUTPUTS
        [bool] indicating if ReferenceTime is within active hours.

    .EXAMPLE
        $isActive = Test-ActiveHours -StartTime "15:00" -EndTime "23:00"

    .EXAMPLE
        # Deterministic test injection
        $ref = Get-Date "2025-01-01T21:30:00"; Test-ActiveHours -StartTime "22:00" -EndTime "06:00" -ReferenceTime $ref
    #>
    param(
        [string]$StartTime,
        [string]$EndTime,
        [DateTime]$ReferenceTime = (Get-Date)
    )

    # Validate format quickly; return false on invalid times
    if (-not (Test-TimeFormat -Time $StartTime) -or -not (Test-TimeFormat -Time $EndTime)) { return $false }

    # Parse only time-of-day; use TimeSpan for clean comparison
    $startSpan = [TimeSpan]::Parse($StartTime)
    $endSpan = [TimeSpan]::Parse($EndTime)
    $currentSpan = $ReferenceTime.TimeOfDay

    if ($startSpan -le $endSpan) {
        # Same-day window
        return ($currentSpan -ge $startSpan -and $currentSpan -le $endSpan)
    }
    else {
        # Overnight window (e.g. 22:00 -> 06:00)
        return ($currentSpan -ge $startSpan -or $currentSpan -le $endSpan)
    }
}

function Format-Duration {
    <#
    .SYNOPSIS
        Formats a duration in minutes to a human-readable string.
    
    .DESCRIPTION
        Converts a duration in minutes to a formatted string showing hours and minutes.
    
    .PARAMETER Minutes
        The duration in minutes.
    
    .OUTPUTS
        String in the format "Xh Ym" or "Ym" if less than an hour.
    
    .EXAMPLE
        $formatted = Format-Duration -Minutes 125  # Returns "2h 5m"
    #>
    param([int]$Minutes)
    
    if ($Minutes -lt 60) {
        return "${Minutes}m"
    }
    
    $hours = [math]::Floor($Minutes / 60)
    $remainingMinutes = $Minutes % 60
    
    if ($remainingMinutes -eq 0) {
        return "${hours}h"
    }
    
    return "${hours}h ${remainingMinutes}m"
}

function ConvertTo-TrafficStatus {
    <#
    .SYNOPSIS
        Determines traffic status based on travel time duration.
    
    .DESCRIPTION
        Classifies traffic conditions as light, moderate, or heavy based on
        the travel time duration in minutes.
    
    .PARAMETER DurationMinutes
        The travel time in minutes.
    
    .OUTPUTS
        String indicating traffic status: "light", "moderate", or "heavy".
    
    .EXAMPLE
        $status = ConvertTo-TrafficStatus -DurationMinutes 35  # Returns "moderate"
    #>
    param([int]$DurationMinutes)
    
    if ($DurationMinutes -gt 45) {
        return "heavy"
    }
    elseif ($DurationMinutes -gt 30) {
        return "moderate"
    }
    else {
        return "light"
    }
}

function Test-TimeFormat {
    <#
    .SYNOPSIS
        Validates if a string is in valid time format (HH:mm).
    
    .DESCRIPTION
        Checks if the provided string can be parsed as a valid time in HH:mm format.
    
    .PARAMETER Time
        The time string to validate.
    
    .OUTPUTS
        Boolean indicating if the time format is valid.
    
    .EXAMPLE
        $isValid = Test-TimeFormat -Time "15:30"  # Returns $true
    #>
    param([string]$Time)
    
    try {
        [DateTime]::Parse($Time) | Out-Null
        return $true
    }
    catch {
        return $false
    }
}