# Windows handoff — gnfp-wallet 0.1.1

Pin: **0.1.1** (`version: 0.1.1+11`). Title: `v0.1.1 - $GNFP privacy wallet`.

Odometer: 0.0.9 → 0.1.0 → 0.1.1. No `.10` segments.

## What shipped

- Mine tab: Germany and Singapore only, plus Custom host:port. No Helsinki. No book/join/front labels.
- gnfp-mine line follows pool, custom host, threads, and payout gnfp1.
- Credit wallet with pending GNFP does not add an explorer row when delta is `<= 0`.

Windows signed zip is not produced on Mac. Build on Windows:

```
cd gnfp-wallet
git pull
flutter build windows
```

Upload `gnfp-wallet-0.1.1-windows.zip` to the `v0.1.1` GitHub release.
