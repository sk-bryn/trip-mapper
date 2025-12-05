import Foundation

/// Response structure from DataDog Logs Search API v2
public struct DataDogLogResponse: Codable {
    /// Array of log entries matching the query
    public let data: [DataDogLogEntry]

    /// Pagination metadata (optional)
    public let meta: DataDogMeta?

    /// Links for pagination (optional)
    public let links: DataDogLinks?

    public init(data: [DataDogLogEntry], meta: DataDogMeta? = nil, links: DataDogLinks? = nil) {
        self.data = data
        self.meta = meta
        self.links = links
    }
}

/// Individual log entry from DataDog
public struct DataDogLogEntry: Codable {
    /// Unique identifier for this log entry
    public let id: String

    /// Log attributes containing message and custom fields
    public let attributes: DataDogLogAttributes

    /// Type of entry (always "log" for log entries)
    public let type: String?

    public init(id: String, attributes: DataDogLogAttributes, type: String? = "log") {
        self.id = id
        self.attributes = attributes
        self.type = type
    }
}

/// Attributes of a DataDog log entry
public struct DataDogLogAttributes: Codable {
    /// ISO 8601 timestamp of when the log was created
    public let timestamp: String

    /// Log message content
    public let message: String

    /// Custom attributes attached to the log (contains segment_coords)
    public let attributes: [String: Any]

    /// Service name that generated this log
    public let service: String?

    /// Host that generated this log
    public let host: String?

    /// Log status/level
    public let status: String?

    /// Tags associated with this log
    public let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case message
        case attributes
        case service
        case host
        case status
        case tags
    }

    public init(
        timestamp: String,
        message: String,
        attributes: [String: Any],
        service: String? = nil,
        host: String? = nil,
        status: String? = nil,
        tags: [String]? = nil
    ) {
        self.timestamp = timestamp
        self.message = message
        self.attributes = attributes
        self.service = service
        self.host = host
        self.status = status
        self.tags = tags
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        message = try container.decode(String.self, forKey: .message)
        service = try container.decodeIfPresent(String.self, forKey: .service)
        host = try container.decodeIfPresent(String.self, forKey: .host)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)

        // Decode attributes as a dictionary
        if let attributesContainer = try? container.decode([String: AnyCodable].self, forKey: .attributes) {
            attributes = attributesContainer.mapValues { $0.value }
        } else {
            attributes = [:]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(service, forKey: .service)
        try container.encodeIfPresent(host, forKey: .host)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(tags, forKey: .tags)

        // Encode attributes
        let encodableAttributes = attributes.mapValues { AnyCodable($0) }
        try container.encode(encodableAttributes, forKey: .attributes)
    }
}

/// Pagination metadata from DataDog response
public struct DataDogMeta: Codable {
    /// Current page information
    public let page: DataDogPageInfo?

    /// Request ID for debugging
    public let requestId: String?

    enum CodingKeys: String, CodingKey {
        case page
        case requestId = "request_id"
    }
}

/// Page information for pagination
public struct DataDogPageInfo: Codable {
    /// Cursor for next page
    public let after: String?

    /// Total number of results (if available)
    public let total: Int?
}

/// Links for pagination
public struct DataDogLinks: Codable {
    /// Link to next page
    public let next: String?
}

// MARK: - Helper for Any type encoding/decoding

/// Wrapper to handle Any type in Codable
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Cannot encode value of type \(type(of: value))"
            ))
        }
    }
}
