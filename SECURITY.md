# Security Policy

## Supported Versions

This project is pre-release and versioning will begin after initial
stabilization. Until semantic versioning is implemented (see Issue #22), all
`main` branch commits are considered the latest supported state.

## Reporting a Vulnerability

If you discover a security vulnerability:

1. DO NOT create a public issue.
2. Use GitHub's
   [private vulnerability reporting](https://github.com/wouterfennis/omp-travel-time/security/advisories)
   feature with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested remediation (optional)
3. You will receive an acknowledgment after maintainers review; response timing
   may vary based on availability.

## Handling Process

1. Triage: Assess severity and validity.
2. Patch: Develop and test a fix privately.
3. Advisory: Publish a security advisory if impact is significant.
4. Release: Include fix in next tagged release.

## Vulnerability Classes of Interest

- Credential exposure or sensitive data leakage
- Remote code execution via scripts
- Privilege escalation in installation or update process
- Arbitrary file writes/reads outside intended scope
- Supply chain risks (dependency abuse)

## Temporary Mitigations

Until modularization and packaging are complete:

- Review scripts before running
- Prefer least-privilege execution
- Keep dependencies updated manually

## Future Improvements

Planned security enhancements:

- Signed PowerShell scripts
- Automated dependency vulnerability scanning
- Secure secret handling for API keys
- Integrity validation of release packages
