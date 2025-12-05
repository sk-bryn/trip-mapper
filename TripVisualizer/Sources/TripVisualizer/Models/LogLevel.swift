import Foundation

/// Logging verbosity levels
public enum LogLevel: String, Codable, CaseIterable, Comparable, Equatable {
    case debug
    case info
    case warning
    case error

    // MARK: - Comparable

    private var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        }
    }

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.priority < rhs.priority
    }
}

// MARK: - CustomStringConvertible

extension LogLevel: CustomStringConvertible {
    public var description: String {
        rawValue.uppercased()
    }
}
