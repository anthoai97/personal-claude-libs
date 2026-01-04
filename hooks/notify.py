#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "sounddevice",
#   "soundfile",
#   "requests",
# ]
# ///
"""
Claude Code notification hook script.
Plays pleasant sounds when Claude needs input or completes tasks.
Optionally sends Telegram messages on completion.
"""

import os
import sys
from datetime import datetime
from pathlib import Path

import sounddevice as sd
import soundfile as sf
import requests


def play_sound_file(sound_file: Path) -> bool:
    """Play a sound file with cross-platform support using sounddevice."""
    if not sound_file.exists():
        print(f"Warning: Sound file not found: {sound_file}", file=sys.stderr)
        return False

    try:
        data, samplerate = sf.read(sound_file)
        sd.play(data, samplerate)
        sd.wait()  # Wait until sound finishes playing
        return True
    except Exception as e:
        print(f"Error playing sound: {e}", file=sys.stderr)
        return False


def send_telegram(event: str) -> None:
    """Send Telegram message if configured (complete event only)."""
    if event != "complete":
        return

    bot_token = os.getenv("TELEGRAM_BOT_TOKEN")
    chat_id = os.getenv("TELEGRAM_CHAT_ID")

    if not (bot_token and chat_id):
        return  # Not configured, skip silently

    message = f"✓ Claude Code done in '{Path.cwd().name}' at {datetime.now():%H:%M:%S}"

    try:
        requests.post(
            f"https://api.telegram.org/bot{bot_token}/sendMessage",
            json={"chat_id": chat_id, "text": message},
            timeout=5
        )
    except Exception:
        pass  # Fail silently - audio still plays


def main() -> int:
    """Main entry point."""
    if len(sys.argv) != 2 or sys.argv[1] not in ("input", "complete"):
        print(f"Usage: {sys.argv[0]} {{input|complete}}", file=sys.stderr)
        print("  input    - Play sound when Claude needs user input", file=sys.stderr)
        print("  complete - Play sound when Claude completes tasks", file=sys.stderr)
        return 1

    event = sys.argv[1]
    script_dir = Path(__file__).resolve().parent
    sounds_dir = script_dir / "sounds"

    sound_files = {
        "input": sounds_dir / "input-needed.ogg",
        "complete": sounds_dir / "complete.ogg",
    }

    play_sound_file(sound_files[event])
    send_telegram(event)
    return 0


if __name__ == "__main__":
    sys.exit(main())
