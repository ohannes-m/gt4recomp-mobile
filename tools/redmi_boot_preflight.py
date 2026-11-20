#!/usr/bin/env python3
"""Offline, read-only readiness check for a REAL GT4Recomp Android build.

This does not execute GT4, compile anything, hash/read the game ISO, transfer
files, call ADB, access the phone, send network requests or change game inputs.
It only checks the already-existing PRIVATE inputs consumed by the Android
CMake recipe, plus tools required for its Windows arm64-v8a build.

GT4Recomp source and the user's disc-derived material must remain separate:
never commit ISOs, rebuilt ELF, generated EE/VU, game-derived capsules, or keys.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

REPO = Path(__file__).resolve().parent.parent
DONOR_REV = "1b4808793a12c45125262fd2d5f50a9ec9f7c020"
SDL_REV = "829a65d769d935c4852f8159e964312c0957260a"

CAPSULES = {
    "EE adapter": ("slice200-port", ("main.cpp", "gs.cpp")),
    "runtime": ("slice262-frame-cost-runtime", ("runtime.json", "system.cpp", "vu_micro.cpp")),
    "license guard": ("slice376-frame-render-license-guard-runtime", ("dispatch.cpp", "kernel.cpp", "cdvdfsv.cpp")),
    "memory card": ("slice200-memcard-runtime", ("runtime.json", "sio2.cpp")),
    "IPU": ("slice365-ipu-fast-runtime", ("runtime.json", "ipu.cpp")),
    "SPU2": ("slice396-spu2-runtime", ("runtime.json", "spu2.cpp")),
}
VU_DIRS = {
    "VU1 AOT": ("slice397-vu1-gen", "vu1_generated"),
    "VU0 AOT": ("slice394-v200-vu0-gen", "vu0_generated"),
}


def arg_path(value: str | None, fallback: Path | None = None) -> Path | None:
    return Path(value).expanduser().resolve() if value else fallback


def default_assets_root() -> Path:
    raw = os.environ.get("GT4_ASSETS_ROOT")
    return arg_path(raw, REPO)  # type: ignore[return-value]


def default_ndk() -> Path | None:
    env = os.environ.get("GT4_ANDROID_NDK")
    if env:
        return arg_path(env)
    local = os.environ.get("LOCALAPPDATA")
    return Path(local, "Android", "Sdk", "ndk", "26.1.10909125") if local else None


def default_vulkan() -> Path | None:
    env = os.environ.get("GT4_VULKAN_INCLUDE")
    if env:
        return arg_path(env)
    sdk = os.environ.get("VULKAN_SDK")
    if sdk:
        return arg_path(str(Path(sdk) / "Include"))
    return None


class Report:
    def __init__(self) -> None:
        self.good = 0
        self.bad = 0

    def record(self, name: str, ok: bool, reason: str = "") -> None:
        if ok:
            self.good += 1
            print(f"[OK]     {name}" + (f" - {reason}" if reason else ""))
        else:
            self.bad += 1
            print(f"[FALTA]  {name}" + (f" - {reason}" if reason else ""))

    def files(self, name: str, root: Path | None, names: tuple[str, ...]) -> None:
        missing = [n for n in names if root is None or not (root / n).is_file()]
        self.record(name, not missing, ", ".join(missing) if missing else "")


def git_status(folder: Path) -> tuple[bool, str]:
    if not folder.is_dir():
        return False, "checkout do runtime ausente"
    if not shutil.which("git"):
        return False, "Git nao encontrado"
    try:
        sha = subprocess.run(
            ["git", "-C", str(folder), "rev-parse", "HEAD"],
            capture_output=True, text=True, check=True, timeout=10,
        ).stdout.strip()
        dirty = subprocess.run(
            ["git", "-C", str(folder), "status", "--porcelain", "--untracked-files=all"],
            capture_output=True, text=True, check=True, timeout=10,
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return False, "impossivel verificar checkout com git"
    return (sha == DONOR_REV and not dirty,
            "commit pinado e limpo" if sha == DONOR_REV and not dirty
            else "commit diferente ou checkout com alteracoes")


def check_source(r: Report) -> None:
    r.files("Fonte Android real", REPO / "android" / "native",
            ("CMakeLists.txt", "configure-android.cmd"))
    r.files("Runtime e renderizadores", REPO / "native",
            ("android_main.cpp", "game_start.cpp"))
    r.files("Frontend ARMSX2", REPO / "android" / "armsx2gs",
            ("gt4gs_host.cpp", "CMakeLists.txt"))


def check_private(r: Report, root: Path, units: Path | None,
                  shaders: Path | None) -> None:
    private = root / "private"
    donor = private / "references" / "ps2-web-recomp"
    ok, note = git_status(donor)
    r.record("Runtime PS2 de origem (pin)", ok, note)

    for label, (folder, files) in CAPSULES.items():
        r.files(f"Capsula: {label}", private / folder, files)

    for label, (folder, prefix) in VU_DIRS.items():
        folder_path = private / folder
        main = folder_path / f"{prefix}.cpp"
        parts = list(folder_path.glob(f"{prefix}_*.cpp")) if folder_path.is_dir() else []
        r.record(label, main.is_file() and len(parts) > 0,
                 f"{len(parts)} partes" if main.is_file() and parts
                 else "codigo gerado ausente (principal ou partes)")

    manifest = arg_path(os.environ.get("GT4_EE_UNITS_MANIFEST"),
                        private / "slice408-ee-v200" / "v200-units-rc14b.camera360-units.json")
    r.record("Manifesto EE de hooks", bool(manifest and manifest.is_file()),
             "necessario para a receita rc14b" if not manifest or not manifest.is_file() else "")

    if units is None:
        r.record("Unidades EE recompiladas", False,
                 "defina GT4_EE_UNITS_DIR (pasta com unit_*.cpp, table.cpp, units.hpp)")
    else:
        count = len(list(units.glob("unit_*.cpp"))) if units.is_dir() else 0
        okay = count >= 300 and (units / "table.cpp").is_file() and (units / "units.hpp").is_file()
        r.record("Unidades EE recompiladas", okay,
                 f"{count} unit_*.cpp" if okay
                 else f"{count} unit_*.cpp; esperado >=300, table.cpp e units.hpp")

    shader_count = len(list(shaders.glob("*_spirv.cpp"))) if shaders and shaders.is_dir() else 0
    r.record("Shaders CoreGS em C++", shader_count > 0,
             f"{shader_count} arquivos" if shader_count > 0
             else "defina GT4_HW_SHADER_CPP_DIR com *_spirv.cpp")

    aar = private / "tooling" / "sdl3-3.4.18-android" / "aar"
    r.files("SDL3 3.4.18 Android", aar, (
        "prefab/modules/SDL3-shared/libs/android.arm64-v8a/libSDL3.so",
        "prefab/modules/SDL3-Headers/include/SDL3/SDL.h",
        ".git-hash",
    ))
    sdl_pin = aar / ".git-hash"
    if sdl_pin.is_file():
        rev = sdl_pin.read_text(encoding="utf-8", errors="replace").strip()
        r.record("Versao SDL3 pinada", rev == SDL_REV,
                 "pin correto" if rev == SDL_REV else "versao diferente da receita")
    else:
        r.record("Versao SDL3 pinada", False, ".git-hash ausente")

    # The native CMake recipe invokes this specific private Python interpreter.
    p = private / "tooling-venv" / "Scripts" / "python.exe"
    r.record("Python privado da receita", p.is_file(),
             "private/tooling-venv/Scripts/python.exe" if not p.is_file() else "")


def check_tools(r: Report, ndk: Path | None, vulkan: Path | None) -> None:
    r.files("Android NDK 26.1 ARM64", ndk,
            ("build/cmake/android.toolchain.cmake",
             "toolchains/llvm/prebuilt/windows-x86_64/bin/clang++.exe",
             "toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-strip.exe"))
    r.files("Headers Vulkan", vulkan, ("vulkan/vulkan.h",))
    for command in ("cmake", "ninja", "git", "cargo"):
        r.record(f"Programa: {command}", bool(shutil.which(command)),
                 "nao esta no PATH" if not shutil.which(command) else "")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verifica insumos privados e ferramentas do verdadeiro libgt4.so. Offline e somente leitura.")
    parser.add_argument("--assets-root", type=Path,
                        help="Checkout que contem private/ (ou GT4_ASSETS_ROOT).")
    parser.add_argument("--ee-units", type=Path,
                        help="Pasta com unit_*.cpp (ou GT4_EE_UNITS_DIR).")
    parser.add_argument("--hw-shaders", type=Path,
                        help="Pasta com *_spirv.cpp (ou GT4_HW_SHADER_CPP_DIR).")
    parser.add_argument("--ndk", type=Path,
                        help="NDK Android 26.1 (ou GT4_ANDROID_NDK).")
    parser.add_argument("--vulkan-include", type=Path,
                        help="Pasta Include do Vulkan SDK (ou GT4_VULKAN_INCLUDE/VULKAN_SDK).")
    args = parser.parse_args()

    assets = (args.assets_root.resolve() if args.assets_root else default_assets_root())
    units = arg_path(str(args.ee_units) if args.ee_units else os.environ.get("GT4_EE_UNITS_DIR"))
    shaders = arg_path(str(args.hw_shaders) if args.hw_shaders
                       else os.environ.get("GT4_HW_SHADER_CPP_DIR"))
    ndk = args.ndk.resolve() if args.ndk else default_ndk()
    vulkan = args.vulkan_include.resolve() if args.vulkan_include else default_vulkan()
    print("GT4Recomp - Redmi / BUILD REAL (somente leitura)")
    print("Nenhum teste de PanVK, instalacao APK, root, ADB ou envio de arquivos.\n")
    r = Report()
    check_source(r)
    check_private(r, assets, units, shaders)
    check_tools(r, ndk, vulkan)
    print(f"\nRESULTADO: {r.good} OK, {r.bad} FALTANDO")
    if r.bad:
        print("BLOQUEADO: primeiro obter/completar os insumos privados da propria copia do jogo.")
        print("Nao envie ISO, ELF, unidades recompiladas, saves ou chaves ao GitHub.")
        return 2
    print("PRONTO PARA CONFIGURAR libgt4.so (nao significa que o jogo ja funciona).")
    print("Proximo passo: android/native/configure-android.cmd arm64-v8a <build-dir>")
    return 0


if __name__ == "__main__":
    sys.exit(main())
