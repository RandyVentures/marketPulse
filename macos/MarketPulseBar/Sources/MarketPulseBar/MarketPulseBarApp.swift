import AppKit
import Foundation
import SwiftUI

// MARK: - Models

enum Vote: String, Codable {
    case bull = "BULL"
    case bear = "BEAR"
    case neutral = "NEUTRAL"
    case na = "N/A"
}

struct Signal: Identifiable {
    let id = UUID()
    let name: String
    let vote: Vote
    let detail: String
}

struct MarketPulseSnapshot {
    let asOf: String
    let score: Int
    let label: Vote
    let signals: [Signal]
    let conflicts: [String]
    let extras: [String: String]
}

struct PriceBar {
    let date: Date
    let close: Double
}

struct VixPoint {
    let date: Date
    let value: Double
}

struct BreadthPoint {
    let date: Date
    let advances: Double
    let declines: Double
    let newHighs: Double
    let newLows: Double
}

// MARK: - Data Fetching

final class MarketDataFetcher {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    func loadPrices(symbol: String) async throws -> [PriceBar] {
        if let local = try loadLocalPrices(symbol: symbol) {
            return local
        }
        return try await fetchStooq(symbol: symbol)
    }

    func loadVix() async throws -> [VixPoint] {
        if let local = try loadLocalVix() {
            return local
        }
        return try await fetchFredVix()
    }

    func loadBreadth() async throws -> [BreadthPoint]? {
        return try loadLocalBreadth()
    }

    private func loadLocalPrices(symbol: String) throws -> [PriceBar]? {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".marketpulse")
            .appendingPathComponent("data")
            .appendingPathComponent("\(symbol.uppercased()).csv")
        guard FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }
        let content = try String(contentsOf: path, encoding: .utf8)
        return parseStooqCSV(content)
    }

    private func loadLocalVix() throws -> [VixPoint]? {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".marketpulse")
            .appendingPathComponent("data")
            .appendingPathComponent("VIX.csv")
        guard FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }
        let content = try String(contentsOf: path, encoding: .utf8)
        return parseVixCSV(content)
    }

    private func loadLocalBreadth() throws -> [BreadthPoint]? {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".marketpulse")
            .appendingPathComponent("data")
            .appendingPathComponent("breadth.csv")
        guard FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }
        let content = try String(contentsOf: path, encoding: .utf8)
        return parseBreadthCSV(content)
    }

    private func fetchStooq(symbol: String) async throws -> [PriceBar] {
        let ticker = symbol.lowercased() + ".us"
        let url = URL(string: "https://stooq.com/q/d/l/?s=\(ticker)&i=d")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let content = String(data: data, encoding: .utf8) ?? ""
        return parseStooqCSV(content)
    }

    private func fetchFredVix() async throws -> [VixPoint] {
        let url = URL(string: "https://fred.stlouisfed.org/graph/fredgraph.csv?id=VIXCLS")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let content = String(data: data, encoding: .utf8) ?? ""
        return parseVixCSV(content)
    }

    private func parseStooqCSV(_ content: String) -> [PriceBar] {
        let lines = content.split(whereSeparator: \ .isNewline)
        guard lines.count > 1 else { return [] }
        var bars: [PriceBar] = []
        for line in lines.dropFirst() {
            let parts = line.split(separator: ",")
            guard parts.count >= 5 else { continue }
            let dateStr = String(parts[0])
            let closeStr = String(parts[4])
            guard let date = dateFormatter.date(from: dateStr), let close = Double(closeStr) else { continue }
            bars.append(PriceBar(date: date, close: close))
        }
        return bars.sorted { $0.date < $1.date }
    }

    private func parseVixCSV(_ content: String) -> [VixPoint] {
        let lines = content.split(whereSeparator: \ .isNewline)
        guard lines.count > 1 else { return [] }
        var points: [VixPoint] = []
        for line in lines.dropFirst() {
            let parts = line.split(separator: ",")
            guard parts.count >= 2 else { continue }
            let dateStr = String(parts[0])
            let valueStr = String(parts[1])
            if valueStr == "." { continue }
            guard let date = dateFormatter.date(from: dateStr), let value = Double(valueStr) else { continue }
            points.append(VixPoint(date: date, value: value))
        }
        return points.sorted { $0.date < $1.date }
    }

    private func parseBreadthCSV(_ content: String) -> [BreadthPoint] {
        let lines = content.split(whereSeparator: \ .isNewline)
        guard lines.count > 1 else { return [] }
        let header = lines.first?.split(separator: ",").map { $0.lowercased() } ?? []
        let dateIdx = header.firstIndex(of: "date")
        let advIdx = header.firstIndex(of: "advances")
        let decIdx = header.firstIndex(of: "declines")
        let nhIdx = header.firstIndex(of: "new_highs")
        let nlIdx = header.firstIndex(of: "new_lows")
        guard let d = dateIdx, let a = advIdx, let c = decIdx, let h = nhIdx, let l = nlIdx else {
            return []
        }
        var points: [BreadthPoint] = []
        for line in lines.dropFirst() {
            let parts = line.split(separator: ",")
            guard parts.count > max(d, a, c, h, l) else { continue }
            let dateStr = String(parts[d])
            guard let date = dateFormatter.date(from: dateStr) else { continue }
            guard
                let adv = Double(parts[a]),
                let dec = Double(parts[c]),
                let nh = Double(parts[h]),
                let nl = Double(parts[l])
            else { continue }
            points.append(BreadthPoint(date: date, advances: adv, declines: dec, newHighs: nh, newLows: nl))
        }
        return points.sorted { $0.date < $1.date }
    }
}

// MARK: - Indicators

enum IndicatorMath {
    static func sma(_ series: [Double], window: Int) -> [Double] {
        guard window > 0 else { return series }
        var result: [Double] = []
        for idx in 0..<series.count {
            let start = max(0, idx - window + 1)
            let slice = series[start...idx]
            let avg = slice.reduce(0, +) / Double(slice.count)
            result.append(avg)
        }
        return result
    }

    static func ema(_ series: [Double], span: Int) -> [Double] {
        guard !series.isEmpty else { return [] }
        let alpha = 2.0 / (Double(span) + 1.0)
        var result: [Double] = []
        var current = series[0]
        result.append(current)
        for value in series.dropFirst() {
            current = alpha * value + (1 - alpha) * current
            result.append(current)
        }
        return result
    }

    static func macd(_ series: [Double], fast: Int = 12, slow: Int = 26, signal: Int = 9) -> (line: [Double], signal: [Double]) {
        let fastEma = ema(series, span: fast)
        let slowEma = ema(series, span: slow)
        let macdLine = zip(fastEma, slowEma).map { $0 - $1 }
        let signalLine = ema(macdLine, span: signal)
        return (macdLine, signalLine)
    }

    static func cumulative(_ series: [Double]) -> [Double] {
        var total = 0.0
        return series.map { value in
            total += value
            return total
        }
    }
}

// MARK: - Engine

final class MarketPulseEngine {
    func buildSnapshot(spy: [PriceBar], rsp: [PriceBar], vix: [VixPoint], breadth: [BreadthPoint]?) -> MarketPulseSnapshot {
        let weekly = weeklySeries(prices: spy)
        let weeklyClose = weekly.map { $0.close }

        let (macdLine, signalLine) = IndicatorMath.macd(weeklyClose)
        let macdBull = macdLine.last ?? 0 > signalLine.last ?? 0
        let macdSignal = Signal(
            name: "Weekly MACD",
            vote: macdBull ? .bull : .bear,
            detail: String(format: "MACD %.2f vs signal %.2f", macdLine.last ?? 0, signalLine.last ?? 0)
        )

        let ma8 = IndicatorMath.sma(weeklyClose, window: 8)
        let ma21 = IndicatorMath.sma(weeklyClose, window: 21)
        let maBull = (ma8.last ?? 0) > (ma21.last ?? 0)
        let maSignal = Signal(
            name: "8/21 Weekly MA",
            vote: maBull ? .bull : .bear,
            detail: String(format: "8W %.2f vs 21W %.2f", ma8.last ?? 0, ma21.last ?? 0)
        )

        let ema8 = IndicatorMath.ema(weeklyClose, span: 8)
        let emaSlope = (ema8.count >= 2) ? ema8[ema8.count - 1] - ema8[ema8.count - 2] : 0
        let emaSignal = Signal(
            name: "8W EMA Slope",
            vote: emaSlope > 0 ? .bull : .bear,
            detail: String(format: "Slope %.2f", emaSlope)
        )

        let vixValue = vix.last?.value ?? 0
        let vixVote: Vote
        if vixValue < 20 {
            vixVote = .bull
        } else if vixValue <= 25 {
            vixVote = .neutral
        } else {
            vixVote = .bear
        }
        let vixSignal = Signal(
            name: "VIX Regime",
            vote: vixVote,
            detail: String(format: "VIX %.2f", vixValue)
        )

        let ratioSeries = ratio(pricesA: rsp, pricesB: spy)
        let ratioValues = ratioSeries.map { $0.close }
        let ratioSma = IndicatorMath.sma(ratioValues, window: 50)
        let ratioSlope = ratioValues.count >= 2 ? ratioValues.last! - ratioValues[ratioValues.count - 2] : 0
        let ratioBull = (ratioValues.last ?? 0) > (ratioSma.last ?? 0) && ratioSlope > 0
        let ratioSignal = Signal(
            name: "RSP/SPY Breadth",
            vote: ratioBull ? .bull : .bear,
            detail: String(format: "Ratio %.4f vs SMA %.4f", ratioValues.last ?? 0, ratioSma.last ?? 0)
        )

        let breadthSignals: [Signal]
        if let breadth, !breadth.isEmpty {
            let adDaily = breadth.map { $0.advances - $0.declines }
            let cumAD = IndicatorMath.cumulative(adDaily)
            let ema89 = IndicatorMath.ema(cumAD, span: 89)
            let adBull = (cumAD.last ?? 0) > (ema89.last ?? 0)
            let adSignal = Signal(
                name: "Cum A/D vs 89-EMA",
                vote: adBull ? .bull : .bear,
                detail: String(format: "Cum %.0f vs EMA %.0f", cumAD.last ?? 0, ema89.last ?? 0)
            )

            let nhnlDaily = breadth.map { $0.newHighs - $0.newLows }
            let cumNHNL = IndicatorMath.cumulative(nhnlDaily)
            let ma10 = IndicatorMath.sma(cumNHNL, window: 10)
            let nhnlBull = (cumNHNL.last ?? 0) > (ma10.last ?? 0)
            let nhnlSignal = Signal(
                name: "NHNL Cum vs 10-MA",
                vote: nhnlBull ? .bull : .bear,
                detail: String(format: "Cum %.0f vs MA %.0f", cumNHNL.last ?? 0, ma10.last ?? 0)
            )

            let ema19 = IndicatorMath.ema(adDaily, span: 19)
            let ema39 = IndicatorMath.ema(adDaily, span: 39)
            let osc = zip(ema19, ema39).map { $0 - $1 }
            let nysi = IndicatorMath.cumulative(osc)
            let slope = nysi.count > 6 ? (nysi.last ?? 0) - nysi[nysi.count - 6] : (nysi.last ?? 0)
            let nysiSignal = Signal(
                name: "NYSI Slope",
                vote: slope > 0 ? .bull : .bear,
                detail: String(format: "Slope %.2f", slope)
            )

            breadthSignals = [adSignal, nhnlSignal, nysiSignal]
        } else {
            breadthSignals = [
                Signal(name: "Cum A/D vs 89-EMA", vote: .na, detail: "Breadth unavailable"),
                Signal(name: "NHNL Cum vs 10-MA", vote: .na, detail: "Breadth unavailable"),
                Signal(name: "NYSI Slope", vote: .na, detail: "Breadth unavailable")
            ]
        }

        let signals = [macdSignal, maSignal, emaSignal] + breadthSignals + [vixSignal, ratioSignal]
        let (score, label) = scoreSignals(signals)
        let asOfDate = max(spy.last?.date ?? Date.distantPast, vix.last?.date ?? Date.distantPast)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let asOf = dateFormatter.string(from: asOfDate)

        let extras = [
            "vix": String(format: "%.2f", vixValue),
            "rsp_spy": String(format: "%.4f", ratioValues.last ?? 0)
        ]

        return MarketPulseSnapshot(asOf: asOf, score: score, label: label, signals: signals, conflicts: [], extras: extras)
    }

    private func weeklySeries(prices: [PriceBar]) -> [PriceBar] {
        var buckets: [String: PriceBar] = [:]
        let calendar = Calendar(identifier: .gregorian)
        for bar in prices {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: bar.date)
            let key = "\(comps.yearForWeekOfYear ?? 0)-\(comps.weekOfYear ?? 0)"
            if let existing = buckets[key] {
                if bar.date > existing.date {
                    buckets[key] = bar
                }
            } else {
                buckets[key] = bar
            }
        }
        return buckets.values.sorted { $0.date < $1.date }
    }

    private func ratio(pricesA: [PriceBar], pricesB: [PriceBar]) -> [PriceBar] {
        let mapB = Dictionary(uniqueKeysWithValues: pricesB.map { ($0.date, $0.close) })
        var ratioBars: [PriceBar] = []
        for bar in pricesA {
            if let closeB = mapB[bar.date] {
                ratioBars.append(PriceBar(date: bar.date, close: bar.close / closeB))
            }
        }
        return ratioBars.sorted { $0.date < $1.date }
    }

    private func scoreSignals(_ signals: [Signal]) -> (Int, Vote) {
        let scoreMap: [Vote: Int] = [.bull: 1, .bear: -1, .neutral: 0, .na: 0]
        let raw = signals.reduce(0) { $0 + (scoreMap[$1.vote] ?? 0) }
        let maxScore = max(signals.count, 1)
        let normalized = Int(round(Double(raw + maxScore) / Double(2 * maxScore) * 100))
        let label: Vote
        if normalized >= 60 {
            label = .bull
        } else if normalized >= 40 {
            label = .neutral
        } else {
            label = .bear
        }
        return (normalized, label)
    }
}

// MARK: - Service + Logging

@MainActor
final class MarketPulseService: ObservableObject {
    static let shared = MarketPulseService()

    @Published var snapshot: MarketPulseSnapshot?
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var statusMessage: String?
    @Published var logPath: String?

    private let fetcher = MarketDataFetcher()
    private let engine = MarketPulseEngine()
    private var timer: Timer?
    private let logURL: URL

    init() {
        let logsDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
        self.logURL = logsDir.appendingPathComponent("MarketPulseBar.log")
        self.logPath = logURL.path
        log("Initialized")
    }

    func start() {
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in
                await self.refresh()
            }
        }
    }

    func refresh() async {
        do {
            log("Refresh start")
            async let spy = fetcher.loadPrices(symbol: "SPY")
            async let rsp = fetcher.loadPrices(symbol: "RSP")
            async let vix = fetcher.loadVix()
            async let breadth = fetcher.loadBreadth()
            let snapshot = engine.buildSnapshot(spy: try await spy, rsp: try await rsp, vix: try await vix, breadth: try await breadth)
            self.snapshot = snapshot
            self.errorMessage = nil
            self.statusMessage = "OK"
            self.lastUpdated = Date()
            log("Refresh ok")
        } catch {
            self.snapshot = nil
            self.errorMessage = error.localizedDescription
            self.statusMessage = "Failed"
            self.lastUpdated = Date()
            log("Refresh failed: \(error.localizedDescription)")
        }
    }

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        do {
            let data = Data(line.utf8)
            if FileManager.default.fileExists(atPath: logURL.path) {
                let handle = try FileHandle(forWritingTo: logURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: logURL, options: .atomic)
            }
        } catch {
            // ignore logging errors
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MarketPulseService.shared.start()
    }
}

// MARK: - UI

struct MenuHeaderView: View {
    let snapshot: MarketPulseSnapshot
    let lastUpdated: Date?

    var body: some View {
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

struct SnapshotSignalsView: View {
    let snapshot: MarketPulseSnapshot

    var body: some View {
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

@main
struct MarketPulseBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var service = MarketPulseService.shared

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if let snapshot = service.snapshot {
                            SectionContainer {
                                MenuHeaderView(snapshot: snapshot, lastUpdated: service.lastUpdated)
                            }
                            SnapshotSignalsView(snapshot: snapshot)
                        } else {
                            SectionContainer {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("No data yet")
                                        .font(.headline)
                                    if let lastUpdated = service.lastUpdated {
                                        Text("Last update: \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let status = service.statusMessage {
                                        Text("Status: \(status)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let errorMessage = service.errorMessage {
                                        Text(errorMessage)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .padding(10)
                }
                Divider()
                HStack(spacing: 12) {
                    Button("Refresh") {
                        Task { await service.refresh() }
                    }
                    Button("Data Folder") {
                        let path = FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent(".marketpulse")
                            .appendingPathComponent("data")
                        NSWorkspace.shared.open(path)
                    }
                    Spacer()
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                }
                .padding(10)
            }
            .frame(width: 320, height: 420)
        } label: {
            Text(menuTitle)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuTitle: String {
        if let snapshot = service.snapshot {
            return "MP \(snapshot.label.rawValue) \(snapshot.score)"
        }
        return "MP --"
    }
}

// MARK: - UI Helpers

struct VoteBadge: View {
    let vote: Vote
    let text: String

    var body: some View {
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

struct MetricPill: View {
    let label: String
    let value: String

    var body: some View {
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

struct ScoreBar: View {
    let score: Int
    let vote: Vote

    var body: some View {
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

struct SignalRow: View {
    let signal: Signal

    var body: some View {
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

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
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

struct SectionContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
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
