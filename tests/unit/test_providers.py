from pathlib import Path

import pandas as pd

from marketpulse.providers.breadth import LocalCsvBreadthProvider
from marketpulse.providers.market import LocalCsvMarketProvider
from marketpulse.providers.vix import LocalCsvVixProvider


def test_local_market_provider_reads_csv(tmp_path: Path):
    data = pd.DataFrame(
        {
            "date": ["2024-01-01", "2024-01-02"],
            "open": [1.0, 2.0],
            "high": [1.5, 2.5],
            "low": [0.9, 1.8],
            "close": [1.2, 2.2],
            "volume": [100, 200],
        }
    )
    path = tmp_path / "SPY.csv"
    data.to_csv(path, index=False)
    provider = LocalCsvMarketProvider(data_dir=tmp_path)
    df = provider.fetch_daily("SPY")
    assert df["close"].iloc[-1] == 2.2


def test_local_breadth_provider_reads_csv(tmp_path: Path):
    data = pd.DataFrame(
        {
            "date": ["2024-01-01", "2024-01-02"],
            "advances": [1200, 1300],
            "declines": [900, 800],
            "new_highs": [200, 220],
            "new_lows": [50, 60],
        }
    )
    path = tmp_path / "breadth.csv"
    data.to_csv(path, index=False)
    provider = LocalCsvBreadthProvider(data_dir=tmp_path)
    df = provider.fetch_daily()
    assert df["advances"].iloc[-1] == 1300


def test_local_vix_provider_reads_csv(tmp_path: Path):
    data = pd.DataFrame(
        {
            "date": ["2024-01-01", "2024-01-02"],
            "vix": [18.0, 19.5],
        }
    )
    path = tmp_path / "VIX.csv"
    data.to_csv(path, index=False)
    provider = LocalCsvVixProvider(data_dir=tmp_path)
    df = provider.fetch_daily()
    assert df["vix"].iloc[-1] == 19.5
