import Foundation

/// Generates JSON data export files for trip visualizations.
///
/// The generator creates a single JSON file containing DataDog log metadata,
/// route segment correlations, orderIds, and waypoint counts for independent
/// verification of rendered maps.
///
/// ## Usage
/// ```swift
/// let generator = DataExportGenerator()
/// let exportPath = try generator.generateAndWrite(
///     tripId: tripUUID,
///     logs: logFragments,
///     route: unifiedRoute,
///     metadata: tripMetadata,
///     to: outputDirectory
/// )
/// ```
public final class DataExportGenerator {

    // MARK: - Properties

    /// JSON encoder configured for pretty-printed, sorted output
    private let encoder: JSONEncoder

    // MARK: - Initialization

    /// Creates a new DataExportGenerator.
    public init() {
        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Public Methods

    /// Generates a TripDataExport from trip visualization data.
    ///
    /// - Parameters:
    ///   - tripId: The trip UUID
    ///   - logs: Array of LogFragment from DataDog (ordered by timestamp)
    ///   - route: The UnifiedRoute with gap detection info
    ///   - metadata: TripMetadata with processing flags
    ///   - enrichmentResult: Optional enrichment data (delivery destinations, restaurant location)
    /// - Returns: A populated TripDataExport ready for serialization
    public func generateExport(
        tripId: UUID,
        logs: [LogFragment],
        route: UnifiedRoute,
        metadata: TripMetadata,
        enrichmentResult: EnrichmentResult? = nil
    ) -> TripDataExport {
        TripDataExport.from(
            tripId: tripId,
            logs: logs,
            route: route,
            metadata: metadata,
            enrichmentResult: enrichmentResult
        )
    }

    /// Writes a TripDataExport to a JSON file.
    ///
    /// - Parameters:
    ///   - export: The TripDataExport to write
    ///   - path: Absolute path for the output file
    /// - Throws: `TripVisualizerError.cannotWriteOutput` if file cannot be written
    public func writeExport(_ export: TripDataExport, to path: String) throws {
        let jsonData: Data
        do {
            jsonData = try encoder.encode(export)
        } catch {
            throw TripVisualizerError.cannotWriteOutput(
                path: path,
                reason: "Failed to encode export data: \(error.localizedDescription)"
            )
        }

        let url = URL(fileURLWithPath: path)

        do {
            try jsonData.write(to: url, options: .atomic)
        } catch {
            throw TripVisualizerError.cannotWriteOutput(
                path: path,
                reason: error.localizedDescription
            )
        }
    }

    /// Generates and writes a data export in one operation.
    ///
    /// Convenience method combining `generateExport` and `writeExport`.
    ///
    /// - Parameters:
    ///   - tripId: The trip UUID
    ///   - logs: Array of LogFragment from DataDog
    ///   - route: The UnifiedRoute
    ///   - metadata: TripMetadata
    ///   - enrichmentResult: Optional enrichment data (delivery destinations, restaurant location)
    ///   - outputDirectory: Directory to write the export file
    /// - Returns: Path to the written export file
    /// - Throws: `TripVisualizerError.cannotWriteOutput` on failure
    @discardableResult
    public func generateAndWrite(
        tripId: UUID,
        logs: [LogFragment],
        route: UnifiedRoute,
        metadata: TripMetadata,
        enrichmentResult: EnrichmentResult? = nil,
        to outputDirectory: String
    ) throws -> String {
        let export = generateExport(
            tripId: tripId,
            logs: logs,
            route: route,
            metadata: metadata,
            enrichmentResult: enrichmentResult
        )

        let filename = "map-data.json"
        let path = (outputDirectory as NSString).appendingPathComponent(filename)

        try writeExport(export, to: path)

        return path
    }
}
