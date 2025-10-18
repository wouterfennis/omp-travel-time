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
        Determines if the current time is within the configured active hours.
    
    .DESCRIPTION
        Compares the current time against the configured start and end times
        to determine if travel time tracking should be active.
    
    .PARAMETER StartTime
        The start time in HH:mm format (e.g., "15:00").
    
    .PARAMETER EndTime
        The end time in HH:mm format (e.g., "23:00").
    
    .OUTPUTS
        Boolean indicating if the current time is within active hours.
    
    .EXAMPLE
        $isActive = Test-ActiveHours -StartTime "15:00" -EndTime "23:00"
    #>
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