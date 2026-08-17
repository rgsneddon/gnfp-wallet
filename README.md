# gnfp-wallet

$GNFP privacy wallet. Spendable asset is GNFP. Proof of work only.

- Pool: https://gnfp.restoreprivacy.online
- Stratum: `de.restoreprivacy.online:1474` (TLS; gnfp-mine 1.0.9)
- Coin: GNFP (not PERC, not Beam)
- Current pin: **0.0.9** — https://github.com/rgsneddon/gnfp-wallet/releases/tag/v0.0.9

## Install

**macOS** — open `gnfp-wallet-0.0.9-macos.dmg` and **drag GNFP Wallet onto the Applications folder** in that window, then eject the disk image. Launch from Applications (Spotlight / Dock), not from the disk image. This pin is Developer ID–signed and notarized so Gatekeeper can open it. If Finder says the app is damaged, re-download.

Do not mine from Downloads, a zip, or the open disk image. Those copies live on a temporary volume; when macOS unmounts it the wallet crashes (SIGBUS). The wallet copies itself into Applications if you still open a temp copy, and it will not start **MINE GNFP** until the app is on a real disk. A zip (`gnfp-wallet-0.0.9-macos.zip`) is still attached for the in-app update feed.

iPhone and iPad do not show the Applications dialog: the IPA is installed into the system app space (sideload / Xcode); there is no Applications folder.

**Android** — `gnfp-wallet-0.0.9-android.apk` (release-signed v2+v3 as **GNFP Wallet**, not the Android Debug cert). The 0.0.8 GitHub APK was debug-signed, so Play Protect / many OEM installers refused it. If 0.0.8 (or any debug `flutter run` copy) is already on the phone, **uninstall it first** — the 0.0.9 signature is different.

**iPhone / iPad** — unsigned `gnfp-wallet-0.0.9-ios.ipa` / `gnfp-wallet-0.0.9-ipad.ipa` (sideload).

**Windows / Linux / Arch** — laptop attaches `gnfp-wallet-0.0.9-windows.zip`, `-linux.zip`, `-archlinux.zip` to the same `v0.0.9` tag. See `WINDOWS_HANDOFF_0.0.9.md`.

```
flutter pub get
flutter test
flutter run
```

macOS GitHub disk image (Developer ID + notary + drag-to-Applications):

```
python3 pack/macos/sign_and_notarize.py --build
gh release upload v0.0.9 dist/gnfp-wallet-0.0.9-macos.dmg dist/gnfp-wallet-0.0.9-macos.zip --clobber
```

0.0.9: selected Mine threads are real CPU workers — N threads hash more than 1 in the same interval (0.0.8 reported the same H/s for any thread count). Stays on the wire (stats every 1s + reconnect in 2s). 0.0.8 dropped to idle after the stratum socket closed (~1 minute, 1 thread) with no lastError. Mining stops only on **STOP** or closing the wallet. Mine tab accepts a **typed pool host:port** so you are not locked to the official book. Presets remain Germany / Singapore / Helsinki. In-wallet miner is **gnfp-mine 1.0.9**. **MINE GNFP** keeps hashing after you leave the Mine tab (flashing green dot). Return to Mine and tap **STOP**.

Releases: https://github.com/rgsneddon/gnfp-wallet/releases
