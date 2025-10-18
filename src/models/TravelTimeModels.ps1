#Requires -Version 5.1

<#
.SYNOPSIS
    Data models and structures for the Travel Time system.

.DESCRIPTION
    This module defines the data structures and models used throughout
    the Travel Time system for consistent data handling.
#>

function New-TravelTimeResult {
    <#
    .SYNOPSIS
        Creates a new travel time result object with standard structure.
    
    .DESCRIPTION
        Creates a standardized hashtable for travel time results with all
        required fields initialized to appropriate default values.
    
    .PARAMETER Config
        The configuration object containing travel settings.
    
    .PARAMETER IsActiveHours
        Boolean indicating if tracking is currently in active hours.
    
    .OUTPUTS
        Hashtable with standardized travel time result structure.
    
    .EXAMPLE
        $result = New-TravelTimeResult -Config $config -IsActiveHours $true
    #>
    param(
        [PSCustomObject]$Config,
        [bool]$IsActiveHours
    )
    
    return @{
        last_updated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        travel_time_minutes = $null
        distance_km = $null
        traffic_status = $null
        travel_mode = if ($Config) { $Config.travel_mode } else { "DRIVE" }
        error_message = $null
        is_active_hours = $IsActiveHours
        active_period = if ($Config) { "$($Config.start_time) - $($Config.end_time)" } else { "Not configured" }
        location_status = "unknown"
    }
}

function New-LocationResult {
    <#
    .SYNOPSIS
        Creates a new location result object with standard structure.
    
    .DESCRIPTION
        Creates a standardized hashtable for location results with all
        required fields for geolocation data.
    
    .PARAMETER Latitude
        The latitude coordinate.
    
    .PARAMETER Longitude
        The longitude coordinate.
    
    .PARAMETER City
        The city name.
    
    .PARAMETER Region
        The region/state name.
    
    .PARAMETER Success
        Boolean indicating if the location retrieval was successful.
    
    .PARAMETER ErrorMessage
        Error message if the location retrieval failed.
    
    .OUTPUTS
        Hashtable with standardized location result structure.
    
    .EXAMPLE
        $location = New-LocationResult -Latitude 40.7128 -Longitude -74.0060 -City "New York" -Region "NY" -Success $true
    #>
    param(
        [double]$Latitude = 0,
        [double]$Longitude = 0,
        [string]$City = "Unknown",
        [string]$Region = "Unknown",
        [string]$Country = "Unknown",
        [bool]$Success = $false,
        [string]$ErrorMessage = $null,
        [string]$Method = "Unknown",
        [string]$Provider = "",
        [double]$Accuracy = 0
    )
    
    return @{
        Latitude = $Latitude
        Longitude = $Longitude
        City = $City
        Region = $Region
        Country = $Country
        Success = $Success
        ErrorMessage = $ErrorMessage
        Method = $Method
        Provider = $Provider
        Accuracy = $Accuracy
        Timestamp = Get-Date
    }
}

function New-ApiResult {
    <#
    .SYNOPSIS
        Creates a new API result object with standard structure.
    
    .DESCRIPTION
        Creates a standardized hashtable for API call results with
        consistent success/error handling structure.
    
    .PARAMETER Success
        Boolean indicating if the API call was successful.
    
    .PARAMETER Data
        The data returned from the successful API call.
    
    .PARAMETER Error
        Error message if the API call failed.
    
    .OUTPUTS
        Hashtable with standardized API result structure.
    
    .EXAMPLE
        $result = New-ApiResult -Success $true -Data $responseData
    #>
    param(
        [bool]$Success = $false,
        [object]$Data = $null,
        [string]$ErrorMessage = $null
    )
    
    return @{
        Success = $Success
        Data = $Data
        ErrorMessage = $ErrorMessage
        Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
}

function Test-TravelTimeResultStructure {
    <#
    .SYNOPSIS
        Validates the structure of a travel time result object.
    
    .DESCRIPTION
        Checks if a travel time result object contains all required fields
        with appropriate data types.
    
    .PARAMETER Result
        The travel time result object to validate.
    
    .OUTPUTS
        Boolean indicating if the structure is valid.
    
    .EXAMPLE
        $isValid = Test-TravelTimeResultStructure -Result $travelResult
    #>
    param([hashtable]$Result)
    
    if (-not $Result) {
        return $false
    }
    
    $requiredFields = @(
        'last_updated',
        'travel_time_minutes',
        'distance_km', 
        'traffic_status',
        'travel_mode',
        'error_message',
        'is_active_hours',
        'active_period',
        'location_status'
    )
    
    foreach ($field in $requiredFields) {
        if (-not $Result.ContainsKey($field)) {
            Write-Warning "Missing required field in travel time result: $field"
            return $false
        }
    }
    
    return $true
}