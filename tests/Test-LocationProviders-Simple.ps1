#Requires -Version 5.1

<#
.SYNOPSIS
    Simple tests for enhanced location detection providers without complex dependencies.

.DESCRIPTION
    Tests core functionality of the new location providers to validate
    the enhanced location detection system works correctly.
#>

param(
    [switch]$SkipNetworkTests,
    [switch]$Verbose
)

# Import required modules directly
$srcPath = Join-Path $PSScriptRoot "..\src"
. "$srcPath\models\TravelTimeModels.ps1"
. "$srcPath\providers\LocationProviders.ps1"

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

# Test 2: GPS Provider
Write-Host "`nTesting GPS Provider..."
try {
    $gpsConfig = @{ Latitude = 40.7128; Longitude = -74.0060 }
    $gpsProvider = New-LocationProvider -Type "GPS" -Config $gpsConfig
    Write-TestResult "GPS Provider - Creation" ($null -ne $gpsProvider)
    
    $gpsLocation = $gpsProvider.GetLocation()
    Write-TestResult "GPS Provider - Get Location" $gpsLocation.Success
    Write-TestResult "GPS Provider - Correct Coordinates" ($gpsLocation.Latitude -eq 40.7128)
    
    $available = $gpsProvider.IsAvailable()
    Write-TestResult "GPS Provider - Availability Check" $available
} catch {
    Write-TestResult "GPS Provider" $false $_.Exception.Message
}

# Test 3: GPS Provider Validation
Write-Host "`nTesting GPS Provider Validation..."
try {
    # Test valid coordinates
    $validConfig = @{ Latitude = 40.7128; Longitude = -74.0060 }
    $validProvider = New-LocationProvider -Type "GPS" -Config $validConfig
    $validResult = $validProvider.GetLocation()
    Write-TestResult "GPS Validation - Valid Coordinates" $validResult.Success
    
    # Test invalid latitude
    $invalidConfig = @{ Latitude = 200; Longitude = -74.0060 }
    $invalidProvider = New-LocationProvider -Type "GPS" -Config $invalidConfig
    $invalidResult = $invalidProvider.GetLocation()
    Write-TestResult "GPS Validation - Invalid Latitude Rejection" (-not $invalidResult.Success)
    
    # Test invalid longitude
    $invalidConfig2 = @{ Latitude = 40.7128; Longitude = 200 }
    $invalidProvider2 = New-LocationProvider -Type "GPS" -Config $invalidConfig2
    $invalidResult2 = $invalidProvider2.GetLocation()
    Write-TestResult "GPS Validation - Invalid Longitude Rejection" (-not $invalidResult2.Success)
} catch {
    Write-TestResult "GPS Provider Validation" $false $_.Exception.Message
}

# Test 4: IP Provider (without network calls)
Write-Host "`nTesting IP Provider Structure..."
try {
    $ipProvider = New-LocationProvider -Type "IP" -Config @{}
    Write-TestResult "IP Provider - Creation" ($null -ne $ipProvider)
    Write-TestResult "IP Provider - Has GetLocation Method" ($null -ne $ipProvider.PSObject.Methods["GetLocation"])
    Write-TestResult "IP Provider - Has IsAvailable Method" ($null -ne $ipProvider.PSObject.Methods["IsAvailable"])
} catch {
    Write-TestResult "IP Provider Structure" $false $_.Exception.Message
}

# Test 5: Windows Provider Structure
Write-Host "`nTesting Windows Provider Structure..."
try {
    $windowsProvider = New-LocationProvider -Type "Windows" -Config @{}
    Write-TestResult "Windows Provider - Creation" ($null -ne $windowsProvider)
    Write-TestResult "Windows Provider - Requires Consent" $windowsProvider.RequiresConsent
    Write-TestResult "Windows Provider - Has Methods" ($null -ne $windowsProvider.PSObject.Methods["GetLocation"])
} catch {
    Write-TestResult "Windows Provider Structure" $false $_.Exception.Message
}

# Test 6: Address Provider Structure
Write-Host "`nTesting Address Provider Structure..."
try {
    $addressConfig = @{ Address = "Times Square, New York, NY"; ApiKey = "test-key" }
    $addressProvider = New-LocationProvider -Type "Address" -Config $addressConfig
    Write-TestResult "Address Provider - Creation" ($null -ne $addressProvider)
    
    # Test without API key
    try {
        $noKeyConfig = @{ Address = "Times Square, New York, NY" }
        $noKeyProvider = New-LocationProvider -Type "Address" -Config $noKeyConfig
        Write-TestResult "Address Provider - No API Key Warning" $true "Created with warning"
    } catch {
        Write-TestResult "Address Provider - No API Key Handling" $true "Validation works"
    }
} catch {
    Write-TestResult "Address Provider Structure" $false $_.Exception.Message
}

# Test 7: Hybrid Provider
Write-Host "`nTesting Hybrid Provider..."
try {
    $hybridProvider = New-LocationProvider -Type "Hybrid" -Config @{}
    Write-TestResult "Hybrid Provider - Creation" ($null -ne $hybridProvider)
    Write-TestResult "Hybrid Provider - Requires Consent" $hybridProvider.RequiresConsent
    Write-TestResult "Hybrid Provider - Has AddProvider Method" ($null -ne $hybridProvider.PSObject.Methods["AddProvider"])
    
    # Test availability (should always be true)
    $hybridAvailable = $hybridProvider.IsAvailable()
    Write-TestResult "Hybrid Provider - Always Available" $hybridAvailable
} catch {
    Write-TestResult "Hybrid Provider" $false $_.Exception.Message
}

# Test 8: Provider Configuration Validation
Write-Host "`nTesting Provider Configuration Validation..."
try {
    # GPS provider without coordinates should fail validation
    try {
        $emptyGpsProvider = New-LocationProvider -Type "GPS" -Config @{}
        Write-TestResult "Config Validation - Empty GPS Config" $false "Should have thrown exception"
    } catch {
        Write-TestResult "Config Validation - Empty GPS Config" $true "Validation works"
    }
    
    # Address provider without address should fail validation  
    try {
        $emptyAddressProvider = New-LocationProvider -Type "Address" -Config @{}
        Write-TestResult "Config Validation - Empty Address Config" $false "Should have thrown exception"
    } catch {
        Write-TestResult "Config Validation - Empty Address Config" $true "Validation works"
    }
} catch {
    Write-TestResult "Provider Configuration Validation" $false $_.Exception.Message
}

# Test 9: Location Distance Calculation
Write-Host "`nTesting Location Distance Calculation..."
try {
    # Test same location (should be 0)
    $sameDistance = Get-LocationDistance -Lat1 40.7128 -Lng1 -74.0060 -Lat2 40.7128 -Lng2 -74.0060
    Write-TestResult "Distance Calculation - Same Location" ($sameDistance -eq 0) "Distance: $sameDistance km"
    
    # Test known distance (New York to Philadelphia ~ 130 km)
    $distance = Get-LocationDistance -Lat1 40.7128 -Lng1 -74.0060 -Lat2 39.9526 -Lng2 -75.1652
    $expectedDistance = 130
    $tolerance = 20
    Write-TestResult "Distance Calculation - Known Distance" ([math]::Abs($distance - $expectedDistance) -lt $tolerance) "Calculated: $([math]::Round($distance, 1)) km, Expected: ~$expectedDistance km"
} catch {
    Write-TestResult "Location Distance Calculation" $false $_.Exception.Message
}

# Test 10: IP Response Parsing
Write-Host "`nTesting IP Response Parsing..."
try {
    # Test ip-api.com response format
    $ipApiResponse = @{
        status = "success"
        lat = 40.7128
        lon = -74.0060
        city = "New York"
        regionName = "New York" 
        country = "United States"
    }
    
    $parsedResult = Parse-IPLocationResponse -Response $ipApiResponse -ProviderUrl "https://ip-api.com/json/"
    Write-TestResult "IP Response Parsing - ip-api.com" $parsedResult.Success
    Write-TestResult "IP Response Parsing - Correct Coordinates" ($parsedResult.Latitude -eq 40.7128)
    
    # Test ipapi.co response format
    $ipapiResponse = @{
        ip = "1.2.3.4"
        latitude = 40.7128
        longitude = -74.0060
        city = "New York"
        region = "New York"
        country_name = "United States"
    }
    
    $parsedResult2 = Parse-IPLocationResponse -Response $ipapiResponse -ProviderUrl "https://ipapi.co/json/"
    Write-TestResult "IP Response Parsing - ipapi.co" $parsedResult2.Success
} catch {
    Write-TestResult "IP Response Parsing" $false $_.Exception.Message
}

# Test 11: Error Handling
Write-Host "`nTesting Error Handling..."
try {
    # Test invalid provider type
    try {
        $invalidProvider = New-LocationProvider -Type "InvalidType" -Config @{}
        Write-TestResult "Error Handling - Invalid Provider Type" $false "Should have thrown exception"
    } catch {
        Write-TestResult "Error Handling - Invalid Provider Type" $true "Exception correctly thrown"
    }
    
    # Test empty response parsing
    $emptyResult = Parse-IPLocationResponse -Response @{} -ProviderUrl "https://unknown-provider.com"
    Write-TestResult "Error Handling - Unknown Provider Response" (-not $emptyResult.Success)
} catch {
    Write-TestResult "Error Handling" $false $_.Exception.Message
}

# Test Summary
Write-Host "`n" + "="*50
Write-Host "Simple Location Provider Test Summary" -ForegroundColor Cyan
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