# Status (NYXGram on the Ghostgram base)
Verified in the sandbox: patch applies to the pinned base; Ghostgram/Strings/check.py passes; shell scripts
pass `bash -n`. Nothing else: no Swift compiler, no Xcode, no iPhone. No IPA exists.
Done: rebrand, switch-offs listed in NYXGRAM_CHANGES.md, setup/build scripts, docs.
Not done: Gifts Studio, dashboard, vault, new security log, filters UI.
Risks: menu skeleton may still show empty sections for switched-off modules; the fake-signing IPA route
(nyx-ipa.sh) is the upstream CI recipe adapted and unrun; first build will likely need fixes.
