@echo off
REM Script para ejecutar todos los tests del proyecto Battletech
REM Requiere Godot 4.x instalado y en el PATH

echo ================================
echo   BATTLETECH - Test Runner
echo ================================
echo.

REM Buscar Godot en rutas comunes
set GODOT_PATH=""

if exist "C:\Program Files\Godot\Godot.exe" (
    set GODOT_PATH="C:\Program Files\Godot\Godot.exe"
)

if exist "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.exe" (
    set GODOT_PATH="C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.exe"
)

if exist "%LOCALAPPDATA%\Programs\Godot\Godot.exe" (
    set GODOT_PATH="%LOCALAPPDATA%\Programs\Godot\Godot.exe"
)

if %GODOT_PATH%=="" (
    echo ERROR: No se encontro Godot en las rutas comunes
    echo Por favor edita este script y pon la ruta a Godot.exe
    pause
    exit /b 1
)

echo Ejecutando tests con Godot...
echo.

REM Ejecutar escena de tests
%GODOT_PATH% --path "G:\Battletech" "res://tests/test_runner.tscn"

echo.
echo Tests completados!
pause
