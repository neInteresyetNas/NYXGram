# NYXGram

Unofficial Telegram client for iOS. Not affiliated with Telegram.

NYXGram is a derivative of **Ghostgram** (https://github.com/ichmagmaus111/ghostgram, GPL-2.0, commit
`2a6b0827`), which in turn is built on the official Telegram for iOS source code. All of that work belongs
to its authors; see `LICENSE` and `NOTICE`. This project is distributed under the same license (GPL-2.0).
If you distribute a build of NYXGram to other people you must make the corresponding source available.

**Status: not compiled by the author of these changes.** See `PROJECT_STATUS.md`.

## What NYXGram changes compared with Ghostgram
See `NYXGRAM_CHANGES.md`. In short: new name, icon and strings; features that contact third-party servers,
fake data or bypass protections chosen by other people are switched off; setup scripts for a Mac.

## Build and install
1. `NYXGram/scripts/nyx-setup.sh`: checks Xcode, fetches submodules, writes the git-ignored configuration
   (asks for your own api_id/api_hash from https://my.telegram.org/apps, never for passwords).
2. `NYXGram/scripts/nyx-ipa.sh`: builds `build-output/ipa/NYXGram.ipa`.
3. Install with Sideloadly: `NYXGram/docs/INSTALL.md`.

Upstream build notes for the Ghostgram base (Xcode project, simulator, own signing) are kept in
`README.ghostgram.md`.

## Layout
Same as Ghostgram: `Ghostgram/` holds all feature modules (`Features/*`, `GGCore`, `GGHooks`,
`GGSettingsUI`, `Strings`, tests); the folder and `GG*` module names are kept on purpose so the build
graph is not disturbed. User-visible names are NYXGram.
