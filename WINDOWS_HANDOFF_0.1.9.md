# Windows pointer — gnfp-wallet 0.1.9

**Do not use this file as the pin list.** All GNFP client leftover lives in:

**https://github.com/rgsneddon/handoff/blob/main/HANDOFF.md**

Current pin here: **0.1.9**. Do **not** rebuild 0.1.8. In-wallet miner stays **GNFPHash 1.0.5**. Standalone CLI miner pin is **GNFPHash 1.0.6** (Node 18+ on PATH — installing Node includes npm; do **not** `npm install` the miner). Node **1.2.6**. `HASH_TX_LIVE` stays **0**.

## What 0.1.9 fixes

Explorer for **this gnfp1** lists **send** (from = your address) and **receive** (to = your address). A local send is not dropped when the book later confirms the same id. Unconfirmed hash-bonus rows stay off the explorer.

## Laptop leftover (this Mac cannot ship these)

Attach to **the same** `v0.1.9` tag. No sibling tags. Do **not** rebuild 0.1.8.

| File | For |
|------|-----|
| `gnfp-wallet-0.1.9-windows.zip` | Windows Flutter desktop |
| `gnfp-wallet-0.1.9-linux.zip` | Linux Flutter desktop |
| `gnfp-wallet-0.1.9-archlinux.zip` | Arch PKGBUILD / same pin |

Title `$GNFP core wallet v0.1.9`. After attaching, update the leftover row in `HANDOFF.md`.

Windows wallet **will not synchronise** report from 0.1.8 leftover still applies until proven on this pin (`Network Tip` / `GET /api/tip` via Dart `HttpClient`).
