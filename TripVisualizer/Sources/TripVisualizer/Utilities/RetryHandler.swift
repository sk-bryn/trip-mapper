import Foundation

/// Handles retry logic for transient failures
///
/// Implements exponential backoff with configurable retry counts
/// for network operations that may fail due to transient issues.
public final class RetryHandler {

    // MARK: - Configuration

    /// Default number of retry attempts
    public static let defaultRetryCount = 3

    /// Base delay between retries in seconds
    public static let baseDelaySeconds: Double = 1.0

    /// Maximum delay between retries in seconds
    public static let maxDelaySeconds: Double = 30.0

    // MARK: - Public Methods

    /// Executes an async operation with retry logic
    /// - Parameters:
    ///   - retryCount: Maximum number of retry attempts
    ///   - operation: The async operation to execute
    ///   - shouldRetry: Closure to determine if an error is retryable
    /// - Returns: The result of the operation
    /// - Throws: The last error if all retries fail
    public static func withRetry<T>(
        retryCount: Int = defaultRetryCount,
        operation: () async throws -> T,
        shouldRetry: (Error) -> Bool = isRetryableError
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<retryCount {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Check if we should retry
                guard shouldRetry(error) else {
                    throw error
                }

                // Don't sleep after the last attempt
                if attempt < retryCount - 1 {
                    let delay = calculateDelay(attempt: attempt)
                    logInfo("Retry \(attempt + 1)/\(retryCount) after \(String(format: "%.1f", delay))s delay...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? TripVisualizerError.networkUnreachable("Unknown error after retries")
    }

    /// Determines if an error is retryable
    /// - Parameter error: The error to check
    /// - Returns: True if the operation should be retried
    public static func isRetryableError(_ error: Error) -> Bool {
        if let vizError = error as? TripVisualizerError {
            switch vizError {
            case .networkTimeout, .networkUnreachable, .rateLimitExceeded:
                return true
            case .httpError(let statusCode, _):
                // Retry on server errors (5xx) and some client errors
                return statusCode >= 500 || statusCode == 429 || statusCode == 408
            default:
                return false
            }
        }

        // Retry on URL errors that are transient
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .cannotConnectToHost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }

        return false
    }

    // MARK: - Private Methods

    /// Calculates the delay for a retry attempt using exponential backoff
    /// - Parameter attempt: The current attempt number (0-indexed)
    /// - Returns: Delay in seconds
    private static func calculateDelay(attempt: Int) -> Double {
        // Exponential backoff: base * 2^attempt with jitter
        let exponentialDelay = baseDelaySeconds * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...0.5) // Add up to 0.5s jitter
        let delay = min(exponentialDelay + jitter, maxDelaySeconds)
        return delay
    }
}
