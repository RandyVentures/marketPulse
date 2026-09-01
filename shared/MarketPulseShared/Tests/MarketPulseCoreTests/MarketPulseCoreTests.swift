import Foundation
import XCTest
@testable import MarketPulseCore

final class IndicatorMathTests: XCTestCase {
    func testSMAUsesAvailableValuesBeforeWindowIsFull() {
        XCTAssertEqual(
            IndicatorMath.sma([1, 2, 3, 4], window: 3),
            [1, 1.5, 2, 3]
        )
    }

    func testEMAUsesTheRecursiveFormula() {
        let actual = IndicatorMath.ema([1, 2, 3, 4], span: 3)
        let expected = [1.0, 1.5, 2.25, 3.125]

        XCTAssertEqual(actual.count, expected.count)
        for (actualValue, expectedValue) in zip(actual, expected) {
            XCTAssertEqual(actualValue, expectedValue, accuracy: 0.000001)
        }
    }

    func testMACDAndCumulativeMatchSmallFixtures() {
        let result = IndicatorMath.macd([1, 2, 3], fast: 2, slow: 3, signal: 2)

        let expectedLine = [0.0, 1.0 / 6.0, 11.0 / 36.0]
        let expectedSignal = [0.0, 1.0 / 9.0, 13.0 / 54.0]
        for (actualValue, expectedValue) in zip(result.line, expectedLine) {
            XCTAssertEqual(actualValue, expectedValue, accuracy: 0.000001)
        }
        for (actualValue, expectedValue) in zip(result.signal, expectedSignal) {
            XCTAssertEqual(actualValue, expectedValue, accuracy: 0.000001)
        }
        XCTAssertEqual(IndicatorMath.cumulative([2, -3, 4]), [2, -1, 3])
    }
}

final class MarketPulseEngineTests: XCTestCase {
    func testBullishSnapshotUsesBullLabelAndDetectsWeakBreadth() {
        let spy = makePrices { index in 100 + Double(index) * 2 }
        let rsp = makePrices { index in
            let spyClose = 100 + Double(index) * 2
            return spyClose * (0.8 + Double(index) * 0.002)
        }
        let breadth = makeBreadth { _ in (advances: 100.0, declines: 200.0, newHighs: 10.0, newLows: 20.0) }

        let snapshot = MarketPulseEngine().buildSnapshot(
            spy: spy,
            rsp: rsp,
            vix: [VixPoint(date: spy.last!.date, value: 15)],
            breadth: breadth
        )

        XCTAssertEqual(snapshot.label, .bull)
        XCTAssertGreaterThanOrEqual(snapshot.score, 60)
        XCTAssertEqual(snapshot.conflicts, ["Trend bullish but breadth weakening"])
    }

    func testBearishSnapshotUsesBearLabelAndDetectsImprovingBreadth() {
        let spy = makePrices { index in 200 - Double(index) * 2 }
        let rsp = makePrices { index in
            let spyClose = 200 - Double(index) * 2
            return spyClose * (0.9 - Double(index) * 0.001)
        }
        let breadth = makeBreadth { index in
            (
                advances: 200.0 + Double(index),
                declines: 100.0,
                newHighs: 30.0 + Double(index),
                newLows: 10.0
            )
        }

        let snapshot = MarketPulseEngine().buildSnapshot(
            spy: spy,
            rsp: rsp,
            vix: [VixPoint(date: spy.last!.date, value: 30)],
            breadth: breadth
        )

        XCTAssertEqual(snapshot.label, .bear)
        XCTAssertLessThan(snapshot.score, 40)
        XCTAssertEqual(snapshot.conflicts, ["Trend bearish but breadth improving"])
    }

    func testCustomScoreThresholdsChangeTheLabelWithoutChangingScore() {
        let spy = makePrices { index in 100 + Double(index) * 2 }
        let rsp = makePrices { index in
            let spyClose = 100 + Double(index) * 2
            return spyClose * (0.8 + Double(index) * 0.002)
        }

        let snapshot = MarketPulseEngine().buildSnapshot(
            spy: spy,
            rsp: rsp,
            vix: [VixPoint(date: spy.last!.date, value: 15)],
            breadth: nil
        )
        let stricter = MarketPulseEngine().buildSnapshot(
            spy: spy,
            rsp: rsp,
            vix: [VixPoint(date: spy.last!.date, value: 15)],
            breadth: nil,
            thresholds: MarketPulseThresholds(scoreBull: 90, scoreNeutral: 80)
        )

        XCTAssertEqual(snapshot.label, .bull)
        XCTAssertEqual(stricter.score, snapshot.score)
        XCTAssertEqual(stricter.label, .neutral)
    }

    private func makePrices(_ close: (Int) -> Double) -> [PriceBar] {
        let calendar = Calendar(identifier: .gregorian)
        let start = date("2023-01-06")
        return (0..<30).map { index in
            PriceBar(
                date: calendar.date(byAdding: .day, value: index * 7, to: start)!,
                close: close(index)
            )
        }
    }

    private func makeBreadth(
        _ values: (Int) -> (advances: Double, declines: Double, newHighs: Double, newLows: Double)
    ) -> [BreadthPoint] {
        let calendar = Calendar(identifier: .gregorian)
        let start = date("2023-01-06")
        return (0..<30).map { index in
            let point = values(index)
            return BreadthPoint(
                date: calendar.date(byAdding: .day, value: index * 7, to: start)!,
                advances: point.advances,
                declines: point.declines,
                newHighs: point.newHighs,
                newLows: point.newLows
            )
        }
    }

    private func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: value)!
    }
}

final class MarketDataFetcherTests: XCTestCase {
    private let fetcher = MarketDataFetcher()

    func testStooqParserSkipsMalformedRowsAndSortsResults() {
        let csv = """
        Date,Open,High,Low,Close,Volume
        2024-01-03,3,4,2,3.5,100
        too-short
        not-a-date,3,4,2,3.0,100
        2024-01-02,2,3,1,2.5,90
        """

        let bars = fetcher.parseStooqCSV(csv)

        XCTAssertEqual(bars.count, 2)
        XCTAssertEqual(bars.map(\.close), [2.5, 3.5])
        XCTAssertEqual(bars.first?.date, date("2024-01-02"))
    }

    func testVixParserSkipsMissingAndMalformedValues() {
        let csv = """
        DATE,VIXCLS
        2024-01-01,.
        2024-01-03,18.5
        malformed
        2024-01-02,not-a-number
        """

        let points = fetcher.parseVixCSV(csv)

        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points.first?.value, 18.5)
        XCTAssertEqual(points.first?.date, date("2024-01-03"))
    }

    func testBreadthParserRequiresColumnsAndSkipsShortRows() {
        let csv = """
        new_lows,date,advances,new_highs,declines
        10,2024-01-02,120,25,80
        11,2024-01-01,not-a-number,24,79
        12,2024-01-03,130
        """

        let points = fetcher.parseBreadthCSV(csv)

        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points.first?.date, date("2024-01-02"))
        XCTAssertEqual(points.first?.advances, 120)
        XCTAssertEqual(points.first?.declines, 80)
        XCTAssertEqual(points.first?.newHighs, 25)
        XCTAssertEqual(points.first?.newLows, 10)
        XCTAssertTrue(fetcher.parseBreadthCSV("date,advances\na,1").isEmpty)
    }

    func testYahooChartParserPairsTimestampsWithNonNilCloses() throws {
        let json = """
        {
          "chart": {
            "result": [{
              "timestamp": [1704067200, 1704153600, 1704240000],
              "indicators": {"quote": [{"close": [100.0, null, 102.5]}]}
            }],
            "error": null
          }
        }
        """

        let bars = try fetcher.parseYahooChartJSON(Data(json.utf8))

        XCTAssertEqual(bars.count, 2)
        XCTAssertEqual(bars.map(\.close), [100.0, 102.5])
        XCTAssertEqual(bars.first?.date, Date(timeIntervalSince1970: 1704067200))
    }

    private func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: value)!
    }
}
