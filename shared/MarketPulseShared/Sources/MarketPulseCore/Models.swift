import Foundation

public enum Vote: String, Codable {
    case bull = "BULL"
    case bear = "BEAR"
    case neutral = "NEUTRAL"
    case na = "N/A"
}

public struct Signal: Identifiable {
    public let id = UUID()
    public let name: String
    public let vote: Vote
    public let detail: String

    public init(name: String, vote: Vote, detail: String) {
        self.name = name
        self.vote = vote
        self.detail = detail
    }
}

public struct MarketPulseSnapshot {
    public let asOf: String
    public let score: Int
    public let label: Vote
    public let signals: [Signal]
    public let conflicts: [String]
    public let extras: [String: String]

    public init(
        asOf: String,
        score: Int,
        label: Vote,
        signals: [Signal],
        conflicts: [String],
        extras: [String: String]
    ) {
        self.asOf = asOf
        self.score = score
        self.label = label
        self.signals = signals
        self.conflicts = conflicts
        self.extras = extras
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
