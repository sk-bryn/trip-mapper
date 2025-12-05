import Foundation

/// Logger utility with file and stderr output
///
/// Logs are written to both stderr (for user visibility) and a log file
/// named `<tripId>-<timestamp>.log` in the logs directory (FR-010).
public final class Logger {

    // MARK: - Singleton

    /// Shared logger instance
    public static let shared = Logger()

    // MARK: - Properties

    /// Current log level (messages below this level are ignored)
    public var logLevel: LogLevel = .info

    /// Current trip ID for log file naming
    public var tripId: UUID?

    /// Log file handle (lazy initialized when tripId is set)
    private var fileHandle: FileHandle?

    /// Path to the current log file
    public private(set) var logFilePath: String?

    /// Date formatter for log timestamps
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Date formatter for log file names
    private let fileNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    // MARK: - Initialization

    private init() {}

    // MARK: - Configuration

    /// Configures the logger for a specific trip
    /// - Parameters:
    ///   - tripId: The trip ID for log file naming
    ///   - logLevel: The minimum log level to output
    ///   - logsDirectory: Directory to store log files (default: "logs")
    public func configure(
        tripId: UUID,
        logLevel: LogLevel = .info,
        logsDirectory: String = "logs"
    ) throws {
        self.tripId = tripId
        self.logLevel = logLevel

        // Close existing file handle
        closeLogFile()

        // Create logs directory if needed
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: logsDirectory) {
            try fileManager.createDirectory(atPath: logsDirectory, withIntermediateDirectories: true)
        }

        // Create log file
        let timestamp = fileNameDateFormatter.string(from: Date())
        let fileName = "\(tripId.uuidString)-\(timestamp).log"
        let filePath = (logsDirectory as NSString).appendingPathComponent(fileName)

        fileManager.createFile(atPath: filePath, contents: nil)
        fileHandle = FileHandle(forWritingAtPath: filePath)
        logFilePath = filePath

        // Write header
        let header = """
        ================================================================================
        Trip Visualizer Log
        Trip ID: \(tripId.uuidString)
        Started: \(dateFormatter.string(from: Date()))
        ================================================================================

        """
        writeToFile(header)
    }

    /// Closes the current log file
    public func closeLogFile() {
        if let handle = fileHandle {
            try? handle.close()
            fileHandle = nil
            logFilePath = nil
        }
    }

    // MARK: - Logging Methods

    /// Logs a debug message
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }

    /// Logs an info message
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }

    /// Logs a warning message
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }

    /// Logs an error message
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }

    /// Logs an error with the error object
    public func error(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, error.localizedDescription, file: file, function: function, line: line)
    }

    // MARK: - Core Logging

    private func log(
        _ level: LogLevel,
        _ message: String,
        file: String,
        function: String,
        line: Int
    ) {
        // Skip if below current log level
        guard level >= logLevel else { return }

        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent

        // Format: [TIMESTAMP] [LEVEL] message
        let logMessage = "[\(timestamp)] [\(level.description)] \(message)"

        // Write to stderr
        writeToStderr(logMessage)

        // Write to file (with more detail)
        let detailedMessage = "[\(timestamp)] [\(level.description)] [\(fileName):\(line)] \(message)"
        writeToFile(detailedMessage + "\n")
    }

    // MARK: - Output Methods

    private func writeToStderr(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    private func writeToFile(_ message: String) {
        guard let handle = fileHandle else { return }
        if let data = message.data(using: .utf8) {
            handle.write(data)
        }
    }

    // MARK: - Cleanup

    deinit {
        closeLogFile()
    }
}

// MARK: - Convenience Functions

/// Logs a debug message to the shared logger
public func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, file: file, function: function, line: line)
}

/// Logs an info message to the shared logger
public func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, file: file, function: function, line: line)
}

/// Logs a warning message to the shared logger
public func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, file: file, function: function, line: line)
}

/// Logs an error message to the shared logger
public func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, file: file, function: function, line: line)
}

/// Logs an error to the shared logger
public func logError(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(error, file: file, function: function, line: line)
}
