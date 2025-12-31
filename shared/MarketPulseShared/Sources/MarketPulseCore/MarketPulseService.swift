import Combine
import Foundation

public struct MarketPulseConfiguration {
    public var refreshInterval: TimeInterval
    public var allowLocal: Bool
    public var dataDirectory: URL?
    public var logFileURL: URL?

    public init(
        refreshInterval: TimeInterval = 300,
        allowLocal: Bool = false,
        dataDirectory: URL? = nil,
        logFileURL: URL? = nil
    ) {
        self.refreshInterval = refreshInterval
        self.allowLocal = allowLocal
        self.dataDirectory = dataDirectory
        self.logFileURL = logFileURL
    }

    public static var `default`: MarketPulseConfiguration {
        MarketPulseConfiguration()
    }
}

@MainActor
public final class MarketPulseService: ObservableObject {
    @Published public var snapshot: MarketPulseSnapshot?
    @Published public var errorMessage: String?
    @Published public var lastUpdated: Date?
    @Published public var statusMessage: String?
    @Published public var logPath: String?
    @Published public var isRefreshing = false

    private let fetcher: MarketDataFetcher
    private let engine = MarketPulseEngine()
    private var timer: Timer?
    private let logURL: URL?
    private let refreshInterval: TimeInterval

    public init(configuration: MarketPulseConfiguration = .default) {
        self.fetcher = MarketDataFetcher(
            dataDirectory: configuration.dataDirectory,
            allowLocal: configuration.allowLocal
        )
        self.logURL = configuration.logFileURL
        self.logPath = configuration.logFileURL?.path
        self.refreshInterval = configuration.refreshInterval
        log("Initialized")
    }

    public func start() {
        timer?.invalidate()
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.refresh()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func refresh() async {
        if isRefreshing {
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            log("Refresh start")
            async let spy = fetcher.loadPrices(symbol: "SPY")
            async let rsp = fetcher.loadPrices(symbol: "RSP")
            async let vix = fetcher.loadVix()
            async let breadth = fetcher.loadBreadth()
            let snapshot = engine.buildSnapshot(
                spy: try await spy,
                rsp: try await rsp,
                vix: try await vix,
                breadth: try await breadth
            )
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
        guard let logURL else { return }
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
                try FileManager.default.createDirectory(
                    at: logURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: logURL, options: .atomic)
            }
        } catch {
            // ignore logging errors
        }
    }
}
