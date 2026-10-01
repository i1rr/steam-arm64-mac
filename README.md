# Steam ARM64 Native Installer for Apple Silicon Macs

Install Steam on your Apple Silicon Mac **without Rosetta 2**.

## Why does this exist?

Steam has supported native ARM64 (Apple Silicon) since June 2025. However, the official installer still delivers an outdated Intel-only (x86_64) stub, which forces macOS to prompt you to install Rosetta 2 before Steam can even open.

This script fetches the universal (ARM64 + x86_64) bootstrapper directly from Valve's own CDN, the same server Steam uses to update itself, and installs it properly.

### The problem in detail

When you download Steam normally, you get a lightweight stub app (~5MB) whose only job is to bootstrap the real Steam client. That stub is currently still compiled for Intel only. macOS detects this and refuses to run it without Rosetta 2.

Valve's CDN already serves a universal version of that same bootstrapper. They just haven't updated the official DMG to point at it yet. This script reads Valve's own update manifest to find the correct package and downloads it directly.

## Requirements

- Apple Silicon Mac (M1 or later)
- macOS 12 Monterey or later
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

### Manual download and installation

If you prefer to run the download and extraction commands yourself, paste this block into Terminal. It downloads the same bootstrapper into a new temporary folder and stops if a command fails.

```bash
(
  set -euo pipefail
  cd "$(mktemp -d)"
  package=$(curl -fsSL https://client-update.steamstatic.com/steam_client_osx | grep -o 'appdmg_osx\.zip[^"[:space:]]*')
  curl -fL "https://client-update.steamstatic.com/$package" -o steam.zip
  unzip -q steam.zip
  tar -xzf SteamMacBootstrapper.tar.gz
  find Steam.app -type f -name '._*' -delete
  rm steam.zip SteamMacBootstrapper.tar.gz SteamMacBootstrapper.version
  printf 'Steam.app is ready in: %s\n' "$PWD"
)
```

Open the printed folder in Finder, fully quit Steam, and move `Steam.app` to `/Applications`. Keep a copy of any existing `Steam.app` until the new one works. You can then delete the temporary folder.

The installer script also verifies the package checksum, ARM64 support, Valve signature, and Gatekeeper acceptance before replacing your app, and restores the previous copy if installation fails. The manual route leaves those checks and replacement to you. To opt into the beta channel manually, select **Steam Beta Update** under **Settings > Interface > Client Beta Participation** after launching Steam.

## What the script does

1. **Checks** you're on Apple Silicon and Steam is not running
2. **Reads** Valve's CDN manifest (`client-update.steamstatic.com/steam_client_osx`) to get the latest bootstrapper URL. This is the same manifest Steam reads when updating itself
3. **Downloads** the universal bootstrapper package directly from Valve's CDN
4. **Verifies** the downloaded package's SHA-256 checksum, ARM64 support, Valve signature, and Gatekeeper notarization before touching your installed copy
5. **Removes** AppleDouble metadata artifacts shipped in Valve's tarball; otherwise they invalidate the app signature and macOS reports Steam as damaged
6. **Replaces** `/Applications/Steam.app` with the universal version, restoring the previous copy if the installation itself fails
7. **Opts into** the Steam beta channel (where the full native ARM64 client lives) by writing to `~/Library/Application Support/Steam/package/beta`

## Is this safe?

The script downloads the bootstrapper directly from Valve and verifies it before installation. It does not patch or re-sign the app.

**How to verify:**

- **The CDN:** `client-update.steamstatic.com` is Valve's official update server, used by the Steam client to update itself.
- **The checksum:** The script compares the downloaded ZIP's SHA-256 digest with the `sha2` value in Valve's manifest. This detects a corrupt or mismatched download. Because both come from the same server, the checksum alone does not independently establish who published the app.
- **The signature:** Before installation, the script verifies the app's code signature, checks Valve's Apple Developer Team ID (`MXGJJ98X76`), and asks Gatekeeper to assess the app. These checks establish app integrity, the expected signer, and acceptance under macOS security policy. You can display the installed app's Team ID manually:

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
- Games that are Intel-only will still require Rosetta to run. Native support depends on the game developers
- You can check any game's ARM64 status at [AppleGamingWiki](https://www.applegamingwiki.com)

### Steam overlay limitation

When running a game in native ARM64 mode, the Steam overlay (Shift+Tab) may not work. This is because Steam's overlay injects a library into the game process, and an x86_64 library cannot inject into an ARM64 process. Valve is actively working on this. Single-player and direct-connect multiplayer are unaffected.

## Reverting

```bash
rm -rf /Applications/Steam.app
rm ~/Library/Application\ Support/Steam/package/beta
```

Then reinstall Steam normally.
