# Contributing to RootFont

Thank you for your interest in contributing to RootFont!

## Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/rootfont.git
   cd rootfont
   ```

2. **Open in Xcode**
   ```bash
   open rootfont.xcodeproj
   ```

3. **Install dependencies**
   ```bash
   # If using Swift Package Manager
   xcodebuild -resolvePackageDependencies
   ```

## Code Style

### Swift Style Guidelines
- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use 4-space indentation
- Prefer explicit types over type inference for public APIs
- Use `guard` for early returns
- Prefer value types (struct, enum) over reference types (class)

### Naming Conventions
- Types: `PascalCase`
- Variables and functions: `camelCase`
- Constants: `camelCase` or `UPPER_CASE` for global constants
- Tests: `test<FunctionalityBeingTested>()`

## Pull Request Process

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Write tests for new functionality
   - Update documentation as needed
   - Ensure all tests pass

3. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add new feature
   
   - Description of the feature
   - Any breaking changes
   
   License: Apache-2.0
   Signed-off-by: YourName <your.email@example.com>"
   ```

4. **Push and create a Pull Request**
   - Push to your fork
   - Create a Pull Request against the main branch
   - Fill out the PR template

## Testing

- Write unit tests for all new functionality
- Ensure test coverage doesn't decrease
- Run tests before submitting PR:
  ```bash
  xcodebuild test -scheme rootfont -destination 'platform=macOS'
  ```

## Documentation

- Update README.md for significant changes
- Add inline documentation for public APIs
- Update CHANGELOG.md for user-facing changes
- Use Markdown for documentation files

## License Agreement

By contributing to RootFont, you agree that your contributions will be 
licensed under the Apache License, Version 2.0. This is automatic under 
Section 5 of the Apache License.

You certify that:
1. The contribution is your original work
2. You have the right to submit the work under the Apache 2.0 license
3. The contribution does not violate any third-party rights

## Questions?

If you have questions about contributing, please:
1. Check existing issues and documentation
2. Open a new issue for discussion
3. Contact the maintainers at hi@rootfont.com