import Foundation

public enum Vote: String, Codable {
    case bull = "BULL"
    case bear = "BEAR"
    case neutral = "NEUTRAL"
    case na = "N/A"
}

public struct Signal: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let vote: Vote
    public let detail: String

    public init(name: String, vote: Vote, detail: String) {
        self.id = UUID()
        self.name = name
        self.vote = vote
        self.detail = detail
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case vote
        case detail
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        vote = try container.decode(Vote.self, forKey: .vote)
        detail = try container.decode(String.self, forKey: .detail)
    }
}

public struct MarketPulseDataHealth: Codable, Equatable, Identifiable {
    public let label: String
    public let source: String
    public let rowCount: Int
    public let lastDate: String?
    public let note: String?

    public init(
        label: String,
        source: String,
        rowCount: Int,
        lastDate: String? = nil,
        note: String? = nil
    ) {
        self.label = label
        self.source = source
        self.rowCount = rowCount
        self.lastDate = lastDate
        self.note = note
    }

    public var isAvailable: Bool {
        rowCount > 0
    }

    public var id: String {
        label
    }
}

public struct MarketPulseSnapshot: Codable {
    public let asOf: String
    public let score: Int
    public let label: Vote
    public let signals: [Signal]
    public let conflicts: [String]
    public let extras: [String: String]
    public let dataHealth: [MarketPulseDataHealth]

    public init(
        asOf: String,
        score: Int,
        label: Vote,
        signals: [Signal],
        conflicts: [String],
        extras: [String: String],
        dataHealth: [MarketPulseDataHealth] = []
    ) {
        self.asOf = asOf
        self.score = score
        self.label = label
        self.signals = signals
        self.conflicts = conflicts
        self.extras = extras
        self.dataHealth = dataHealth
    }

    private enum CodingKeys: String, CodingKey {
        case asOf
        case score
        case label
        case signals
        case conflicts
        case extras
        case dataHealth
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        asOf = try container.decode(String.self, forKey: .asOf)
        score = try container.decode(Int.self, forKey: .score)
        label = try container.decode(Vote.self, forKey: .label)
        signals = try container.decode([Signal].self, forKey: .signals)
        conflicts = try container.decode([String].self, forKey: .conflicts)
        extras = try container.decode([String: String].self, forKey: .extras)
        dataHealth = try container.decodeIfPresent([MarketPulseDataHealth].self, forKey: .dataHealth) ?? []
    }
}

public struct PriceBar {
    public let date: Date
    public let close: Double

    public init(date: Date, close: Double) {
        self.date = date
        self.close = close
    }
}

public struct VixPoint {
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public struct BreadthPoint {
    public let date: Date
    public let advances: Double
    public let declines: Double
    public let newHighs: Double
    public let newLows: Double

    public init(date: Date, advances: Double, declines: Double, newHighs: Double, newLows: Double) {
        self.date = date
        self.advances = advances
        self.declines = declines
        self.newHighs = newHighs
        self.newLows = newLows
    }
}

public struct MarketPulseThresholds: Equatable {
    public var scoreBull: Int
    public var scoreNeutral: Int
    public var vixBull: Double
    public var vixNeutral: Double

    public init(
        scoreBull: Int = 60,
        scoreNeutral: Int = 40,
        vixBull: Double = 20,
        vixNeutral: Double = 25
    ) {
        self.scoreBull = scoreBull
        self.scoreNeutral = scoreNeutral
        self.vixBull = vixBull
        self.vixNeutral = vixNeutral
    }

    public static let `default` = MarketPulseThresholds()
}
