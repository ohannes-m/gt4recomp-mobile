@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Build REAL GT4 native Android libraries from local user-owned inputs.
rem Never commits/transfers game inputs, installs APK or calls ADB.
rem Use: android\redmi-native.cmd [--check | --build-native | --build-apk]
pushd "%~dp0.." || exit /b 2

set "MODE=%~1"
if not defined MODE set "MODE=--check"
if /I "%MODE%"=="--check" goto arguments_ok
if /I "%MODE%"=="--build-native" goto arguments_ok
if /I "%MODE%"=="--build-apk" goto arguments_ok
echo Uso: android\redmi-native.cmd [--check ^| --build-native ^| --build-apk]
popd
exit /b 2

:arguments_ok
if not defined GT4_ASSETS_ROOT set "GT4_ASSETS_ROOT=%CD%"
if not defined GT4_ANDROID_NDK set "GT4_ANDROID_NDK=%LOCALAPPDATA%\Android\Sdk\ndk\26.1.10909125"
if not defined GT4_VULKAN_INCLUDE (
    if defined VULKAN_SDK set "GT4_VULKAN_INCLUDE=%VULKAN_SDK%\Include"
)
if not defined ANDROID_HOME (
    if defined LOCALAPPDATA set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
)
if not defined NDK_HOME set "NDK_HOME=%GT4_ANDROID_NDK%"
if not defined CMAKE_BUILD_PARALLEL_LEVEL set "CMAKE_BUILD_PARALLEL_LEVEL=1"

set "PYTHON=python"
where py >nul 2>nul
if not errorlevel 1 set "PYTHON=py -3"
if "%PYTHON%"=="python" (
    where python >nul 2>nul
    if errorlevel 1 (
        echo ERRO: Python 3 nao esta no PATH.
        popd
        exit /b 2
    )
)

set "EXTRA_ARGS="
if /I "%MODE%"=="--build-apk" set "EXTRA_ARGS=--apk-tools"
echo.
echo Conferindo as entradas reais, sem abrir a ISO ou acessar o celular ...
%PYTHON% tools\redmi_boot_preflight.py %EXTRA_ARGS%
if errorlevel 1 (
    echo.
    echo BLOQUEADO: verifique os itens FALTANDO.
    echo Nenhum APK foi criado nem instalado, e nada foi enviado ao GitHub.
    popd
    exit /b 2
)

if /I "%MODE%"=="--check" (
    echo.
    echo Entradas presentes. Para compilar o GT4 Android real:
    echo     android\redmi-native.cmd --build-apk
    popd
    exit /b 0
)

echo.
echo Compilando EE + VU0/VU1 + IOP + CoreGS em libgt4.so ARM64 ...
call android\native\configure-android.cmd arm64-v8a build\redmi-arm64
if errorlevel 1 (
    echo FALHA: compilacao do runtime real libgt4.so.
    popd
    exit /b 3
)

echo.
echo Staging libgt4.so + SDL3 do runtime ...
call android\stage-native-libs.cmd arm64-v8a build\redmi-arm64
if errorlevel 1 (
    echo FALHA: staging do libgt4.so / SDL3.
    popd
    exit /b 4
)

if /I "%MODE%"=="--build-native" (
    echo.
    echo LIBGT4_ARM64_PREPARADA
    echo Biblioteca real gerada; GS e APK ainda nao compilados.
    popd
    exit /b 0
)

rem A mobile Mali-G76 first-boot candidate uses ARMSX2 GS OpenGL ES,
rem NOT the experimental PanVK ICD used by the separate diagnostic app.
rem Forbid the accidental choice of the deviceless Null GS or a Vulkan-only
rem build by pinning both CMake options here for this private candidate.
set "GS_DIR=%CD%\build\redmi-armsx2-gles"
set "GS_FRONT=%CD%\android\armsx2gs"
set "GS_SOURCE=%CD%\third_party\armsx2\platforms\android\app\src\main\cpp"
echo.
echo Configurando o renderizador ARMSX2 GS / OpenGL ES sem JIT ...
cmake -S "%GS_SOURCE%" -B "%GS_DIR%" -G Ninja ^
 "-DCMAKE_TOOLCHAIN_FILE=%GT4_ANDROID_NDK%\build\cmake\android.toolchain.cmake" ^
 -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-29 ^
 -DANDROID_STL=c++_static -DCMAKE_BUILD_TYPE=Release ^
 -DUSE_OPENGL=ON -DUSE_VULKAN=OFF -DGT4GS_BUILD_TESTS=OFF ^
 "-DGT4GS_FRONTEND_DIR=%GS_FRONT%"
if errorlevel 1 (
    echo FALHA: configuracao ARMSX2 GS / OpenGL ES.
    popd
    exit /b 5
)
cmake --build "%GS_DIR%" --target gt4gs --parallel %CMAKE_BUILD_PARALLEL_LEVEL%
if errorlevel 1 (
    echo FALHA: compilacao do libgt4gs.so.
    popd
    exit /b 6
)

echo.
echo Staging libgt4gs.so e recursos graficos obrigatorios ...
call android\stage-armsx2gs.cmd arm64-v8a "%GS_DIR%"
if errorlevel 1 (
    echo FALHA: staging do libgt4gs.so ou shaders/fontes do ARMSX2.
    popd
    exit /b 7
)

echo.
echo Conferindo os tres .so, o AAR e shaders dentro do launcher ...
%PYTHON% tools\redmi_boot_preflight.py --staged
if errorlevel 1 (
    echo FALHA: o APK ficaria incompleto; empacotamento cancelado.
    popd
    exit /b 8
)

rem The keystore is supplied by the owner via GT4_ANDROID_SIGNING.
rem No signing key or game code is uploaded or generated in GitHub Actions.
if not defined GT4_RELEASE_LABEL set "GT4_RELEASE_LABEL=redmi-gles-private"
rem Ensure this candidate has a versionCode above 1.3.0-rc15 (103001509).
if not defined GT4_ANDROID_VERSION_CODE set "GT4_ANDROID_VERSION_CODE=103001520"

echo.
echo Empacotando o launcher Android real (Tauri + SDL3 + GT4) ...
pushd "launcher\crates\gt4l-tauri"
if errorlevel 1 (
    echo FALHA: launcher Tauri nao encontrado.
    popd
    exit /b 9
)
call cargo tauri android build --target aarch64 --apk --ci
if errorlevel 1 (
    popd
    echo FALHA: geracao do APK. Bibliotecas locais mantidas.
    popd
    exit /b 10
)
popd

set "APK=launcher\crates\gt4l-tauri\gen\android\app\build\outputs\apk\universal\release\app-universal-release.apk"
if not exist "%APK%" (
    echo FALHA: o comando terminou sem o APK esperado.
    popd
    exit /b 11
)
if not exist "build\redmi-output" mkdir "build\redmi-output"
copy /y "%APK%" "build\redmi-output\GT4Recomp-private-redmi-arm64.apk" >nul
if errorlevel 1 (
    echo FALHA: nao foi possivel copiar o APK ao diretorio privado local.
    popd
    exit /b 12
)
echo.
echo GT4_ANDROID_APK_CONSTRUIDO_LOCALMENTE
echo Arquivo: build\redmi-output\GT4Recomp-private-redmi-arm64.apk
echo Ainda nao testado no Redmi. Nenhum APK foi instalado automaticamente.
echo NUNCA enviar ISO, ELF, bibliotecas de jogo, chaves ou APK privado a repositorios publicos.
popd
exit /b 0
