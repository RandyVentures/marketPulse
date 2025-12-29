"""VIX providers."""

from __future__ import annotations

from io import StringIO
from pathlib import Path
from typing import Optional

import pandas as pd
import requests

from marketpulse.config import DEFAULT_CONFIG
from marketpulse.providers.base import ProviderChain, ProviderChainError, VixDataProvider
from marketpulse.utils import normalize_vix


class LocalCsvVixProvider(VixDataProvider):
    def __init__(self, data_dir: Optional[Path] = None) -> None:
        self.data_dir = data_dir or DEFAULT_CONFIG.data_dir

    def fetch_daily(self) -> pd.DataFrame:
        path = self.data_dir / "VIX.csv"
        if not path.exists():
            raise FileNotFoundError(f"Missing local CSV: {path}")
        df = pd.read_csv(path)
        return normalize_vix(df)


class FredVixProvider(VixDataProvider):
    def fetch_daily(self) -> pd.DataFrame:
        url = "https://fred.stlouisfed.org/graph/fredgraph.csv?id=VIXCLS"
        response = requests.get(url, timeout=15)
        response.raise_for_status()
        df = pd.read_csv(StringIO(response.text))
        df.columns = [str(col).strip().lstrip("\ufeff") for col in df.columns]
        df = df.rename(columns={"DATE": "date", "observation_date": "date", "VIXCLS": "vix"})
        df["vix"] = pd.to_numeric(df["vix"], errors="coerce")
        df = df.dropna(subset=["vix"])
        return normalize_vix(df)


class VixProviderChain(ProviderChain, VixDataProvider):
    def __init__(self, providers: Optional[list[VixDataProvider]] = None) -> None:
        super().__init__(label="VIX data")
        self.providers = providers or [LocalCsvVixProvider(), FredVixProvider()]

    def fetch_daily(self) -> pd.DataFrame:
        for provider in self.providers:
            try:
                data = provider.fetch_daily()
                if not data.empty:
                    return data
            except Exception as exc:  # pragma: no cover
                self.record_error(exc)
        raise ProviderChainError(self.label, self.errors)
