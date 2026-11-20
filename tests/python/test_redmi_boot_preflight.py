#!/usr/bin/env python3
"""Offline tests for Redmi real-game build preflight. No private game inputs."""
from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "redmi_boot_preflight", ROOT / "tools" / "redmi_boot_preflight.py"
)
assert SPEC and SPEC.loader
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class ReadinessTests(unittest.TestCase):
    def test_missing_private_files_gate_real_native_build(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory)
            with patch.object(module, "REPO", fake):
                r = module.Report()
                module.check_source(r)
                module.check_private(r, fake, None, None)
                self.assertGreater(r.bad, 0)

    def test_missing_stage_files_cannot_be_packaged(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(module, "REPO", Path(directory)):
                r = module.Report()
                module.check_staged(r)
                self.assertEqual(r.good, 0)
                self.assertGreater(r.bad, 0)

    def test_staged_library_and_resources_gate(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory)
            app = fake / "launcher" / "crates" / "gt4l-tauri" / "gen" / "android" / "app"
            files = (
                "src/main/jniLibs/arm64-v8a/libgt4.so",
                "src/main/jniLibs/arm64-v8a/libgt4gs.so",
                "src/main/jniLibs/arm64-v8a/libSDL3.so",
                "libs/SDL3-3.4.18.aar",
                "src/main/assets/armsx2gs/resources/GameIndex.yaml",
                "src/main/assets/armsx2gs/resources/shaders/common/fxaa.fx",
                "src/main/assets/armsx2gs/resources/shaders/opengl/merge.glsl",
                "src/main/assets/armsx2gs/resources/fonts/RobotoMono-Medium.ttf",
            )
            for rel in files:
                path = app / rel
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"fixture")
            with patch.object(module, "REPO", fake):
                valid = module.Report()
                module.check_staged(valid)
                self.assertEqual(valid.bad, 0)
                # Lose the real GS and fail closed; other staged files remain.
                (app / files[1]).unlink()
                invalid = module.Report()
                module.check_staged(invalid)
                self.assertGreater(invalid.bad, 0)

    def test_no_signing_file_blocks_apk(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(module, "REPO", Path(directory)), patch.dict(
                os.environ, {"GT4_ANDROID_SIGNING": str(Path(directory) / "not-here.properties")},
            ):
                r = module.Report()
                module.check_apk_tools(r)
                self.assertGreater(r.bad, 0)

    def test_args_preflight_does_not_read_game_iso(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            f = Path(directory) / "GT4.iso"
            f.write_bytes(b"private, must not be read")
            with patch.object(module, "REPO", Path(directory)), patch.dict(
                os.environ, {"GT4_ASSETS_ROOT": directory,
                             "GT4_EE_UNITS_DIR": "",
                             "GT4_HW_SHADER_CPP_DIR": ""},
            ):
                r = module.Report()
                module.check_source(r)
                module.check_private(r, Path(directory), None, None)
                self.assertEqual(f.read_bytes(), b"private, must not be read")
                self.assertGreater(r.bad, 0)


if __name__ == "__main__":
    unittest.main()
