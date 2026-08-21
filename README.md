# gnfp-wallet

$GNFP privacy wallet. Spendable asset is GNFP. Proof of work only.

- Pool: https://gnfp.restoreprivacy.online
- Stratum: `de.restoreprivacy.online:1474` (TLS; GNFPHash 1.0.2 — https://github.com/rgsneddon/GNFPHash)
- Coin: GNFP (not PERC, not Beam)
- Current pin: **0.1.4** — https://github.com/rgsneddon/gnfp-wallet/releases/tag/v0.1.4
- Mac handoff (node + wallet + miner): see `HANDOFF_APPLE_GNFP.md` in **gnfp-node** (one file for all pins)

## Install

**macOS** — open `gnfp-wallet-0.1.0-macos.dmg` and **drag GNFP Wallet onto the Applications folder** in that window, then eject the disk image. Launch from Applications (Spotlight / Dock), not from the disk image. This pin is Developer ID–signed and notarized so Gatekeeper can open it. If Finder says the app is damaged, re-download.

Do not mine from Downloads, a zip, or the open disk image. Those copies live on a temporary volume; when macOS unmounts it the wallet crashes (SIGBUS). The wallet copies itself into Applications if you still open a temp copy, and it will not start **MINE GNFP** until the app is on a real disk. A zip (`gnfp-wallet-0.1.0-macos.zip`) is still attached for the in-app update feed.

iPhone and iPad do not show the Applications dialog: the IPA is installed into the system app space (sideload / Xcode); there is no Applications folder.

**Android** — `gnfp-wallet-0.1.0-android.apk` (release-signed v2+v3 as **GNFP Wallet**, not the Android Debug cert). If 0.0.8 (debug-signed) is already on the phone, **uninstall it first**.

**iPhone / iPad** — unsigned `gnfp-wallet-0.1.0-ios.ipa` / `gnfp-wallet-0.1.0-ipad.ipa` (sideload).

**Windows / Linux / Arch** — laptop attaches `gnfp-wallet-0.1.0-windows.zip`, `-linux.zip`, `-archlinux.zip` to the same `v0.1.0` tag. See `WINDOWS_HANDOFF_0.1.0.md`.

```
flutter pub get
flutter test
flutter run
```

## CLI wallet how-to (Windows / Linux / macOS)

The GUI zip is one way to hold GNFP. The **CLI wallet** is the other: same `gnfp1` seed rules, same official book `https://gnfp.restoreprivacy.online`, same miner command as the Mine tab. Source is `bin/gnfp_cli.dart` (library `lib/gnfp_cli.dart`). It is not a separate coin or a sibling GitHub tag.

### Install / run

You need Dart (the Flutter SDK is enough). From a clone of this repo:

**Windows** (cmd or PowerShell):

```
cd gnfp-wallet
flutter pub get
dart run bin/gnfp_cli.dart -h
pack\gnfp-cli.cmd -h
```

**Linux**:

```
cd gnfp-wallet
flutter pub get
dart run bin/gnfp_cli.dart -h
chmod +x pack/gnfp-cli
./pack/gnfp-cli -h
```

**macOS**:

```
cd gnfp-wallet
flutter pub get
dart run bin/gnfp_cli.dart -h
chmod +x pack/gnfp-cli
./pack/gnfp-cli -h
```

`-h` and `--help` print the same tree:

```
usage: gnfp-cli [-h] {new,restore,show,balance,history,tip,send,mine-cmd} ...

Command-line GNFP wallet
```

### Session store

The CLI persists seed + `gnfp1` so `show` / `balance` / `send` reuse the same wallet as a later launch (and the GUI, if they share the store).

| OS | Default session file |
|----|----------------------|
| Windows | `%APPDATA%\GNFP\session.json` |
| Linux | `~/.gnfp/session.json` |
| macOS | `~/Library/Application Support/GNFP/session.json` |

Override with `--store PATH` (tests and extra wallets). Do not point `--pool` at a random host unless you intend a local book; the default is the official pool.

### Verbs

| Command | What it does |
|---------|----------------|
| `new` | Create a new hex seed + `gnfp1` address and write the session |
| `restore <hex>` | Restore from an existing hex seed (32 hex chars) |
| `show` | Print seed and address |
| `balance` | Query live spendable balance on the official book |
| `history` | Query address history (owner ledger) |
| `tip` | Query network tip (`ticker=GNFP` and height) |
| `send --to gnfp1… --amount N` | Send GNFP via the official pool book |
| `mine-cmd` | Print a GNFPHash / `gnfp-mine` command for this address (public TLS book) |

Examples (Windows; drop `dart run bin/gnfp_cli.dart` in for `gnfp-cli` on every OS):

```
dart run bin/gnfp_cli.dart new
dart run bin/gnfp_cli.dart show
dart run bin/gnfp_cli.dart restore aabbccddeeff00112233445566778899
dart run bin/gnfp_cli.dart balance
dart run bin/gnfp_cli.dart history
dart run bin/gnfp_cli.dart tip
dart run bin/gnfp_cli.dart send --to gnfp1… --amount 1.5
dart run bin/gnfp_cli.dart mine-cmd --threads 2
```

`tip` talks to the book and does not need a session. `balance` / `history` / `send` / `mine-cmd` / `show` need `new` or `restore` first. `send` moves **real** GNFP on the live book — check `balance` and the destination `gnfp1` before you run it.

Darwin packaging of this CLI onto a **later** GUI pin is Mac leftover (same tag as that pin, no `vX.Y.Z-cli` sibling). Do not rebuild the 0.1.8 GUI zips to carry it.

macOS GitHub disk image (Developer ID + notary + drag-to-Applications):

```
python3 pack/macos/sign_and_notarize.py --build
gh release upload v0.1.0 dist/gnfp-wallet-0.1.0-macos.dmg dist/gnfp-wallet-0.1.0-macos.zip --clobber
```

0.1.0: next pin after 0.0.9 (digits 0–9; there is no 0.0.10). Mine tab H/s is the same verified work rate the pool publishes (`accepted × 2^jobBits / elapsed` from the first accepted share). Login is not an accept. 0.0.9 showed farm hashes/sec from `start()`, so the wallet number did not match the pool.

0.0.9: selected Mine threads are real CPU workers — N threads hash more than 1 in the same interval (0.0.8 reported the same H/s for any thread count). Stays on the wire (stats every 1s + reconnect in 2s). 0.0.8 dropped to idle after the stratum socket closed (~1 minute, 1 thread) with no lastError. Mining stops only on **STOP** or closing the wallet. Mine tab accepts a **typed pool host:port** so you are not locked to the official book. Presets remain Germany / Singapore / Helsinki. In-wallet miner is **gnfp-mine 1.0.9**. **MINE GNFP** keeps hashing after you leave the Mine tab (flashing green dot). Return to Mine and tap **STOP**.

Releases: https://github.com/rgsneddon/gnfp-wallet/releases
