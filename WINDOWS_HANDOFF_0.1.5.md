# Windows / Arch / Linux handoff — gnfp-wallet 0.1.5

Pin: **0.1.5** (`version: 0.1.5+15`). GitHub title: `v0.1.5 - $GNFP privacy wallet`.
Miner: **GNFPHash 1.0.3** — https://github.com/rgsneddon/GNFPHash/releases/tag/v1.0.3
Node: **gnfp-node 1.2.3** — https://github.com/rgsneddon/gnfp-node/releases/tag/v1.2.3

Odometer: `0.1.4` → `0.1.5`. No `.10` segments.

Mac produces **macOS** (Developer ID + notarized), **Android**, and **iOS** when Xcode allows. It cannot emit signed **Windows**, **Arch**, or **Linux** zips. Build those here and upload to the matching GitHub releases.

This file is the Windows-machine job list.

```
git clone https://github.com/rgsneddon/gnfp-wallet
cd gnfp-wallet
git pull
git log -1 --oneline   # expect WINDOWS_HANDOFF_0.1.5 on master
```

Confirm `lib/gnfp_mine_command.dart` has `gnfpMineVersion = '1.0.3'`, `gnfpMineClient = 'GNFPHash'`.

## Why this pin

- Close/reopen must keep the same `gnfp1` and last-known spendable. Live `0` must not wipe a known amount. Android store is `/data/user/0/online.restoreprivacy.gnfp_wallet/files/GNFP/session.json`.
- Honest balances reconstruct from the height-indexed ledger with **wallet address + shear-obfuscation at that tx height**.
- Pool miners stay listed across a found block (round shares reset; presence stays).
- Miners must report **honest live farm threads**. The pool flags inflate / hide cheats.
- GNFPHash 1.0.3: cpuminer-opt-style native C loop (`src/native/gnfphash.c`) + official Node stratum client.

## Windows wallet

```
flutter build windows --release --build-name=0.1.5 --build-number=15
```

Zip the Release tree as `gnfp-wallet-0.1.5-windows.zip` (same layout as `v0.1.4`). Upload to `rgsneddon/gnfp-wallet` release `v0.1.5`.

## Linux wallet

```
flutter build linux --release --build-name=0.1.5 --build-number=15
```

Zip as `gnfp-wallet-0.1.5-linux.zip`. Upload to the same release.

## Arch

Build the Linux bundle, then package with `pack/archlinux/PKGBUILD` (`pkgver=0.1.5`). Upload `gnfp-wallet-0.1.5-archlinux.zip`.

## Miner (same machine)

```
git clone https://github.com/rgsneddon/GNFPHash.git
cd GNFPHash
git checkout v1.0.3
```

Compile the native loop if you have a C compiler + OpenSSL:

```
cc -O3 -std=c11 -o src/native/gnfphash.exe src/native/gnfphash.c -lssl -lcrypto
```

(or skip native; JS `hash_worker.js` still hashes).

Zip as `GNFPHash-1.0.3-windows.zip` (keep the `gnfp-mine` / `gnfp-mine.cmd` bin name). Upload to `rgsneddon/GNFPHash` `v1.0.3`.

```
node src/miner.js --pool de.restoreprivacy.online:1474 --user gnfp1YOURADDRESS.worker --threads 4
```

TLS by default. `--threads` clamps to CPUs−1. Wire `threads` is **farm.running** (honest live isolates), never a fake requested count.

## Node (same machine)

```
git clone https://github.com/rgsneddon/gnfp-node.git
cd gnfp-node
git checkout v1.2.3
```

Zip as `gnfp-node-1.2.3-windows.zip`. Upload to `rgsneddon/gnfp-node` `v1.2.3`.

```
node src/node.js --print-config
```

Must name GNFP, stratum 1474.

## Checks

1. Wallet chrome is `GNFPv0.1.5`. No Mix tab.
2. Seed coins, close, reopen: **same gnfp1**, balance does **not** revert to zero.
3. Mine tab: Germany / Singapore / Custom. Login/stats/submit send live farm threads, `client: GNFPHash`, `algorithm: GNFPHash`, version `1.0.3`.
4. CLI line still starts `gnfp-mine`. Download from https://github.com/rgsneddon/GNFPHash.
5. Pool UI: miners stay listed across a found block; **Threads honest** shows HONEST or CHEAT.
