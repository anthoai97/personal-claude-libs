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
├── .claude/             # Claude Code configuration
│   ├── commands/        # Custom slash commands
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

## Slash Commands

Custom Claude Code commands available in this repository:

| Command | Description |
|---------|-------------|
| `/update-doc` | Automatically analyze changes and update project documentation using AI-optimized workflow |

Slash commands are defined in `.claude/commands/` as markdown files.

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
#   "requests",
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

### Telegram Notifications (Optional)

The notification hook supports optional Telegram messages via environment variables:

- `TELEGRAM_BOT_TOKEN` - Bot token from @BotFather
- `TELEGRAM_CHAT_ID` - Your Telegram chat ID

If both are set, completion notifications send to Telegram. If not set, only audio plays.

**Dependencies:** `requests` library for HTTP calls to Telegram Bot API.

**Setup:** Chat with @BotFather to create a bot (takes ~2 minutes). See `hooks/Readme.md` for detailed setup instructions.

## Development Hook Flow

### Creating a New Hook

1. **Create hook script** in `hooks/` directory using PEP 723 format:
   ```python
   #!/usr/bin/env -S uv run --script
   # /// script
   # requires-python = ">=3.10"
   # dependencies = ["your-deps"]
   # ///
   ```

2. **Make executable**: `chmod +x hooks/your_hook.py`

3. **Write unit tests** in `test/` directory using the same PEP 723 pattern with pytest

4. **Test manually** across platforms before distribution

### Testing Workflow

```bash
# Run all tests with verbose output
uv run test/test_notify.py -v

# Run specific test class
uv run test/test_notify.py -v -k "TestPlaySoundFile"

# Run single test
uv run test/test_notify.py -v -k "test_missing_file_returns_false"
```

### Multi-OS Compatibility Guidelines

When developing hooks, ensure compatibility across macOS, Linux, and Windows:

| Concern | Solution |
|---------|----------|
| Shebang | Use `#!/usr/bin/env -S uv run --script` (works on all platforms) |
| Paths | Use `pathlib.Path` for cross-platform path handling |
| Audio | Use `sounddevice`/`soundfile` (not OS-specific commands) |
| File permissions | `setup.sh` handles `chmod +x`; Windows ignores it |
| Path separators | `Path` handles `/` vs `\` automatically |
| Config paths | Use forward slashes in JSON; Windows Git Bash converts them |

### Hook Lifecycle Integration

```
Claude Code Session
       │
       ├─► SessionStart ────► (session initialization hooks)
       │
       ├─► UserPromptSubmit ─► (validate/transform user input)
       │
       ├─► PreToolUse ──────► (block or allow tool execution)
       │
       ├─► [Tool Executes]
       │
       ├─► PostToolUse ─────► (format, lint, validate output)
       │
       ├─► Notification ────► (alert user when input needed)
       │
       └─► Stop ────────────► (cleanup, notifications on completion)
```

### Setup Script Platform Detection

The `setup.sh` script detects OS for platform-specific behavior:
- **macOS/Linux**: Uses shell installer for uv (`curl | sh`)
- **Windows (MINGW/MSYS/Git Bash)**: Uses PowerShell installer for uv
- Path conversion: `/d/path` → `D:/path` for Windows JSON configs
