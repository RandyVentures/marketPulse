"""Snapshot summary rendering."""

from __future__ import annotations

from marketpulse.models import MarketPulseSnapshot, Vote


def summary_text(snapshot: MarketPulseSnapshot) -> str:
    lines = [
        f"Market Pulse {snapshot.label.value} ({snapshot.score}/100) as of {snapshot.as_of}",
        f"VIX: {snapshot.extras.get('vix', 'N/A')} | RSP/SPY: {snapshot.extras.get('rsp_spy', 'N/A')}",
        "",
        "Signals:",
    ]
    for signal in snapshot.signals:
        vote = signal.vote.value
        lines.append(f"- {signal.name}: {vote} ({signal.detail})")
    if snapshot.conflicts:
        lines.append("")
        lines.append("Conflicts:")
        for conflict in snapshot.conflicts:
            lines.append(f"- {conflict}")
    return "\n".join(lines)
