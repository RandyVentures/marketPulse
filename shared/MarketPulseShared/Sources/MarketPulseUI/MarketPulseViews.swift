import MarketPulseCore
import SwiftUI

public struct MenuHeaderView: View {
    public let snapshot: MarketPulseSnapshot
    public let lastUpdated: Date?

    public init(snapshot: MarketPulseSnapshot, lastUpdated: Date?) {
        self.snapshot = snapshot
        self.lastUpdated = lastUpdated
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
                    Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
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
        }
    }

    private func signal(named name: String) -> Signal {
        snapshot.signals.first { $0.name == name } ?? Signal(name: name, vote: .na, detail: "N/A")
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
            .background(voteColor.opacity(0.18))
            .foregroundStyle(voteColor)
            .clipShape(Capsule())
    }

    private var voteColor: Color {
        switch vote {
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
                    .fill(voteColor)
                    .frame(width: width)
            }
        }
        .frame(height: 5)
    }

    private var voteColor: Color {
        switch vote {
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

public struct SignalRow: View {
    public let signal: Signal

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
            }
            Text(signal.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 2)
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
