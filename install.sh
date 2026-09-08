#!/bin/bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "Steam ARM64 Native Installer for Apple Silicon Macs"
echo "===================================================="
echo ""

# Check we're on Apple Silicon
ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
  echo -e "${RED}Error: This script is for Apple Silicon Macs only (detected: $ARCH)${NC}"
  exit 1
fi

# Check Steam is not running
if pgrep -x "steam_osx" >/dev/null || pgrep -x "Steam" >/dev/null; then
  echo -e "${RED}Error: Steam is currently running. Please quit Steam fully and try again.${NC}"
  exit 1
fi

echo -e "${YELLOW}Step 1/5: Fetching latest package info from Valve's CDN...${NC}"
MANIFEST=$(curl -sf "https://client-update.steamstatic.com/steam_client_osx")
if [ -z "$MANIFEST" ]; then
  echo -e "${RED}Error: Could not reach Valve's CDN. Check your internet connection.${NC}"
  exit 1
fi

# Extract the appdmg_osx filename and its SHA-256 digest.
FILE=$(echo "$MANIFEST" | grep -A15 '"appdmg_osx"' | grep '"file"' | grep -v steamchina | awk -F'"' '{print $4}' | head -n 1)
SHA256=$(echo "$MANIFEST" | grep -A15 '"appdmg_osx"' | grep '"sha2"' | tail -n 1 | awk -F'"' '{print $4}')
if [ -z "$FILE" ]; then
  echo -e "${RED}Error: Could not parse manifest. Valve may have changed their CDN format.${NC}"
  exit 1
fi
if ! echo "$SHA256" | grep -Eq '^[0-9a-fA-F]{64}$'; then
  echo -e "${RED}Error: Could not parse the package checksum from Valve's manifest.${NC}"
  exit 1
fi

echo "  Found bootstrapper: $FILE"

echo -e "${YELLOW}Step 2/5: Downloading universal bootstrapper from Valve's CDN...${NC}"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
curl -L "https://client-update.steamstatic.com/$FILE" -o "$TMP_DIR/appdmg_osx.zip"

DOWNLOADED_SHA256=$(shasum -a 256 "$TMP_DIR/appdmg_osx.zip" | awk '{print $1}')
if [ "$DOWNLOADED_SHA256" != "$SHA256" ]; then
  echo -e "${RED}Error: Download checksum does not match Valve's manifest. Aborting.${NC}"
  exit 1
fi

echo -e "${YELLOW}Step 3/5: Extracting...${NC}"
unzip -q "$TMP_DIR/appdmg_osx.zip" -d "$TMP_DIR"
tar xzf "$TMP_DIR/SteamMacBootstrapper.tar.gz" -C "$TMP_DIR"

# Valve's tarball includes AppleDouble (._*) sidecar files.  They are not part
# of the app's code signature, and leaving them in the bundle makes Gatekeeper
# report the app as damaged.
find "$TMP_DIR/Steam.app" -name '._*' -type f -delete

echo -e "${YELLOW}Step 4/5: Verifying ARM64 support...${NC}"
ARCHS=$(file "$TMP_DIR/Steam.app/Contents/MacOS/steam_osx")
if ! echo "$ARCHS" | grep -q "arm64"; then
  echo -e "${RED}Error: Downloaded binary does not contain arm64 slice. Aborting.${NC}"
  exit 1
fi
echo "  Confirmed architectures: $ARCHS"

echo "  Verifying Valve code signature and Gatekeeper assessment..."
if ! codesign --verify --deep --strict "$TMP_DIR/Steam.app"; then
  echo -e "${RED}Error: Downloaded app has an invalid code signature. Aborting.${NC}"
  exit 1
fi
TEAM=$(codesign -dv "$TMP_DIR/Steam.app" 2>&1 | awk -F= '/TeamIdentifier/{print $2}')
if [ "$TEAM" != "MXGJJ98X76" ]; then
  echo -e "${RED}Error: Downloaded app was not signed by Valve (Team ID: $TEAM). Aborting.${NC}"
  exit 1
fi
if ! spctl --assess --type execute "$TMP_DIR/Steam.app"; then
  echo -e "${RED}Error: Gatekeeper did not accept the downloaded app. Aborting.${NC}"
  exit 1
fi
echo -e "${GREEN}  Signature valid. Signed and notarized by Valve.${NC}"

echo -e "${YELLOW}Step 5/5: Installing to /Applications...${NC}"
BACKUP_APP="/Applications/Steam.app.backup.$$"
if [ -e /Applications/Steam.app ]; then
  mv /Applications/Steam.app "$BACKUP_APP"
fi
if ! ditto "$TMP_DIR/Steam.app" /Applications/Steam.app; then
  rm -rf /Applications/Steam.app
  if [ -e "$BACKUP_APP" ]; then
    mv "$BACKUP_APP" /Applications/Steam.app
  fi
  echo -e "${RED}Error: Installation failed; restored the previous Steam app.${NC}"
  exit 1
fi
rm -rf "$BACKUP_APP"
# A bundle copied from a locally extracted archive normally has no quarantine
# attribute; in that case xattr exits non-zero, which is not an error.
xattr -dr com.apple.quarantine /Applications/Steam.app 2>/dev/null || true

# Opt into beta channel
STEAM_PKG_DIR="$HOME/Library/Application Support/Steam/package"
mkdir -p "$STEAM_PKG_DIR"
echo "publicbeta" >"$STEAM_PKG_DIR/beta"
echo "  Beta channel configured."

echo ""
echo -e "${GREEN}Done! Steam is now installed as a universal binary.${NC}"
echo ""
echo "What happens next:"
echo "  1. Launch Steam from /Applications"
echo "  2. Steam will self-update to the full native ARM64 client"
echo "  3. You will NOT be prompted to install Rosetta"
echo ""

echo ""
