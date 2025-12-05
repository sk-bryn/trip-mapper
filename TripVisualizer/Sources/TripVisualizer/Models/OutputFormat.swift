import Foundation

/// Output format options for trip visualization
public enum OutputFormat: String, Codable, CaseIterable, Equatable {
    /// PNG static map image
    case image

    /// Interactive HTML file with embedded Google Maps
    case html

    /// Google Maps URL printed to stdout
    case url
}

// MARK: - CustomStringConvertible

extension OutputFormat: CustomStringConvertible {
    public var description: String {
        switch self {
        case .image:
            return "PNG image"
        case .html:
            return "HTML file"
        case .url:
            return "Google Maps URL"
        }
    }
}

// MARK: - File Extension

extension OutputFormat {
    /// Returns the file extension for this output format
    public var fileExtension: String? {
        switch self {
        case .image:
            return "png"
        case .html:
            return "html"
        case .url:
            return nil // URL is printed to stdout, no file
        }
    }

    /// Returns true if this format produces a file
    public var producesFile: Bool {
        fileExtension != nil
    }
}
