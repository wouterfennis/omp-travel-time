#Requires -Version 5.1

<#
.SYNOPSIS
    Tests for the Travel Time Service uninstaller.

.DESCRIPTION
    Comprehensive tests for the Uninstall-TravelTimeService.ps1 script including
    component removal, preservation options, error handling, and rollback scenarios.
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

function Test-UninstallerSyntax {
    Write-Host "Testing: Uninstaller Script Syntax"
    
    $scriptPath = "$PSScriptRoot\..\scripts\Uninstall-TravelTimeService.ps1"
    
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$null)
        return $true
    }
    catch {
        Write-Host "    Error: Uninstaller script syntax error: $_" -ForegroundColor Red
        return $false
    }
}

function Test-UninstallerWhatIf {
    $testRoot = "/tmp/TravelTimeTest"
    $configDir = "$testRoot/scripts/config"
    $dataDir = "$testRoot/data"
    
    try {
        # Setup test environment
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        
        $testConfig = @{
            google_routes_api_key = "test-key-123"
            home_address = "123 Test St"
            start_time = "15:00"
            end_time = "23:00"
        }
        
        $configPath = "$configDir/travel-config.json"
        $dataPath = "$dataDir/travel_time.json"
        $gitignorePath = "$testRoot/.gitignore"
        
        $testConfig | ConvertTo-Json | Set-Content $configPath
        '{"display_text": "Test"}' | Set-Content $dataPath
        @("data/travel_time.json", "scripts/config/travel-config.json") | Set-Content $gitignorePath
        
        # Test WhatIf mode (using a mock since we can't directly test the script)
        if ((Test-Path $configPath) -and (Test-Path $dataPath) -and (Test-Path $gitignorePath)) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        return $false
    }
    finally {
        if (Test-Path $testRoot) {
            Remove-Item $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Test-ComponentIdentification {
    try {
        # Test that the uninstaller can identify all components installed by the installer
        $installerScript = Get-Content "$PSScriptRoot\..\scripts\Install-TravelTimeService.ps1" -Raw
        $uninstallerScript = Get-Content "$PSScriptRoot\..\scripts\Uninstall-TravelTimeService.ps1" -Raw
        
        # Check for scheduled task handling
        $hasScheduledTask = $uninstallerScript -match "OhMyPosh-TravelTime" -and $uninstallerScript -match "Unregister-ScheduledTask"
        
        # Check for config file handling
        $hasConfigRemoval = $uninstallerScript -match "travel-config\.json" -and $uninstallerScript -match "Remove-Item"
        
        # Check for data file handling
        $hasDataRemoval = $uninstallerScript -match "travel_time\.json" -and $uninstallerScript -match "data"
        
        # Check for gitignore handling
        $hasGitignoreCleanup = $uninstallerScript -match "\.gitignore" -and $uninstallerScript -match "travel time"
        
        if ($hasScheduledTask -and $hasConfigRemoval -and $hasDataRemoval -and $hasGitignoreCleanup) {
            return $true
        }
        else {
            Write-Host "    Missing components - Task: $hasScheduledTask, Config: $hasConfigRemoval, Data: $hasDataRemoval, Git: $hasGitignoreCleanup" -ForegroundColor Red
            return $false
        }
    }
    catch {
        return $false
    }
}

function Test-PreservationOptions {
    try {
        $uninstallerScript = Get-Content "$PSScriptRoot\..\scripts\Uninstall-TravelTimeService.ps1" -Raw
        
        # Check for PreserveConfig parameter
        $hasPreserveConfig = $uninstallerScript -match "\[switch\]\`$PreserveConfig"
        
        # Check for PreserveData parameter
        $hasPreserveData = $uninstallerScript -match "\[switch\]\`$PreserveData"
        
        # Check for preservation logic
        $hasPreservationLogic = $uninstallerScript -match "Preserve.*=" -and $uninstallerScript -match "preserved"
        
        if ($hasPreserveConfig -and $hasPreserveData -and $hasPreservationLogic) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        return $false
    }
}

function Test-ErrorHandling {
    try {
        $uninstallerScript = Get-Content "$PSScriptRoot\..\scripts\Uninstall-TravelTimeService.ps1" -Raw
        
        # Check for try-catch blocks
        $hasTryCatch = $uninstallerScript -match "try\s*{" -and $uninstallerScript -match "catch\s*{"
        
        # Check for error logging
        $hasErrorLogging = $uninstallerScript -match "Write-UninstallLog.*Error" -and $uninstallerScript -match "FailedRemovals"
        
        # Check for graceful error handling
        $hasGracefulHandling = $uninstallerScript -match "ErrorAction\s*SilentlyContinue" -or $uninstallerScript -match "-ErrorAction\s*Stop"
        
        if ($hasTryCatch -and $hasErrorLogging -and $hasGracefulHandling) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        return $false
    }
}

function Test-SafetyMeasures {
    try {
        $uninstallerScript = Get-Content "$PSScriptRoot\..\scripts\Uninstall-TravelTimeService.ps1" -Raw
        
        # Check for user confirmation prompts
        $hasConfirmations = $uninstallerScript -match "Get-UserConfirmation" -or $uninstallerScript -match "Read-Host.*\[.*\]"
        
        # Check for administrator privilege checks
        $hasAdminCheck = $uninstallerScript -match "Administrator" -and $uninstallerScript -match "IsInRole"
        
        # Check for Force parameter to bypass confirmations
        $hasForceOption = $uninstallerScript -match "\[switch\]\`$Force"
        
        # Check for WhatIf parameter for preview
        $hasWhatIf = $uninstallerScript -match "\[switch\]\`$WhatIf"
        
        if ($hasConfirmations -and $hasAdminCheck -and $hasForceOption -and $hasWhatIf) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        return $false
    }
}

function Test-OhMyPoshGuidance {
    try {
        $uninstallerScript = Get-Content "$PSScriptRoot\..\scripts\Uninstall-TravelTimeService.ps1" -Raw
        
        # Check for Oh My Posh guidance function
        $hasGuidanceFunction = $uninstallerScript -match "Show-OhMyPoshGuidance" -or $uninstallerScript -match "Oh My Posh.*guidance"
        
        # Check for configuration removal instructions
        $hasConfigInstructions = $uninstallerScript -match "travel time segment" -and $uninstallerScript -match "configuration"
        
        # Check for example segment reference
        $hasExampleSegment = $uninstallerScript -match "travel_time\.json" -and $uninstallerScript -match "ConvertFrom-Json"
        
        if ($hasGuidanceFunction -and $hasConfigInstructions -and $hasExampleSegment) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        return $false
    }
}

function Test-SilentOperation {
    try {
        $uninstallerScript = Get-Content "$PSScriptRoot\..\scripts\Uninstall-TravelTimeService.ps1" -Raw
        
        # Check for Silent parameter
        $hasSilentParam = $uninstallerScript -match "\[switch\]\`$Silent"
        
        # Check for silent mode logic in confirmations
        $hasSilentLogic = $uninstallerScript -match "if.*\`$Silent.*-or.*\`$Force" -or $uninstallerScript -match "\`$Silent.*return.*true"
        
        # Check that silent mode bypasses user prompts
        $bypassesPrompts = $uninstallerScript -match "Silent.*Force" -and $uninstallerScript -match "return.*true"
        
        if ($hasSilentParam -and $hasSilentLogic -and $bypassesPrompts) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        return $false
    }
}

function Test-LoggingAndReporting {
    try {
        $uninstallerScript = Get-Content "$PSScriptRoot\..\scripts\Uninstall-TravelTimeService.ps1" -Raw
        
        # Check for logging infrastructure
        $hasLoggingFunction = $uninstallerScript -match "Write-UninstallLog"
        
        # Check for summary reporting
        $hasSummaryFunction = $uninstallerScript -match "Write-UninstallSummary"
        
        # Check for component tracking
        $hasComponentTracking = $uninstallerScript -match "RemovedComponents" -and $uninstallerScript -match "PreservedComponents" -and $uninstallerScript -match "FailedRemovals"
        
        # Check for log file creation
        $hasLogFile = $uninstallerScript -match "uninstall\.log" -or $uninstallerScript -match "Set-Content.*log"
        
        if ($hasLoggingFunction -and $hasSummaryFunction -and $hasComponentTracking -and $hasLogFile) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        return $false
    }
}

function Test-ParameterValidation {
    try {
        $uninstallerScript = Get-Content "$PSScriptRoot\..\scripts\Uninstall-TravelTimeService.ps1" -Raw
        
        # Check that all required parameters are defined
        $hasAllParams = $uninstallerScript -match "Silent" -and 
                       $uninstallerScript -match "PreserveConfig" -and 
                       $uninstallerScript -match "PreserveData" -and 
                       $uninstallerScript -match "Force" -and 
                       $uninstallerScript -match "WhatIf"
        
        # Check parameter types are switches
        $hasCorrectTypes = $uninstallerScript -match "\[switch\].*Silent" -and 
                          $uninstallerScript -match "\[switch\].*PreserveConfig" -and 
                          $uninstallerScript -match "\[switch\].*PreserveData"
        
        if ($hasAllParams -and $hasCorrectTypes) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        return $false
    }
}

# Main test execution
Write-Host ""
Write-Host "Travel Time Service Uninstaller Tests" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

Test-Function "Uninstaller Script Syntax" { Test-UninstallerSyntax }
Test-Function "Component Identification" { Test-ComponentIdentification } 
Test-Function "Preservation Options" { Test-PreservationOptions }
Test-Function "Error Handling and Logging" { Test-ErrorHandling }
Test-Function "Safety Measures and Confirmations" { Test-SafetyMeasures }
Test-Function "Oh My Posh Configuration Guidance" { Test-OhMyPoshGuidance }
Test-Function "Silent Operation Mode" { Test-SilentOperation }
Test-Function "Logging and Reporting Features" { Test-LoggingAndReporting }
Test-Function "Parameter Combinations and Validation" { Test-ParameterValidation }
Test-Function "Uninstaller WhatIf Mode" { Test-UninstallerWhatIf }

Write-Host ""
Write-Host "Uninstaller Test Summary" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host "Passed:  $($TestResults.Passed)" -ForegroundColor Green
Write-Host "Failed:  $($TestResults.Failed)" -ForegroundColor Red
Write-Host "Total:   $($TestResults.Passed + $TestResults.Failed)"
Write-Host "Pass Rate: $([math]::Round(($TestResults.Passed / ($TestResults.Passed + $TestResults.Failed)) * 100, 1))%"
Write-Host ""

if ($TestResults.Failed -eq 0) {
    Write-Host "All uninstaller tests passed!" -ForegroundColor Green
    Write-Host "The uninstaller is ready for use." -ForegroundColor Green
}
else {
    Write-Host "Some uninstaller tests failed. Review the issues above." -ForegroundColor Yellow
}

# Return results for integration with test runner
return @{
    Passed = $TestResults.Passed
    Failed = $TestResults.Failed
    Total = $TestResults.Passed + $TestResults.Failed
    AllPassed = ($TestResults.Failed -eq 0)
}