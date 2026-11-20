@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem TASK-215: derive only public MIT PS2 runtime sources on this Windows PC.
rem No game/ISO/ELF/EE/VU inputs are read. No APK or game library is built.
rem The only network access is a git fetch of the known public MIT donor.
rem No git push, uploads, ADB, root, modifications to the user's phone, or
rem overwrite of any preexisting private capsule is permitted.

pushd "%~dp0.." || exit /b 2
set "ROOT=%CD%"
set "DONOR=%ROOT%\private\references\ps2-web-recomp"
set "PIN=1b4808793a12c45125262fd2d5f50a9ec9f7c020"

where git >nul 2>nul
if errorlevel 1 (
    echo BLOQUEADO: Git nao encontrado. Nenhum arquivo foi alterado.
    popd
    exit /b 2
)
set "PYCMD=python"
where py >nul 2>nul
if not errorlevel 1 set "PYCMD=py -3"
if "%PYCMD%"=="python" (
    where python >nul 2>nul
    if errorlevel 1 (
        echo BLOQUEADO: Python 3 nao encontrado. Nenhum arquivo foi alterado.
        popd
        exit /b 2
    )
)

if exist "%DONOR%\" (
    if not exist "%DONOR%\.git\" (
        echo BLOQUEADO: o diretorio publico do runtime ja existe, mas nao e um checkout Git.
        echo Nada foi sobrescrito. Verifique: "%DONOR%"
        popd
        exit /b 2
    )
    echo GT4: checkout do runtime publico ja existe. Verificando versao e integridade...
) else (
    echo GT4: obtendo apenas codigo publico MIT, sem arquivos do jogo...
    mkdir "%DONOR%" || (popd & exit /b 2)
    git -C "%DONOR%" init -q
    if errorlevel 1 (popd & exit /b 2)
    git -C "%DONOR%" config core.autocrlf true
    if errorlevel 1 (popd & exit /b 2)
    git -C "%DONOR%" remote add origin https://github.com/snuri00/ps2-web-recomp.git
    if errorlevel 1 (popd & exit /b 2)
    git -C "%DONOR%" fetch --depth=1 origin %PIN%
    if errorlevel 1 (
        echo BLOQUEADO: nao foi possivel obter o runtime publico. Nao alterar o checkout parcial.
        popd
        exit /b 2
    )
    git -C "%DONOR%" checkout -q --detach FETCH_HEAD
    if errorlevel 1 (popd & exit /b 2)
)

echo.
echo GT4: reconstruindo/verificando fontes publicas do PS2...
%PYCMD% tools\verify_public_runtime_capsules.py --assets-root "%ROOT%" --reuse-existing
if errorlevel 1 (
    echo.
    echo BLOQUEADO: os fontes nao bateram com os pins. Nenhuma verificacao foi ignorada.
    echo Os arquivos ja existentes foram preservados. Nenhum jogo ou APK foi construido.
    popd
    exit /b 2
)
echo.
echo PUBLIC_PS2_RUNTIME_CAPSULES_READY
echo O codigo publico do runtime foi gerado e verificado em private\.
echo Os arquivos do GT4 ficam separados e nao foram acessados.
echo Isto nao compila libgt4.so nem um APK.
popd
exit /b 0
