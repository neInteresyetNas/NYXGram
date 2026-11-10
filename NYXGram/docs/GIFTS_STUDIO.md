# Gifts Studio

Status: **written, statically checked only (brace balance, forbidden-call script). Not compiled, not run, tests not executed** — there was no Swift toolchain in the authoring environment. Build it on a Mac or in CI first.

## What it does
- **Catalog** — Telegram's real gift catalog (`engine.payments.cachedStarGifts` / `keepStarGiftsUpdated`): search, filter by type/favorites, sort (newest, price, name, scarcest). Read-only.
- **Collection** — your own gifts (`ProfileGiftsContext`): same search/filter/sort plus pinned/shown/hidden filters, details, compare two gifts (only fields Telegram provides).
- **Layout** — local profile layouts (styles Classic / Minimal / Premium / Collector / Midnight / NYX Purple, columns, card size, titles, rarity, max items, primary gift, drag to reorder). Always labelled *local preview — not published to Telegram*.
- **Data** — export (share sheet) / import (clipboard) of local settings, reset, local change history.
- Local favorites and private notes (device only).

## Changes to the real Telegram profile (each asks for confirmation)
Show/hide a gift, pin/unpin a gift, apply the pinned order of a layout. Nothing else.

## What it never does
Buy, send, transfer, convert to Stars, withdraw, upgrade, resell or delete gifts. `Ghostgram/Features/GiftsStudio/Scripts/check-gifts-forbidden.sh` greps the sources for those calls.

## Storage
`Application Support/NYXGram/gifts-studio.json`, versioned (`schemaVersion`), written atomically, previous good file kept as `.bak`; a damaged file is restored from the backup or set aside as `.corrupt-<time>` (never silently deleted); a file from a newer version is left untouched and the app runs read-only. Import validates size, version and limits.

## Known limits
- Gift thumbnails are not rendered (a gift icon is shown); real animations/media loading is not implemented.
- Collection items without a Telegram reference are not listed as manageable.
- Pin limit comes from `stargifts_pinned_to_top_limit` (default 6).
- UI strings are inline EN/RU (not in the Strings JSON pipeline).
