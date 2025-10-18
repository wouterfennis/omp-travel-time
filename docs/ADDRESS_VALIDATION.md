# Address Validation

The Travel Time system includes comprehensive address validation to ensure reliable geocoding and travel time calculations.

## Overview

Address validation operates in multiple layers:

1. **Format Validation** - Basic checks on address structure
2. **Geocoding Validation** - Tests if address can be found via Google's geocoding API
3. **User Experience** - Provides helpful feedback and suggestions
4. **Caching** - Stores validation results to avoid repeated API calls

## Validation Categories

### Format Validation

Basic validation that runs without requiring an API key:

- **Not empty or whitespace only** - Ensures address contains actual content
- **Reasonable length limits** - 5-200 characters to catch obviously invalid inputs
- **Basic character validation** - Must contain letters or numbers, not just special characters
- **Format suggestions** - Recommends including street numbers, commas for separation, and city/state information

### Geocoding Validation

Advanced validation using Google's Geocoding API (requires API key):

- **Address resolution** - Tests if Google can find the address
- **Coordinate validation** - Ensures returned coordinates are geographically valid
- **Address completion** - Checks for missing components (street number, city, etc.)
- **Formatted address suggestions** - Offers Google's standardized address format

### Caching

- **Automatic caching** - Results are cached by address string to avoid repeated API calls
- **Cache management** - Cache can be cleared programmatically
- **Performance optimization** - Reduces API usage and improves response times

## Usage

### Basic Format Validation

```powershell
. ./src/services/AddressValidationService.ps1

$result = Test-AddressFormat -Address "123 Main Street, Springfield, IL"
if ($result.IsValid) {
    Write-Host "Address format is valid"
    if ($result.Suggestions.Count -gt 0) {
        Write-Host "Suggestions: $($result.Suggestions -join ', ')"
    }
} else {
    Write-Host "Address format issues: $($result.Issues -join ', ')"
}
```

### Geocoding Validation

```powershell
$result = Test-AddressGeocoding -Address "123 Main Street, Springfield, IL" -ApiKey $yourApiKey
if ($result.IsValid) {
    Write-Host "Address found at coordinates: $($result.Latitude), $($result.Longitude)"
    Write-Host "Formatted address: $($result.FormattedAddress)"
} else {
    Write-Host "Geocoding failed: $($result.Error)"
}
```

### Comprehensive Validation

```powershell
$result = Invoke-AddressValidation -Address "123 Main Street" -ApiKey $yourApiKey -AllowOverride $true
if ($result.CanProceed) {
    if ($result.IsValid) {
        Write-Host "Address is valid"
    } else {
        Write-Host "Address has warnings but can proceed: $($result.OverallSuggestions -join ', ')"
    }
    $addressToUse = $result.RecommendedAddress
} else {
    Write-Host "Address validation failed: $($result.OverallIssues -join ', ')"
}
```

## Integration with Installation

The installation script (`Install-TravelTimeService.ps1`) automatically uses address validation when available:

- **Real-time feedback** - Validates addresses as users enter them
- **Helpful suggestions** - Shows examples and provides format guidance
- **Google recommendations** - Offers to use Google's formatted version of addresses
- **Override capability** - Allows proceeding with warnings for edge cases

### Installation Flow

1. User enters home address
2. System performs format validation
3. If API key available, performs geocoding validation
4. Shows validation results and suggestions
5. Offers to use Google's recommended address format
6. Allows override for addresses with warnings

## Error Handling

### Common Validation Results

- **Empty Address**: "Address cannot be empty"
- **Too Short**: "Address is too short" (less than 5 characters)
- **Too Long**: "Address is too long" (more than 200 characters)
- **No Alphanumeric**: "Address must contain letters or numbers"
- **API Issues**: Network errors, quota exceeded, invalid API key

### Graceful Degradation

- **No API Key**: Falls back to format validation only
- **Network Issues**: Continues with format validation, logs warning
- **API Quota Exceeded**: Uses cached results when available
- **Service Unavailable**: Provides offline validation

## Best Practices

### For Users

1. **Include street numbers** - "123 Main St" better than "Main St"
2. **Use commas** - "123 Main St, Springfield, IL" for clarity
3. **Add city and state** - Improves geocoding accuracy
4. **Follow suggestions** - Use Google's recommended formats when offered

### For Developers

1. **Cache results** - Avoid repeated API calls for same addresses
2. **Handle errors gracefully** - Provide fallbacks when API unavailable
3. **User feedback** - Show clear error messages and suggestions
4. **Allow overrides** - Don't block valid but unusual addresses

## Address Examples

### Well-Formatted Addresses

- `1600 Amphitheatre Parkway, Mountain View, CA 94043, USA`
- `10 Downing Street, London SW1A 2AA, UK`
- `1 Microsoft Way, Redmond, WA 98052, USA`
- `PO Box 1234, Springfield, IL 62701, USA`

### Addresses That Need Improvement

- `Main Street` → Add street number and location
- `123 Main` → Add city and state
- `House next to the store` → Use formal address format

## API Requirements

### Google Geocoding API

- **Required for**: Full address validation
- **Setup**: Enable Geocoding API in Google Cloud Console
- **Cost**: See [Google's pricing](https://developers.google.com/maps/documentation/geocoding/usage-and-billing)
- **Rate Limits**: 50 requests per second per project

### Optional Features

- **Without API Key**: Format validation only
- **With API Key**: Full geocoding validation
- **Cached Results**: Reduced API usage for repeated addresses

## Configuration

Address validation is automatically integrated into the configuration validation process:

```powershell
# Configuration validation now includes address validation
$config = Get-TravelTimeConfig -Path "config.json"
$validation = Test-ConfigurationFile -Config $config -ValidateAddress $true

if ($validation.AddressValidation) {
    # Address validation was performed
    if ($validation.AddressValidation.IsValid) {
        Write-Host "Home address is valid"
    } else {
        Write-Host "Address warnings: $($validation.Warnings -join ', ')"
    }
}
```

## Testing

Comprehensive test suite available in `tests/Test-AddressValidation.ps1`:

```powershell
# Run address validation tests
.\tests\Test-AddressValidation.ps1

# Run with API key for full testing
.\tests\Test-AddressValidation.ps1 -TestApiKey "your_api_key"

# Include in full test suite
.\tests\Run-AllTests.ps1 -TestApiKey "your_api_key"
```

## Troubleshooting

### Common Issues

1. **"Address validation service not found"**
   - Ensure `src/services/AddressValidationService.ps1` exists
   - Check file permissions

2. **"API key is required for geocoding validation"**
   - Provide valid Google Maps API key
   - Enable Geocoding API in Google Cloud Console

3. **"Network error: Cannot connect to geocoding service"**
   - Check internet connectivity
   - Verify API key permissions
   - Check for firewall restrictions

4. **"API request denied"**
   - Verify API key is valid
   - Check API quotas and billing
   - Ensure Geocoding API is enabled

### Performance Optimization

- **Use caching** - Results are automatically cached
- **Batch validations** - Validate multiple addresses with delays
- **Monitor quotas** - Check Google Cloud Console for usage
- **Consider alternatives** - Format validation when API unavailable