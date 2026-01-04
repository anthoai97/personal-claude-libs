# Claude Code Development Kit

A collection of utilities and hooks for enhancing Claude Code workflows.

## Structure

- `hooks/` - Custom hooks for Claude Code (notifications, validators, etc.)
- `ai_docs/` - AI documentation and reference materials
- `setup.sh` - Installation script for setting up hooks in your projects

## Quick Start

### One-line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/user/personal-claude-libs/master/setup.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/user/personal-claude-libs.git
cd personal-claude-libs
./setup.sh
```

### What the Setup Script Does

1. **Checks prerequisites** - Verifies Claude Code and required tools are installed
2. **Prompts for options** - Asks which components to install (notifications, etc.)
3. **Installs uv** - Automatically installs uv if needed for Python hooks
4. **Copies files** - Installs hooks and sounds to your target project
5. **Generates config** - Creates `.claude/settings.local.json` with hook configuration

## Requirements

- **Claude Code** - The CLI tool from Anthropic
- **uv** - Python package manager (auto-installed by setup script if missing)
- **jq** - JSON processor for configuration

## Components

### Notification Hooks

Audio notifications when Claude Code needs input or completes tasks.

- **Input notification** - Plays when Claude needs your input
- **Completion notification** - Plays when Claude finishes a task

The notification script uses [uv](https://docs.astral.sh/uv/) with inline script metadata (PEP 723) for automatic dependency management. No virtual environment setup required.

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

### Testing Notifications

After installation, test the notification sounds:

```bash
# Test input notification
/path/to/project/.claude/hooks/notify.py input

# Test completion notification
/path/to/project/.claude/hooks/notify.py complete
```

## Manual Installation

If you prefer manual setup:

1. Copy hooks to your project:
   ```bash
   mkdir -p your-project/.claude/hooks/sounds
   cp hooks/notify.py your-project/.claude/hooks/
   cp hooks/sounds/* your-project/.claude/hooks/sounds/
   chmod +x your-project/.claude/hooks/notify.py
   ```

2. Add to `.claude/settings.local.json`:
   ```json
   {
     "hooks": {
       "Notification": [
         {
           "matcher": "",
           "hooks": [
             {
               "type": "command",
               "command": "/path/to/project/.claude/hooks/notify.py input"
             }
           ]
         }
       ],
       "Stop": [
         {
           "matcher": "",
           "hooks": [
             {
               "type": "command",
               "command": "/path/to/project/.claude/hooks/notify.py complete"
             }
           ]
         }
       ]
     }
   }
   ```

## Platform Support

The notification system works on:
- **macOS** - Full support
- **Linux** - Full support (requires audio output)
- **Windows** - Full support (via MINGW/MSYS/Git Bash)

Audio playback uses `sounddevice` and `soundfile` Python libraries for cross-platform compatibility.

## License

MIT
