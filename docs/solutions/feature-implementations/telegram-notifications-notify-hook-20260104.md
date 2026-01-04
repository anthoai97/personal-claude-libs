---
date: 2026-01-04
problem_type: feature_implementation
component: notification_hook
severity: minor
tags: [telegram, notifications, remote-alerts, environment-variables, opt-in]
---

# Telegram Notifications for notify.py Hook

## Problem

**Need:** Remote notification capability when Claude Code completes tasks
**Limitation:** Existing audio notifications only work when at computer
**Use Case:** Developers step away during long-running tasks and want mobile alerts

## Investigation

### Approach 1: WhatsApp Cloud API (Rejected)
**Why evaluated:** Popular messaging platform, 2B+ users
**Why rejected:**
- Complex 30-minute setup process
- Requires Facebook Business account
- Requires credit card (even for free tier)
- Requires 3 environment variables
- Needs phone number verification

### Approach 2: Telegram Bot API (Selected) ✅
**Why selected:**
- Simple 2-minute setup with @BotFather
- No business account required
- No credit card required
- Only 2 environment variables
- Free and unlimited
- Works in headless/SSH environments

## Root Cause

Not a bug - this was a feature enhancement. The notification hook was designed for local audio only and lacked any remote notification capability.

## Solution

Added optional Telegram integration using environment variables:

### Code Changes

**File:** `hooks/notify.py`

1. **Added dependency** (PEP 723 metadata):
```python
# dependencies = [
#   "sounddevice",
#   "soundfile",
#   "requests",  # NEW
# ]
```

2. **Added imports**:
```python
import os
import requests
from datetime import datetime
```

3. **Added send_telegram() function**:
```python
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
```

4. **Integrated with main()**:
```python
def main() -> int:
    event = sys.argv[1]
    # ... existing audio code ...
    play_sound_file(sound_files[event])
    send_telegram(event)  # NEW
    return 0
```

### Configuration

**Environment Variables:**
```bash
# Add to ~/.zshrc or ~/.bashrc
export TELEGRAM_BOT_TOKEN="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
export TELEGRAM_CHAT_ID="123456789"
```

**Setup Process (2 minutes):**
1. Open Telegram, search for `@BotFather`
2. Send `/newbot` and follow prompts
3. Get bot token from BotFather
4. Send message to your bot
5. Visit `https://api.telegram.org/bot<TOKEN>/getUpdates` to get chat ID
6. Add both values to shell profile

### Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Configuration** | Environment variables | No files, no .gitignore, standard practice for secrets |
| **Error handling** | Silent failure | Audio always plays, Telegram failure doesn't break hook |
| **Scope** | "complete" event only | "input" events too frequent for mobile |
| **Validation** | None | Telegram API validates, no need to duplicate |

## Testing

**Backwards compatibility test:**
```bash
unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
uv run hooks/notify.py complete
# Result: Audio plays, no errors
```

**Success test:**
```bash
export TELEGRAM_BOT_TOKEN="your-token"
export TELEGRAM_CHAT_ID="your-chat-id"
uv run hooks/notify.py complete
# Result: Audio plays + Telegram message sent
```

## Prevention / Best Practices

### For Similar Features

1. **Opt-in design** - Use environment variables for optional features
2. **Silent failure** - Don't break core functionality if enhancement fails
3. **Simple setup** - Prioritize solutions with minimal configuration
4. **Backwards compatible** - Existing users unaffected

### API Selection Criteria

When choosing notification APIs:
- ✅ Setup time (2 min > 30 min)
- ✅ Requirements (no business accounts)
- ✅ Dependencies (fewer env vars)
- ✅ Cross-platform (works everywhere)
- ✅ Cost (free unlimited > limited free tier)

## Related Issues

None - first documented solution in this repository.

## Files Modified

- `hooks/notify.py` - Added Telegram integration (22 lines)
- `hooks/Readme.md` - Setup instructions
- `CLAUDE.md` - Technical documentation

## Pull Request

**PR:** https://github.com/anthoai97/personal-claude-libs/pull/3
**Branch:** `feat/telegram-notifications`
**Status:** Ready for review

## Key Takeaways

1. **Environment variables > config files** for simple opt-in features
2. **Telegram Bot API** is simpler than WhatsApp for developer notifications
3. **Silent failure** preserves core functionality when enhancements break
4. **2-minute setup** beats 30-minute setup every time
