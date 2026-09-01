import MarketPulseCore
import SwiftUI

public extension Vote {
    var color: Color {
        switch self {
        case .bull:
            return .green
        case .bear:
            return .red
        case .neutral:
            return .yellow
        case .na:
            return .gray
        }
    }
}

public enum SignalExplanations {
    public static let byName: [String: String] = [
        "Weekly MACD": "Compares the weekly MACD line to its signal line. Bull when the MACD line is above the signal line, meaning weekly momentum is turning up.",
        "8/21 Weekly MA": "Compares the 8-week moving average to the 21-week moving average. Bull when the shorter average is above the longer one — a classic trend-following signal.",
        "8W EMA Slope": "Bull when the 8-week EMA is higher than it was the prior week, showing momentum is still building.",
        "Cum A/D vs 89-EMA": "Cumulative advance/decline line vs its 89-day EMA. Bull when more stocks have been advancing than declining on a sustained basis.",
        "NHNL Cum vs 10-MA": "Cumulative new-highs-minus-new-lows vs its 10-day average. Bull when more stocks are hitting new highs than new lows.",
        "NYSI Slope": "McClellan Summation Index slope. Bull when breadth momentum (advances vs declines) is accelerating upward.",
        "VIX Regime": "The CBOE Volatility Index. Below 20 = calm (bull), 20–25 = neutral, above 25 = elevated fear (bear).",
        "RSP/SPY Breadth": "Equal-weight S&P 500 (RSP) vs cap-weight S&P 500 (SPY). Bull when equal-weight is outperforming and rising, meaning gains are broad rather than concentrated in a few mega-caps."
    ]
}

public struct MenuHeaderView: View {
    public let snapshot: MarketPulseSnapshot
    public let lastUpdated: Date?
    public let isStale: Bool

    public init(snapshot: MarketPulseSnapshot, lastUpdated: Date?, isStale: Bool = false) {
        self.snapshot = snapshot
        self.lastUpdated = lastUpdated
        self.isStale = isStale
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text("Market Pulse")
                    .font(.headline)
                Spacer()
                VoteBadge(vote: snapshot.label, text: snapshot.label.rawValue)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(snapshot.score)")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("/100")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let vix = snapshot.extras["vix"] {
                    MetricPill(label: "VIX", value: vix)
                }
                if let ratio = snapshot.extras["rsp_spy"] {
                    MetricPill(label: "RSP/SPY", value: ratio)
                }
            }

            ScoreBar(score: snapshot.score, vote: snapshot.label)

            HStack(spacing: 8) {
                Text("As of \(snapshot.asOf)")
                if let lastUpdated {
                    HStack(spacing: 3) {
                        if isStale {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                    }
                    .opacity(isStale ? 0.7 : 1)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

public struct SnapshotSignalsView: View {
    public let snapshot: MarketPulseSnapshot

    public init(snapshot: MarketPulseSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionCard(title: "Trend") {
                SignalRow(signal: signal(named: "Weekly MACD"))
                SignalRow(signal: signal(named: "8/21 Weekly MA"))
                SignalRow(signal: signal(named: "8W EMA Slope"))
            }
            SectionCard(title: "Breadth") {
                SignalRow(signal: signal(named: "Cum A/D vs 89-EMA"))
                SignalRow(signal: signal(named: "NHNL Cum vs 10-MA"))
                SignalRow(signal: signal(named: "NYSI Slope"))
            }
            SectionCard(title: "Risk + Proxy") {
                SignalRow(signal: signal(named: "VIX Regime"))
                SignalRow(signal: signal(named: "RSP/SPY Breadth"))
            }
            if !snapshot.dataHealth.isEmpty {
                SectionCard(title: "Data Health") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(snapshot.dataHealth, id: \.label) { (health: MarketPulseDataHealth) in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(health.label)
                                        .font(.caption)
                                    Spacer()
                                    Text(health.source)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(health.isAvailable ? Color.secondary : Color.orange)
                                }
                                Text(dataSummary(for: health))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if let note = health.note {
                                    Text(note)
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
            if !snapshot.conflicts.isEmpty {
                SectionCard(title: "Conflicts") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(snapshot.conflicts, id: \.self) { conflict in
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(conflict)
                            }
                            .font(.caption)
                            .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
    }

    private func signal(named name: String) -> Signal {
        snapshot.signals.first { $0.name == name } ?? Signal(name: name, vote: .na, detail: "N/A")
    }

    private func dataSummary(for health: MarketPulseDataHealth) -> String {
        guard health.isAvailable else { return "No usable data" }
        let rows = "\(health.rowCount) rows"
        guard let lastDate = health.lastDate else { return rows }
        return "\(rows) through \(lastDate)"
    }
}

public struct VoteBadge: View {
    public let vote: Vote
    public let text: String

    public init(vote: Vote, text: String) {
        self.vote = vote
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(vote.color.opacity(0.18))
            .foregroundStyle(vote.color)
            .clipShape(Capsule())
    }
}

public struct MetricPill: View {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.12))
        .clipShape(Capsule())
    }
}

public struct ScoreBar: View {
    public let score: Int
    public let vote: Vote

    public init(score: Int, vote: Vote) {
        self.score = score
        self.vote = vote
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * CGFloat(min(max(score, 0), 100)) / 100.0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(vote.color)
                    .frame(width: width)
            }
        }
        .frame(height: 5)
    }
}

public struct SignalRow: View {
    public let signal: Signal
    @State private var isExpanded = false

    public init(signal: Signal) {
        self.signal = signal
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(signal.name)
                    .font(.caption)
                Spacer()
                VoteBadge(vote: signal.vote, text: signal.vote.rawValue)
                if SignalExplanations.byName[signal.name] != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            Text(signal.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            if isExpanded, let explanation = SignalExplanations.byName[signal.name] {
                Text(explanation)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            guard SignalExplanations.byName[signal.name] != nil else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.toggle()
            }
        }
    }
}

public struct SectionCard<Content: View>: View {
    public let title: String
    @ViewBuilder public let content: Content

    public init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            content
        }
        .padding(6)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

public struct SectionContainer<Content: View>: View {
    @ViewBuilder public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

public struct SettingsView: View {
    @ObservedObject public var settings: MarketPulseSettings
    public var onDone: (() -> Void)?

    public init(settings: MarketPulseSettings, onDone: (() -> Void)? = nil) {
        self.settings = settings
        self.onDone = onDone
    }

    private var refreshMinutes: Binding<Double> {
        Binding(
            get: { settings.refreshInterval / 60 },
            set: { settings.refreshInterval = $0 * 60 }
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                if let onDone {
                    Button("Done", action: onDone)
                        .font(.caption)
                }
            }

            SectionCard(title: "Refresh") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Every \(Int(refreshMinutes.wrappedValue)) min")
                            .font(.caption)
                        Spacer()
                    }
                    Slider(
                        value: refreshMinutes,
                        in: MarketPulseSettings.refreshIntervalRange.lowerBound / 60...MarketPulseSettings.refreshIntervalRange.upperBound / 60,
                        step: 1
                    )
                }
            }

            SectionCard(title: "Score thresholds") {
                VStack(alignment: .leading, spacing: 8) {
                    thresholdRow(
                        label: "Bull at or above",
                        value: Binding(
                            get: { Double(settings.thresholds.scoreBull) },
                            set: { settings.thresholds.scoreBull = Int($0) }
                        ),
                        range: MarketPulseSettings.scoreThresholdRange,
                        format: "%.0f"
                    )
                    thresholdRow(
                        label: "Neutral at or above",
                        value: Binding(
                            get: { Double(settings.thresholds.scoreNeutral) },
                            set: { settings.thresholds.scoreNeutral = Int($0) }
                        ),
                        range: MarketPulseSettings.scoreThresholdRange,
                        format: "%.0f"
                    )
                }
            }

            SectionCard(title: "VIX thresholds") {
                VStack(alignment: .leading, spacing: 8) {
                    thresholdRow(
                        label: "Bull below",
                        value: Binding(
                            get: { settings.thresholds.vixBull },
                            set: { settings.thresholds.vixBull = $0 }
                        ),
                        range: MarketPulseSettings.vixThresholdRange,
                        format: "%.0f"
                    )
                    thresholdRow(
                        label: "Neutral at or below",
                        value: Binding(
                            get: { settings.thresholds.vixNeutral },
                            set: { settings.thresholds.vixNeutral = $0 }
                        ),
                        range: MarketPulseSettings.vixThresholdRange,
                        format: "%.0f"
                    )
                }
            }

            Button("Reset to defaults") {
                settings.resetToDefaults()
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private func thresholdRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 1)
        }
    }
}
