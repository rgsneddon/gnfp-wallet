# Mac handover — gnfp-wallet 0.1.0 Apple / Android

**From:** Windows laptop (2026-08-18)  
**Pin:** `0.1.0` (`v0.1.0`) — next pin after `0.0.9`. There is no `0.0.10`.  
**Repo:** `rgsneddon/gnfp-wallet`  
**Why:** digits 0–9 only; in-wallet Mine H/s now matches the pool (`accepted × 2^jobBits / elapsed` from first accept). Login is not an accept.

Windows / Linux / Arch zips attach from the laptop to **this same tag**. Do **not** invent another tag. Do not rebuild 0.0.9.

## On Amelia’s Mac

```
cd ~/gnfp-wallet   # or wherever the clone lives
git fetch origin
git checkout master
git pull
git fetch --tags
# tip must include the 0.1.0 release commit (pin in pubspec.yaml / version.json)

flutter pub get
flutter test

# macOS — Developer ID + notary + drag-to-Applications (same as 0.0.9)
python3 pack/macos/sign_and_notarize.py --build
# produces dist/gnfp-wallet-0.1.0-macos.dmg and dist/gnfp-wallet-0.1.0-macos.zip

# Android — release-signed v2+v3 as GNFP Wallet (not the debug cert)
flutter build apk --release --build-name=0.1.0 --build-number=10
# copy the signed APK to dist/gnfp-wallet-0.1.0-android.apk

# iOS / iPad — unsigned sideload IPAs, same as 0.0.9
# dist/gnfp-wallet-0.1.0-ios.ipa
# dist/gnfp-wallet-0.1.0-ipad.ipa

gh release upload v0.1.0 \
  dist/gnfp-wallet-0.1.0-macos.dmg \
  dist/gnfp-wallet-0.1.0-macos.zip \
  dist/gnfp-wallet-0.1.0-android.apk \
  dist/gnfp-wallet-0.1.0-ios.ipa \
  dist/gnfp-wallet-0.1.0-ipad.ipa \
  --clobber
```

If `v0.1.0` is not on GitHub yet, wait for the laptop to push `master` + tag + Windows/Linux/Arch zips, then upload Apple/Android onto that tag.

## Mine check on Darwin

Mine tab H/s must match the pool worker after the first accepted share (not farm hashes/sec from tap). Login must not bump accepted. Chrome must show **GNFPv0.1.0**, not 0.0.10.

## Do not

- Do not restore 50-GNFP / 3000 ms blocks.
- Do not enable DE join.
- Do not attach these Apple bits to `v0.0.9`.
- Do not ship a `v0.0.10` tag.
- Do not force-push.
