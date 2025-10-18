#Requires -Version 5.1

<#
.SYNOPSIS
    Comprehensive test runner for the Oh My Posh Travel Time system.

.DESCRIPTION
    This script runs all test suites and provides a comprehensive report
    on the system's readiness for deployment.

.PARAMETER TestApiKey
    Optional Google Routes API key for testing actual API connectivity.

.PARAMETER SkipApiTests
    Skip API connectivity tests (useful for offline testing).

.PARAMETER Verbose
    Enable detailed output for all tests.

.EXAMPLE
    .\Run-AllTests.ps1
    
.EXAMPLE
    .\Run-AllTests.ps1 -TestApiKey "YOUR_API_KEY"
    
.EXAMPLE
    .\Run-AllTests.ps1 -SkipApiTests -Verbose
#>

param(
    [string]$TestApiKey = $null,
    [switch]$SkipApiTests = $false
)

# Set up test environment
$ErrorActionPreference = "Continue"
$TestStartTime = Get-Date

# Test suite tracking
$TestSuites = @{
    Unit = @{ Name = "Unit Tests"; Script = "Test-TravelTimeUnit.ps1"; Status = "Pending"; Results = $null }
    Integration = @{ Name = "Integration Tests"; Script = "Test-Integration.ps1"; Status = "Pending"; Results = $null }
    Configuration = @{ Name = "Configuration Tests"; Script = "Test-Configuration.ps1"; Status = "Pending"; Results = $null }
    Uninstaller = @{ Name = "Uninstaller Tests"; Script = "Test-Uninstaller.ps1"; Status = "Pending"; Results = $null }
}

$OverallResults = @{
    TotalPassed = 0
    TotalFailed = 0
    TotalSkipped = 0
    SuitesRun = 0
    SuitesFailed = 0
    StartTime = $TestStartTime
    EndTime = $null
    Duration = $null
}

# Helper functions
function Write-TestHeader {
    param([string]$Title, [string]$Color = "Yellow")
    
    $border = "=" * 64
    Write-Host ""
    Write-Host "+$border+" -ForegroundColor $Color
    $totalPadding = 64 - $Title.Length
    $leftPadding = [int]($totalPadding / 2)
    $rightPadding = $totalPadding - $leftPadding
    Write-Host "|$(' ' * $leftPadding)$Title$(' ' * $rightPadding)|" -ForegroundColor $Color
    Write-Host "+$border+" -ForegroundColor $Color
    Write-Host ""
}

function Write-SuiteStatus {
    param([string]$Suite, [string]$Status, [string]$Color = "White")
    
    $padding = 20 - $Suite.Length
    Write-Host "Test Suite: $Suite$(' ' * $padding) [$Status]" -ForegroundColor $Color
}

function Invoke-TestSuite {
    param(
        [string]$SuiteName,
        [hashtable]$SuiteInfo,
        [hashtable]$Parameters = @{}
    )
    
    Write-Host ""
    Write-Host "Running $($SuiteInfo.Name)..." -ForegroundColor Cyan
    Write-Host "Script: $($SuiteInfo.Script)" -ForegroundColor Gray
    Write-Host ""
    
    $scriptPath = Join-Path $PSScriptRoot $SuiteInfo.Script
    
    if (-not (Test-Path $scriptPath)) {
        Write-Host "ERROR: Test script not found: $scriptPath" -ForegroundColor Red
        $SuiteInfo.Status = "Missing"
        $OverallResults.SuitesFailed++
        return
    }
    
    try {
        $startTime = Get-Date
        
        # Execute test script with parameters
        if ($Parameters.Count -gt 0) {
            $results = & $scriptPath @Parameters
        }
        else {
            $results = & $scriptPath
        }
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        if ($results -and $results.GetType().Name -eq "Hashtable") {
            $SuiteInfo.Results = $results
            $SuiteInfo.Results.Duration = $duration
            
            if ($results.AllPassed) {
                $SuiteInfo.Status = "PASSED"
                Write-Host "Suite completed successfully" -ForegroundColor Green
            }
            else {
                $SuiteInfo.Status = "FAILED"
                Write-Host "Suite completed with failures" -ForegroundColor Red
                $OverallResults.SuitesFailed++
            }
            
            # Accumulate results
            $OverallResults.TotalPassed += $results.Passed
            $OverallResults.TotalFailed += $results.Failed
            if ($results.Skipped) {
                $OverallResults.TotalSkipped += $results.Skipped
            }
        }
        else {
            $SuiteInfo.Status = "UNKNOWN"
            Write-Host "Suite completed but returned unexpected results" -ForegroundColor Yellow
            $OverallResults.SuitesFailed++
        }
        
        $OverallResults.SuitesRun++
        
        Write-Host "Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Gray
    }
    catch {
        $SuiteInfo.Status = "ERROR"
        $SuiteInfo.Results = @{ Error = $_.Exception.Message }
        Write-Host "Suite failed with error: $($_.Exception.Message)" -ForegroundColor Red
        $OverallResults.SuitesFailed++
        $OverallResults.SuitesRun++
    }
}

# Main execution
Write-TestHeader "Travel Time System Test Runner" "Blue"

Write-Host "Initializing test environment..." -ForegroundColor Cyan
Write-Host "Test Directory: $PSScriptRoot" -ForegroundColor Gray
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "Execution Policy: $(Get-ExecutionPolicy)" -ForegroundColor Gray

if ($TestApiKey) {
    Write-Host "API Testing: Enabled (key provided)" -ForegroundColor Green
}
elseif ($SkipApiTests) {
    Write-Host "API Testing: Disabled (skipped)" -ForegroundColor Yellow
}
else {
    Write-Host "API Testing: Limited (no key provided)" -ForegroundColor Yellow
}

Write-Host ""

# Pre-flight checks
Write-Host "Running pre-flight checks..." -ForegroundColor Cyan

$preflightPassed = $true

# Check if required scripts exist
foreach ($suiteName in $TestSuites.Keys) {
    $scriptPath = Join-Path $PSScriptRoot $TestSuites[$suiteName].Script
    if (-not (Test-Path $scriptPath)) {
        Write-Host "Missing test script: $($TestSuites[$suiteName].Script)" -ForegroundColor Red
        $preflightPassed = $false
    }
    else {
        Write-Host "Found test script: $($TestSuites[$suiteName].Script)" -ForegroundColor Green
    }
}

# Check if main scripts exist
$mainScripts = @(
    "..\scripts\TravelTimeUpdater.ps1",
    "..\scripts\Install-TravelTimeService.ps1",
    "..\scripts\Uninstall-TravelTimeService.ps1",
    "..\new_config.omp.json"
)

foreach ($script in $mainScripts) {
    $scriptPath = Join-Path $PSScriptRoot $script
    if (-not (Test-Path $scriptPath)) {
        Write-Host "Missing main file: $(Split-Path $script -Leaf)" -ForegroundColor Red
        $preflightPassed = $false
    }
    else {
        Write-Host "Found main file: $(Split-Path $script -Leaf)" -ForegroundColor Green
    }
}

if (-not $preflightPassed) {
    Write-Host ""
    Write-Host "Pre-flight checks failed. Cannot proceed with testing." -ForegroundColor Red
    exit 1
}

Write-Host "All pre-flight checks passed" -ForegroundColor Green

# Run test suites
Write-TestHeader "Executing Test Suites" "Green"

# 1. Unit Tests
Invoke-TestSuite "Unit" $TestSuites.Unit

# 2. Integration Tests  
$integrationParams = @{}
if ($TestApiKey -and -not $SkipApiTests) {
    $integrationParams.TestApiKey = $TestApiKey
}
Invoke-TestSuite "Integration" $TestSuites.Integration $integrationParams

# 3. Configuration Tests
Invoke-TestSuite "Configuration" $TestSuites.Configuration

# 4. Uninstaller Tests
Invoke-TestSuite "Uninstaller" $TestSuites.Uninstaller

# Calculate final results
$OverallResults.EndTime = Get-Date
$OverallResults.Duration = $OverallResults.EndTime - $OverallResults.StartTime

# Display summary
Write-TestHeader "Test Execution Complete" "Blue"

Write-Host "Overall Test Results:" -ForegroundColor Cyan
Write-Host ""

foreach ($suiteName in $TestSuites.Keys) {
    Write-SuiteStatus $TestSuites[$suiteName].Name $TestSuites[$suiteName].Status $(
        if ($TestSuites[$suiteName].Status -eq "PASSED") { "Green" }
        elseif ($TestSuites[$suiteName].Status -eq "FAILED") { "Red" }
        else { "Yellow" }
    )
}

Write-Host ""
Write-Host "Summary Statistics:" -ForegroundColor Cyan
Write-Host "Total Passed:  $($OverallResults.TotalPassed)" -ForegroundColor Green
Write-Host "Total Failed:  $($OverallResults.TotalFailed)" -ForegroundColor Red
Write-Host "Total Skipped: $($OverallResults.TotalSkipped)" -ForegroundColor Yellow
Write-Host "Total Tests:   $($OverallResults.TotalPassed + $OverallResults.TotalFailed + $OverallResults.TotalSkipped)" -ForegroundColor White
Write-Host "Duration:      $($OverallResults.Duration.ToString('mm\:ss'))" -ForegroundColor White

$totalTests = $OverallResults.TotalPassed + $OverallResults.TotalFailed
if ($totalTests -gt 0) {
    $passRate = [math]::Round(($OverallResults.TotalPassed / $totalTests) * 100, 1)
    Write-Host "Pass Rate:     $passRate%" -ForegroundColor $(
        if ($passRate -eq 100) { "Green" }
        elseif ($passRate -ge 80) { "Yellow" }
        else { "Red" }
    )
}

Write-Host ""

# Final recommendation
if ($OverallResults.SuitesFailed -eq 0 -and $OverallResults.TotalFailed -eq 0) {
    Write-Host "All tests passed! The Travel Time system is ready for deployment." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Get your Google Routes API key" -ForegroundColor White
    Write-Host "2. Run: .\scripts\Install-TravelTimeService.ps1" -ForegroundColor White
    Write-Host "3. Reload your PowerShell profile" -ForegroundColor White
    $exitCode = 0
}
else {
    Write-Host "Some tests failed. Review the issues before deployment." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Recommendations:" -ForegroundColor Cyan
    Write-Host "1. Review failed test details above" -ForegroundColor White
    Write-Host "2. Fix any identified issues" -ForegroundColor White
    Write-Host "3. Re-run tests before installation" -ForegroundColor White
    $exitCode = 1
}

Write-Host ""
Write-Host "Test execution completed." -ForegroundColor Blue

# Return results for automation
return @{
    Passed = $OverallResults.TotalPassed
    Failed = $OverallResults.TotalFailed
    Skipped = $OverallResults.TotalSkipped
    SuitesRun = $OverallResults.SuitesRun
    SuitesFailed = $OverallResults.SuitesFailed
    PassRate = if ($totalTests -gt 0) { $passRate } else { 0 }
    AllPassed = ($OverallResults.SuitesFailed -eq 0 -and $OverallResults.TotalFailed -eq 0)
    Duration = $OverallResults.Duration
    ExitCode = $exitCode
}