# Apple + Android handoff — gnfp-wallet 0.1.4

**From:** Windows (this host)
**For:** Mac cut of macOS (Developer ID + notarize), iOS IPA, and a **release-signed** Android APK
**Date:** 2026-08-19
**This file is the Mac work.** gnfp-node **1.1.8** is JS — do **not** cut an Apple node.

Windows **did not** build `.app`, IPA, notarized Apple binaries, or a Play-signed 0.1.4 APK.

## Pins (digits 1–9 only)

| part | pin | git |
|---|---|---|
| Wallet | **0.1.4** | `rgsneddon/gnfp-wallet` `master` (`5d2e063`) / feature `0990665` |
| Node | **1.1.8** | JS only — `rgsneddon/gnfp-node` `v1.1.8`. No Apple node package. |
| Miner CLI | **GNFPHash 1.0.2** | still valid. No new Apple miner unless you already owe one. |

## Why Mac must cut

**0.1.3 is unsafe.** An update could mint a new gnfp1 or paint **0** after a failed/empty book fetch (one report ~1200 GNFP). **0.1.4** keeps the same address and must not replace a known spendable with zero. Mac/iOS/Android users still on 0.1.3 need this pin.

## What Mac should cut

1. `git clone https://github.com/rgsneddon/gnfp-wallet.git && git checkout 5d2e063` (or `master` that prints `0.1.4`).
2. Confirm `lib/gnfp_build_stamp.dart` has `kGnfpPackageVersion = '0.1.4'` and `pubspec.yaml` is `0.1.4+14`.
3. Cut **macOS** (Developer ID + notarize) and **iOS** IPA for **0.1.4**.
4. Rebuild/sign **Android APK** as GNFP Wallet. Attach `gnfp-wallet-0.1.4-android.apk` to GitHub **`v0.1.4`** (already exists; Windows zip is on it).
5. Do **not** reuse the 0.1.3 APK. Do **not** attach 0.0.2 zips to this tag.

## What 0.1.4 must keep

- Same gnfp1 from Application Support / older `~/.gnfp` / container session files (Mac) and `%APPDATA%\GNFP\session.json` plus older Windows paths.
- Last-known spendable in the session store; a live `0` or failed fetch does not wipe it.
- Owner `/api/wallet/balance` still returns the honest amount for that gnfp1.

## Already on GitHub (do not rebuild)

- Node: https://github.com/rgsneddon/gnfp-node/releases/tag/v1.1.8
- Wallet Windows: https://github.com/rgsneddon/gnfp-wallet/releases/tag/v0.1.4 (`gnfp-wallet-0.1.4-windows.zip` only)
