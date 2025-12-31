import Foundation

public final class MarketPulseEngine {
    public init() {}

    public func buildSnapshot(
        spy: [PriceBar],
        rsp: [PriceBar],
        vix: [VixPoint],
        breadth: [BreadthPoint]?
    ) -> MarketPulseSnapshot {
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
            let adSignal = Signal(
                name: "Cum A/D vs 89-EMA",
                vote: (cumAD.last ?? 0) > (ema89.last ?? 0) ? .bull : .bear,
                detail: String(format: "Cum %.0f vs EMA %.0f", cumAD.last ?? 0, ema89.last ?? 0)
            )

            let nhnlDaily = breadth.map { $0.newHighs - $0.newLows }
            let cumNHNL = IndicatorMath.cumulative(nhnlDaily)
            let ma10 = IndicatorMath.sma(cumNHNL, window: 10)
            let nhnlSignal = Signal(
                name: "NHNL Cum vs 10-MA",
                vote: (cumNHNL.last ?? 0) > (ma10.last ?? 0) ? .bull : .bear,
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
