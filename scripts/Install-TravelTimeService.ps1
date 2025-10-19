#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Installs and configures the Oh My Posh Travel Time service.

.DESCRIPTION
    This script sets up the travel time tracking service for Oh My Posh prompts.
    It creates configuration files, sets up scheduled tasks, and prepares the environment
    for displaying travel time information in your PowerShell prompt.

.PARAMETER GoogleMapsApiKey
    Your Google Maps API key with Routes API enabled.

.PARAMETER HomeAddress
    Your home address for travel time calculations.

.PARAMETER StartTime
    Time when travel time tracking should start each day (HH:MM format).

.PARAMETER EndTime
    Time when travel time tracking should end each day (HH:MM format).

.PARAMETER BufferFilePath
    Custom path for the buffer file that stores travel time data. If not specified,
    uses OS-specific default location.

.EXAMPLE
    .\Install-TravelTimeService.ps1
    
.EXAMPLE
    .\Install-TravelTimeService.ps1 -GoogleMapsApiKey "YOUR_KEY" -HomeAddress "123 Main St" -StartTime "14:30" -EndTime "22:00"

.NOTES
    - Requires Administrator privileges to create scheduled tasks
    - Requires Google Maps API key with Routes API enabled
    - Get API key at: https://developers.google.com/maps/documentation/routes/cloud-setup
#>

param(
    [string]$GoogleMapsApiKey,
    [string]$HomeAddress,
    [string]$StartTime,
    [string]$EndTime,
    [string]$BufferFilePath,
    [switch]$Plain
)

# Attempt to force UTF-8 output (PowerShell 7 already defaults to UTF-8)
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

function Show-Header {
    param([switch]$PlainMode)

    if ($PlainMode) {
        Write-Host 'Oh My Posh Travel Time Service - Installation Wizard' -ForegroundColor Cyan
        Write-Host '----------------------------------------------------' -ForegroundColor Cyan
        Write-Host ''
        return
    }

    $isLegacyPwsh = ($PSVersionTable.PSVersion.Major -lt 6)
    $unicodeOk = $true
    try {
        # Quick heuristic: try to write a box character silently
        [void]('╔')
    }
    catch { $unicodeOk = $false }

    if ($isLegacyPwsh -and -not ($env:WT_SESSION) -and ([Console]::OutputEncoding.WebName -notmatch 'utf')) {
        $unicodeOk = $false
    }

    if (-not $unicodeOk) {
        Write-Host 'Oh My Posh Travel Time Service - Installation Wizard' -ForegroundColor Cyan
        Write-Host 'Use -Plain (or rerun after chcp 65001) to avoid garbled characters.' -ForegroundColor Yellow
        Write-Host ''
        return
    }

    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                Oh My Posh Travel Time Service                ║" -ForegroundColor Cyan
    Write-Host "║                     Installation Wizard                      ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ''
}

function Get-UserInput {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )

    if ($Default) {
        $userResponse = Read-Host "$Prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($userResponse)) {
            return $Default
        }
        return $userResponse
    }
    do {
        $userResponse = Read-Host $Prompt
    } while ([string]::IsNullOrWhiteSpace($userResponse))
    return $userResponse
}

function Test-TimeFormat {
    param([string]$Time)
    
    try {
        [DateTime]::Parse($Time) | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Test-ApiKey {
    param([string]$ApiKey)
    
    # Basic validation - Google API keys are typically 39 characters
    if ($ApiKey.Length -lt 30) {
        return $false
    }
    
    if ($ApiKey -match "^[A-Za-z0-9_-]+$") {
        return $true
    }
    
    return $false
}

function Install-TravelTimeService {
    Show-Header -PlainMode:$Plain
    
    # Collect configuration if not provided via parameters
    if (-not $GoogleMapsApiKey) {
        Write-Host "🗝️  Google Maps API Configuration" -ForegroundColor Yellow
        Write-Host "   You'll need a Google Maps API key with Routes API enabled." -ForegroundColor White
        Write-Host "   Get one at: https://developers.google.com/maps/documentation/routes/cloud-setup" -ForegroundColor Cyan
        Write-Host ""
        
        do {
            $GoogleMapsApiKey = Get-UserInput "   Enter your Google Maps API Key"
            if (-not (Test-ApiKey $GoogleMapsApiKey)) {
                Write-Host "   ❌ Invalid API key format. Please check your key." -ForegroundColor Red
                $GoogleMapsApiKey = $null
            }
        } while (-not $GoogleMapsApiKey)
        
        Write-Host "   ✓ API key accepted" -ForegroundColor Green
        Write-Host ""
    }
    
    if (-not $HomeAddress) {
        Write-Host "🏠 Home Address Configuration" -ForegroundColor Yellow
        Write-Host "   Enter your home address for travel time calculations." -ForegroundColor White
        Write-Host "   Tips for best results:" -ForegroundColor Cyan
        Write-Host "   • Include street number and name" -ForegroundColor Cyan
        Write-Host "   • Add city, state/province" -ForegroundColor Cyan
        Write-Host "   • Use commas to separate components" -ForegroundColor Cyan
        Write-Host ""
        
        # Load address validation service
        $addressServicePath = Join-Path $PSScriptRoot "..\src\services\AddressValidationService.ps1"
        $addressValidationAvailable = Test-Path $addressServicePath
        
        if ($addressValidationAvailable) {
            . $addressServicePath
            Write-Host "   Examples of well-formatted addresses:" -ForegroundColor DarkCyan
            $examples = Get-AddressValidationExamples
            for ($i = 0; $i -lt [Math]::Min(3, $examples.Length); $i++) {
                Write-Host "   • $($examples[$i])" -ForegroundColor DarkGray
            }
            Write-Host ""
        }
        
        do {
            $HomeAddress = Get-UserInput "   Home Address" "123 Main St, City, State"
            
            if ($addressValidationAvailable) {
                Write-Host "   🔍 Validating address..." -ForegroundColor Yellow
                
                # Perform validation with current API key if available
                $tempApiKey = if ($GoogleMapsApiKey -and (Test-ApiKey $GoogleMapsApiKey)) { $GoogleMapsApiKey } else { $null }
                $validation = Invoke-AddressValidation -Address $HomeAddress -ApiKey $tempApiKey -AllowOverride $true
                
                if ($validation.IsValid) {
                    Write-Host "   ✓ Address validation passed" -ForegroundColor Green
                    if ($validation.RecommendedAddress -ne $HomeAddress) {
                        Write-Host "   💡 Google suggests: $($validation.RecommendedAddress)" -ForegroundColor Cyan
                        $useRecommended = Read-Host "   Use recommended address? [Y/n]"
                        if ($useRecommended -ne "n" -and $useRecommended -ne "N") {
                            $HomeAddress = $validation.RecommendedAddress
                            Write-Host "   ✓ Using recommended address" -ForegroundColor Green
                        }
                    }
                    break
                }
                elseif ($validation.CanProceed) {
                    Write-Host "   ⚠️  Address has warnings:" -ForegroundColor Yellow
                    foreach ($warning in $validation.OverallSuggestions) {
                        Write-Host "      • $warning" -ForegroundColor Yellow
                    }
                    
                    $proceed = Read-Host "   Continue with this address anyway? [Y/n]"
                    if ($proceed -ne "n" -and $proceed -ne "N") {
                        break
                    }
                }
                else {
                    Write-Host "   ❌ Address validation failed:" -ForegroundColor Red
                    foreach ($issue in $validation.OverallIssues) {
                        Write-Host "      • $issue" -ForegroundColor Red
                    }
                    Write-Host ""
                    Write-Host "   💡 Suggestions:" -ForegroundColor Cyan
                    foreach ($suggestion in $validation.OverallSuggestions) {
                        Write-Host "      • $suggestion" -ForegroundColor Cyan
                    }
                    Write-Host ""
                }
            }
            else {
                Write-Host "   ⚠️  Address validation service not available - using basic validation" -ForegroundColor Yellow
                if ($HomeAddress.Trim().Length -lt 5) {
                    Write-Host "   ❌ Address appears too short. Please provide a more complete address." -ForegroundColor Red
                }
                else {
                    break
                }
            }
        } while ($true)
        
        Write-Host "   ✓ Home address set: $HomeAddress" -ForegroundColor Green
        Write-Host ""
    }
    
    if (-not $StartTime) {
        Write-Host "⏰ Active Hours Configuration" -ForegroundColor Yellow
        Write-Host "   Configure when travel time tracking should be active each day." -ForegroundColor White
        Write-Host ""
        
        do {
            $StartTime = Get-UserInput "   Start Time (HH:MM format)" "15:00"
            if (-not (Test-TimeFormat $StartTime)) {
                Write-Host "   ❌ Invalid time format. Please use HH:MM format (e.g., 15:00)" -ForegroundColor Red
                $StartTime = $null
            }
        } while (-not $StartTime)
        
        Write-Host "   ✓ Start time set: $StartTime" -ForegroundColor Green
    }
    
    if (-not $EndTime) {
        do {
            $EndTime = Get-UserInput "   End Time (HH:MM format)" "23:00"
            if (-not (Test-TimeFormat $EndTime)) {
                Write-Host "   ❌ Invalid time format. Please use HH:MM format (e.g., 23:00)" -ForegroundColor Red
                $EndTime = $null
            }
        } while (-not $EndTime)
        
        Write-Host "   ✓ End time set: $EndTime" -ForegroundColor Green
        Write-Host ""
    }
    
    # Import buffer path utilities for default path resolution
    $bufferUtilsPath = "$PSScriptRoot\..\src\utils\BufferPathUtils.ps1"
    if (Test-Path $bufferUtilsPath) {
        . $bufferUtilsPath
    }
    
    if (-not $BufferFilePath) {
        Write-Host "💾 Buffer File Location" -ForegroundColor Yellow
        Write-Host "   Configure where travel time data should be stored." -ForegroundColor White
        Write-Host ""
        
        # Show default location
        $defaultPath = Get-DefaultBufferFilePath
        Write-Host "   Default location: $defaultPath" -ForegroundColor Cyan
        Write-Host ""
        
        do {
            $BufferFilePath = Get-UserInput "   Custom buffer file path (press Enter for default)" ""
            
            if ([string]::IsNullOrWhiteSpace($BufferFilePath)) {
                $BufferFilePath = ""
                Write-Host "   ✓ Using default OS-specific location" -ForegroundColor Green
                break
            }
            else {
                # Validate the custom path
                $pathValidation = Test-BufferFilePathAccess -Path $BufferFilePath
                if ($pathValidation.IsValid) {
                    if ($pathValidation.DirectoryCreated) {
                        Write-Host "   ✓ Created directory: $(Split-Path $BufferFilePath -Parent)" -ForegroundColor Green
                    }
                    Write-Host "   ✓ Custom buffer file path set: $BufferFilePath" -ForegroundColor Green
                    break
                }
                else {
                    Write-Host "   ❌ Invalid path:" -ForegroundColor Red
                    foreach ($issue in $pathValidation.Issues) {
                        Write-Host "      • $issue" -ForegroundColor Red
                    }
                    Write-Host ""
                    $BufferFilePath = $null
                }
            }
        } while (-not $BufferFilePath -and $BufferFilePath -ne "")
        
        Write-Host ""
    }
    
    Write-Host "📋 Configuration Summary:" -ForegroundColor Cyan
    Write-Host "   • API Key: ********" -ForegroundColor White
    Write-Host "   • Home Address: $HomeAddress" -ForegroundColor White
    Write-Host "   • Active Hours: $StartTime - $EndTime" -ForegroundColor White
    if ([string]::IsNullOrWhiteSpace($BufferFilePath)) {
        Write-Host "   • Buffer File: Default OS location" -ForegroundColor White
    }
    else {
        Write-Host "   • Buffer File: $BufferFilePath" -ForegroundColor White
    }
    Write-Host ""
    
    $confirm = Read-Host "Continue with installation? [Y/n]"
    if ($confirm -eq "n" -or $confirm -eq "N") {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        return
    }
    
    $scriptRoot = $PSScriptRoot
    $projectRoot = Split-Path $scriptRoot -Parent
    
    Write-Host "🔧 Installing Travel Time Service..." -ForegroundColor Green
    Write-Host ""
    
    # Create config file
    $configPath = "$scriptRoot\config\travel-config.json"
    $configDir = Split-Path $configPath -Parent
    
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    $config = @{
        google_routes_api_key = $GoogleMapsApiKey
        home_address = $HomeAddress
        update_interval_minutes = 5
        start_time = $StartTime
        end_time = $EndTime
        travel_mode = "DRIVE"
        routing_preference = "TRAFFIC_AWARE"
        units = "METRIC"
        buffer_file_path = $BufferFilePath
    }
    
    $config | ConvertTo-Json -Depth 2 | Set-Content -Path $configPath -Encoding UTF8
    Write-Host "   ✓ Created config file: $configPath" -ForegroundColor Green
    
    # Create scheduled task
    $taskName = "OhMyPosh-TravelTime"
    $scriptPath = "$scriptRoot\TravelTimeUpdater.ps1"
    
    # Remove existing task if it exists
    try {
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-Host "   ✓ Removed existing scheduled task" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to remove existing scheduled task: $_"
    }
    
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

    # Create a minimal one-time trigger (no repetition specified here) that starts next minute.
    $startAt = (Get-Date).AddMinutes(1).AddSeconds(- (Get-Date).Second)
    $trigger = New-ScheduledTaskTrigger -Once -At $startAt
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 2)

    try {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Updates travel time data for Oh My Posh prompt using Google Routes API" | Out-Null
        Write-Host "   ✓ Created scheduled task: $taskName" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create scheduled task: $_"
        return
    }

    # Adjust repetition AFTER registration (approach avoids parameter set conflicts).
    try {
        $isoInterval = 'PT5M'      # ISO 8601 duration for minutes
        $isoDuration = 'P7300D'                            # ~20 years
        $task = Get-ScheduledTask -TaskName $taskName
        if ($task.Triggers.Count -gt 0) {
            $task.Triggers[0].Repetition.Interval = $isoInterval
            $task.Triggers[0].Repetition.Duration = $isoDuration
            $task | Set-ScheduledTask | Out-Null
            Write-Host "   ✓ Set repetition: every 5 min for $isoDuration" -ForegroundColor Green
        }
        else {
            Write-Warning "Could not adjust repetition: no trigger found on task."
        }
    }
    catch {
        Write-Warning "Failed to adjust repetition on scheduled task: $_"
    }
    
    # Create .gitignore entry
    $gitignorePath = "$projectRoot\.gitignore"
    $gitignoreEntries = @(
        "",
        "# Travel time service data and config",
        "data/travel_time.json",
        "scripts/config/travel-config.json"
    )
    
    if (Test-Path $gitignorePath) {
        $existingContent = Get-Content $gitignorePath -ErrorAction SilentlyContinue
        if ($existingContent -notcontains "scripts/config/travel-config.json") {
            Add-Content -Path $gitignorePath -Value ($gitignoreEntries -join "`n")
            Write-Host "   ✓ Updated .gitignore" -ForegroundColor Green
        }
        else {
            Write-Host "   ✓ .gitignore already contains travel time entries" -ForegroundColor Green
        }
    }
    else {
        Set-Content -Path $gitignorePath -Value ($gitignoreEntries -join "`n")
        Write-Host "   ✓ Created .gitignore" -ForegroundColor Green
    }
    
    # Run initial update
    Write-Host ""
    Write-Host "🚀 Running initial travel time update..." -ForegroundColor Yellow
    try {
        & $scriptPath
        Write-Host "   ✓ Initial update completed successfully" -ForegroundColor Green
    }
    catch {
        Write-Warning "Initial update failed: $_"
        Write-Host "   This is normal if you're not currently in the configured active hours." -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                    Installation Complete!                   ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎯 Travel time tracking is now active from $StartTime to $EndTime daily" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 Next steps:" -ForegroundColor Cyan
    Write-Host "   1. Add the travel time segment to your Oh My Posh config" -ForegroundColor White
    Write-Host "   2. Reload your PowerShell profile: . `$PROFILE" -ForegroundColor White
    Write-Host "   3. The prompt will show travel time after $StartTime" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 Management commands:" -ForegroundColor Cyan
    Write-Host "   • View scheduled task: Get-ScheduledTask -TaskName '$taskName'" -ForegroundColor White
    Write-Host "   • Check data file: Get-Content '$projectRoot\data\travel_time.json'" -ForegroundColor White
    Write-Host "   • Manual update: & '$scriptPath'" -ForegroundColor White
    Write-Host ""
}

# Check if running as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script requires Administrator privileges to create scheduled tasks. Please run as Administrator."
    exit 1
}

# Main execution
try {
    Install-TravelTimeService
}
catch {
    Write-Error "Installation failed: $_"
    exit 1
}