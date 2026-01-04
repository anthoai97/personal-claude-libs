# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **Claude Code Development Kit** - a collection of utilities and hooks for enhancing Claude Code workflows. The primary feature is an audio notification system that plays sounds when Claude Code needs user input or completes tasks.

## Repository Structure

```
├── hooks/               # Source hooks for distribution
│   ├── notify.py        # Main notification hook script
│   ├── sounds/          # Audio files (.ogg format)
│   └── Readme.md
├── .claude/             # Local installation of hooks (for this repo)
│   └── hooks/           # Installed hooks and sounds
├── ai_docs/             # Reference documentation for AI assistants
├── test/                # Unit tests
├── setup.sh             # Interactive installation script
└── install.sh           # Alternative installation script
```

## Commands

### Run Tests
```bash
uv run test/test_notify.py
```

### Test Notification Sounds
```bash
# Test input notification
uv run hooks/notify.py input

# Test completion notification
uv run hooks/notify.py complete
```

### Install to Another Project
```bash
./setup.sh
```

## Technical Details

### Hook Script Pattern (PEP 723)

Hooks use uv's single-file script format with inline metadata for automatic dependency management:

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "sounddevice",
#   "soundfile",
# ]
# ///
```

This allows scripts to run without virtual environment setup - uv handles dependencies automatically.

### Claude Code Hook Events

The notification system integrates with these Claude Code lifecycle events:
- **Notification** - Triggers when Claude needs user input (plays `input-needed.ogg`)
- **Stop** - Triggers when Claude finishes responding (plays `complete.ogg`)

Configuration is stored in `.claude/settings.local.json`.

### Cross-Platform Audio

Audio playback uses `sounddevice` and `soundfile` libraries for cross-platform support (macOS, Linux, Windows).
