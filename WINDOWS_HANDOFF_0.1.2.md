# Windows / Arch / Linux handoff — gnfp-wallet 0.1.2

Pin: **0.1.2** (`version: 0.1.2+12`). GitHub title: `v0.1.2 - $GNFP privacy wallet`.
Miner: **GNFPHash 1.0.1** — https://github.com/rgsneddon/GNFPHash/releases/tag/v1.0.1

Odometer: `0.1.1` → `0.1.2`. No `.10` segments.

Mac produces **macOS** (Developer ID + notarized) and **iOS** when Xcode allows. It cannot emit signed **Windows**, **Arch**, or **Linux** zips. Build those here and upload to the same `v0.1.2` release.

Live book: `client` and `algorithm` must be **GNFPHash**. Old `gnfp-mine` clients are refused.

```
git clone https://github.com/rgsneddon/gnfp-wallet
cd gnfp-wallet
git pull
git log -1 --oneline   # expect 8c079db or later on master (GNFPHash 1.0.1 wire)
```

Confirm `lib/gnfp_mine_command.dart` has `gnfpMineVersion = '1.0.1'`, `gnfpMineClient = 'GNFPHash'`.

## Windows

```
flutter build windows --release --build-name=0.1.2 --build-number=12
```

Zip the Release tree as `gnfp-wallet-0.1.2-windows.zip` (same layout as `v0.1.1`). Upload to `rgsneddon/gnfp-wallet` release `v0.1.2`.

## Linux

```
flutter build linux --release --build-name=0.1.2 --build-number=12
```

Zip as `gnfp-wallet-0.1.2-linux.zip`. Upload to the same release.

## Arch

Build the Linux bundle, then package with `pack/archlinux/PKGBUILD` (bump `pkgver=0.1.2` if it is still 0.1.1). Upload `gnfp-wallet-0.1.2-archlinux.zip`.

## Miner (same machine)

```
git clone https://github.com/rgsneddon/GNFPHash.git
cd GNFPHash
git checkout v1.0.1
```

Zip as `GNFPHash-1.0.1-windows.zip` (or keep the `gnfp-mine` bin name). Upload to `rgsneddon/GNFPHash` `v1.0.1`.

```
node src/miner.js --pool de.restoreprivacy.online:1474 --user gnfp1YOURADDRESS.worker --threads 4
```

TLS by default. `--threads` clamps to CPUs−1. Wire `threads` is farm.running.

## Checks

1. Wallet chrome is `GNFPv0.1.2`. No Mix tab.
2. Mine tab: Germany / Singapore / Custom. Login/stats/submit send live farm threads, `client: GNFPHash`, `algorithm: GNFPHash`, version `1.0.1`.
3. CLI line still starts `gnfp-mine` (binary name). Download from https://github.com/rgsneddon/GNFPHash.
4. In-wallet mine against the live book accepts shares (not `old_miner_refused` / `client_required`).
