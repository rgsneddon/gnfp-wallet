#!/usr/bin/env python3
"""Developer ID sign, notarize, staple, and ditto-zip GNFP Wallet for Gatekeeper.

The 0.0.6 GitHub zip was ad-hoc signed (`CODE_SIGN_IDENTITY = "-"`) and packed
with `zip`, which broke nested Flutter framework seals. Downloaded ad-hoc /
invalid nested code is exactly the macOS dialog:

    “gnfp_wallet” is damaged and can’t be opened. You should move it to the Bin.

Usage:
  python3 pack/macos/sign_and_notarize.py [--build] [--skip-notarize]
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_APP = (
    ROOT / "build" / "macos" / "Build" / "Products" / "Release" / "gnfp_wallet.app"
)
DEFAULT_IDENTITY = "Developer ID Application: Russell Sneddon (SFCBP95595)"
DEFAULT_KEY_DIR = Path.home() / "Library/Developer/perccent-codesign"
ENTITLEMENTS = ROOT / "macos" / "Runner" / "Release.entitlements"
PIN = "0.1.6"
BUILD_NUMBER = "16"


def run(cmd: list[str]) -> None:
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, check=True)


def run_capture(cmd: list[str]) -> str:
    print("+", " ".join(cmd), flush=True)
    p = subprocess.run(cmd, check=True, text=True, capture_output=True)
    return (p.stdout or "") + (p.stderr or "")


def sign_path(path: Path, identity: str, entitlements: Path | None) -> None:
    cmd = [
        "codesign",
        "--force",
        "--timestamp",
        "--options",
        "runtime",
        "--sign",
        identity,
    ]
    if entitlements is not None:
        cmd.extend(["--entitlements", str(entitlements)])
    cmd.append(str(path))
    run(cmd)


def sign_app(app: Path, identity: str) -> None:
    if not app.is_dir():
        raise FileNotFoundError(f"app not found: {app}")
    if not ENTITLEMENTS.is_file():
        raise FileNotFoundError(f"missing {ENTITLEMENTS}")

    nested: list[Path] = []
    contents = app / "Contents"
    for root, dirs, files in os.walk(contents):
        for d in dirs:
            p = Path(root) / d
            if p.suffix in {".framework", ".appex"}:
                nested.append(p)
        for f in files:
            p = Path(root) / f
            if p.suffix in {".dylib", ".so"}:
                nested.append(p)
    nested.sort(key=lambda p: len(p.parts), reverse=True)
    seen: set[str] = set()
    for p in nested:
        key = str(p.resolve())
        if key in seen:
            continue
        seen.add(key)
        if ".framework/" in str(p) and p.suffix != ".framework":
            continue
        sign_path(p, identity, None)

    for p in sorted((app / "Contents/Frameworks").glob("*.framework")):
        sign_path(p, identity, None)

    main_bin = app / "Contents/MacOS/gnfp_wallet"
    if main_bin.is_file():
        sign_path(main_bin, identity, ENTITLEMENTS)
    sign_path(app, identity, ENTITLEMENTS)
    run(["codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app)])


def resolve_notary_args() -> list[str]:
    key = os.environ.get("RP_NOTARY_KEY")
    key_id = os.environ.get("RP_NOTARY_KEY_ID")
    issuer = os.environ.get("RP_NOTARY_ISSUER")
    if not key and (DEFAULT_KEY_DIR / "key-id.txt").is_file():
        for line in (DEFAULT_KEY_DIR / "key-id.txt").read_text().splitlines():
            if line.startswith("KEY_ID="):
                key_id = key_id or line.split("=", 1)[1].strip()
            if line.startswith("P8="):
                key = key or line.split("=", 1)[1].strip()
        if not key:
            keys = list(DEFAULT_KEY_DIR.glob("AuthKey_*.p8"))
            if keys:
                key = str(keys[0])
                if not key_id:
                    key_id = keys[0].stem.replace("AuthKey_", "")
    if not issuer and (DEFAULT_KEY_DIR / "issuer-id.txt").is_file():
        issuer = (DEFAULT_KEY_DIR / "issuer-id.txt").read_text().strip()
    if not (key and key_id and issuer):
        raise RuntimeError(
            "set RP_NOTARY_KEY / RP_NOTARY_KEY_ID / RP_NOTARY_ISSUER "
            "or install AuthKey + issuer-id under ~/Library/Developer/perccent-codesign/"
        )
    return ["--key", key, "--key-id", key_id, "--issuer", issuer]


def notarize_and_staple(app: Path) -> None:
    creds = resolve_notary_args()
    with tempfile.TemporaryDirectory() as td:
        zip_path = Path(td) / "gnfp_wallet-for-notary.zip"
        run(["ditto", "-c", "-k", "--keepParent", str(app), str(zip_path)])
        run(["xcrun", "notarytool", "submit", str(zip_path), *creds, "--wait"])
    run(["xcrun", "stapler", "staple", str(app)])
    run(["xcrun", "stapler", "validate", str(app)])


def assess(app: Path) -> str:
    try:
        return run_capture(["spctl", "--assess", "--type", "execute", "-vv", str(app)])
    except subprocess.CalledProcessError as e:
        return (e.stdout or "") + (e.stderr or "") + f"\nexit={e.returncode}"


def launch_probe(app: Path) -> dict:
    main_bin = app / "Contents/MacOS/gnfp_wallet"
    if not main_bin.is_file():
        return {"ok": False, "error": f"missing {main_bin}"}
    proc = subprocess.Popen(
        [str(main_bin)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    try:
        rc = proc.wait(timeout=2.5)
    except subprocess.TimeoutExpired:
        try:
            proc.terminate()
            proc.wait(timeout=5)
        except Exception:
            proc.kill()
        return {"ok": True, "alive": True, "rc": None}
    if rc == 0:
        return {"ok": True, "alive": False, "rc": 0}
    return {"ok": False, "alive": False, "rc": rc, "error": f"exited rc={rc}"}


def package_zip(app: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        dest.unlink()
    run(["ditto", "-c", "-k", "--keepParent", str(app), str(dest)])


def notarize_artifact(path: Path) -> None:
    creds = resolve_notary_args()
    run(["xcrun", "notarytool", "submit", str(path), *creds, "--wait"])
    run(["xcrun", "stapler", "staple", str(path)])
    run(["xcrun", "stapler", "validate", str(path)])


def package_dmg(app: Path, dest: Path, identity: str) -> None:
    script = Path(__file__).resolve().parent / "make_dmg.py"
    run(
        [
            sys.executable,
            str(script),
            "--app",
            str(app),
            "--dmg",
            str(dest),
            "--identity",
            identity,
        ]
    )


def flutter_build() -> None:
    flutter = os.environ.get("FLUTTER", "flutter")
    run(
        [
            flutter,
            "build",
            "macos",
            "--release",
            f"--build-name={PIN}",
            f"--build-number={BUILD_NUMBER}",
        ]
    )


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--app", type=Path, default=DEFAULT_APP)
    ap.add_argument(
        "--zip",
        type=Path,
        default=ROOT / "dist" / f"gnfp-wallet-{PIN}-macos.zip",
    )
    ap.add_argument("--identity", default=DEFAULT_IDENTITY)
    ap.add_argument("--build", action="store_true")
    ap.add_argument("--skip-notarize", action="store_true")
    args = ap.parse_args(argv)

    os.chdir(ROOT)
    if args.build:
        flutter_build()

    app = args.app.resolve()
    identity = args.identity
    print(f"Signing {app} with {identity}", flush=True)
    sign_app(app, identity)

    cs = run_capture(["codesign", "-dv", "--verbose=4", str(app)])
    print(cs)
    if "Signature=adhoc" in cs:
        print("ERROR: still ad-hoc after sign", file=sys.stderr)
        return 2
    if "Developer ID Application" not in cs:
        print(f"ERROR: not Developer ID Application:\n{cs}", file=sys.stderr)
        return 2
    ents = run_capture(["codesign", "-d", "--entitlements", ":-", str(app)])
    if "get-task-allow" in ents:
        print("ERROR: get-task-allow leaked into distribution seal", file=sys.stderr)
        return 2

    if not args.skip_notarize:
        try:
            notarize_and_staple(app)
        except subprocess.CalledProcessError as e:
            print(f"NOTARY_FAILED: {e}", file=sys.stderr)
            return e.returncode or 3

    sp = assess(app)
    print(sp)
    if not args.skip_notarize and "Notarized Developer ID" not in sp:
        print("WARNING: spctl did not report Notarized Developer ID", file=sys.stderr)

    probe = launch_probe(app)
    print(f"launch_probe={probe}", flush=True)
    if not probe.get("ok"):
        print(f"ERROR: launch probe failed: {probe}", file=sys.stderr)
        return 4

    dest = args.zip.resolve()
    package_zip(app, dest)
    sha = run_capture(["shasum", "-a", "256", str(dest)]).split()[0]
    print(f"Wrote {dest} sha256={sha}", flush=True)

    dmg = (ROOT / "dist" / f"gnfp-wallet-{PIN}-macos.dmg").resolve()
    package_dmg(app, dmg, identity)
    if not args.skip_notarize:
        try:
            notarize_artifact(dmg)
        except subprocess.CalledProcessError as e:
            print(f"DMG_NOTARY_FAILED: {e}", file=sys.stderr)
            return e.returncode or 3
    dmg_sha = run_capture(["shasum", "-a", "256", str(dmg)]).split()[0]
    print(f"Wrote {dmg} sha256={dmg_sha}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
