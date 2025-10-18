#Requires -Version 5.1

<#
.SYNOPSIS
    Uninstalls and removes the Oh My Posh Travel Time service.

.DESCRIPTION
    This script provides comprehensive removal of the travel time tracking service for Oh My Posh prompts.
    It can remove scheduled tasks, configuration files, data files, and clean up the environment
    with options to preserve user data and configurations.

.PARAMETER Silent
    Run uninstallation silently without user prompts. Uses default removal options.

.PARAMETER PreserveConfig
    Preserve configuration files during uninstallation.

.PARAMETER PreserveData
    Preserve data files and logs during uninstallation.

.PARAMETER Force
    Force removal of all components without confirmation prompts.

.PARAMETER WhatIf
    Show what would be removed without actually performing the uninstallation.

.EXAMPLE
    .\Uninstall-TravelTimeService.ps1
    Interactive uninstallation with user prompts
    
.EXAMPLE
    .\Uninstall-TravelTimeService.ps1 -Silent
    Silent uninstallation with default settings
    
.EXAMPLE
    .\Uninstall-TravelTimeService.ps1 -PreserveConfig -PreserveData
    Remove service but preserve configuration and data files
    
.EXAMPLE
    .\Uninstall-TravelTimeService.ps1 -WhatIf
    Preview what would be removed without making changes

.NOTES
    - Requires Administrator privileges to remove scheduled tasks
    - Provides options to preserve user data and configurations
    - Safe handling of Oh My Posh configuration (guidance only)
    - Comprehensive logging of uninstallation process
#>

param(
    [switch]$Silent,
    [switch]$PreserveConfig,
    [switch]$PreserveData,
    [switch]$Force,
    [switch]$WhatIf
)

# Global variables for tracking removal operations
$global:UninstallLog = @()
$global:RemovedComponents = @()
$global:PreservedComponents = @()
$global:FailedRemovals = @()

function Write-UninstallLog {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    $global:UninstallLog += $logEntry
    
    switch ($Level) {
        "Error" { Write-Host "   ❌ $Message" -ForegroundColor Red }
        "Warning" { Write-Host "   ⚠️  $Message" -ForegroundColor Yellow }
        "Success" { Write-Host "   ✓ $Message" -ForegroundColor Green }
        "Info" { Write-Host "   • $Message" -ForegroundColor White }
        default { Write-Host "   • $Message" -ForegroundColor White }
    }
}

function Test-AdministratorPrivileges {
    try {
        if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        }
        else {
            # On non-Windows platforms, assume privileges are adequate
            return $true
        }
    }
    catch {
        # If we can't determine privileges, assume they're adequate and let the operation fail if needed
        return $true
    }
}

function Get-UserConfirmation {
    param(
        [string]$Message,
        [string]$DefaultChoice = "Y"
    )
    
    if ($Silent -or $Force) {
        return $true
    }
    
    $choice = Read-Host "$Message [$DefaultChoice/n]"
    return ($choice -eq "" -and $DefaultChoice -eq "Y") -or ($choice -eq "Y" -or $choice -eq "y")
}

function Remove-ScheduledTask {
    param([string]$TaskName)
    
    Write-UninstallLog "Checking for scheduled task: $TaskName"
    
    if ($WhatIf) {
        Write-UninstallLog "Would remove scheduled task: $TaskName" "Info"
        return $true
    }
    
    try {
        $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            if (Get-UserConfirmation "Remove scheduled task '$TaskName'?") {
                Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
                Write-UninstallLog "Removed scheduled task: $TaskName" "Success"
                $global:RemovedComponents += "Scheduled Task: $TaskName"
                return $true
            }
            else {
                Write-UninstallLog "Scheduled task preserved: $TaskName" "Info"
                $global:PreservedComponents += "Scheduled Task: $TaskName"
                return $false
            }
        }
        else {
            Write-UninstallLog "Scheduled task not found: $TaskName" "Info"
            return $true
        }
    }
    catch {
        Write-UninstallLog "Failed to remove scheduled task '$TaskName': $_" "Error"
        $global:FailedRemovals += "Scheduled Task: $TaskName - $_"
        return $false
    }
}

function Remove-ConfigurationFiles {
    param(
        [string]$ProjectRoot,
        [bool]$Preserve = $false
    )
    
    $configPath = "$ProjectRoot\scripts\config\travel-config.json"
    $configDir = "$ProjectRoot\scripts\config"
    
    Write-UninstallLog "Checking configuration files"
    
    if ($WhatIf) {
        if (Test-Path $configPath) {
            if ($Preserve) {
                Write-UninstallLog "Would preserve configuration file: $configPath" "Info"
            }
            else {
                Write-UninstallLog "Would remove configuration file: $configPath" "Info"
            }
        }
        return $true
    }
    
    if (Test-Path $configPath) {
        if ($Preserve) {
            Write-UninstallLog "Configuration file preserved: $configPath" "Info"
            $global:PreservedComponents += "Configuration: $configPath"
            return $true
        }
        
        if (Get-UserConfirmation "Remove configuration file '$configPath'?") {
            try {
                Remove-Item $configPath -Force
                Write-UninstallLog "Removed configuration file: $configPath" "Success"
                $global:RemovedComponents += "Configuration: $configPath"
                
                # Remove config directory if empty
                if ((Test-Path $configDir) -and ((Get-ChildItem $configDir).Count -eq 0)) {
                    Remove-Item $configDir -Force
                    Write-UninstallLog "Removed empty configuration directory: $configDir" "Success"
                    $global:RemovedComponents += "Directory: $configDir"
                }
                return $true
            }
            catch {
                Write-UninstallLog "Failed to remove configuration file '$configPath': $_" "Error"
                $global:FailedRemovals += "Configuration: $configPath - $_"
                return $false
            }
        }
        else {
            Write-UninstallLog "Configuration file preserved: $configPath" "Info"
            $global:PreservedComponents += "Configuration: $configPath"
            return $false
        }
    }
    else {
        Write-UninstallLog "Configuration file not found: $configPath" "Info"
        return $true
    }
}

function Remove-DataFiles {
    param(
        [string]$ProjectRoot,
        [bool]$Preserve = $false
    )
    
    $dataPath = "$ProjectRoot\data\travel_time.json"
    $dataDir = "$ProjectRoot\data"
    
    Write-UninstallLog "Checking data files"
    
    if ($WhatIf) {
        if (Test-Path $dataPath) {
            if ($Preserve) {
                Write-UninstallLog "Would preserve data file: $dataPath" "Info"
            }
            else {
                Write-UninstallLog "Would remove data file: $dataPath" "Info"
            }
        }
        if (Test-Path $dataDir) {
            if ($Preserve) {
                Write-UninstallLog "Would preserve data directory: $dataDir" "Info"
            }
            else {
                Write-UninstallLog "Would remove data directory: $dataDir" "Info"
            }
        }
        return $true
    }
    
    if (Test-Path $dataPath) {
        if ($Preserve) {
            Write-UninstallLog "Data file preserved: $dataPath" "Info"
            $global:PreservedComponents += "Data: $dataPath"
            return $true
        }
        
        if (Get-UserConfirmation "Remove data file '$dataPath'?") {
            try {
                Remove-Item $dataPath -Force
                Write-UninstallLog "Removed data file: $dataPath" "Success"
                $global:RemovedComponents += "Data: $dataPath"
            }
            catch {
                Write-UninstallLog "Failed to remove data file '$dataPath': $_" "Error"
                $global:FailedRemovals += "Data: $dataPath - $_"
                return $false
            }
        }
        else {
            Write-UninstallLog "Data file preserved: $dataPath" "Info"
            $global:PreservedComponents += "Data: $dataPath"
            return $false
        }
    }
    else {
        Write-UninstallLog "Data file not found: $dataPath" "Info"
    }
    
    # Handle data directory
    if (Test-Path $dataDir) {
        $dataFiles = Get-ChildItem $dataDir -Force
        if ($dataFiles.Count -eq 0) {
            if (-not $Preserve -and (Get-UserConfirmation "Remove empty data directory '$dataDir'?")) {
                try {
                    Remove-Item $dataDir -Force
                    Write-UninstallLog "Removed empty data directory: $dataDir" "Success"
                    $global:RemovedComponents += "Directory: $dataDir"
                }
                catch {
                    Write-UninstallLog "Failed to remove data directory '$dataDir': $_" "Error"
                    $global:FailedRemovals += "Directory: $dataDir - $_"
                    return $false
                }
            }
            else {
                Write-UninstallLog "Data directory preserved: $dataDir" "Info"
                $global:PreservedComponents += "Directory: $dataDir"
            }
        }
        else {
            Write-UninstallLog "Data directory contains files, preserved: $dataDir" "Info"
            $global:PreservedComponents += "Directory: $dataDir (contains files)"
        }
    }
    
    return $true
}

function Clean-GitIgnoreEntries {
    param([string]$ProjectRoot)
    
    $gitignorePath = "$ProjectRoot\.gitignore"
    
    Write-UninstallLog "Checking .gitignore entries"
    
    if ($WhatIf) {
        if (Test-Path $gitignorePath) {
            Write-UninstallLog "Would clean travel time entries from .gitignore" "Info"
        }
        return $true
    }
    
    if (-not (Test-Path $gitignorePath)) {
        Write-UninstallLog ".gitignore file not found" "Info"
        return $true
    }
    
    try {
        $content = Get-Content $gitignorePath
        $travelTimeEntries = @(
            "# Travel time service data and config",
            "data/travel_time.json",
            "scripts/config/travel-config.json"
        )
        
        $hasEntries = $false
        foreach ($entry in $travelTimeEntries) {
            if ($content -contains $entry) {
                $hasEntries = $true
                break
            }
        }
        
        if ($hasEntries) {
            if (Get-UserConfirmation "Remove travel time entries from .gitignore?") {
                $newContent = $content | Where-Object { $_ -notin $travelTimeEntries }
                # Remove empty lines that might be left behind
                $newContent = $newContent | Where-Object { $_.Trim() -ne "" -or $_ -eq $newContent[-1] }
                
                Set-Content $gitignorePath -Value $newContent
                Write-UninstallLog "Cleaned travel time entries from .gitignore" "Success"
                $global:RemovedComponents += "GitIgnore entries"
                return $true
            }
            else {
                Write-UninstallLog ".gitignore entries preserved" "Info"
                $global:PreservedComponents += "GitIgnore entries"
                return $false
            }
        }
        else {
            Write-UninstallLog "No travel time entries found in .gitignore" "Info"
            return $true
        }
    }
    catch {
        Write-UninstallLog "Failed to clean .gitignore entries: $_" "Error"
        $global:FailedRemovals += "GitIgnore entries - $_"
        return $false
    }
}

function Show-OhMyPoshGuidance {
    Write-Host ""
    Write-Host "📋 Oh My Posh Configuration Guidance:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "The travel time service has been removed, but you may need to manually update" -ForegroundColor White
    Write-Host "your Oh My Posh configuration to remove the travel time segment." -ForegroundColor White
    Write-Host ""
    Write-Host "Steps to clean up your Oh My Posh config:" -ForegroundColor Yellow
    Write-Host "   1. Open your Oh My Posh configuration file (usually in your PowerShell profile)" -ForegroundColor White
    Write-Host "   2. Look for a travel time segment that references 'data/travel_time.json'" -ForegroundColor White
    Write-Host "   3. Remove or comment out the travel time segment" -ForegroundColor White
    Write-Host "   4. Reload your PowerShell profile: . `$PROFILE" -ForegroundColor White
    Write-Host ""
    Write-Host "Example segment to look for and remove:" -ForegroundColor Gray
    Write-Host '   {' -ForegroundColor DarkGray
    Write-Host '     "type": "command",' -ForegroundColor DarkGray
    Write-Host '     "style": "diamond",' -ForegroundColor DarkGray
    Write-Host '     "template": "{{ .Output }}",' -ForegroundColor DarkGray
    Write-Host '     "properties": {' -ForegroundColor DarkGray
    Write-Host '       "command": "pwsh -c \"Get-Content data/travel_time.json | ConvertFrom-Json | Select-Object -ExpandProperty display_text\""' -ForegroundColor DarkGray
    Write-Host '     }' -ForegroundColor DarkGray
    Write-Host '   }' -ForegroundColor DarkGray
    Write-Host ""
}

function Write-UninstallSummary {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    Uninstallation Summary                   ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    if ($global:RemovedComponents.Count -gt 0) {
        Write-Host "🗑️  Components Removed:" -ForegroundColor Green
        foreach ($component in $global:RemovedComponents) {
            Write-Host "   ✓ $component" -ForegroundColor Green
        }
        Write-Host ""
    }
    
    if ($global:PreservedComponents.Count -gt 0) {
        Write-Host "💾 Components Preserved:" -ForegroundColor Yellow
        foreach ($component in $global:PreservedComponents) {
            Write-Host "   • $component" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    if ($global:FailedRemovals.Count -gt 0) {
        Write-Host "❌ Failed Removals:" -ForegroundColor Red
        foreach ($failure in $global:FailedRemovals) {
            Write-Host "   • $failure" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    # Save uninstall log
    $logPath = "$PSScriptRoot\..\data\uninstall.log"
    try {
        $logDir = Split-Path $logPath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $global:UninstallLog | Set-Content $logPath
        Write-Host "📝 Uninstall log saved to: $logPath" -ForegroundColor Cyan
    }
    catch {
        Write-Host "⚠️  Could not save uninstall log: $_" -ForegroundColor Yellow
    }
}

function Uninstall-TravelTimeService {
    $scriptRoot = $PSScriptRoot
    $projectRoot = Split-Path $scriptRoot -Parent
    
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║              Oh My Posh Travel Time Service                 ║" -ForegroundColor Red
    Write-Host "║                   Uninstallation Wizard                     ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    
    if ($WhatIf) {
        Write-Host "🔍 PREVIEW MODE - No changes will be made" -ForegroundColor Cyan
        Write-Host ""
    }
    
    Write-UninstallLog "Starting Travel Time Service uninstallation"
    Write-UninstallLog "Project root: $projectRoot"
    Write-UninstallLog "Script parameters: Silent=$Silent, PreserveConfig=$PreserveConfig, PreserveData=$PreserveData, Force=$Force, WhatIf=$WhatIf"
    
    # Check administrator privileges for scheduled task removal
    $isAdmin = Test-AdministratorPrivileges
    if (-not $isAdmin) {
        Write-UninstallLog "Administrator privileges required for scheduled task removal" "Warning"
        if (-not $WhatIf) {
            Write-Host "⚠️  Some operations require Administrator privileges." -ForegroundColor Yellow
            Write-Host "   Run as Administrator for complete uninstallation." -ForegroundColor Yellow
            Write-Host ""
        }
    }
    
    # Display removal plan
    if (-not $Silent -and -not $WhatIf) {
        Write-Host "📋 Uninstallation Plan:" -ForegroundColor Cyan
        Write-Host "   • Remove scheduled task: OhMyPosh-TravelTime" -ForegroundColor White
        if (-not $PreserveConfig) {
            Write-Host "   • Remove configuration files" -ForegroundColor White
        } else {
            Write-Host "   • Preserve configuration files" -ForegroundColor Yellow
        }
        if (-not $PreserveData) {
            Write-Host "   • Remove data files and directories" -ForegroundColor White
        } else {
            Write-Host "   • Preserve data files and directories" -ForegroundColor Yellow
        }
        Write-Host "   • Clean .gitignore entries (optional)" -ForegroundColor White
        Write-Host "   • Provide Oh My Posh configuration guidance" -ForegroundColor White
        Write-Host ""
        
        if (-not (Get-UserConfirmation "Continue with uninstallation?")) {
            Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
            return
        }
        Write-Host ""
    }
    
    Write-Host "🗑️  Removing Travel Time Service components..." -ForegroundColor Red
    Write-Host ""
    
    # Remove scheduled task
    if ($isAdmin -or $WhatIf) {
        Remove-ScheduledTask -TaskName "OhMyPosh-TravelTime"
    }
    else {
        Write-UninstallLog "Skipping scheduled task removal (requires Administrator privileges)" "Warning"
    }
    
    # Remove configuration files
    Remove-ConfigurationFiles -ProjectRoot $projectRoot -Preserve $PreserveConfig
    
    # Remove data files
    Remove-DataFiles -ProjectRoot $projectRoot -Preserve $PreserveData
    
    # Clean .gitignore entries
    Clean-GitIgnoreEntries -ProjectRoot $projectRoot
    
    # Show summary
    if (-not $WhatIf) {
        Write-UninstallSummary
        Show-OhMyPoshGuidance
        
        $successCount = $global:RemovedComponents.Count
        $failureCount = $global:FailedRemovals.Count
        
        if ($failureCount -eq 0) {
            Write-Host "✅ Uninstallation completed successfully!" -ForegroundColor Green
        }
        elseif ($successCount -gt 0) {
            Write-Host "⚠️  Uninstallation completed with some issues. See summary above." -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ Uninstallation failed. See summary above." -ForegroundColor Red
        }
    }
    else {
        Write-Host "🔍 Preview completed. Use without -WhatIf to perform actual uninstallation." -ForegroundColor Cyan
    }
    
    Write-UninstallLog "Uninstallation process completed"
}

# Main execution
try {
    Uninstall-TravelTimeService
}
catch {
    Write-UninstallLog "Uninstallation failed with exception: $_" "Error"
    Write-Error "Uninstallation failed: $_"
    exit 1
}