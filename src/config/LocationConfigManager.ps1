#Requires -Version 5.1

<#
.SYNOPSIS
    Advanced configuration manager for location detection with adaptive provider selection.

.DESCRIPTION
    Manages location provider configuration with automatic optimization based on 
    reliability scores, network conditions, and user preferences.
#>

# Import dependencies - Note: LocationProviders.ps1 will be loaded when needed to avoid circular imports

function Get-OptimalLocationConfiguration {
    <#
    .SYNOPSIS
        Determines the optimal location provider configuration for current environment.
    
    .DESCRIPTION
        Analyzes available providers, network conditions, and reliability metrics
        to recommend the best location detection configuration.
    
    .PARAMETER UserPreferences
        User-specified preferences for location providers.
        
    .PARAMETER RequireConsent
        Whether to include providers that require user consent.
        
    .PARAMETER MaxResponseTime
        Maximum acceptable response time in milliseconds.
    #>
    param(
        [hashtable]$UserPreferences = @{},
        [bool]$RequireConsent = $false,
        [int]$MaxResponseTime = 5000
    )
    
    $config = @{
        preferred_order = @()
        enable_hybrid = $true
        providers = @{}
        optimization_info = @{
            timestamp = Get-Date
            factors_considered = @()
            recommendations = @()
        }
    }
    
    # Test all providers
    $providerTests = Test-LocationProviders
    $availableProviders = $providerTests | Where-Object { $_.Available -and ($_.Success -or $null -eq $_.Success) }
    
    # Filter by consent requirements
    if (-not $RequireConsent) {
        # Remove Windows provider if consent not granted
        $windowsProvider = New-LocationProvider -Type "Windows" -Config @{} -ErrorAction SilentlyContinue
        if ($windowsProvider -and $windowsProvider.RequiresConsent) {
            $availableProviders = $availableProviders | Where-Object { $_.Provider -ne "Windows" }
            $config.optimization_info.factors_considered += "Excluded Windows provider (requires consent)"
        }
    }
    
    # Filter by response time
    $fastProviders = $availableProviders | Where-Object { $null -eq $_.ResponseTime -or $_.ResponseTime -le $MaxResponseTime }
    if ($fastProviders.Count -lt $availableProviders.Count) {
        $config.optimization_info.factors_considered += "Filtered providers by response time (<= ${MaxResponseTime}ms)"
    }
    $availableProviders = $fastProviders
    
    # Sort by reliability score (if available) or success rate
    $sortedProviders = $availableProviders | Sort-Object @{Expression={
        if ($_.ReliabilityScore -gt 0) { $_.ReliabilityScore }
        elseif ($_.Success) { 100 }
        else { 0 }
    }; Descending=$true}
    
    # Build preferred order
    $config.preferred_order = $sortedProviders | ForEach-Object { $_.Provider }
    
    # Add user preferences to the front if they're available
    if ($UserPreferences.preferred_order) {
        $userOrder = @()
        foreach ($userPref in $UserPreferences.preferred_order) {
            if ($userPref -in $config.preferred_order) {
                $userOrder += $userPref
            }
        }
        # Add remaining providers
        foreach ($provider in $config.preferred_order) {
            if ($provider -notin $userOrder) {
                $userOrder += $provider
            }
        }
        $config.preferred_order = $userOrder
        $config.optimization_info.factors_considered += "Applied user preferences"
    }
    
    # Configure individual providers
    foreach ($providerName in $config.preferred_order) {
        $providerConfig = @{}
        
        switch ($providerName) {
            "IP" {
                # Use reliability assessment to order IP providers
                $ipReport = Get-IPLocationReliabilityReport -TestIterations 1 2>$null
                if ($ipReport -and $ipReport.ProviderAssessments.Count -gt 0) {
                    $reliableProviders = $ipReport.ProviderAssessments | 
                        Where-Object { $_.ReliabilityScore -gt 50 } |
                        Sort-Object ReliabilityScore -Descending |
                        Select-Object -First 3
                    
                    $providerConfig.providers = $reliableProviders | ForEach-Object { $_.Provider }
                    $config.optimization_info.recommendations += "IP providers ordered by reliability"
                }
            }
            "Windows" {
                $providerConfig.use_high_accuracy = $true
                $providerConfig.timeout_seconds = 30
                
                if ($RequireConsent) {
                    $config.optimization_info.recommendations += "Windows provider enabled (user consented)"
                }
            }
            "GPS" {
                # GPS config comes from user preferences only
                if ($UserPreferences.providers -and $UserPreferences.providers.GPS) {
                    $providerConfig = $UserPreferences.providers.GPS
                }
            }
            "Address" {
                # Address config comes from user preferences
                if ($UserPreferences.providers -and $UserPreferences.providers.Address) {
                    $providerConfig = $UserPreferences.providers.Address
                }
            }
        }
        
        $config.providers[$providerName] = $providerConfig
    }
    
    # Determine hybrid mode
    if ($config.preferred_order.Count -gt 1) {
        $config.enable_hybrid = $true
        $config.optimization_info.recommendations += "Hybrid mode enabled (multiple providers available)"
    }
    else {
        $config.enable_hybrid = $false
        $config.optimization_info.recommendations += "Hybrid mode disabled (only one provider available)"
    }
    
    # Network-specific optimizations
    $networkType = Get-NetworkType
    if ($networkType.IsMobile) {
        # Prefer Windows location services on mobile
        if ("Windows" -in $config.preferred_order -and $RequireConsent) {
            $config.preferred_order = @("Windows") + ($config.preferred_order | Where-Object { $_ -ne "Windows" })
            $config.optimization_info.recommendations += "Prioritized Windows provider (mobile connection detected)"
        }
    }
    elseif ($networkType.IsVPN) {
        # Deprioritize IP providers when VPN detected
        $nonIpProviders = $config.preferred_order | Where-Object { $_ -ne "IP" }
        $ipProviders = $config.preferred_order | Where-Object { $_ -eq "IP" }
        $config.preferred_order = $nonIpProviders + $ipProviders
        $config.optimization_info.recommendations += "Deprioritized IP provider (VPN connection detected)"
    }
    
    return $config
}

function Get-NetworkType {
    <#
    .SYNOPSIS
        Analyzes current network connection type for location provider optimization.
    #>
    
    $networkInfo = @{
        IsMobile = $false
        IsVPN = $false
        IsReliable = $true
        ConnectionType = "Unknown"
    }
    
    try {
        # Check network adapter types
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        
        foreach ($adapter in $adapters) {
            if ($adapter.InterfaceDescription -like "*WiFi*" -or $adapter.InterfaceDescription -like "*Wireless*") {
                $networkInfo.ConnectionType = "WiFi"
            }
            elseif ($adapter.InterfaceDescription -like "*Ethernet*") {
                $networkInfo.ConnectionType = "Ethernet"
            }
            elseif ($adapter.InterfaceDescription -like "*Mobile*" -or $adapter.InterfaceDescription -like "*Cellular*") {
                $networkInfo.IsMobile = $true
                $networkInfo.ConnectionType = "Mobile"
            }
            elseif ($adapter.InterfaceDescription -like "*VPN*" -or $adapter.InterfaceDescription -like "*TAP*" -or $adapter.InterfaceDescription -like "*TUN*") {
                $networkInfo.IsVPN = $true
                $networkInfo.ConnectionType = "VPN"
            }
        }
        
        # Additional VPN detection
        if (-not $networkInfo.IsVPN) {
            $vpnDetection = Test-VPNDetection
            if ($vpnDetection -and $vpnDetection.VPNDetected -and $vpnDetection.Confidence -gt 70) {
                $networkInfo.IsVPN = $true
            }
        }
    }
    catch {
        Write-Verbose "Network type detection failed: $($_.Exception.Message)"
    }
    
    return $networkInfo
}

function Update-LocationConfiguration {
    <#
    .SYNOPSIS
        Updates the location configuration in the travel config file.
    
    .PARAMETER NewConfig
        New location configuration to apply.
        
    .PARAMETER ConfigPath
        Path to the travel configuration file.
    #>
    param(
        [hashtable]$NewConfig,
        [string]$ConfigPath
    )
    
    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }
    
    try {
        $config = Get-Content $ConfigPath | ConvertFrom-Json -AsHashtable
        
        # Update location providers section
        if (-not $config.location_providers) {
            $config.location_providers = @{}
        }
        
        foreach ($key in $NewConfig.Keys) {
            $config.location_providers[$key] = $NewConfig[$key]
        }
        
        # Write back to file
        $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath
        
        Write-Host "Location configuration updated successfully" -ForegroundColor Green
    }
    catch {
        throw "Failed to update configuration: $($_.Exception.Message)"
    }
}

function Invoke-LocationConfigurationOptimizer {
    <#
    .SYNOPSIS
        Interactive wizard to optimize location detection configuration.
    
    .DESCRIPTION
        Guides user through location provider setup, testing, and optimization
        based on their environment and preferences.
    #>
    param(
        [string]$ConfigPath = "scripts\config\travel-config.json"
    )
    
    Write-Host "`n=== Location Detection Configuration Optimizer ===" -ForegroundColor Cyan
    Write-Host "This wizard will optimize your location detection settings for best accuracy and performance.`n"
    
    # Step 1: Test current environment
    Write-Host "Step 1: Testing current environment..." -ForegroundColor Yellow
    $providerTests = Test-LocationProviders
    $networkInfo = Get-NetworkType
    
    Write-Host "Available providers:"
    foreach ($test in $providerTests) {
        $status = if ($test.Available) { if ($test.Success) { "✅ Working" } else { "⚠️  Available" } } else { "❌ Unavailable" }
        $timing = if ($test.ResponseTime) { " ($($test.ResponseTime)ms)" } else { "" }
        Write-Host "  $($test.Provider): $status$timing" -ForegroundColor $(if ($test.Success) { "Green" } elseif ($test.Available) { "Yellow" } else { "Red" })
    }
    
    Write-Host "`nNetwork: $($networkInfo.ConnectionType)" -ForegroundColor Cyan
    if ($networkInfo.IsVPN) {
        Write-Host "⚠️  VPN connection detected - IP geolocation may be inaccurate" -ForegroundColor Yellow
    }
    
    # Step 2: User preferences
    Write-Host "`nStep 2: User preferences..." -ForegroundColor Yellow
    
    $requireConsent = $false
    if (($providerTests | Where-Object { $_.Provider -eq "Windows" -and $_.Available }).Count -gt 0) {
        $consentResponse = Read-Host "Enable Windows Location Services for higher accuracy? (requires location permission) [y/N]"
        $requireConsent = $consentResponse -eq "y" -or $consentResponse -eq "Y"
    }
    
    $maxResponseTime = 5000
    $performanceResponse = Read-Host "Performance preference: [f]ast response, [b]alanced, [a]ccurate [b]"
    switch ($performanceResponse.ToLower()) {
        "f" { $maxResponseTime = 2000 }
        "a" { $maxResponseTime = 10000 }
        default { $maxResponseTime = 5000 }
    }
    
    # Step 3: Generate optimal configuration
    Write-Host "`nStep 3: Generating optimal configuration..." -ForegroundColor Yellow
    
    $userPrefs = @{
        preferred_order = @()
    }
    
    $optimalConfig = Get-OptimalLocationConfiguration -UserPreferences $userPrefs -RequireConsent $requireConsent -MaxResponseTime $maxResponseTime
    
    # Step 4: Show recommendations
    Write-Host "`nRecommended Configuration:" -ForegroundColor Green
    Write-Host "Provider order: $($optimalConfig.preferred_order -join ' → ')"
    Write-Host "Hybrid mode: $(if ($optimalConfig.enable_hybrid) { 'Enabled' } else { 'Disabled' })"
    
    if ($optimalConfig.optimization_info.recommendations.Count -gt 0) {
        Write-Host "`nOptimization notes:" -ForegroundColor Cyan
        foreach ($rec in $optimalConfig.optimization_info.recommendations) {
            Write-Host "  • $rec" -ForegroundColor Gray
        }
    }
    
    # Step 5: Apply configuration
    $applyResponse = Read-Host "`nApply this configuration? [Y/n]"
    if ($applyResponse -ne "n" -and $applyResponse -ne "N") {
        try {
            Update-LocationConfiguration -NewConfig $optimalConfig -ConfigPath $ConfigPath
            Write-Host "`n✅ Configuration applied successfully!" -ForegroundColor Green
            Write-Host "Your location detection is now optimized for your environment." -ForegroundColor Green
        }
        catch {
            Write-Host "`n❌ Failed to apply configuration: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    return $optimalConfig
}