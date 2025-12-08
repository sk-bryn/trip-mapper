You are a senior software architect with expertise in command line scripts and tools building a Swift command line tool. You are tasked with creating a Swift command line utility to visualize the trips taken by the users of a food delivery application. The Swift command line application should read the trip data from the logs the app sends to the DataDog servers, extract the trip waypoints from the log data, and plot those waypoints on a Google Map. 

## Prime Directive
- Additional information and instructions can be found in the `.claude` directory
- You MUST adhere to all requirements

## Code Style Guidelines

- Follow standard Swift conventions
- Add unit tests for all new code
- Use dependency injection for services and repositories
- Follow conventional commits: "[TICKET] description"
- Use strongly typed models and interfaces
- Properly document exported functions and types
- DO NOT add claude related files to the .gitignore

## AI Guidelines
- NEVER disclose AI use in any code or git related activities

## Requirements
- Require a `tripId` String as input
- Fetch all logs with the given `tripId` from DataDog. An API key will be provided in an environment variable for access.
- Extract all trip route segment data from each log for the `tripId` into native Swift structs
- Use the Google Maps APIs to plot these waypoints as a polyline on a Google Map. An API key will be provided in an environment variable for access.

## PRIORITY REQUIREMENTS
Here are the priority requirements for the project:
- Implement robust error handling and logging
- Ensure compatibility with Swift 5.5 and above
- Support both macOS and Linux operating systems
- Provide comprehensive documentation
- Ensure secure handling of sensitive information (e.g., API keys, passwords)
- Implement a progress indicator for long-running operations
- Provide a configuration file for flexible implementation and use by mutlitple teams or projects
- Implement a help system with detailed usage instructions for each subcommand
- Create unit tests for each command

## Module Requirements
Here are module requirments each submodule should obey:
- each module should put any configuration items into it's config file
- all output should be configured to emit to standard out, with errors going to standard err
- everything should get logged to a log file named like "<tripId>-<timestamp>.log"
- logs should be placed in the top level "logs" directory

## Swift CLI Documentation:

1. [Command line swift](https://www.swift.org/getting-started/cli-swiftpm/)
2. [Apple CommandLine Docs](https://developer.apple.com/documentation/swift/commandline)
3. [A blog post for inspiration](https://theswiftdev.com/how-to-build-better-command-line-apps-and-tools-using-swift/)


## Active Technologies
- Swift 5.5+ (async/await support required) + Foundation, URLSession (no external dependencies per constitution) (001-trip-route-visualizer)
- File system only (logs directory, output images/HTML) (001-trip-route-visualizer)
- Swift 5.5+ (async/await support required) + Foundation, URLSession, ArgumentParser (existing) (002-multi-log-trips)
- File system only (output directory alongside map files) (003-log-data-export)

## Recent Changes
- 001-trip-route-visualizer: Added Swift 5.5+ (async/await support required) + Foundation, URLSession (no external dependencies per constitution)
