# gnfp-wallet

$GNFP privacy wallet. Spendable asset is GNFP. Proof of work only.

- Pool: https://gnfp.restoreprivacy.online
- Stratum: `de.restoreprivacy.online:1474` (TLS; gnfp-mine 1.0.9)
- Coin: GNFP (not PERC, not Beam)
- Current pin: **0.0.8** — https://github.com/rgsneddon/gnfp-wallet/releases/tag/v0.0.8

## Install

**macOS** — open `gnfp-wallet-0.0.8-macos.dmg` and **drag GNFP Wallet onto the Applications folder** in that window, then eject the disk image. Launch from Applications (Spotlight / Dock), not from the disk image. This pin is Developer ID–signed and notarized so Gatekeeper can open it. If Finder says the app is damaged, re-download.

Do not mine from Downloads, a zip, or the open disk image. Those copies live on a temporary volume; when macOS unmounts it the wallet crashes (SIGBUS). 0.0.8 copies itself into Applications if you still open a temp copy, and it will not start **MINE GNFP** until the app is on a real disk. A zip (`gnfp-wallet-0.0.8-macos.zip`) is still attached for the in-app update feed.

iPhone and iPad do not show the Applications dialog: the IPA is installed into the system app space (sideload / Xcode); there is no Applications folder.

**Android** — `gnfp-wallet-0.0.8-android.apk`

**iPhone / iPad** — unsigned `gnfp-wallet-0.0.8-ios.ipa` / `gnfp-wallet-0.0.8-ipad.ipa` (sideload).

**Windows / Linux / Arch** — laptop attaches `gnfp-wallet-0.0.8-windows.zip`, `-linux.zip`, `-archlinux.zip` to the same `v0.0.8` tag.

```
flutter pub get
flutter test
flutter run
```

macOS GitHub disk image (Developer ID + notary + drag-to-Applications):

```
python3 pack/macos/sign_and_notarize.py --build
gh release upload v0.0.8 dist/gnfp-wallet-0.0.8-macos.dmg dist/gnfp-wallet-0.0.8-macos.zip --clobber
```

0.0.8: in-wallet miner is **gnfp-mine 1.0.9** (public book/fronts stay TLS even if an old `tls:false` leftover is present). macOS drag-to-Applications disk image, and the wallet no longer stays mining on a Gatekeeper temp copy (the 0.0.7 SIGBUS while mining). In-wallet **MINE GNFP** still keeps hashing after you leave the Mine tab (flashing green dot on the current page). Return to Mine and tap **STOP**. Mine tab picks **threads** (max is this device’s CPU count minus 1), a **payout gnfp1**, and a functioning pool (Germany book / Singapore join / Helsinki front). Explorer shows **your address** and honest **send** / **receive**, and **Export spreadsheet** writes a CSV of that ledger (Excel / Numbers / Sheets).

Releases: https://github.com/rgsneddon/gnfp-wallet/releases
