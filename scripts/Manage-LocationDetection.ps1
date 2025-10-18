#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Enhanced location detection management tool for Oh My Posh Travel Time.

.DESCRIPTION
    Provides interactive configuration, testing, and optimization of location
    detection providers including IP geolocation, Windows location services,
    GPS coordinates, and address geocoding with intelligent recommendations.

.PARAMETER Action
    The action to perform: Configure, Test, Report, Optimize, or Status.
    
.PARAMETER ConfigPath
    Path to the travel configuration file.
    
.PARAMETER Quiet
    Suppress interactive prompts and use defaults.

.EXAMPLE
    .\Manage-LocationDetection.ps1 -Action Configure
    Interactive configuration wizard for location detection.

.EXAMPLE
    .\Manage-LocationDetection.ps1 -Action Test
    Test all available location providers and show reliability report.

.EXAMPLE
    .\Manage-LocationDetection.ps1 -Action Optimize
    Automatically optimize location provider configuration.
#>

param(
    [ValidateSet("Configure", "Test", "Report", "Optimize", "Status", "Menu")]
    [string]$Action = "Menu",
    [string]$ConfigPath = "config\travel-config.json",
    [switch]$Quiet
)

# Import required modules
$srcPath = Join-Path $PSScriptRoot "..\src"
. "$srcPath\models\TravelTimeModels.ps1"
. "$srcPath\providers\LocationProviders.ps1"
. "$srcPath\services\LocationService.ps1"
. "$srcPath\config\LocationConfigManager.ps1"

function Show-MainMenu {
    <#
    .SYNOPSIS
        Shows the main interactive menu for location detection management.
    #>
    
    Clear-Host
    Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                Location Detection Manager                    ║
║              Oh My Posh Travel Time System                   ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

    Write-Host "Enhanced location detection with multiple providers:" -ForegroundColor Yellow
    Write-Host "  • IP Geolocation (Multiple services with reliability scoring)" -ForegroundColor Gray
    Write-Host "  • Windows Location Services (High accuracy GPS/WiFi)" -ForegroundColor Gray  
    Write-Host "  • GPS Coordinates (Direct input for known locations)" -ForegroundColor Gray
    Write-Host "  • Address Geocoding (Convert addresses to coordinates)" -ForegroundColor Gray
    Write-Host "  • Hybrid Mode (Automatic best-provider selection)" -ForegroundColor Gray

    Write-Host "`nAvailable Actions:" -ForegroundColor Green
    Write-Host "  [1] Configure - Set up location detection preferences" -ForegroundColor White
    Write-Host "  [2] Test - Test all providers and show reliability report" -ForegroundColor White
    Write-Host "  [3] Optimize - Auto-optimize configuration for your environment" -ForegroundColor White
    Write-Host "  [4] Status - Show current configuration and provider status" -ForegroundColor White
    Write-Host "  [5] Report - Generate detailed reliability assessment" -ForegroundColor White
    Write-Host "  [6] Exit" -ForegroundColor White
    
    Write-Host ""
    $choice = Read-Host "Select an option [1-6]"
    
    switch ($choice) {
        "1" { Invoke-LocationConfiguration }
        "2" { Invoke-LocationTesting }
        "3" { Invoke-LocationOptimization }
        "4" { Show-LocationStatus }
        "5" { Show-ReliabilityReport }
        "6" { 
            Write-Host "Goodbye! 👋" -ForegroundColor Green
            return 
        }
        default { 
            Write-Host "Invalid choice. Please select 1-6." -ForegroundColor Red
            Start-Sleep 2
            Show-MainMenu
        }
    }
}

function Invoke-LocationConfiguration {
    <#
    .SYNOPSIS
        Interactive location detection configuration wizard.
    #>
    
    Clear-Host
    Write-Host "🔧 Location Detection Configuration" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════" -ForegroundColor Cyan
    
    # Check if config file exists
    $fullConfigPath = Join-Path $PSScriptRoot $ConfigPath
    $configExists = Test-Path $fullConfigPath
    
    if (-not $configExists) {
        Write-Host "⚠️  Configuration file not found: $fullConfigPath" -ForegroundColor Yellow
        Write-Host "Creating configuration from template..." -ForegroundColor Yellow
        
        $templatePath = Join-Path $PSScriptRoot "config\travel-config.json.template"
        if (Test-Path $templatePath) {
            Copy-Item $templatePath $fullConfigPath
            Write-Host "✅ Configuration file created from template" -ForegroundColor Green
        } else {
            Write-Host "❌ Template file not found. Please run Install-TravelTimeService.ps1 first." -ForegroundColor Red
            Read-Host "Press Enter to return to menu"
            Show-MainMenu
            return
        }
    }
    
    # Test current environment
    Write-Host "`n🔍 Testing current environment..." -ForegroundColor Yellow
    $providerTests = Test-LocationProviders
    $networkInfo = Get-NetworkType
    
    # Show current status
    Write-Host "`nCurrent Provider Status:" -ForegroundColor Cyan
    foreach ($test in $providerTests) {
        $icon = if ($test.Available -and ($test.Success -or $null -eq $test.Success)) { "✅" } 
               elseif ($test.Available) { "⚠️" }
               else { "❌" }
        
        $timing = if ($test.ResponseTime) { " ($($test.ResponseTime)ms)" } else { "" }
        Write-Host "  $icon $($test.Provider)$timing" -ForegroundColor $(
            if ($test.Success) { "Green" } 
            elseif ($test.Available) { "Yellow" } 
            else { "Red" }
        )
    }
    
    Write-Host "`nNetwork: $($networkInfo.ConnectionType)" -ForegroundColor Cyan
    if ($networkInfo.IsVPN) {
        Write-Host "⚠️  VPN detected - IP geolocation may be less accurate" -ForegroundColor Yellow
    }
    
    # Configuration options
    Write-Host "`n📋 Configuration Options:" -ForegroundColor Green
    
    # 1. Provider preferences
    Write-Host "`n1. Provider Priority Order" -ForegroundColor White
    Write-Host "   Current default: Windows → GPS → IP → Address" -ForegroundColor Gray
    
    $customOrder = Read-Host "   Customize provider order? [y/N]"
    $providerOrder = @("Windows", "GPS", "IP", "Address")
    
    if ($customOrder -eq "y" -or $customOrder -eq "Y") {
        Write-Host "   Available providers: Windows, GPS, IP, Address" -ForegroundColor Gray
        Write-Host "   Enter providers in priority order (comma-separated):"
        $orderInput = Read-Host "   "
        if (-not [string]::IsNullOrWhiteSpace($orderInput)) {
            $providerOrder = $orderInput -split ',' | ForEach-Object { $_.Trim() }
        }
    }
    
    # 2. Windows Location Services
    $enableWindows = $false
    $windowsAvailable = ($providerTests | Where-Object { $_.Provider -eq "Windows" }).Available
    
    if ($windowsAvailable) {
        Write-Host "`n2. Windows Location Services" -ForegroundColor White
        Write-Host "   Provides highest accuracy using GPS/WiFi/cellular triangulation" -ForegroundColor Gray
        Write-Host "   Requires: Location permission in Windows Settings" -ForegroundColor Yellow
        
        $windowsChoice = Read-Host "   Enable Windows Location Services? [Y/n]"
        $enableWindows = $windowsChoice -ne "n" -and $windowsChoice -ne "N"
        
        if ($enableWindows) {
            Write-Host "   ✅ Windows Location Services will be enabled" -ForegroundColor Green
            Write-Host "   📝 Note: You may be prompted for location permission on first use" -ForegroundColor Cyan
        }
    } else {
        Write-Host "`n2. Windows Location Services" -ForegroundColor White
        Write-Host "   ❌ Not available (Location service not running)" -ForegroundColor Red
        $enableWindows = $false
    }
    
    # 3. GPS Coordinates
    Write-Host "`n3. GPS Coordinates (Fixed Location)" -ForegroundColor White
    Write-Host "   For office/work locations where coordinates are known" -ForegroundColor Gray
    
    $useGPS = Read-Host "   Configure GPS coordinates for a fixed location? [y/N]"
    $gpsLat = $null
    $gpsLng = $null
    
    if ($useGPS -eq "y" -or $useGPS -eq "Y") {
        do {
            $latInput = Read-Host "   Enter latitude (-90 to 90)"
            $lngInput = Read-Host "   Enter longitude (-180 to 180)"
            
            if ([double]::TryParse($latInput, [ref]$gpsLat) -and [double]::TryParse($lngInput, [ref]$gpsLng)) {
                if ($gpsLat -ge -90 -and $gpsLat -le 90 -and $gpsLng -ge -180 -and $gpsLng -le 180) {
                    Write-Host "   ✅ GPS coordinates configured: $gpsLat, $gpsLng" -ForegroundColor Green
                    break
                }
            }
            Write-Host "   ❌ Invalid coordinates. Please try again." -ForegroundColor Red
        } while ($true)
    }
    
    # 4. Performance preferences
    Write-Host "`n4. Performance Preferences" -ForegroundColor White
    Write-Host "   [1] Fast (≤2s response, lower accuracy)" -ForegroundColor Gray
    Write-Host "   [2] Balanced (≤5s response, good accuracy)" -ForegroundColor Gray
    Write-Host "   [3] Accurate (≤10s response, best accuracy)" -ForegroundColor Gray
    
    $perfChoice = Read-Host "   Select performance preference [1-3, default: 2]"
    $maxResponseTime = switch ($perfChoice) {
        "1" { 2000 }
        "3" { 10000 }
        default { 5000 }
    }
    
    # Generate configuration
    Write-Host "`n⚙️  Generating optimized configuration..." -ForegroundColor Yellow
    
    $userPrefs = @{
        preferred_order = $providerOrder
        providers = @{}
    }
    
    if ($gpsLat -and $gpsLng) {
        $userPrefs.providers.GPS = @{
            Latitude = $gpsLat
            Longitude = $gpsLng
        }
    }
    
    try {
        $optimalConfig = Get-OptimalLocationConfiguration -UserPreferences $userPrefs -RequireConsent $enableWindows -MaxResponseTime $maxResponseTime
        
        # Update configuration file
        Update-LocationConfiguration -NewConfig $optimalConfig -ConfigPath $fullConfigPath
        
        Write-Host "`n✅ Configuration updated successfully!" -ForegroundColor Green
        Write-Host "Provider order: $($optimalConfig.preferred_order -join ' → ')" -ForegroundColor Cyan
        Write-Host "Hybrid mode: $(if ($optimalConfig.enable_hybrid) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Cyan
        
        if ($optimalConfig.optimization_info.recommendations.Count -gt 0) {
            Write-Host "`nOptimization recommendations:" -ForegroundColor Yellow
            foreach ($rec in $optimalConfig.optimization_info.recommendations) {
                Write-Host "  • $rec" -ForegroundColor Gray
            }
        }
        
    } catch {
        Write-Host "`n❌ Configuration failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to return to menu"
    Show-MainMenu
}

function Invoke-LocationTesting {
    <#
    .SYNOPSIS
        Tests all location providers and shows results.
    #>
    
    Clear-Host
    Write-Host "🧪 Location Provider Testing" -ForegroundColor Cyan
    Write-Host "═══════════════════════════" -ForegroundColor Cyan
    
    Write-Host "`n🔍 Testing all location providers..." -ForegroundColor Yellow
    
    # Test individual providers
    $providerTests = Test-LocationProviders
    
    Write-Host "`nProvider Test Results:" -ForegroundColor Green
    Write-Host "─────────────────────" -ForegroundColor Green
    
    foreach ($test in $providerTests) {
        $icon = if ($test.Success) { "✅" } 
               elseif ($test.Available) { "⚠️" }
               else { "❌" }
        
        $status = if ($test.Success) { "Working" }
                 elseif ($test.Available) { "Available" }
                 else { "Unavailable" }
        
        $timing = if ($test.ResponseTime) { " ($($test.ResponseTime)ms)" } else { "" }
        $score = if ($test.ReliabilityScore -gt 0) { " [Score: $($test.ReliabilityScore)]" } else { "" }
        
        Write-Host "$icon $($test.Provider): $status$timing$score" -ForegroundColor $(
            if ($test.Success) { "Green" } 
            elseif ($test.Available) { "Yellow" } 
            else { "Red" }
        )
        
        if ($test.Error) {
            Write-Host "   Error: $($test.Error)" -ForegroundColor Red
        }
    }
    
    # Test VPN detection
    Write-Host "`n🌐 Network Analysis:" -ForegroundColor Green
    Write-Host "───────────────────" -ForegroundColor Green
    
    $networkInfo = Get-NetworkType
    Write-Host "Connection Type: $($networkInfo.ConnectionType)" -ForegroundColor Cyan
    
    if ($networkInfo.IsVPN) {
        Write-Host "🔒 VPN Status: Detected" -ForegroundColor Yellow
        Write-Host "   Impact: IP geolocation may be less accurate" -ForegroundColor Gray
        Write-Host "   Recommendation: Use Windows Location Services or GPS coordinates" -ForegroundColor Gray
    } else {
        Write-Host "🌍 VPN Status: Not detected" -ForegroundColor Green
    }
    
    # Test actual location retrieval
    Write-Host "`n📍 Location Retrieval Test:" -ForegroundColor Green
    Write-Host "──────────────────────────" -ForegroundColor Green
    
    try {
        $location = Get-CurrentLocation
        
        if ($location.Success) {
            Write-Host "✅ Location retrieved successfully!" -ForegroundColor Green
            Write-Host "   Method: $($location.Method)" -ForegroundColor Cyan
            Write-Host "   Provider: $($location.Provider)" -ForegroundColor Cyan
            Write-Host "   Coordinates: $($location.Latitude), $($location.Longitude)" -ForegroundColor Cyan
            Write-Host "   Location: $($location.City), $($location.Region), $($location.Country)" -ForegroundColor Cyan
            
            if ($location.Accuracy -gt 0) {
                Write-Host "   Accuracy: $($location.Accuracy)m" -ForegroundColor Cyan
            }
        } else {
            Write-Host "❌ Location retrieval failed" -ForegroundColor Red
            Write-Host "   Error: $($location.Error)" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Location test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to return to menu"
    Show-MainMenu
}

function Invoke-LocationOptimization {
    <#
    .SYNOPSIS
        Automatically optimizes location detection configuration.
    #>
    
    Clear-Host
    Write-Host "⚡ Location Detection Optimization" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════" -ForegroundColor Cyan
    
    Write-Host "`n🔍 Analyzing current environment..." -ForegroundColor Yellow
    
    # Run optimization
    try {
        $result = Invoke-LocationConfigurationOptimizer -ConfigPath (Join-Path $PSScriptRoot $ConfigPath)
        
        Write-Host "`n✅ Optimization completed!" -ForegroundColor Green
    } catch {
        Write-Host "`n❌ Optimization failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to return to menu"
    Show-MainMenu
}

function Show-LocationStatus {
    <#
    .SYNOPSIS
        Shows current location detection configuration and status.
    #>
    
    Clear-Host
    Write-Host "📊 Location Detection Status" -ForegroundColor Cyan
    Write-Host "═══════════════════════════" -ForegroundColor Cyan
    
    # Load current configuration
    $fullConfigPath = Join-Path $PSScriptRoot $ConfigPath
    
    if (Test-Path $fullConfigPath) {
        try {
            $config = Get-Content $fullConfigPath | ConvertFrom-Json -AsHashtable
            
            Write-Host "`n📋 Current Configuration:" -ForegroundColor Green
            Write-Host "────────────────────────" -ForegroundColor Green
            
            if ($config.location_providers) {
                $locationConfig = $config.location_providers
                
                Write-Host "Provider Order: $($locationConfig.preferred_order -join ' → ')" -ForegroundColor Cyan
                Write-Host "Hybrid Mode: $(if ($locationConfig.enable_hybrid) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Cyan
                Write-Host "Cache Expiry: $($locationConfig.cache_expiry_minutes) minutes" -ForegroundColor Cyan
                
                if ($locationConfig.providers) {
                    Write-Host "`nProvider Settings:" -ForegroundColor Yellow
                    foreach ($providerName in $locationConfig.providers.Keys) {
                        Write-Host "  $providerName : Configured" -ForegroundColor Gray
                    }
                }
            } else {
                Write-Host "❌ No location provider configuration found" -ForegroundColor Red
                Write-Host "   Run configuration to set up location detection" -ForegroundColor Yellow
            }
            
        } catch {
            Write-Host "❌ Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Configuration file not found: $fullConfigPath" -ForegroundColor Red
        Write-Host "   Run Install-TravelTimeService.ps1 first" -ForegroundColor Yellow
    }
    
    # Show provider status
    Write-Host "`n🔌 Provider Status:" -ForegroundColor Green
    Write-Host "──────────────────" -ForegroundColor Green
    
    $providerTests = Test-LocationProviders
    foreach ($test in $providerTests) {
        $icon = if ($test.Success) { "✅" } 
               elseif ($test.Available) { "⚠️" }
               else { "❌" }
        
        Write-Host "$icon $($test.Provider)" -ForegroundColor $(
            if ($test.Success) { "Green" } 
            elseif ($test.Available) { "Yellow" } 
            else { "Red" }
        )
    }
    
    Read-Host "`nPress Enter to return to menu"
    Show-MainMenu
}

function Show-ReliabilityReport {
    <#
    .SYNOPSIS
        Generates and displays a detailed reliability report.
    #>
    
    Clear-Host
    Write-Host "📈 Location Detection Reliability Report" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════" -ForegroundColor Cyan
    
    Write-Host "`n🔄 Generating comprehensive reliability report..." -ForegroundColor Yellow
    Write-Host "This may take a few moments as we test multiple providers..." -ForegroundColor Gray
    
    try {
        $report = Get-IPLocationReliabilityReport -TestIterations 3 -IncludeVPNDetection
        
        Write-Host "`n📊 IP Geolocation Provider Assessment:" -ForegroundColor Green
        Write-Host "────────────────────────────────────────" -ForegroundColor Green
        
        if ($report.ProviderAssessments.Count -gt 0) {
            foreach ($assessment in $report.ProviderAssessments) {
                $providerName = Split-Path $assessment.Provider -Leaf
                $score = $assessment.ReliabilityScore
                $scoreColor = if ($score -gt 80) { "Green" } elseif ($score -gt 60) { "Yellow" } else { "Red" }
                
                Write-Host "`n🌐 $providerName" -ForegroundColor Cyan
                Write-Host "   Reliability Score: $score / 100" -ForegroundColor $scoreColor
                Write-Host "   Success Rate: $($assessment.SuccessRate * 100)%" -ForegroundColor Cyan
                Write-Host "   Average Response: $([math]::Round($assessment.AverageResponseTime, 0))ms" -ForegroundColor Cyan
                Write-Host "   Tests: $($assessment.SuccessCount)/$($assessment.TotalAttempts)" -ForegroundColor Gray
            }
        }
        
        if ($report.VPNDetection) {
            Write-Host "`n🔒 VPN Detection Analysis:" -ForegroundColor Green
            Write-Host "─────────────────────────" -ForegroundColor Green
            
            if ($report.VPNDetection.VPNDetected) {
                Write-Host "Status: VPN Detected" -ForegroundColor Yellow
                Write-Host "Confidence: $($report.VPNDetection.Confidence)%" -ForegroundColor Yellow
                Write-Host "Indicators:" -ForegroundColor Yellow
                foreach ($reason in $report.VPNDetection.Reasons) {
                    Write-Host "  • $reason" -ForegroundColor Gray
                }
            } else {
                Write-Host "Status: No VPN Detected" -ForegroundColor Green
            }
        }
        
        Write-Host "`n💡 Recommendations:" -ForegroundColor Green
        Write-Host "──────────────────" -ForegroundColor Green
        
        if ($report.Recommendations.Count -gt 0) {
            foreach ($rec in $report.Recommendations) {
                Write-Host "  • $rec" -ForegroundColor Cyan
            }
        } else {
            Write-Host "  • Current configuration appears optimal" -ForegroundColor Green
        }
        
        Write-Host "`n📈 Overall Score: $($report.OverallScore) / 100" -ForegroundColor $(
            if ($report.OverallScore -gt 80) { "Green" } 
            elseif ($report.OverallScore -gt 60) { "Yellow" } 
            else { "Red" }
        )
        
    } catch {
        Write-Host "`n❌ Report generation failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to return to menu"
    Show-MainMenu
}

# Main execution
try {
    switch ($Action.ToLower()) {
        "menu" { Show-MainMenu }
        "configure" { Invoke-LocationConfiguration }
        "test" { Invoke-LocationTesting }
        "optimize" { Invoke-LocationOptimization }
        "status" { Show-LocationStatus }
        "report" { Show-ReliabilityReport }
    }
} catch {
    Write-Host "`n❌ An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    
    if (-not $Quiet) {
        Read-Host "`nPress Enter to exit"
    }
}