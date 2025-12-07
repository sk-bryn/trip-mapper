import Foundation

/// Progress indicator for CLI feedback during long-running operations
///
/// Provides spinner animation and status updates to keep users informed
/// about the current operation state.
public final class ProgressIndicator {

    // MARK: - Types

    /// Represents a stage in the visualization pipeline
    public enum Stage: String, CaseIterable {
        case fetching = "Fetching logs from DataDog"
        case parsing = "Parsing route data"
        case generating = "Generating map outputs"
        case downloading = "Downloading static map"
        case complete = "Complete"

        var icon: String {
            switch self {
            case .fetching: return "🔍"
            case .parsing: return "📊"
            case .generating: return "🗺️"
            case .downloading: return "⬇️"
            case .complete: return "✅"
            }
        }
    }

    // MARK: - Properties

    /// Whether to show progress indicators (disabled in non-TTY environments)
    private let isEnabled: Bool

    /// Whether to use emoji icons
    private let useEmoji: Bool

    /// Current stage being displayed
    private var currentStage: Stage?

    /// Spinner animation frames
    private static let spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    /// Current spinner frame index
    private var spinnerIndex = 0

    /// Timer for spinner animation
    private var spinnerTimer: DispatchSourceTimer?

    /// Whether spinner is currently running
    private var isSpinning = false

    // MARK: - Singleton

    /// Shared progress indicator instance
    public static let shared = ProgressIndicator()

    // MARK: - Initialization

    public init(enabled: Bool? = nil, useEmoji: Bool = false) {
        // Auto-detect if we're in a TTY
        if let enabled = enabled {
            self.isEnabled = enabled
        } else {
            self.isEnabled = isatty(STDERR_FILENO) != 0
        }
        self.useEmoji = useEmoji
    }

    // MARK: - Public Methods

    /// Starts a new stage with optional spinner
    /// - Parameters:
    ///   - stage: The stage to start
    ///   - showSpinner: Whether to show animated spinner
    public func start(_ stage: Stage, showSpinner: Bool = true) {
        guard isEnabled else {
            // In non-TTY mode, just log the stage
            logInfo(stage.rawValue)
            return
        }

        stopSpinner()
        currentStage = stage

        if showSpinner {
            startSpinner(message: stage.rawValue)
        } else {
            printStatus(stage.rawValue, icon: useEmoji ? stage.icon : "→")
        }
    }

    /// Updates the current stage message
    /// - Parameter message: Additional detail to show
    public func update(_ message: String) {
        guard isEnabled, currentStage != nil else { return }

        if isSpinning {
            // Update spinner message
            clearLine()
            let frame = Self.spinnerFrames[spinnerIndex]
            fputs("\r\(frame) \(message)", stderr)
            fflush(stderr)
        }
    }

    /// Completes the current stage successfully
    /// - Parameter message: Optional completion message
    public func complete(_ message: String? = nil) {
        guard isEnabled else { return }

        stopSpinner()

        if let stage = currentStage {
            let msg = message ?? stage.rawValue
            clearLine()
            printStatus(msg, icon: useEmoji ? "✅" : "✓", color: .green)
        }
        currentStage = nil
    }

    /// Marks the current stage as failed
    /// - Parameter message: Error message to display
    public func fail(_ message: String) {
        guard isEnabled else {
            logError(message)
            return
        }

        stopSpinner()
        clearLine()
        printStatus(message, icon: useEmoji ? "❌" : "✗", color: .red)
        currentStage = nil
    }

    /// Shows a warning message
    /// - Parameter message: Warning message
    public func warn(_ message: String) {
        guard isEnabled else {
            logWarning(message)
            return
        }

        printStatus(message, icon: useEmoji ? "⚠️" : "!", color: .yellow)
    }

    /// Shows final summary
    /// - Parameters:
    ///   - tripId: The trip ID that was processed
    ///   - outputCount: Number of outputs generated
    ///   - duration: Total processing time
    public func showSummary(tripId: String, outputCount: Int, duration: TimeInterval) {
        guard isEnabled else { return }

        let durationStr = String(format: "%.2fs", duration)
        printStatus("Generated \(outputCount) output(s) for trip \(tripId) in \(durationStr)",
                   icon: useEmoji ? "✅" : "✓",
                   color: .green)
    }

    // MARK: - Private Methods

    private func startSpinner(message: String) {
        isSpinning = true
        spinnerIndex = 0

        let queue = DispatchQueue(label: "com.tripvisualizer.spinner")
        spinnerTimer = DispatchSource.makeTimerSource(queue: queue)
        spinnerTimer?.schedule(deadline: .now(), repeating: .milliseconds(80))

        let msg = message
        spinnerTimer?.setEventHandler { [weak self] in
            guard let self = self, self.isSpinning else { return }
            let frame = Self.spinnerFrames[self.spinnerIndex]
            self.spinnerIndex = (self.spinnerIndex + 1) % Self.spinnerFrames.count

            // Write to stderr to avoid mixing with stdout output
            fputs("\r\(frame) \(msg)", stderr)
            fflush(stderr)
        }

        spinnerTimer?.resume()
    }

    private func stopSpinner() {
        guard isSpinning else { return }
        isSpinning = false
        spinnerTimer?.cancel()
        spinnerTimer = nil
    }

    private func clearLine() {
        fputs("\r\u{001B}[K", stderr)
        fflush(stderr)
    }

    private func printStatus(_ message: String, icon: String, color: ANSIColor = .default) {
        let colorCode = color.code
        let resetCode = ANSIColor.reset.code
        fputs("\(colorCode)\(icon)\(resetCode) \(message)\n", stderr)
        fflush(stderr)
    }
}

// MARK: - ANSI Colors

private enum ANSIColor {
    case `default`
    case green
    case red
    case yellow
    case reset

    var code: String {
        switch self {
        case .default: return ""
        case .green: return "\u{001B}[32m"
        case .red: return "\u{001B}[31m"
        case .yellow: return "\u{001B}[33m"
        case .reset: return "\u{001B}[0m"
        }
    }
}
