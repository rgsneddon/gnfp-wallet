# Windows / Linux / Arch handoff — gnfp-wallet 0.0.9

**From:** Amelia’s Mac (2026-08-17)  
**Pin:** `0.0.9` (`v0.0.9`)  
**Same tag:** attach these zips to https://github.com/rgsneddon/gnfp-wallet/releases/tag/v0.0.9  
**Do not** invent a sibling tag.

## Laptop attach (exact filenames)

| File | Built on |
|------|----------|
| `gnfp-wallet-0.0.9-windows.zip` | Windows laptop |
| `gnfp-wallet-0.0.9-linux.zip` | Windows laptop (WSL/Linux) or Linux box |
| `gnfp-wallet-0.0.9-archlinux.zip` | same Linux build + PKGBUILD |

Mac already attaches (or will attach) to the **same** `v0.0.9`:

- `gnfp-wallet-0.0.9-macos.dmg`
- `gnfp-wallet-0.0.9-macos.zip`
- `gnfp-wallet-0.0.9-android.apk` (release-signed v2+v3 as GNFP Wallet — **not** the 0.0.8 debug-signed APK that Play Protect rejected. Uninstall 0.0.8 first.)
- `gnfp-wallet-0.0.9-ios.ipa`
- `gnfp-wallet-0.0.9-ipad.ipa`

```
git pull
flutter pub get
flutter build windows --release --build-name=0.0.9 --build-number=9
# zip build\windows\x64\runner\Release\* → dist\gnfp-wallet-0.0.9-windows.zip

flutter build linux --release --build-name=0.0.9 --build-number=9
# zip build/linux/x64/release/bundle/. → dist/gnfp-wallet-0.0.9-linux.zip
# PKGBUILD pkgver=0.0.9 + that bundle → dist/gnfp-wallet-0.0.9-archlinux.zip

gh release upload v0.0.9 \
  dist/gnfp-wallet-0.0.9-windows.zip \
  dist/gnfp-wallet-0.0.9-linux.zip \
  dist/gnfp-wallet-0.0.9-archlinux.zip \
  --clobber
```

## Mine checks (Windows — do these on the laptop zip)

0.0.8 / early 0.0.9-wip dropped the wallet miner to **idle** after the stratum socket closed (~1 minute, 1 thread) and showed the same H/s for 1 thread as for any N. 0.0.9 ships real per-thread workers and stays on the wire until **STOP** or the wallet process closes.

1. Mine tab → pick **1 thread** → Germany book (or a typed `host:1474`) → **MINE GNFP**.
2. Leave it **≥ 60 seconds**. Status must stay **STOP** (reconnecting is OK). Idle + **MINE GNFP** again is the old bug.
3. Change to **N>1 threads**, mine the same interval. Reported H/s and hashes must be **higher** than the 1-thread run.
4. Leave the Mine tab — green flashing dot stays; hashing continues. Return and tap **STOP** — only then it goes idle.
5. Close the wallet while mining — process exit is the other allowed stop.

If Windows still goes idle with an empty error, capture the Mine status line and whether the process still has a TCP session to `:1474`.
