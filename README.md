# gnfp-wallet

$GNFP privacy wallet. Spendable asset is GNFP. Proof of work only.

- Pool: https://gnfp.restoreprivacy.online
- Stratum: `de.restoreprivacy.online:1474` (TLS; gnfp-mine 1.0.8)
- Coin: GNFP (not PERC, not Beam)
- Current pin: **0.0.7** — https://github.com/rgsneddon/gnfp-wallet/releases/tag/v0.0.7

## Install

**macOS** — unzip `gnfp-wallet-0.0.7-macos.zip` and move **GNFP Wallet** (`gnfp_wallet.app`) into Applications. This pin is Developer ID–signed and notarized so Gatekeeper can open it. If Finder says the app is damaged, re-download. Launching from Downloads still asks you to move it into Applications. iPhone and iPad do not show that dialog: the IPA is installed into the system app space (sideload / Xcode); there is no Applications folder.

**Android** — `gnfp-wallet-0.0.7-android.apk`

**iPhone / iPad** — unsigned `gnfp-wallet-0.0.7-ios.ipa` / `gnfp-wallet-0.0.7-ipad.ipa` (sideload).

**Windows / Linux / Arch** — laptop attaches `gnfp-wallet-0.0.7-windows.zip`, `-linux.zip`, `-archlinux.zip` to the same `v0.0.7` tag.

```
flutter pub get
flutter test
flutter run
```

macOS GitHub zip (Developer ID + notary + `ditto`):

```
python3 pack/macos/sign_and_notarize.py --build
gh release upload v0.0.7 dist/gnfp-wallet-0.0.7-macos.zip --clobber
```

0.0.7: in-wallet **MINE GNFP** keeps hashing after you leave the Mine tab (flashing green dot on the current page). Return to Mine and tap **STOP**. Mine tab picks **threads** (max is this device’s CPU count minus 1), a **payout gnfp1**, and a functioning pool (Germany book / Singapore join / Helsinki front). Explorer shows **your address** and honest **send** / **receive**, and **Export spreadsheet** writes a CSV of that ledger (Excel / Numbers / Sheets).

Releases: https://github.com/rgsneddon/gnfp-wallet/releases
