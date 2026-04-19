# Security Policy

## Supported Versions

Use this section to tell people about which versions of your project are
currently being supported with security updates.

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of RootFont seriously. If you believe you have found a security vulnerability, please report it to us as described below.

### **Do Not** report security vulnerabilities through public GitHub issues.

Instead, please report them via email to **hi@rootfont.com**.

You should receive a response within 48 hours. If for some reason you do not, please follow up via email to ensure we received your original message.

### Please include the following information in your report:

- Type of issue (e.g., buffer overflow, SQL injection, cross-site scripting, etc.)
- Full paths of source file(s) related to the manifestation of the issue
- The location of the affected source code (tag/branch/commit or direct URL)
- Any special configuration required to reproduce the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

## What to Expect

After you submit a vulnerability report, you can expect the following:

1. **Acknowledgement**: We will acknowledge receipt of your vulnerability report within 48 hours.
2. **Investigation**: We will investigate the issue and determine its severity and impact.
3. **Fix Development**: If accepted, we will work on a fix. This process may take some time depending on the complexity of the issue.
4. **Release**: We will release a security update for all supported versions.
5. **Disclosure**: We will coordinate public disclosure with you. We prefer to fully disclose the issue after a fix is available.

## Security Best Practices

### For Users
- Always use the latest version of RootFont
- Keep your macOS system updated
- Review the permissions requested by the application
- Report any suspicious behavior immediately

### For Developers
- Follow secure coding practices
- Use the latest Swift security features
- Regularly update dependencies
- Conduct security reviews of code changes

## Dependency Security

RootFont uses automated tools to monitor for vulnerable dependencies:
- Dependabot scans for security vulnerabilities weekly
- GitHub Actions include security checks
- All dependencies are reviewed for license compliance

## License and Legal

This security policy is governed by the same Apache License 2.0 as the RootFont software. See [LICENSE](LICENSE) for details.