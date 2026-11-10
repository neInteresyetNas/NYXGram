#!/usr/bin/env bash
# Builds a release IPA (arm64) with the fake signing profiles, for re-signing with Sideloadly / AltStore.
# For your own paid signing use build-system/GGBuildRelease.sh instead (see README.ghostgram.md).
set -euo pipefail
cd "$(dirname "$0")/../.."
CFG="build-system/ghostgram-configuration.json"
[[ -f "$CFG" ]] || { echo "Run NYXGram/scripts/nyx-setup.sh first."; exit 1; }

# Pin Bazel to the active Xcode and apply the submodule patches (same steps as GGBuild.sh).
GG_PATCHES_ONLY=1 build-system/GGBuild.sh

python3 build-system/Make/ImportCertificates.py --path build-system/fake-codesigning/certs
python3 -u build-system/Make/Make.py --overrideXcodeVersion --cacheDir "$HOME/telegram-bazel-cache" \
  build --configurationPath "$CFG" \
  --codesigningInformationPath build-system/fake-codesigning \
  --buildNumber=1 --configuration=release_arm64

mkdir -p build-output/ipa
for f in bazel-out/applebin_ios-ios_arm*-opt-ST-*/bin/Telegram/Telegram.ipa; do
  cp "$f" build-output/ipa/NYXGram.ipa
done
echo "IPA: $(pwd)/build-output/ipa/NYXGram.ipa  -> install with Sideloadly (see NYXGram/docs/INSTALL.md)"
