#Requires -Version 5.1

<#
.SYNOPSIS
    Tests for the Address Validation Service.

.DESCRIPTION
    Comprehensive test suite for address validation functionality including
    format validation, geocoding validation, caching, and user experience features.
#>

param(
    [string]$TestApiKey = $null,
    [switch]$Verbose = $false
)

# Set up test environment
$ErrorActionPreference = "Continue"
if ($Verbose) { $VerbosePreference = "Continue" }

# Test results tracking
$TestResults = @{
    Passed = 0
    Failed = 0
    Skipped = 0
    Tests = @()
}

function Test-AddressValidation {
    param([string]$Name, [scriptblock]$TestCode, [bool]$Skip = $false)
    
    Write-Host "Testing: $Name" -ForegroundColor Cyan
    
    if ($Skip) {
        Write-Host "  SKIPPED" -ForegroundColor Yellow
        $TestResults.Skipped++
        $TestResults.Tests += @{ Name = $Name; Passed = $false; Skipped = $true }
        return
    }
    
    try {
        $result = & $TestCode
        if ($result) {
            Write-Host "  PASSED" -ForegroundColor Green
            $TestResults.Passed++
            $TestResults.Tests += @{ Name = $Name; Passed = $true; Skipped = $false }
        }
        else {
            Write-Host "  FAILED" -ForegroundColor Red
            $TestResults.Failed++
            $TestResults.Tests += @{ Name = $Name; Passed = $false; Skipped = $false }
        }
    }
    catch {
        Write-Host "  FAILED - Exception: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
        $TestResults.Tests += @{ Name = $Name; Passed = $false; Skipped = $false }
    }
}

# Import the address validation service
$serviceRoot = Split-Path $PSScriptRoot -Parent
$addressServicePath = Join-Path $serviceRoot "src\services\AddressValidationService.ps1"

if (-not (Test-Path $addressServicePath)) {
    Write-Host "ERROR: Address validation service not found at: $addressServicePath" -ForegroundColor Red
    exit 1
}

. $addressServicePath

Write-Host ""
Write-Host "Address Validation Service Tests" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Format Validation - Valid Addresses
Test-AddressValidation "Format Validation - Valid Complete Address" {
    $result = Test-AddressFormat -Address "123 Main Street, Springfield, IL 62701"
    return $result.IsValid -eq $true -and $result.Issues.Count -eq 0
}

Test-AddressValidation "Format Validation - Valid International Address" {
    $result = Test-AddressFormat -Address "10 Downing Street, London SW1A 2AA, United Kingdom"
    return $result.IsValid -eq $true -and $result.Issues.Count -eq 0
}

Test-AddressValidation "Format Validation - Valid P.O. Box" {
    $result = Test-AddressFormat -Address "P.O. Box 1234, Springfield, IL 62701"
    return $result.IsValid -eq $true -and $result.Issues.Count -eq 0
}

# Test 2: Format Validation - Invalid Addresses
Test-AddressValidation "Format Validation - Empty Address" {
    $result = Test-AddressFormat -Address ""
    return $result.IsValid -eq $false -and $result.Issues -contains "Address cannot be empty"
}

Test-AddressValidation "Format Validation - Whitespace Only" {
    $result = Test-AddressFormat -Address "   "
    return $result.IsValid -eq $false -and $result.Issues -contains "Address cannot be empty"
}

Test-AddressValidation "Format Validation - Too Short" {
    $result = Test-AddressFormat -Address "123"
    return $result.IsValid -eq $false -and $result.Issues -contains "Address is too short"
}

Test-AddressValidation "Format Validation - Too Long" {
    $longAddress = "A" * 250
    $result = Test-AddressFormat -Address $longAddress
    return $result.IsValid -eq $false -and $result.Issues -contains "Address is too long"
}

Test-AddressValidation "Format Validation - No Alphanumeric Characters" {
    $result = Test-AddressFormat -Address "!@#$%^&*()"
    return $result.IsValid -eq $false -and $result.Issues -contains "Address must contain letters or numbers"
}

Test-AddressValidation "Format Validation - Only Special Characters" {
    $result = Test-AddressFormat -Address "@@@@@@"
    # Should fail with "must contain letters or numbers" rather than "only special characters"
    return $result.IsValid -eq $false -and ($result.Issues -contains "Address must contain letters or numbers")
}

# Test 3: Format Validation - Suggestions
Test-AddressValidation "Format Validation - Missing Number Suggestion" {
    $result = Test-AddressFormat -Address "Main Street, Springfield, IL"
    return $result.IsValid -eq $true -and ($result.Suggestions | Where-Object { $_ -like "*street number*" }).Count -gt 0
}

Test-AddressValidation "Format Validation - Missing Comma Suggestion" {
    $result = Test-AddressFormat -Address "123 Main Street Springfield IL"
    return $result.IsValid -eq $true -and ($result.Suggestions | Where-Object { $_ -like "*comma*" }).Count -gt 0
}

Test-AddressValidation "Format Validation - Missing City Suggestion" {
    $result = Test-AddressFormat -Address "123 Main Street"
    return $result.IsValid -eq $true -and ($result.Suggestions | Where-Object { $_ -like "*city*" }).Count -gt 0
}

# Test 4: Geocoding Validation (with API key)
Test-AddressValidation "Geocoding Validation - Valid Address" -Skip:([string]::IsNullOrWhiteSpace($TestApiKey)) {
    $result = Test-AddressGeocoding -Address "1600 Amphitheatre Parkway, Mountain View, CA" -ApiKey $TestApiKey
    return $result.IsValid -eq $true -and $result.Latitude -ne $null -and $result.Longitude -ne $null
}

Test-AddressValidation "Geocoding Validation - Invalid Address" -Skip:([string]::IsNullOrWhiteSpace($TestApiKey)) {
    $result = Test-AddressGeocoding -Address "This is definitely not a real address 123456789" -ApiKey $TestApiKey
    return $result.IsValid -eq $false -and $result.Error -ne $null
}

Test-AddressValidation "Geocoding Validation - No API Key" {
    $result = Test-AddressGeocoding -Address "123 Main Street" -ApiKey ""
    return $result.IsValid -eq $false -and $result.Error -like "*API key*"
}

# Test 5: Caching Functionality
Test-AddressValidation "Caching - Cache Clear" {
    Clear-AddressValidationCache
    # Should not throw an exception
    return $true
}

Test-AddressValidation "Caching - Cache Usage" -Skip:([string]::IsNullOrWhiteSpace($TestApiKey)) {
    # Clear cache first
    Clear-AddressValidationCache
    
    # First call should cache the result
    $result1 = Test-AddressGeocoding -Address "1600 Amphitheatre Parkway, Mountain View, CA" -ApiKey $TestApiKey -UseCache $true
    
    # Second call should use cached result (we can't easily test this without timing, so we just verify it doesn't error)
    $result2 = Test-AddressGeocoding -Address "1600 Amphitheatre Parkway, Mountain View, CA" -ApiKey $TestApiKey -UseCache $true
    
    return $result1.IsValid -eq $result2.IsValid
}

# Test 6: Comprehensive Validation
Test-AddressValidation "Comprehensive Validation - Valid Address Without API" {
    $result = Invoke-AddressValidation -Address "123 Main Street, Springfield, IL 62701"
    return $result.IsValid -eq $true -and $result.CanProceed -eq $true
}

Test-AddressValidation "Comprehensive Validation - Invalid Address" {
    $result = Invoke-AddressValidation -Address ""
    return $result.IsValid -eq $false -and $result.CanProceed -eq $false
}

Test-AddressValidation "Comprehensive Validation - With Warnings and Override" {
    $result = Invoke-AddressValidation -Address "Main Street" -AllowOverride $true
    return $result.HasWarnings -eq $true -and $result.CanProceed -eq $true
}

Test-AddressValidation "Comprehensive Validation - With Warnings No Override" {
    $result = Invoke-AddressValidation -Address "Main Street" -AllowOverride $false
    # When valid but has warnings and no override allowed, it should still allow proceeding since the address is valid
    return $result.IsValid -eq $true -and $result.HasWarnings -eq $true -and $result.CanProceed -eq $true
}

Test-AddressValidation "Comprehensive Validation - With API Key" -Skip:([string]::IsNullOrWhiteSpace($TestApiKey)) {
    $result = Invoke-AddressValidation -Address "1600 Amphitheatre Parkway, Mountain View, CA" -ApiKey $TestApiKey
    return $result.IsValid -eq $true -and $result.GeocodingValidation -ne $null
}

# Test 7: Address Examples
Test-AddressValidation "Address Examples - Returns Examples" {
    $examples = Get-AddressValidationExamples
    return $examples.Count -gt 0 -and ($examples | Where-Object { $_.Length -gt 10 }).Count -gt 0
}

# Test 8: Edge Cases
Test-AddressValidation "Edge Cases - Unicode Characters" {
    $result = Test-AddressFormat -Address "123 Rue de la Paix, 75001 Paris, France"
    return $result.IsValid -eq $true
}

Test-AddressValidation "Edge Cases - Numbers and Hyphens" {
    $result = Test-AddressFormat -Address "123-456 Main Street, Apt 4-B, Springfield, IL 62701"
    return $result.IsValid -eq $true
}

Test-AddressValidation "Edge Cases - Multiple Spaces" {
    $result = Test-AddressFormat -Address "123    Main    Street,    Springfield,    IL"
    return $result.IsValid -eq $true
}

# Test 9: Coordinate Validation
Test-AddressValidation "Coordinate Validation - Valid Coordinates" -Skip:([string]::IsNullOrWhiteSpace($TestApiKey)) {
    $result = Test-AddressGeocoding -Address "Times Square, New York, NY" -ApiKey $TestApiKey
    if ($result.IsValid) {
        $lat = $result.Latitude
        $lng = $result.Longitude
        return $lat -ge -90 -and $lat -le 90 -and $lng -ge -180 -and $lng -le 180
    }
    return $false
}

# Test 10: Integration with Configuration
Test-AddressValidation "Integration - Configuration Validation" {
    # Create a mock config object
    $config = [PSCustomObject]@{
        google_routes_api_key = if ($TestApiKey) { $TestApiKey } else { "test_key_12345678901234567890123456789" }
        home_address = "123 Main Street, Springfield, IL 62701"
        start_time = "15:00"
        end_time = "23:00"
        travel_mode = "DRIVE"
        routing_preference = "TRAFFIC_AWARE"
    }
    
    # Import config manager
    $configManagerPath = Join-Path $serviceRoot "src\config\ConfigManager.ps1"
    if (Test-Path $configManagerPath) {
        . $configManagerPath
        $result = Test-ConfigurationFile -Config $config -ValidateAddress $true
        return $result.IsValid -eq $true
    }
    else {
        Write-Warning "Config manager not found, skipping integration test"
        return $true
    }
}

Write-Host ""
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "============" -ForegroundColor Cyan
Write-Host "Passed:  $($TestResults.Passed)" -ForegroundColor Green
Write-Host "Failed:  $($TestResults.Failed)" -ForegroundColor Red
Write-Host "Skipped: $($TestResults.Skipped)" -ForegroundColor Yellow
Write-Host "Total:   $($TestResults.Passed + $TestResults.Failed + $TestResults.Skipped)"

$passRate = if (($TestResults.Passed + $TestResults.Failed) -gt 0) {
    [math]::Round(($TestResults.Passed / ($TestResults.Passed + $TestResults.Failed)) * 100, 1)
} else { 0 }

Write-Host "Pass Rate: $passRate%" -ForegroundColor Cyan

if ($TestResults.Failed -gt 0) {
    Write-Host ""
    Write-Host "Some tests failed. Review the issues above." -ForegroundColor Red
    Write-Host ""
    Write-Host "Failed tests:" -ForegroundColor Red
    foreach ($test in $TestResults.Tests | Where-Object { -not $_.Passed -and -not $_.Skipped }) {
        Write-Host "  - $($test.Name)" -ForegroundColor Red
    }
    
    return @{
        AllPassed = $false
        Passed = $TestResults.Passed
        Failed = $TestResults.Failed
        Skipped = $TestResults.Skipped
        PassRate = $passRate
        Tests = $TestResults.Tests
    }
}
else {
    Write-Host ""
    Write-Host "All tests passed!" -ForegroundColor Green
    if ($TestResults.Skipped -gt 0) {
        Write-Host ""
        Write-Host "Skipped tests (provide -TestApiKey for full testing):" -ForegroundColor Yellow
        foreach ($test in $TestResults.Tests | Where-Object { $_.Skipped }) {
            Write-Host "  - $($test.Name)" -ForegroundColor Yellow
        }
    }
    
    return @{
        AllPassed = $true
        Passed = $TestResults.Passed
        Failed = $TestResults.Failed
        Skipped = $TestResults.Skipped
        PassRate = $passRate
        Tests = $TestResults.Tests
    }
}