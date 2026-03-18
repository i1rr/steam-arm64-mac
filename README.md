# Steam ARM64 Native Installer for Apple Silicon Macs

Install Steam on your Apple Silicon Mac **without Rosetta 2**.

## Why does this exist?

Steam has supported native ARM64 (Apple Silicon) since June 2025. However, the official installer still delivers an outdated Intel-only (x86_64) stub, which forces macOS to prompt you to install Rosetta 2 before Steam can even open.

This script fetches the universal (ARM64 + x86_64) bootstrapper directly from Valve's own CDN — the same server Steam uses to update itself — and installs it properly.

### The problem in detail

When you download Steam normally, you get a lightweight stub app (~5MB) whose only job is to bootstrap the real Steam client. That stub is currently still compiled for Intel only. macOS detects this and refuses to run it without Rosetta 2.

Valve's CDN already serves a universal version of that same bootstrapper — they just haven't updated the official DMG to point at it yet. This script reads Valve's own update manifest to find the correct package and downloads it directly.

## Requirements

- Apple Silicon Mac (M1 or later)
- macOS 12 Ventura or later
- Internet connection
- Steam must be fully quit before running

## Usage

```bash
curl -fsSL https://raw.githubusercontent.com/i1rr/steam-arm64-mac/main/install.sh | bash
```

Or if you prefer to inspect the script first (recommended):

```bash
# Download
curl -fsSL https://raw.githubusercontent.com/i1rr/steam-arm64-mac/main/install.sh -o install.sh

# Read it
cat install.sh

# Run it
bash install.sh
```

## What the script does

1. **Checks** you're on Apple Silicon and Steam is not running
2. **Reads** Valve's CDN manifest (`client-update.steamstatic.com/steam_client_osx`) to get the latest bootstrapper URL — this is the same manifest Steam reads when updating itself
3. **Downloads** the universal bootstrapper package directly from Valve's CDN
4. **Verifies** the downloaded binary actually contains an ARM64 slice before touching anything
5. **Replaces** `/Applications/Steam.app` with the universal version
6. **Opts into** the Steam beta channel (where the full native ARM64 client lives) by writing to `~/Library/Application Support/Steam/package/beta`
7. **Verifies** Valve's code signature (Team ID: `MXGJJ98X76`)

## Is this safe?

Yes. The script only uses Valve's own infrastructure — no third-party mirrors, no patched binaries, no modifications.

**How to verify:**

- **The CDN:** `client-update.steamstatic.com` is Valve's official update server — the same one the Steam client has always used internally to update itself
- **The manifest:** `steam_client_osx` is a public plaintext file listing every package Steam can download, along with SHA1 hashes embedded in each filename. If a file were tampered with, its hash wouldn't match
- **The signature:** After installation, the script checks Valve's Apple Developer Team ID (`MXGJJ98X76`). This is a company-wide identifier issued by Apple to Valve — not specific to your machine, not specific to this script. Every legitimate Steam binary ever signed by Valve carries it. You can check it manually:
  ```bash
  codesign -dv /Applications/Steam.app 2>&1 | grep TeamIdentifier
  # Expected: TeamIdentifier=MXGJJ98X76
  ```

## After installation

1. Launch Steam from `/Applications`
2. Steam will detect the beta channel flag and self-update to the full native ARM64 client
3. You will **not** be prompted to install Rosetta

### A note on games

This script only makes the **Steam client** itself native. Individual games are separate:

- Games with native ARM64 builds (e.g. Baldur's Gate 3, Stray) will run without Rosetta
- Games that are Intel-only will still require Rosetta to run — that's on the game developers, not Steam
- You can check any game's ARM64 status at [AppleGamingWiki](https://www.applegamingwiki.com)

### Steam overlay limitation

When running a game in native ARM64 mode, the Steam overlay (Shift+Tab) may not work. This is because Steam's overlay injects a library into the game process, and an x86_64 library cannot inject into an ARM64 process. Valve is actively working on this. Single-player and direct-connect multiplayer are unaffected.

## Reverting

```bash
rm -rf /Applications/Steam.app
rm ~/Library/Application\ Support/Steam/package/beta
```

Then reinstall Steam normally.
