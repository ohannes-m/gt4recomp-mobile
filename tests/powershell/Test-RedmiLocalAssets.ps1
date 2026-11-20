$ErrorActionPreference = 'Stop'
# Synthetic file counts only. Never use real game files in CI.
$root = Join-Path $env:RUNNER_TEMP ("gt4-redmi-fixture-" + [guid]::NewGuid().ToString("N"))
try {
    $ee = Join-Path $root "GT4_PRIVADO_NAO_PUBLICAR\GT4_CPP_20261119_154130_877"
    $vu = Join-Path $root "GT4_VU0_VU1_PRIVADO_20261119_155917_606\GT4_VU_GERADO_PRIVADO\20261119_163501_336"
    $vu0 = Join-Path $vu "VU0"
    $vu1 = Join-Path $vu "VU1"
    foreach ($d in @($root, $ee, $vu0, $vu1)) {
        New-Item -Path $d -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText((Join-Path $root "SCUS_973.28.elf"), "fixture")
    [System.IO.File]::WriteAllText((Join-Path $ee "table.cpp"), "fixture")
    [System.IO.File]::WriteAllText((Join-Path $ee "units.hpp"), "fixture")
    for ($i = 0; $i -lt 326; $i++) {
        [System.IO.File]::WriteAllText((Join-Path $ee ("unit_{0:X4}.cpp" -f $i)), "fixture")
    }
    foreach ($folder in @($vu0, $vu1)) {
        [System.IO.File]::WriteAllText((Join-Path $folder "manifest.json"), "{}")
    }
    [System.IO.File]::WriteAllText((Join-Path $vu0 "vu0.cpp"), "fixture")
    for ($i = 0; $i -lt 129; $i++) {
        [System.IO.File]::WriteAllText((Join-Path $vu1 ("vu1_{0:D3}.cpp" -f $i)), "fixture")
    }

    $script = Join-Path $PSScriptRoot "..\..\android\redmi-local-assets.ps1"
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -PrivateRoot $root
    if ($LASTEXITCODE -ne 0) { throw "Local inventory script failed" }
    foreach ($token in @(
        "ELF: ENCONTRADO",
        "EE: ENCONTRADO (326",
        "VU0: ENCONTRADO (1",
        "VU1: ENCONTRADO (129",
        "EXTRACAO ANTERIOR: ENCONTRADA."
    )) {
        if (!(($output | Out-String).Contains($token))) {
            throw "Missing report marker: $token"
        }
    }
    Write-Output "LOCAL_GT4_EXISTING_EE_VU_INVENTORY_PASS"
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
