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
        Also performs address validation if address validation service is available.
    
    .PARAMETER Config
        The configuration object to validate.
    
    .PARAMETER ValidateAddress
        Whether to perform address validation. Default is true.
    
    .OUTPUTS
        Hashtable containing validation results with keys:
        - IsValid: Boolean indicating if configuration is valid
        - Issues: Array of validation issues found
        - Warnings: Array of validation warnings
        - AddressValidation: Address validation results if performed
        - BufferPathValidation: Buffer file path validation results
    
    .EXAMPLE
        $result = Test-ConfigurationFile -Config $config
    #>
    param(
        [PSCustomObject]$Config,
        [bool]$ValidateAddress = $true
    )
    
    $result = @{
        IsValid = $true
        Issues = @()
        Warnings = @()
        AddressValidation = $null
        BufferPathValidation = $null
    }
    
    if (-not $Config) {
        $result.IsValid = $false
        $result.Issues += "Configuration object is null"
        return $result
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
            $result.IsValid = $false
            $result.Issues += "Missing required configuration field: $field"
        }
        elseif ([string]::IsNullOrWhiteSpace($Config.$field)) {
            $result.IsValid = $false
            $result.Issues += "Empty value for required field: $field"
        }
    }
    
    # Validate buffer file path if specified
    if ($Config.PSObject.Properties.Name -contains 'buffer_file_path' -and 
        -not [string]::IsNullOrWhiteSpace($Config.buffer_file_path)) {
        try {
            # Import buffer path utilities if not already loaded
            $bufferUtilsPath = Join-Path $PSScriptRoot "..\utils\BufferPathUtils.ps1"
            if (Test-Path $bufferUtilsPath) {
                . $bufferUtilsPath
                
                $bufferPathResult = Test-BufferFilePathAccess -Path $Config.buffer_file_path
                $result.BufferPathValidation = $bufferPathResult
                
                if (-not $bufferPathResult.IsValid) {
                    $result.IsValid = $false
                    $result.Issues += "Buffer file path validation failed: $($bufferPathResult.Issues -join ', ')"
                }
            }
            else {
                $result.Warnings += "Buffer path utilities not found - skipping buffer path validation"
            }
        }
        catch {
            $result.Warnings += "Buffer file path validation failed: $($_.Exception.Message)"
        }
    }
    
    # Perform address validation if requested and address is present
    if ($ValidateAddress -and $Config.home_address -and -not [string]::IsNullOrWhiteSpace($Config.home_address)) {
        try {
            # Import address validation service
            $addressServicePath = Join-Path $PSScriptRoot "..\services\AddressValidationService.ps1"
            if (Test-Path $addressServicePath) {
                . $addressServicePath
                
                # Perform address validation
                $apiKey = if ($Config.google_routes_api_key -and $Config.google_routes_api_key -ne "YOUR_GOOGLE_ROUTES_API_KEY_HERE") {
                    $Config.google_routes_api_key
                } else {
                    $null
                }
                
                $addressResult = Invoke-AddressValidation -Address $Config.home_address -ApiKey $apiKey -AllowOverride $true
                $result.AddressValidation = $addressResult
                
                if (-not $addressResult.IsValid -and -not $addressResult.CanProceed) {
                    $result.IsValid = $false
                    $result.Issues += "Home address validation failed: $($addressResult.OverallIssues -join ', ')"
                }
                elseif ($addressResult.HasWarnings) {
                    $result.Warnings += "Home address warnings: $($addressResult.OverallSuggestions -join ', ')"
                }
            }
            else {
                $result.Warnings += "Address validation service not found - skipping address validation"
            }
        }
        catch {
            $result.Warnings += "Address validation failed: $($_.Exception.Message)"
        }
    }
    
    return $result
}