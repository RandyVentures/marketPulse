from marketpulse.engine import score_signals
from marketpulse.models import Signal, Vote


def test_score_signals_labels():
    signals = [
        Signal("A", Vote.BULL, 1.0, ""),
        Signal("B", Vote.BULL, 1.0, ""),
        Signal("C", Vote.BEAR, 1.0, ""),
    ]
    score, label = score_signals(signals)
    assert 0 <= score <= 100
    assert label in {Vote.BULL, Vote.NEUTRAL, Vote.BEAR}
