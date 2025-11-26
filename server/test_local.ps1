# Script para probar el servidor localmente
# Ejecutar desde el directorio raíz del proyecto

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BattleTech Server - Test Local" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar que estamos en el directorio correcto
if (-not (Test-Path "project.godot")) {
    Write-Host "ERROR: Ejecutar desde el directorio raiz del proyecto" -ForegroundColor Red
    exit 1
}

# Buscar Godot
$godotPath = $null
$possiblePaths = @(
    "godot",
    "C:\Program Files\Godot\Godot.exe",
    "$env:USERPROFILE\scoop\apps\godot\current\godot.exe",
    "$env:LOCALAPPDATA\Godot\godot.exe",
    "C:\Godot\Godot_v4.3-stable_win64.exe",
    "C:\Godot\Godot_v4.2-stable_win64.exe"
)

foreach ($path in $possiblePaths) {
    if (Get-Command $path -ErrorAction SilentlyContinue) {
        $godotPath = $path
        break
    }
    if (Test-Path $path) {
        $godotPath = $path
        break
    }
}

if (-not $godotPath) {
    Write-Host "ERROR: No se encontro Godot. Asegurate de tenerlo instalado." -ForegroundColor Red
    Write-Host "Puedes especificar la ruta manualmente editando este script." -ForegroundColor Yellow
    exit 1
}

Write-Host "Usando Godot: $godotPath" -ForegroundColor Gray
Write-Host ""

# Instrucciones
Write-Host "=== INSTRUCCIONES ===" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Este script iniciara el SERVIDOR en esta ventana" -ForegroundColor White
Write-Host "2. Abre DOS instancias adicionales de Godot como CLIENTES" -ForegroundColor White
Write-Host "3. En cada cliente, ve a Multiplayer y conecta a: 127.0.0.1" -ForegroundColor White
Write-Host ""
Write-Host "Para abrir clientes manualmente:" -ForegroundColor Cyan
Write-Host "  $godotPath --path `"$(Get-Location)`"" -ForegroundColor Gray
Write-Host ""
Write-Host "Presiona ENTER para iniciar el servidor..." -ForegroundColor Yellow
Read-Host

Write-Host ""
Write-Host "Iniciando servidor en puerto 7777..." -ForegroundColor Green
Write-Host "(Presiona Ctrl+C para detener)" -ForegroundColor Gray
Write-Host ""

# Iniciar servidor
# Usamos la escena server_main.tscn como escena principal
& $godotPath --headless --path "$(Get-Location)" --main-pack "" "res://scenes/server_main.tscn" -- --port=7777
