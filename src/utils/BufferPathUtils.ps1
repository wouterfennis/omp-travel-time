#Requires -Version 5.1

<#
.SYNOPSIS
    Buffer file path utilities for the Travel Time system.

.DESCRIPTION
    This module provides functions for resolving and validating buffer file paths
    with support for multiple configuration methods and OS-specific defaults.
#>

function Get-BufferFilePath {
    <#
    .SYNOPSIS
        Resolves the buffer file path based on configuration hierarchy.
    
    .DESCRIPTION
        Determines the buffer file path using the following priority order:
        1. Command-line parameter (if provided)
        2. Environment variable (OMP_TRAVEL_TIME_DATA_PATH)
        3. OS-specific default location
    
    .PARAMETER DataPath
        Explicit data path from command-line parameter.
    
    .OUTPUTS
        String containing the resolved buffer file path.
    
    .EXAMPLE
        $path = Get-BufferFilePath -Config $config
    
    .EXAMPLE
        $path = Get-BufferFilePath -DataPath "C:\MyData\travel.json" -Config $config
    #>
    param(
        [string]$DataPath
    )
    
    # Priority 1: Explicit command-line parameter
    if (-not [string]::IsNullOrWhiteSpace($DataPath)) {
        Write-Verbose "Using explicit data path: $DataPath"
        return $DataPath
    }
    
    # Priority 2: Environment variable
    $envPath = [Environment]::GetEnvironmentVariable('OMP_TRAVEL_TIME_DATA_PATH')
    if (-not [string]::IsNullOrWhiteSpace($envPath)) {
        Write-Verbose "Using environment variable path: $envPath"
        return $envPath
    }
    
    # Priority 3: OS-specific default location
    $defaultPath = Get-DefaultBufferFilePath
    Write-Verbose "Using OS default path: $defaultPath"
    return $defaultPath
}

function Get-DefaultBufferFilePath {
    <#
    .SYNOPSIS
        Gets the OS-specific default buffer file path.
    
    .DESCRIPTION
        Returns the appropriate default location for the buffer file based on
        operating system conventions and user data directory standards.
    
    .OUTPUTS
        String containing the default buffer file path.
    
    .EXAMPLE
        $defaultPath = Get-DefaultBufferFilePath
    #>
    
    $fileName = "travel_time.json"
    
    if ($IsWindows -or [Environment]::OSVersion.Platform -eq "Win32NT" -or $env:OS -eq "Windows_NT") {
        # Windows: Use %LOCALAPPDATA%\OhMyPosh\TravelTime\
        $userDataPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
        $appDataPath = Join-Path $userDataPath "OhMyPosh\TravelTime"
    }
    elseif ($IsLinux -or [Environment]::OSVersion.Platform -eq "Unix") {
        # Linux: Use ~/.local/share/omp-travel-time/
        $userHome = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
        if ([string]::IsNullOrEmpty($userHome)) {
            $userHome = $env:HOME
        }
        $appDataPath = Join-Path $userHome ".local/share/omp-travel-time"
    }
    elseif ($IsMacOS) {
        # macOS: Use ~/Library/Application Support/OhMyPosh/TravelTime/
        $userHome = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
        if ([string]::IsNullOrEmpty($userHome)) {
            $userHome = $env:HOME
        }
        $appDataPath = Join-Path $userHome "Library/Application Support/OhMyPosh/TravelTime"
    }
    else {
        # Fallback: Use current directory relative path for unknown platforms
        $scriptRoot = $PSScriptRoot
        if ([string]::IsNullOrEmpty($scriptRoot)) {
            $scriptRoot = Get-Location
        }
        $appDataPath = Join-Path (Split-Path (Split-Path $scriptRoot -Parent) -Parent) "data"
    }
    
    return Join-Path $appDataPath $fileName
}

function Test-BufferFilePathAccess {
    <#
    .SYNOPSIS
        Validates a buffer file path for accessibility and permissions.
    
    .DESCRIPTION
        Checks if the specified path is valid and the directory is writable.
        Creates the directory if it doesn't exist and has appropriate permissions.
    
    .PARAMETER Path
        The buffer file path to validate.
    
    .OUTPUTS
        Hashtable containing validation results with keys:
        - IsValid: Boolean indicating if path is accessible
        - Issues: Array of validation issues found
        - DirectoryCreated: Boolean indicating if directory was created
    
    .EXAMPLE
        $result = Test-BufferFilePathAccess -Path "C:\Data\travel_time.json"
    #>
    param([string]$Path)
    
    $result = @{
        IsValid = $true
        Issues = @()
        DirectoryCreated = $false
    }
    
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $result.IsValid = $false
        $result.Issues += "Path cannot be empty"
        return $result
    }
    
    try {
        # Resolve to absolute path
        $absolutePath = [System.IO.Path]::GetFullPath($Path)
        $directory = [System.IO.Path]::GetDirectoryName($absolutePath)
        
        # Check if directory exists, create if necessary
        if (-not (Test-Path $directory)) {
            try {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
                $result.DirectoryCreated = $true
                Write-Verbose "Created directory: $directory"
            }
            catch {
                $result.IsValid = $false
                $result.Issues += "Cannot create directory '$directory': $($_.Exception.Message)"
                return $result
            }
        }
        
        # Test write permissions by attempting to create a temporary file
        $testFile = Join-Path $directory "test_permissions.tmp"
        try {
            "test" | Set-Content -Path $testFile -ErrorAction Stop
            Remove-Item $testFile -ErrorAction SilentlyContinue
        }
        catch {
            $result.IsValid = $false
            $result.Issues += "No write permission to directory '$directory': $($_.Exception.Message)"
            return $result
        }
        
        # Check if path is too long
        if ($absolutePath.Length -gt 260) {
            $result.Issues += "Path may be too long for some operations (>260 characters)"
            # This is a warning, not a failure
        }
        
    }
    catch {
        $result.IsValid = $false
        $result.Issues += "Invalid path '$Path': $($_.Exception.Message)"
    }
    
    return $result
}

function Convert-ToAbsolutePath {
    <#
    .SYNOPSIS
        Converts a relative path to an absolute path.
    
    .DESCRIPTION
        Resolves relative paths relative to the project root or current directory.
        If the path is already absolute, returns it unchanged.
    
    .PARAMETER Path
        The path to convert (may be relative or absolute).
    
    .PARAMETER ProjectRoot
        The project root directory for resolving relative paths.
    
    .OUTPUTS
        String containing the absolute path.
    
    .EXAMPLE
        $absolutePath = Convert-ToAbsolutePath -Path ".\data\travel_time.json" -ProjectRoot "C:\Project"
    #>
    param(
        [string]$Path,
        [string]$ProjectRoot
    )
    
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }
    
    # If already absolute, return as-is
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    
    # For relative paths, resolve against project root if provided
    if (-not [string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $basePath = $ProjectRoot
    }
    else {
        # Fallback to current directory
        $basePath = Get-Location
    }
    
    $combinedPath = Join-Path $basePath $Path
    return [System.IO.Path]::GetFullPath($combinedPath)
}