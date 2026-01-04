# feat: Add Telegram Notifications to notify.py Hook

## Overview

Extend the `hooks/notify.py` script to send Telegram messages when Claude Code completes tasks. Keep it simple: 2 environment variables, one HTTP POST, done.

## Problem Statement

Developers working with Claude Code want to be notified on their phone when long-running tasks complete. Audio notifications only work when you're at your computer.

## Solution

Add Telegram notification to the `complete` event using environment variables and the Telegram Bot API. No config files, no setup wizards, no validation - if the env vars exist, send the message. If not, skip it.

## Why Telegram > WhatsApp

| Feature | Telegram | WhatsApp |
|---------|----------|----------|
| **Setup time** | 2 minutes | 30 minutes |
| **Requirements** | Just Telegram account | Facebook Business + phone verification + credit card |
| **Bot creation** | Chat with @BotFather | Navigate Meta Business dashboard |
| **API complexity** | 1 endpoint | Multiple IDs, tokens, phone numbers |
| **Environment variables** | 2 | 3 |
| **Free tier** | Unlimited | 1,000 messages/month |
| **Rate limits** | 30 messages/second | 1 per 6 seconds per recipient |

**Telegram wins on simplicity.**

## Implementation

### Code Changes

Add Telegram support to `hooks/notify.py`:

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["sounddevice", "soundfile", "requests"]
# ///
"""Claude Code notification hook with optional Telegram."""

import os
import sys
from datetime import datetime
from pathlib import Path
import sounddevice as sd
import soundfile as sf
import requests


def play_sound_file(sound_file: Path) -> bool:
    """Play a sound file."""
    if not sound_file.exists():
        return False
    try:
        data, samplerate = sf.read(sound_file)
        sd.play(data, samplerate)
        sd.wait()
        return True
    except Exception:
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
```

**Total addition: ~22 lines of code** (even simpler than WhatsApp!)

### Documentation Update

Update `hooks/Readme.md`:

```markdown
## Telegram Notifications (Optional)

Get Telegram notifications when Claude Code completes tasks.

### Setup (2 minutes)

1. **Create a Telegram bot:**
   - Open Telegram and search for `@BotFather`
   - Send `/newbot` and follow the prompts
   - Copy the bot token (looks like `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`)

2. **Get your Chat ID:**
   - Send a message to your bot (any message)
   - Visit: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
   - Find `"chat":{"id":123456789}` in the response
   - Copy that number

3. **Add to your shell profile** (`~/.zshrc` or `~/.bashrc`):

```bash
export TELEGRAM_BOT_TOKEN="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
export TELEGRAM_CHAT_ID="123456789"
```

4. Restart your terminal or run `source ~/.zshrc`

That's it. Next time Claude Code completes a task, you'll get a Telegram message.

### Message Format

Messages look like: `✓ Claude Code done in 'project-name' at 14:35:22`

### Troubleshooting

**No messages being sent?**
- Check env vars are set: `echo $TELEGRAM_BOT_TOKEN`
- Make sure you sent at least one message to your bot first
- Verify chat ID is correct (visit the getUpdates URL)

**Want to disable?**
- Unset the env vars or comment them out in your shell profile

**Test manually:**
```bash
curl -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\": \"$TELEGRAM_CHAT_ID\", \"text\": \"Test message\"}"
```
```

Update `CLAUDE.md` technical details:

```markdown
### Telegram Notifications (Optional)

The notification hook supports optional Telegram messages via environment variables:

- `TELEGRAM_BOT_TOKEN` - Bot token from @BotFather
- `TELEGRAM_CHAT_ID` - Your Telegram chat ID

If both are set, completion notifications send to Telegram. If not set, only audio plays.

**Dependencies:** `requests` library for HTTP calls to Telegram Bot API.

**Setup:** Chat with @BotFather to create a bot (takes ~2 minutes).
```

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Configuration** | Environment variables | No files to manage, no .gitignore concerns, standard practice |
| **Setup** | Manual (README) | Setup is so simple (chat with @BotFather), no wizard needed |
| **Validation** | None | Telegram API will reject invalid tokens/chat IDs |
| **Error handling** | Silent failure | Audio still plays, Telegram failure doesn't break the hook |
| **Scope** | "complete" event only | "input" events are too frequent for mobile notifications |
| **Messaging platform** | Telegram over WhatsApp | 10x simpler setup, no business account required |

## Why This Approach

### Telegram is Simpler Than WhatsApp
- **2-minute setup** vs 30-minute setup
- **No credit card** required
- **No business account** verification
- **No phone number** requirements
- **2 env vars** instead of 3
- **Cleaner API** - just bot token + chat ID

### Environment Variables Win
- ✅ No files to track in Git
- ✅ No permission issues
- ✅ No path resolution across platforms
- ✅ Standard practice for secrets
- ✅ Easy to enable/disable (just unset)

### Silent Failure is Fine
- Audio notification always plays (core feature)
- Telegram is enhancement, not critical
- User will notice if messages stop coming
- No need for elaborate error categorization

### API Does Validation
- Invalid bot token? API returns 401
- Invalid chat ID? API returns 400
- Rate limited? API returns 429
- Why duplicate this logic in our code?

## Acceptance Criteria

- [ ] When env vars are set and `notify.py complete` runs, Telegram message is sent
- [ ] When env vars are NOT set, script works as before (audio only, no errors)
- [ ] Message includes project name and timestamp
- [ ] Audio plays regardless of Telegram success/failure
- [ ] Script completes within 6 seconds (5s timeout + processing)
- [ ] PEP 723 dependencies include `requests`
- [ ] Documentation updated (Readme.md, CLAUDE.md)

## Testing

### Manual Testing

```bash
# Test 1: Without Telegram (backwards compatibility)
unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
uv run .claude/hooks/notify.py complete
# Expected: Audio plays, no Telegram attempt, no errors

# Test 2: With valid Telegram config
export TELEGRAM_BOT_TOKEN="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
export TELEGRAM_CHAT_ID="123456789"
uv run .claude/hooks/notify.py complete
# Expected: Audio plays, Telegram message sent

# Test 3: With invalid token (simulate failure)
export TELEGRAM_BOT_TOKEN="invalid"
uv run .claude/hooks/notify.py complete
# Expected: Audio plays, Telegram fails silently, no crash

# Test 4: Input event (should NOT send Telegram)
uv run .claude/hooks/notify.py input
# Expected: Audio plays, no Telegram sent
```

### Unit Tests (Optional)

Add to `test/test_notify.py`:

```python
class TestTelegram(unittest.TestCase):
    """Test Telegram integration."""

    @patch.dict(os.environ, {
        "TELEGRAM_BOT_TOKEN": "123456:ABC-DEF",
        "TELEGRAM_CHAT_ID": "123456789"
    })
    @patch('requests.post')
    def test_sends_telegram_on_complete(self, mock_post):
        """Should send Telegram when env vars set and event is complete."""
        send_telegram("complete")
        mock_post.assert_called_once()

        # Verify correct URL format
        call_args = mock_post.call_args
        assert "api.telegram.org/bot123456:ABC-DEF/sendMessage" in call_args[0][0]

    def test_skips_telegram_when_not_configured(self):
        """Should skip Telegram when env vars not set."""
        with patch.dict(os.environ, {}, clear=True):
            send_telegram("complete")  # Should not raise

    @patch.dict(os.environ, {
        "TELEGRAM_BOT_TOKEN": "123456:ABC-DEF",
        "TELEGRAM_CHAT_ID": "123456789"
    })
    def test_skips_telegram_on_input_event(self):
        """Should not send Telegram for input events."""
        with patch('requests.post') as mock_post:
            send_telegram("input")
            mock_post.assert_not_called()

    @patch.dict(os.environ, {
        "TELEGRAM_BOT_TOKEN": "123456:ABC-DEF",
        "TELEGRAM_CHAT_ID": "123456789"
    })
    @patch('requests.post')
    def test_telegram_message_includes_project_name(self, mock_post):
        """Should include project name in message."""
        send_telegram("complete")

        call_json = mock_post.call_args[1]['json']
        assert Path.cwd().name in call_json['text']
        assert "✓ Claude Code done" in call_json['text']
```

## Implementation Checklist

### Phase 1: Code (20 minutes)
- [ ] Add `requests` to PEP 723 dependencies (if not already added)
- [ ] Import `os`, `requests`, `datetime`
- [ ] Add `send_telegram()` function (~18 lines)
- [ ] Call `send_telegram(event)` from `main()`
- [ ] Test manually with real Telegram bot

### Phase 2: Documentation (10 minutes)
- [ ] Update `hooks/Readme.md` with Telegram setup section
- [ ] Update `CLAUDE.md` technical details
- [ ] Test setup instructions by following them fresh

### Phase 3: Testing (10 minutes)
- [ ] Test without env vars (backwards compatibility)
- [ ] Test with valid env vars (happy path)
- [ ] Test with invalid token (failure path)
- [ ] Test input event doesn't send Telegram
- [ ] Optional: Add unit tests

### Phase 4: Ship (5 minutes)
- [ ] Commit changes
- [ ] Push to GitHub
- [ ] Close issue

**Total estimated time: ~45 minutes** (even faster than WhatsApp!)

## What We're NOT Doing

To keep this simple, we're explicitly NOT adding:

- ❌ Config files (`.claude/telegram.config.json`)
- ❌ Interactive setup wizard
- ❌ Token/Chat ID validation
- ❌ Error categorization (401 vs 429 vs 500)
- ❌ "enabled" flag (just unset env vars)
- ❌ Message templates or customization
- ❌ Multiple recipients / group chats
- ❌ Test sending during setup
- ❌ Success/failure logging
- ❌ Retry logic
- ❌ Rich message formatting (markdown, buttons)

If users need these later, we can add them. Start simple.

## Telegram Bot API Details

### API Endpoint
```
POST https://api.telegram.org/bot{token}/sendMessage
```

### Request Body
```json
{
  "chat_id": "123456789",
  "text": "Your message here"
}
```

### Response (Success)
```json
{
  "ok": true,
  "result": {
    "message_id": 123,
    "chat": {"id": 123456789, "type": "private"},
    "text": "Your message here"
  }
}
```

### Rate Limits
- 30 messages per second per bot
- 1 message per second to the same chat
- For our use case (completion notifications): well within limits

### Error Codes
- `400` - Bad Request (invalid chat_id)
- `401` - Unauthorized (invalid bot token)
- `429` - Too Many Requests (rate limited)

We don't handle these explicitly - silent failure is fine.

## Why Telegram Bot API?

**Pros:**
- ✅ **2-minute setup** - chat with @BotFather, done
- ✅ **No business verification** required
- ✅ **No credit card** required
- ✅ **No phone number** requirements
- ✅ **Simple API** - just 2 parameters
- ✅ **Generous rate limits** - 30/sec
- ✅ **Completely free** - no paid tiers
- ✅ **Works everywhere** - headless, SSH, any platform

**Cons:**
- ❌ Requires Telegram account (but most devs have one)
- ❌ Less ubiquitous than WhatsApp (2B vs 500M users)

**Alternatives considered:**
- WhatsApp Cloud API: Too complex (30-min setup, business account, credit card)
- PyWhatKit: Unreliable, requires browser
- Email: Less immediate than messaging app
- Slack: Requires workspace setup

## Setup Guide (Detailed)

### Step 1: Create Bot (30 seconds)

1. Open Telegram
2. Search for `@BotFather`
3. Send: `/newbot`
4. Follow prompts:
   ```
   BotFather: Alright, a new bot. How are we going to call it?
   You: ClaudeNotifier

   BotFather: Good. Now let's choose a username for your bot.
   You: claude_notifier_bot

   BotFather: Done! Here's your token:
   123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
   ```

### Step 2: Get Chat ID (30 seconds)

1. Send any message to your bot (e.g., "Hello")
2. Visit in browser:
   ```
   https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
   ```
3. Look for:
   ```json
   {
     "ok": true,
     "result": [{
       "message": {
         "chat": {"id": 123456789}
       }
     }]
   }
   ```
4. Copy the `id` number

### Step 3: Set Environment Variables (30 seconds)

Add to `~/.zshrc` (or `~/.bashrc`):
```bash
export TELEGRAM_BOT_TOKEN="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
export TELEGRAM_CHAT_ID="123456789"
```

Reload: `source ~/.zshrc`

### Step 4: Test (30 seconds)

```bash
curl -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\": \"$TELEGRAM_CHAT_ID\", \"text\": \"Test from Claude Code!\"}"
```

You should receive a Telegram message!

## References

### External Resources
- **Telegram Bot API Docs:** https://core.telegram.org/bots/api
- **BotFather Commands:** https://core.telegram.org/bots/features#botfather
- **Getting Started:** https://core.telegram.org/bots/tutorial

### Internal Files
- **Current implementation:** `hooks/notify.py:1-59`
- **Tests:** `test/test_notify.py`
- **Documentation:** `hooks/Readme.md`, `CLAUDE.md`

---

## Estimated Effort

**Total code addition:** ~22 lines (2 fewer than WhatsApp!)
**Documentation updates:** ~40 lines
**Unit tests (optional):** ~25 lines
**Implementation time:** ~45 minutes (15 minutes faster!)

**Setup time for users:** 2 minutes (vs 30 minutes for WhatsApp)

Simple, focused, ships fast, easier to set up.
