# Apple + Android handoff — gnfp-wallet 0.1.3 / gnfp-node 1.1.7 / GNFPHash 1.0.2

**From:** Windows (this host)  
**For:** Mac cut of macOS / iOS and **double-check / attach Android APKs**  
**Date:** 2026-08-19  

Windows **did not** build `.app`, IPA, notarized Apple binaries, or a Play-signed 0.1.3 APK.

## Pins (digits 1–9 only)

| part | pin | git |
|---|---|---|
| Node | **1.1.7** | `rgsneddon/gnfp-node` master (`7af25e5` or later) |
| Miner CLI | **GNFPHash 1.0.2** | `rgsneddon/GNFPHash` (`a3bead5` or later) |
| Wallet | **0.1.3** | local branch `ship-0.1.3` (`9e9a536`) — miner tab **must** send `client=GNFPHash` / `version=1.0.2` |

Consensus stays in node book law (1 GNFP pot + 0.000000001 GNFP per in-window hash). Pool/wallet do not invent a second rate.

## Why a new wallet

Published **0.1.2** is the last storefront. In-wallet miner must speak **GNFPHash 1.0.2** or the book refuses `old_miner_refused` and used to **lasting-ban** the gnfp1. DE no longer lasting-bans old clients, but the 0.1.2 tab still cannot mine. Ship **0.1.3**.

## What Mac should cut

1. Pull/merge `ship-0.1.3` (or the commit that has `gnfpMineVersion = '1.0.2'` and `gnfpMineClient = 'GNFPHash'`).
2. Cut **macOS** (Developer ID + notarize) and **iOS** IPA for **0.1.3**.
3. **Android APK:** rebuild/sign as **GNFP Wallet**. Attach `gnfp-wallet-0.1.3-android.apk` to GitHub `v0.1.3`. Double-check the existing `v0.1.2` APK is still named/signed as GNFP Wallet and is **not** reused as 0.1.3 (its miner tab is the old storefront).
4. Do not invent a second bonus rate in the wallet.

## Non-Apple (already produced on Windows)

See implementer `release-artifacts.txt`:

- `gnfp-node-1.1.7-win.zip` / `gnfp-node-1.1.7-unix.zip`
- `GNFPHash-1.0.2-win.zip` / `GNFPHash-1.0.2-unix.zip`
- Wallet Windows zip for 0.1.3 if `flutter build windows` finished on this host

Linux/Arch wallet zips: this host is Windows; Mac or a Linux box cuts those if Flutter Linux is available.
