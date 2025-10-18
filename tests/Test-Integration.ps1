#Requires -Version 5.1

<#
.SYNOPSIS
    Integration tests for the Travel Time system.

.DESCRIPTION
    This script tests the interaction between components and validates
    the complete system workflow.
#>

param(
    [string]$TestApiKey = $null,
    [switch]$Verbose = $false
)

# Set up test environment
$ErrorActionPreference = "Continue"

# Test results tracking
$IntegrationResults = @{
    Passed = 0
    Failed = 0
    Skipped = 0
    Tests = @()
}

function Test-Integration {
    param([string]$Name, [scriptblock]$TestCode, [bool]$Skip = $false)
    
    Write-Host "Testing: $Name" -ForegroundColor Cyan
    
    if ($Skip) {
        Write-Host "  SKIPPED" -ForegroundColor Yellow
        $IntegrationResults.Skipped++
        $IntegrationResults.Tests += @{ Name = $Name; Passed = $false; Skipped = $true }
        return
    }
    
    try {
        $result = & $TestCode
        if ($result) {
            Write-Host "  PASSED" -ForegroundColor Green
            $IntegrationResults.Passed++
            $IntegrationResults.Tests += @{ Name = $Name; Passed = $true; Skipped = $false }
        }
        else {
            Write-Host "  Failed" -ForegroundColor Red
            $IntegrationResults.Failed++
            $IntegrationResults.Tests += @{ Name = $Name; Passed = $false; Skipped = $false }
        }
    }
    catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $IntegrationResults.Failed++
        $IntegrationResults.Tests += @{ Name = $Name; Passed = $false; Skipped = $false; Error = $_.Exception.Message }
    }
}

Write-Host "Travel Time Integration Tests" -ForegroundColor Blue
Write-Host "=============================" -ForegroundColor Blue
Write-Host ""

# Test 1: File Structure
Test-Integration "Project Directory Structure" {
    $projectDir = Split-Path $PSScriptRoot -Parent
    $requiredPaths = @(
        "$projectDir\scripts",
        "$projectDir\scripts\config",
        "$projectDir\data",
        "$projectDir\scripts\TravelTimeUpdater.ps1",
        "$projectDir\scripts\Install-TravelTimeService.ps1",
        "$projectDir\scripts\config\travel-config.json.template"
    )

    foreach ($path in $requiredPaths) {
        if (-not (Test-Path $path)) {
            Write-Host "  Missing: $path" -ForegroundColor Red
            return $false
        }
    }
    return $true
}

# Test 2: Script Syntax Validation
Test-Integration "PowerShell Script Syntax" {
    $scripts = @(
        "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1",
        "$PSScriptRoot\..\scripts\Install-TravelTimeService.ps1"
    )

    foreach ($script in $scripts) {
        try {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script -Raw), [ref]$null)
        }
        catch {
            Write-Host "  Syntax error in $script`: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    return $true
}

# Test 3: Configuration Template
Test-Integration "Configuration Template Validation" {
    $templatePath = "$PSScriptRoot\..\scripts\config\travel-config.json.template"
    try {
        $template = Get-Content $templatePath | ConvertFrom-Json
        $requiredKeys = @("google_routes_api_key", "home_address", "start_time", "end_time", "travel_mode")

        foreach ($key in $requiredKeys) {
            if (-not $template.PSObject.Properties.Name.Contains($key)) {
                Write-Host "  Missing required key: $key" -ForegroundColor Red
                return $false
            }
        }
        return $true
    }
    catch {
        Write-Host "  Invalid JSON in template: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Test 4: Mock Configuration Test
Test-Integration "Test Configuration Creation" {
    $testConfigPath = "$PSScriptRoot\integration-test-config.json"
    try {
        $testConfig = @{
            google_routes_api_key = "TEST_KEY_123"
            home_address = "123 Test Street, Test City"
            update_interval_minutes = 5
            start_time = "15:00"
            end_time = "23:00"
            travel_mode = "DRIVE"
            routing_preference = "TRAFFIC_AWARE"
            units = "METRIC"
        }

        $testConfig | ConvertTo-Json | Set-Content $testConfigPath

        # Test if we can read it back
        . "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"
        $config = Get-TravelTimeConfig -Path $testConfigPath

        $success = ($config -ne $null -and $config.google_routes_api_key -eq "TEST_KEY_123")

        # Clean up
        Remove-Item $testConfigPath -ErrorAction SilentlyContinue

        return $success
    }
    catch {
        Remove-Item $testConfigPath -ErrorAction SilentlyContinue
        return $false
    }
}

# Test 5: Data File Integration
Test-Integration "Data File Read/Write" {
    $testDataPath = "$PSScriptRoot\integration-test-data.json"
    try {
        # Create test data structure
        $testData = @{
            last_updated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            travel_time_minutes = 30
            distance_km = 20.5
            traffic_status = "moderate"
            travel_mode = "DRIVE"
            error = $null
            is_active_hours = $true
            active_period = "15:00 - 23:00"
        }

        # Write data
        $testData | ConvertTo-Json | Set-Content $testDataPath

        # Read data back
        $readData = Get-Content $testDataPath | ConvertFrom-Json

        $success = ($readData.travel_time_minutes -eq 30 -and $readData.traffic_status -eq "moderate")

        # Clean up
        Remove-Item $testDataPath -ErrorAction SilentlyContinue

        return $success
    }
    catch {
        Remove-Item $testDataPath -ErrorAction SilentlyContinue
        return $false
    }
}

# Test 6: Oh My Posh Configuration
Test-Integration "Oh My Posh Configuration" {
    $ompConfigPath = "$PSScriptRoot\..\new_config.omp.json"
    try {
        $config = Get-Content $ompConfigPath | ConvertFrom-Json

        # Check for travel time segment
        $hasBlocks = $config.blocks -ne $null
        $hasSegments = $config.blocks[0].segments -ne $null

        # Look for travel time template
        $hasTravelTimeTemplate = $false
        foreach ($segment in $config.blocks[0].segments) {
            if ($segment.template -and $segment.template -like "*travel_time*") {
                $hasTravelTimeTemplate = $true
                break
            }
        }

        return ($hasBlocks -and $hasTravelTimeTemplate)
    }
    catch {
        Write-Host "  Invalid JSON in Oh My Posh config: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Test 7: Function Dependencies
Test-Integration "Function Dependencies" {
    try {
        . "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"

        # Test that all required functions exist
        $requiredFunctions = @(
            "Get-TravelTimeConfig",
            "Test-ActiveHours",
            "Get-CurrentLocation",
            "Get-TravelTimeRoutes",
            "Update-TravelTimeData"
        )

        foreach ($func in $requiredFunctions) {
            if (-not (Get-Command $func -ErrorAction SilentlyContinue)) {
                Write-Host "  Missing function: $func" -ForegroundColor Red
                return $false
            }
        }
        return $true
    }
    catch {
        Write-Host "  Error loading functions: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Test 8: API Connectivity (Optional)
$skipApiTest = [string]::IsNullOrWhiteSpace($TestApiKey)
Test-Integration "Google Routes API Connectivity" {
    try {
        . "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"

        # Test with known coordinates (Google HQ to test address)
        $result = Get-TravelTimeRoutes -ApiKey $TestApiKey -OriginLat 37.4220656 -OriginLng -122.0840897 -Destination "1600 Amphitheatre Parkway, Mountain View, CA"
        
        if ($result.Success) {
            Write-Host "  API Response: $($result.TravelTimeMinutes) minutes" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "  API Error: $($result.ErrorMessage)" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "  API Exception: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} $skipApiTest

# Display Results
Write-Host ""
Write-Host "Integration Test Summary" -ForegroundColor Blue
Write-Host "=======================" -ForegroundColor Blue
Write-Host "- Passed:  $($IntegrationResults.Passed)" -ForegroundColor Green
Write-Host "- Failed:  $($IntegrationResults.Failed)" -ForegroundColor Red
Write-Host "- Skipped: $($IntegrationResults.Skipped)" -ForegroundColor Yellow
Write-Host "- Total:   $($IntegrationResults.Passed + $IntegrationResults.Failed + $IntegrationResults.Skipped)" -ForegroundColor White

$totalTests = $IntegrationResults.Passed + $IntegrationResults.Failed
if ($totalTests -gt 0) {
    $passRate = [math]::Round(($IntegrationResults.Passed / $totalTests) * 100, 1)
    Write-Host "- Pass Rate: $passRate%" -ForegroundColor $(
        if ($passRate -eq 100) { "Green" }
        elseif ($passRate -ge 80) { "Yellow" }
        else { "Red" }
    )
}

Write-Host ""

if ($IntegrationResults.Failed -eq 0) {
    Write-Host "All integration tests passed!" -ForegroundColor Green
    if ($IntegrationResults.Skipped -gt 0) {
        Write-Host "Note: Some tests were skipped (API tests require a valid API key)" -ForegroundColor Yellow
    }
}
else {
    Write-Host "Some tests failed. Review the issues above." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "   1. Review any failed tests above" -ForegroundColor White
Write-Host "   2. Run configuration tests with: .\Test-Configuration.ps1" -ForegroundColor White
Write-Host "   3. Get a Google Routes API key for full testing" -ForegroundColor White
Write-Host "   4. If all tests pass, proceed with installation" -ForegroundColor White

# Return results for automation
return @{
    Passed = $IntegrationResults.Passed
    Failed = $IntegrationResults.Failed
    Skipped = $IntegrationResults.Skipped
    PassRate = if ($totalTests -gt 0) { $passRate } else { 0 }
    AllPassed = ($IntegrationResults.Failed -eq 0)
}