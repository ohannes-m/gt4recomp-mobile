#!/usr/bin/env python3
"""Rebuild the PS2 *public MIT runtime* derivations in an isolated workspace.

Requires an existing pinned ps2-web-recomp Git checkout in
<assets_root>/private/references/ps2-web-recomp. Does not download anything,
read disc/game files, build an APK, or publish generated C++.

This checks actual SHA-256 against immutable docs/inputs manifest pins, not
just successful script exit codes. A failure means do NOT substitute the new
derived sources into the user's private Android build.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
DONOR_COMMIT = "1b4808793a12c45125262fd2d5f50a9ec9f7c020"

# output directory name, generating script, extra CLI flags, pin manifest
DERIVATIONS = (
    ("slice200-port", "prepare_external_vulkan.py",
     ("--gs-stream-hooks",), "slice262-frame-cost-runtime.json", "PORT"),
    ("slice262-frame-cost-runtime", "prepare_perf_runtime.py",
     ("--mtvu", "--gs-stream", "--frame-cost"), "slice262-frame-cost-runtime.json", None),
    ("slice376-frame-render-license-guard-runtime", "prepare_license_guard.py",
     ("--display-aspect", "--frame-counters", "--frame-skip"),
     "slice376-frame-render-license-guard-runtime.json", None),
    ("slice200-memcard-runtime", "prepare_memcard_flush.py",
     (), None, "sio2.cpp"),
    ("slice365-ipu-fast-runtime", "prepare_ipu_fast.py",
     (), None, "ipu.cpp"),
    ("slice396-spu2-runtime", "prepare_spu2_runtime.py",
     (), None, "spu2.cpp"),
)


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for part in iter(lambda: stream.read(262144), b""):
            h.update(part)
    return h.hexdigest()


def verified_donor(assets_root: pathlib.Path) -> pathlib.Path:
    checkout = assets_root / "private" / "references" / "ps2-web-recomp"
    if not checkout.is_dir():
        raise ValueError("missing pinned donor checkout; this verifier does not download sources")
    head = subprocess.check_output(
        ["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True,
    ).strip()
    if head != DONOR_COMMIT:
        raise ValueError("donor commit is not the exact required revision")
    dirty = subprocess.check_output(
        ["git", "-C", str(checkout), "status", "--porcelain", "--untracked-files=all"],
        text=True,
    ).strip()
    if dirty:
        raise ValueError("donor has modified/untracked files; refusing unpinned input")
    return checkout


def derive(assets_root: pathlib.Path, name: str, script: str, flags: tuple[str, ...],
           manifest: str | None, field: str | None) -> None:
    output = assets_root / "private" / name
    if output.exists():
        raise ValueError(f"refusing to overwrite existing private capsule {name}")

    command = [sys.executable, str(REPO / "scripts" / script),
               str(output), "--assets-root", str(assets_root), *flags]
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL, timeout=120)
    if manifest is None:
        # The smaller IPU/SPU2/memory-card tools are pinned to exact donor
        # hashes and produce a receipt listing their source hash.
        receipt = json.loads((output / "runtime.json").read_text(encoding="utf-8"))
        if field is None:
            raise ValueError(f"{name}: missing source key")
        base = output / field
        key = field.partition(".")[0] + "_sha256"
        if not base.is_file() or sha256(base) != receipt[key]:
            raise ValueError(f"{name}: generated source does not match its receipt")
        print(f"PUBLIC_RUNTIME_RECEIPT_PASS {name} (1 pinned-donor derived source)")
        return

    pinned = json.loads((REPO / "docs" / "inputs" / manifest).read_text(encoding="utf-8"))
    if field == "PORT":
        expected_sources = pinned["inputs"]["PORT"]
    else:
        expected_sources = pinned["source_sha256"]

    if not expected_sources:
        raise ValueError(f"no pinned sources for {name}")
    for filename, expected in sorted(expected_sources.items()):
        actual_file = output / filename
        if not actual_file.is_file() or sha256(actual_file) != expected:
            raise ValueError(f"{name}: pinned SHA-256 mismatch in {filename}")

    if field is None:
        receipt = output / "runtime.json"
        if not receipt.is_file():
            raise ValueError(f"{name}: missing receipt runtime.json")
        expected = pinned.get("receipt_sha256")
        if expected and sha256(receipt) != expected:
            raise ValueError(f"{name}: pinned runtime.json SHA-256 mismatch")
    print(f"PUBLIC_RUNTIME_PIN_PASS {name} ({len(expected_sources)} sources)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assets-root", type=pathlib.Path, default=REPO)
    options = parser.parse_args()
    assets_root = options.assets_root.expanduser().resolve()
    try:
        verified_donor(assets_root)
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        print(f"PUBLIC_RUNTIME_PIN_FAIL donor: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 2

    failed = []
    for name, script, flags, manifest, field in DERIVATIONS:
        try:
            derive(assets_root, name, script, flags, manifest, field)
        except (ValueError, OSError, subprocess.CalledProcessError,
                subprocess.TimeoutExpired, KeyError, json.JSONDecodeError) as exc:
            failed.append(name)
            print(f"PUBLIC_RUNTIME_PIN_FAIL {name}: {type(exc).__name__}: {exc}", file=sys.stderr)
    if failed:
        print(f"PUBLIC_RUNTIME_BLOCKED {len(failed)}/{len(DERIVATIONS)} derivations failed: {', '.join(failed)}",
              file=sys.stderr)
        return 2
    print("PUBLIC_RUNTIME_RECONSTRUCTION_PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
