# Contributing to Oh My Posh Travel Time Integration

Thank you for your interest in contributing to this project! This
PowerShell-based Oh My Posh integration provides real-time travel time display
using the Google Routes API. We welcome contributions from the community.

Refer to these project documents for broader context:

- `CODE_OF_CONDUCT.md` – expected behavior
- `SECURITY.md` – how to report vulnerabilities
- `SUPPORT.md` – ways to get help
- `CHANGELOG.md` – history of notable changes
- `ROADMAP.md` – planned direction
- `AUTHORS.md` / `ACKNOWLEDGMENTS.md` – credits and thanks

## 🚀 Quick Start

### Prerequisites

- Windows PowerShell 5.1 or newer (or PowerShell Core 6+ for cross-platform)
- Oh My Posh installed and configured
- Git for version control
- A text editor or IDE (VS Code recommended)

### Development Setup

1. **Fork and Clone**

   ```powershell
   git clone https://github.com/YOUR_USERNAME/omp-travel-time.git
   cd omp-travel-time
   ```

2. **Run Tests Before Making Changes**

   ```powershell
   # Run all tests to ensure everything works
   .\tests\Run-AllTests.ps1

   # Or with your Google API key for complete testing
   .\tests\Run-AllTests.ps1 -TestApiKey "YOUR_GOOGLE_API_KEY"
   ```

3. **Create a Feature Branch**

   ```powershell
   git checkout -b feature/your-feature-name
   ```

## 🧪 Testing

**Always run tests before submitting changes!**

### Test Suites Available

- **Unit Tests**: `.\tests\Test-TravelTimeUnit.ps1`
- **Integration Tests**: `.\tests\Test-Integration.ps1`
- **Configuration Tests**: `.\tests\Test-Configuration.ps1`
- **Complete Suite**: `.\tests\Run-AllTests.ps1`

### Writing Tests

- Add unit tests for new functions in `Test-TravelTimeUnit.ps1`
- Add integration tests for workflow changes in `Test-Integration.ps1`
- Add configuration tests for config-related changes in `Test-Configuration.ps1`
- Use the existing mock data in `tests/data/` for consistent testing

## 📝 Code Style Guidelines

### PowerShell Conventions

- **Functions**: Use `Verb-Noun` naming (e.g., `Get-TravelTime`)
- **Variables**: Use `$camelCase` for local variables, `$PascalCase` for
   parameters
- **Constants**: Use `$UPPER_CASE` for constants
- **Indentation**: 4 spaces (no tabs)
- **Line Length**: Maximum 120 characters

### Code Structure

```powershell
function Get-TravelTime {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [string]$ApiKey,

      [Parameter(Mandatory = $true)]
      [string]$HomeAddress
   )

   try {
      # Implementation here
      Write-Verbose "Processing travel time request"

      return $result
   }
   catch {
      Write-Error "Failed to get travel time: $_"
      throw
   }
}
```

### Documentation

- Add comment-based help for all public functions
- Use `Write-Verbose` for debug information
- Use `Write-Warning` for non-critical issues
- Use `Write-Error` for error conditions

## 🏗️ Project Structure

```text
omp-travel-time/
├── scripts/
│   ├── Install-TravelTimeService.ps1    # Installation wizard
│   ├── TravelTimeUpdater.ps1            # Main polling script
│   └── config/                          # Configuration templates
├── tests/
│   ├── Run-AllTests.ps1                 # Test runner
│   ├── Test-*.ps1                       # Individual test suites
│   └── data/                            # Mock test data
├── .github/                             # GitHub templates
├── README.md                            # Main documentation
└── new_config.omp.json                  # Oh My Posh configuration
```

## 🔄 Pull Request Process

### Before Submitting

1. **Test Your Changes**

   ```powershell
   .\tests\Run-AllTests.ps1
   ```

2. **Check Code Style**

   - Follow PowerShell best practices
   - Ensure proper error handling
   - Add appropriate logging/verbose output

3. **Update Documentation**

   - Update README.md if adding new features
   - Add/update function documentation
   - Update configuration examples if needed

### PR Requirements

- [ ] All tests pass
- [ ] Code follows project style guidelines
- [ ] New features include tests
- [ ] Documentation is updated
- [ ] Changelog entry added if user-facing
- [ ] PR description explains the changes
- [ ] Commits have clear, descriptive messages

### PR Template

When creating a PR, please:

1. **Describe your changes** clearly
2. **Reference any related issues** using `#issue-number`
3. **List breaking changes** if any
4. **Include screenshots** for UI/display changes
5. **Test on your system** and document the results

## 🐛 Reporting Issues

### Bug Reports

Use the bug report template and include:

- PowerShell version
- Oh My Posh version
- Operating system
- Steps to reproduce
- Expected vs actual behavior
- Error messages or logs

### Feature Requests

Use the feature request template and include:

- Clear description of the feature
- Use case and motivation
- Proposed implementation (if any)
- Potential alternatives considered

## 🏷️ Issue Labels

- `bug`: Something isn't working
- `enhancement`: New feature or improvement
- `documentation`: Documentation changes
- `good first issue`: Good for newcomers
- `help wanted`: Extra attention needed
- `question`: Further information requested

## 🌟 Types of Contributions

We welcome various types of contributions:

### Code Contributions

- Bug fixes
- New features
- Performance improvements
- Code refactoring

### Documentation & Knowledge

- README improvements
- Code comments
- Wiki articles
- Tutorial content

### Testing

- Additional test cases
- Test coverage improvements
- Cross-platform testing

### Design

- Oh My Posh theme improvements
- Display formatting enhancements
- User experience improvements

## 💡 Development Tips

### Local Development

1. **Test with Mock Data**: Use the provided mock data files for development
   without API calls
2. **Debug Mode**: Run scripts with `-Verbose` for detailed output
3. **Configuration Testing**: Test with various configuration scenarios

### API Development

- Always test with rate limiting in mind
- Use mock responses for unit testing
- Validate API responses thoroughly
- Handle network failures gracefully

### Cross-Platform Considerations

- Test on different PowerShell versions
- Consider Windows vs. Linux/macOS differences
- Use platform-agnostic path handling

## 📞 Getting Help

- **Questions**: Use GitHub Discussions or create an issue with the `question`
   label
- **Chat**: Join our community discussions
- **Documentation**: Check the README.md and existing issues first

## 🙏 Code of Conduct

Please note that this project follows our [Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you agree to abide by its terms.

## 📄 License

By contributing, you agree that your contributions will be licensed under the
project's [MIT License](LICENSE).

---

Thank you for contributing to make travel time integration better for everyone! 🚗✨
