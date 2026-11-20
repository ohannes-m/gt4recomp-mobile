@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Local-only EE/VU integration. Do NOT upload the private ZIP to GitHub.
rem Usage: integrar-ee-vu-privado.cmd "C:\path\GT4_PRIVADO_NAO_PUBLICAR" [--check|--build-native|--build-apk]
set "GAME_INPUTS=%~1"
set "MODE=%~2"
if not defined MODE set "MODE=--check"
if /I not "%MODE%"=="--check" if /I not "%MODE%"=="--build-native" if /I not "%MODE%"=="--build-apk" (
  echo ERRO: modo desconhecido: %MODE%
  exit /b 2
)
if not defined GAME_INPUTS (
  echo Uso: android\integrar-ee-vu-privado.cmd "PASTA_EXTRAIDA\GT4_PRIVADO_NAO_PUBLICAR" [--check^|--build-native^|--build-apk]
  exit /b 2
)
if not exist "%GAME_INPUTS%\EE_hooked\table.cpp" goto missing
if not exist "%GAME_INPUTS%\EE_hooked\units.hpp" goto missing
if not exist "%GAME_INPUTS%\EE_hooked\unit_0000.cpp" goto missing
if not exist "%GAME_INPUTS%\EE_hooked.camera360-units.json" goto missing
if not exist "%GAME_INPUTS%\VU0\vu0_generated.cpp" goto missing
if not exist "%GAME_INPUTS%\VU0\manifest.json" goto missing
if not exist "%GAME_INPUTS%\VU1\vu1_generated.cpp" goto missing
if not exist "%GAME_INPUTS%\VU1\manifest.json" goto missing
set "GT4_EE_UNITS_DIR=%GAME_INPUTS%\EE_hooked"
set "GT4_EE_UNITS_MANIFEST=%GAME_INPUTS%\EE_hooked.camera360-units.json"
set "GT4_VU0_GENERATED_DIR=%GAME_INPUTS%\VU0"
set "GT4_VU1_GENERATED_DIR=%GAME_INPUTS%\VU1"
echo GT4Recomp: preparando EE e VU locais, sem upload.
echo OBS: o runtime PS2 privado, capsulas rc14b, SDL3, CoreGS e toolchain ainda sao requisitos.
call "%~dp0redmi-native.cmd" %MODE%
exit /b %ERRORLEVEL%
:missing
echo ERRO: pasta incompleta. Extraia o pacote privado completo antes de continuar.
exit /b 2
