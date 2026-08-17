#!/usr/bin/env python3
"""Build the classic drag-to-Applications GNFP Wallet disk image.

Finder window: GNFP Wallet.app on the left, Applications folder on the right.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_APP = (
    ROOT / "build" / "macos" / "Build" / "Products" / "Release" / "gnfp_wallet.app"
)
VOLNAME = "GNFP Wallet"
APP_NAME = "GNFP Wallet.app"
BACKGROUND = ROOT / "pack" / "macos" / "dmg_background.png"
RENDER = ROOT / "pack" / "macos" / "render_dmg_background.swift"


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess[str]:
    print("+", " ".join(cmd), flush=True)
    return subprocess.run(cmd, check=True, text=True, **kw)


def render_background(dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    run(["swift", str(RENDER), str(dest)])
    if not dest.is_file():
        raise RuntimeError(f"background not written: {dest}")


def detatch(path: Path) -> None:
    subprocess.run(
        ["hdiutil", "detach", str(path), "-quiet", "-force"],
        check=False,
        capture_output=True,
    )


def make_dmg(app: Path, dest: Path, identity: str | None) -> Path:
    if not app.is_dir():
        raise FileNotFoundError(f"app not found: {app}")
    if not BACKGROUND.is_file():
        render_background(BACKGROUND)

    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        dest.unlink()

    with tempfile.TemporaryDirectory(prefix="gnfp-dmg-") as td:
        td_path = Path(td)
        stage = td_path / "stage"
        stage.mkdir()
        shutil.copytree(app, stage / APP_NAME, symlinks=True)
        os.symlink("/Applications", stage / "Applications")
        bg_dir = stage / ".background"
        bg_dir.mkdir()
        shutil.copy2(BACKGROUND, bg_dir / "background.png")

        rw = td_path / "rw.dmg"
        run(
            [
                "hdiutil",
                "create",
                "-ov",
                "-volname",
                VOLNAME,
                "-fs",
                "HFS+",
                "-srcfolder",
                str(stage),
                "-format",
                "UDRW",
                str(rw),
            ]
        )
        mount = Path("/Volumes") / VOLNAME
        detatch(mount)
        run(["hdiutil", "attach", str(rw), "-readwrite", "-noverify", "-noautoopen"])
        try:
            subprocess.run(["chflags", "hidden", str(mount / ".background")], check=False)
            layout = f'''
tell application "Finder"
  tell disk "{VOLNAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {{200, 120, 860, 540}}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 128
    try
      set background picture of opts to file ".background:background.png"
    end try
    set position of item "{APP_NAME}" to {{160, 200}}
    set position of item "Applications" to {{500, 200}}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
'''
            styled = subprocess.run(
                ["osascript", "-e", layout],
                check=False,
                text=True,
                capture_output=True,
            )
            if styled.returncode != 0:
                print(
                    f"WARNING: Finder layout skipped: {styled.stderr.strip()}",
                    flush=True,
                )
            # Flush Finder's .DS_Store before detach.
            subprocess.run(["sync"], check=False)
        finally:
            detatch(mount)

        run(
            [
                "hdiutil",
                "convert",
                str(rw),
                "-format",
                "UDZO",
                "-imagekey",
                "zlib-level=9",
                "-o",
                str(dest),
            ]
        )

    if identity:
        run(
            [
                "codesign",
                "--force",
                "--timestamp",
                "--sign",
                identity,
                str(dest),
            ]
        )
    print(f"Wrote {dest}", flush=True)
    return dest


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--app", type=Path, default=DEFAULT_APP)
    ap.add_argument(
        "--dmg",
        type=Path,
        default=ROOT / "dist" / "gnfp-wallet-macos.dmg",
    )
    ap.add_argument("--identity", default="")
    args = ap.parse_args(argv)
    make_dmg(args.app.resolve(), args.dmg.resolve(), args.identity or None)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
