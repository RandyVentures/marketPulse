"""Shared data models for the engine and UI."""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Dict, List, Optional


class Vote(str, Enum):
    BULL = "BULL"
    BEAR = "BEAR"
    NEUTRAL = "NEUTRAL"
    NA = "N/A"


@dataclass(frozen=True)
class Signal:
    name: str
    vote: Vote
    value: Optional[float]
    detail: str


@dataclass(frozen=True)
class MarketPulseSnapshot:
    as_of: str
    score: int
    label: Vote
    signals: List[Signal]
    conflicts: List[str]
    extras: Dict[str, str]
