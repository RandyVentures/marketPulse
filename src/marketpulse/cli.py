"""CLI entrypoints."""

from __future__ import annotations

import json
from dataclasses import asdict
from enum import Enum

import typer

from marketpulse.config import DEFAULT_CONFIG
from marketpulse.dashboard import DashboardApp
from marketpulse.engine import build_snapshot
from marketpulse.summary import summary_text

app = typer.Typer(add_completion=False)


@app.command()
def run() -> None:
    """Start the terminal dashboard."""
    DashboardApp(DEFAULT_CONFIG).run()


@app.command()
def snapshot() -> None:
    """Print a shareable daily summary."""
    snap = build_snapshot(DEFAULT_CONFIG)
    typer.echo(summary_text(snap))


@app.command()
def _serialize(obj):
    if isinstance(obj, Enum):
        return obj.value
    if isinstance(obj, list):
        return [_serialize(item) for item in obj]
    if isinstance(obj, dict):
        return {key: _serialize(value) for key, value in obj.items()}
    return obj


@app.command()
def export(json_output: bool = typer.Option(True, "--json")) -> None:
    """Export computed signals."""
    snap = build_snapshot(DEFAULT_CONFIG)
    if json_output:
        typer.echo(json.dumps(_serialize(asdict(snap)), indent=2))
