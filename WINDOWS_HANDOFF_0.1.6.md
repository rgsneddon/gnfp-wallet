# Windows / Arch / Linux handoff — gnfp-wallet 0.1.6

Pin: **0.1.6** (`version: 0.1.6+16`). GitHub title: `v0.1.6 - $GNFP privacy wallet`.
Miner: **GNFPHash 1.0.4** — https://github.com/rgsneddon/GNFPHash/releases/tag/v1.0.4
Node: **gnfp-node 1.2.4** — https://github.com/rgsneddon/gnfp-node/releases/tag/v1.2.4

Odometer: `0.1.5` → `0.1.6`. No `.10` segments.

Mac produces **macOS** (Developer ID + notarized), **Android**, and **iOS** when Xcode allows. It cannot emit signed **Windows**, **Arch**, or **Linux** zips. Build those here and upload to the matching GitHub releases.

Operator index: **https://github.com/rgsneddon/handoff/blob/main/HANDOFF.md**

```
git clone https://github.com/rgsneddon/gnfp-wallet
cd gnfp-wallet
git pull
git log -1 --oneline   # expect WINDOWS_HANDOFF_0.1.6 on master
```

Confirm `lib/gnfp_mine_command.dart` has `gnfpMineVersion = '1.0.4'`, `gnfpMineClient = 'GNFPHash'`. Login/stats/submit send `cpuCores` (physical) and `threads` with `cpuCores >= threads`.

## Why this pin

- In-wallet miner is **GNFPHash 1.0.4**. Pool/node refuse 1.0.3 and lower.
- **1 thread = 1 physical core.** `--threads 10` on 12 cores stays 10. On 6-core/12-SMT the honor cap is 6 so the pool does not see inflate.
- Login / stats / submit send live farm threads **and** `cpuCores` / `cpuThreads` / `smt`.

## Windows wallet

```
flutter build windows --release --build-name=0.1.6 --build-number=16
```

Zip the Release tree as `gnfp-wallet-0.1.6-windows.zip`. Upload to `rgsneddon/gnfp-wallet` release `v0.1.6`.

## Linux wallet

```
flutter build linux --release --build-name=0.1.6 --build-number=16
```

Zip as `gnfp-wallet-0.1.6-linux.zip`. Upload to the same release.

## Arch

Build the Linux bundle, then package with `pack/archlinux/PKGBUILD` (`pkgver=0.1.6`). Upload `gnfp-wallet-0.1.6-archlinux.zip`.

## Miner native (same machine)

This Mac already attached **source** `GNFPHash-1.0.4-windows.zip` on `v1.0.4` (no Darwin binary). Laptop leftover:

```
cc -O3 -std=c11 -o src/native/gnfphash.exe src/native/gnfphash.c -lssl -lcrypto
```

(`GNFP_NATIVE=1`). JS `hash_worker.js` hashes if native cannot run.

```
node src/miner.js --pool de.restoreprivacy.online:1474 --user gnfp1YOURADDRESS.worker --threads 4
```

TLS by default. Honor cap is **physical cores**. Wire `threads` is farm.running.

## Node (same machine)

```
git clone https://github.com/rgsneddon/gnfp-node.git
cd gnfp-node
git checkout v1.2.4
```

Source pack is on the tag. Windows zip leftover if a PE layout is needed: `gnfp-node-1.2.4-windows.zip`.
