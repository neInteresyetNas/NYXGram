#!/usr/bin/env bash
# Run on the Mac, in the folder where you unzipped this overlay:  bash get-nyxgram.sh
# 1) downloads Ghostgram at the exact commit this patch was made against (about 600 MB),
# 2) applies the NYXGram patch,
# 3) you then continue with: cd NYXGram-src && NYXGram/scripts/nyx-setup.sh && NYXGram/scripts/nyx-ipa.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
git clone https://github.com/ichmagmaus111/ghostgram.git "$HERE/NYXGram-src"
cd "$HERE/NYXGram-src"
git checkout 2a6b08272b7da893f88986846022bafd0727df89
git apply --whitespace=nowarn "$HERE/nyxgram2.patch"
git -c user.email=nyx@local -c user.name=NYXGram add -A
git -c user.email=nyx@local -c user.name=NYXGram commit -qm "NYXGram patch applied"
echo "Done. Next: cd NYXGram-src && NYXGram/scripts/nyx-setup.sh && NYXGram/scripts/nyx-ipa.sh"
