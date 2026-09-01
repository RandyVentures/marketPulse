import Foundation

public struct ProviderChainError: Error, LocalizedError {
    public let label: String
    public let errors: [String]

    public init(label: String, errors: [String]) {
        self.label = label
        self.errors = errors
    }

    public var lastError: String {
        errors.last ?? "no data returned"
    }

    public var errorDescription: String? {
        let details = errors.isEmpty ? "no data returned" : errors.joined(separator: "; ")
        return "\(label) failed: \(details)"
    }
}

private struct ProviderChain<Value> {
    typealias Provider = () async throws -> Value?

    let label: String
    let providers: [Provider]
    let isUsable: (Value) -> Bool

    func load() async throws -> Value {
        var errors: [String] = []
        for provider in providers {
            do {
                guard let value = try await provider() else {
                    errors.append("no data returned")
                    continue
                }
                guard isUsable(value) else {
                    errors.append("no data returned")
                    continue
                }
                return value
            } catch {
                errors.append(error.localizedDescription)
            }
        }
        throw ProviderChainError(label: label, errors: errors)
    }
}

private enum MarketDataError: Error, LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case invalidPayload(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response"
        case let .httpStatus(statusCode):
            return "HTTP status \(statusCode)"
        case let .invalidPayload(message):
            return message
        }
    }
}

public final class MarketDataFetcher {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private let allowLocal: Bool
    private let dataDirectory: URL?

    public init(dataDirectory: URL? = nil, allowLocal: Bool = false) {
        self.dataDirectory = dataDirectory
        self.allowLocal = allowLocal
    }

    public func loadPrices(symbol: String) async throws -> [PriceBar] {
        try await ProviderChain(
            label: "Market data \(symbol.uppercased())",
            providers: [
                { try self.loadLocalPrices(symbol: symbol) },
                { try await self.fetchStooq(symbol: symbol) },
                { try await self.fetchYahoo(symbol: symbol) }
            ],
            isUsable: { !$0.isEmpty }
        ).load()
    }

    public func loadVix() async throws -> [VixPoint] {
        try await ProviderChain(
            label: "VIX data",
            providers: [
                { try self.loadLocalVix() },
                { try await self.fetchFredVix() }
            ],
            isUsable: { !$0.isEmpty }
        ).load()
    }

    public func loadBreadth() async throws -> [BreadthPoint]? {
        do {
            return try await ProviderChain(
                label: "Breadth data",
                providers: [
                    { try self.loadLocalBreadth() }
                ],
                isUsable: { !$0.isEmpty }
            ).load()
        } catch {
            // Breadth is optional in the Python implementation; lack of a local
            // file should not prevent the rest of the snapshot from loading.
            return nil
        }
    }

    private func localURL(filename: String) -> URL? {
        guard allowLocal, let dataDirectory else { return nil }
        return dataDirectory.appendingPathComponent(filename)
    }

    private func loadLocalPrices(symbol: String) throws -> [PriceBar]? {
        guard let path = localURL(filename: "\(symbol.uppercased()).csv") else {
            return nil
        }
        guard FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }
        let content = try String(contentsOf: path, encoding: .utf8)
        return parseStooqCSV(content)
    }

    private func loadLocalVix() throws -> [VixPoint]? {
        guard let path = localURL(filename: "VIX.csv") else {
            return nil
        }
        guard FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }
        let content = try String(contentsOf: path, encoding: .utf8)
        return parseVixCSV(content)
    }

    private func loadLocalBreadth() throws -> [BreadthPoint]? {
        guard let path = localURL(filename: "breadth.csv") else {
            return nil
        }
        guard FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }
        let content = try String(contentsOf: path, encoding: .utf8)
        return parseBreadthCSV(content)
    }

    private func fetchStooq(symbol: String) async throws -> [PriceBar] {
        let ticker = symbol.lowercased() + ".us"
        let url = URL(string: "https://stooq.com/q/d/l/?s=\(ticker)&i=d")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response)
        let content = String(data: data, encoding: .utf8) ?? ""
        return parseStooqCSV(content)
    }

    private func fetchFredVix() async throws -> [VixPoint] {
        let url = URL(string: "https://fred.stlouisfed.org/graph/fredgraph.csv?id=VIXCLS")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response)
        let content = String(data: data, encoding: .utf8) ?? ""
        return parseVixCSV(content)
    }

    private func fetchYahoo(symbol: String) async throws -> [PriceBar] {
        let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encodedSymbol)")
        components?.queryItems = [
            URLQueryItem(name: "range", value: "2y"),
            URLQueryItem(name: "interval", value: "1d")
        ]
        guard let url = components?.url else {
            throw MarketDataError.invalidPayload("Invalid Yahoo Finance URL")
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response)
        return try parseYahooChartJSON(data)
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MarketDataError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw MarketDataError.httpStatus(httpResponse.statusCode)
        }
    }

    func parseStooqCSV(_ content: String) -> [PriceBar] {
        let lines = content.split(whereSeparator: \.isNewline)
        guard lines.count > 1 else { return [] }
        var bars: [PriceBar] = []
        for line in lines.dropFirst() {
            let parts = line.split(separator: ",", omittingEmptySubsequences: false)
            guard parts.count >= 5 else { continue }
            let dateStr = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let closeStr = String(parts[4]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let date = dateFormatter.date(from: dateStr), let close = Double(closeStr) else { continue }
            bars.append(PriceBar(date: date, close: close))
        }
        return bars.sorted { $0.date < $1.date }
    }

    func parseVixCSV(_ content: String) -> [VixPoint] {
        let lines = content.split(whereSeparator: \.isNewline)
        guard lines.count > 1 else { return [] }
        var points: [VixPoint] = []
        for line in lines.dropFirst() {
            let parts = line.split(separator: ",", omittingEmptySubsequences: false)
            guard parts.count >= 2 else { continue }
            let dateStr = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let valueStr = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            if valueStr == "." { continue }
            guard let date = dateFormatter.date(from: dateStr), let value = Double(valueStr) else { continue }
            points.append(VixPoint(date: date, value: value))
        }
        return points.sorted { $0.date < $1.date }
    }

    func parseBreadthCSV(_ content: String) -> [BreadthPoint] {
        let lines = content.split(whereSeparator: \.isNewline)
        guard lines.count > 1 else { return [] }
        let header = lines.first?.split(separator: ",").map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        } ?? []
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

    func parseYahooChartJSON(_ data: Data) throws -> [PriceBar] {
        let payload: YahooChartPayload
        do {
            payload = try JSONDecoder().decode(YahooChartPayload.self, from: data)
        } catch {
            throw MarketDataError.invalidPayload("Invalid Yahoo Finance payload: \(error.localizedDescription)")
        }

        guard let result = payload.chart.result?.first else {
            let message = payload.chart.error?.description ?? "Yahoo Finance returned no data"
            throw MarketDataError.invalidPayload(message)
        }
        guard let timestamps = result.timestamp, let quotes = result.indicators.quote.first,
              let closes = quotes.close else {
            throw MarketDataError.invalidPayload("Yahoo Finance returned no price series")
        }

        var bars: [PriceBar] = []
        for (timestamp, close) in zip(timestamps, closes) {
            guard let close, close.isFinite else { continue }
            bars.append(PriceBar(date: Date(timeIntervalSince1970: TimeInterval(timestamp)), close: close))
        }
        return bars.sorted { $0.date < $1.date }
    }
}

private struct YahooChartPayload: Decodable {
    let chart: YahooChart
}

private struct YahooChart: Decodable {
    let result: [YahooChartResult]?
    let error: YahooChartError?
}

private struct YahooChartResult: Decodable {
    let timestamp: [Int64]?
    let indicators: YahooIndicators
}

private struct YahooIndicators: Decodable {
    let quote: [YahooQuote]
}

private struct YahooQuote: Decodable {
    let close: [Double?]?
}

private struct YahooChartError: Decodable {
    let description: String?
}
