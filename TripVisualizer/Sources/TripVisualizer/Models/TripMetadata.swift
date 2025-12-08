import Foundation

/// Metadata about trip log processing for logging and display.
///
/// TripMetadata provides summary information about how logs were processed,
/// including counts and timing information. This is useful for
/// logging, debugging, and providing feedback to users.
///
/// Note: Only logs with valid coordinate data are counted. Logs without
/// coordinates are silently ignored and not included in any counts.
public struct TripMetadata: Codable, Equatable, Sendable {

    // MARK: - Properties

    /// Total logs with valid coordinate data
    public let totalLogs: Int

    /// True if the log limit was reached (truncated)
    public let truncated: Bool

    /// Timestamp of first log
    public let firstTimestamp: Date

    /// Timestamp of last log
    public let lastTimestamp: Date

    // MARK: - Initialization

    public init(
        totalLogs: Int,
        truncated: Bool,
        firstTimestamp: Date,
        lastTimestamp: Date
    ) {
        self.totalLogs = totalLogs
        self.truncated = truncated
        self.firstTimestamp = firstTimestamp
        self.lastTimestamp = lastTimestamp
    }

    // MARK: - Computed Properties

    /// Time duration from first to last log
    public var totalDuration: TimeInterval {
        lastTimestamp.timeIntervalSince(firstTimestamp)
    }

    /// Returns true if all logs were processed successfully (not truncated)
    public var isComplete: Bool {
        !truncated
    }

    /// Human-readable duration string
    public var durationString: String {
        let duration = totalDuration
        if duration < 60 {
            return String(format: "%.0f seconds", duration)
        } else if duration < 3600 {
            let minutes = duration / 60
            return String(format: "%.1f minutes", minutes)
        } else {
            let hours = duration / 3600
            return String(format: "%.1f hours", hours)
        }
    }
}

// MARK: - CustomStringConvertible

extension TripMetadata: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []
        parts.append("\(totalLogs) logs")

        if truncated {
            parts.append("truncated")
        }

        parts.append("duration: \(durationString)")

        return "TripMetadata(\(parts.joined(separator: ", ")))"
    }
}

// MARK: - Factory Methods

extension TripMetadata {
    /// Creates metadata for a single log
    public static func single(timestamp: Date) -> TripMetadata {
        TripMetadata(
            totalLogs: 1,
            truncated: false,
            firstTimestamp: timestamp,
            lastTimestamp: timestamp
        )
    }

    /// Creates metadata from an array of successfully parsed logs
    public static func from(
        logs: [LogFragment],
        truncated: Bool
    ) -> TripMetadata {
        let sortedLogs = logs.sorted()

        return TripMetadata(
            totalLogs: logs.count,
            truncated: truncated,
            firstTimestamp: sortedLogs.first?.timestamp ?? Date(),
            lastTimestamp: sortedLogs.last?.timestamp ?? Date()
        )
    }
}
