#Requires -Version 5.1

<#
.SYNOPSIS
    Tests for the enhanced logging functionality in TravelTimeUpdater.ps1.

.DESCRIPTION
    This script tests the new logging framework, log levels, and file output
    to ensure the enhanced logging meets all requirements.
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

Write-Host "Enhanced Logging Tests" -ForegroundColor Blue
Write-Host "======================" -ForegroundColor Blue
Write-Host ""

# Test 1: LogLevel Parameter Validation
Test-Function "LogLevel Parameter - Valid Values" {
    try {
        $scriptPath = "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"
        
        # Test valid log levels
        $validLevels = @("Error", "Warning", "Information", "Debug")
        $allValid = $true
        
        foreach ($level in $validLevels) {
            $output = & pwsh -File $scriptPath -LogLevel $level -WhatIf 2>&1
            if ($LASTEXITCODE -ne 0) {
                $allValid = $false
                break
            }
        }
        
        return $allValid
    }
    catch {
        return $false
    }
}

# Test 2: Information Level Output
Test-Function "Information Level - Appropriate Output" {
    try {
        $scriptPath = "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"
        $output = & pwsh -File $scriptPath -LogLevel Information 2>&1 | Out-String
        
        # Should contain key information level messages
        $hasStartMessage = $output -match "TravelTimeUpdater script started"
        $hasCycleMessage = $output -match "Starting travel time update cycle"
        $hasCompletionMessage = $output -match "completed successfully"
        
        return ($hasStartMessage -and $hasCycleMessage -and $hasCompletionMessage)
    }
    catch {
        return $false
    }
}

# Test 3: Debug Level Verbosity
Test-Function "Debug Level - Comprehensive Output" {
    try {
        $scriptPath = "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"
        $output = & pwsh -File $scriptPath -LogLevel Debug 2>&1 | Out-String
        
        # Should contain debug messages for all major operations
        $hasConfigDebug = $output -match "\[DEBUG\].*\[Configuration\]"
        $hasTimeCheckDebug = $output -match "\[DEBUG\].*\[TimeCheck\]"
        $hasFileOpDebug = $output -match "\[DEBUG\].*\[FileOperation\]"
        $hasDataProcessDebug = $output -match "\[DEBUG\].*\[DataProcessing\]"
        
        return ($hasConfigDebug -and $hasTimeCheckDebug -and $hasFileOpDebug -and $hasDataProcessDebug)
    }
    catch {
        return $false
    }
}

# Test 4: Error Level Filtering
Test-Function "Error Level - Minimal Output" {
    try {
        $scriptPath = "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"
        $output = & pwsh -File $scriptPath -LogLevel Error 2>&1 | Out-String
        
        # Should have no output for successful execution with Error level
        return ($output.Trim() -eq "")
    }
    catch {
        return $false
    }
}

# Test 5: Log File Output
Test-Function "Log File - Output Creation" {
    try {
        $scriptPath = "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"
        $testLogPath = "$PSScriptRoot\test-log.log"
        
        # Clean up any existing test log
        if (Test-Path $testLogPath) {
            Remove-Item $testLogPath -Force
        }
        
        # Run with log file output
        & pwsh -File $scriptPath -LogLevel Information -LogPath $testLogPath 2>&1 | Out-Null
        
        # Check if log file was created and has content
        $logExists = Test-Path $testLogPath
        $hasContent = $false
        
        if ($logExists) {
            $content = Get-Content $testLogPath -Raw
            $hasContent = ($content.Length -gt 0) -and ($content -match "TravelTimeUpdater script started")
        }
        
        # Clean up
        if (Test-Path $testLogPath) {
            Remove-Item $testLogPath -Force
        }
        
        return ($logExists -and $hasContent)
    }
    catch {
        return $false
    }
}

# Test 6: Correlation ID Tracking
Test-Function "Correlation ID - Consistent Tracking" {
    try {
        $scriptPath = "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"
        $output = & pwsh -File $scriptPath -LogLevel Debug 2>&1 | Out-String
        
        # Extract correlation IDs from the output
        $correlationIds = [regex]::Matches($output, '\[([a-f0-9]{8})\]') | ForEach-Object { $_.Groups[1].Value }
        
        # All correlation IDs should be the same
        $uniqueIds = $correlationIds | Sort-Object -Unique
        return ($uniqueIds.Count -eq 1)
    }
    catch {
        return $false
    }
}

# Test 7: Structured Logging Format
Test-Function "Structured Format - Consistent Pattern" {
    try {
        $scriptPath = "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"
        $output = & pwsh -File $scriptPath -LogLevel Debug 2>&1 | Out-String
        
        # Check that all log lines follow the expected format
        $lines = $output -split "`n" | Where-Object { $_.Trim() -ne "" }
        $allFormatted = $true
        
        foreach ($line in $lines) {
            # Expected format: [timestamp] [LEVEL] [correlation-id] [category] message
            if ($line -notmatch '^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\] \[(ERROR|WARNING|INFORMATION|DEBUG)\] \[[a-f0-9]{8}\] \[[^\]]+\]') {
                $allFormatted = $false
                break
            }
        }
        
        return $allFormatted
    }
    catch {
        return $false
    }
}

# Test 8: No Sensitive Information
Test-Function "Security - No API Keys in Logs" {
    try {
        $scriptPath = "$PSScriptRoot\..\scripts\TravelTimeUpdater.ps1"
        $output = & pwsh -File $scriptPath -LogLevel Debug 2>&1 | Out-String
        
        # Should not contain the full API key (only masked version)
        $hasFullApiKey = $output -match "TEST_API_KEY_FOR_DEMO"
        $hasMaskedApiKey = $output -match "TEST_API\*\*\*"
        
        return (-not $hasFullApiKey)
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
    Write-Host "All logging tests passed!" -ForegroundColor Green
}
else {
    Write-Host "Some logging tests failed. Review the issues above." -ForegroundColor Yellow
}

# Return test results for automation
return @{
    Passed = $TestResults.Passed
    Failed = $TestResults.Failed
    Skipped = 0
    PassRate = if ($totalTests -gt 0) { $passRate } else { 0 }
    AllPassed = ($TestResults.Failed -eq 0)
}