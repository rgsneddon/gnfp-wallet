# Windows / Linux / Arch handoff — gnfp-wallet 0.1.0

**From:** Windows laptop (2026-08-18)  
**Pin:** `0.1.0` (`v0.1.0`)  
**Same tag:** attach these zips to https://github.com/rgsneddon/gnfp-wallet/releases/tag/v0.1.0  
**Do not** invent a sibling tag. Do not rebuild or clobber `v0.0.9`. There is no `0.0.10` — after `0.0.9` the pin is `0.1.0`.

## Laptop attach (exact filenames)

| File | Built on |
|------|----------|
| `gnfp-wallet-0.1.0-windows.zip` | Windows laptop |
| `gnfp-wallet-0.1.0-linux.zip` | Windows laptop (WSL/Linux) |
| `gnfp-wallet-0.1.0-archlinux.zip` | same Linux build + PKGBUILD |

Mac attaches (see `MAC_HANDOFF_0.1.0.md`) to the **same** `v0.1.0`:

- `gnfp-wallet-0.1.0-macos.dmg`
- `gnfp-wallet-0.1.0-macos.zip`
- `gnfp-wallet-0.1.0-android.apk` (release-signed v2+v3 as GNFP Wallet)
- `gnfp-wallet-0.1.0-ios.ipa`
- `gnfp-wallet-0.1.0-ipad.ipa`

```
git pull
flutter pub get
flutter build windows --release --build-name=0.1.0 --build-number=10
# zip build\windows\x64\runner\Release\* → dist\gnfp-wallet-0.1.0-windows.zip

flutter build linux --release --build-name=0.1.0 --build-number=10
# zip build/linux/x64/release/bundle/. → dist/gnfp-wallet-0.1.0-linux.zip
# PKGBUILD pkgver=0.1.0 + that bundle → dist/gnfp-wallet-0.1.0-archlinux.zip

gh release upload v0.1.0 \
  dist/gnfp-wallet-0.1.0-windows.zip \
  dist/gnfp-wallet-0.1.0-linux.zip \
  dist/gnfp-wallet-0.1.0-archlinux.zip \
  --clobber
```

## What 0.1.0 changes

Pins after `0.0.9` are `0.1.0` (digits 0–9; not `0.0.10`).

Mine tab H/s is the same verified work rate the pool publishes (`accepted × 2^jobBits / elapsed` from the first accepted share). Login is not an accept. 0.0.9 showed farm hashes/sec from `start()`, so the wallet number did not match the pool.

## Mine checks (Windows zip)

1. Mine tab → 1 thread → Germany book → **MINE GNFP**.
2. Leave it until **accepted ≥ 1**. Wallet H/s and the pool worker row for that miner must be the same order of magnitude and use the same accepts/bits/elapsed (not farm hashes/sec).
3. N>1 threads still hashes more than 1 thread in the same interval (hashes, not a second rate definition).
4. **STOP** leaves running false.
