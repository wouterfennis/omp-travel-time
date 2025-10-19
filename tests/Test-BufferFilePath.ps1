#Requires -Version 5.1

<#
.SYNOPSIS
    Unit tests for buffer file path configuration functionality.

.DESCRIPTION
    Tests the new configurable buffer file storage location feature including
    path resolution, validation, and OS-specific defaults.
#>

param(
    [string]$TestApiKey = $null
)

# Import the modules
$ProjectRoot = Split-Path $PSScriptRoot -Parent
. "$ProjectRoot\src\utils\BufferPathUtils.ps1"
. "$ProjectRoot\src\config\ConfigManager.ps1"

function Test-BufferPathResolution {
    Write-Host "Testing: Buffer Path Resolution Priority" -ForegroundColor Yellow
    
    # Test 1: Command-line parameter takes priority
    $config = @{ buffer_file_path = "config_path.json" } | ConvertTo-Json | ConvertFrom-Json
    $resolved = Get-BufferFilePath -DataPath "cmdline_path.json" -Config $config
    
    if ($resolved -eq "cmdline_path.json") {
        Write-Host "  ✓ Command-line parameter priority" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ Command-line parameter priority failed" -ForegroundColor Red
        return $false
    }
    
    # Test 2: Environment variable takes priority over config
    $env:OMP_TRAVEL_TIME_DATA_PATH = "env_path.json"
    try {
        $resolved = Get-BufferFilePath -Config $config
        if ($resolved -eq "env_path.json") {
            Write-Host "  ✓ Environment variable priority" -ForegroundColor Green
        }
        else {
            Write-Host "  ❌ Environment variable priority failed" -ForegroundColor Red
            return $false
        }
    }
    finally {
        # Clean up
        Remove-Item Env:\OMP_TRAVEL_TIME_DATA_PATH -ErrorAction SilentlyContinue
    }
    
    # Test 3: Configuration file setting
    $resolved = Get-BufferFilePath -Config $config
    if ($resolved -eq "config_path.json") {
        Write-Host "  ✓ Configuration file setting" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ Configuration file setting failed" -ForegroundColor Red
        return $false
    }
    
    # Test 4: Default OS location fallback
    $emptyConfig = @{} | ConvertTo-Json | ConvertFrom-Json
    $resolved = Get-BufferFilePath -Config $emptyConfig
    $defaultPath = Get-DefaultBufferFilePath
    
    if ($resolved -eq $defaultPath) {
        Write-Host "  ✓ Default OS location fallback" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ Default OS location fallback failed" -ForegroundColor Red
        return $false
    }
    
    return $true
}

function Test-DefaultPathGeneration {
    Write-Host "Testing: OS-Specific Default Paths" -ForegroundColor Yellow
    
    $defaultPath = Get-DefaultBufferFilePath
    
    # Basic validation
    if ([string]::IsNullOrWhiteSpace($defaultPath)) {
        Write-Host "  ❌ Default path is empty" -ForegroundColor Red
        return $false
    }
    
    if (-not $defaultPath.EndsWith("travel_time.json")) {
        Write-Host "  ❌ Default path doesn't end with travel_time.json" -ForegroundColor Red
        return $false
    }
    
    Write-Host "  ✓ Default path generated: $defaultPath" -ForegroundColor Green
    
    # Test path characteristics based on OS
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        if ($defaultPath -like "*LocalApplicationData*" -or $defaultPath -like "*AppData\Local*") {
            Write-Host "  ✓ Windows path uses LocalApplicationData" -ForegroundColor Green
        }
        else {
            Write-Host "  ⚠️  Windows path might not follow expected convention" -ForegroundColor Yellow
        }
    }
    elseif ($IsLinux) {
        if ($defaultPath -like "*/.local/share/*") {
            Write-Host "  ✓ Linux path uses ~/.local/share" -ForegroundColor Green
        }
        else {
            Write-Host "  ⚠️  Linux path might not follow expected convention" -ForegroundColor Yellow
        }
    }
    elseif ($IsMacOS) {
        if ($defaultPath -like "*/Library/Application Support/*") {
            Write-Host "  ✓ macOS path uses Library/Application Support" -ForegroundColor Green
        }
        else {
            Write-Host "  ⚠️  macOS path might not follow expected convention" -ForegroundColor Yellow
        }
    }
    
    return $true
}

function Test-PathValidation {
    Write-Host "Testing: Path Validation and Permissions" -ForegroundColor Yellow
    
    # Test 1: Valid writable path
    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "test_travel_time.json"
    $result = Test-BufferFilePathAccess -Path $tempPath
    
    if ($result.IsValid) {
        Write-Host "  ✓ Valid writable path accepted" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ Valid writable path rejected: $($result.Issues -join ', ')" -ForegroundColor Red
        return $false
    }
    
    # Test 2: Empty path
    $result = Test-BufferFilePathAccess -Path ""
    if (-not $result.IsValid -and $result.Issues -contains "Path cannot be empty") {
        Write-Host "  ✓ Empty path rejected" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ Empty path validation failed" -ForegroundColor Red
        return $false
    }
    
    # Test 3: Directory creation
    $testDir = Join-Path ([System.IO.Path]::GetTempPath()) "test_omp_travel" 
    $testFile = Join-Path $testDir "travel_time.json"
    
    # Ensure directory doesn't exist
    if (Test-Path $testDir) {
        Remove-Item $testDir -Recurse -Force
    }
    
    $result = Test-BufferFilePathAccess -Path $testFile
    
    if ($result.IsValid -and $result.DirectoryCreated) {
        Write-Host "  ✓ Directory creation successful" -ForegroundColor Green
        # Clean up
        Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "  ❌ Directory creation failed" -ForegroundColor Red
        return $false
    }
    
    return $true
}

function Test-ConfigurationIntegration {
    Write-Host "Testing: Configuration File Integration" -ForegroundColor Yellow
    
    # Test 1: Configuration with buffer_file_path
    $configWithPath = @{
        google_routes_api_key = "test_key"
        home_address = "123 Test St"
        start_time = "15:00"
        end_time = "23:00"
        travel_mode = "DRIVE"
        routing_preference = "TRAFFIC_AWARE"
        buffer_file_path = "custom_buffer.json"
    } | ConvertTo-Json | ConvertFrom-Json
    
    $result = Test-ConfigurationFile -Config $configWithPath -ValidateAddress $false
    
    if ($result.IsValid) {
        Write-Host "  ✓ Configuration with buffer_file_path accepted" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ Configuration with buffer_file_path rejected: $($result.Issues -join ', ')" -ForegroundColor Red
        return $false
    }
    
    # Test 2: Configuration without buffer_file_path (should still be valid)
    $configWithoutPath = @{
        google_routes_api_key = "test_key"
        home_address = "123 Test St"
        start_time = "15:00"
        end_time = "23:00"
        travel_mode = "DRIVE"
        routing_preference = "TRAFFIC_AWARE"
    } | ConvertTo-Json | ConvertFrom-Json
    
    $result = Test-ConfigurationFile -Config $configWithoutPath -ValidateAddress $false
    
    if ($result.IsValid) {
        Write-Host "  ✓ Configuration without buffer_file_path accepted" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ Configuration without buffer_file_path rejected: $($result.Issues -join ', ')" -ForegroundColor Red
        return $false
    }
    
    return $true
}

function Test-AbsolutePathConversion {
    Write-Host "Testing: Relative to Absolute Path Conversion" -ForegroundColor Yellow
    
    # Test 1: Already absolute path
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        $absolutePath = "C:\test\path.json"
    }
    else {
        $absolutePath = "/test/path.json"
    }
    
    $result = Convert-ToAbsolutePath -Path $absolutePath -ProjectRoot "/project"
    if ($result -eq $absolutePath) {
        Write-Host "  ✓ Absolute path unchanged" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ Absolute path conversion failed" -ForegroundColor Red
        return $false
    }
    
    # Test 2: Relative path conversion
    $relativePath = "data/travel_time.json"
    $projectRoot = "/project"
    $result = Convert-ToAbsolutePath -Path $relativePath -ProjectRoot $projectRoot
    
    if ($result -and $result.Contains("project") -and $result.Contains("data")) {
        Write-Host "  ✓ Relative path conversion successful" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ Relative path conversion failed" -ForegroundColor Red
        return $false
    }
    
    return $true
}

# Main test execution
Write-Host ""
Write-Host "Buffer File Path Configuration Tests" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true
$testResults = @()

$testResults += Test-BufferPathResolution
$testResults += Test-DefaultPathGeneration  
$testResults += Test-PathValidation
$testResults += Test-ConfigurationIntegration
$testResults += Test-AbsolutePathConversion

$passed = ($testResults | Where-Object { $_ -eq $true }).Count
$failed = ($testResults | Where-Object { $_ -eq $false }).Count
$total = $testResults.Count

Write-Host ""
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "============" -ForegroundColor Cyan
Write-Host "Passed:  $passed" -ForegroundColor Green
Write-Host "Failed:  $failed" -ForegroundColor Red
Write-Host "Total:   $total" -ForegroundColor White
Write-Host "Pass Rate: $([Math]::Round(($passed / $total) * 100, 1))%" -ForegroundColor White

if ($failed -eq 0) {
    Write-Host ""
    Write-Host "All buffer file path tests passed!" -ForegroundColor Green
    $allPassed = $true
}
else {
    Write-Host ""
    Write-Host "Some buffer file path tests failed." -ForegroundColor Red
    $allPassed = $false
}

return $allPassed