# Offline, read-only inventory of already-extracted local GT4 (USA v2.00) pieces.
# Works with Windows PowerShell 5.1, no Python, SDK, internet, Git or Android.
# Never reads or copies ISO, ELF, executable data, C++ contents, keys or saves.
[CmdletBinding()]
param(
    [string]$PrivateRoot = ""
)
$ErrorActionPreference = "Stop"

function ExistsFile([string]$Path) {
    return [System.IO.File]::Exists($Path)
}
function FirstNewestFolder([string]$Parent, [string]$Pattern) {
    if (-not [System.IO.Directory]::Exists($Parent)) { return $null }
    $matches = @(Get-ChildItem -LiteralPath $Parent -Directory -Filter $Pattern -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending)
    if ($matches.Count -eq 0) { return $null }
    return $matches[0].FullName
}
function CountSources([string]$Folder, [string]$Pattern) {
    if (-not $Folder -or -not [System.IO.Directory]::Exists($Folder)) { return 0 }
    return @(Get-ChildItem -LiteralPath $Folder -File -Filter $Pattern -ErrorAction SilentlyContinue).Count
}

$Desktop = [Environment]::GetFolderPath("Desktop")
if ([string]::IsNullOrWhiteSpace($PrivateRoot)) {
    # The original folder was named "verificacao iso" with accents on many
    # Windows installations. Discover it by a Unicode-safe prefix wildcard.
    $extractionFolder = FirstNewestFolder $Desktop "verifica* iso"
    if ($extractionFolder) {
        $PrivateRoot = Join-Path $extractionFolder "GT4_PRIVADO_NAO_PUBLICAR\GT4_RECOMP_PRIVADO"
    } else {
        $PrivateRoot = Join-Path $Desktop "GT4_PRIVADO_NAO_PUBLICAR\GT4_RECOMP_PRIVADO"
    }
}
$PrivateRoot = [System.IO.Path]::GetFullPath($PrivateRoot)

Write-Output "GT4Recomp - ARQUIVOS JA RECOMPILADOS NO PC"
Write-Output "Somente verifica existencia e contagens. Nao le conteudo nem envia arquivos."
Write-Output ""

$elf = Join-Path $PrivateRoot "SCUS_973.28.elf"
$elfOk = ExistsFile $elf
if ($elfOk) {
    Write-Output "ELF: ENCONTRADO"
} else {
    Write-Output "ELF: NAO ENCONTRADO"
}

$eeFolder = FirstNewestFolder (Join-Path $PrivateRoot "GT4_PRIVADO_NAO_PUBLICAR") "GT4_CPP_*"
$eeCount = CountSources $eeFolder "unit_*.cpp"
$eeOk = $false
if ($eeFolder) {
    $eeOk = $eeCount -ge 326 -and (ExistsFile (Join-Path $eeFolder "table.cpp")) -and (ExistsFile (Join-Path $eeFolder "units.hpp"))
}
if ($eeOk) {
    Write-Output "EE: ENCONTRADO ($eeCount unidades C++ + table.cpp + units.hpp)"
} else {
    Write-Output "EE: NAO ENCONTRADO OU INCOMPLETO ($eeCount unidades)"
}

$vuOutput = Join-Path $PrivateRoot "GT4_VU0_VU1_PRIVADO_20261119_155917_606\GT4_VU_GERADO_PRIVADO"
$vuRun = FirstNewestFolder $vuOutput "20*"
$vu0 = if ($vuRun) { Join-Path $vuRun "VU0" } else { $null }
$vu1 = if ($vuRun) { Join-Path $vuRun "VU1" } else { $null }
$vu0Count = CountSources $vu0 "*.cpp"
$vu1Count = CountSources $vu1 "*.cpp"
$vu0Ok = $false
$vu1Ok = $false
if ($vu0) { $vu0Ok = $vu0Count -ge 1 -and (ExistsFile (Join-Path $vu0 "manifest.json")) }
if ($vu1) { $vu1Ok = $vu1Count -ge 129 -and (ExistsFile (Join-Path $vu1 "manifest.json")) }
if ($vu0Ok) { Write-Output "VU0: ENCONTRADO ($vu0Count fontes C++)" }
else { Write-Output "VU0: NAO ENCONTRADO OU INCOMPLETO ($vu0Count fontes)" }
if ($vu1Ok) { Write-Output "VU1: ENCONTRADO ($vu1Count fontes C++)" }
else { Write-Output "VU1: NAO ENCONTRADO OU INCOMPLETO ($vu1Count fontes)" }

Write-Output ""
if ($elfOk -and $eeOk -and $vu0Ok -and $vu1Ok) {
    Write-Output "EXTRACAO ANTERIOR: ENCONTRADA. NAO REEXTRAIR."
    Write-Output "PROXIMO TRABALHO: adaptar fontes EE/VU ao runtime Android e construir libgt4.so."
    Write-Output "AVISO: o build atual tambem requer capsulas privadas rc14b/hook, SDL3 e CoreGS."
    Write-Output "Essas dependencias NAO ficam prontas apenas por haver C++ gerado."
} else {
    Write-Output "EXTRACAO ANTERIOR: PARCIAL OU EM OUTRO LOCAL."
    Write-Output "Verifique somente a pasta privada que ja foi usada; nao refaca extracoes."
}
Write-Output "Nao envie ELF, ISO, VU, unit_*.cpp nem manifests. Apenas este resumo."
