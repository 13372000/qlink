<p align="center">
  <img src="assets/qlink.png" width="120" alt="Q-Link logo">
</p>

# Q-Link

Q-Link is a Windows tray bridge that receives Telegram messages and submits them to Codex Desktop through local UI automation.

```text
Telegram -> optional local speech-to-text -> Codex Desktop
```

It is designed for local desktop use. Codex Desktop must be open and accessible on the Windows session where Q-Link is running.

## Features

- Telegram text prompt forwarding
- Telegram voice prompt transcription with local Whisper
- Codex Desktop foreground/focus handling
- Clipboard paste and configurable submit shortcut
- Optional Windows tray launcher
- Optional QDex audio relay back to Telegram

## Quick Start

```powershell
cd C:\path\to\Q-Link
Copy-Item .env.example .env
notepad .env
.\qlink-tray.bat start
```

At minimum, configure:

```env
TELEGRAM_BOT_TOKEN=
TELEGRAM_ALLOWED_CHAT_IDS=
```

Only run one long-polling Telegram bridge per bot token at a time.

## Tray App

`qlink-tray.bat start` launches Q-Link as a small Windows tray app. It starts hidden by default and appears in the Windows hidden icons area.

The tray menu provides:

- Start Q-Link
- Restart Q-Link
- Stop Q-Link
- Open Logs
- Open README
- Exit

The service runner is also available directly:

```powershell
.\qlink.bat start
.\qlink.bat status
.\qlink.bat stop
.\qlink.bat restart
```

## Telegram Commands

- Free text: submit the message to Codex Desktop.
- Voice message: transcribe locally, then submit the text.
- `/qlink <prompt>`: explicit prompt command.
- `/status`: show bridge status.
- `/help`: show help.

## Desktop Automation

Q-Link uses the Windows clipboard and `SendKeys`:

1. Find a Codex Desktop window.
2. Bring it to the foreground.
3. Optionally click near the prompt input.
4. Paste the prompt.
5. Press the configured submit shortcut.

Useful settings:

```env
QLINK_TARGET_PROCESS_NAMES=Codex
QLINK_WINDOW_TITLE_PATTERN=Codex
QLINK_CLICK_INPUT=1
QLINK_CLICK_X_RATIO=0.5
QLINK_CLICK_Y_MODE=bottom-offset
QLINK_CLICK_BOTTOM_OFFSET_PX=105
QLINK_CLICK_Y_RATIO=0.925
QLINK_SUBMIT_KEYS={ENTER}
QLINK_AUTO_SUBMIT=1
```

`bottom-offset` clicks a fixed number of pixels above the bottom of the window, which is usually more stable across window sizes. `QLINK_CLICK_Y_RATIO` is available when `QLINK_CLICK_Y_MODE=ratio`.

Set `QLINK_AUTO_SUBMIT=0` while calibrating the click position so Q-Link pastes without pressing Enter.

## QDex Audio Relay

If QDex is running and local broadcasts are enabled, Q-Link can relay generated speech audio back to Telegram.

```text
Codex Desktop response -> QDex speech -> QDex broadcast -> Q-Link Telegram audio
```

Q-Link watches the local QDex broadcast file:

```text
%USERPROFILE%\.qdex\broadcast.jsonl
```

When a prompt came from Telegram, Q-Link waits for the next QDex audio broadcast and sends that audio to the same Telegram chat.

Useful settings:

```env
QLINK_QDEX_ENABLED=1
QLINK_QDEX_SEND_AUDIO_TO_TELEGRAM=1
QLINK_QDEX_BROADCAST_POLL_MS=500
QLINK_QDEX_RELAY_TIMEOUT_MS=900000
```

## Voice Input

Voice input uses local command-line tools:

```text
Telegram audio -> ffmpeg -> whisper-cli -> text -> Codex Desktop
```

Configure the paths and transcription settings in `.env`:

```env
WHISPER_PATH=
WHISPER_MODEL=
WHISPER_LANGUAGE=auto
FFMPEG_PATH=
```

## Limits

- Codex Desktop must be open and unlocked.
- UI automation can be affected by focus changes, window layout changes, or desktop lock state.
- The text clipboard is temporarily replaced with the prompt. Text clipboard content is restored by default.
- Voice transcription requires local ffmpeg and whisper-cli binaries.

## Publishing Notes

Do not publish local runtime files:

- `.env`
- `data/`
- `logs/`
- `node_modules/`

These are ignored by `.gitignore`.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for external tool/runtime notes.
