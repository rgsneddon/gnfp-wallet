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
flutter build linux --release --build-name=0.1.8 --build-number=18
python3 - <<'PY'
import os, zipfile, shutil
root = os.path.expanduser("~/src/gnfp-wallet/build/linux/x64/release/bundle")
dist = "/mnt/c/Users/rgsne/gnfp-wallet/dist"
os.makedirs(dist, exist_ok=True)
linux_out = os.path.join(dist, "gnfp-wallet-0.1.8-linux.zip")
with zipfile.ZipFile(linux_out, "w", zipfile.ZIP_DEFLATED) as z:
    for dp, _dns, fns in os.walk(root):
        for fn in fns:
            p = os.path.join(dp, fn)
            z.write(p, os.path.relpath(p, root))
print("wrote", linux_out, os.path.getsize(linux_out))
# Arch zip: PKGBUILD + the same linux bundle
arch_out = os.path.join(dist, "gnfp-wallet-0.1.8-archlinux.zip")
pkgbuild = os.path.expanduser("~/src/gnfp-wallet/pack/archlinux/PKGBUILD")
with zipfile.ZipFile(arch_out, "w", zipfile.ZIP_DEFLATED) as z:
    z.write(pkgbuild, "PKGBUILD")
    for dp, _dns, fns in os.walk(root):
        for fn in fns:
            p = os.path.join(dp, fn)
            z.write(p, os.path.relpath(p, root))
print("wrote", arch_out, os.path.getsize(arch_out))
PY
ls -l /mnt/c/Users/rgsne/gnfp-wallet/dist/gnfp-wallet-0.1.8-linux.zip \
      /mnt/c/Users/rgsne/gnfp-wallet/dist/gnfp-wallet-0.1.8-archlinux.zip
# Refuse tiny/source stubs
python3 - <<'PY'
import zipfile, sys
for name in (
    "/mnt/c/Users/rgsne/gnfp-wallet/dist/gnfp-wallet-0.1.8-linux.zip",
    "/mnt/c/Users/rgsne/gnfp-wallet/dist/gnfp-wallet-0.1.8-archlinux.zip",
):
    size = __import__("os").path.getsize(name)
    names = zipfile.ZipFile(name).namelist()
    print(name, "bytes", size, "entries", len(names))
    print("\n".join(names[:30]))
    if size < 1_000_000:
        sys.exit(f"refusing tiny zip {name}")
    if not any(n.endswith("gnfp_wallet") or n == "gnfp_wallet" for n in names):
        sys.exit(f"missing gnfp_wallet in {name}")
    if "archlinux" in name and "PKGBUILD" not in names:
        sys.exit("arch zip missing PKGBUILD")
print("ok")
PY
