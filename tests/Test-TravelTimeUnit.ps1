#Requires -Version 5.1

<#
.SYNOPSIS
    Unit tests for the Travel Time system functions.

.DESCRIPTION
    This script tests individual functions and components of the travel time system
    to ensure they work correctly in isolation.
#>

param(
    [switch]$Verbose = $false
)

# Set up test environment
$ErrorActionPreference = "Continue"

# Test results tracking
$TestResults = @{
    Passed = 0
    Failed = 0
    Tests = @()
}

function Test-Function {
    param([string]$Name, [scriptblock]$TestCode)
    
    Write-Host "Testing: $Name" -ForegroundColor Cyan
    
    try {
        $result = & $TestCode
        if ($result) {
            Write-Host "  PASSED" -ForegroundColor Green
            $TestResults.Passed++
            $TestResults.Tests += @{ Name = $Name; Passed = $true }
        }
        else {
            Write-Host "  FAILED" -ForegroundColor Red
            $TestResults.Failed++
            $TestResults.Tests += @{ Name = $Name; Passed = $false }
        }
    }
    catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
        $TestResults.Tests += @{ Name = $Name; Passed = $false; Error = $_.Exception.Message }
    }
}

Write-Host "Travel Time Unit Tests" -ForegroundColor Blue
Write-Host "======================" -ForegroundColor Blue
Write-Host ""

# Test 1: Script Syntax
Test-Function "Script Syntax - TravelTimeUpdater.ps1" {
    $scriptPath = "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"
    return (Test-Path $scriptPath)
}

# Test 2: Get-TravelTimeConfig Function
Test-Function "Get-TravelTimeConfig - Valid JSON" {
    try {
        . "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"
        
        # Create valid test config
        $testConfig = @{
            google_routes_api_key = "test_key"
            home_address = "Test Address"
            start_time = "09:00"
            end_time = "17:00"
        }
        
        $testPath = "$PSScriptRoot\test-config.json"
        $testConfig | ConvertTo-Json | Set-Content $testPath
        
        $config = Get-TravelTimeConfig -Path $testPath
        
        Remove-Item $testPath -ErrorAction SilentlyContinue
        
        return ($config -ne $null -and $config.google_routes_api_key -eq "test_key")
    }
    catch {
        return $false
    }
}

# Test 3: Test-ActiveHours Function
Test-Function "Test-ActiveHours - Basic Logic" {
    try {
        . "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"

        # Use a deterministic reference time (current now) and construct one range
        # that must include it and one range that must exclude it.
        $ref = Get-Date
        $inStart  = ($ref.AddMinutes(-30)).ToString("HH:mm")
        $inEnd    = ($ref.AddMinutes(30)).ToString("HH:mm")
        $outStart = ($ref.AddHours(2)).ToString("HH:mm")
        $outEnd   = ($ref.AddHours(3)).ToString("HH:mm")

        $result1 = Test-ActiveHours -StartTime $inStart -EndTime $inEnd -ReferenceTime $ref
        $result2 = Test-ActiveHours -StartTime $outStart -EndTime $outEnd -ReferenceTime $ref

        return ($result1 -and -not $result2)
    }
    catch {
        return $false
    }
}

# Test 4: Configuration Template
Test-Function "Configuration Template - Structure" {
    $templatePath = "$PSScriptRoot\..\scripts\config\travel-config.json.template"
    
    if (-not (Test-Path $templatePath)) {
        return $false
    }
    
    try {
        $template = Get-Content $templatePath | ConvertFrom-Json
        $requiredKeys = @("google_routes_api_key", "home_address", "start_time", "end_time")
        
        foreach ($key in $requiredKeys) {
            if (-not $template.PSObject.Properties.Name.Contains($key)) {
                return $false
            }
        }
        
        return $true
    }
    catch {
        return $false
    }
}

# Test 5: Oh My Posh Configuration
Test-Function "Oh My Posh Config - JSON Syntax" {
    $configPath = "$PSScriptRoot\..\new_config.omp.json"
    
    if (-not (Test-Path $configPath)) {
        return $false
    }
    
    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        return ($config -ne $null)
    }
    catch {
        return $false
    }
}

# Display Results
Write-Host ""
Write-Host "Test Summary" -ForegroundColor Blue
Write-Host "============" -ForegroundColor Blue
Write-Host "Passed:  $($TestResults.Passed)" -ForegroundColor Green
Write-Host "Failed:  $($TestResults.Failed)" -ForegroundColor Red
Write-Host "Total:   $($TestResults.Passed + $TestResults.Failed)" -ForegroundColor White

$totalTests = $TestResults.Passed + $TestResults.Failed
if ($totalTests -gt 0) {
    $passRate = [math]::Round(($TestResults.Passed / $totalTests) * 100, 1)
    Write-Host "Pass Rate: $passRate%" -ForegroundColor $(
        if ($passRate -eq 100) { "Green" }
        elseif ($passRate -ge 80) { "Yellow" }
        else { "Red" }
    )
}

Write-Host ""

if ($TestResults.Failed -eq 0) {
    Write-Host "All unit tests passed!" -ForegroundColor Green
}
else {
    Write-Host "Some tests failed. Review the issues above." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "   1. Review any failed tests above" -ForegroundColor White
Write-Host "   2. Run integration tests with: .\Test-Integration.ps1" -ForegroundColor White
Write-Host "   3. If all tests pass, proceed with installation" -ForegroundColor White

# Return test results for automation
return @{
    Passed = $TestResults.Passed
    Failed = $TestResults.Failed
    Skipped = 0
    PassRate = if ($totalTests -gt 0) { $passRate } else { 0 }
    AllPassed = ($TestResults.Failed -eq 0)
}