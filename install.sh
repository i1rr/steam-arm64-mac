#!/bin/bash

set -e

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
if pgrep -x "steam_osx" > /dev/null || pgrep -x "Steam" > /dev/null; then
  echo -e "${RED}Error: Steam is currently running. Please quit Steam fully and try again.${NC}"
  exit 1
fi

echo -e "${YELLOW}Step 1/5: Fetching latest package info from Valve's CDN...${NC}"
MANIFEST=$(curl -sf "https://client-update.steamstatic.com/steam_client_osx")
if [ -z "$MANIFEST" ]; then
  echo -e "${RED}Error: Could not reach Valve's CDN. Check your internet connection.${NC}"
  exit 1
fi

# Extract the appdmg_osx filename (contains the hash)
FILE=$(echo "$MANIFEST" | grep -A5 '"appdmg_osx"' | grep '"file"' | grep -v steamchina | awk -F'"' '{print $4}')
if [ -z "$FILE" ]; then
  echo -e "${RED}Error: Could not parse manifest. Valve may have changed their CDN format.${NC}"
  exit 1
fi

echo "  Found bootstrapper: $FILE"

echo -e "${YELLOW}Step 2/5: Downloading universal bootstrapper from Valve's CDN...${NC}"
TMP_DIR=$(mktemp -d)
curl -L "https://client-update.steamstatic.com/$FILE" -o "$TMP_DIR/appdmg_osx.zip"

echo -e "${YELLOW}Step 3/5: Extracting...${NC}"
unzip -q "$TMP_DIR/appdmg_osx.zip" -d "$TMP_DIR"
tar xzf "$TMP_DIR/SteamMacBootstrapper.tar.gz" -C "$TMP_DIR"

echo -e "${YELLOW}Step 4/5: Verifying ARM64 support...${NC}"
ARCHS=$(lipo -info "$TMP_DIR/Steam.app/Contents/MacOS/steam_osx" 2>&1)
if ! echo "$ARCHS" | grep -q "arm64"; then
  echo -e "${RED}Error: Downloaded binary does not contain arm64 slice. Aborting.${NC}"
  rm -rf "$TMP_DIR"
  exit 1
fi
echo "  Confirmed architectures: $ARCHS"

echo -e "${YELLOW}Step 5/5: Installing to /Applications...${NC}"
rm -rf /Applications/Steam.app
cp -R "$TMP_DIR/Steam.app" /Applications/
xattr -dr com.apple.quarantine /Applications/Steam.app

# Opt into beta channel
STEAM_PKG_DIR="$HOME/Library/Application Support/Steam/package"
mkdir -p "$STEAM_PKG_DIR"
echo "publicbeta" > "$STEAM_PKG_DIR/beta"
echo "  Beta channel configured."

# Cleanup
rm -rf "$TMP_DIR"

echo ""
echo -e "${GREEN}Done! Steam is now installed as a universal binary.${NC}"
echo ""
echo "What happens next:"
echo "  1. Launch Steam from /Applications"
echo "  2. Steam will self-update to the full native ARM64 client"
echo "  3. You will NOT be prompted to install Rosetta"
echo ""

# Verify Valve signature
echo "Verifying Valve code signature..."
TEAM=$(codesign -dv /Applications/Steam.app 2>&1 | grep "TeamIdentifier" | awk -F= '{print $2}')
if [ "$TEAM" = "MXGJJ98X76" ]; then
  echo -e "${GREEN}  Signature valid. Signed by Valve (Team ID: $TEAM)${NC}"
else
  echo -e "${YELLOW}  Warning: Could not verify Valve signature (Team ID: $TEAM)${NC}"
fi

echo ""
