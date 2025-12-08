import Foundation

/// Metadata about trip fragment processing for logging and display.
///
/// TripMetadata provides summary information about how fragments were processed,
/// including success/failure counts and timing information. This is useful for
/// logging, debugging, and providing feedback to users.
public struct TripMetadata: Codable, Equatable, Sendable {

    // MARK: - Properties

    /// Total fragments found in DataDog
    public let totalFragments: Int

    /// Successfully processed fragments
    public let successfulFragments: Int

    /// Failed fragments (download or parse errors)
    public let failedFragments: Int

    /// True if more than 50 fragments existed (truncated)
    public let truncated: Bool

    /// Timestamp of first fragment
    public let firstTimestamp: Date

    /// Timestamp of last fragment
    public let lastTimestamp: Date

    // MARK: - Initialization

    public init(
        totalFragments: Int,
        successfulFragments: Int,
        failedFragments: Int,
        truncated: Bool,
        firstTimestamp: Date,
        lastTimestamp: Date
    ) {
        self.totalFragments = totalFragments
        self.successfulFragments = successfulFragments
        self.failedFragments = failedFragments
        self.truncated = truncated
        self.firstTimestamp = firstTimestamp
        self.lastTimestamp = lastTimestamp
    }

    // MARK: - Computed Properties

    /// Time duration from first to last fragment
    public var totalDuration: TimeInterval {
        lastTimestamp.timeIntervalSince(firstTimestamp)
    }

    /// Percentage of successful fragments (0.0 to 1.0)
    public var successRate: Double {
        guard totalFragments > 0 else { return 0.0 }
        return Double(successfulFragments) / Double(totalFragments)
    }

    /// Returns true if any fragments failed processing
    public var hasFailures: Bool {
        failedFragments > 0
    }

    /// Returns true if all fragments were processed successfully
    public var isComplete: Bool {
        failedFragments == 0 && !truncated
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
        parts.append("\(successfulFragments)/\(totalFragments) fragments")

        if hasFailures {
            parts.append("\(failedFragments) failed")
        }

        if truncated {
            parts.append("truncated")
        }

        parts.append("duration: \(durationString)")

        return "TripMetadata(\(parts.joined(separator: ", ")))"
    }
}

// MARK: - Factory Methods

extension TripMetadata {
    /// Creates metadata for a single fragment (no aggregation needed)
    public static func single(timestamp: Date) -> TripMetadata {
        TripMetadata(
            totalFragments: 1,
            successfulFragments: 1,
            failedFragments: 0,
            truncated: false,
            firstTimestamp: timestamp,
            lastTimestamp: timestamp
        )
    }

    /// Creates metadata from an array of successfully processed fragments
    public static func from(
        fragments: [LogFragment],
        totalFound: Int,
        failedCount: Int,
        truncated: Bool
    ) -> TripMetadata {
        let sortedFragments = fragments.sorted()

        return TripMetadata(
            totalFragments: totalFound,
            successfulFragments: fragments.count,
            failedFragments: failedCount,
            truncated: truncated,
            firstTimestamp: sortedFragments.first?.timestamp ?? Date(),
            lastTimestamp: sortedFragments.last?.timestamp ?? Date()
        )
    }
}
