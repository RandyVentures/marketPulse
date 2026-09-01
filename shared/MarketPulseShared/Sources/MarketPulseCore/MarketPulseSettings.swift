import Foundation

@MainActor
public final class MarketPulseSettings: ObservableObject {
    @Published public var refreshInterval: TimeInterval {
        didSet { defaults.set(refreshInterval, forKey: Keys.refreshInterval) }
    }
    @Published public var thresholds: MarketPulseThresholds {
        didSet {
            defaults.set(thresholds.scoreBull, forKey: Keys.scoreBull)
            defaults.set(thresholds.scoreNeutral, forKey: Keys.scoreNeutral)
            defaults.set(thresholds.vixBull, forKey: Keys.vixBull)
            defaults.set(thresholds.vixNeutral, forKey: Keys.vixNeutral)
        }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let refreshInterval = "marketpulse.refreshInterval"
        static let scoreBull = "marketpulse.scoreBull"
        static let scoreNeutral = "marketpulse.scoreNeutral"
        static let vixBull = "marketpulse.vixBull"
        static let vixNeutral = "marketpulse.vixNeutral"
    }

    public static let refreshIntervalRange: ClosedRange<TimeInterval> = 60...1800
    public static let scoreThresholdRange: ClosedRange<Double> = 0...100
    public static let vixThresholdRange: ClosedRange<Double> = 5...50

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedInterval = defaults.object(forKey: Keys.refreshInterval) as? TimeInterval
        self.refreshInterval = storedInterval ?? 300

        let fallback = MarketPulseThresholds.default
        let scoreBull = defaults.object(forKey: Keys.scoreBull) as? Int ?? fallback.scoreBull
        let scoreNeutral = defaults.object(forKey: Keys.scoreNeutral) as? Int ?? fallback.scoreNeutral
        let vixBull = defaults.object(forKey: Keys.vixBull) as? Double ?? fallback.vixBull
        let vixNeutral = defaults.object(forKey: Keys.vixNeutral) as? Double ?? fallback.vixNeutral
        self.thresholds = MarketPulseThresholds(
            scoreBull: scoreBull,
            scoreNeutral: scoreNeutral,
            vixBull: vixBull,
            vixNeutral: vixNeutral
        )
    }

    public func resetToDefaults() {
        refreshInterval = 300
        thresholds = .default
    }
}
