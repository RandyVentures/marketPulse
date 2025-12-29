"""Textual dashboard app."""

from __future__ import annotations

from datetime import datetime

from rich.align import Align
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from textual.app import App, ComposeResult
from textual.widgets import Footer, Header, Static

from marketpulse.config import DEFAULT_CONFIG, MarketPulseConfig
from marketpulse.engine import build_snapshot
from marketpulse.summary import summary_text


class DashboardApp(App):
    CSS = """
    Screen { layout: vertical; }
    #content { height: 1fr; }
    #summary { height: auto; }
    """

    def __init__(self, config: MarketPulseConfig | None = None) -> None:
        super().__init__()
        self.config = config or DEFAULT_CONFIG

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static(id="content")
        yield Static(id="summary")
        yield Footer()

    def on_mount(self) -> None:
        self.refresh_snapshot()
        self.set_interval(self.config.refresh_seconds, self.refresh_snapshot)

    def refresh_snapshot(self) -> None:
        content = self.query_one("#content", Static)
        summary = self.query_one("#summary", Static)
        try:
            snapshot = build_snapshot(self.config)
        except Exception as exc:
            content.update(Panel(f"Error: {exc}", title="marketPulse"))
            return

        table = Table(title="Market Pulse", expand=True, show_lines=True)
        table.add_column("Signal", style="bold")
        table.add_column("Vote")
        table.add_column("Detail")
        for signal in snapshot.signals:
            table.add_row(signal.name, signal.vote.value, signal.detail)

        header = Text(
            f"{snapshot.label.value} {snapshot.score}/100 | VIX {snapshot.extras.get('vix', 'N/A')} | RSP/SPY {snapshot.extras.get('rsp_spy', 'N/A')} | {snapshot.as_of}",
            style="bold",
        )
        panel = Panel(Align.left(table), title=header)
        content.update(panel)
        summary.update(Panel(summary_text(snapshot), title="Daily Summary", expand=False))
