# Apple + Android handoff — gnfp-wallet 0.1.4 / gnfp-node 1.1.8 / GNFPHash 1.0.2

**From:** Windows (this host)
**For:** Mac cut of macOS / iOS and release-signed Android APK
**Date:** 2026-08-19

Windows **did not** build `.app`, IPA, notarized Apple binaries, or a Play-signed 0.1.4 APK.

## Pins (digits 1–9 only)

| part | pin | note |
|---|---|---|
| Wallet | **0.1.4** | keep spendable across updates |
| Node | **1.1.8** | book law; hash-commit bonus + pot on block found |
| Miner CLI | **GNFPHash 1.0.2** | still valid |

## Why a new wallet

A 0.1.3 update could show a new gnfp1 (missed Windows session path) or paint **0** when the book fetch failed or returned an empty snapshot. Users reported lost GNFP (about 1200 in one case). **0.1.4** must keep the same address and must not replace a known spendable with zero.

## What Mac should cut

1. Pull gnfp-wallet at the 0.1.4 commit (`kGnfpPackageVersion = '0.1.4'`, `pubspec` `0.1.4+14`).
2. Cut **macOS** (Developer ID + notarize) and **iOS** IPA for **0.1.4**.
3. Rebuild/sign **Android APK** as GNFP Wallet. Attach `gnfp-wallet-0.1.4-android.apk` to GitHub `v0.1.4`.
4. Do not reuse the 0.1.3 APK.

## What 0.1.4 must keep

- Same gnfp1 from `%APPDATA%\GNFP\session.json` **and** older Windows/Mac/Linux session files.
- Last-known spendable in the session store; a live `0` or failed fetch does not wipe it.
- Owner `/api/wallet/balance` still returns the honest amount for that gnfp1.

## Non-Apple

Windows zip from this host if Flutter Windows finished. Linux/Arch if a Linux box is available. Apple/Android only on Mac.
