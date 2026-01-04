# Claude Code Hooks

This directory contains hooks that provide audio feedback when Claude Code completes tasks or needs input.

## Requirements

- **uv** - Python package manager for running scripts with inline dependencies
  - Install: `curl -LsSf https://astral.sh/uv/install.sh | sh`
  - Or use the setup script which auto-installs uv

## Architecture

```
Claude Code Lifecycle
        │
        ├── Notification ───► Input Sound (when input needed)
        │
        ├── PreToolUse
        │
        ├── Tool Execution
        │
        ├── PostToolUse
        │
        └── Stop ───► Completion Sound
```

## Available Hook

### Notification System (`notify.py`)

**Purpose**: Provides audio feedback for Claude Code events.

**Triggers**:
- `Notification` events - plays input-needed sound
- `Stop` events - plays completion sound

**Features**:
- Cross-platform audio support (macOS, Linux, Windows)
- Uses `sounddevice` and `soundfile` for reliable audio playback
- UV single-file script format with PEP 723 inline metadata
- No virtual environment needed - uv handles dependencies automatically

**Script format**:
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

## Installation

### Using Setup Script (Recommended)

Run from the repository root:
```bash
./setup.sh
```

The setup script will:
- Check for uv and offer to install it if missing
- Copy hooks to your project's `.claude/hooks/` directory
- Generate the settings configuration
- Make scripts executable

### Manual Installation

1. **Install uv** (if not already installed):
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

2. **Copy the hooks to your project**:
   ```bash
   mkdir -p your-project/.claude/hooks/sounds
   cp notify.py your-project/.claude/hooks/
   cp sounds/* your-project/.claude/hooks/sounds/
   chmod +x your-project/.claude/hooks/notify.py
   ```

3. **Configure hooks in your project** (`.claude/settings.local.json`):
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

4. **Test the hook**:
   ```bash
   .claude/hooks/notify.py input
   .claude/hooks/notify.py complete
   ```

## Best Practices

1. **Hook Design**:
   - Keep execution time minimal
   - Fail gracefully - never break the main workflow
   - Use uv inline script format for dependency management

2. **Configuration**:
   - Use absolute paths in settings.json
   - Keep hooks executable (`chmod +x`)
   - Version control hook configurations

## Troubleshooting

### Hook not executing
- Verify paths in settings.json are absolute
- Check Claude Code logs for errors
- Ensure script is executable: `chmod +x notify.py`

### No sound playing
- Verify sound files exist in `sounds/` directory
- Test directly: `.claude/hooks/notify.py complete`
- Check system audio settings and volume
- Verify uv is installed: `uv --version`

### uv not found
- Install uv: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- Restart your terminal after installation
- Check PATH includes `~/.local/bin` or `~/.cargo/bin`

## Extension Points

The hook system is designed for extensibility:
- Add hooks for other lifecycle events (PreToolUse, PostToolUse)
- Implement custom security scanning
- Add context injection for AI tools
- Create custom event handlers
