# Windows pointer — gnfp-wallet 0.1.8

**Do not use this file as the pin list.** All GNFP client leftover lives in:

**https://github.com/rgsneddon/handoff/blob/main/HANDOFF.md**

Current pin here: **0.1.8**. In-wallet miner **GNFPHash 1.0.5** (unchanged). Node **1.2.6**. `HASH_TX_LIVE` stays **0**.

## Laptop leftover (this Mac cannot ship these)

Attach to **the same** `v0.1.8` tag. No sibling tags (`v0.1.8-windows` etc). Do **not** rebuild 0.1.7 or 0.1.6.

| File | For |
|------|-----|
| `gnfp-wallet-0.1.8-windows.zip` | Windows Flutter desktop |
| `gnfp-wallet-0.1.8-linux.zip` | Linux Flutter desktop |
| `gnfp-wallet-0.1.8-archlinux.zip` | Arch PKGBUILD / same pin |

Title must be `$GNFP core wallet v0.1.8`. Window chrome, backup warning (cream text on a dark fill, yellow border — not yellow-on-yellow), Restore must persist `%APPDATA%\GNFP\session.json` so a relaunch returns the restored gnfp1.

After attaching, update the laptop leftover row in `HANDOFF.md`.

## User report — Windows wallet will not synchronise

A user on the **Windows** wallet says it **will not synchronise**. This Mac cannot reproduce a Win32 HTTP/TLS stack. Investigate on the laptop **before** calling 0.1.8 Windows done.

What “synchronise” is in this app (there is no separate sync button):

1. **Network Tip** on the Wallet tab (`gnfp-network-tip`). `WalletScreen` polls every 3s via `GnfpLedger.networkTip()` → `GET {pool}/api/tip`, fallback `GET {pool}/api/network`. If this stays `…`, HTTP never returned.
2. **Spendable / Balance.** Boot and the same poll call `GET /api/wallet/balance?address=gnfp1…` (`syncSpendable` / `pool.balance`). Errors are swallowed (`catch (_) {}`). A hung or failed TLS looks like a forever-stale balance.
3. **Explorer history.** `syncOwnerHistory` → `GET /api/wallet/history?address=…`. Hash-bonus rows appear only after tip (pending is spendable, not an explorer row).

Book origins the client hits (HTTPS, no timeout on `HttpClient`):

- `https://gnfp.restoreprivacy.online` (`gnfpPoolUrl`)
- fallback `https://explorer.restoreprivacy.online` for missing wallet/bridge paths

### Reproduce on the laptop (0.1.7 zip first, then 0.1.8)

1. Launch `gnfp-wallet-0.1.7-windows.zip` (current public Windows pin). Note whether **Network Tip** stays `…` and whether Balance never moves off a cached amount.
2. From **cmd** on the same box (not WSL unless the user is on WSL):

```bat
curl -v https://gnfp.restoreprivacy.online/api/network
curl -v https://gnfp.restoreprivacy.online/api/tip
curl -v https://explorer.restoreprivacy.online/api/network
```

Expect JSON `ticker=GNFP` and a live `height`. If curl fails (Schannel, proxy, TLS, timeout, 4xx), that is the wallet failure too.

3. Check Windows session store exists and is the address on screen:

```
%APPDATA%\GNFP\session.json
```

Older leftovers also: `%APPDATA%\gnfp\session.json`, `%LOCALAPPDATA%\GNFP\session.json`. `0.1.8` still migrates those.

4. Defender / firewall / corporate TLS-intercept proxy: Dart `HttpClient` uses the Windows cert store. A MITM proxy without the intercept CA installed will hang or throw; the UI stays on `…` because `_pullNetwork` swallows errors.
5. Confirm the window title is `$GNFP core wallet v0.1.7` on the user’s zip (not a leftover 0.0.2 / 0.1.0 binary).

### Likely causes to check in this order

| Rank | Cause | What to do |
|------|--------|------------|
| 1 | TLS to `gnfp.restoreprivacy.online` fails on this Windows (Schannel, missing intermediates, TLS-intercept) | curl `-v` as above; if curl works and the app does not, Dart `HttpClient` / `SecurityContext` on Windows is the bug — add an explicit timeout + surface the error instead of swallowing it |
| 2 | `HttpClient` has **no** `connectionTimeout` | hung DNS/TCP looks like “won’t sync”. 0.1.8 Mac sources can take a timeout; if you patch it, ship it on **0.1.8** Windows, do not rebuild 0.1.7 |
| 3 | User is on a stale zip / wrong pin | title + `version.json` inside the zip |
| 4 | Session gnfp1 is a restore-to-empty wallet (wrong 12 words) | 0.1.8 Restore persist is fixed; confirm they did not mint a new empty gnfp1 |
| 5 | Explorer empty while balance pending | expected until the next formed block (`HASH_TX_LIVE=0`); Network Tip should still move |

Do **not** treat Helsinki as a book. Do **not** point the wallet at `127.0.0.1:8014` unless a local 1.2.6 join is running. Live book is Germany (`rpt-gnfp-pool`).

If 0.1.8 Windows still will not fill Network Tip after curl succeeds, file the Dart `HttpClient` Windows behaviour (timeout + visible error) as a follow-up on the same `v0.1.8` tag — no sibling tag.
