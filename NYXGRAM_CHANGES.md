# NYXGram changes against Ghostgram 2a6b0827

Branding
- App display name: NYXGram (`Telegram/BUILD`). New app icon (`GhostgramAppIcon.xcassets`, file name kept).
- User-visible strings: "Ghostgram" -> "NYXGram" in `Ghostgram/Strings/{en,ru,uk,ar}`; generated Swift
  strings regenerated with `Ghostgram/Strings/generate.py`; `check.py` passes (run in the sandbox).

Switched off (not registered, so no menu rows, no hooks, no network use)
- Nick badges (GCONNECT): polled badges.gconnect.cc every 5 minutes, paid badges via a third-party bot.
- Camera masks module: downloaded a catalog from ghostpixel.win.
- Network spoof and VLESS/Xray tunnel modules.
- Registration date lookups (module off; its server address was unset anyway).
- Fake gifts and local stars: show data that is not real.
- Restriction bypasses: copy/forward of protected content, keeping view-once media, screenshot-notice
  suppression, content-restriction bypass, ad hiding (handlers and menu rows removed; old imported values
  for these settings are no longer migrated). "Reveal spoilers" is kept: it only unblurs text already
  on your device.
- Removed unused string keys that belonged to those menu rows.

Kept as in Ghostgram: Ghost mode, deleted/edited message history, chat protection and passcode options,
appearance, translation (Google/Telegram/system; the Google engine sends the text to Google), chat export.

Not touched: the module sources of the switched-off features are still in the tree and still compile
into the app; they are only unreachable. Removing them needs a Mac build to verify.

CI: the inherited workflows (a macOS-13 build, a bot that posts PRs to a Telegram chat) were removed.
