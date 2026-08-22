# Windows pointer — gnfp-wallet 0.2.0

**Do not use this file as the pin list.** All leftover lives in:

**https://github.com/rgsneddon/handoff/blob/main/HANDOFF.md**

Current pin here: **0.2.0**. Do **not** rebuild **0.1.9**. In-wallet Mine path is **gnfp-cminer 1.1.0** (same GNFPHash-v1 wire, declared **5% miner** dual-login fee). That is **not** a pool tax — the live book still takes **1%** of formed blocks. Official standalone miner pin is public **gnfp-cminer 1.1.0**. Node **GNFPHash** / `gnfp-mine` is deprecated. Node **1.2.7**. `HASH_TX_LIVE` stays **0**.

## What 0.2.0 ships

- Mine tab states the **5% dev fee** and hashes the same dual-login path as gnfp-cminer
- CLI `--version` is `$GNFP core wallet v0.2.0 (cli)` (same pin as the GUI)
- Send / receive / balance / tip / explorer unchanged from the 0.1.9 standard

Attach to **the same** `v0.2.0` tag. No sibling tags. Do **not** rebuild 0.1.9. Do **not** rebuild C-miner PE already on public `v1.1.0`.

| File | What is inside |
|------|----------------|
| `gnfp-wallet-0.2.0-windows.zip` | Windows Flutter desktop |
| `gnfp-wallet-0.2.0-linux.zip` | Linux Flutter desktop |
| `gnfp-wallet-0.2.0-archlinux.zip` | Arch PKGBUILD / same pin |

Title `$GNFP core wallet v0.2.0`. After attaching, update the leftover row in `HANDOFF.md`. Mac leftover for this pin is **none** once Darwin/Android/iOS are on the tag; laptop leftover is Windows/Linux/Arch + APK second-eye only.
