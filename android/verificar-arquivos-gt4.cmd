@echo off
setlocal
title GT4 - Verificar os componentes ja extraidos
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0redmi-local-assets.ps1"
set "RC=%errorlevel%"
echo.
echo Copie somente o resumo da tela. Nao envie arquivos do jogo.
pause
exit /b %RC%
