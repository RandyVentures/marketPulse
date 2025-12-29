"""Configuration defaults and data paths."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path



@dataclass(frozen=True)
class MarketPulseConfig:
    refresh_seconds: int = 60
    vix_bull: float = 20.0
    vix_neutral: float = 25.0
    score_bull: int = 60
    score_neutral: int = 40

    @property
    def data_dir(self) -> Path:
        return Path.home() / ".marketpulse" / "data"

    @property
    def cache_dir(self) -> Path:
        return Path.home() / ".marketpulse" / "cache"


DEFAULT_CONFIG = MarketPulseConfig()
