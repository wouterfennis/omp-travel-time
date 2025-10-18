#Requires -Version 5.1

<#
.SYNOPSIS
    Simple tests for Windows-only location detection and location model.

.DESCRIPTION
    Validates location result model creation, Windows Location retrieval,
    and simulated unavailable scenario.
#>

param(
    [switch]$SkipNetworkTests,
    [switch]$Verbose
)

# Import required modules directly
$srcPath = Join-Path $PSScriptRoot "..\src"
. "$srcPath\models\TravelTimeModels.ps1"
. "$srcPath\services\LocationService.ps1"

# Test statistics
$script:TestResults = @{
    Passed = 0
    Failed = 0
    Skipped = 0
    Total = 0
}

function Write-TestResult {
    param([string]$TestName, [bool]$Passed, [string]$Message = "")
    
    $script:TestResults.Total++
    
    if ($Passed) {
        $script:TestResults.Passed++
        Write-Host "  ✅ $TestName" -ForegroundColor Green
    } else {
        $script:TestResults.Failed++
        Write-Host "  ❌ $TestName" -ForegroundColor Red
        if ($Message) {
            Write-Host "     $Message" -ForegroundColor Yellow
        }
    }
}

function Write-TestSkipped {
    param([string]$TestName, [string]$Reason = "")
    
    $script:TestResults.Total++
    $script:TestResults.Skipped++
    Write-Host "  ⏭️  $TestName" -ForegroundColor Yellow
    if ($Reason) {
        Write-Host "     $Reason" -ForegroundColor Gray
    }
}

Write-Host "`nSimple Location Provider Tests" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

# Test 1: Location Result Model
Write-Host "`nTesting Location Result Model..."
try {
    $result = New-LocationResult -Latitude 40.7128 -Longitude -74.0060 -City "New York" -Success $true
    Write-TestResult "Location Model - Creation" ($null -ne $result)
    Write-TestResult "Location Model - Required Fields" ($result.ContainsKey("Latitude") -and $result.ContainsKey("Success"))
    Write-TestResult "Location Model - Timestamp" ($null -ne $result.Timestamp)
} catch {
    Write-TestResult "Location Model" $false $_.Exception.Message
}

Write-Host "`nTesting Windows Location Retrieval..."
try {
    $loc = Get-CurrentLocation -UseCache $true
    Write-TestResult "Windows Location - Retrieval" $loc.Success $loc.Error
    if ($loc.Success) {
        Write-TestResult "Windows Location - Coordinates Present" ($loc.ContainsKey('Latitude') -and $loc.ContainsKey('Longitude'))
    }
} catch { Write-TestResult "Windows Location - Retrieval" $false $_.Exception.Message }

Write-Host "`nTesting Windows Location Unavailable (Mock)..."
try {
    if (Get-Command Get-WindowsLocation -ErrorAction SilentlyContinue) {
        $original = (Get-Command Get-WindowsLocation).ScriptBlock
        function Get-WindowsLocation { return @{ Success = $false; Error = 'Simulated unavailable'; Method = 'Windows' } }
        $failLoc = Get-CurrentLocation -ForceRefresh
        Write-TestResult "Windows Location - Unavailable Mock" (-not $failLoc.Success) $failLoc.Error
        Remove-Item function:Get-WindowsLocation -ErrorAction SilentlyContinue
        Set-Item -Path function:Get-WindowsLocation -Value $original
    } else {
        Write-TestSkipped "Windows Location - Unavailable Mock" "Function not found"
    }
} catch { Write-TestResult "Windows Location - Unavailable Mock" $false $_.Exception.Message }

# Test Summary
Write-Host "`n" + "="*50
Write-Host "Windows Location Simple Test Summary" -ForegroundColor Cyan
Write-Host "="*50
Write-Host "Passed:  $($script:TestResults.Passed)" -ForegroundColor Green
Write-Host "Failed:  $($script:TestResults.Failed)" -ForegroundColor Red
Write-Host "Skipped: $($script:TestResults.Skipped)" -ForegroundColor Yellow
Write-Host "Total:   $($script:TestResults.Total)"

$passRate = if ($script:TestResults.Total -gt 0) { 
    [math]::Round(($script:TestResults.Passed / $script:TestResults.Total) * 100, 1) 
} else { 0 }

Write-Host "Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 90) { "Green" } elseif ($passRate -ge 75) { "Yellow" } else { "Red" })

if ($script:TestResults.Failed -eq 0) {
    Write-Host "`n✅ All tests passed!" -ForegroundColor Green
    Write-Host "The enhanced location detection system core functionality is working correctly." -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Some tests failed." -ForegroundColor Yellow
    Write-Host "Review the failures above." -ForegroundColor Yellow
}

# Return results for automation
return @{
    Passed = $script:TestResults.Passed
    Failed = $script:TestResults.Failed
    Skipped = $script:TestResults.Skipped
    Total = $script:TestResults.Total
    PassRate = $passRate
    AllPassed = $script:TestResults.Failed -eq 0
}