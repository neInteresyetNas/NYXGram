# Installing on your iPhone (free Apple ID)
1. On the Mac: `NYXGram/scripts/nyx-setup.sh` (mode 1), then `NYXGram/scripts/nyx-ipa.sh`.
2. iPhone: Settings > Privacy & Security > Developer Mode > on, restart.
3. Install Sideloadly (sideloadly.io) on the Mac, connect the iPhone, drag `build-output/ipa/NYXGram.ipa`
   in, enter your own Apple ID **in Sideloadly only**, press Start. Trust the profile in Settings > General >
   VPN & Device Management.
Free Apple IDs: re-sign every 7 days (repeat step 3). Update: build a new IPA and install it over the old
app with the same Apple ID; data is kept. Push notifications and some Telegram extensions may not work
with a re-signed app. Telegram's terms apply to your account; use at your own risk.
