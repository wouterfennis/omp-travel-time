# TODO

Remaining improvement backlog items (to be converted to GitHub issues):

1. Wrap any remaining long markdown table rows (README MD013 edge cases).
2. Provide a minimal theme excerpt showing travel segment integration.
3. Add guard for missing/empty API key before invoking Google Routes API.
4. Create `scripts/Smoke-Test.ps1` to validate config and data schema quickly.
5. Add GitHub Action workflow: markdownlint + PowerShell syntax (PSScriptAnalyzer).
6. Document ExecutionPolicy considerations in README install section.
7. Implement optional caching/backoff to reduce API calls during stable traffic.
8. Add config toggle to enable/disable distance display in prompt.
9. Externalize icon/glyph mapping to JSON or a dedicated PowerShell module.
10. Add error backoff logic (cooldown after consecutive failures to API/location).
