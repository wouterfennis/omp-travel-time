#Requires -Version 5.1

<#
.SYNOPSIS
    Updates travel time data using Google Routes API for Oh My Posh prompt integration.

.DESCRIPTION
    This script fetches current travel time to home using Google Routes API and stores
    the result in a JSON file that can be read by Oh My Posh prompt configuration.
    
    The script only fetches data during configured active hours to optimize API usage.

.PARAMETER ConfigPath
    Path to the travel configuration JSON file. Defaults to config\travel-config.json.

.PARAMETER DataPath
    Path where travel time data will be stored. Defaults to ..\data\travel_time.json.

.PARAMETER LogLevel
    Logging level (Error, Warning, Information, Debug). Defaults to Information.

.PARAMETER LogPath
    Path to log file. If not specified, logs to console only.

.EXAMPLE
    .\TravelTimeUpdater.ps1
    
.EXAMPLE
    .\TravelTimeUpdater.ps1 -ConfigPath ".\config\travel-config.json" -DataPath ".\data\travel_time.json"

.EXAMPLE
    .\TravelTimeUpdater.ps1 -LogLevel Debug -LogPath ".\logs\travel-time.log"
#>

param(
    [string]$ConfigPath = "$PSScriptRoot\config\travel-config.json",
    [string]$DataPath = "$PSScriptRoot\..\data\travel_time.json",
    [ValidateSet("Error", "Warning", "Information", "Debug")]
    [string]$LogLevel = "Information",
    [string]$LogPath = $null
)

# Logging Configuration
$script:LogLevels = @{
    "Error" = 1
    "Warning" = 2
    "Information" = 3
    "Debug" = 4
}

$script:CurrentLogLevel = $script:LogLevels[$LogLevel]
$script:CorrelationId = [System.Guid]::NewGuid().ToString().Substring(0, 8)

function Write-Log {
    param(
        [ValidateSet("Error", "Warning", "Information", "Debug")]
        [string]$Level,
        [string]$Message,
        [string]$Category = "General",
        [hashtable]$Properties = @{}
    )
    
    if ($script:LogLevels[$Level] -gt $script:CurrentLogLevel) {
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[{0}] [{1}] [{2}] [{3}] {4}" -f $timestamp, $Level.ToUpper(), $script:CorrelationId, $Category, $Message
    
    # Add properties if provided
    if ($Properties.Count -gt 0) {
        $propertyString = ($Properties.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ", "
        $logEntry += " | $propertyString"
    }
    
    # Output to console with appropriate colors
    $color = switch ($Level) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Information" { "Green" }
        "Debug" { "Cyan" }
    }
    
    Write-Host $logEntry -ForegroundColor $color
    
    # Output to file if LogPath is specified
    if ($LogPath) {
        try {
            $logDir = Split-Path $LogPath -Parent
            if ($logDir -and -not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            Add-Content -Path $LogPath -Value $logEntry -Encoding UTF8
        }
        catch {
            Write-Warning "Failed to write to log file: $_"
        }
    }
}

function Write-ErrorLog { param([string]$Message, [string]$Category = "General", [hashtable]$Properties = @{}) Write-Log -Level "Error" -Message $Message -Category $Category -Properties $Properties }
function Write-WarningLog { param([string]$Message, [string]$Category = "General", [hashtable]$Properties = @{}) Write-Log -Level "Warning" -Message $Message -Category $Category -Properties $Properties }
function Write-InfoLog { param([string]$Message, [string]$Category = "General", [hashtable]$Properties = @{}) Write-Log -Level "Information" -Message $Message -Category $Category -Properties $Properties }
function Write-DebugLog { param([string]$Message, [string]$Category = "General", [hashtable]$Properties = @{}) Write-Log -Level "Debug" -Message $Message -Category $Category -Properties $Properties }

function Measure-ExecutionTime {
    param([scriptblock]$ScriptBlock, [string]$OperationName)
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $result = & $ScriptBlock
        $stopwatch.Stop()
        Write-DebugLog -Message "Operation completed" -Category "Performance" -Properties @{
            Operation = $OperationName
            Duration = "$($stopwatch.ElapsedMilliseconds)ms"
        }
        return $result
    }
    catch {
        $stopwatch.Stop()
        Write-ErrorLog -Message "Operation failed: $($_.Exception.Message)" -Category "Performance" -Properties @{
            Operation = $OperationName
            Duration = "$($stopwatch.ElapsedMilliseconds)ms"
        }
        throw
    }
}

function Get-TravelTimeConfig {
    param([string]$Path)
    
    Write-DebugLog -Message "Loading configuration" -Category "Configuration" -Properties @{ Path = $Path }
    
    if (-not (Test-Path $Path)) {
        Write-ErrorLog -Message "Config file not found. Run Install-TravelTimeService.ps1 first." -Category "Configuration" -Properties @{ Path = $Path }
        return $null
    }
    
    try {
        Write-DebugLog -Message "Reading configuration file" -Category "Configuration"
        $content = Get-Content $Path -Raw
        Write-DebugLog -Message "Parsing JSON configuration" -Category "Configuration" -Properties @{ ContentLength = $content.Length }
        
        $config = $content | ConvertFrom-Json
        
        # Validate required configuration properties
        $requiredProperties = @("google_routes_api_key", "home_address", "start_time", "end_time")
        $missingProperties = @()
        
        foreach ($property in $requiredProperties) {
            if (-not $config.PSObject.Properties.Name.Contains($property)) {
                $missingProperties += $property
            }
        }
        
        if ($missingProperties.Count -gt 0) {
            Write-ErrorLog -Message "Missing required configuration properties" -Category "Configuration" -Properties @{ 
                MissingProperties = ($missingProperties -join ", ")
            }
            return $null
        }
        
        Write-DebugLog -Message "Configuration loaded successfully" -Category "Configuration" -Properties @{
            TravelMode = $config.travel_mode
            RoutingPreference = $config.routing_preference
            UpdateInterval = $config.update_interval_minutes
            ActiveHours = "$($config.start_time) - $($config.end_time)"
        }
        
        return $config
    }
    catch {
        Write-ErrorLog -Message "Invalid JSON in config file: $($_.Exception.Message)" -Category "Configuration" -Properties @{ Path = $Path }
        return $null
    }
}

function Test-ActiveHours {
    param(
        [string]$StartTime,
        [string]$EndTime
    )
    
    Write-DebugLog -Message "Checking active hours" -Category "TimeCheck" -Properties @{
        StartTime = $StartTime
        EndTime = $EndTime
    }
    
    try {
        $current = Get-Date
        $start = [DateTime]::Parse($StartTime)
        $end = [DateTime]::Parse($EndTime)
        
        $currentTime = [DateTime]::Parse($current.ToString("HH:mm"))
        
        $isActive = ($currentTime -ge $start -and $currentTime -le $end)
        
        Write-DebugLog -Message "Active hours check completed" -Category "TimeCheck" -Properties @{
            CurrentTime = $current.ToString("HH:mm")
            StartTime = $StartTime
            EndTime = $EndTime
            IsActive = $isActive
        }
        
        return $isActive
    }
    catch {
        Write-ErrorLog -Message "Error parsing time values: $($_.Exception.Message)" -Category "TimeCheck" -Properties @{
            StartTime = $StartTime
            EndTime = $EndTime
        }
        return $false
    }
}

function Get-CurrentLocation {
    <#
    .SYNOPSIS
        Gets current location using IP geolocation service.
    
    .DESCRIPTION
        Uses a free IP geolocation service to determine current location.
        Falls back to a default location if the service is unavailable.
    #>
    
    Write-DebugLog -Message "Starting geolocation request" -Category "Geolocation"
    
    try {
        # Using ip-api.com free service (1000 requests/month)
        $apiUrl = "https://ip-api.com/json/"
        Write-DebugLog -Message "Calling geolocation API" -Category "Geolocation" -Properties @{ 
            ApiUrl = $apiUrl
            Timeout = "10s"
        }
        
        $response = Measure-ExecutionTime -OperationName "GeolocationAPI" -ScriptBlock {
            Invoke-RestMethod -Uri $apiUrl -TimeoutSec 10
        }
        
        Write-DebugLog -Message "Geolocation API response received" -Category "Geolocation" -Properties @{
            Status = $response.status
            Country = $response.country
            Region = $response.regionName
            City = $response.city
            ISP = $response.isp
        }
        
        if ($response.status -eq "success") {
            $result = @{
                Latitude = $response.lat
                Longitude = $response.lon
                Success = $true
                City = $response.city
                Region = $response.regionName
            }
            
            Write-DebugLog -Message "Geolocation successful" -Category "Geolocation" -Properties @{
                Latitude = $result.Latitude
                Longitude = $result.Longitude
                Location = "$($result.City), $($result.Region)"
            }
            
            return $result
        }
        else {
            throw "Geolocation service returned: $($response.status)"
        }
    }
    catch {
        Write-DebugLog -Message "Geolocation failed, using fallback" -Category "Geolocation" -Properties @{
            Error = $_.Exception.Message
            FallbackLocation = "New York City, NY, USA"
        }
        
        Write-WarningLog -Message "Could not get current location: $($_.Exception.Message). Using fallback location." -Category "Geolocation"
        
        # Fallback coordinates represent New York City, NY, USA.
        # New York City is chosen as a default because it is a well-known, central location commonly used in geolocation services.
        return @{
            Latitude = 40.7128
            Longitude = -74.0060
            Success = $true
            City = "Unknown"
            Region = "Unknown"
        }
    }
}

function Get-TravelTimeRoutes {
    param(
        [string]$ApiKey,
        [double]$OriginLat,
        [double]$OriginLng,
        [string]$Destination,
        [string]$TravelMode = "DRIVE",
        [string]$RoutingPreference = "TRAFFIC_AWARE"
    )
    
    Write-DebugLog -Message "Preparing Routes API request" -Category "RoutesAPI" -Properties @{
        OriginLat = $OriginLat
        OriginLng = $OriginLng
        Destination = $Destination
        TravelMode = $TravelMode
        RoutingPreference = $RoutingPreference
    }
    
    try {
        $url = "https://routes.googleapis.com/directions/v2:computeRoutes"
        
        $requestBody = @{
            origin = @{
                location = @{
                    latLng = @{
                        latitude = $OriginLat
                        longitude = $OriginLng
                    }
                }
            }
            destination = @{
                address = $Destination
            }
            travelMode = $TravelMode
            routingPreference = $RoutingPreference
            computeAlternativeRoutes = $false
            routeModifiers = @{
                avoidTolls = $false
                avoidHighways = $false
                avoidFerries = $false
            }
            languageCode = "en-US"
            units = "METRIC"
        }
        
        $requestBodyJson = $requestBody | ConvertTo-Json -Depth 10
        
        Write-DebugLog -Message "Request body prepared" -Category "RoutesAPI" -Properties @{
            RequestSize = $requestBodyJson.Length
            URL = $url
        }
        
        $headers = @{
            'Content-Type' = 'application/json'
            'X-Goog-Api-Key' = $ApiKey.Substring(0, [Math]::Min(8, $ApiKey.Length)) + "***"  # Log only first 8 chars for security
            'X-Goog-FieldMask' = 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline'
        }
        
        Write-DebugLog -Message "Making Routes API request" -Category "RoutesAPI" -Properties @{
            HeaderCount = $headers.Count
            Timeout = "30s"
        }
        
        $response = Measure-ExecutionTime -OperationName "RoutesAPI" -ScriptBlock {
            $actualHeaders = @{
                'Content-Type' = 'application/json'
                'X-Goog-Api-Key' = $ApiKey
                'X-Goog-FieldMask' = 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline'
            }
            Invoke-RestMethod -Uri $url -Method Post -Body $requestBodyJson -Headers $actualHeaders -TimeoutSec 30
        }
        
        Write-DebugLog -Message "Routes API response received" -Category "RoutesAPI" -Properties @{
            RoutesCount = if ($response.routes) { $response.routes.Count } else { 0 }
        }
        
        if ($response.routes -and $response.routes.Count -gt 0) {
            $route = $response.routes[0]
            
            Write-DebugLog -Message "Processing route data" -Category "DataProcessing" -Properties @{
                RawDuration = $route.duration
                RawDistance = $route.distanceMeters
            }
            
            $durationSeconds = [int]($route.duration -replace 's$', '')
            $durationMinutes = [math]::Round($durationSeconds / 60)
            $distanceKm = [math]::Round($route.distanceMeters / 1000, 1)
            
            # Estimate traffic conditions based on duration
            # This is a simplified approach since Routes API doesn't directly provide traffic status
            $trafficStatus = if ($durationMinutes -gt 45) { "heavy" } 
                           elseif ($durationMinutes -gt 30) { "moderate" } 
                           else { "light" }
            
            Write-DebugLog -Message "Route calculations completed" -Category "DataProcessing" -Properties @{
                DurationSeconds = $durationSeconds
                DurationMinutes = $durationMinutes
                DistanceKm = $distanceKm
                TrafficStatus = $trafficStatus
            }
            
            $result = @{
                Success = $true
                TravelTimeMinutes = $durationMinutes
                DistanceKm = $distanceKm
                TrafficStatus = $trafficStatus
                DurationText = "{0}h {1}m" -f [math]::Floor($durationMinutes / 60), ($durationMinutes % 60)
            }
            
            Write-DebugLog -Message "Route processing successful" -Category "RoutesAPI" -Properties @{
                TravelTime = "$($result.TravelTimeMinutes) minutes"
                Distance = "$($result.DistanceKm) km"
                Traffic = $result.TrafficStatus
                FormattedDuration = $result.DurationText
            }
            
            return $result
        }
        else {
            Write-WarningLog -Message "No routes found in API response" -Category "RoutesAPI"
            return @{
                Success = $false
                Error = "No routes found"
            }
        }
    }
    catch {
        $errorMessage = if ($_.Exception.Response) {
            try {
                Write-DebugLog -Message "Processing API error response" -Category "RoutesAPI" -Properties @{
                    StatusCode = $_.Exception.Response.StatusCode
                }
                
                $errorStream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorStream)
                $errorBody = $reader.ReadToEnd()
                $errorObj = $errorBody | ConvertFrom-Json
                
                Write-DebugLog -Message "API error details" -Category "RoutesAPI" -Properties @{
                    ErrorCode = $errorObj.error.code
                    ErrorMessage = $errorObj.error.message
                }
                
                "API Error: $($errorObj.error.message)"
            }
            catch {
                Write-DebugLog -Message "Failed to parse error response" -Category "RoutesAPI" -Properties @{
                    StatusCode = $_.Exception.Response.StatusCode
                }
                "HTTP Error: $($_.Exception.Response.StatusCode)"
            }
        }
        else {
            Write-DebugLog -Message "Network or general error" -Category "RoutesAPI" -Properties @{
                ExceptionType = $_.Exception.GetType().Name
            }
            $_.Exception.Message
        }
        
        Write-ErrorLog -Message "Routes API request failed: $errorMessage" -Category "RoutesAPI"
        
        return @{
            Success = $false
            Error = $errorMessage
        }
    }
}

function Update-TravelTimeData {
    param(
        [string]$ConfigPath,
        [string]$DataPath
    )
    
    Write-InfoLog -Message "Starting travel time update cycle" -Category "Cycle" -Properties @{
        ConfigPath = $ConfigPath
        DataPath = $DataPath
        CorrelationId = $script:CorrelationId
    }
    
    $config = Get-TravelTimeConfig -Path $ConfigPath
    if (-not $config) { 
        Write-ErrorLog -Message "Failed to load configuration, aborting cycle" -Category "Cycle"
        return 
    }
    
    Write-DebugLog -Message "Configuration loaded successfully" -Category "Cycle"
    
    $isActiveHours = Test-ActiveHours -StartTime $config.start_time -EndTime $config.end_time
    
    # Ensure data directory exists
    $dataDir = Split-Path $DataPath -Parent
    Write-DebugLog -Message "Ensuring data directory exists" -Category "FileOperation" -Properties @{
        DataDirectory = $dataDir
    }
    
    if (-not (Test-Path $dataDir)) {
        Write-DebugLog -Message "Creating data directory" -Category "FileOperation" -Properties @{
            DataDirectory = $dataDir
        }
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
    
    $result = @{
        last_updated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        travel_time_minutes = $null
        distance_km = $null
        traffic_status = $null
        travel_mode = $config.travel_mode
        error = $null
        is_active_hours = $isActiveHours
        active_period = "$($config.start_time) - $($config.end_time)"
    }
    
    Write-DebugLog -Message "Result object initialized" -Category "DataProcessing" -Properties @{
        TravelMode = $result.travel_mode
        ActivePeriod = $result.active_period
        IsActiveHours = $isActiveHours
    }
    
    if ($isActiveHours) {
        Write-InfoLog -Message "Active hours detected, fetching travel time data" -Category "Cycle" -Properties @{
            ActivePeriod = "$($config.start_time) - $($config.end_time)"
        }
        
        $location = Get-CurrentLocation
        
        if ($location.Success) {
            Write-InfoLog -Message "Current location obtained" -Category "Geolocation" -Properties @{
                Location = "$($location.City), $($location.Region)"
                Coordinates = "$($location.Latitude), $($location.Longitude)"
            }
            
            $travelData = Get-TravelTimeRoutes -ApiKey $config.google_routes_api_key -OriginLat $location.Latitude -OriginLng $location.Longitude -Destination $config.home_address -TravelMode $config.travel_mode -RoutingPreference $config.routing_preference
            
            if ($travelData.Success) {
                $result.travel_time_minutes = $travelData.TravelTimeMinutes
                $result.distance_km = $travelData.DistanceKm
                $result.traffic_status = $travelData.TrafficStatus
                
                Write-InfoLog -Message "Travel time data updated successfully" -Category "Cycle" -Properties @{
                    TravelTime = "$($travelData.TravelTimeMinutes) minutes"
                    Distance = "$($travelData.DistanceKm) km"
                    Traffic = $travelData.TrafficStatus
                    FormattedDuration = $travelData.DurationText
                }
            }
            else {
                $result.error = $travelData.Error
                Write-ErrorLog -Message "Travel time fetch failed" -Category "Cycle" -Properties @{
                    Error = $travelData.Error
                }
            }
        }
        else {
            $result.error = "Could not get location: $($location.Error)"
            Write-ErrorLog -Message "Location detection failed" -Category "Cycle" -Properties @{
                Error = $location.Error
            }
        }
    }
    else {
        Write-InfoLog -Message "Outside active hours, skipping travel time update" -Category "Cycle" -Properties @{
            CurrentTime = (Get-Date).ToString("HH:mm")
            ActivePeriod = "$($config.start_time) - $($config.end_time)"
        }
    }
    
    # Write result to file
    Write-DebugLog -Message "Writing result to data file" -Category "FileOperation" -Properties @{
        DataPath = $DataPath
        HasError = ($result.error -ne $null)
        HasTravelData = ($result.travel_time_minutes -ne $null)
    }
    
    try {
        $jsonResult = $result | ConvertTo-Json -Depth 2
        Write-DebugLog -Message "JSON serialization completed" -Category "FileOperation" -Properties @{
            JsonLength = $jsonResult.Length
        }
        
        Measure-ExecutionTime -OperationName "FileWrite" -ScriptBlock {
            $jsonResult | Set-Content -Path $DataPath -Encoding UTF8
        }
        
        Write-DebugLog -Message "Data file written successfully" -Category "FileOperation" -Properties @{
            DataPath = $DataPath
        }
        
        Write-InfoLog -Message "Travel time update cycle completed successfully" -Category "Cycle" -Properties @{
            DataPath = $DataPath
            UpdateStatus = if ($result.error) { "Failed" } elseif ($result.travel_time_minutes) { "Success" } else { "Skipped" }
        }
    }
    catch {
        Write-ErrorLog -Message "Failed to write data file" -Category "FileOperation" -Properties @{
            DataPath = $DataPath
            Error = $_.Exception.Message
        }
    }
}

# Main execution
try {
    Write-InfoLog -Message "TravelTimeUpdater script started" -Category "Main" -Properties @{
        Version = "Enhanced Logging v1.0"
        LogLevel = $LogLevel
        LogPath = if ($LogPath) { $LogPath } else { "Console Only" }
        CorrelationId = $script:CorrelationId
    }
    
    Write-DebugLog -Message "Script parameters" -Category "Main" -Properties @{
        ConfigPath = $ConfigPath
        DataPath = $DataPath
        LogLevel = $LogLevel
        LogPath = $LogPath
    }
    
    Update-TravelTimeData -ConfigPath $ConfigPath -DataPath $DataPath
    
    Write-InfoLog -Message "TravelTimeUpdater script completed successfully" -Category "Main"
}
catch {
    Write-ErrorLog -Message "Script execution failed" -Category "Main" -Properties @{
        Error = $_.Exception.Message
        ScriptLine = $_.InvocationInfo.ScriptLineNumber
        StackTrace = $_.ScriptStackTrace
    }
    exit 1
}