#!/bin/bash
# Gifts Studio must never buy, send, transfer, convert, withdraw, upgrade, resell or delete gifts.
# Fails when the feature sources call any of the TelegramCore functions that do that.
cd "$(dirname "$0")/.." || exit 2
pattern='buyStarGift|sendStarsGift|transferStarGift|convertStarGift|withdrawStarGift|upgradeStarGift|updateStarGiftResellPrice|deleteStarGift|removeStarGift|dropOriginalDetails|insertStarGifts|requestStarsPayment|sendStarsPaymentForm|craft\('
if grep -nE "$pattern" Core/*.swift Sources/*.swift; then
    echo "FORBIDDEN gift operation found in Gifts Studio sources" >&2
    exit 1
fi
echo "OK: no purchase/transfer/convert/withdraw/upgrade/delete calls in Gifts Studio"
