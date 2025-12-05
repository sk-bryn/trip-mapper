# Trip Mapper Constitution

## Core Principles

### I. CLI-First Design
All functionality is exposed via command-line interface following Unix conventions:
- Text I/O protocol: arguments/stdin for input, stdout for output, stderr for errors
- Log files follow naming convention `<tripId>-<timestamp>.log` stored in top-level `logs/` directory
- Progress indicators required for all long-running operations
- Comprehensive help system with detailed usage instructions for each subcommand

### II. Test-First Development (NON-NEGOTIABLE)
Unit tests are mandatory for all code:
- Tests written before implementation (TDD)
- Unit tests required for every new module and command
- Red-Green-Refactor cycle strictly enforced
- No code merges without passing test coverage

### III. Strongly-Typed Swift
Type safety is paramount:
- Swift 5.5+ required for async/await support
- All models use strongly typed Swift structs and interfaces
- Dependency injection for all services and repositories
- Native Swift types for data extraction (no untyped dictionaries for domain models)

### IV. Cross-Platform Compatibility
Code must run on multiple platforms:
- Support both macOS and Linux operating systems
- Use only Foundation framework and Swift standard library
- Avoid platform-specific APIs; use conditional compilation when unavoidable
- Test on both platforms before release

### V. Security-First
Sensitive data must be protected:
- API keys provided exclusively via environment variables (`DD_API_KEY`, `DD_APP_KEY`, `GOOGLE_MAPS_API_KEY`)
- Never commit secrets, credentials, or API keys to version control
- Validate and sanitize all external input
- Log redaction for sensitive data

### VI. Modular Configuration
Configuration enables flexibility and reuse:
- Each module maintains its own configuration file
- Configuration supports multi-team and multi-project deployment
- Sensible defaults with override capability
- Configuration files are version-controlled (excluding secrets)

### VII. Comprehensive Documentation
All code must be documented:
- Document all exported functions, types, and interfaces
- Help system provides usage instructions for each subcommand
- Follow standard Swift documentation conventions (DocC compatible)
- README with setup and usage instructions

## Technology Stack

| Component | Technology | Notes |
|-----------|------------|-------|
| Language | Swift 5.5+ | Required for async/await |
| HTTP Client | URLSession | Built-in, no external dependencies |
| Data Source | DataDog REST API v2 | Log search endpoint |
| Visualization | Google Maps JavaScript API | HTML output with embedded map |
| Build System | Swift Package Manager | Cross-platform support |

## Development Workflow

### Commit Standards
- Follow conventional commits format: `[TICKET] description`
- Atomic commits with clear, descriptive messages
- No work-in-progress commits to main branch

### Error Handling
- Robust error handling with typed errors
- User-friendly error messages to stderr
- Detailed error context in log files
- Graceful degradation where possible

### Code Style
- Follow standard Swift conventions and API Design Guidelines
- Use SwiftLint for consistency (when available)
- Prefer clarity over brevity

## Governance

This constitution supersedes all other development practices for the Trip Mapper project:
- All pull requests must verify compliance with these principles
- CLAUDE.md serves as the authoritative source of project requirements
- Amendments require documentation and team approval
- Complexity must be justified against these principles

**Version**: 1.0.0 | **Ratified**: 2025-12-04 | **Last Amended**: 2025-12-04
