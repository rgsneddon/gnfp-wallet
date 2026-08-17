# gnfp-wallet

$GNFP privacy wallet. Spendable asset is GNFP. Proof of work only.

- Pool: https://gnfp.restoreprivacy.online
- Stratum: `de.restoreprivacy.online:1474` (TLS; gnfp-mine 1.0.8)
- Coin: GNFP (not PERC, not Beam)
- Current pin: **0.0.6** — https://github.com/rgsneddon/gnfp-wallet/releases/tag/v0.0.6

## Install

**macOS** — unzip `gnfp-wallet-0.0.6-macos.zip` and move **GNFP Wallet** into the Applications folder. If you launch it from Downloads or the zip, the app asks you to do that. iPhone and iPad do not show that dialog: the IPA is installed into the system app space (sideload / Xcode); there is no Applications folder.

**Android** — `gnfp-wallet-0.0.6-android.apk`

**iPhone / iPad** — unsigned `gnfp-wallet-0.0.6-ios.ipa` / `gnfp-wallet-0.0.6-ipad.ipa` (sideload).

**Windows / Linux / Arch** — laptop still attaches `gnfp-wallet-0.0.6-windows.zip`, `-linux.zip`, `-archlinux.zip`.

```
flutter pub get
flutter test
flutter run
```

Releases: https://github.com/rgsneddon/gnfp-wallet/releases
