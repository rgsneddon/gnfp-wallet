#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/flutter-sdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
mkdir -p "$HOME/src"
rm -rf "$HOME/src/gnfp-wallet"
mkdir -p "$HOME/src/gnfp-wallet"
rsync -a --delete \
  --exclude build --exclude dist --exclude .dart_tool --exclude _leftover \
  /mnt/c/Users/rgsne/gnfp-wallet/ "$HOME/src/gnfp-wallet/"
cd "$HOME/src/gnfp-wallet"
flutter pub get
flutter build linux --release --build-name=0.1.0 --build-number=10
python3 - <<'PY'
import os, zipfile
root = os.path.expanduser("~/src/gnfp-wallet/build/linux/x64/release/bundle")
out = "/mnt/c/Users/rgsne/gnfp-wallet/dist/gnfp-wallet-0.1.0-linux.zip"
os.makedirs(os.path.dirname(out), exist_ok=True)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for dp, _dns, fns in os.walk(root):
        for fn in fns:
            p = os.path.join(dp, fn)
            z.write(p, os.path.relpath(p, root))
print("wrote", out, os.path.getsize(out))
PY
ls -l /mnt/c/Users/rgsne/gnfp-wallet/dist/gnfp-wallet-0.1.0-linux.zip
