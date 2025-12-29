"""Market price providers."""

from __future__ import annotations

from io import StringIO
from pathlib import Path
from typing import Optional

import pandas as pd
import requests

from marketpulse.config import DEFAULT_CONFIG
from marketpulse.providers.base import MarketDataProvider, ProviderChain, ProviderChainError
from marketpulse.utils import normalize_ohlcv


class LocalCsvMarketProvider(MarketDataProvider):
    def __init__(self, data_dir: Optional[Path] = None) -> None:
        self.data_dir = data_dir or DEFAULT_CONFIG.data_dir

    def fetch_daily(self, symbol: str) -> pd.DataFrame:
        path = self.data_dir / f"{symbol.upper()}.csv"
        if not path.exists():
            raise FileNotFoundError(f"Missing local CSV: {path}")
        df = pd.read_csv(path)
        return normalize_ohlcv(df)


class StooqMarketProvider(MarketDataProvider):
    def fetch_daily(self, symbol: str) -> pd.DataFrame:
        ticker = f"{symbol.lower()}.us"
        url = f"https://stooq.com/q/d/l/?s={ticker}&i=d"
        response = requests.get(url, timeout=15)
        response.raise_for_status()
        df = pd.read_csv(StringIO(response.text))
        return normalize_ohlcv(df)


class YFinanceMarketProvider(MarketDataProvider):
    def fetch_daily(self, symbol: str) -> pd.DataFrame:
        try:
            import yfinance as yf
        except ImportError as exc:  # pragma: no cover - optional dependency
            raise ImportError("yfinance is required for this provider") from exc
        ticker = yf.Ticker(symbol)
        hist = ticker.history(period="max", interval="1d")
        if hist.empty:
            raise ValueError("No data returned from yfinance")
        hist = hist.reset_index()
        hist = hist.rename(columns={
            "Date": "date",
            "Open": "open",
            "High": "high",
            "Low": "low",
            "Close": "close",
            "Volume": "volume",
        })
        return normalize_ohlcv(hist)


class MarketDataProviderChain(ProviderChain, MarketDataProvider):
    def __init__(self, providers: Optional[list[MarketDataProvider]] = None) -> None:
        super().__init__(label="Market data")
        self.providers = providers or [
            LocalCsvMarketProvider(),
            StooqMarketProvider(),
            YFinanceMarketProvider(),
        ]

    def fetch_daily(self, symbol: str) -> pd.DataFrame:
        for provider in self.providers:
            try:
                data = provider.fetch_daily(symbol)
                if not data.empty:
                    return data
            except Exception as exc:  # pragma: no cover - exercised via chain logic
                self.record_error(exc)
        raise ProviderChainError(self.label, self.errors)
