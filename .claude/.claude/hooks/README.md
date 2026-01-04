# Claude Code Hooks

This directory contains a hook that provides pleasant audio feedback when Claude Code completes tasks.

## Architecture

```
Claude Code Lifecycle
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

**Purpose**: Provides pleasant audio feedback when Claude Code completes tasks.

**Trigger**: `Stop` events (task completion)

**Features**:
- Cross-platform audio support (macOS, Linux, Windows)
- Non-blocking audio playback (runs in background)
- Multiple audio playback fallbacks
- Pleasant completion sound
- UV single-file script format (no virtual environment needed)

## Installation

1. **Copy the hooks to your project**:
   ```bash
   cp -r hooks your-project/.claude/
   ```

2. **Configure hooks in your project**:
   ```bash
   cp hooks/setup/settings.json.template your-project/.claude/settings.json
   ```
   Then edit the WORKSPACE path in the settings file.

3. **Test the hook**:
   ```bash
   # Test completion sound
   .claude/hooks/notify.py complete
   ```

## Hook Configuration

Add to your Claude Code `settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "${WORKSPACE}/.claude/hooks/notify.py complete"
          }
        ]
      }
    ]
  }
}
```

## Best Practices

1. **Hook Design**:
   - Keep execution time minimal
   - Log important events for debugging
   - Fail gracefully - never break the main workflow

2. **Configuration**:
   - Use `${WORKSPACE}` variable for portability
   - Keep hooks executable (`chmod +x`)
   - Version control hook configurations

## Troubleshooting

### Hook not executing
- Verify paths in settings.json
- Check Claude Code logs for errors

### No sound playing
- Verify sound files exist in `sounds/` directory
- Test audio playback: `.claude/hooks/notify.py complete`
- Check system audio settings
- Ensure you have an audio player installed (afplay, paplay, aplay, pw-play, play, ffplay, or PowerShell on Windows)

## Extension Points

The hook system is designed for extensibility. As your needs grow, you can:
- Add hooks for other lifecycle events (PreToolUse, PostToolUse, Notification)
- Implement custom security scanning
- Add context injection for AI tools
- Create custom event handlers