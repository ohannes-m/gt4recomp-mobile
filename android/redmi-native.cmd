@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Real GT4 Android boot path. Uses ONLY local private inputs.
rem Default: read-only readiness check. Optional: --build-native compiles
rem libgt4.so from the user's own translated EE/VU inputs.
rem Never installs an APK, invokes ADB, reads the game ISO or uploads files.
pushd "%~dp0.." || exit /b 2

if not defined GT4_ASSETS_ROOT set "GT4_ASSETS_ROOT=%CD%"
if not defined GT4_ANDROID_NDK set "GT4_ANDROID_NDK=%LOCALAPPDATA%\Android\Sdk\ndk\26.1.10909125"
if not defined GT4_VULKAN_INCLUDE (
    if defined VULKAN_SDK set "GT4_VULKAN_INCLUDE=%VULKAN_SDK%\Include"
)

where py >nul 2>nul
if not errorlevel 1 (
    py -3 tools\redmi_boot_preflight.py
) else (
    where python >nul 2>nul
    if errorlevel 1 (
        echo ERRO: Python 3 nao esta no PATH.
        popd
        exit /b 2
    )
    python tools\redmi_boot_preflight.py
)
if errorlevel 1 (
    echo.
    echo BUILDER BLOQUEADO: corrija os itens FALTANDO antes de compilar GT4.
    popd
    exit /b 2
)

if /I not "%~1"=="--build-native" (
    echo.
    echo Os insumos estao presentes. Para compilar a biblioteca nativa:
    echo     android\redmi-native.cmd --build-native
    echo Nao foi executado nenhum teste de GPU ou comando no celular.
    popd
    exit /b 0
)

echo.
echo Construindo o runtime REAL ARM64: EE + VU + IOP + CoreGS ...
call android\native\configure-android.cmd arm64-v8a build\redmi-arm64
if errorlevel 1 (
    echo ERRO: falha ao compilar libgt4.so. A fonte privada ficou no PC.
    popd
    exit /b 3
)

echo.
echo Integrando libgt4.so e SDL3 no projeto Android ...
call android\stage-native-libs.cmd arm64-v8a build\redmi-arm64
if errorlevel 1 (
    echo ERRO: falha no staging Android, nenhum APK foi instalado.
    popd
    exit /b 4
)

echo.
echo LIBGT4_ARM64_PREPARADA
echo Nao e um APK jogavel: ainda sao necessarios libgt4gs.so,
echo recursos ARMSX2 e o empacotamento do launcher.
echo As entradas do jogo nao foram enviadas ao GitHub.
popd
exit /b 0
