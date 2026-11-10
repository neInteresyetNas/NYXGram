#!/usr/bin/env bash
# One-time setup on the Mac: checks tools and writes the (git-ignored) build configuration.
# It never asks for an Apple ID password or a Telegram login.
set -euo pipefail
cd "$(dirname "$0")/../.."

[[ "$(uname)" == "Darwin" ]] || { echo "Run this on macOS."; exit 1; }
echo "macOS : $(sw_vers -productVersion)"
command -v xcodebuild >/dev/null || { echo "Install Xcode first."; exit 1; }
echo "Xcode : $(xcodebuild -version | head -1)   (versions.json asks for $(python3 -c 'import json;print(json.load(open("versions.json"))["xcode"])'))"
command -v python3 >/dev/null || { echo "python3 missing: xcode-select --install"; exit 1; }
echo "Free  : $(df -g . | awk 'NR==2{print $4}') GB (100+ GB recommended)"

git submodule update --init --recursive -j8

CFG="build-system/ghostgram-configuration.json"
if [[ -f "$CFG" ]]; then echo "$CFG exists, leaving it as is."; exit 0; fi

echo
echo "Get api_id / api_hash at https://my.telegram.org/apps (log in with your phone number)."
read -r -p "api_id: " API_ID
read -r -p "api_hash: " API_HASH
echo
echo "Install mode:"
echo "  1) Sideloadly / AltStore (free Apple ID): builds an IPA with the fake signing profiles; the installer re-signs it."
echo "  2) Own signing: you have profiles and a certificate for your own bundle id (paid developer account)."
read -r -p "Mode [1/2]: " MODE
if [[ "$MODE" == "2" ]]; then
  read -r -p "Apple Team ID: " TEAM_ID
  read -r -p "Your bundle id (e.g. com.yourname.nyxgram): " BUNDLE_ID
else
  TEAM_ID="C67CF9S4VU"; BUNDLE_ID="ph.telegra.Telegraph"   # matches build-system/fake-codesigning
fi

NYX_API_ID="$API_ID" NYX_API_HASH="$API_HASH" NYX_TEAM="$TEAM_ID" NYX_BUNDLE="$BUNDLE_ID" python3 - <<'PY'
import json, os
cfg = json.load(open("build-system/ghostgram-configuration.example.json"))
cfg["api_id"] = os.environ["NYX_API_ID"]
cfg["api_hash"] = os.environ["NYX_API_HASH"]
cfg["team_id"] = os.environ["NYX_TEAM"]
cfg["bundle_id"] = os.environ["NYX_BUNDLE"]
json.dump(cfg, open("build-system/ghostgram-configuration.json", "w"), indent=2)
PY
chmod 600 "$CFG"
echo "Wrote $CFG (git-ignored). Next: NYXGram/scripts/nyx-ipa.sh"
