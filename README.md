# Oh My Posh Travel Time Integration

This project adds real-time travel time display to your
Oh My Posh PowerShell prompt using the Google Routes API.
The travel time segment appears in your prompt during configured hours,
showing current travel time to home with traffic-aware routing.

## Features

- 🏠 **Real-time travel time** to your home address
- 🚦 **Traffic-aware routing** using Google Routes API
- ⏰ **Configurable active hours** to optimize API usage
- 🎨 **Color-coded traffic status** (green/yellow/red indicators)
- 🔄 **Automated updates** via Windows scheduled tasks
- 🛡️ **Privacy-focused** with local data storage
- ✅ **Address validation** with format and geocoding checks

### Location

- 📍 **Windows Location Services only** (high accuracy when enabled)
- 🔒 **Privacy-respecting** (uses OS level consent)
- 🗂️ **Local cache** (short-lived, reduces repeated queries)

## Prerequisites

- Windows PowerShell 5.1 or newer
- Administrator privileges (for scheduled task creation)
- Google Maps API key with Routes API enabled
- Oh My Posh installed and configured

## Testing Before Installation

🧪 It is recommended to run the test suite before installation to ensure
everything works correctly on your system.

### Quick Test Run

```powershell
# Navigate to your project directory
cd C:\Git\omp-travel-time

# Run all tests (no API key required for basic tests)
.\tests\Run-AllTests.ps1

# Or run with your API key for complete testing
.\tests\Run-AllTests.ps1 -TestApiKey "YOUR_GOOGLE_API_KEY"

# (Detailed HTML report generation is not currently supported)
```

### Individual Test Suites

You can also run specific test suites:

```powershell
# Unit tests (test individual functions)
.\tests\Test-TravelTimeUnit.ps1

# Integration tests (test component interaction)
.\tests\Test-Integration.ps1

# Configuration tests (test config validation and Oh My Posh integration)
.\tests\Test-Configuration.ps1
```

### Test Coverage

The test suite includes:

- ✅ **Unit Tests**: Function logic, time calculations, data validation
- ✅ **Integration Tests**: File operations, API structure, end-to-end workflow
- ✅ **Configuration Tests**: JSON validation, Oh My Posh config, edge cases
- ✅ **Mock Data**: Various traffic scenarios and error conditions
- ✅ **API Tests**: Google Routes API connectivity (with valid key)

### Test Results

The tests will show:

- 🟢 **Pass/Fail status** for each test
- 📊 **Overall pass rate** and summary statistics
- 🔍 **Detailed error messages** for any failures
- 📄 **HTML report generation** (optional)

If all tests pass, you're ready to proceed with installation!

## Getting Started

### 1. Get Google Maps API Key

1. Visit the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Routes API**
4. Create credentials (API key)
5. Optionally restrict the API key to Routes API for security

**Important**: The Routes API has usage limits and costs.
See
[Google's pricing](https://developers.google.com/maps/documentation/routes/usage-and-billing)
for details.

### 2. Install the Service

Run the installation script as Administrator:

```powershell
# Navigate to your project directory
cd C:\Git\omp-travel-time

# Run the installer (will prompt for configuration)
.\scripts\Install-TravelTimeService.ps1
```

Or install with parameters:

```powershell
./scripts/Install-TravelTimeService.ps1 -GoogleMapsApiKey "YOUR_API_KEY" `
  -HomeAddress "123 Main St, City, State" -StartTime "15:00" -EndTime "23:00"
```

Or install with custom buffer file location:

```powershell
./scripts/Install-TravelTimeService.ps1 -GoogleMapsApiKey "YOUR_API_KEY" `
  -HomeAddress "123 Main St, City, State" -BufferFilePath "C:\MyData\travel.json"
```

### 3. Reload Your PowerShell Profile

```powershell
. $PROFILE
```

## Configuration

### Markdownlint (Documentation Quality)

To run documentation lint checks locally install markdownlint-cli globally:

```powershell
npm install -g markdownlint-cli
```

Or use the provided script with on-demand npx resolution:

```powershell
./scripts/Run-MarkdownLint.ps1 -UseNpx
```

The script automatically falls back to `npx markdownlint` if a global
installation is not found.

### Installation Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `GoogleMapsApiKey` | Your Google Routes API key | *Required* | `"AIza..."` |
| `HomeAddress` | Your home address | *Required* | `"123 Main St, City, State"` |
| `StartTime` | When to start tracking (24h format) | `"15:00"` | `"14:30"` |
| `EndTime` | When to stop tracking (24h format) | `"23:00"` | `"22:00"` |
| `BufferFilePath` | Custom buffer file location | OS default | `"C:\MyData\travel.json"` |

### Active Hours Logic

The system determines whether updates should run using `Test-ActiveHours`.

Key behaviors:

- Same-day windows (Start <= End) are inclusive of both endpoints.
  - Example: `09:00`–`17:00` is active when current time is between 09:00 and 17:00.
- Overnight windows (Start > End) wrap past midnight.
  - Example: `22:00`–`06:00` is active when the time is >=22:00 OR <=06:00.
- Invalid time formats cause the function to return `$false` (treated as
  inactive) and can be detected via `Test-TimeFormat`.
- Unit tests inject a deterministic time using the optional `-ReferenceTime`
  parameter so logic can be validated regardless of the real clock.

Example usages:

```powershell
# Basic same-day window
Test-ActiveHours -StartTime "15:00" -EndTime "23:00"

# Overnight window (late night into morning)
Test-ActiveHours -StartTime "22:30" -EndTime "05:30"

# Deterministic evaluation for testing
$fixed = Get-Date "2025-01-01T03:00:00";
Test-ActiveHours -StartTime "22:00" -EndTime "06:00" -ReferenceTime $fixed
```

If you require more complex schedules (multiple windows per day), consider
wrapping multiple calls or extending the utility with an array-based
configuration (future enhancement candidate).

### Configuration File

After installation, configuration is stored in:

```text
scripts/config/travel-config.json
```

Example configuration:

```json
{
  "google_routes_api_key": "YOUR_API_KEY_HERE",
  "home_address": "123 Main St, City, State",
  "update_interval_minutes": 5,
  "start_time": "15:00",
  "end_time": "23:00",
  "travel_mode": "DRIVE",
  "routing_preference": "TRAFFIC_AWARE",
  "units": "METRIC",
  "buffer_file_path": ""
}
```

### Buffer File Location

The buffer file (`travel_time.json`) stores current travel time data and can be configured using multiple methods in priority order:

1. **Command-line parameter**: `TravelTimeUpdater.ps1 -DataPath "C:\MyData\travel.json"`
2. **Environment variable**: Set `OMP_TRAVEL_TIME_DATA_PATH` environment variable
3. **Configuration file**: Set `buffer_file_path` in the configuration file
4. **OS-specific default**: Automatic location based on OS conventions

#### Default Locations by OS:
- **Windows**: `%LOCALAPPDATA%\OhMyPosh\TravelTime\travel_time.json`
- **Linux**: `~/.local/share/omp-travel-time/travel_time.json`
- **macOS**: `~/Library/Application Support/OhMyPosh/TravelTime/travel_time.json`

#### Configuration Examples:

```json
{
  "buffer_file_path": ""                           // Use OS default
}
```

```json
{
  "buffer_file_path": "C:\\MyData\\travel.json"    // Windows absolute path
}
```

```json
{
  "buffer_file_path": "./data/travel_time.json"    // Relative to project
}
```

The system automatically creates directories and validates write permissions for the specified location.

## Address Validation

The system includes comprehensive address validation to ensure reliable
geocoding and travel time calculations:

### Validation Features

- 🔍 **Format validation** - Checks address structure, length, and content
- 🌍 **Geocoding validation** - Verifies addresses can be found via Google's API
- 💡 **Smart suggestions** - Provides helpful formatting tips and corrections
- 🎯 **Google recommendations** - Offers to use Google's standardized address format
- ⚡ **Caching** - Stores validation results to minimize API calls
- 🔧 **Override capability** - Allows proceeding with warnings for edge cases

### Address Format Tips

For best results, include:

- Street number and name: `123 Main Street`
- City and state: `Springfield, IL`
- Use commas to separate components: `123 Main St, Springfield, IL 62701`

### Examples of Well-Formatted Addresses

- `1600 Amphitheatre Parkway, Mountain View, CA 94043, USA`
- `10 Downing Street, London SW1A 2AA, UK`
- `PO Box 1234, Springfield, IL 62701, USA`

The installation wizard automatically validates your home address and provides
real-time feedback and suggestions.

For detailed information, see [Address Validation Documentation](docs/ADDRESS_VALIDATION.md).

## Architecture

### Modular Design

The system uses a clean, modular architecture with production logic organized
in the `src/` folder:

- **Clear Separation**: Production logic is separated from scripts, tests, and configuration
- **Organized by Function**: Related functionality is grouped into logical
modules  
- **Backward Compatible**: Existing scripts and interfaces continue to work unchanged
- **Extensible**: New providers and services can be easily added
- **Testable**: Individual modules can be tested in isolation

For detailed information about the source code organization, see
[Source Organization](docs/SOURCE_ORGANIZATION.md). For prompt travel segment
logic details see `docs/travel-segment.md`.

## How It Works

### 1. Location Detection

The system now uses only **Windows Location Services** via the .NET
`GeoCoordinateWatcher` API.
No IP-based geolocation, manual GPS coordinates, or address geocoding are
performed for origin detection.

Requirements:

1. Windows Location Services enabled (Settings > Privacy & Security > Location)
2. "Let desktop apps access your location" turned ON
3. Consent granted to PowerShell (first use may prompt)
4. First acquisition after a cold start may take several seconds; a short
  polling loop (≤10s) is used.

### 2. Travel Time Calculation

- A PowerShell script runs every 5 minutes (fixed)
- During active hours, it determines your current location via Windows Location Services
- Calls Google Routes API for travel time to your home address
- Stores results in `data/travel_time.json`

### 2. Prompt Display

- Oh My Posh reads the JSON data file
- Displays travel time only during active hours
- Shows traffic status with color-coded indicators:
  - 🟢 Light traffic (≤30 min)
  - 🟡 Moderate traffic (31-45 min)
  - 🔴 Heavy traffic (>45 min)

### 3. Security

- Configuration files are gitignored
- API key is stored locally only
- No data sent to external services except Google Routes API

## Project Structure

```text
omp-travel-time/
├── src/                                  # Production logic (modular)
│   ├── core/                             # Core business logic
│   ├── services/                         # External service integrations
│   │                                       (Location, Routing)
│   ├── config/                           # Configuration management
│   ├── utils/                            # Utility helpers
│   ├── models/                           # Data models and types
├── scripts/
│   ├── Install-TravelTimeService.ps1    # Installation wizard
│   ├── TravelTimeUpdater.ps1            # Main polling script (uses src/ modules)
│   └── config/
│       ├── travel-config.json           # Your configuration (gitignored)
│       └── travel-config.json.template  # Template file
├── tests/                               # Test files and data
├── docs/                                # Documentation
│   └── SOURCE_ORGANIZATION.md           # Details on the src/ structure
├── data/
│   └── travel_time.json                 # Current travel data (gitignored)
├── new_config.omp.json                  # Oh My Posh configuration
└── README.md                            # This file
```

> **Note**: The project now uses a modular architecture with production logic
> organized in the `src/` folder. See
> [Source Organization](docs/SOURCE_ORGANIZATION.md) for detailed information
> about the new structure.

## Data Format

The `travel_time.json` file contains:

```json
{
  "last_updated": "2025-10-17T15:30:00Z",
  "travel_time_minutes": 25,
  "distance_km": 15.2,
  "traffic_status": "moderate",
  "travel_mode": "DRIVE",
  "errorMessage": null,
  "is_active_hours": true,
  "active_period": "15:00 - 23:00"
}
```

## Management

### View Scheduled Task

```powershell
Get-ScheduledTask -TaskName "OhMyPosh-TravelTime"
```

### Check Current Data

```powershell
Get-Content "C:\Git\omp-travel-time\data\travel_time.json" | ConvertFrom-Json
```

### Manual Update

```powershell
& "C:\Git\omp-travel-time\scripts\TravelTimeUpdater.ps1"
```

### Disable Service

```powershell
Disable-ScheduledTask -TaskName "OhMyPosh-TravelTime"
```

### Location Management

No separate location provider configuration is required. Ensure Windows
Location Services are enabled. If disabled, travel time updates will mark
location as unavailable.

### Uninstall Service

```powershell
Unregister-ScheduledTask -TaskName "OhMyPosh-TravelTime" -Confirm:$false
Remove-Item "C:\Git\omp-travel-time\scripts\config\travel-config.json" -Force
Remove-Item "C:\Git\omp-travel-time\data\travel_time.json" -Force
```

## Troubleshooting

### Common Issues

#### CONFIG ERROR in prompt

- Check if `travel_time.json` exists and is valid JSON
- Verify Oh My Posh configuration syntax
- Check file permissions

#### No travel time display

- Verify you're in the configured active hours
- Check if scheduled task is running: `Get-ScheduledTask -TaskName "OhMyPosh-TravelTime"`
- Review data file for errors: `Get-Content "data\travel_time.json"`

#### API errors

- Verify API key is correct and Routes API is enabled
- Check API quotas and billing in Google Cloud Console
- Ensure your IP isn't blocked by Google

### Debug Mode

Run the updater manually to see detailed output:

```powershell
& "C:\Git\omp-travel-time\scripts\TravelTimeUpdater.ps1" -Verbose
```

### Log Files

Scheduled task logs can be viewed in:

- Event Viewer → Windows Logs → Application
- Task Scheduler → Task Scheduler Library → OhMyPosh-TravelTime

## Customization

### Changing the Display

Edit the template in `new_config.omp.json` to customize:

- Icons (currently uses 🏠 `\uf1fa` and traffic icons)
- Colors and background templates
- Displayed information (time, distance, etc.)

### Different Travel Modes

Modify `travel_mode` in config:

- `"DRIVE"` - Driving (default)
- `"WALK"` - Walking
- `"BICYCLE"` - Cycling
- `"TRANSIT"` - Public transportation

### API Optimization

The update interval is fixed at every 5 minutes. To further reduce API calls:

- Narrow the active time window
- (Future) Introduce caching/backoff strategies (see TODO/backlog)

## Contributing

This project is designed to be shared as open source. To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Privacy & Security

- Your API key and home address are stored locally only
- Data files are gitignored to prevent accidental sharing
- Location data is collected using Windows Location Services only
- No personal data is transmitted except to Google Routes API

## License

[Add your preferred license here]

## Support

For issues and questions:

- Check the troubleshooting section above
- Review Google Routes API documentation
- Check Oh My Posh documentation for prompt configuration

---

**Note**: This integration requires active internet connection and uses
external APIs. Monitor your usage to avoid unexpected charges.
