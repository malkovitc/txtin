# txtin

> Hold to talk. Release to paste.

A minimal macOS menu bar app that transcribes your voice and pastes the text into any focused input field.

![macOS](https://img.shields.io/badge/macOS-14.0+-black)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## How it works

1. Hold `Option+Q` — recording starts
2. Speak
3. Release `Option+Q` — audio is sent to Deepgram, transcript is pasted

Works in any app: browsers, editors, chat apps, terminals.

## Requirements

- macOS 14.0+
- [Deepgram API key](https://console.deepgram.com/) (free tier available)
- Microphone permission
- Accessibility permission (for global hotkey + text insertion)

## Installation

Download the latest DMG from [Releases](../../releases), open it, drag `txtin.app` to Applications.

On first launch:
1. Open txtin from the menu bar icon
2. Paste your Deepgram API key and click **SAVE**
3. Grant Microphone and Accessibility permissions when prompted

## Building from source

### Run in development

```bash
swift run
```

### Build `.app` bundle

```bash
./scripts/build-app.sh release
open txtin.app
```

### Build signed + notarized DMG

Set environment variables, then run the script:

```bash
export DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"
export APPLE_ID="your@email.com"
export APPLE_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # app-specific password
export TEAM_ID="YOURTEAMID"

./scripts/create-signed-dmg.sh --notarize
```

The DMG is saved to `dist/`.

## Configuration

All settings are in the menu bar popover:

| Setting | Description |
|---------|-------------|
| Deepgram API key | Required for transcription. Get one at [console.deepgram.com](https://console.deepgram.com/) |
| Language | AUTO (detect from system locale), RU, or EN |

## Transcription

Uses Deepgram's `nova-3` model with `smart_format` and `punctuate` enabled.

Supported languages in AUTO mode: English, Russian, Ukrainian, Spanish, French, German, Italian, Portuguese, Dutch, Polish, Turkish, Japanese, Korean, Chinese, Hindi.

## Privacy

- Audio is sent to Deepgram's API for transcription and is not stored locally after the request
- Your API key is stored in macOS UserDefaults (local to your machine)
- No analytics, no tracking

## License

MIT — see [LICENSE](LICENSE)
