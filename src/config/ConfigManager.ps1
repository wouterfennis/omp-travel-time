#Requires -Version 5.1

<#
.SYNOPSIS
    Configuration management module for the Travel Time system.

.DESCRIPTION
    This module provides functions for loading, validating, and managing
    configuration files for the Travel Time system.
#>

function Get-TravelTimeConfig {
    <#
    .SYNOPSIS
        Loads and validates the travel time configuration from a JSON file.
    
    .DESCRIPTION
        Reads the configuration file and returns a validated configuration object.
        Returns null if the file doesn't exist or contains invalid JSON.
    
    .PARAMETER Path
        The path to the configuration JSON file.
    
    .OUTPUTS
        PSCustomObject containing the configuration, or $null if invalid.
    
    .EXAMPLE
        $config = Get-TravelTimeConfig -Path ".\config\travel-config.json"
    #>
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Error "Config file not found: $Path. Run Install-TravelTimeService.ps1 first."
        return $null
    }
    
    try {
        return Get-Content $Path | ConvertFrom-Json
    }
    catch {
        Write-Error "Invalid JSON in config file: $_"
        return $null
    }
}

function Test-ConfigurationFile {
    <#
    .SYNOPSIS
        Validates a configuration file structure and required fields.
    
    .DESCRIPTION
        Checks if a configuration object contains all required fields with valid values.
    
    .PARAMETER Config
        The configuration object to validate.
    
    .OUTPUTS
        Boolean indicating if the configuration is valid.
    
    .EXAMPLE
        $isValid = Test-ConfigurationFile -Config $config
    #>
    param([PSCustomObject]$Config)
    
    if (-not $Config) {
        return $false
    }
    
    $requiredFields = @(
        'google_routes_api_key',
        'home_address',
        'start_time',
        'end_time',
        'travel_mode',
        'routing_preference'
    )
    
    foreach ($field in $requiredFields) {
        if (-not $Config.PSObject.Properties.Name -contains $field) {
            Write-Warning "Missing required configuration field: $field"
            return $false
        }
        
        if ([string]::IsNullOrWhiteSpace($Config.$field)) {
            Write-Warning "Empty value for required field: $field"
            return $false
        }
    }
    
    return $true
}