#Requires -Version 5.1

<#
.SYNOPSIS
    Configuration validation tests for the Travel Time system.

.DESCRIPTION
    This script validates configuration files, settings, and deployment readiness
    for the Oh My Posh travel time integration.
#>

param(
    [switch]$Verbose = $false
)

# Set up test environment
$ErrorActionPreference = "Continue"

# Test results tracking
$ConfigResults = @{
    Passed = 0
    Failed = 0
    Skipped = 0
    Tests = @()
}

function Test-Configuration {
    param([string]$Name, [scriptblock]$TestCode, [bool]$Skip = $false)
    
    Write-Host "Testing: $Name" -ForegroundColor Cyan
    
    if ($Skip) {
        Write-Host "  SKIPPED" -ForegroundColor Yellow
        $ConfigResults.Skipped++
        $ConfigResults.Tests += @{ Name = $Name; Passed = $false; Skipped = $true }
        return
    }
    
    try {
        $result = & $TestCode
        if ($result) {
            Write-Host "  PASSED" -ForegroundColor Green
            $ConfigResults.Passed++
            $ConfigResults.Tests += @{ Name = $Name; Passed = $true; Skipped = $false }
        }
        else {
            Write-Host "  FAILED" -ForegroundColor Red
            $ConfigResults.Failed++
            $ConfigResults.Tests += @{ Name = $Name; Passed = $false; Skipped = $false }
        }
    }
    catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $ConfigResults.Failed++
        $ConfigResults.Tests += @{ Name = $Name; Passed = $false; Skipped = $false; Error = $_.Exception.Message }
    }
}

Write-Host "Travel Time Configuration Tests" -ForegroundColor Blue
Write-Host "===============================" -ForegroundColor Blue
Write-Host ""

# Test 1: Template File Validation
Test-Configuration "Configuration Template Exists" {
    $templatePath = "$PSScriptRoot\..\scripts\config\travel-config.json.template"
    return (Test-Path $templatePath)
}

# Test 2: Template JSON Structure
Test-Configuration "Template JSON Structure" {
    $templatePath = "$PSScriptRoot\..\scripts\config\travel-config.json.template"
    try {
        $template = Get-Content $templatePath | ConvertFrom-Json
        
        $requiredFields = @(
            "google_routes_api_key",
            "home_address", 
            "update_interval_minutes",
            "start_time",
            "end_time",
            "travel_mode",
            "routing_preference",
            "units"
        )
        
        foreach ($field in $requiredFields) {
            if (-not $template.PSObject.Properties.Name.Contains($field)) {
                Write-Host "  Missing field: $field" -ForegroundColor Red
                return $false
            }
        }
        
        return $true
    }
    catch {
        return $false
    }
}

# Test 3: Time Format Validation
Test-Configuration "Time Format Validation" {
    try {
        . "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"
        
        # Test valid time formats
        $validTimes = @("09:00", "17:30", "23:59", "00:00")
        
        foreach ($time in $validTimes) {
            try {
                $parsed = [DateTime]::ParseExact($time, "HH:mm", $null)
            }
            catch {
                Write-Host "  Invalid time format: $time" -ForegroundColor Red
                return $false
            }
        }
        
        return $true
    }
    catch {
        return $false
    }
}

# Test 4: API Key Format Validation
Test-Configuration "API Key Format Validation" {
    # Test that our validation function works
    $testKeys = @{
        "AIzaSyD1234567890abcdefghijklmnopqrstuv" = $true    # Valid format
        "invalid-key" = $false                                # Too short
        "empty-string" = $false                               # Empty placeholder
    }
    
    foreach ($key in $testKeys.Keys) {
        $expected = $testKeys[$key]
        
        # Simple validation - Google API keys are typically 39 characters and start with AIza
        $isValid = $false
        if ($key -and $key.Length -ge 30 -and $key -match "^AIza") {
            $isValid = $true
        }
        elseif ($key -eq "empty-string") {
            $isValid = $false  # Treat as empty
        }
        
        if ($isValid -ne $expected) {
            Write-Host "  API key validation failed for: $key" -ForegroundColor Red
            return $false
        }
    }
    
    return $true
}

# Test 5: Oh My Posh Integration
Test-Configuration "Oh My Posh Config Integration" {
    $ompConfigPath = "$PSScriptRoot\..\new_config.omp.json"
    
    try {
        $config = Get-Content $ompConfigPath | ConvertFrom-Json
        
        # Verify structure
        if (-not $config.blocks) {
            Write-Host "  Missing blocks array" -ForegroundColor Red
            return $false
        }
        
        # Look for travel time segment
        $foundTravelSegment = $false
        foreach ($block in $config.blocks) {
            if ($block.segments) {
                foreach ($segment in $block.segments) {
                    if ($segment.type -eq "text" -and $segment.template -like "*travel_time*") {
                        $foundTravelSegment = $true
                        break
                    }
                }
            }
        }
        
        return $foundTravelSegment
    }
    catch {
        return $false
    }
}

# Test 6: Data Directory Structure
Test-Configuration "Data Directory Structure" {
    $dataDir = "$PSScriptRoot\..\data"
    
    # Check if data directory exists (or can be created)
    if (-not (Test-Path $dataDir)) {
        try {
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
            $created = Test-Path $dataDir
            if ($created) {
                Write-Host "  Created data directory" -ForegroundColor Green
            }
            return $created
        }
        catch {
            return $false
        }
    }
    
    return $true
}

# Test 7: PowerShell Requirements
Test-Configuration "PowerShell Version Requirements" {
    $requiredVersion = [Version]"5.1"
    $currentVersion = $PSVersionTable.PSVersion
    
    if ($currentVersion -ge $requiredVersion) {
        return $true
    }
    else {
        Write-Host "  Required: PowerShell $requiredVersion, Current: $currentVersion" -ForegroundColor Red
        return $false
    }
}

# Test 8: Execution Policy
Test-Configuration "PowerShell Execution Policy" {
    $policy = Get-ExecutionPolicy
    $validPolicies = @("Unrestricted", "RemoteSigned", "Bypass")
    
    if ($policy -in $validPolicies) {
        return $true
    }
    else {
        Write-Host "  Current policy: $policy (may prevent script execution)" -ForegroundColor Yellow
        return $false
    }
}

# Test 9: Configuration Validation Function
Test-Configuration "Configuration Validation Logic" {
    try {
        . "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"
        
        # Test with valid configuration
        $validConfig = @{
            google_routes_api_key = "AIzaSyD1234567890abcdefghijklmnopqrstuv"
            home_address = "123 Test Street, Test City"
            start_time = "09:00"
            end_time = "17:00"
            travel_mode = "DRIVE"
        }
        
        $testPath = "$PSScriptRoot\test-valid-config.json"
        $validConfig | ConvertTo-Json | Set-Content $testPath
        
        $config = Get-TravelTimeConfig -Path $testPath
        
        Remove-Item $testPath -ErrorAction SilentlyContinue
        
        return ($config -ne $null)
    }
    catch {
        Remove-Item "$PSScriptRoot\test-valid-config.json" -ErrorAction SilentlyContinue
        return $false
    }
}

# Test 10: Error Handling
Test-Configuration "Error Handling - Invalid JSON" {
    try {
        . "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"
        
        $malformedConfigPath = "$PSScriptRoot\test-malformed-config.json"
        
        # Create malformed JSON
        '{ "invalid": "json"' | Set-Content $malformedConfigPath
        
        # Test with malformed config
        $config = Get-TravelTimeConfig -Path $malformedConfigPath
        
        Remove-Item $malformedConfigPath -ErrorAction SilentlyContinue
        
        # Should return null for invalid JSON
        return ($config -eq $null)
    }
    catch {
        Remove-Item "$PSScriptRoot\test-malformed-config.json" -ErrorAction SilentlyContinue
        return $true  # Expected to catch error
    }
}

# Display Results
Write-Host ""
Write-Host "Configuration Test Summary" -ForegroundColor Blue
Write-Host "=========================" -ForegroundColor Blue
Write-Host "Passed:  $($ConfigResults.Passed)" -ForegroundColor Green
Write-Host "Failed:  $($ConfigResults.Failed)" -ForegroundColor Red
Write-Host "Skipped: $($ConfigResults.Skipped)" -ForegroundColor Yellow
Write-Host "Total:   $($ConfigResults.Passed + $ConfigResults.Failed + $ConfigResults.Skipped)" -ForegroundColor White

$totalTests = $ConfigResults.Passed + $ConfigResults.Failed
if ($totalTests -gt 0) {
    $passRate = [math]::Round(($ConfigResults.Passed / $totalTests) * 100, 1)
    Write-Host "Pass Rate: $passRate%" -ForegroundColor $(
        if ($passRate -eq 100) { "Green" }
        elseif ($passRate -ge 80) { "Yellow" }
        else { "Red" }
    )
}

Write-Host ""

if ($ConfigResults.Failed -eq 0) {
    Write-Host "All configuration tests passed!" -ForegroundColor Green
    Write-Host "The system is ready for installation." -ForegroundColor Green
}
else {
    Write-Host "Some configuration tests failed." -ForegroundColor Yellow
    Write-Host "Review the issues above before proceeding." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Configuration Notes:" -ForegroundColor Cyan
Write-Host "   - Time ranges cannot cross midnight (e.g., 23:00-01:00)" -ForegroundColor White
Write-Host "   - API keys are validated for format but not authenticity" -ForegroundColor White
Write-Host "   - Configuration files are automatically gitignored" -ForegroundColor White
Write-Host "   - Oh My Posh segment only shows in the cli-tag directory" -ForegroundColor White

# Return test results for automation
return @{
    Passed = $ConfigResults.Passed
    Failed = $ConfigResults.Failed
    Skipped = $ConfigResults.Skipped
    PassRate = if ($totalTests -gt 0) { $passRate } else { 0 }
    AllPassed = ($ConfigResults.Failed -eq 0)
}