#Requires -Version 5.1

<#
.SYNOPSIS
    Address validation service for the Travel Time system.

.DESCRIPTION
    This module provides comprehensive address validation functionality including
    format validation, geocoding validation, caching, and user experience features.
#>

# Global cache for validation results
$script:ValidationCache = @{}

function Test-AddressFormat {
    <#
    .SYNOPSIS
        Performs basic format validation on an address string.
    
    .DESCRIPTION
        Validates address format with lightweight checks including:
        - Not empty or whitespace only
        - Reasonable length limits
        - Basic character validation
    
    .PARAMETER Address
        The address string to validate.
    
    .OUTPUTS
        Hashtable containing validation results with keys:
        - IsValid: Boolean indicating if format is valid
        - Issues: Array of issues found
        - Suggestions: Array of improvement suggestions
    
    .EXAMPLE
        $result = Test-AddressFormat -Address "123 Main St, City, State"
    #>
    param([string]$Address)
    
    $result = @{
        IsValid = $true
        Issues = @()
        Suggestions = @()
    }
    
    # Check if empty or whitespace only
    if ([string]::IsNullOrWhiteSpace($Address)) {
        $result.IsValid = $false
        $result.Issues += "Address cannot be empty"
        $result.Suggestions += "Please enter a valid address"
        return $result
    }
    
    # Check minimum length (at least 5 characters for basic address)
    if ($Address.Trim().Length -lt 5) {
        $result.IsValid = $false
        $result.Issues += "Address is too short"
        $result.Suggestions += "Please provide a more complete address"
        return $result
    }
    
    # Check maximum length (reasonable limit for most addresses)
    if ($Address.Length -gt 200) {
        $result.IsValid = $false
        $result.Issues += "Address is too long"
        $result.Suggestions += "Please shorten the address to under 200 characters"
        return $result
    }
    
    # Check for basic alphanumeric content
    if (-not ($Address -match '[a-zA-Z0-9]')) {
        $result.IsValid = $false
        $result.Issues += "Address must contain letters or numbers"
        $result.Suggestions += "Please include street numbers, names, and location information"
        return $result
    }
    
    # Check for purely special characters (excluding spaces and common address punctuation)
    $cleanAddress = $Address -replace '[\s,.\-#/()]+', ''
    if ($cleanAddress -match '^[^a-zA-Z0-9]+$' -and $cleanAddress.Length -gt 0) {
        $result.IsValid = $false
        $result.Issues += "Address contains only special characters"
        $result.Suggestions += "Please include street numbers, names, and location information"
        return $result
    }
    
    # Format hints and suggestions for better geocoding
    $hasNumber = $Address -match '\d'
    $hasComma = $Address -match ','
    $hasCity = $Address -match '\w+\s*,\s*\w+'
    
    if (-not $hasNumber) {
        $result.Suggestions += "Consider including a street number for better accuracy"
    }
    
    if (-not $hasComma) {
        $result.Suggestions += "Consider using commas to separate address components (e.g., '123 Main St, City, State')"
    }
    
    if (-not $hasCity) {
        $result.Suggestions += "Consider including city and state/country for better geocoding results"
    }
    
    return $result
}

function Test-AddressGeocoding {
    <#
    .SYNOPSIS
        Tests if an address can be geocoded using Google's geocoding service.
    
    .DESCRIPTION
        Validates address by attempting to geocode it and checking if valid
        coordinates are returned. This is a more comprehensive validation but
        requires an API key.
    
    .PARAMETER Address
        The address string to geocode.
    
    .PARAMETER ApiKey
        The Google Maps API key for geocoding.
    
    .PARAMETER UseCache
        Whether to use cached results. Default is true.
    
    .OUTPUTS
        Hashtable containing geocoding validation results with keys:
        - IsValid: Boolean indicating if address can be geocoded
        - Latitude: Latitude coordinate if found
        - Longitude: Longitude coordinate if found
        - FormattedAddress: Google's formatted version of the address
        - Issues: Array of issues found
        - Suggestions: Array of improvement suggestions
        - Error: Error message if geocoding failed
    
    .EXAMPLE
        $result = Test-AddressGeocoding -Address "123 Main St, City, State" -ApiKey $apiKey
    #>
    param(
        [string]$Address,
        [string]$ApiKey,
        [bool]$UseCache = $true
    )
    
    $result = @{
        IsValid = $false
        Latitude = $null
        Longitude = $null
        FormattedAddress = $null
        Issues = @()
        Suggestions = @()
        ErrorMessage = $null
    }
    
    # Check cache first if enabled
    if ($UseCache -and $script:ValidationCache.ContainsKey($Address)) {
        Write-Verbose "Using cached validation result for address: $Address"
        return $script:ValidationCache[$Address]
    }
    
    # Validate API key
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        $result.ErrorMessage = "API key is required for geocoding validation"
        $result.Issues += "Cannot validate address without API key"
        $result.Suggestions += "Provide a valid Google Maps API key"
        return $result
    }
    
    try {
        # Use Google Geocoding API for validation
        $encodedAddress = [System.Web.HttpUtility]::UrlEncode($Address)
        $url = "https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$ApiKey"
        
        $response = Invoke-RestMethod -Uri $url -TimeoutSec 15
        
        if ($response.status -eq "OK" -and $response.results.Count -gt 0) {
            $geoResult = $response.results[0]
            $location = $geoResult.geometry.location
            
            # Validate coordinates make sense geographically
            $lat = $location.lat
            $lng = $location.lng
            
            if ($lat -ge -90 -and $lat -le 90 -and $lng -ge -180 -and $lng -le 180) {
                $result.IsValid = $true
                $result.Latitude = $lat
                $result.Longitude = $lng
                $result.FormattedAddress = $geoResult.formatted_address
                
                # Check if the formatted address is significantly different
                if ($geoResult.formatted_address -ne $Address) {
                    $result.Suggestions += "Google suggests: '$($geoResult.formatted_address)'"
                }
                
                # Check address completeness based on address components
                $components = $geoResult.address_components
                $hasStreetNumber = $components | Where-Object { $_.types -contains "street_number" }
                $hasRoute = $components | Where-Object { $_.types -contains "route" }
                $hasLocality = $components | Where-Object { $_.types -contains "locality" }
                $hasCountry = $components | Where-Object { $_.types -contains "country" }
                
                if (-not $hasStreetNumber) {
                    $result.Suggestions += "Consider including a street number for more precise location"
                }
                
                if (-not $hasRoute) {
                    $result.Suggestions += "Consider including a street name"
                }
                
                if (-not $hasLocality) {
                    $result.Suggestions += "Consider including city information"
                }
                
                if (-not $hasCountry) {
                    $result.Suggestions += "Consider including country information for international addresses"
                }
            }
            else {
                $result.ErrorMessage = "Invalid coordinates returned from geocoding service"
                $result.Issues += "Coordinates are outside valid ranges"
            }
        }
        elseif ($response.status -eq "ZERO_RESULTS") {
            $result.ErrorMessage = "Address not found"
            $result.Issues += "No results found for this address"
            $result.Suggestions += "Check spelling and include more location details (city, state, country)"
        }
        elseif ($response.status -eq "OVER_QUERY_LIMIT") {
            $result.ErrorMessage = "API quota exceeded"
            $result.Issues += "Geocoding API quota exceeded"
            $result.Suggestions += "Wait before trying again or check API quotas"
        }
        elseif ($response.status -eq "REQUEST_DENIED") {
            $result.ErrorMessage = "API request denied"
            $result.Issues += "Geocoding API request denied"
            $result.Suggestions += "Check API key permissions and billing"
        }
        elseif ($response.status -eq "INVALID_REQUEST") {
            $result.ErrorMessage = "Invalid request"
            $result.Issues += "Invalid geocoding request"
            $result.Suggestions += "Check address format and try again"
        }
        else {
            $result.ErrorMessage = "Unknown geocoding error: $($response.status)"
            $result.Issues += "Unexpected error from geocoding service"
        }
    }
    catch {
        $result.ErrorMessage = "Network error: $($_.Exception.Message)"
        $result.Issues += "Cannot connect to geocoding service"
        $result.Suggestions += "Check internet connection and try again later"
    }
    
    # Cache the result if caching is enabled
    if ($UseCache) {
        $script:ValidationCache[$Address] = $result
    }
    
    return $result
}

function Invoke-AddressValidation {
    <#
    .SYNOPSIS
        Performs comprehensive address validation with progressive checks.
    
    .DESCRIPTION
        Validates an address using multiple validation layers:
        1. Format validation (always performed)
        2. Geocoding validation (if API key provided)
        3. Provides user-friendly feedback and suggestions
    
    .PARAMETER Address
        The address string to validate.
    
    .PARAMETER ApiKey
        Optional Google Maps API key for geocoding validation.
    
    .PARAMETER AllowOverride
        Whether to allow manual override of validation warnings.
    
    .PARAMETER UseCache
        Whether to use cached geocoding results. Default is true.
    
    .OUTPUTS
        Hashtable containing comprehensive validation results with keys:
        - IsValid: Boolean indicating overall validity
        - HasWarnings: Boolean indicating if there are warnings
        - CanProceed: Boolean indicating if can proceed (even with warnings)
        - FormatValidation: Results from format validation
        - GeocodingValidation: Results from geocoding validation (if performed)
        - OverallIssues: Combined issues from all validations
        - OverallSuggestions: Combined suggestions from all validations
        - RecommendedAddress: Best suggested address format
    
    .EXAMPLE
        $result = Invoke-AddressValidation -Address "123 Main St" -ApiKey $apiKey -AllowOverride $true
    #>
    param(
        [string]$Address,
        [string]$ApiKey = $null,
        [bool]$AllowOverride = $true,
        [bool]$UseCache = $true
    )
    
    $result = @{
        IsValid = $false
        HasWarnings = $false
        CanProceed = $false
        FormatValidation = $null
        GeocodingValidation = $null
        OverallIssues = @()
        OverallSuggestions = @()
        RecommendedAddress = $Address
    }
    
    # Step 1: Format validation (always performed)
    Write-Verbose "Performing format validation for address: $Address"
    $formatResult = Test-AddressFormat -Address $Address
    $result.FormatValidation = $formatResult
    
    if (-not $formatResult.IsValid) {
        $result.OverallIssues += $formatResult.Issues
        $result.OverallSuggestions += $formatResult.Suggestions
        # Format validation failed - cannot proceed
        return $result
    }
    
    # Add format suggestions to overall suggestions
    $result.OverallSuggestions += $formatResult.Suggestions
    
    # Step 2: Geocoding validation (if API key provided)
    if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
        Write-Verbose "Performing geocoding validation for address: $Address"
        $geoResult = Test-AddressGeocoding -Address $Address -ApiKey $ApiKey -UseCache $UseCache
        $result.GeocodingValidation = $geoResult
        
        if ($geoResult.IsValid) {
            $result.IsValid = $true
            if ($geoResult.FormattedAddress) {
                $result.RecommendedAddress = $geoResult.FormattedAddress
            }
        }
        else {
            $result.HasWarnings = $true
            $result.OverallIssues += $geoResult.Issues
            if ($geoResult.ErrorMessage) {
                $result.OverallIssues += $geoResult.ErrorMessage
            }
        }
        
        $result.OverallSuggestions += $geoResult.Suggestions
    }
    else {
        # No API key provided - only format validation
        Write-Verbose "No API key provided, skipping geocoding validation"
        $result.IsValid = $true
        $result.HasWarnings = $formatResult.Suggestions.Count -gt 0
        if ($result.HasWarnings) {
            $result.OverallSuggestions += "Consider providing a Google Maps API key for geocoding validation"
        }
    }
    
    # Determine if can proceed
    if ($result.IsValid) {
        $result.CanProceed = $true
    } elseif ($AllowOverride -and $result.HasWarnings) {
        $result.CanProceed = $true
    } else {
        $result.CanProceed = $false
    }
    
    return $result
}

function Clear-AddressValidationCache {
    <#
    .SYNOPSIS
        Clears the address validation cache.
    
    .DESCRIPTION
        Removes all cached validation results to force fresh validation.
    
    .EXAMPLE
        Clear-AddressValidationCache
    #>
    $script:ValidationCache.Clear()
    Write-Verbose "Address validation cache cleared"
}

function Get-AddressValidationExamples {
    <#
    .SYNOPSIS
        Provides examples of well-formatted addresses for different regions.
    
    .DESCRIPTION
        Returns example addresses that demonstrate good formatting practices
        for different geographical regions and address types.
    
    .OUTPUTS
        Array of example address strings.
    
    .EXAMPLE
        $examples = Get-AddressValidationExamples
    #>
    return @(
        "1600 Amphitheatre Parkway, Mountain View, CA 94043, USA",
        "10 Downing Street, London SW1A 2AA, UK",
        "1 Microsoft Way, Redmond, WA 98052, USA",
        "Champ de Mars, 5 Avenue Anatole France, 75007 Paris, France",
        "PO Box 1234, Springfield, IL 62701, USA",
        "Rural Route 2, Box 45, Smalltown, MT 59718, USA"
    )
}

# Remove the Export-ModuleMember line since this isn't being used as a proper PowerShell module